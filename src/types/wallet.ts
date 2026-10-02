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
  displayName: 'Francisco Estrada',
  defaultCurrency: 'GTQ',
  startDayOfMonth: 27,
  enableSplitPeriod: true,
  midMonthDay: 13,
};

export const INITIAL_ACCOUNTS_SEED: Omit<WalletAccount, 'userId' | 'createdAt' | 'updatedAt'>[] = [
  {
    id: 'acc_efectivo',
    name: 'Efectivo',
    type: 'cash',
    balance: 4990.9,
    currentBalance: 4990.9,
    currency: 'GTQ',
    colorHex: '#00DCF5',
    iconName: 'payments',
    subtitle: '+240,00 hoy · Saldo disponible',
  },
  {
    id: 'acc_bac',
    name: 'BAC Credomatic',
    type: 'credit_card',
    balance: -7807.7,
    currentBalance: -7807.7,
    currency: 'GTQ',
    colorHex: '#FF5252',
    iconName: 'credit_card',
    subtitle: 'Corte: 15 Oct · Tarjeta Crédito',
  },
  {
    id: 'acc_bi',
    name: 'Banco Industrial (BI)',
    type: 'bank',
    balance: -1611.11,
    currentBalance: -1611.11,
    currency: 'GTQ',
    colorHex: '#00E676',
    iconName: 'account_balance',
    subtitle: 'Monetaria ****4920',
  },
];

export const INITIAL_CATEGORIES_SEED: Omit<WalletCategory, 'userId' | 'createdAt' | 'updatedAt'>[] = [
  {
    id: 'cat_comida',
    name: 'Comida y Bebida',
    subtitle: 'Supermercados, cafeterías, delivery',
    iconName: 'utensils',
    colorHex: '#00E676',
    type: 'expense',
  },
  {
    id: 'cat_mercado',
    name: 'Supermercado',
    subtitle: 'Abarrotes y despensa mensual',
    iconName: 'shopping_cart',
    colorHex: '#FFB300',
    type: 'expense',
  },
  {
    id: 'cat_servicios',
    name: 'Servicios e Internet',
    subtitle: 'Luz, Agua, Fibra, Celular',
    iconName: 'wifi',
    colorHex: '#00DCF5',
    type: 'expense',
  },
  {
    id: 'cat_transporte',
    name: 'Transporte y Gasolina',
    subtitle: 'Combustible, peajes, parqueo',
    iconName: 'fuel',
    colorHex: '#FF5252',
    type: 'expense',
  },
  {
    id: 'cat_ocio',
    name: 'Entretenimiento',
    subtitle: 'Streaming, salidas de ocio, cine',
    iconName: 'film',
    colorHex: '#9C27B0',
    type: 'expense',
  },
  {
    id: 'cat_salud',
    name: 'Salud y Farmacia',
    subtitle: 'Medicamentos, consultas médicas',
    iconName: 'heart_pulse',
    colorHex: '#FF5252',
    type: 'expense',
  },
  {
    id: 'cat_salario',
    name: 'Salario y Nómina',
    subtitle: 'Depósito quincenal y bonificaciones',
    iconName: 'briefcase',
    colorHex: '#00E676',
    type: 'income',
  },
];

export const INITIAL_BUDGETS_SEED: Omit<WalletBudget, 'userId' | 'createdAt' | 'updatedAt'>[] = [
  {
    id: 'bud_supermercado',
    name: 'Supermercado',
    categoryId: 'cat_comida',
    limitAmount: 2000.0,
    spentAmount: 1400.0,
    currency: 'GTQ',
    period: 'period_2026_11',
    iconName: 'shopping_cart',
    colorHex: '#00DCF5',
  },
  {
    id: 'bud_gasolina',
    name: 'Gasolina & Peajes',
    categoryId: 'cat_transporte',
    limitAmount: 800.0,
    spentAmount: 200.0,
    currency: 'GTQ',
    period: 'period_2026_11',
    iconName: 'fuel',
    colorHex: '#00E676',
  },
  {
    id: 'bud_servicios',
    name: 'Servicios y Hogar',
    categoryId: 'cat_servicios',
    limitAmount: 2000.0,
    spentAmount: 1800.0,
    currency: 'GTQ',
    period: 'period_2026_11',
    iconName: 'wifi',
    colorHex: '#FF5252',
  },
];

export const INITIAL_TRANSACTIONS_SEED: Omit<WalletTransaction, 'userId' | 'createdAt' | 'updatedAt'>[] = [
  {
    id: 'tx_1',
    accountId: 'acc_bac',
    accountName: 'BAC Credomatic',
    categoryId: 'cat_mercado',
    categoryName: 'Supermercado',
    categoryIcon: 'shopping_cart',
    categoryColor: '#FFB300',
    type: 'expense',
    amount: 280.0,
    currency: 'GTQ',
    note: 'Supermercado La Torre · Abarrotes',
    dateIso: '2026-10-28T15:15:00.000Z',
    yearMonth: 'period_2026_11',
    periodId: 'period_2026_11',
  },
  {
    id: 'tx_2',
    accountId: 'acc_efectivo',
    accountName: 'Efectivo',
    categoryId: 'cat_comida',
    categoryName: 'Comida y Bebida',
    categoryIcon: 'utensils',
    categoryColor: '#00E676',
    type: 'expense',
    amount: 60.0,
    currency: 'GTQ',
    note: 'Café Barista · Desayuno',
    dateIso: '2026-10-28T08:45:00.000Z',
    yearMonth: 'period_2026_11',
    periodId: 'period_2026_11',
  },
  {
    id: 'tx_3',
    accountId: 'acc_efectivo',
    accountName: 'Efectivo',
    categoryId: 'cat_comida',
    categoryName: 'Comida y Bebida',
    categoryIcon: 'utensils',
    categoryColor: '#FF5252',
    type: 'expense',
    amount: 10.0,
    currency: 'GTQ',
    note: 'Gastos diarios · Comida casual',
    dateIso: '2026-10-27T19:00:00.000Z',
    yearMonth: 'period_2026_11',
    periodId: 'period_2026_11',
  },
  {
    id: 'tx_4',
    accountId: 'acc_bi',
    accountName: 'Banco Industrial (BI)',
    categoryId: 'cat_salario',
    categoryName: 'Salario y Nómina',
    categoryIcon: 'briefcase',
    categoryColor: '#00E676',
    type: 'income',
    amount: 8500.0,
    currency: 'GTQ',
    note: 'Depósito de nómina inicio de ciclo (27 Oct)',
    dateIso: '2026-10-27T09:15:00.000Z',
    yearMonth: 'period_2026_11',
    periodId: 'period_2026_11',
  },
  {
    id: 'tx_5',
    accountId: 'acc_efectivo',
    accountName: 'Efectivo',
    categoryId: 'cat_comida',
    categoryName: 'Comida y Bebida',
    categoryIcon: 'utensils',
    categoryColor: '#FF5252',
    type: 'expense',
    amount: 25.0,
    currency: 'GTQ',
    note: 'Compra de almuerzo · Restaurante San Martín',
    dateIso: '2026-11-02T13:21:00.000Z',
    yearMonth: 'period_2026_11',
    periodId: 'period_2026_11',
  },
  {
    id: 'tx_6',
    accountId: 'acc_efectivo',
    accountName: 'Efectivo',
    categoryId: 'cat_comida',
    categoryName: 'Comida y Bebida',
    categoryIcon: 'utensils',
    categoryColor: '#FF5252',
    type: 'expense',
    amount: 50.0,
    currency: 'GTQ',
    note: 'Compra de almuerzo ejecutiva · Pollo Campero',
    dateIso: '2026-11-14T13:11:00.000Z',
    yearMonth: 'period_2026_11',
    periodId: 'period_2026_11',
  },
  {
    id: 'tx_7',
    accountId: 'acc_bac',
    accountName: 'BAC Credomatic',
    categoryId: 'cat_transporte',
    categoryName: 'Transporte y Gasolina',
    categoryIcon: 'fuel',
    categoryColor: '#00DCF5',
    type: 'expense',
    amount: 200.0,
    currency: 'GTQ',
    note: 'Gasolina Shell Las Américas · V-Power',
    dateIso: '2026-11-15T08:40:00.000Z',
    yearMonth: 'period_2026_11',
    periodId: 'period_2026_11',
  },
  {
    id: 'tx_8',
    accountId: 'acc_efectivo',
    accountName: 'Efectivo',
    toAccountId: 'acc_bac',
    toAccountName: 'BAC Credomatic',
    categoryId: 'cat_servicios',
    categoryName: 'Servicios e Internet',
    categoryIcon: 'wifi',
    categoryColor: '#00DCF5',
    type: 'transfer',
    amount: 500.0,
    currency: 'GTQ',
    note: 'Transferencia abono a tarjeta BAC Credomatic',
    dateIso: '2026-11-16T16:20:00.000Z',
    yearMonth: 'period_2026_11',
    periodId: 'period_2026_11',
  },
];
