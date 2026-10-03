# Auditoría Técnica y Matriz de Migración — Wallet

**Fecha de ejecución:** Octubre 2026  
**Repositorio:** `CFestradaG/Wallet`  
**Objetivo:** Inventario exhaustivo y clasificación técnica de las tres implementaciones del repositorio (`React Web`, `flutter_wallet_app`, y `temp_fintrack_compare/fintrack_gt2-main`) conforme a la **ETAPA 0** del plan maestro de arquitectura.

---

## 1. Inventario por Implementación

### 1.1 Fuente Funcional Principal: React Web (`/` y `/src`)
* **Framework y Entorno:** React 19 + TypeScript + Vite + Tailwind CSS.
* **Backend y Persistencia:** Firebase Authentication (Google Auth + Estado de sesión reactivo) + Cloud Firestore (`/users/{uid}/accounts`, `/transactions`, `/budgets`, `/categories`, `/summaries`).
* **Pantallas y Vistas activas (`activeTab` en `src/App.tsx`):**
  1. `panel`: Dashboard general con balance neto consolidado, gauges de liquidez/tasa de ahorro, desglose de cuentas bancarias y efectivo, proyección a fin de mes, y mini-gráficos.
  2. `analitica`: Flujo de caja diario dinámico (SVG responsivo con tooltips y fechas reales), desglose porcentual de gastos por categoría, indicadores de superávit y ratio de ahorro.
  3. `registros`: Historial completo de transacciones con barra unificada de filtros (período financiero, tipo de movimiento, cuenta, categoría, buscador con debounce y botón para limpiar filtros).
  4. `cuentas`: Gestión de cuentas (Efectivo, Banco, Ahorro, Inversión, Tarjetas de Crédito).
  5. `categorias`: Catálogo de categorías con soporte para subcategorías jerárquicas y badges de iconos.
  6. `presupuestos`: Configuración de límites presupuestarios mensuales por categoría con barra de progreso de consumo en tiempo real.
* **Componentes Principales:**
  - `src/components/NewTransactionModal.tsx`: Modal de registro de transacciones con calculadora aritmética integrada, selector de cuentas con indicador de saldo disponible, advertencia de saldo insuficiente, selector de categorías y subcategorías.
  - `src/components/FlutterArchitectureExplorer.tsx`: Explorador de arquitectura Clean Architecture para contrastar Dart/Flutter con TypeScript.
  - `src/components/MobilePreviewView.tsx`: Simulador móvil interactivo con mockup de smartphone para previsualizar la experiencia de usuario.
* **Lógica de Negocio y Utilidades:**
  - `src/utils/financialPeriodHelper.ts` (`FinancialPeriodHelper`): Motor de cálculo de períodos financieros catorcenales y quincenales (ej. ciclo del 27 al 26 del mes siguiente), división en dos mitades (primera y segunda quincena) y rangos personalizados.
* **Seguridad y Reglas (`firestore.rules`):**
  - Modelo de propiedad estricto por usuario (`request.auth.uid == userId`).
  - Validación de esquemas (`isValidAccount`, `isValidTransaction`, `isValidBudget`, `isValidCategory`, `isValidSummary`).
  - Transacciones atómicas de actualización de saldos (`runTransaction`) con protección contra saldos inconsistentes.

---

### 1.2 Implementación Secundaria: Flutter Clean Architecture (`/flutter_wallet_app`)
* **Framework:** Flutter (Dart) + Riverpod 2.x + GoRouter.
* **Estructura modular (`lib/features`):**
  - `features/accounts`: Modelo de cuentas `AccountModel` y repositorio `AccountRepository` con mapeo Firestore.
  - `features/transactions`: `TransactionModel`, `TransactionRepository`, y pantalla `AddTransactionScreen`.
  - `features/budgets`: `BudgetModel` con cálculo de límites y consumos.
  - `features/categories`: `CategoryModel` con soporte de iconos y colores.
  - `features/dashboard`: `DashboardScreen` y providers de estado `dashboard_providers.dart`.
  - `features/settings`: `UserSettingsModel` con preferencias de moneda y ciclo financiero.
  - `core/utils/financial_period_helper.dart`: Implementación nativa en Dart del cálculo de ciclos quincenales/catorcenales, idéntica a `FinancialPeriodHelper` en TS.
  - `core/widgets/financial_period_selector.dart`: Widget visual para seleccionar períodos en móvil.

---

### 1.3 Fuente Funcional de Referencia: FinTrack GT (`/temp_fintrack_compare/fintrack_gt2-main`)
* **Framework:** Flutter + Riverpod + Firestore.
* **Módulos y Pantallas destacadas:**
  - `lib/screens/tabs/dashboard_tab.dart`: Dashboard móvil nativo.
  - `lib/screens/tabs/accounts_tab.dart`: Gestión avanzada de cuentas.
  - `lib/screens/tabs/reports_tab.dart`: Reportes analíticos de ingresos y gastos.
  - `lib/screens/tabs/vehicles_tab.dart`: **Módulo de vehículos y combustible** (`Vehicle` y `FuelLog`) con cálculo de costo por kilómetro y litros consumidos.
  - `lib/models/models.dart`:
    * Soporte profundo para **Tarjetas de Crédito**: fecha de corte (`cutDay`), fecha máxima de pago (`paymentDay`), días de gracia (`graceDays`), límite de crédito (`creditLimit`), deuda actual (`currentDebt`) y porcentaje de pago mínimo (`minimumPaymentPercent`).
    * **Compras a cuotas fijas**: clase `Installment` con cuotas pagadas, cuotas restantes, fecha de vencimiento y cálculo de saldo pendiente.
    * Tags y métodos de pago (`PaymentMethod.card`, `PaymentMethod.cash`, `PaymentMethod.transfer`).

---

## 2. Matriz de Clasificación de Funcionalidades

| Funcionalidad / Módulo | React Web Actual | flutter_wallet_app | fintrack_gt2 (Referencia) | Acción Arquitectónica | Prioridad |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Autenticación (Firebase Auth + Sesión)** | Sí (Google + Persistencia) | Parcial / Riverpod | Sí (Email + AuthWrapper) | **RESCATAR** | CRÍTICA |
| **Reglas de Seguridad (`firestore.rules`)** | Sí (Reglas atómicas desplegadas) | N/A (Usa el mismo backend) | Sí (Reglas base) | **RESCATAR** | CRÍTICA |
| **Motor de Períodos Financieros (27-26 / Quincenas)** | Sí (`FinancialPeriodHelper.ts`) | Sí (`financial_period_helper.dart`) | Referencia básica | **RESCATAR** | CRÍTICA |
| **Transacciones Atómicas (`runTransaction` balances)** | Sí (Soporte completo en App.tsx) | En progreso (`transaction_repository`) | Parcial / Lógica duplicada | **RESCATAR** | CRÍTICA |
| **Validación de Saldo Insuficiente** | Sí (Modal bloquea monto > saldo) | Pendiente en UI | No valida en UI | **RESCATAR** | ALTA |
| **Calculadora en Nueva Transacción** | Sí (`evaluateExpression` integrado) | Teclado estándar | Teclado numérico simple | **REIMPLEMENTAR** | ALTA |
| **Sistema Unificado de Filtros** | Sí (Período, cuenta, cat, tipo, search) | Parcial | Sí (`filters_card.dart`) | **RESCATAR** | ALTA |
| **Gráfico Dinámico de Flujo de Caja Diario** | Sí (SVG adaptativo con tooltips) | Pendiente | Sí (Gráficos en reports_tab) | **REIMPLEMENTAR** | ALTA |
| **Cuentas Básicas (Efectivo, Banco, Ahorro)** | Sí (CRUD completo) | Sí (`AccountModel`) | Sí | **RESCATAR** | ALTA |
| **Tarjetas de Crédito (Corte, Pago, Deuda)** | Parcial (Campos base) | Parcial | Profundo (Corte, pago, disponible) | **REIMPLEMENTAR** | ALTA |
| **Compras a Cuotas (`InstallmentPlan`)** | No implementado en UI | No implementado | Sí (`Installment` en models.dart) | **REIMPLEMENTAR** | MEDIA |
| **Gestión de Categorías y Subcategorías** | Sí (CRUD + badges en UI) | Sí (`CategoryModel`) | Sí | **RESCATAR** | ALTA |
| **Presupuestos por Categoría y Período** | Sí (Límites, barras y cálculo) | Sí (`BudgetModel`) | Sí | **RESCATAR** | ALTA |
| **Módulo de Vehículos y Combustible** | No implementado | No implementado | Sí (`Vehicle`, `FuelLog`, `vehicles_tab`) | **REIMPLEMENTAR** | MEDIA |
| **Transacciones Recurrentes Programadas** | No implementado | No implementado | Referencia | **REIMPLEMENTAR** | MEDIA |
| **Tags de Transacciones (#familia, #trabajo)** | No implementado | No implementado | Sí (Array de tags) | **REIMPLEMENTAR** | MEDIA |
| **Exportación CSV / Excel** | Sí (`handleExportCSV`) | No | No | **RESCATAR** | BAJA |
| **Simulador de Arquitectura Web-Only** | Sí (`FlutterArchitectureExplorer`) | N/A | N/A | **DESCARTAR** (para móvil) | BAJA |
| **Mockup Frame de Teléfono Web-Only** | Sí (`MobilePreviewView`) | N/A | N/A | **DESCARTAR** (para móvil) | BAJA |

---

## 3. Identificación de Código Web-Only a no trasladar mecánicamente

1. **Manipulaciones directas del DOM y ventanas del navegador**:
   - `window.print()` (utilizado en la exportación rápida de reportes).
   - Generación de blobs y descarga simulada de archivos CSV mediante `document.createElement('a')`.
   - Modales dependientes de etiquetas HTML (`<div className="fixed inset-0 ...">`).
2. **Estilizado Tailwind CSS y utilidades de navegador**:
   - Clases puras de Tailwind (`bg-[#1C1B1B]`, `flex-col`, `gap-6`, `overflow-visible`).
   - Elementos `<svg>` directos de HTML con `<defs>`, `<linearGradient>`, `<rect>` y `<line>` que en un entorno móvil nativo requerirán una biblioteca de gráficos adecuada (ej. `react-native-svg` o `victory-native`).
3. **Componentes visuales de visualización y demo**:
   - `FlutterArchitectureExplorer.tsx`: Componente estrictamente educativo y de documentación para la interfaz web.
   - `MobilePreviewView.tsx`: Simulación del contorno de un iPhone para visualización dentro de un navegador de escritorio.

---

## 4. Conclusiones y Próximos Pasos (Hoja de Ruta)

* **Preservación total:** Se mantiene la integridad completa de ambas bases de código existentes (`src/` en React y `flutter_wallet_app/` en Flutter) sin modificaciones destructivas ni eliminaciones de archivos.
* **Base funcional lista:** Las mejoras críticas del núcleo financiero (cálculo de flujo de caja diario 100% dinámico, sistema unificado de filtros entre vistas, validación de saldos en transacciones y eliminación segura con modal) han sido consolidadas y verificadas en la aplicación.
* **Transición ordenada:** Toda la lógica de dominio (`FinancialPeriodHelper`, cálculo de balance atómico, validaciones y contratos) queda inventariada y lista para ser encapsulada en la capa de casos de uso y repositorios según las fases maestras del proyecto.
