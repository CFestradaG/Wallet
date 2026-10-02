/**
 * Security Rules Verification Suite — Dirty Dozen Payload Tests
 * Verifies all 12 attack vectors defined in security_spec.md return PERMISSION_DENIED.
 */

export interface DirtyDozenTestCase {
  id: number;
  name: string;
  operation: 'get' | 'list' | 'create' | 'update' | 'delete';
  path: string;
  authUid: string | null;
  emailVerified: boolean;
  payload?: Record<string, unknown>;
  expectedResult: 'PERMISSION_DENIED';
}

export const DIRTY_DOZEN_TESTS: DirtyDozenTestCase[] = [
  {
    id: 1,
    name: 'Cross-Tenant Account Read',
    operation: 'get',
    path: '/users/user_B/accounts/acc_1',
    authUid: 'user_A',
    emailVerified: true,
    expectedResult: 'PERMISSION_DENIED',
  },
  {
    id: 2,
    name: 'Spoofed Owner Field on Account Create',
    operation: 'create',
    path: '/users/user_A/accounts/acc_1',
    authUid: 'user_A',
    emailVerified: true,
    payload: {
      userId: 'user_B',
      name: 'Efectivo',
      type: 'cash',
      balance: 4990.9,
      currency: 'GTQ',
      colorHex: '#00B4D8',
      iconName: 'payments',
      subtitle: 'Saldo disponible',
    },
    expectedResult: 'PERMISSION_DENIED',
  },
  {
    id: 3,
    name: 'Shadow Field Injection on Account Update',
    operation: 'update',
    path: '/users/user_A/accounts/acc_1',
    authUid: 'user_A',
    emailVerified: true,
    payload: {
      isAdmin: true,
      balance: 999999,
    },
    expectedResult: 'PERMISSION_DENIED',
  },
  {
    id: 4,
    name: 'Unverified Email Transaction Write',
    operation: 'create',
    path: '/users/user_A/transactions/tx_1',
    authUid: 'user_A',
    emailVerified: false,
    payload: {
      userId: 'user_A',
      amount: 150,
    },
    expectedResult: 'PERMISSION_DENIED',
  },
  {
    id: 5,
    name: 'Orphaned Subcollection Write Without User Doc',
    operation: 'create',
    path: '/users/non_existent_user/transactions/tx_1',
    authUid: 'non_existent_user',
    emailVerified: true,
    payload: {
      userId: 'non_existent_user',
      amount: 100,
    },
    expectedResult: 'PERMISSION_DENIED',
  },
  {
    id: 6,
    name: 'Negative Transaction Amount',
    operation: 'create',
    path: '/users/user_A/transactions/tx_1',
    authUid: 'user_A',
    emailVerified: true,
    payload: {
      userId: 'user_A',
      amount: -500,
    },
    expectedResult: 'PERMISSION_DENIED',
  },
  {
    id: 7,
    name: 'Forged Timestamp on Create',
    operation: 'create',
    path: '/users/user_A/budgets/b_1',
    authUid: 'user_A',
    emailVerified: true,
    payload: {
      userId: 'user_A',
      createdAt: '2020-01-01T00:00:00Z',
    },
    expectedResult: 'PERMISSION_DENIED',
  },
  {
    id: 8,
    name: 'Mutating Immutable createdAt on Update',
    operation: 'update',
    path: '/users/user_A/budgets/b_1',
    authUid: 'user_A',
    emailVerified: true,
    payload: {
      createdAt: '2026-10-02T00:00:00Z',
    },
    expectedResult: 'PERMISSION_DENIED',
  },
  {
    id: 9,
    name: 'Oversized String DoW Attack in Note',
    operation: 'create',
    path: '/users/user_A/transactions/tx_2',
    authUid: 'user_A',
    emailVerified: true,
    payload: {
      note: 'A'.repeat(5000),
    },
    expectedResult: 'PERMISSION_DENIED',
  },
  {
    id: 10,
    name: 'Invalid Currency Enum',
    operation: 'create',
    path: '/users/user_A/accounts/acc_2',
    authUid: 'user_A',
    emailVerified: true,
    payload: {
      currency: 'BTC',
    },
    expectedResult: 'PERMISSION_DENIED',
  },
  {
    id: 11,
    name: 'Malformed year_month Document ID',
    operation: 'create',
    path: '/users/user_A/summaries/october-2026',
    authUid: 'user_A',
    emailVerified: true,
    payload: {
      yearMonth: 'october-2026',
    },
    expectedResult: 'PERMISSION_DENIED',
  },
  {
    id: 12,
    name: 'Blanket Cross-Tenant List Query',
    operation: 'list',
    path: '/users/user_B/transactions',
    authUid: 'user_A',
    emailVerified: true,
    expectedResult: 'PERMISSION_DENIED',
  },
];
