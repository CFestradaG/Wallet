# Cifra — Recomendaciones Técnicas
**Análisis completo del codebase · Abril 2026**

---

## Resumen ejecutivo

Cifra está bien construida: arquitectura sólida con Riverpod + Firestore, modelos limpios, y features diferenciadoras como cuotas fijas, transferencias con grupo, y rendimientos. El trabajo pendiente se concentra en tres grandes áreas: **eficiencia de datos** (reducir lecturas de Firestore innecesarias), **deuda técnica** (lógica duplicada y código muerto), y **experiencia de producto** (el chat AI local necesita ser reemplazado con Claude real).

---

## 1. Eficiencia de datos y caché

### 1.1 Habilitar persistencia offline de Firestore

Firestore tiene caché local integrado. Actualmente no está configurado explícitamente. Activarlo con `PersistenceSettings` hace que todos los streams funcionen offline, reduce lecturas en sesiones repetidas, y no rompe la consistencia porque el SDK maneja la reconciliación automáticamente.

**Dónde:** `lib/main.dart`, antes de `Firebase.initializeApp`.

```dart
// main.dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

**Impacto:** En sesiones típicas, hasta 80% menos de lecturas de Firestore. Sin costo de implementación. No afecta sincronización multiplataforma porque Firestore usa "last-write-wins" con timestamps del servidor.

---

### 1.2 Consolidar el cálculo de balances en un provider central

`_computeBalances` está duplicado en **tres archivos**:
- `accounts_tab.dart`
- `dashboard_tab.dart`
- `ai_chat_tab.dart`

Cada uno itera sobre todas las transacciones por separado. Con 500 transacciones y 10 cuentas, eso son tres iteraciones idénticas en cada rebuild.

**Solución:** Un `Provider.family` o `Provider` derivado en `firestore_providers.dart`.

```dart
// firestore_providers.dart

/// Mapa de accountId -> balance calculado
final accountBalancesProvider = Provider<Map<String, double>>((ref) {
  final accounts = ref.watch(accountsStreamProvider).value ?? [];
  final transactions = ref.watch(allTransactionsStreamProvider).value ?? [];

  final byId = {for (final a in accounts) a.id: a};
  final balances = {for (final a in accounts) a.id: a.currentDebt};

  for (final tx in transactions) {
    final acc = byId[tx.accountId];
    if (acc == null) continue;
    final current = balances[acc.id] ?? 0.0;
    if (acc.type == AccountType.creditCard) {
      balances[acc.id] = tx.type == TransactionType.expense
          ? current + tx.amount
          : current - tx.amount;
    } else {
      balances[acc.id] = tx.type == TransactionType.income
          ? current + tx.amount
          : current - tx.amount;
    }
  }
  return balances;
});
```

Luego en cada pantalla: `final balances = ref.watch(accountBalancesProvider);`

**Impacto:** Riverpod cachea el resultado. Si ni las cuentas ni las transacciones cambiaron, no recalcula. Elimina ~150 líneas duplicadas.

---

### 1.3 Reducir escrituras en Firestore al persistir filtros

`_persistFilters()` en `transactions_screen.dart` y `reports_tab.dart` escribe a Firestore en **cada cambio de estado**. Si el usuario escribe en el buscador, cada tecla genera una escritura. Con el plan Spark, Firestore tiene límite de 20,000 escrituras/día.

**Solución:** Debounce con un `Timer` de 800ms.

```dart
Timer? _debounceTimer;

void _updateFilters(VoidCallback update) {
  setState(update);
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 800), _persistFilters);
}

@override
void dispose() {
  _debounceTimer?.cancel();
  _searchController.dispose();
  super.dispose();
}
```

**Impacto:** De potencialmente 50+ escrituras por sesión de búsqueda a 1–2. Mejor UX porque el UI responde inmediatamente.

---

### 1.4 Separar filtros del documento de preferencias de usuario

Actualmente, los filtros de transacciones (`transactionsAccountId`, `transactionsPeriodId`, etc.) y los filtros de reportes (`f_account`, `f_period`, etc.) se guardan en `users/{uid}` como parte de `preferences`. Esto significa que **cada cambio de filtro re-descarga el documento completo de preferencias** en todos los dispositivos del usuario, incluyendo tema y moneda.

**Solución:** Mover los filtros a un documento separado que solo se lean cuando se abre la pantalla correspondiente, no en stream continuo.

```dart
// En firestoreServiceProvider:
Future<Map<String, dynamic>> getScreenFilters(String uid, String screen) async {
  final snap = await _db
      .collection('users')
      .doc(uid)
      .collection('screen_state')
      .doc(screen)
      .get();
  return snap.data() ?? {};
}

Future<void> saveScreenFilters(
    String uid, String screen, Map<String, dynamic> filters) async {
  await _db
      .collection('users')
      .doc(uid)
      .collection('screen_state')
      .doc(screen)
      .set(filters, SetOptions(merge: true));
}
```

Las preferencias reales (tema, moneda, etiquetas) quedan en el stream reactivo. Los filtros de UI se cargan una vez con `Future` al abrir la pantalla, no con `StreamProvider`.

---

### 1.5 Limitar las transacciones cargadas en el stream global

`allTransactionsStreamProvider` carga **todas las transacciones de todos los períodos** en tiempo real. Con un año de datos esto puede ser 300–500 documentos cargados siempre en memoria.

**Estrategia recomendada:** Cargar solo los últimos N meses por defecto y paginar hacia atrás cuando el usuario lo necesite.

```dart
final recentTransactionsProvider = StreamProvider<List<TransactionRecord>>((ref) {
  final db = ref.watch(firestoreProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();

  // Solo los últimos 90 días por defecto
  final cutoff = DateTime.now().subtract(const Duration(days: 90));
  
  return db
      .collection('users')
      .doc(user.uid)
      .collection('transactions')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => TransactionRecord.fromMap(doc.id, doc.data()))
          .toList());
});
```

Para los reportes históricos, mantener `allTransactionsStreamProvider` pero marcarlo como "para uso en reportes únicamente" y evitar usarlo en el dashboard y cuentas.

> **Nota:** Requiere crear un índice compuesto en Firestore para `date` + cualquier campo adicional usado en filtros.

---

## 2. Deuda técnica y código muerto

### 2.1 Eliminar código muerto en `add_transaction_screen.dart`

Hay un bloque de código con `if (false)` que ocupa ~40 líneas y nunca se ejecuta. Fue reemplazado por `_buildAmountSection` pero no se eliminó. Eliminar para reducir confusión al leer el archivo.

```dart
// ELIMINAR completamente este bloque (líneas ~55–100 aprox):
if (false) Container(
  padding: ...
  // ... todo este widget muerto
),
const SizedBox(height: 10),
if (false) Wrap(
  // ... también muerto
),
```

---

### 2.2 Extraer `_getIconForName` a una utilidad compartida

La función `_getIconForName(String name) → IconData` existe en **cuatro archivos**:
- `dashboard_tab.dart`
- `transactions_screen.dart`
- `reports_tab.dart`
- `settings_tab.dart`

**Solución:** Crear `lib/utils/icon_utils.dart`:

```dart
// lib/utils/icon_utils.dart
import 'package:flutter/material.dart';

IconData getIconForName(String name) {
  switch (name) {
    case 'home': return Icons.home_rounded;
    case 'credit_card': return Icons.credit_card_rounded;
    case 'school': return Icons.school_rounded;
    case 'person': return Icons.person_rounded;
    case 'phone_android': return Icons.phone_android_rounded;
    case 'bolt': return Icons.bolt_rounded;
    case 'water_drop': return Icons.water_drop_rounded;
    case 'shopping_cart': return Icons.shopping_cart_rounded;
    case 'storefront': return Icons.storefront_rounded;
    case 'local_gas_station': return Icons.local_gas_station_rounded;
    case 'two_wheeler': return Icons.two_wheeler_rounded;
    case 'restaurant': return Icons.restaurant_rounded;
    case 'bakery_dining': return Icons.bakery_dining_rounded;
    case 'directions_bus': return Icons.directions_bus_rounded;
    case 'credit_score': return Icons.credit_score_rounded;
    case 'savings': return Icons.savings_rounded;
    case 'payments': return Icons.payments_rounded;
    case 'swap_horiz': return Icons.swap_horiz_rounded;
    case 'directions_car': return Icons.directions_car_rounded;
    case 'receipt_long': return Icons.receipt_long_rounded;
    default: return Icons.category_rounded;
  }
}
```

Elimina ~90 líneas de código repetido.

---

### 2.3 Extraer `_isPerformanceTransaction` a una utilidad compartida

Esta función también está duplicada en `transactions_screen.dart` y `reports_tab.dart`. Mover a `lib/utils/transaction_utils.dart` junto con otras lógicas de filtrado que se reusan.

```dart
// lib/utils/transaction_utils.dart
bool isPerformanceTransaction(
    TransactionRecord tx, Map<String, Category> categoriesById) {
  final category = categoriesById[tx.categoryId];
  final icon = category?.icon ?? '';
  final note = tx.note.toLowerCase();
  return icon == 'local_gas_station' ||
      icon == 'bolt' ||
      icon == 'school' ||
      note.startsWith('carga ');
}
```

---

### 2.4 Corregir categorías con master hardcodeado incorrecto en `seed_service.dart`

La categoría `despensa` tiene `master: 'Alimentacion'` (sin tilde), mientras que el resto del sistema usa `'Alimentación'` (con tilde). Esto causa que no aparezca correctamente en los filtros por master.

```dart
// ANTES:
_cat('despensa', 'Despensa + Carne', ..., 'Alimentacion'),

// DESPUÉS:
_cat('despensa', 'Despensa + Carne', ..., 'Alimentación'),
```

Similarmente `transporte` usa `'directions_car'` como icono pero ese nombre no está en el switch de `getIconForName` — el switch tiene `directions_car` pero el ícono correcto en Material 3 es `directions_car_rounded`, y hay inconsistencias menores entre los iconos definidos en seed vs. los que el switch maneja.

---

### 2.5 Limpiar `FirestoreService` (el legacy)

`lib/services/firestore_service.dart` es una clase legacy que convive con `FirestoreDataService` en `firestore_providers.dart`. Solo tiene `saveUserIfNotExists`, `addTransaction` (no usada), y `getTransactions` (no usada). La función `saveUserIfNotExists` debería migrarse a `FirestoreDataService` y el archivo eliminado para evitar confusión sobre cuál servicio usar.

---

### 2.6 Reemplazar `print()` por `debugPrint()` en servicios

`firebase_auth_service.dart` usa `print()` en los catch blocks. En producción, `print()` puede filtrarse a logs externos. Reemplazar por `debugPrint()` que solo imprime en modo debug:

```dart
// ANTES:
print('Error en signInWithGoogle: $e');

// DESPUÉS:
debugPrint('Error en signInWithGoogle: $e');
```

---

## 3. Chat AI — Migración a Claude real

### 3.1 Estado actual

`ai_chat_tab.dart` tiene un sistema de respuestas hardcodeadas con `if/else` y matching de keywords. Reconoce palabras como "tarjeta", "ahorro", "rendimiento" y devuelve templates. No aprende, no puede responder preguntas compuestas, y no entiende contexto de conversación.

### 3.2 Arquitectura propuesta

El tab ya construye un `_AssistantSnapshot` excelente con toda la data financiera del usuario. La idea es usarlo como contexto del sistema para Claude.

**Flujo:**
1. Usuario escribe pregunta
2. App serializa `_AssistantSnapshot` como JSON/texto estructurado
3. Se envía a `api.anthropic.com/v1/messages` con ese contexto como system prompt
4. Claude responde en lenguaje natural con los datos reales del usuario

**Implementación:**

```dart
// lib/services/ai_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';
  // La API key NO debe estar en el cliente. 
  // Usar Firebase Functions o Cloud Run como proxy.
  static const _proxyUrl = 'https://tu-proxy.cloudfunctions.net/claude';

  Future<String> chat({
    required String userMessage,
    required String financialContext,
    required List<Map<String, String>> history,
  }) async {
    final messages = [
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    final response = await http.post(
      Uri.parse(_proxyUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'system': _buildSystemPrompt(financialContext),
        'messages': messages,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al contactar el asistente');
    }

    final data = jsonDecode(response.body);
    return data['content'][0]['text'] as String;
  }

  String _buildSystemPrompt(String context) => '''
Eres el asistente financiero personal de Cifra, una app de finanzas personales.
Hablas en español, eres directo y no usas jerga financiera innecesaria.
Respondes SOLO sobre los datos del usuario. Si no sabes algo con los datos 
disponibles, lo dices claramente en lugar de inventar.

DATOS FINANCIEROS DEL USUARIO:
$context
''';
}
```

**Proxy con Firebase Functions (para no exponer la API key):**

```javascript
// functions/index.js
const functions = require('firebase-functions');
const fetch = require('node-fetch');

exports.claude = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated');
  
  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': functions.config().anthropic.key,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1024,
      system: data.system,
      messages: data.messages,
    }),
  });
  return response.json();
});
```

**Serialización del snapshot para el contexto:**

```dart
String serializeSnapshot(_AssistantSnapshot s) => '''
PERIODO ACTIVO: ${s.activePeriodName} (${s.periodDateLabel})
INGRESOS: ${s.income.toStringAsFixed(2)}
EGRESOS: ${s.expense.toStringAsFixed(2)}
NETO: ${s.net.toStringAsFixed(2)}
TASA DE AHORRO: ${s.savingsRate.toStringAsFixed(1)}%
MOVIMIENTOS: ${s.transactionCount}
CATEGORIA DOMINANTE: ${s.topExpenseCategoryName} (${s.topExpenseCategoryAmount.toStringAsFixed(2)})
DEUDA EN TARJETAS: ${s.debtTotal.toStringAsFixed(2)}
UTILIZACION DE CREDITO: ${s.creditUtilization.toStringAsFixed(1)}%
CUOTAS MENSUALES FIJAS: ${s.monthlyInstallments.toStringAsFixed(2)}
CUENTA MAS PRESIONADA: ${s.mostPressedAccount}
RENDIMIENTOS TRACKED: ${s.performanceTrackedCount}
EFICIENCIA PROMEDIO: ${s.averageEfficiency.toStringAsFixed(1)} km/L
''';
```

> **Importante:** La API key de Anthropic **nunca** debe estar en el código del cliente Flutter. Siempre usar un proxy autenticado con Firebase Auth o similar.

---

## 4. Arquitectura de providers — Mejoras puntuales

### 4.1 Mover `MovementFilterKind` y `MovementSortOrder` a `models.dart`

Actualmente están en `models.dart` (bien hecho en la versión actual). Verificar que todos los imports apunten al modelo y no a definiciones locales en las pantallas — en versiones previas existían como enums privados en `transactions_screen.dart`.

---

### 4.2 Agregar `budgetComplianceProvider` derivado

El `BudgetTab` recalcula `_getBudgetStats` en cada rebuild. Extraerlo como provider derivado evita recalcular cuando el usuario navega entre tabs:

```dart
final budgetStatsProvider = Provider.family<List<BudgetStat>, String>((ref, periodId) {
  final categories = ref.watch(categoriesStreamProvider).value ?? [];
  final allTxs = ref.watch(allTransactionsStreamProvider).value ?? [];
  final periods = ref.watch(periodsStreamProvider).value ?? [];
  
  final period = periods.firstWhere((p) => p.id == periodId, 
      orElse: () => throw StateError('Period not found'));
  final periodTxs = allTxs.where((t) => t.periodId == periodId).toList();
  
  // ... lógica de cálculo
  return stats;
});
```

---

### 4.3 Evitar `ref.read(periodsStreamProvider).value` en `_onPressSave`

En `add_transaction_screen.dart`, `_onPressSave` hace `ref.read(periodsStreamProvider).value`. Si el stream aún no tiene datos (estado loading), retorna null y el guardado falla silenciosamente. Agregar validación explícita:

```dart
void _onPressSave() async {
  final periodsState = ref.read(periodsStreamProvider);
  if (periodsState.isLoading) {
    _showSnack('Cargando períodos, intenta de nuevo...');
    return;
  }
  final periods = periodsState.value ?? [];
  if (periods.isEmpty) {
    _showSnack('No hay períodos configurados.');
    return;
  }
  // ...
}
```

---

## 5. UX y producto

### 5.1 Gráfico de tendencia en Reportes

El tab de Reportes tiene solo un gráfico de barras por categoría. Falta la dimensión temporal: "¿cómo han evolucionado mis gastos mes a mes?" Esta es la pregunta más natural en una app de finanzas.

**Datos ya disponibles:** `allTransactionsStreamProvider` + `periodsStreamProvider`. Solo falta la visualización.

Estructura propuesta: un gráfico de líneas simple mostrando `income` y `expense` por período, ordenado cronológicamente. Con `fl_chart` o `syncfusion_flutter_charts` (ambos tienen versiones gratuitas).

```dart
// Cálculo del trend ya es directo:
final trendData = periods.map((p) {
  final txs = allTxs.where((t) => t.periodId == p.id).toList();
  return PeriodTrend(
    period: p,
    income: txs.where((t) => !t.isTransfer && t.type == TransactionType.income)
               .fold(0.0, (s, t) => s + t.amount),
    expense: txs.where((t) => !t.isTransfer && t.type == TransactionType.expense)
                .fold(0.0, (s, t) => s + t.amount),
  );
}).toList()..sort((a, b) => a.period.startDate.compareTo(b.period.startDate));
```

---

### 5.2 Notificaciones de vencimiento de tarjetas

`daysUntilPayment()` ya existe en el modelo `Account`. Falta conectarlo con notificaciones locales (`flutter_local_notifications`).

**Cuándo notificar:** Al abrir la app (o via background fetch), verificar si alguna tarjeta tiene `daysUntilPayment() <= 3`. Si es así, mostrar notificación local.

```dart
// lib/services/notification_service.dart
class NotificationService {
  Future<void> checkAndSchedulePaymentReminders(List<Account> accounts) async {
    for (final acc in accounts) {
      if (acc.type != AccountType.creditCard) continue;
      final days = acc.daysUntilPayment();
      if (days <= 3 && days >= 0) {
        await _showLocalNotification(
          title: '💳 Pago próximo: ${acc.name}',
          body: days == 0 
              ? '¡El pago de ${acc.name} vence hoy!'
              : 'El pago de ${acc.name} vence en $days días.',
        );
      }
    }
  }
}
```

---

### 5.3 Estado vacío en BudgetTab cuando no hay presupuestos definidos

Cuando un período no tiene ningún presupuesto configurado, el tab simplemente muestra vacío. Agregar un CTA claro:

```dart
if (budgetRows.isEmpty && displayPeriod.budgets.isEmpty)
  _EmptyBudgetState(
    onSetupBudget: () => setState(() => _isEditing = true),
  )
```

---

### 5.4 Selector de período en `AddTransactionScreen` — Bug potencial

`_onPressSave` busca el período correcto por fecha. Si la fecha cae exactamente en el boundary de dos períodos (el mismo día que empieza uno y termina otro), `firstWhere` tomará el primero que encuentre en la lista, que no necesariamente está ordenada. Agregar ordenamiento explícito:

```dart
// Ordenar períodos por fecha de inicio descendente antes de buscar
final sortedPeriods = [...periods]
  ..sort((a, b) => b.startDate.compareTo(a.startDate));

Period? targetPeriod;
try {
  targetPeriod = sortedPeriods.firstWhere(
    (p) => !_date.isBefore(p.startDate) && !_date.isAfter(p.endDate),
  );
} catch (_) {
  targetPeriod = null;
}
```

---

### 5.5 Mínimo de pago de tarjeta — Cálculo mejorable

En `accounts_tab.dart`, el mínimo se calcula como `currentAmount * 0.1` (10%). Los bancos guatemaltecos típicamente cobran entre 5% y 15% con un mínimo fijo. Agregar campo `minimumPaymentPercent` al modelo `Account` para que el usuario configure el porcentaje real de su banco, con 10% como default.

---

## 6. Seguridad

### 6.1 Reglas de Firestore

Verificar que las reglas de Firestore en la consola de Firebase solo permitan que cada usuario lea/escriba su propia subcolección `users/{uid}/*`. El patrón típico que falta en muchos proyectos:

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

Sin esta regla, cualquier usuario autenticado podría leer datos de otro si conoce su UID.

---

### 6.2 Sanitizar nota en transferencias automáticas

En `accounts_tab.dart`, la nota de transferencia incluye directamente `account.name` sin sanitizar:
```dart
note: 'Pago tarjeta ${account.name}',
```
Si el nombre de la cuenta contiene caracteres especiales o es muy largo, puede causar problemas en la UI. Agregar `trim()` y limitar longitud:

```dart
note: 'Pago tarjeta ${account.name.trim().substring(0, account.name.length.clamp(0, 30))}',
```

---

## 7. Roadmap priorizado

| Prioridad | Tarea | Esfuerzo | Impacto |
|-----------|-------|----------|---------|
| 🔴 Alta | Activar persistencia offline de Firestore | 5 min | Muy alto |
| 🔴 Alta | Centralizar `_computeBalances` en provider | 1h | Alto |
| 🔴 Alta | Debounce en `_persistFilters` | 30 min | Alto |
| 🔴 Alta | Migrar chat AI a Claude real via proxy | 1 día | Muy alto |
| 🟡 Media | Separar filtros de UI de preferences doc | 2h | Medio |
| 🟡 Media | Extraer `getIconForName` a utils | 30 min | Bajo (mantenibilidad) |
| 🟡 Media | Extraer `isPerformanceTransaction` a utils | 20 min | Bajo (mantenibilidad) |
| 🟡 Media | Eliminar código muerto (`if (false)`) | 10 min | Bajo (legibilidad) |
| 🟡 Media | Corregir master de categoría `despensa` | 5 min | Medio (bug silencioso) |
| 🟡 Media | Gráfico de tendencia temporal en Reportes | 4h | Alto |
| 🟢 Baja | Notificaciones locales de vencimiento | 3h | Alto |
| 🟢 Baja | Reglas de seguridad Firestore | 30 min | Alto (seguridad) |
| 🟢 Baja | Limitar stream a últimos 90 días | 2h | Medio |
| 🟢 Baja | `budgetStatsProvider` derivado | 1h | Bajo |
| 🟢 Baja | Campo `minimumPaymentPercent` en Account | 1h | Bajo |

---

## 8. Consideraciones multiplataforma

### 8.1 Persistencia offline y sincronización

La caché de Firestore es **por dispositivo**. Si el usuario tiene la app en Android y en iOS, cada dispositivo tiene su propia caché local. Cuando ambos están online, Firestore los mantiene sincronizados automáticamente. Cuando uno está offline, las escrituras se encolan y se sincronizan al reconectar. Esto es completamente transparente para la app.

**No hay riesgo de datos inconsistentes** porque:
- Todas las escrituras pasan por el servidor antes de considerarse confirmadas (a menos que uses `SetOptions(source: Source.cache)` explícitamente, lo cual no se hace aquí)
- Firestore usa timestamps del servidor para ordering, no del cliente
- Los streams de Riverpod reaccionan a cambios del servidor en tiempo real

### 8.2 `NavigationProvider` — Consideración de estado

El `navigationProvider` en `firestore_providers.dart` guarda el índice de navegación como estado global de Riverpod. Esto es correcto pero significa que si el usuario está en la tab de Cuentas y navega a otra pantalla y regresa, el estado se mantiene. Verificar que este comportamiento sea el deseado (probablemente sí lo es).

---

## 9. Deuda técnica menor (quick wins)

- **`ai_chat_tab.dart` — Tab removido del home_navigator:** El tab de AI fue reemplazado por `BudgetTab` en `home_navigator.dart` pero el archivo `ai_chat_tab.dart` sigue existiendo. Si ya no se usa, eliminar o restaurar según decisión de producto.

- **`settings_tab.dart` — Encoding de caracteres:** La versión anterior tenía `CategorÃ­as` y `AlimentaciÃ³n` (UTF-8 mal interpretado). La versión actual parece estar corregida. Verificar que el archivo esté guardado en UTF-8 sin BOM en el editor.

- **`FiltersCard` — margin en `TransactionsScreen`:** El widget `FiltersCard` en `transactions_screen.dart` no tiene margin horizontal (`EdgeInsets.symmetric(horizontal: 16)`) como sí tiene en `reports_tab.dart`. Agregar para consistencia visual.

- **`Period.copyWithId` — extension en `add_transaction_screen.dart`:** Esta extension está definida localmente en el archivo. Moverla al archivo del modelo o a un archivo de extensiones dedicado para que esté disponible en toda la app.

---

*Documento generado el 02/04/2026 basado en análisis estático del codebase de Cifra.*
