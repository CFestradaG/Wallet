export type CurrencyCode = 'GTQ' | 'USD' | 'EUR' | 'MXN';
export type AccountType = 'cash' | 'bank' | 'credit_card' | 'savings' | 'investment';
export type TransactionType = 'income' | 'expense' | 'transfer';

export type PeriodFilterMode =
  | 'fullPeriod'
  | 'firstHalf'
  | 'secondHalf'
  | 'custom';

export interface UserSettingsModel {
  userId: string;
  displayName: string;
  defaultCurrency: CurrencyCode;
  /** Día del mes en que inicia el nuevo período financiero (ej. 27) */
  startDayOfMonth: number;
  /** Habilita la división interna del período en dos partes (Inicio de mes / Quincena) */
  enableSplitPeriod: boolean;
  /** Día en que inicia la segunda fase o quincena (ej. 13) */
  midMonthDay: number;
  createdAt?: unknown;
  updatedAt?: unknown;
}

export type UserProfile = UserSettingsModel;

export interface WalletAccount {
  id: string;
  userId: string;
  name: string;
  type: AccountType;
  balance: number;
  currentBalance?: number;
  currency: CurrencyCode;
  colorHex: string;
  iconName: string;
  subtitle: string;
  createdAt?: unknown;
  updatedAt?: unknown;
}

export interface WalletCategory {
  id: string;
  userId: string;
  name: string;
  subtitle: string;
  iconName: string;
  colorHex: string;
  type: 'income' | 'expense';
  subcategories: string[];
  createdAt?: unknown;
  updatedAt?: unknown;
}

export interface WalletTransaction {
  id: string;
  userId: string;
  accountId: string;
  accountName: string;
  toAccountId?: string;
  toAccountName?: string;
  categoryId: string;
  categoryName: string;
  categoryIcon: string;
  categoryColor: string;
  subcategory?: string;
  type: TransactionType;
  amount: number;
  currency: CurrencyCode;
  note: string;
  dateIso: string;
  yearMonth: string;
  periodId?: string;
  createdAt?: unknown;
  updatedAt?: unknown;
}

export interface WalletBudget {
  id: string;
  userId: string;
  name: string;
  categoryId: string;
  limitAmount: number;
  spentAmount: number;
  currency: CurrencyCode;
  period: string;
  iconName: string;
  colorHex: string;
  createdAt?: unknown;
  updatedAt?: unknown;
}

export interface MonthlySummary {
  id: string;
  userId: string;
  yearMonth: string;
  periodId?: string;
  totalIncome: number;
  totalExpense: number;
  netCashFlow: number;
  savingsRate: number;
  currency: CurrencyCode;
  createdAt?: unknown;
  updatedAt?: unknown;
}

export const INITIAL_USER_SETTINGS: UserSettingsModel = {
  userId: 'demo',
  displayName: 'Mi Usuario',
  defaultCurrency: 'GTQ',
  startDayOfMonth: 27,
  enableSplitPeriod: true,
  midMonthDay: 13,
};

// Cuentas iniciales limpias con SALDO CERO (sin saldos ficticios)
export const INITIAL_ACCOUNTS_SEED: Omit<WalletAccount, 'userId' | 'createdAt' | 'updatedAt'>[] = [
  {
    id: 'acc_efectivo',
    name: 'Efectivo',
    type: 'cash',
    balance: 0.0,
    currentBalance: 0.0,
    currency: 'GTQ',
    colorHex: '#00DCF5',
    iconName: 'payments',
    subtitle: 'Billetera / Efectivo disponible',
  },
  {
    id: 'acc_banco',
    name: 'Cuenta Bancaria',
    type: 'bank',
    balance: 0.0,
    currentBalance: 0.0,
    currency: 'GTQ',
    colorHex: '#00E676',
    iconName: 'account_balance',
    subtitle: 'Cuenta monetaria o ahorros',
  },
];

// Categorías estándar con sus SUBCATEGORÍAS integradas (Gastos e Ingresos)
export const INITIAL_CATEGORIES_SEED: Omit<WalletCategory, 'userId' | 'createdAt' | 'updatedAt'>[] = [
  // --- GASTOS ---
  {
    id: 'cat_comida',
    name: 'Comida y Bebida',
    subtitle: 'Restaurantes, cafeterías y delivery',
    iconName: 'utensils',
    colorHex: '#00E676',
    type: 'expense',
    subcategories: ['Restaurantes', 'Cafeterías', 'Comida Rápida', 'Delivery / Pedidos', 'Almuerzo Trabajo'],
  },
  {
    id: 'cat_mercado',
    name: 'Supermercado',
    subtitle: 'Abarrotes y despensa del hogar',
    iconName: 'shopping_cart',
    colorHex: '#FFB300',
    type: 'expense',
    subcategories: ['Abarrotes y Despensa', 'Frutas y Verduras', 'Carnes y Embutidos', 'Limpieza y Hogar', 'Bebidas'],
  },
  {
    id: 'cat_servicios',
    name: 'Vivienda y Servicios',
    subtitle: 'Alquiler, Luz, Agua, Fibra, Gas',
    iconName: 'wifi',
    colorHex: '#00DCF5',
    type: 'expense',
    subcategories: ['Alquiler / Hipoteca', 'Electricidad', 'Internet / Fibra Óptica', 'Agua Potable', 'Gas Propano', 'Mantenimiento'],
  },
  {
    id: 'cat_transporte',
    name: 'Transporte y Gasolina',
    subtitle: 'Combustible, peajes, parqueo, taller',
    iconName: 'fuel',
    colorHex: '#FF5252',
    type: 'expense',
    subcategories: ['Gasolina / Combustible', 'Uber / Taxi / Indrive', 'Peajes (VAS/Palín)', 'Mantenimiento / Taller', 'Parqueos', 'Transporte Público'],
  },
  {
    id: 'cat_ocio',
    name: 'Entretenimiento y Ocio',
    subtitle: 'Streaming, cine, salidas, hobbies',
    iconName: 'film',
    colorHex: '#9C27B0',
    type: 'expense',
    subcategories: ['Streaming (Netflix/Spotify)', 'Cine y Eventos', 'Salidas y Fiestas', 'Videojuegos y Hobbies', 'Vacaciones'],
  },
  {
    id: 'cat_salud',
    name: 'Salud y Farmacia',
    subtitle: 'Medicamentos, consultas médicas',
    iconName: 'heart_pulse',
    colorHex: '#FF5252',
    type: 'expense',
    subcategories: ['Farmacia y Medicinas', 'Consultas Médicas', 'Laboratorios y Exámenes', 'Cuidado Personal y Óptica', 'Seguro Médico'],
  },
  {
    id: 'cat_educacion',
    name: 'Educación y Cursos',
    subtitle: 'Universidad, cursos y certificaciones',
    iconName: 'briefcase',
    colorHex: '#26A69A',
    type: 'expense',
    subcategories: ['Colegiatura / Universidad', 'Cursos y Certificaciones', 'Libros y Materiales', 'Plataformas Educativas'],
  },
  {
    id: 'cat_compras',
    name: 'Compras y Ropa',
    subtitle: 'Ropa, calzado, gadgets y hogar',
    iconName: 'shopping_cart',
    colorHex: '#EC407A',
    type: 'expense',
    subcategories: ['Ropa y Calzado', 'Electrónica / Gadgets', 'Accesorios', 'Hogar y Decoración'],
  },

  // --- INGRESOS ---
  {
    id: 'cat_salario',
    name: 'Salario y Nómina',
    subtitle: 'Sueldo quincenal, mensual y bonos',
    iconName: 'briefcase',
    colorHex: '#00E676',
    type: 'income',
    subcategories: ['Sueldo Quincenal', 'Sueldo Fin de Mes', 'Bono 14', 'Aguinaldo', 'Horas Extras'],
  },
  {
    id: 'cat_negocio',
    name: 'Negocio y Ventas',
    subtitle: 'Ventas, clientes y servicios independientes',
    iconName: 'shopping_cart',
    colorHex: '#00DCF5',
    type: 'income',
    subcategories: ['Venta de Productos', 'Servicios Prestados', 'Comisiones', 'Cobro de Facturas'],
  },
  {
    id: 'cat_inversiones',
    name: 'Inversiones y Rendimientos',
    subtitle: 'Dividendos, intereses y rentas',
    iconName: 'briefcase',
    colorHex: '#FFB300',
    type: 'income',
    subcategories: ['Dividendos', 'Intereses Bancarios', 'Cripto / Acciones', 'Alquileres Cobrados'],
  },
  {
    id: 'cat_otros_ingresos',
    name: 'Otros Ingresos',
    subtitle: 'Regalos, reembolsos y varios',
    iconName: 'heart_pulse',
    colorHex: '#AB47BC',
    type: 'income',
    subcategories: ['Regalos y Donaciones', 'Reembolsos', 'Premios y Sorteos', 'Préstamos Recibidos'],
  },
];

// Presupuestos y transacciones vacíos por defecto (CERO datos demo)
export const INITIAL_BUDGETS_SEED: Omit<WalletBudget, 'userId' | 'createdAt' | 'updatedAt'>[] = [];

export const INITIAL_TRANSACTIONS_SEED: Omit<WalletTransaction, 'userId' | 'createdAt' | 'updatedAt'>[] = [];
