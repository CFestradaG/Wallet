export type CurrencyCode = 'GTQ' | 'USD' | 'EUR' | 'MXN';
export type AccountType = 'cash' | 'bank' | 'credit_card' | 'savings' | 'investment';
export type TransactionType = 'income' | 'expense' | 'transfer';

export interface UserProfile {
  userId: string;
  displayName: string;
  defaultCurrency: CurrencyCode;
  createdAt?: unknown;
  updatedAt?: unknown;
}

export interface WalletAccount {
  id: string;
  userId: string;
  name: string;
  type: AccountType;
  balance: number;
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
  totalIncome: number;
  totalExpense: number;
  netCashFlow: number;
  savingsRate: number;
  currency: CurrencyCode;
  createdAt?: unknown;
  updatedAt?: unknown;
}

export const INITIAL_ACCOUNTS_SEED: Omit<WalletAccount, 'userId' | 'createdAt' | 'updatedAt'>[] = [
  {
    id: 'acc_efectivo',
    name: 'Efectivo',
    type: 'cash',
    balance: 4990.9,
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
    period: '2026_10',
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
    period: '2026_10',
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
    period: '2026_10',
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
    dateIso: '2026-10-02T15:15:00.000Z',
    yearMonth: '2026_10',
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
    dateIso: '2026-10-02T08:45:00.000Z',
    yearMonth: '2026_10',
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
    dateIso: '2026-10-01T19:00:00.000Z',
    yearMonth: '2026_10',
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
    note: 'Depósito de nómina quincenal',
    dateIso: '2026-10-01T09:15:00.000Z',
    yearMonth: '2026_10',
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
    dateIso: '2026-09-30T13:21:00.000Z',
    yearMonth: '2026_10',
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
    dateIso: '2026-09-30T13:11:00.000Z',
    yearMonth: '2026_10',
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
    dateIso: '2026-09-30T08:40:00.000Z',
    yearMonth: '2026_10',
  },
  {
    id: 'tx_8',
    accountId: 'acc_efectivo',
    accountName: 'Efectivo',
    categoryId: 'cat_salud',
    categoryName: 'Salud y Farmacia',
    categoryIcon: 'heart_pulse',
    categoryColor: '#FF5252',
    type: 'expense',
    amount: 150.0,
    currency: 'GTQ',
    note: 'Farmacia Galeno · Medicamentos',
    dateIso: '2026-09-30T16:20:00.000Z',
    yearMonth: '2026_10',
  },
];
