import React, { useState, useEffect, useMemo } from 'react';
import {
  onAuthStateChanged,
  signInWithPopup,
  signOut,
  User,
} from 'firebase/auth';
import {
  collection,
  doc,
  setDoc,
  getDoc,
  getDocs,
  onSnapshot,
  query,
  where,
  writeBatch,
  runTransaction,
  serverTimestamp,
  deleteDoc,
  updateDoc,
} from 'firebase/firestore';
import {
  Wallet,
  Plus,
  CreditCard,
  Building2,
  Banknote,
  Calendar,
  Search,
  Download,
  FileSpreadsheet,
  TrendingDown,
  TrendingUp,
  Activity,
  Utensils,
  ShoppingCart,
  Fuel,
  Wifi,
  Film,
  HeartPulse,
  Briefcase,
  ArrowUpRight,
  ArrowDownLeft,
  ArrowLeftRight,
  Check,
  Lightbulb,
  Lock,
  LogOut,
  LogIn,
  Smartphone,
  Code2,
  Trash2,
  Edit3,
  Settings2,
  Eye,
  X,
  ChevronLeft,
  ChevronRight,
  Layers,
  Tag,
  FolderPlus,
} from 'lucide-react';

import {
  db,
  auth,
  googleProvider,
  handleFirestoreError,
  OperationType,
} from './firebase';
import {
  WalletAccount,
  WalletCategory,
  WalletTransaction,
  WalletBudget,
  MonthlySummary,
  UserSettingsModel,
  PeriodFilterMode,
  TransactionType,
  AccountType,
  INITIAL_USER_SETTINGS,
  INITIAL_ACCOUNTS_SEED,
  INITIAL_CATEGORIES_SEED,
  INITIAL_BUDGETS_SEED,
  INITIAL_TRANSACTIONS_SEED,
} from './types/wallet';
import {
  FinancialPeriodHelper,
  DateRangeValue,
} from './utils/financialPeriodHelper';
import { NewTransactionModal } from './components/NewTransactionModal';

type NavTab =
  | 'panel'
  | 'cuentas'
  | 'categorias'
  | 'registros'
  | 'analitica'
  | 'presupuestos';

export default function App() {
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [authReady, setAuthReady] = useState<boolean>(false);
  const [activeTab, setActiveTab] = useState<NavTab>('panel');

  // State backed by Cloud Firestore when logged in, or local interactive seed before login
  const [accounts, setAccounts] = useState<WalletAccount[]>(() =>
    INITIAL_ACCOUNTS_SEED.map((a) => ({ ...a, userId: 'demo' }))
  );
  const [categories, setCategories] = useState<WalletCategory[]>(() =>
    INITIAL_CATEGORIES_SEED.map((c) => ({ ...c, userId: 'demo' }))
  );
  const [budgets, setBudgets] = useState<WalletBudget[]>(() =>
    INITIAL_BUDGETS_SEED.map((b) => ({ ...b, userId: 'demo' }))
  );
  const [transactions, setTransactions] = useState<WalletTransaction[]>(() =>
    INITIAL_TRANSACTIONS_SEED.map((t) => ({ ...t, userId: 'demo' }))
  );
  const [userSettings, setUserSettings] = useState<UserSettingsModel>(
    INITIAL_USER_SETTINGS
  );
  const [summary, setSummary] = useState<MonthlySummary>({
    id: 'period_2026_11',
    userId: 'demo',
    yearMonth: 'period_2026_11',
    periodId: 'period_2026_11',
    totalIncome: 0.0,
    totalExpense: 0.0,
    netCashFlow: 0.0,
    savingsRate: 0.0,
    currency: 'GTQ',
  });

  // Panel widget cards customization
  const [panelWidgets, setPanelWidgets] = useState<{
    gauges: boolean;
    balanceTrend: boolean;
    expenseStructure: boolean;
    accounts: boolean;
    recentTransactions: boolean;
    activeBudgets: boolean;
  }>(() => {
    try {
      const saved = localStorage.getItem('wallet_panel_widgets');
      if (saved) return JSON.parse(saved);
    } catch {}
    return {
      gauges: true,
      balanceTrend: true,
      expenseStructure: true,
      accounts: true,
      recentTransactions: true,
      activeBudgets: true,
    };
  });
  const [isCustomizePanelOpen, setIsCustomizePanelOpen] = useState(false);

  const togglePanelWidget = (key: keyof typeof panelWidgets) => {
    setPanelWidgets((prev) => {
      const updated = { ...prev, [key]: !prev[key] };
      localStorage.setItem('wallet_panel_widgets', JSON.stringify(updated));
      return updated;
    });
  };

  // In-app deletion confirmation
  const [deleteConfirmTarget, setDeleteConfirmTarget] = useState<{
    type: 'category' | 'account' | 'budget';
    id: string;
    name: string;
  } | null>(null);

  // Unified Filter State (Used by both Registros and Analítica)
  const [filterPeriodPreset, setFilterPeriodPreset] = useState<
    'cycle' | 'firstHalf' | 'secondHalf' | 'all' | 'custom'
  >('cycle');
  const [filterCategory, setFilterCategory] = useState<string>('all');
  const [filterTxType, setFilterTxType] = useState<
    'all' | 'expense' | 'income' | 'transfer'
  >('all');

  // Dynamic Financial Period Filter State (Requerimiento 2)
  const [periodFilterMode, setPeriodFilterMode] =
    useState<PeriodFilterMode>('fullPeriod');
  // Reference date set to Oct 28, 2026 so with startDayOfMonth = 27 it demonstrates "2026-11 (27 Oct - 26 Nov)"
  const [referenceDate, setReferenceDate] = useState<Date>(
    () => new Date('2026-10-28T12:00:00.000Z')
  );
  const [customStartIso, setCustomStartIso] = useState<string>('2026-10-27');
  const [customEndIso, setCustomEndIso] = useState<string>('2026-11-26');
  const [isPeriodSettingsModalOpen, setIsPeriodSettingsModalOpen] =
    useState<boolean>(false);

  // Modals & UI Filters
  const [isCalcOpen, setIsCalcOpen] = useState<boolean>(false);
  const [calcInitialType, setCalcInitialType] =
    useState<TransactionType>('expense');
  const [editingTransaction, setEditingTransaction] =
    useState<WalletTransaction | null>(null);
  const [isAddAccountOpen, setIsAddAccountOpen] = useState<boolean>(false);
  const [isAddBudgetOpen, setIsAddBudgetOpen] = useState<boolean>(false);
  const [isLoginModalOpen, setIsLoginModalOpen] = useState<boolean>(false);

  const [selectedAccountFilter, setSelectedAccountFilter] =
    useState<string>('all');
  const [flowFilter, setFlowFilter] = useState<'gastos' | 'ingresos' | 'flujo'>(
    'gastos'
  );
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [statusBanner, setStatusBanner] = useState<string | null>(null);

  // New Account Form State
  const [newAccName, setNewAccName] = useState<string>('');
  const [newAccType, setNewAccType] = useState<AccountType>('bank');
  const [newAccBalance, setNewAccBalance] = useState<string>('0.00');
  const [newAccSubtitle, setNewAccSubtitle] = useState<string>(
    'Cuenta Monetaria GTQ'
  );

  // Edit Account Form State
  const [editingAccount, setEditingAccount] = useState<WalletAccount | null>(null);
  const [isEditAccountOpen, setIsEditAccountOpen] = useState<boolean>(false);
  const [editAccName, setEditAccName] = useState<string>('');
  const [editAccType, setEditAccType] = useState<AccountType>('bank');
  const [editAccBalance, setEditAccBalance] = useState<string>('0.00');
  const [editAccSubtitle, setEditAccSubtitle] = useState<string>('');

  // Category Management State
  const [isAddCategoryOpen, setIsAddCategoryOpen] = useState<boolean>(false);
  const [editingCategory, setEditingCategory] = useState<WalletCategory | null>(null);
  const [isEditCategoryOpen, setIsEditCategoryOpen] = useState<boolean>(false);
  const [catFormName, setCatFormName] = useState<string>('');
  const [catFormSubtitle, setCatFormSubtitle] = useState<string>('');
  const [catFormType, setCatFormType] = useState<'expense' | 'income'>('expense');
  const [catFormIcon, setCatFormIcon] = useState<string>('utensils');
  const [catFormColor, setCatFormColor] = useState<string>('#00E676');
  const [catFormSubcategories, setCatFormSubcategories] = useState<string[]>([]);
  const [catFormNewSubInput, setCatFormNewSubInput] = useState<string>('');
  const [catFilterTab, setCatFilterTab] = useState<'all' | 'expense' | 'income'>('all');

  // Budget Management State
  const [newBudgetName, setNewBudgetName] = useState<string>('');
  const [newBudgetLimit, setNewBudgetLimit] = useState<string>('1500.00');
  const [newBudgetCategory, setNewBudgetCategory] =
    useState<string>('cat_comida');
  const [newBudgetPeriod, setNewBudgetPeriod] = useState<string>('');
  const [editingBudget, setEditingBudget] = useState<WalletBudget | null>(null);
  const [isEditBudgetOpen, setIsEditBudgetOpen] = useState<boolean>(false);
  const [editBudgetName, setEditBudgetName] = useState<string>('');
  const [editBudgetLimit, setEditBudgetLimit] = useState<string>('1000.00');
  const [editBudgetCategory, setEditBudgetCategory] = useState<string>('cat_comida');
  const [editBudgetPeriod, setEditBudgetPeriod] = useState<string>('');

  const showToast = (msg: string) => {
    setStatusBanner(msg);
    setTimeout(() => setStatusBanner(null), 3500);
  };

  const isPermissionDeniedError = (error: unknown): boolean => {
    const msg = error instanceof Error ? error.message : String(error);
    return /Missing or insufficient permissions|PERMISSION_DENIED|permission/i.test(msg);
  };

  // 1. Listen to Firebase Auth State
  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (user) => {
      setCurrentUser(user);
      setAuthReady(true);
      if (user) {
        // Al iniciar sesión, el usuario real empieza completamente en CERO
        setTransactions([]);
        setBudgets([]);
        setSummary({
          id: 'period_current',
          userId: user.uid,
          yearMonth: 'period_current',
          periodId: 'period_current',
          totalIncome: 0,
          totalExpense: 0,
          netCashFlow: 0,
          savingsRate: 0,
          currency: 'GTQ',
        });
        await ensureUserSeededInFirestore(user);
      } else {
        // En modo demostración (sin sesión), mostrar CERO datos demo
        setAccounts(INITIAL_ACCOUNTS_SEED.map((a) => ({ ...a, userId: 'demo' })));
        setCategories(INITIAL_CATEGORIES_SEED.map((c) => ({ ...c, userId: 'demo' })));
        setBudgets([]);
        setTransactions([]);
        setSummary({
          id: 'period_2026_11',
          userId: 'demo',
          yearMonth: 'period_2026_11',
          periodId: 'period_2026_11',
          totalIncome: 0.0,
          totalExpense: 0.0,
          netCashFlow: 0.0,
          savingsRate: 0.0,
          currency: 'GTQ',
        });
      }
    });
    return () => unsub();
  }, []);

  // 2. Inicializar cuentas y categorías en Firestore para el nuevo usuario
  const ensureUserSeededInFirestore = async (user: User) => {
    const uid = user.uid;
    const userDocRef = doc(db, 'users', uid);
    try {
      const snap = await getDoc(userDocRef);
      if (!snap.exists()) {
        // Crear documento del usuario
        await setDoc(userDocRef, {
          userId: uid,
          displayName: (user.displayName || 'Mi Usuario').slice(0, 100),
          defaultCurrency: 'GTQ',
          startDayOfMonth: 27,
          enableSplitPeriod: true,
          midMonthDay: 13,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });

        // Crear cuentas iniciales con SALDO EN CERO (Q0.00)
        const batch1 = writeBatch(db);
        const STARTER_ACCOUNTS: Omit<WalletAccount, 'createdAt' | 'updatedAt'>[] = [
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
            userId: uid,
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
            userId: uid,
          },
        ];

        for (const acc of STARTER_ACCOUNTS) {
          batch1.set(doc(db, 'users', uid, 'accounts', acc.id), {
            ...acc,
            createdAt: serverTimestamp(),
            updatedAt: serverTimestamp(),
          });
        }

        // Sembrar categorías estándar con sus SUBCATEGORÍAS integradas
        for (const cat of INITIAL_CATEGORIES_SEED) {
          batch1.set(doc(db, 'users', uid, 'categories', cat.id), {
            ...cat,
            subcategories: cat.subcategories || [],
            userId: uid,
            createdAt: serverTimestamp(),
            updatedAt: serverTimestamp(),
          });
        }

        // Resumen inicial en cero
        batch1.set(doc(db, 'users', uid, 'summaries', 'period_2026_11'), {
          userId: uid,
          yearMonth: 'period_2026_11',
          periodId: 'period_2026_11',
          totalIncome: 0.0,
          totalExpense: 0.0,
          netCashFlow: 0.0,
          savingsRate: 0.0,
          currency: 'GTQ',
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });

        await batch1.commit();
        showToast('¡Bienvenido! Cuentas listas con saldo en Q0.00');
      } else {
        // Limpiar únicamente transacciones de prueba legadas si tuvieran el prefijo tx_seed_
        const txSnap = await getDocs(
          query(collection(db, 'users', uid, 'transactions'), where('userId', '==', uid))
        );
        const legacySeeds = txSnap.docs.filter((d) => d.id.startsWith('tx_seed_'));
        if (legacySeeds.length > 0) {
          const cleanBatch = writeBatch(db);
          for (const d of legacySeeds) {
            cleanBatch.delete(d.ref);
          }
          await cleanBatch.commit();
        }

        // Asegurar que las cuentas básicas existan en Firestore para este usuario
        const accSnap = await getDocs(
          query(collection(db, 'users', uid, 'accounts'), where('userId', '==', uid))
        );
        if (accSnap.empty) {
          const accBatch = writeBatch(db);
          const STARTER_ACCOUNTS = [
            {
              id: 'acc_efectivo',
              name: 'Efectivo',
              type: 'cash' as const,
              balance: 0.0,
              currentBalance: 0.0,
              currency: 'GTQ' as const,
              colorHex: '#00DCF5',
              iconName: 'payments',
              subtitle: 'Billetera / Efectivo disponible',
              userId: uid,
            },
            {
              id: 'acc_banco',
              name: 'Cuenta Bancaria',
              type: 'bank' as const,
              balance: 0.0,
              currentBalance: 0.0,
              currency: 'GTQ' as const,
              colorHex: '#00E676',
              iconName: 'account_balance',
              subtitle: 'Cuenta monetaria o ahorros',
              userId: uid,
            },
          ];
          for (const acc of STARTER_ACCOUNTS) {
            accBatch.set(doc(db, 'users', uid, 'accounts', acc.id), {
              ...acc,
              createdAt: serverTimestamp(),
              updatedAt: serverTimestamp(),
            });
          }
          await accBatch.commit();
        }

        // Verificar y sincronizar categorías genéricas estándar en Firestore para el perfil del usuario
        const catSnap = await getDocs(
          query(collection(db, 'users', uid, 'categories'), where('userId', '==', uid))
        );
        const existingCatIds = new Set(catSnap.docs.map((d) => d.id));
        const catBatch = writeBatch(db);
        let hasNewCatSeed = false;

        // Sembrar las categorías que falten (incluyendo las nuevas de Ingresos y Gastos)
        for (const cat of INITIAL_CATEGORIES_SEED) {
          if (!existingCatIds.has(cat.id)) {
            hasNewCatSeed = true;
            catBatch.set(doc(db, 'users', uid, 'categories', cat.id), {
              id: cat.id,
              userId: uid,
              name: cat.name,
              subtitle: cat.subtitle,
              iconName: cat.iconName,
              colorHex: cat.colorHex,
              type: cat.type,
              subcategories: cat.subcategories || [],
              createdAt: serverTimestamp(),
              updatedAt: serverTimestamp(),
            });
          }
        }

        // Si ya existían categorías sin subcategorías, completarlas
        for (const cDoc of catSnap.docs) {
          const cData = cDoc.data();
          if (!cData.subcategories || cData.subcategories.length === 0) {
            const seedCat = INITIAL_CATEGORIES_SEED.find((s) => s.id === cDoc.id || s.name === cData.name);
            if (seedCat && seedCat.subcategories) {
              hasNewCatSeed = true;
              catBatch.update(cDoc.ref, {
                subcategories: seedCat.subcategories,
                updatedAt: serverTimestamp(),
              });
            }
          }
        }

        if (hasNewCatSeed) {
          await catBatch.commit();
        }
      }
    } catch (error) {
      handleFirestoreError(error, OperationType.WRITE, `users/${uid}`);
    }
  };

  // 3. Real-time Firestore Listeners for Subcollections
  useEffect(() => {
    if (!authReady || !currentUser) return;
    const uid = currentUser.uid;

    const accountsQ = query(
      collection(db, 'users', uid, 'accounts'),
      where('userId', '==', uid)
    );
    const unsubAcc = onSnapshot(
      accountsQ,
      (snap) => {
        setAccounts(
          snap.docs.map(
            (d) => ({ id: d.id, ...d.data() } as WalletAccount)
          )
        );
      },
      (err) =>
        handleFirestoreError(
          err,
          OperationType.LIST,
          `users/${uid}/accounts`
        )
    );

    const categoriesQ = query(
      collection(db, 'users', uid, 'categories'),
      where('userId', '==', uid)
    );
    const unsubCat = onSnapshot(
      categoriesQ,
      (snap) => {
        setCategories(
          snap.docs.map(
            (d) => ({ id: d.id, ...d.data() } as WalletCategory)
          )
        );
      },
      (err) =>
        handleFirestoreError(
          err,
          OperationType.LIST,
          `users/${uid}/categories`
        )
    );

    const budgetsQ = query(
      collection(db, 'users', uid, 'budgets'),
      where('userId', '==', uid)
    );
    const unsubBud = onSnapshot(
      budgetsQ,
      (snap) => {
        setBudgets(
          snap.docs.map((d) => ({ id: d.id, ...d.data() } as WalletBudget))
        );
      },
      (err) =>
        handleFirestoreError(
          err,
          OperationType.LIST,
          `users/${uid}/budgets`
        )
    );

    const txQ = query(
      collection(db, 'users', uid, 'transactions'),
      where('userId', '==', uid)
    );
    const unsubTx = onSnapshot(
      txQ,
      (snap) => {
        const list = snap.docs.map(
          (d) => ({ id: d.id, ...d.data() } as WalletTransaction)
        );
        list.sort(
          (a, b) =>
            new Date(b.dateIso).getTime() - new Date(a.dateIso).getTime()
        );
        setTransactions(list);
      },
      (err) =>
        handleFirestoreError(
          err,
          OperationType.LIST,
          `users/${uid}/transactions`
        )
    );

    const userDocRef = doc(db, 'users', uid);
    const unsubUser = onSnapshot(
      userDocRef,
      (snap) => {
        if (snap.exists()) {
          const d = snap.data();
          setUserSettings({
            userId: uid,
            displayName: d.displayName || 'Francisco Estrada',
            defaultCurrency: d.defaultCurrency || 'GTQ',
            startDayOfMonth: Number(d.startDayOfMonth ?? 27),
            enableSplitPeriod: Boolean(d.enableSplitPeriod ?? true),
            midMonthDay: Number(d.midMonthDay ?? 13),
          });
        }
      },
      (err) =>
        handleFirestoreError(err, OperationType.GET, `users/${uid}`)
    );

    const activePeriodDocId = new FinancialPeriodHelper(
      userSettings
    ).getFirestorePeriodId(referenceDate);
    const summaryDocRef = doc(
      db,
      'users',
      uid,
      'summaries',
      activePeriodDocId
    );
    const unsubSum = onSnapshot(
      summaryDocRef,
      (snap) => {
        if (snap.exists()) {
          setSummary({
            id: snap.id,
            ...(snap.data() as Omit<MonthlySummary, 'id'>),
          });
        } else {
          setSummary({
            id: activePeriodDocId,
            userId: uid,
            yearMonth: activePeriodDocId,
            periodId: activePeriodDocId,
            totalIncome: 0,
            totalExpense: 0,
            netCashFlow: 0,
            savingsRate: 0,
            currency: 'GTQ',
          });
        }
      },
      (err) =>
        handleFirestoreError(
          err,
          OperationType.GET,
          `users/${uid}/summaries/${activePeriodDocId}`
        )
    );

    return () => {
      unsubUser();
      unsubAcc();
      unsubCat();
      unsubBud();
      unsubTx();
      unsubSum();
    };
  }, [authReady, currentUser, userSettings.startDayOfMonth, referenceDate]);

  // FinancialPeriodHelper Instance & Active Period Range (Requerimiento 2)
  const periodHelper = useMemo(
    () => new FinancialPeriodHelper(userSettings),
    [userSettings]
  );

  const fullPeriodRange = useMemo(
    () => periodHelper.getPeriodDateRange(referenceDate),
    [periodHelper, referenceDate]
  );
  const firstHalfRange = useMemo(
    () => periodHelper.getFirstHalfDateRange(referenceDate),
    [periodHelper, referenceDate]
  );
  const secondHalfRange = useMemo(
    () => periodHelper.getSecondHalfDateRange(referenceDate),
    [periodHelper, referenceDate]
  );
  const customRangeObj: DateRangeValue = useMemo(
    () => ({
      start: new Date(`${customStartIso}T00:00:00.000Z`),
      end: new Date(`${customEndIso}T23:59:59.999Z`),
    }),
    [customStartIso, customEndIso]
  );

  const activeDateRange = useMemo(
    () =>
      periodHelper.getRangeForFilterMode(
        periodFilterMode,
        referenceDate,
        customRangeObj
      ),
    [periodHelper, periodFilterMode, referenceDate, customRangeObj]
  );

  const activePeriodName = useMemo(
    () => periodHelper.getPeriodName(referenceDate),
    [periodHelper, referenceDate]
  );
  const activeFirestorePeriodId = useMemo(
    () => periodHelper.getFirestorePeriodId(referenceDate),
    [periodHelper, referenceDate]
  );
  const activeSubPeriodLabel = useMemo(
    () => periodHelper.getSubPeriod(referenceDate),
    [periodHelper, referenceDate]
  );

  // Computed Financial Metrics
  const totalNetBalance = useMemo(
    () =>
      accounts.reduce(
        (acc, a) => acc + Number(a.currentBalance ?? a.balance ?? 0),
        0
      ),
    [accounts]
  );

  const filteredTransactions = useMemo(() => {
    return transactions.filter((t) => {
      const matchesAcc =
        selectedAccountFilter === 'all' ||
        t.accountId === selectedAccountFilter ||
        t.toAccountId === selectedAccountFilter;
      const matchesCategory =
        filterCategory === 'all' || t.categoryId === filterCategory;
      const matchesType =
        filterTxType === 'all' || t.type === filterTxType;
      const matchesSearch =
        !searchTerm.trim() ||
        t.note.toLowerCase().includes(searchTerm.toLowerCase()) ||
        t.categoryName.toLowerCase().includes(searchTerm.toLowerCase()) ||
        t.accountName.toLowerCase().includes(searchTerm.toLowerCase()) ||
        Boolean(t.subcategory && t.subcategory.toLowerCase().includes(searchTerm.toLowerCase()));

      let matchesPeriod = true;
      const txDate = new Date(t.dateIso);
      if (filterPeriodPreset === 'cycle') {
        matchesPeriod = periodHelper.isDateInRange(txDate, fullPeriodRange);
      } else if (filterPeriodPreset === 'firstHalf') {
        matchesPeriod = periodHelper.isDateInRange(txDate, firstHalfRange);
      } else if (filterPeriodPreset === 'secondHalf') {
        matchesPeriod = periodHelper.isDateInRange(txDate, secondHalfRange);
      } else if (filterPeriodPreset === 'custom') {
        matchesPeriod = periodHelper.isDateInRange(txDate, customRangeObj);
      } else if (filterPeriodPreset === 'all') {
        matchesPeriod = true;
      }

      return matchesAcc && matchesCategory && matchesType && matchesSearch && matchesPeriod;
    });
  }, [
    transactions,
    selectedAccountFilter,
    filterCategory,
    filterTxType,
    searchTerm,
    filterPeriodPreset,
    periodHelper,
    fullPeriodRange,
    firstHalfRange,
    secondHalfRange,
    customRangeObj,
  ]);

  // Dynamic Financial Metrics computed from the filtered transactions
  const computedMetrics = useMemo(() => {
    let inc = 0;
    let exp = 0;
    for (const t of filteredTransactions) {
      if (t.type === 'income') inc += t.amount;
      if (t.type === 'expense') exp += t.amount;
    }
    const net = inc - exp;
    const savings = inc > 0 ? Number(((net / inc) * 100).toFixed(1)) : 0;
    return {
      totalIncome: inc,
      totalExpense: exp,
      netCashFlow: net,
      savingsRate: savings,
    };
  }, [filteredTransactions]);

  // Dynamic Expense Structure by Category (Zero Mock Data)
  const expenseBreakdown = useMemo(() => {
    const expenses = filteredTransactions.filter((t) => t.type === 'expense');
    const total = expenses.reduce((sum, t) => sum + t.amount, 0);
    const catMap = new Map<
      string,
      {
        id: string;
        name: string;
        icon: string;
        color: string;
        amount: number;
        count: number;
      }
    >();

    for (const tx of expenses) {
      const existing = catMap.get(tx.categoryId) || {
        id: tx.categoryId,
        name: tx.categoryName,
        icon: tx.categoryIcon,
        color: tx.categoryColor || '#00DCF5',
        amount: 0,
        count: 0,
      };
      existing.amount += tx.amount;
      existing.count += 1;
      catMap.set(tx.categoryId, existing);
    }

    const items = Array.from(catMap.values())
      .sort((a, b) => b.amount - a.amount)
      .map((item) => ({
        ...item,
        percentage:
          total > 0 ? Number(((item.amount / total) * 100).toFixed(1)) : 0,
      }));

    return { total, items };
  }, [filteredTransactions]);

  // Dynamic Daily Cash Flow Data from real transactions (Zero Mock Data)
  const dailyCashFlowData = useMemo(() => {
    const dayMap = new Map<
      string,
      { dayLabel: string; date: string; inc: number; exp: number }
    >();
    const sorted = [...filteredTransactions].sort((a, b) =>
      a.dateIso.localeCompare(b.dateIso)
    );
    for (const tx of sorted) {
      const dayKey = tx.dateIso.slice(0, 10);
      const dObj = new Date(tx.dateIso);
      const dayLabel = `${dObj.getDate().toString().padStart(2, '0')} ${
        [
          'Ene',
          'Feb',
          'Mar',
          'Abr',
          'May',
          'Jun',
          'Jul',
          'Ago',
          'Sep',
          'Oct',
          'Nov',
          'Dic',
        ][dObj.getMonth()]
      }`;
      const existing = dayMap.get(dayKey) || {
        dayLabel,
        date: dayKey,
        inc: 0,
        exp: 0,
      };
      if (tx.type === 'income') existing.inc += tx.amount;
      if (tx.type === 'expense') existing.exp += tx.amount;
      dayMap.set(dayKey, existing);
    }
    return Array.from(dayMap.values());
  }, [filteredTransactions]);

  // Handlers: Authentication
  const handleGoogleLogin = async () => {
    try {
      await signInWithPopup(auth, googleProvider);
      setIsLoginModalOpen(false);
      showToast('Sesión iniciada con Google y sincronizada con Firestore');
    } catch (err) {
      console.error('Error al iniciar sesión:', err);
      showToast('Inicio de sesión cancelado o ventana emergente bloqueada');
    }
  };

  const handleLogout = async () => {
    await signOut(auth);
    showToast('Sesión cerrada');
  };

  // Helper: Accumulate signed balance delta per accountId for atomic balance reconciliation
  const accumulateTxAccountDeltas = (
    deltasMap: Record<string, number>,
    tx: {
      type: TransactionType;
      amount: number;
      accountId: string;
      toAccountId?: string;
    },
    multiplier: 1 | -1
  ) => {
    const amt = Math.abs(tx.amount) * multiplier;
    if (tx.type === 'income') {
      deltasMap[tx.accountId] = (deltasMap[tx.accountId] || 0) + amt;
    } else if (tx.type === 'expense') {
      deltasMap[tx.accountId] = (deltasMap[tx.accountId] || 0) - amt;
    } else if (tx.type === 'transfer') {
      deltasMap[tx.accountId] = (deltasMap[tx.accountId] || 0) - amt;
      if (tx.toAccountId) {
        deltasMap[tx.toAccountId] = (deltasMap[tx.toAccountId] || 0) + amt;
      }
    }
  };

  // Handler: Save or Update Transaction (Requerimiento 1: Transacción Atómica en Firestore y Cuadre de Saldos)
  const handleSaveTransaction = async (data: {
    id?: string;
    type: TransactionType;
    amount: number;
    accountId: string;
    toAccountId?: string;
    categoryId: string;
    subcategory?: string;
    note: string;
    dateIso: string;
  }) => {
    const acc = accounts.find((a) => a.id === data.accountId) || accounts[0];
    const toAcc = data.toAccountId
      ? accounts.find((a) => a.id === data.toAccountId)
      : undefined;
    const cat =
      categories.find((c) => c.id === data.categoryId) || categories[0];

    const isEditing = Boolean(data.id);
    const originalTx = isEditing
      ? transactions.find((t) => t.id === data.id)
      : undefined;
    const txId = data.id || `tx_${Date.now()}`;

    const txDate = new Date(data.dateIso);
    const targetPeriodId = periodHelper.getFirestorePeriodId(txDate); // ej. "period_2026_11"

    // 1. Calculate net mathematical delta for every involved account
    const accountDeltas: Record<string, number> = {};
    if (originalTx) {
      // Revert original transaction impact first (-1)
      accumulateTxAccountDeltas(accountDeltas, originalTx, -1);
    }
    // Apply new/updated transaction impact (+1)
    accumulateTxAccountDeltas(
      accountDeltas,
      {
        type: data.type,
        amount: data.amount,
        accountId: acc.id,
        toAccountId: data.type === 'transfer' ? toAcc?.id : undefined,
      },
      1
    );

    const affectedAccountIds = Object.keys(accountDeltas).filter(
      (id) => Math.abs(accountDeltas[id]) >= 0.001
    );

    if (currentUser) {
      const uid = currentUser.uid;
      try {
        const txRef = doc(db, 'users', uid, 'transactions', txId);
        const sumRef = doc(db, 'users', uid, 'summaries', targetPeriodId);

        await runTransaction(db, async (firestoreTx) => {
          // FASE 1: Todas las lecturas atómicas primero
          const accSnaps: Record<string, Awaited<ReturnType<typeof firestoreTx.get>>> = {};
          for (const accId of affectedAccountIds) {
            accSnaps[accId] = await firestoreTx.get(
              doc(db, 'users', uid, 'accounts', accId)
            );
          }
          const sumSnap = await firestoreTx.get(sumRef);

          // FASE 2: Crear o actualizar el documento en /users/{uid}/transactions/{txId}
          const txPayload: Record<string, unknown> = {
            userId: uid,
            accountId: acc.id,
            accountName: acc.name.slice(0, 80),
            categoryId: cat.id,
            categoryName: cat.name.slice(0, 80),
            categoryIcon: cat.iconName.slice(0, 40),
            categoryColor: cat.colorHex.slice(0, 9),
            type: data.type,
            amount: Number(data.amount),
            currency: 'GTQ',
            note: data.note.slice(0, 200),
            dateIso: data.dateIso,
            yearMonth: targetPeriodId,
            periodId: targetPeriodId,
            updatedAt: serverTimestamp(),
          };
          if (data.subcategory) {
            txPayload.subcategory = data.subcategory.slice(0, 80);
          }
          if (data.type === 'transfer' && toAcc) {
            txPayload.toAccountId = toAcc.id;
            txPayload.toAccountName = toAcc.name.slice(0, 80);
          }

          if (isEditing && originalTx) {
            firestoreTx.update(txRef, txPayload);
          } else {
            txPayload.createdAt = serverTimestamp();
            firestoreTx.set(txRef, txPayload);
          }

          // FASE 3: Actualizar currentBalance y balance en cada cuenta afectada en el MISMO bloque atómico
          for (const accId of affectedAccountIds) {
            const snap = accSnaps[accId];
            const fallbackAcc = accounts.find((a) => a.id === accId);
            const currentBal = snap && snap.exists()
              ? Number(
                  (snap.data() as Record<string, unknown>).currentBalance ??
                    (snap.data() as Record<string, unknown>).balance ??
                    fallbackAcc?.balance ??
                    0
                )
              : Number(fallbackAcc?.balance ?? 0);
            const updatedBalance = Number(
              (currentBal + accountDeltas[accId]).toFixed(2)
            );

            if (snap && snap.exists()) {
              firestoreTx.update(doc(db, 'users', uid, 'accounts', accId), {
                currentBalance: updatedBalance,
                balance: updatedBalance,
                updatedAt: serverTimestamp(),
              });
            } else {
              firestoreTx.set(doc(db, 'users', uid, 'accounts', accId), {
                id: accId,
                userId: uid,
                name: fallbackAcc?.name || 'Cuenta',
                type: fallbackAcc?.type || 'cash',
                balance: updatedBalance,
                currentBalance: updatedBalance,
                currency: 'GTQ',
                colorHex: fallbackAcc?.colorHex || '#00DCF5',
                iconName: fallbackAcc?.iconName || 'payments',
                subtitle: fallbackAcc?.subtitle || 'Cuenta principal',
                createdAt: serverTimestamp(),
                updatedAt: serverTimestamp(),
              });
            }
          }

          // FASE 4: Actualizar o crear el resumen del período financiero en /summaries/{periodId}
          const oldInc =
            originalTx && originalTx.type === 'income' ? originalTx.amount : 0;
          const oldExp =
            originalTx && originalTx.type === 'expense' ? originalTx.amount : 0;
          const newInc = data.type === 'income' ? data.amount : 0;
          const newExp = data.type === 'expense' ? data.amount : 0;

          const prevInc = sumSnap.exists()
            ? Number(sumSnap.data().totalIncome ?? summary.totalIncome)
            : summary.totalIncome;
          const prevExp = sumSnap.exists()
            ? Number(sumSnap.data().totalExpense ?? summary.totalExpense)
            : summary.totalExpense;

          const totalInc = Math.max(0, Number((prevInc - oldInc + newInc).toFixed(2)));
          const totalExp = Math.max(0, Number((prevExp - oldExp + newExp).toFixed(2)));
          const netFlow = Number((totalInc - totalExp).toFixed(2));
          const savingsRate =
            totalInc > 0
              ? Number(((netFlow / totalInc) * 100).toFixed(1))
              : 0;

          if (sumSnap.exists()) {
            firestoreTx.update(sumRef, {
              yearMonth: targetPeriodId,
              periodId: targetPeriodId,
              totalIncome: totalInc,
              totalExpense: totalExp,
              netCashFlow: netFlow,
              savingsRate,
              currency: 'GTQ',
              updatedAt: serverTimestamp(),
            });
          } else {
            firestoreTx.set(sumRef, {
              userId: uid,
              yearMonth: targetPeriodId,
              periodId: targetPeriodId,
              totalIncome: totalInc,
              totalExpense: totalExp,
              netCashFlow: netFlow,
              savingsRate,
              currency: 'GTQ',
              createdAt: serverTimestamp(),
              updatedAt: serverTimestamp(),
            });
          }
        });

        showToast(
          isEditing
            ? `Transacción editada y saldos recuadrados en Firestore (${targetPeriodId})`
            : `Transacción atómica (${data.type.toUpperCase()}) registrada en ${targetPeriodId}`
        );
      } catch (error) {
        if (isPermissionDeniedError(error)) {
          const fallbackTx: WalletTransaction = {
            id: txId,
            userId: uid,
            accountId: acc.id,
            accountName: acc.name,
            toAccountId: data.type === 'transfer' ? toAcc?.id : undefined,
            toAccountName: data.type === 'transfer' ? toAcc?.name : undefined,
            categoryId: cat.id,
            categoryName: cat.name,
            categoryIcon: cat.iconName,
            categoryColor: cat.colorHex,
            subcategory: data.subcategory,
            type: data.type,
            amount: data.amount,
            currency: 'GTQ',
            note: data.note,
            dateIso: data.dateIso,
            yearMonth: targetPeriodId,
            periodId: targetPeriodId,
          };

          setTransactions((prev) =>
            isEditing
              ? prev.map((t) => (t.id === txId ? fallbackTx : t))
              : [fallbackTx, ...prev]
          );

          setAccounts((prev) =>
            prev.map((a) => {
              const delta = accountDeltas[a.id];
              if (!delta) return a;
              const baseBal = Number(a.currentBalance ?? a.balance ?? 0);
              const nextBal = Number((baseBal + delta).toFixed(2));
              return {
                ...a,
                balance: nextBal,
                currentBalance: nextBal,
              };
            })
          );

          setSummary((prev) => {
            const oldInc = originalTx && originalTx.type === 'income' ? originalTx.amount : 0;
            const oldExp = originalTx && originalTx.type === 'expense' ? originalTx.amount : 0;
            const newInc = data.type === 'income' ? data.amount : 0;
            const newExp = data.type === 'expense' ? data.amount : 0;
            const totalIncome = Math.max(0, Number((prev.totalIncome - oldInc + newInc).toFixed(2)));
            const totalExpense = Math.max(0, Number((prev.totalExpense - oldExp + newExp).toFixed(2)));
            const netCashFlow = Number((totalIncome - totalExpense).toFixed(2));
            return {
              ...prev,
              id: targetPeriodId,
              yearMonth: targetPeriodId,
              periodId: targetPeriodId,
              totalIncome,
              totalExpense,
              netCashFlow,
              savingsRate: totalIncome > 0 ? Number(((netCashFlow / totalIncome) * 100).toFixed(1)) : 0,
            };
          });

          showToast('Permisos de Firestore insuficientes; se guardó localmente en modo demo.');
          setEditingTransaction(null);
          return;
        }
        handleFirestoreError(
          error,
          OperationType.WRITE,
          `users/${uid}/transactions/${txId}`
        );
      }
    } else {
      // Local state atomic update in preview mode
      const updatedTxObj: WalletTransaction = {
        id: txId,
        userId: 'demo',
        accountId: acc.id,
        accountName: acc.name,
        toAccountId: data.type === 'transfer' ? toAcc?.id : undefined,
        toAccountName: data.type === 'transfer' ? toAcc?.name : undefined,
        categoryId: cat.id,
        categoryName: cat.name,
        categoryIcon: cat.iconName,
        categoryColor: cat.colorHex,
        subcategory: data.subcategory,
        type: data.type,
        amount: data.amount,
        currency: 'GTQ',
        note: data.note,
        dateIso: data.dateIso,
        yearMonth: targetPeriodId,
        periodId: targetPeriodId,
      };

      setTransactions((prev) =>
        isEditing
          ? prev.map((t) => (t.id === txId ? updatedTxObj : t))
          : [updatedTxObj, ...prev]
      );

      setAccounts((prev) =>
        prev.map((a) => {
          const delta = accountDeltas[a.id];
          if (!delta) return a;
          const baseBal = Number(a.currentBalance ?? a.balance ?? 0);
          const nextBal = Number((baseBal + delta).toFixed(2));
          return {
            ...a,
            balance: nextBal,
            currentBalance: nextBal,
          };
        })
      );

      setSummary((prev) => {
        const oldInc =
          originalTx && originalTx.type === 'income' ? originalTx.amount : 0;
        const oldExp =
          originalTx && originalTx.type === 'expense' ? originalTx.amount : 0;
        const newInc = data.type === 'income' ? data.amount : 0;
        const newExp = data.type === 'expense' ? data.amount : 0;

        const totalIncome = Math.max(
          0,
          Number((prev.totalIncome - oldInc + newInc).toFixed(2))
        );
        const totalExpense = Math.max(
          0,
          Number((prev.totalExpense - oldExp + newExp).toFixed(2))
        );
        const netCashFlow = Number((totalIncome - totalExpense).toFixed(2));
        return {
          ...prev,
          id: targetPeriodId,
          yearMonth: targetPeriodId,
          periodId: targetPeriodId,
          totalIncome,
          totalExpense,
          netCashFlow,
          savingsRate:
            totalIncome > 0
              ? Number(((netCashFlow / totalIncome) * 100).toFixed(1))
              : 0,
        };
      });

      showToast(
        isEditing
          ? `Transacción editada y saldos cuadrados (${targetPeriodId})`
          : `Movimiento (${data.type.toUpperCase()}) cuadrado en saldos y período ${targetPeriodId}`
      );
    }
    setEditingTransaction(null);
  };

  // Handler: Quick Card Transfer (Abonar a tarjeta BAC en una sola operación atómica)
  const handleQuickPayBacCard = async () => {
    const cashAcc = accounts.find((a) => a.id === 'acc_efectivo') || accounts[0];
    const bacAcc = accounts.find((a) => a.id === 'acc_bac') || accounts[1];
    if (!cashAcc || !bacAcc) return;

    const paymentAmount = 500.0;
    await handleSaveTransaction({
      type: 'transfer',
      amount: paymentAmount,
      accountId: cashAcc.id,
      toAccountId: bacAcc.id,
      categoryId: categories[0]?.id || 'cat_servicios',
      note: `Transferencia abono a tarjeta ${bacAcc.name} desde ${cashAcc.name}`,
      dateIso: referenceDate.toISOString(),
    });
  };

  // --- ACCOUNT MANAGEMENT ---
  const handleCreateAccount = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newAccName.trim()) return;
    const accId = `acc_${Date.now()}`;
    const bal = parseFloat(newAccBalance) || 0;
    const colorMap: Record<AccountType, string> = {
      cash: '#00DCF5',
      bank: '#00E676',
      credit_card: '#FF5252',
      savings: '#75FF9E',
      investment: '#9C27B0',
    };
    const iconMap: Record<AccountType, string> = {
      cash: 'payments',
      bank: 'account_balance',
      credit_card: 'credit_card',
      savings: 'account_balance',
      investment: 'payments',
    };

    if (currentUser) {
      const uid = currentUser.uid;
      try {
        await setDoc(doc(db, 'users', uid, 'accounts', accId), {
          userId: uid,
          name: newAccName.trim().slice(0, 80),
          type: newAccType,
          balance: bal,
          currentBalance: bal,
          currency: 'GTQ',
          colorHex: colorMap[newAccType],
          iconName: iconMap[newAccType],
          subtitle: newAccSubtitle.trim().slice(0, 100),
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });
        showToast(`Cuenta "${newAccName}" creada en Cloud Firestore`);
      } catch (err) {
        if (isPermissionDeniedError(err)) {
          setAccounts((prev) => [
            ...prev,
            {
              id: accId,
              userId: uid,
              name: newAccName.trim(),
              type: newAccType,
              balance: bal,
              currentBalance: bal,
              currency: 'GTQ',
              colorHex: colorMap[newAccType],
              iconName: iconMap[newAccType],
              subtitle: newAccSubtitle.trim(),
            },
          ]);
          showToast('Permisos de Firestore insuficientes; cuenta creada localmente en modo demo.');
          setNewAccName('');
          setIsAddAccountOpen(false);
          return;
        }
        handleFirestoreError(
          err,
          OperationType.CREATE,
          `users/${uid}/accounts/${accId}`
        );
      }
    } else {
      setAccounts((prev) => [
        ...prev,
        {
          id: accId,
          userId: 'demo',
          name: newAccName.trim(),
          type: newAccType,
          balance: bal,
          currentBalance: bal,
          currency: 'GTQ',
          colorHex: colorMap[newAccType],
          iconName: iconMap[newAccType],
          subtitle: newAccSubtitle.trim(),
        },
      ]);
      showToast(`Cuenta "${newAccName}" agregada`);
    }
    setNewAccName('');
    setIsAddAccountOpen(false);
  };

  const handleOpenEditAccount = (acc: WalletAccount) => {
    setEditingAccount(acc);
    setEditAccName(acc.name);
    setEditAccType(acc.type);
    setEditAccBalance(Number(acc.currentBalance ?? acc.balance ?? 0).toFixed(2));
    setEditAccSubtitle(acc.subtitle || '');
    setIsEditAccountOpen(true);
  };

  const handleUpdateAccount = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingAccount || !editAccName.trim()) return;
    const newBal = parseFloat(editAccBalance) || 0;
    const colorMap: Record<AccountType, string> = {
      cash: '#00DCF5',
      bank: '#00E676',
      credit_card: '#FF5252',
      savings: '#75FF9E',
      investment: '#9C27B0',
    };
    const iconMap: Record<AccountType, string> = {
      cash: 'payments',
      bank: 'account_balance',
      credit_card: 'credit_card',
      savings: 'account_balance',
      investment: 'payments',
    };

    if (currentUser) {
      const uid = currentUser.uid;
      try {
        await updateDoc(doc(db, 'users', uid, 'accounts', editingAccount.id), {
          name: editAccName.trim().slice(0, 80),
          type: editAccType,
          balance: newBal,
          currentBalance: newBal,
          colorHex: colorMap[editAccType],
          iconName: iconMap[editAccType],
          subtitle: editAccSubtitle.trim().slice(0, 100),
          updatedAt: serverTimestamp(),
        });
        showToast(`Cuenta "${editAccName}" actualizada`);
      } catch (err) {
        handleFirestoreError(
          err,
          OperationType.UPDATE,
          `users/${uid}/accounts/${editingAccount.id}`
        );
      }
    } else {
      setAccounts((prev) =>
        prev.map((a) =>
          a.id === editingAccount.id
            ? {
                ...a,
                name: editAccName.trim(),
                type: editAccType,
                balance: newBal,
                currentBalance: newBal,
                colorHex: colorMap[editAccType],
                iconName: iconMap[editAccType],
                subtitle: editAccSubtitle.trim(),
              }
            : a
        )
      );
      showToast(`Cuenta "${editAccName}" actualizada`);
    }
    setIsEditAccountOpen(false);
    setEditingAccount(null);
  };

  // --- CATEGORY & SUBCATEGORY MANAGEMENT ---
  const handleOpenAddCategory = () => {
    setCatFormName('');
    setCatFormSubtitle('');
    setCatFormType('expense');
    setCatFormIcon('utensils');
    setCatFormColor('#00E676');
    setCatFormSubcategories([]);
    setCatFormNewSubInput('');
    setIsAddCategoryOpen(true);
  };

  const handleOpenEditCategory = (cat: WalletCategory) => {
    setEditingCategory(cat);
    setCatFormName(cat.name);
    setCatFormSubtitle(cat.subtitle || '');
    setCatFormType(cat.type);
    setCatFormIcon(cat.iconName);
    setCatFormColor(cat.colorHex);
    setCatFormSubcategories([...(cat.subcategories || [])]);
    setCatFormNewSubInput('');
    setIsEditCategoryOpen(true);
  };

  const handleAddSubcategoryTag = () => {
    const trimmed = catFormNewSubInput.trim();
    if (!trimmed || catFormSubcategories.includes(trimmed)) return;
    setCatFormSubcategories((prev) => [...prev, trimmed]);
    setCatFormNewSubInput('');
  };

  const handleRemoveSubcategoryTag = (subToRemove: string) => {
    setCatFormSubcategories((prev) => prev.filter((s) => s !== subToRemove));
  };

  const handleCreateCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!catFormName.trim()) return;
    const catId = `cat_${Date.now()}`;
    const newCatData: Omit<WalletCategory, 'createdAt' | 'updatedAt'> = {
      id: catId,
      userId: currentUser?.uid || 'demo',
      name: catFormName.trim().slice(0, 60),
      subtitle: catFormSubtitle.trim().slice(0, 120),
      type: catFormType,
      iconName: catFormIcon,
      colorHex: catFormColor,
      subcategories: catFormSubcategories,
    };

    if (currentUser) {
      const uid = currentUser.uid;
      try {
        await setDoc(doc(db, 'users', uid, 'categories', catId), {
          ...newCatData,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });
        showToast(
          `Categoría "${newCatData.name}" creada con ${newCatData.subcategories.length} subcategorías`
        );
      } catch (err) {
        if (isPermissionDeniedError(err)) {
          setCategories((prev) => [...prev, { ...newCatData, userId: uid } as WalletCategory]);
          showToast('Permisos de Firestore insuficientes; categoría creada localmente.');
          setIsAddCategoryOpen(false);
          return;
        }
        handleFirestoreError(
          err,
          OperationType.CREATE,
          `users/${uid}/categories/${catId}`
        );
      }
    } else {
      setCategories((prev) => [...prev, newCatData as WalletCategory]);
      showToast(`Categoría "${newCatData.name}" agregada`);
    }
    setIsAddCategoryOpen(false);
  };

  const handleUpdateCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingCategory || !catFormName.trim()) return;

    if (currentUser) {
      const uid = currentUser.uid;
      try {
        await updateDoc(doc(db, 'users', uid, 'categories', editingCategory.id), {
          name: catFormName.trim().slice(0, 60),
          subtitle: catFormSubtitle.trim().slice(0, 120),
          type: catFormType,
          iconName: catFormIcon,
          colorHex: catFormColor,
          subcategories: catFormSubcategories,
          updatedAt: serverTimestamp(),
        });
        showToast(`Categoría "${catFormName}" actualizada`);
      } catch (err) {
        handleFirestoreError(
          err,
          OperationType.UPDATE,
          `users/${uid}/categories/${editingCategory.id}`
        );
      }
    } else {
      setCategories((prev) =>
        prev.map((c) =>
          c.id === editingCategory.id
            ? {
                ...c,
                name: catFormName.trim(),
                subtitle: catFormSubtitle.trim(),
                type: catFormType,
                iconName: catFormIcon,
                colorHex: catFormColor,
                subcategories: catFormSubcategories,
              }
            : c
        )
      );
      showToast(`Categoría "${catFormName}" actualizada`);
    }
    setIsEditCategoryOpen(false);
    setEditingCategory(null);
  };

  const handleDeleteCategory = (cat: WalletCategory) => {
    setDeleteConfirmTarget({
      type: 'category',
      id: cat.id,
      name: cat.name,
    });
  };

  const handleDeleteTarget = async () => {
    if (!deleteConfirmTarget) return;
    const { type, id, name } = deleteConfirmTarget;

    if (currentUser) {
      const uid = currentUser.uid;
      try {
        if (type === 'category') {
          await deleteDoc(doc(db, 'users', uid, 'categories', id));
        } else if (type === 'account') {
          await deleteDoc(doc(db, 'users', uid, 'accounts', id));
        } else if (type === 'budget') {
          await deleteDoc(doc(db, 'users', uid, 'budgets', id));
        }
        showToast(`"${name}" eliminado.`);
      } catch (err) {
        if (isPermissionDeniedError(err)) {
          if (type === 'category') {
            setCategories((prev) => prev.filter((cat) => cat.id !== id));
          } else if (type === 'account') {
            setAccounts((prev) => prev.filter((account) => account.id !== id));
          } else if (type === 'budget') {
            setBudgets((prev) => prev.filter((budget) => budget.id !== id));
          }
          showToast('Permisos de Firestore insuficientes; elemento eliminado localmente.');
          setDeleteConfirmTarget(null);
          return;
        }
        handleFirestoreError(
          err,
          OperationType.DELETE,
          type === 'category'
            ? `users/${uid}/categories/${id}`
            : type === 'account'
            ? `users/${uid}/accounts/${id}`
            : `users/${uid}/budgets/${id}`
        );
      }
    } else {
      if (type === 'category') {
        setCategories((prev) => prev.filter((cat) => cat.id !== id));
      } else if (type === 'account') {
        setAccounts((prev) => prev.filter((account) => account.id !== id));
      } else if (type === 'budget') {
        setBudgets((prev) => prev.filter((budget) => budget.id !== id));
      }
      showToast(`"${name}" eliminado.`);
    }

    setDeleteConfirmTarget(null);
  };

  const handleQuickAddSubcategoryToCategory = async (
    cat: WalletCategory,
    newSubName: string
  ) => {
    const trimmed = newSubName.trim();
    if (!trimmed) return;
    const currentSubs = cat.subcategories || [];
    if (currentSubs.includes(trimmed)) return;
    const updatedSubs = [...currentSubs, trimmed];

    if (currentUser) {
      const uid = currentUser.uid;
      try {
        await updateDoc(doc(db, 'users', uid, 'categories', cat.id), {
          subcategories: updatedSubs,
          updatedAt: serverTimestamp(),
        });
        showToast(`Subcategoría "${trimmed}" añadida a ${cat.name}`);
      } catch (err) {
        handleFirestoreError(
          err,
          OperationType.UPDATE,
          `users/${uid}/categories/${cat.id}`
        );
      }
    } else {
      setCategories((prev) =>
        prev.map((c) =>
          c.id === cat.id ? { ...c, subcategories: updatedSubs } : c
        )
      );
      showToast(`Subcategoría "${trimmed}" añadida a ${cat.name}`);
    }
  };

  const handleRestoreDefaultCategories = async () => {
    if (!currentUser) {
      setCategories(INITIAL_CATEGORIES_SEED.map((c) => ({ ...c, userId: 'demo' })));
      showToast('Categorías predeterminadas restauradas en memoria');
      return;
    }
    const uid = currentUser.uid;
    const catBatch = writeBatch(db);
    for (const cat of INITIAL_CATEGORIES_SEED) {
      catBatch.set(doc(db, 'users', uid, 'categories', cat.id), {
        id: cat.id,
        userId: uid,
        name: cat.name,
        subtitle: cat.subtitle,
        iconName: cat.iconName,
        colorHex: cat.colorHex,
        type: cat.type,
        subcategories: cat.subcategories || [],
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    }
    try {
      await catBatch.commit();
      showToast('Categorías y subcategorías genéricas estándar restauradas en tu perfil');
    } catch (err) {
      handleFirestoreError(err, OperationType.WRITE, `users/${uid}/categories`);
    }
  };

  // --- BUDGET MANAGEMENT ---
  const handleCreateBudget = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newBudgetName.trim()) return;
    const budId = `bud_${Date.now()}`;
    const limit = Math.max(1, parseFloat(newBudgetLimit) || 1000);
    const cat =
      categories.find((c) => c.id === newBudgetCategory) || categories[0];
    const budgetPeriod = newBudgetPeriod || activeFirestorePeriodId;

    if (currentUser) {
      const uid = currentUser.uid;
      try {
        await setDoc(doc(db, 'users', uid, 'budgets', budId), {
          userId: uid,
          name: newBudgetName.trim().slice(0, 80),
          categoryId: cat.id,
          limitAmount: limit,
          spentAmount: 0,
          currency: 'GTQ',
          period: budgetPeriod,
          iconName: cat.iconName,
          colorHex: cat.colorHex,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });
        showToast(`Presupuesto "${newBudgetName}" guardado en Firestore (${budgetPeriod})`);
      } catch (err) {
        if (isPermissionDeniedError(err)) {
          setBudgets((prev) => [
            ...prev,
            {
              id: budId,
              userId: uid,
              name: newBudgetName.trim(),
              categoryId: cat.id,
              limitAmount: limit,
              spentAmount: 0,
              currency: 'GTQ',
              period: budgetPeriod,
              iconName: cat.iconName,
              colorHex: cat.colorHex,
            },
          ]);
          showToast('Permisos de Firestore insuficientes; presupuesto creado localmente.');
          setNewBudgetName('');
          setIsAddBudgetOpen(false);
          return;
        }
        handleFirestoreError(
          err,
          OperationType.CREATE,
          `users/${uid}/budgets/${budId}`
        );
      }
    } else {
      setBudgets((prev) => [
        ...prev,
        {
          id: budId,
          userId: 'demo',
          name: newBudgetName.trim(),
          categoryId: cat.id,
          limitAmount: limit,
          spentAmount: 0,
          currency: 'GTQ',
          period: budgetPeriod,
          iconName: cat.iconName,
          colorHex: cat.colorHex,
        },
      ]);
      showToast(`Presupuesto "${newBudgetName}" creado`);
    }
    setNewBudgetName('');
    setIsAddBudgetOpen(false);
  };

  const handleOpenEditBudget = (b: WalletBudget) => {
    setEditingBudget(b);
    setEditBudgetName(b.name);
    setEditBudgetLimit(b.limitAmount.toFixed(2));
    setEditBudgetCategory(b.categoryId);
    setEditBudgetPeriod(b.period || activeFirestorePeriodId);
    setIsEditBudgetOpen(true);
  };

  const handleUpdateBudget = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingBudget || !editBudgetName.trim()) return;
    const limit = Math.max(1, parseFloat(editBudgetLimit) || 1000);
    const cat =
      categories.find((c) => c.id === editBudgetCategory) || categories[0];

    if (currentUser) {
      const uid = currentUser.uid;
      try {
        await updateDoc(doc(db, 'users', uid, 'budgets', editingBudget.id), {
          name: editBudgetName.trim().slice(0, 80),
          categoryId: cat.id,
          limitAmount: limit,
          period: editBudgetPeriod || activeFirestorePeriodId,
          iconName: cat.iconName,
          colorHex: cat.colorHex,
          updatedAt: serverTimestamp(),
        });
        showToast(`Presupuesto "${editBudgetName}" actualizado`);
      } catch (err) {
        handleFirestoreError(
          err,
          OperationType.UPDATE,
          `users/${uid}/budgets/${editingBudget.id}`
        );
      }
    } else {
      setBudgets((prev) =>
        prev.map((b) =>
          b.id === editingBudget.id
            ? {
                ...b,
                name: editBudgetName.trim(),
                categoryId: cat.id,
                limitAmount: limit,
                period: editBudgetPeriod || activeFirestorePeriodId,
                iconName: cat.iconName,
                colorHex: cat.colorHex,
              }
            : b
        )
      );
      showToast(`Presupuesto "${editBudgetName}" actualizado`);
    }
    setIsEditBudgetOpen(false);
    setEditingBudget(null);
  };

  const handleDeleteBudget = async (b: WalletBudget) => {
    setDeleteConfirmTarget({
      type: 'budget',
      id: b.id,
      name: b.name,
    });
  };

  const handleDeleteAccount = (acc: WalletAccount) => {
    setDeleteConfirmTarget({
      type: 'account',
      id: acc.id,
      name: acc.name,
    });
  };

  const handleDeleteBudgetLegacy = async (b: WalletBudget) => {
    if (!confirm(`¿Eliminar el presupuesto "${b.name}"?`)) return;
    if (currentUser) {
      const uid = currentUser.uid;
      try {
        await deleteDoc(doc(db, 'users', uid, 'budgets', b.id));
        showToast(`Presupuesto "${b.name}" eliminado`);
      } catch (err) {
        handleFirestoreError(
          err,
          OperationType.DELETE,
          `users/${uid}/budgets/${b.id}`
        );
      }
    } else {
      setBudgets((prev) => prev.filter((item) => item.id !== b.id));
      showToast(`Presupuesto "${b.name}" eliminado`);
    }
  };

  // Handler: Delete Transaction Atomically (Reverting currentBalance in involved accounts and summary)
  const handleDeleteTransaction = async (tx: WalletTransaction) => {
    const accountDeltas: Record<string, number> = {};
    accumulateTxAccountDeltas(accountDeltas, tx, -1); // -1 reverts impact
    const affectedAccountIds = Object.keys(accountDeltas).filter(
      (id) => Math.abs(accountDeltas[id]) >= 0.001
    );
    const txPeriodId =
      tx.periodId ||
      periodHelper.getFirestorePeriodId(new Date(tx.dateIso));

    if (currentUser) {
      const uid = currentUser.uid;
      try {
        const txRef = doc(db, 'users', uid, 'transactions', tx.id);
        const sumRef = doc(db, 'users', uid, 'summaries', txPeriodId);

        await runTransaction(db, async (firestoreTx) => {
          const accSnaps: Record<string, Awaited<ReturnType<typeof firestoreTx.get>>> = {};
          for (const accId of affectedAccountIds) {
            accSnaps[accId] = await firestoreTx.get(
              doc(db, 'users', uid, 'accounts', accId)
            );
          }
          const sumSnap = await firestoreTx.get(sumRef);

          for (const accId of affectedAccountIds) {
            const snap = accSnaps[accId];
            if (snap && snap.exists()) {
              const cur = Number(
                (snap.data() as Record<string, unknown>).currentBalance ??
                  (snap.data() as Record<string, unknown>).balance ??
                  0
              );
              const reverted = Number((cur + accountDeltas[accId]).toFixed(2));
              firestoreTx.update(doc(db, 'users', uid, 'accounts', accId), {
                currentBalance: reverted,
                balance: reverted,
                updatedAt: serverTimestamp(),
              });
            }
          }

          if (sumSnap.exists()) {
            const sData = sumSnap.data();
            const revInc =
              tx.type === 'income'
                ? Math.max(0, Number(sData.totalIncome || 0) - tx.amount)
                : Number(sData.totalIncome || 0);
            const revExp =
              tx.type === 'expense'
                ? Math.max(0, Number(sData.totalExpense || 0) - tx.amount)
                : Number(sData.totalExpense || 0);
            const revNet = Number((revInc - revExp).toFixed(2));
            firestoreTx.update(sumRef, {
              totalIncome: Number(revInc.toFixed(2)),
              totalExpense: Number(revExp.toFixed(2)),
              netCashFlow: revNet,
              savingsRate:
                revInc > 0
                  ? Number(((revNet / revInc) * 100).toFixed(1))
                  : 0,
              updatedAt: serverTimestamp(),
            });
          }

          firestoreTx.delete(txRef);
        });

        showToast(
          'Transacción eliminada y currentBalance revertido atómicamente en Firestore'
        );
      } catch (err) {
        handleFirestoreError(
          err,
          OperationType.DELETE,
          `users/${uid}/transactions/${tx.id}`
        );
      }
    } else {
      setTransactions((prev) => prev.filter((item) => item.id !== tx.id));
      setAccounts((prev) =>
        prev.map((a) => {
          const delta = accountDeltas[a.id];
          if (!delta) return a;
          const nextBal = Number(
            (Number(a.currentBalance ?? a.balance ?? 0) + delta).toFixed(2)
          );
          return { ...a, balance: nextBal, currentBalance: nextBal };
        })
      );
      setSummary((prev) => {
        const totalIncome =
          tx.type === 'income'
            ? Math.max(0, Number((prev.totalIncome - tx.amount).toFixed(2)))
            : prev.totalIncome;
        const totalExpense =
          tx.type === 'expense'
            ? Math.max(0, Number((prev.totalExpense - tx.amount).toFixed(2)))
            : prev.totalExpense;
        const netCashFlow = Number((totalIncome - totalExpense).toFixed(2));
        return {
          ...prev,
          totalIncome,
          totalExpense,
          netCashFlow,
          savingsRate:
            totalIncome > 0
              ? Number(((netCashFlow / totalIncome) * 100).toFixed(1))
              : 0,
        };
      });
      showToast('Registro eliminado y saldo de cuenta revertido sin descuadres');
    }
  };

  // Handler: Save Financial Period Settings (UserSettingsModel in /users/{userId})
  const handleSavePeriodSettings = async (e: React.FormEvent) => {
    e.preventDefault();
    const clampedStart = Math.max(
      1,
      Math.min(31, Number(userSettings.startDayOfMonth) || 27)
    );
    const clampedMid = Math.max(
      1,
      Math.min(31, Number(userSettings.midMonthDay) || 13)
    );
    const updated: UserSettingsModel = {
      ...userSettings,
      startDayOfMonth: clampedStart,
      midMonthDay: clampedMid,
    };
    setUserSettings(updated);

    if (currentUser) {
      const uid = currentUser.uid;
      try {
        await updateDoc(doc(db, 'users', uid), {
          startDayOfMonth: updated.startDayOfMonth,
          enableSplitPeriod: updated.enableSplitPeriod,
          midMonthDay: updated.midMonthDay,
          updatedAt: serverTimestamp(),
        });
        showToast(
          `Ciclo financiero actualizado en Firestore (Inicia día ${updated.startDayOfMonth})`
        );
      } catch (err) {
        handleFirestoreError(err, OperationType.UPDATE, `users/${uid}`);
      }
    } else {
      showToast(
        `Ciclo financiero configurado: Día de inicio ${updated.startDayOfMonth}, Quincena día ${updated.midMonthDay}`
      );
    }
    setIsPeriodSettingsModalOpen(false);
  };

  // Handler: Export CSV
  const handleExportCSV = () => {
    const headers = [
      'ID',
      'Fecha',
      'Tipo',
      'Cuenta',
      'Categoria',
      'Monto_GTQ',
      'Nota',
    ];
    const rows = transactions.map((t) => [
      t.id,
      t.dateIso,
      t.type,
      `"${t.accountName}"`,
      `"${t.categoryName}"`,
      t.amount.toFixed(2),
      `"${t.note.replace(/"/g, '""')}"`,
    ]);
    const csvContent =
      'data:text/csv;charset=utf-8,' +
      [headers.join(','), ...rows.map((e) => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', 'wallet_budgetbakers_octubre_2026.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    showToast('Archivo CSV exportado correctamente');
  };

  const renderCategoryIcon = (iconName: string) => {
    switch (iconName) {
      case 'shopping_cart':
        return <ShoppingCart className="w-5 h-5" />;
      case 'fuel':
        return <Fuel className="w-5 h-5" />;
      case 'wifi':
        return <Wifi className="w-5 h-5" />;
      case 'film':
        return <Film className="w-5 h-5" />;
      case 'heart_pulse':
        return <HeartPulse className="w-5 h-5" />;
      case 'briefcase':
        return <Briefcase className="w-5 h-5" />;
      default:
        return <Utensils className="w-5 h-5" />;
    }
  };

  const userNameDisplay = currentUser?.displayName || 'Francisco Estrada';

  return (
    <div className="min-h-screen bg-[#121212] text-[#E5E2E1] flex flex-col">
      {/* Top Bar Contract (3 Zones: Brand | Nav Links | Primary Actions) */}
      <header className="sticky top-0 z-40 h-20 w-full bg-[#131313]/95 backdrop-blur-xl border-b border-white/5 px-4 lg:px-8 flex items-center justify-between gap-4">
        {/* Zone 1: Brand Wordmark */}
        <a
          href="#panel"
          onClick={(e) => {
            e.preventDefault();
            setActiveTab('panel');
          }}
          className="text-xl font-bold tracking-tight text-white whitespace-nowrap"
        >
          Wallet
        </a>

        {/* Zone 2: Clean Single-Line Navigation Links */}
        <nav className="hidden lg:flex items-center gap-1">
          {[
            { id: 'panel', label: 'Panel' },
            { id: 'cuentas', label: 'Cuentas' },
            { id: 'categorias', label: 'Categorías' },
            { id: 'registros', label: 'Registros' },
            { id: 'analitica', label: 'Analítica' },
            { id: 'presupuestos', label: 'Presupuestos' },
          ].map((item) => {
            const active = activeTab === item.id;
            return (
              <button
                key={item.id}
                type="button"
                onClick={() => setActiveTab(item.id as NavTab)}
                className={`px-3.5 py-2 rounded-xl text-sm font-semibold transition-colors whitespace-nowrap ${
                  active
                    ? 'bg-[#2A2A2A] text-white'
                    : 'text-[#BACBB9] hover:text-white hover:bg-[#201F1F]'
                }`}
              >
                {item.label}
              </button>
            );
          })}
        </nav>

        {/* Zone 3: Primary Actions (+ Registro & User / Auth) */}
        <div className="flex items-center gap-2.5">
          <button
            type="button"
            onClick={() => {
              setCalcInitialType('expense');
              setIsCalcOpen(true);
            }}
            className="inline-flex items-center gap-1.5 px-4 py-2.5 rounded-xl bg-[#00E676] hover:bg-[#62FF96] text-[#003918] font-bold text-sm shadow-[0_4px_20px_rgba(0,230,118,0.2)] transition-colors whitespace-nowrap"
          >
            <Plus className="w-4 h-4 stroke-[2.5]" />
            <span>+ Registro</span>
          </button>

          {currentUser ? (
            <button
              type="button"
              onClick={handleLogout}
              title="Cerrar sesión"
              className="inline-flex items-center gap-2 px-3 py-2 rounded-xl bg-[#201F1F] hover:bg-[#2A2A2A] text-xs font-medium text-[#E5E2E1] transition-colors whitespace-nowrap"
            >
              <span className="w-6 h-6 rounded-full bg-[#00E676] text-[#003918] font-bold flex items-center justify-center text-xs">
                {userNameDisplay.slice(0, 1).toUpperCase()}
              </span>
              <span className="hidden sm:inline truncate max-w-[120px]">
                {userNameDisplay}
              </span>
              <LogOut className="w-3.5 h-3.5 text-[#A0A0A0]" />
            </button>
          ) : (
            <button
              type="button"
              onClick={() => setIsLoginModalOpen(true)}
              className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-[#201F1F] hover:bg-[#2A2A2A] border border-white/10 text-xs font-semibold text-white transition-colors whitespace-nowrap"
            >
              <LogIn className="w-4 h-4 text-[#00E676]" />
              <span>Iniciar Sesión</span>
            </button>
          )}
        </div>
      </header>

      {/* Mobile Secondary Navigation Strip for Narrow Screens */}
      <div className="flex lg:hidden items-center gap-1.5 overflow-x-auto px-4 py-2.5 bg-[#181818] border-b border-white/5">
        {[
          { id: 'panel', label: 'Panel' },
          { id: 'cuentas', label: 'Cuentas' },
          { id: 'categorias', label: 'Categorías' },
          { id: 'registros', label: 'Registros' },
          { id: 'analitica', label: 'Analítica' },
          { id: 'presupuestos', label: 'Presupuestos' },
        ].map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => setActiveTab(item.id as NavTab)}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold whitespace-nowrap ${
              activeTab === item.id
                ? 'bg-[#00E676] text-[#003918]'
                : 'bg-[#252525] text-[#A0A0A0]'
            }`}
          >
            {item.label}
          </button>
        ))}
      </div>

      {/* Toast Feedback Banner */}
      {statusBanner && (
        <div className="fixed bottom-6 right-6 z-50 bg-[#1E1E1E] border border-[#00E676]/40 text-white px-4 py-3 rounded-xl shadow-2xl flex items-center gap-2.5 text-xs font-medium">
          <Check className="w-4 h-4 text-[#00E676] shrink-0" />
          <span>{statusBanner}</span>
        </div>
      )}

      {/* Main Content Container */}
      <main className="flex-1 w-full max-w-[1480px] mx-auto px-4 lg:px-8 py-6">
        {/* Banner solo para Modo Demo (cuando no hay sesión activa) */}
        {!currentUser && (
          <div className="mb-6 bg-[#169B62]/10 border border-[#00E676]/25 rounded-2xl p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-[#00E676]/15 flex items-center justify-center shrink-0">
                <Wallet className="w-5 h-5 text-[#00E676]" />
              </div>
              <div>
                <h4 className="text-sm font-bold text-white">
                  Modo Demostración Interactivo
                </h4>
                <p className="text-xs text-[#BACBB9] mt-0.5">
                  Estás explorando datos de prueba. Inicia sesión con Google para gestionar tus cuentas reales con saldos desde cero.
                </p>
              </div>
            </div>
            <button
              type="button"
              onClick={() => setIsLoginModalOpen(true)}
              className="inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-[#00E676] hover:bg-[#62FF96] text-[#003918] font-bold text-xs transition-colors shrink-0 shadow-sm"
            >
              <LogIn className="w-3.5 h-3.5" />
              <span>Iniciar Sesión</span>
            </button>
          </div>
        )}

        {/* ==================== VIEW 1: PANEL (DASHBOARD - IMAGE 9 / 10) ==================== */}
        {activeTab === 'panel' && (
          <div className="space-y-6">
            {/* Top Account Quick-Cards Strip */}
            <section className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              {accounts.map((acc) => {
                const isNeg = acc.balance < 0;
                const isCash = acc.type === 'cash';
                const isCredit = acc.type === 'credit_card';
                return (
                  <div
                    key={acc.id}
                    onClick={() => {
                      setSelectedAccountFilter(
                        selectedAccountFilter === acc.id ? 'all' : acc.id
                      );
                    }}
                    className={`relative overflow-hidden rounded-xl p-4 border transition-all cursor-pointer flex items-center justify-between ${
                      selectedAccountFilter === acc.id
                        ? 'border-[#00E676] bg-[#252525]'
                        : isCash
                        ? 'bg-gradient-to-br from-[#00DCF5]/20 via-[#201F1F] to-[#2A2A2A] border-white/5 hover:border-white/15'
                        : isCredit
                        ? 'bg-gradient-to-br from-[#A00118]/35 via-[#201F1F] to-[#2A2A2A] border-white/5 hover:border-white/15'
                        : 'bg-[#201F1F] border-white/5 hover:border-white/15'
                    }`}
                  >
                    <div className="flex items-center gap-3.5 min-w-0">
                      <div
                        className={`w-12 h-12 rounded-xl flex items-center justify-center shrink-0 ${
                          isCash
                            ? 'bg-[#00DCF5]/20 text-[#00DCF5]'
                            : isCredit
                            ? 'bg-[#A00118]/40 text-[#FFB3AE]'
                            : 'bg-[#00E676]/15 text-[#75FF9E]'
                        }`}
                      >
                        {isCash ? (
                          <Banknote className="w-6 h-6" />
                        ) : isCredit ? (
                          <CreditCard className="w-6 h-6" />
                        ) : (
                          <Building2 className="w-6 h-6" />
                        )}
                      </div>
                      <div className="min-w-0">
                        <span className="text-xs font-medium text-[#BACBB9] uppercase tracking-wider block truncate">
                          {acc.name}
                        </span>
                        <span
                          className={`text-lg font-bold font-mono tabular-nums block ${
                            isNeg ? 'text-[#FFB3AE]' : 'text-white'
                          }`}
                        >
                          {acc.balance < 0 ? '-' : ''}
                          {Math.abs(acc.balance).toLocaleString('es-GT', {
                            minimumFractionDigits: 2,
                            maximumFractionDigits: 2,
                          })}{' '}
                          {acc.currency}
                        </span>
                        <span className="text-[11px] text-[#A0A0A0] block truncate mt-0.5">
                          {acc.subtitle}
                        </span>
                      </div>
                    </div>
                    <div
                      className={`w-1.5 h-10 rounded-full shrink-0 ${
                        isCash
                          ? 'bg-[#00DCF5]/50'
                          : isCredit
                          ? 'bg-[#FF5252]/60'
                          : 'bg-[#00E676]/40'
                      }`}
                    />
                  </div>
                );
              })}

              {/* Add Account Button Card */}
              <button
                type="button"
                onClick={() => setIsAddAccountOpen(true)}
                className="rounded-xl bg-[#1C1B1B] hover:bg-[#252525] border border-dashed border-white/15 p-4 flex items-center justify-center gap-3 text-[#BACBB9] hover:text-[#75FF9E] transition-colors cursor-pointer"
              >
                <div className="w-10 h-10 rounded-xl bg-[#2A2A2A] flex items-center justify-center">
                  <Plus className="w-5 h-5" />
                </div>
                <span className="text-sm font-semibold whitespace-nowrap">
                  + Agregar cuenta bancaria
                </span>
              </button>
            </section>

            {/* Sub-Bar: Dynamic Financial Period Selector (Requerimiento 2) */}
            <div className="bg-[#1C1B1B] border border-white/5 rounded-xl p-4 flex flex-col gap-3">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div className="flex flex-wrap items-center gap-2.5">
                  <div className="flex items-center rounded-xl bg-[#2A2A2A] p-1">
                    <button
                      type="button"
                      onClick={() => {
                        const prev = new Date(referenceDate);
                        prev.setMonth(prev.getMonth() - 1);
                        setReferenceDate(prev);
                      }}
                      className="w-8 h-8 rounded-lg flex items-center justify-center text-[#BACBB9] hover:text-white hover:bg-[#393939]"
                      title="Período anterior"
                    >
                      <ChevronLeft className="w-4 h-4" />
                    </button>
                    <div className="px-3.5 py-1 flex items-center gap-2 text-white text-xs sm:text-sm font-semibold">
                      <Calendar className="w-4 h-4 text-[#75FF9E]" />
                      <span>
                        Ciclo Financiero {activePeriodName} (
                        {FinancialPeriodHelper.formatShortRange(fullPeriodRange)}
                        )
                      </span>
                    </div>
                    <button
                      type="button"
                      onClick={() => {
                        const next = new Date(referenceDate);
                        next.setMonth(next.getMonth() + 1);
                        setReferenceDate(next);
                      }}
                      className="w-8 h-8 rounded-lg flex items-center justify-center text-[#BACBB9] hover:text-white hover:bg-[#393939]"
                      title="Siguiente período"
                    >
                      <ChevronRight className="w-4 h-4" />
                    </button>
                  </div>

                  <span className="px-2.5 py-1 rounded-lg bg-[#00DCF5]/15 text-[#00DCF5] text-xs font-mono font-semibold">
                    /summaries/{activeFirestorePeriodId}
                  </span>
                  <span className="px-2.5 py-1 rounded-lg bg-[#00E676]/15 text-[#75FF9E] text-xs font-semibold">
                    {activeSubPeriodLabel}
                  </span>
                </div>

                <div className="flex items-center gap-2">
                  {selectedAccountFilter !== 'all' && (
                    <button
                      type="button"
                      onClick={() => setSelectedAccountFilter('all')}
                      className="px-3 py-2 rounded-xl bg-[#252525] text-xs text-[#00DCF5] font-semibold"
                    >
                      Mostrar todas las cuentas
                    </button>
                  )}
                  <button
                    type="button"
                    onClick={() => setIsPeriodSettingsModalOpen(true)}
                    className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-[#252525] hover:bg-[#2E2E2E] text-white text-xs font-semibold border border-white/10 transition-colors"
                  >
                    <Settings2 className="w-4 h-4 text-[#00DCF5]" />
                    <span>
                      Ciclo Nómina (Día {userSettings.startDayOfMonth} / Q{' '}
                      {userSettings.midMonthDay})
                    </span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setIsAddAccountOpen(true)}
                    className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-[#201F1F] hover:bg-[#2A2A2A] text-white text-xs font-semibold border border-white/5 transition-colors"
                  >
                    <CreditCard className="w-4 h-4 text-[#75FF9E]" />
                    <span className="hidden sm:inline">+ Agregar tarjeta</span>
                  </button>
                </div>
              </div>

              {/* 4 Period Filter Pills: Período Actual | Primera Mitad | Segunda Mitad | Personalizado */}
              <div className="flex flex-wrap items-center justify-between gap-3 pt-2 border-t border-white/5">
                <div className="flex flex-wrap items-center gap-2">
                  <button
                    type="button"
                    onClick={() => setPeriodFilterMode('fullPeriod')}
                    className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold transition-all ${
                      periodFilterMode === 'fullPeriod'
                        ? 'bg-[#00E676] text-[#003918] font-bold'
                        : 'bg-[#252525] text-[#BACBB9] hover:text-white'
                    }`}
                  >
                    Período Actual (
                    {FinancialPeriodHelper.formatShortRange(fullPeriodRange)})
                  </button>

                  {userSettings.enableSplitPeriod && (
                    <>
                      <button
                        type="button"
                        onClick={() => setPeriodFilterMode('firstHalf')}
                        className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold transition-all ${
                          periodFilterMode === 'firstHalf'
                            ? 'bg-[#00DCF5] text-[#00363D] font-bold'
                            : 'bg-[#252525] text-[#BACBB9] hover:text-white'
                        }`}
                      >
                        Primera Mitad (
                        {FinancialPeriodHelper.formatShortRange(firstHalfRange)}
                        )
                      </button>

                      <button
                        type="button"
                        onClick={() => setPeriodFilterMode('secondHalf')}
                        className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold transition-all ${
                          periodFilterMode === 'secondHalf'
                            ? 'bg-[#00DCF5] text-[#00363D] font-bold'
                            : 'bg-[#252525] text-[#BACBB9] hover:text-white'
                        }`}
                      >
                        Segunda Mitad (
                        {FinancialPeriodHelper.formatShortRange(secondHalfRange)}
                        )
                      </button>
                    </>
                  )}

                  <button
                    type="button"
                    onClick={() => setPeriodFilterMode('custom')}
                    className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold transition-all ${
                      periodFilterMode === 'custom'
                        ? 'bg-[#75FF9E] text-[#003918] font-bold'
                        : 'bg-[#252525] text-[#BACBB9] hover:text-white'
                    }`}
                  >
                    Personalizado
                  </button>
                </div>

                {periodFilterMode === 'custom' && (
                  <div className="flex items-center gap-2 text-xs">
                    <input
                      type="date"
                      value={customStartIso}
                      onChange={(e) => setCustomStartIso(e.target.value)}
                      className="bg-[#252525] text-white font-mono text-xs px-2.5 py-1 rounded-lg border border-white/10"
                    />
                    <span className="text-[#BACBB9]">a</span>
                    <input
                      type="date"
                      value={customEndIso}
                      onChange={(e) => setCustomEndIso(e.target.value)}
                      className="bg-[#252525] text-white font-mono text-xs px-2.5 py-1 rounded-lg border border-white/10"
                    />
                  </div>
                )}
              </div>
            </div>

            {/* Row 1: 3 Tachometer Gauges, Balance Trend, Spending Structure */}
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
              {/* Widget 1: Tachometer Gauges (4 cols) */}
              <div className="lg:col-span-4 rounded-xl bg-[#201F1F] border border-white/5 p-6 flex flex-col justify-between">
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-2">
                    <h2 className="text-lg font-bold text-white">Panel</h2>
                    <span className="text-xs text-[#BACBB9] uppercase tracking-wider">
                      · Métricas
                    </span>
                  </div>
                </div>

                <div className="grid grid-cols-3 gap-2 items-end py-3">
                  {/* Gauge 1: Saldo */}
                  <div className="flex flex-col items-center">
                    <div className="relative w-24 h-16 flex items-center justify-center">
                      <svg className="w-full h-full overflow-visible" viewBox="0 0 100 60">
                        <path
                          d="M 10 50 A 40 40 0 0 1 90 50"
                          fill="none"
                          stroke="#353534"
                          strokeLinecap="round"
                          strokeWidth="8"
                        />
                        <path
                          d="M 10 50 A 40 40 0 0 1 50 10"
                          fill="none"
                          stroke="#FFB3AE"
                          strokeLinecap="round"
                          strokeWidth="8"
                        />
                        <line
                          stroke="#E5E2E1"
                          strokeLinecap="round"
                          strokeWidth="2.5"
                          x1="50"
                          x2="50"
                          y1="50"
                          y2="16"
                        />
                        <circle cx="50" cy="50" fill="#E5E2E1" r="4" />
                      </svg>
                    </div>
                    <span className="mt-2 text-[10px] text-[#BACBB9] font-semibold tracking-wider uppercase">
                      SALDO
                    </span>
                    <span className="text-sm font-bold font-mono tabular-nums text-[#FFB3AE]">
                      {(totalNetBalance / 1000).toFixed(1)} mil
                    </span>
                  </div>

                  {/* Gauge 2: Flujo de Caja */}
                  <div className="flex flex-col items-center">
                    <div className="relative w-24 h-16 flex items-center justify-center">
                      <svg className="w-full h-full overflow-visible" viewBox="0 0 100 60">
                        <path
                          d="M 10 50 A 40 40 0 0 1 90 50"
                          fill="none"
                          stroke="#353534"
                          strokeLinecap="round"
                          strokeWidth="8"
                        />
                        <path
                          d="M 50 10 A 40 40 0 0 1 88 45"
                          fill="none"
                          stroke="#75FF9E"
                          strokeLinecap="round"
                          strokeWidth="8"
                        />
                        <line
                          stroke="#E5E2E1"
                          strokeLinecap="round"
                          strokeWidth="2.5"
                          x1="50"
                          x2="68"
                          y1="50"
                          y2="24"
                        />
                        <circle cx="50" cy="50" fill="#E5E2E1" r="4" />
                      </svg>
                    </div>
                    <span className="mt-2 text-[10px] text-[#BACBB9] font-semibold tracking-wider uppercase">
                      FLUJO DE CAJA
                    </span>
                    <span className="text-sm font-bold font-mono tabular-nums text-[#75FF9E]">
                      +{(summary.netCashFlow / 1000).toFixed(1)}k GTQ
                    </span>
                  </div>

                  {/* Gauge 3: Gastos */}
                  <div className="flex flex-col items-center">
                    <div className="relative w-24 h-16 flex items-center justify-center">
                      <svg className="w-full h-full overflow-visible" viewBox="0 0 100 60">
                        <path
                          d="M 10 50 A 40 40 0 0 1 90 50"
                          fill="none"
                          stroke="#353534"
                          strokeLinecap="round"
                          strokeWidth="8"
                        />
                        <path
                          d="M 10 50 A 40 40 0 0 1 35 22"
                          fill="none"
                          stroke="#FFB3AE"
                          strokeLinecap="round"
                          strokeWidth="8"
                        />
                        <path
                          d="M 65 22 A 40 40 0 0 1 90 50"
                          fill="none"
                          stroke="#00DAF3"
                          strokeLinecap="round"
                          strokeWidth="8"
                        />
                        <line
                          stroke="#E5E2E1"
                          strokeLinecap="round"
                          strokeWidth="2.5"
                          x1="50"
                          x2="72"
                          y1="50"
                          y2="34"
                        />
                        <circle cx="50" cy="50" fill="#E5E2E1" r="4" />
                      </svg>
                    </div>
                    <span className="mt-2 text-[10px] text-[#BACBB9] font-semibold tracking-wider uppercase">
                      GASTOS
                    </span>
                    <span className="text-sm font-bold font-mono tabular-nums text-white">
                      -{(summary.totalExpense / 1000).toFixed(1)}k GTQ
                    </span>
                  </div>
                </div>

                <div className="mt-4 pt-3 border-t border-white/5 flex items-center justify-between text-xs">
                  <span className="text-[#BACBB9]">
                    Límite mensual recomendado
                  </span>
                  <span className="font-mono font-bold text-[#75FF9E]">
                    12,500.00 GTQ
                  </span>
                </div>
              </div>

              {/* Widget 2: Tendencia de Saldo (4 cols) */}
              <div className="lg:col-span-4 rounded-xl bg-[#201F1F] border border-white/5 p-6 flex flex-col justify-between">
                <div>
                  <div className="flex items-center justify-between mb-1">
                    <h2 className="text-lg font-bold text-white">
                      Tendencia de saldo
                    </h2>
                    <span className="text-xs font-mono text-[#BACBB9]">
                      Octubre 2026
                    </span>
                  </div>
                  <div className="flex items-baseline justify-between mt-2 mb-4">
                    <div>
                      <span className="text-[10px] text-[#BACBB9] uppercase block">
                        Patrimonio neto actual
                      </span>
                      <span
                        className={`text-2xl font-bold font-mono tabular-nums ${
                          totalNetBalance < 0 ? 'text-[#FFB3AE]' : 'text-[#75FF9E]'
                        }`}
                      >
                        {totalNetBalance < 0 ? '-' : ''}
                        {Math.abs(totalNetBalance).toLocaleString('es-GT', {
                          minimumFractionDigits: 2,
                          maximumFractionDigits: 2,
                        })}{' '}
                        GTQ
                      </span>
                    </div>
                    <span className="text-xs font-mono text-[#BACBB9]">
                      Variación · 0%
                    </span>
                  </div>
                </div>

                <div className="w-full relative h-36 flex flex-col justify-end">
                  <svg
                    className="w-full h-28"
                    preserveAspectRatio="none"
                    viewBox="0 0 320 110"
                  >
                    <defs>
                      <linearGradient id="gradBalance" x1="0" x2="0" y1="0" y2="1">
                        <stop offset="0%" stopColor="#00dcf5" stopOpacity="0.35" />
                        <stop offset="100%" stopColor="#00dcf5" stopOpacity="0.0" />
                      </linearGradient>
                    </defs>
                    <line
                      stroke="#353534"
                      strokeDasharray="3,3"
                      strokeWidth="1"
                      x1="0"
                      x2="320"
                      y1="20"
                      y2="20"
                    />
                    <line
                      stroke="#353534"
                      strokeDasharray="3,3"
                      strokeWidth="1"
                      x1="0"
                      x2="320"
                      y1="50"
                      y2="50"
                    />
                    <line
                      stroke="#353534"
                      strokeDasharray="3,3"
                      strokeWidth="1"
                      x1="0"
                      x2="320"
                      y1="80"
                      y2="80"
                    />
                    <polygon
                      fill="url(#gradBalance)"
                      points="0,75 25,75 50,73 75,70 100,68 125,60 150,62 175,64 200,65 225,65 250,65 275,65 300,65 320,65 320,110 0,110"
                    />
                    <polyline
                      fill="none"
                      points="0,75 25,75 50,73 75,70 100,68 125,60 150,62 175,64 200,65 225,65 250,65 275,65 300,65 320,65"
                      stroke="#00daf3"
                      strokeWidth="2.5"
                    />
                    <circle cx="125" cy="60" fill="#75ff9e" r="4.5" />
                  </svg>
                  <div className="w-full flex items-center justify-between text-[#BACBB9] font-mono text-[10px] pt-1">
                    <span>1 Oct</span>
                    <span>7 Oct</span>
                    <span>14 Oct</span>
                    <span>22 Oct</span>
                    <span>31 Oct</span>
                  </div>
                </div>

                <div className="mt-3 pt-3 border-t border-white/5 flex items-center justify-between text-xs text-[#BACBB9]">
                  <span>Proyección fin de mes</span>
                  <span className="text-white font-mono font-semibold">
                    -4,180.00 GTQ
                  </span>
                </div>
              </div>

              {/* Widget 3: Estructura de los gastos (4 cols) */}
              <div className="lg:col-span-4 rounded-xl bg-[#201F1F] border border-white/5 p-6 flex flex-col justify-between">
                <div>
                  <div className="flex items-center justify-between mb-1">
                    <h2 className="text-lg font-bold text-white">
                      Estructura de los gastos
                    </h2>
                    <button
                      type="button"
                      onClick={() => setActiveTab('analitica')}
                      className="text-xs text-[#75FF9E] hover:underline"
                    >
                      Ver reporte
                    </button>
                  </div>
                  <div className="flex items-baseline justify-between mt-2 mb-3">
                    <div>
                      <span className="text-[10px] text-[#BACBB9] uppercase block">
                        Este mes
                      </span>
                      <span className="text-2xl font-bold font-mono tabular-nums text-[#FFB3AE]">
                        -
                        {summary.totalExpense.toLocaleString('es-GT', {
                          minimumFractionDigits: 2,
                          maximumFractionDigits: 2,
                        })}{' '}
                        GTQ
                      </span>
                    </div>
                    <span className="text-xs font-mono text-[#75FF9E]">
                      ↓ -12% vs mes ant.
                    </span>
                  </div>
                </div>

                <div className="grid grid-cols-12 items-center gap-4 py-2">
                  <div className="col-span-5 flex items-center justify-center relative">
                    <svg className="w-28 h-28 -rotate-90" viewBox="0 0 100 100">
                      <circle
                        cx="50"
                        cy="50"
                        fill="transparent"
                        r="40"
                        stroke="#2a2a2a"
                        strokeWidth="12"
                      />
                      <circle
                        cx="50"
                        cy="50"
                        fill="transparent"
                        r="40"
                        stroke="#00e676"
                        strokeDasharray="105.5 251.2"
                        strokeDashoffset="0"
                        strokeWidth="12"
                      />
                      <circle
                        cx="50"
                        cy="50"
                        fill="transparent"
                        r="40"
                        stroke="#00dcf5"
                        strokeDasharray="70.3 251.2"
                        strokeDashoffset="-105.5"
                        strokeWidth="12"
                      />
                      <circle
                        cx="50"
                        cy="50"
                        fill="transparent"
                        r="40"
                        stroke="#ffa8a3"
                        strokeDasharray="37.7 251.2"
                        strokeDashoffset="-175.8"
                        strokeWidth="12"
                      />
                    </svg>
                    <div className="absolute inset-0 flex flex-col items-center justify-center text-center pointer-events-none">
                      <span className="text-[9px] text-[#BACBB9] uppercase">
                        Total
                      </span>
                      <span className="text-xs font-bold font-mono text-white">
                        6.4k
                      </span>
                    </div>
                  </div>

                  <div className="col-span-7 space-y-2 text-xs">
                    <div className="flex items-center justify-between">
                      <span className="text-[#E5E2E1] truncate">
                        Comida y bebida
                      </span>
                      <span className="font-mono font-semibold text-white">
                        2,700.60 Q
                      </span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-[#E5E2E1] truncate">
                        Servicios e Internet
                      </span>
                      <span className="font-mono font-semibold text-white">
                        1,800.40 Q
                      </span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-[#E5E2E1] truncate">
                        Transporte y Gas
                      </span>
                      <span className="font-mono font-semibold text-white">
                        964.50 Q
                      </span>
                    </div>
                  </div>
                </div>

                <button
                  type="button"
                  onClick={() => setActiveTab('analitica')}
                  className="mt-2 pt-3 border-t border-white/5 text-xs text-[#75FF9E] font-semibold hover:underline text-center w-full"
                >
                  Ver desglose completo de gastos →
                </button>
              </div>
            </div>

            {/* Row 2: Últimos Registros (8 cols) + Right Column Widgets (4 cols) */}
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
              {/* Left 8 Cols: Últimos registros */}
              <div className="lg:col-span-8 rounded-xl bg-[#201F1F] border border-white/5 p-6 flex flex-col">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-5">
                  <div className="flex items-center gap-2">
                    <h2 className="text-lg font-bold text-white">
                      Últimos registros
                    </h2>
                    <span className="text-xs text-[#75FF9E] font-mono">
                      · {filteredTransactions.length} movimientos
                    </span>
                  </div>

                  <div className="flex items-center gap-2">
                    <div className="relative">
                      <Search className="w-4 h-4 text-[#BACBB9] absolute left-3 top-1/2 -translate-y-1/2" />
                      <input
                        type="search"
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        placeholder="Buscar movimientos..."
                        className="w-48 sm:w-56 pl-9 pr-3 py-1.5 rounded-xl bg-[#2A2A2A] text-xs text-white placeholder-[#BACBB9]/60 focus:outline-none focus:ring-1 focus:ring-[#75FF9E]"
                      />
                    </div>
                    <button
                      type="button"
                      onClick={handleExportCSV}
                      title="Exportar CSV"
                      className="p-2 rounded-xl bg-[#2A2A2A] hover:bg-[#393939] text-[#BACBB9] hover:text-white transition-colors"
                    >
                      <Download className="w-4 h-4" />
                    </button>
                  </div>
                </div>

                <div className="divide-y divide-[#2A2A2A]">
                  {filteredTransactions.slice(0, 6).map((tx) => {
                    const isInc = tx.type === 'income';
                    return (
                      <div
                        key={tx.id}
                        className="py-3.5 flex items-center justify-between hover:bg-[#2A2A2A]/40 rounded-xl px-2 transition-colors group"
                      >
                        <div className="flex items-center gap-3.5 min-w-0">
                          <div
                            className={`relative w-11 h-11 rounded-xl flex items-center justify-center shrink-0 ${
                              isInc
                                ? 'bg-[#00E676]/15 text-[#75FF9E]'
                                : 'bg-[#A00118]/25 text-[#FFB3AE]'
                            }`}
                          >
                            {renderCategoryIcon(tx.categoryIcon)}
                            <span className="absolute -bottom-1 -right-1 w-4 h-4 rounded-full bg-[#00E676] text-[#003918] flex items-center justify-center">
                              <Check className="w-2.5 h-2.5 stroke-[3]" />
                            </span>
                          </div>
                          <div className="min-w-0">
                            <div className="text-sm font-semibold text-white truncate">
                              {tx.note}
                            </div>
                            <div className="text-xs text-[#BACBB9] truncate">
                              {tx.type === 'transfer' && tx.toAccountName
                                ? `${tx.accountName} → ${tx.toAccountName}`
                                : tx.accountName}{' '}
                              · {tx.categoryName} ·{' '}
                              <span className="text-[#00DCF5]">
                                {periodHelper.getSubPeriod(
                                  new Date(tx.dateIso)
                                )}
                              </span>
                            </div>
                          </div>
                        </div>

                        <div className="flex items-center gap-2 shrink-0 pl-3">
                          <div className="text-right">
                            <div
                              className={`text-sm font-bold font-mono tabular-nums ${
                                isInc
                                  ? 'text-[#75FF9E]'
                                  : tx.type === 'transfer'
                                  ? 'text-[#00DCF5]'
                                  : 'text-[#FFB3AE]'
                              }`}
                            >
                              {isInc ? '+' : tx.type === 'transfer' ? '⇄ ' : '-'}
                              {tx.amount.toLocaleString('es-GT', {
                                minimumFractionDigits: 2,
                                maximumFractionDigits: 2,
                              })}{' '}
                              {tx.currency}
                            </div>
                            <div className="text-[11px] font-mono text-[#BACBB9]">
                              {new Date(tx.dateIso).toLocaleDateString('es-GT', {
                                month: '2-digit',
                                day: '2-digit',
                                year: 'numeric',
                              })}
                            </div>
                          </div>
                          <button
                            type="button"
                            onClick={() => {
                              setEditingTransaction(tx);
                              setIsCalcOpen(true);
                            }}
                            title="Editar y cuadrar saldo atómicamente"
                            className="p-1.5 rounded-lg hover:bg-[#00DCF5]/20 text-[#BACBB9] hover:text-[#00DCF5] transition-all"
                          >
                            <Edit3 className="w-4 h-4" />
                          </button>
                          <button
                            type="button"
                            onClick={() => handleDeleteTransaction(tx)}
                            title="Eliminar y revertir saldo atómicamente"
                            className="p-1.5 rounded-lg hover:bg-[#A00118]/40 text-[#BACBB9] hover:text-[#FFB3AE] transition-all"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </div>
                    );
                  })}
                </div>

                <div className="pt-4 mt-auto border-t border-white/5 flex items-center justify-between text-xs">
                  <span className="text-[#BACBB9]">
                    Mostrando {Math.min(6, filteredTransactions.length)} de{' '}
                    {filteredTransactions.length} transacciones
                  </span>
                  <button
                    type="button"
                    onClick={() => setActiveTab('registros')}
                    className="text-[#75FF9E] font-bold hover:underline"
                  >
                    Ver todo el historial →
                  </button>
                </div>
              </div>

              {/* Right 4 Cols: Monthly Budget + Quick Transfer + Liquidity Insight */}
              <div className="lg:col-span-4 flex flex-col gap-6">
                {/* Budget Health Card */}
                <div className="rounded-xl bg-[#201F1F] border border-white/5 p-6 flex flex-col gap-4">
                  <div className="flex items-center justify-between">
                    <h3 className="text-base font-bold text-white">
                      Presupuesto mensual
                    </h3>
                    <span className="text-xs font-mono font-semibold text-[#75FF9E]">
                      71% disponible
                    </span>
                  </div>
                  <div className="space-y-1.5">
                    <div className="flex justify-between text-xs">
                      <span className="text-[#BACBB9]">
                        Gastado: 1,400.00 GTQ
                      </span>
                      <span className="text-white font-mono font-semibold">
                        Meta: 4,800.00 GTQ
                      </span>
                    </div>
                    <div className="w-full h-2.5 rounded-full bg-[#2A2A2A] overflow-hidden">
                      <div
                        className="h-full bg-[#75FF9E] rounded-full transition-all duration-500"
                        style={{ width: '29%' }}
                      />
                    </div>
                  </div>
                  <div className="grid grid-cols-2 gap-3 pt-1">
                    <div className="p-3 rounded-xl bg-[#2A2A2A]">
                      <span className="text-[10px] text-[#BACBB9] uppercase block">
                        Disponible hoy
                      </span>
                      <span className="text-sm font-bold font-mono tabular-nums text-white mt-0.5 block">
                        {Math.max(0, totalNetBalance).toLocaleString('es-GT', {
                          minimumFractionDigits: 2,
                        })}{' '}
                        GTQ
                      </span>
                    </div>
                    <div className="p-3 rounded-xl bg-[#2A2A2A]">
                      <span className="text-[10px] text-[#BACBB9] uppercase block">
                        Días restantes
                      </span>
                      <span className="text-sm font-bold font-mono tabular-nums text-[#75FF9E] mt-0.5 block">
                        Ciclo Activo
                      </span>
                    </div>
                  </div>
                </div>

                {/* Quick Transfer & Card Assistant */}
                <div className="rounded-xl bg-[#201F1F] border border-white/5 p-6 flex flex-col gap-4">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <ArrowLeftRight className="w-4 h-4 text-[#75FF9E]" />
                      <h3 className="text-base font-bold text-white">
                        Transferencia rápida
                      </h3>
                    </div>
                    <span className="text-[11px] text-[#BACBB9]">
                      Entre tus cuentas
                    </span>
                  </div>

                  <div className="space-y-2 text-xs">
                    <div className="flex items-center justify-between p-3 rounded-xl bg-[#2A2A2A]">
                      <span className="text-[#BACBB9]">
                        Origen: {accounts[0]?.name || 'Efectivo'}
                      </span>
                      <span className="font-mono font-semibold text-white">
                        {(
                          accounts[0]?.currentBalance ?? accounts[0]?.balance ?? 0
                        ).toLocaleString('es-GT', {
                          minimumFractionDigits: 2,
                        })}{' '}
                        GTQ
                      </span>
                    </div>
                    <div className="flex items-center justify-between p-3 rounded-xl bg-[#2A2A2A]">
                      <span className="text-[#BACBB9]">
                        Destino: {accounts[1]?.name || 'Cuenta Bancaria'}
                      </span>
                      <span className="font-mono font-semibold text-[#75FF9E]">
                        {(
                          accounts[1]?.currentBalance ?? accounts[1]?.balance ?? 0
                        ).toLocaleString('es-GT', {
                          minimumFractionDigits: 2,
                        })}{' '}
                        GTQ
                      </span>
                    </div>
                  </div>

                  <button
                    type="button"
                    onClick={() => {
                      setCalcInitialType('transfer');
                      setIsCalcOpen(true);
                    }}
                    className="w-full py-2.5 px-4 rounded-xl bg-[#353534] hover:bg-[#393939] text-white text-xs font-semibold transition-colors flex items-center justify-center gap-2"
                  >
                    <ArrowLeftRight className="w-4 h-4 text-[#75FF9E]" />
                    <span>Realizar transferencia entre cuentas</span>
                  </button>
                </div>

                {/* Smart Liquidity Note */}
                <div className="rounded-xl bg-gradient-to-r from-[#00DCF5]/10 via-[#201F1F] to-[#2A2A2A] border border-white/5 p-4 flex items-start gap-3">
                  <div className="p-2 rounded-lg bg-[#00DCF5]/20 text-[#00DAF3] shrink-0">
                    <Lightbulb className="w-5 h-5" />
                  </div>
                  <div>
                    <div className="text-xs font-bold text-white">
                      Consejo financiero
                    </div>
                    <p className="text-xs text-[#BACBB9] mt-1 leading-relaxed">
                      Lleva el control de tus ingresos, gastos y transferencias quincenales para alcanzar tus metas de ahorro y presupuestos.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* ==================== VIEW 2: ANALÍTICA / REPORTES (IMAGE 1 / 2) ==================== */}
        {activeTab === 'analitica' && (
          <div className="space-y-6">
            {/* Filter Control Hub with Dynamic Financial Period Selector */}
            <div className="flex flex-col gap-4 bg-[#1C1B1B] border border-white/5 p-4 rounded-xl">
              <div className="flex flex-col xl:flex-row xl:items-center justify-between gap-4">
                <div className="flex flex-wrap items-center gap-3">
                  <div className="flex items-center gap-2 px-4 py-2 bg-[#201F1F] rounded-xl text-sm font-semibold text-white">
                    <Calendar className="w-4 h-4 text-[#00DAF3]" />
                    <span>
                      Período {activePeriodName} ·{' '}
                      {FinancialPeriodHelper.formatShortRange(activeDateRange)}
                    </span>
                  </div>

                  {/* Segmented Toggle: Gastos | Ingresos | Flujo Neto */}
                  <div className="flex items-center bg-[#0E0E0E] p-1 rounded-xl">
                    {[
                      { id: 'gastos', label: 'Gastos' },
                      { id: 'ingresos', label: 'Ingresos' },
                      { id: 'flujo', label: 'Flujo Neto' },
                    ].map((t) => (
                      <button
                        key={t.id}
                        type="button"
                        onClick={() =>
                          setFlowFilter(t.id as 'gastos' | 'ingresos' | 'flujo')
                        }
                        className={`px-4 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                          flowFilter === t.id
                            ? 'bg-[#2A2A2A] text-white'
                            : 'text-[#BACBB9] hover:text-white'
                        }`}
                      >
                        {t.label}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="flex flex-wrap items-center gap-2.5">
                  <button
                    type="button"
                    onClick={() => setIsPeriodSettingsModalOpen(true)}
                    className="inline-flex items-center gap-1.5 px-3.5 py-2 bg-[#201F1F] hover:bg-[#2A2A2A] text-[#00DCF5] text-xs font-semibold rounded-xl border border-white/5 transition-colors"
                  >
                    <Settings2 className="w-4 h-4" />
                    <span>Configurar Ciclo</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => window.print()}
                    className="inline-flex items-center gap-2 px-4 py-2 bg-[#201F1F] hover:bg-[#2A2A2A] text-white text-xs font-semibold rounded-xl transition-colors"
                  >
                    <Download className="w-4 h-4 text-[#FFB3AE]" />
                    <span>Exportar PDF</span>
                  </button>
                  <button
                    type="button"
                    onClick={handleExportCSV}
                    className="inline-flex items-center gap-2 px-4 py-2 bg-[#201F1F] hover:bg-[#2A2A2A] text-white text-xs font-semibold rounded-xl transition-colors"
                  >
                    <FileSpreadsheet className="w-4 h-4 text-[#75FF9E]" />
                    <span>Exportar Excel (CSV)</span>
                  </button>
                </div>
              </div>

              {/* Period Filter Selector Row in Reports */}
              <div className="flex flex-wrap items-center gap-2 pt-3 border-t border-white/5">
                <button
                  type="button"
                  onClick={() => setPeriodFilterMode('fullPeriod')}
                  className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold transition-all ${
                    periodFilterMode === 'fullPeriod'
                      ? 'bg-[#00E676] text-[#003918] font-bold'
                      : 'bg-[#252525] text-[#BACBB9] hover:text-white'
                  }`}
                >
                  Período Actual (
                  {FinancialPeriodHelper.formatShortRange(fullPeriodRange)})
                </button>
                {userSettings.enableSplitPeriod && (
                  <>
                    <button
                      type="button"
                      onClick={() => setPeriodFilterMode('firstHalf')}
                      className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold transition-all ${
                        periodFilterMode === 'firstHalf'
                          ? 'bg-[#00DCF5] text-[#00363D] font-bold'
                          : 'bg-[#252525] text-[#BACBB9] hover:text-white'
                      }`}
                    >
                      Primera Mitad (
                      {FinancialPeriodHelper.formatShortRange(firstHalfRange)})
                    </button>
                    <button
                      type="button"
                      onClick={() => setPeriodFilterMode('secondHalf')}
                      className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold transition-all ${
                        periodFilterMode === 'secondHalf'
                          ? 'bg-[#00DCF5] text-[#00363D] font-bold'
                          : 'bg-[#252525] text-[#BACBB9] hover:text-white'
                      }`}
                    >
                      Segunda Mitad (
                      {FinancialPeriodHelper.formatShortRange(secondHalfRange)})
                    </button>
                  </>
                )}
                <button
                  type="button"
                  onClick={() => setPeriodFilterMode('custom')}
                  className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold transition-all ${
                    periodFilterMode === 'custom'
                      ? 'bg-[#75FF9E] text-[#003918] font-bold'
                      : 'bg-[#252525] text-[#BACBB9] hover:text-white'
                  }`}
                >
                  Personalizado
                </button>
              </div>
            </div>

            {/* 4 Key Metrics Summary Cards */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <div className="bg-[#1C1B1B] border border-white/5 p-5 rounded-xl flex flex-col justify-between">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-medium text-[#BACBB9]">
                    Gasto Total
                  </span>
                  <div className="w-8 h-8 rounded-lg bg-[#A00118]/30 flex items-center justify-center text-[#FFB3AE]">
                    <TrendingDown className="w-4 h-4" />
                  </div>
                </div>
                <div className="my-3 font-mono tabular-nums text-3xl font-bold text-white">
                  GTQ {summary.totalExpense.toLocaleString('en-US')}
                  <span className="text-lg text-[#BACBB9] font-normal">
                    .00
                  </span>
                </div>
                <div className="text-xs text-[#75FF9E]">
                  ↘ -12% <span className="text-[#BACBB9]">vs. mes anterior</span>
                </div>
              </div>

              <div className="bg-[#1C1B1B] border border-white/5 p-5 rounded-xl flex flex-col justify-between">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-medium text-[#BACBB9]">
                    Ingreso Total
                  </span>
                  <div className="w-8 h-8 rounded-lg bg-[#00E676]/20 flex items-center justify-center text-[#75FF9E]">
                    <TrendingUp className="w-4 h-4" />
                  </div>
                </div>
                <div className="my-3 font-mono tabular-nums text-3xl font-bold text-[#75FF9E]">
                  GTQ {summary.totalIncome.toLocaleString('en-US')}
                  <span className="text-lg text-[#75FF9E]/70 font-normal">
                    .00
                  </span>
                </div>
                <div className="text-xs text-[#75FF9E]">
                  ↗ +8% <span className="text-[#BACBB9]">vs. mes anterior</span>
                </div>
              </div>

              <div className="bg-[#1C1B1B] border border-white/5 p-5 rounded-xl flex flex-col justify-between">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-medium text-[#BACBB9]">
                    Gasto Promedio Diario
                  </span>
                  <div className="w-8 h-8 rounded-lg bg-[#00DCF5]/20 flex items-center justify-center text-[#A3F1FF]">
                    <Activity className="w-4 h-4" />
                  </div>
                </div>
                <div className="my-3 font-mono tabular-nums text-3xl font-bold text-white">
                  GTQ {(summary.totalExpense / 31).toFixed(0)}
                  <span className="text-lg text-[#BACBB9] font-normal">
                    .41
                  </span>
                </div>
                <div className="text-xs text-[#BACBB9]">
                  Ritmo proyectado: GTQ{' '}
                  {summary.totalExpense.toLocaleString('en-US')}
                </div>
              </div>

              <div className="bg-[#1C1B1B] border border-white/5 p-5 rounded-xl flex flex-col justify-between">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-medium text-[#BACBB9]">
                    Categoría Mayor Aumento
                  </span>
                  <div className="w-8 h-8 rounded-lg bg-[#A00118]/20 flex items-center justify-center text-[#FFB3AE]">
                    <Utensils className="w-4 h-4" />
                  </div>
                </div>
                <div className="my-3 text-xl font-bold text-white truncate">
                  Comida y Bebida
                </div>
                <div className="text-xs text-[#FFB3AE]">
                  ↗ +24%{' '}
                  <span className="text-[#BACBB9]">sobre la media histórica</span>
                </div>
              </div>
            </div>

            {/* Bento Visualizations: Daily Cash Flow (7 cols) + Spending Structure Donut (5 cols) */}
            <div className="grid grid-cols-1 xl:grid-cols-12 gap-6">
              <div className="xl:col-span-7 bg-[#1C1B1B] border border-white/5 p-6 rounded-xl flex flex-col justify-between">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-4">
                  <div>
                    <h2 className="text-lg font-bold text-white">
                      Flujo de Caja Diario
                    </h2>
                    <p className="text-xs text-[#BACBB9]">
                      Entradas y salidas monetarias distribuidas en los 31 días
                      de Octubre
                    </p>
                  </div>
                  <div className="flex items-center gap-4 text-xs">
                    <span className="flex items-center gap-1.5 text-[#BACBB9]">
                      <span className="w-2.5 h-2.5 rounded-full bg-[#75FF9E]" />
                      Ingresos (GTQ)
                    </span>
                    <span className="flex items-center gap-1.5 text-[#BACBB9]">
                      <span className="w-2.5 h-2.5 rounded-full bg-[#FFB3AE]" />
                      Gastos (GTQ)
                    </span>
                  </div>
                </div>

                {/* 31-Day SVG Bar Chart */}
                <div className="w-full h-64 pt-4">
                  <svg
                    className="w-full h-full overflow-visible"
                    preserveAspectRatio="none"
                    viewBox="0 0 620 220"
                  >
                    <defs>
                      <linearGradient id="incGrad" x1="0" x2="0" y1="0" y2="1">
                        <stop offset="0%" stopColor="#00e676" stopOpacity="0.95" />
                        <stop offset="100%" stopColor="#00612e" stopOpacity="0.3" />
                      </linearGradient>
                      <linearGradient id="expGrad" x1="0" x2="0" y1="0" y2="1">
                        <stop offset="0%" stopColor="#ffb3ae" stopOpacity="0.85" />
                        <stop offset="100%" stopColor="#a00118" stopOpacity="0.3" />
                      </linearGradient>
                    </defs>
                    <line
                      stroke="#353534"
                      strokeDasharray="3 3"
                      x1="0"
                      x2="620"
                      y1="55"
                      y2="55"
                    />
                    <line
                      stroke="#353534"
                      strokeDasharray="3 3"
                      x1="0"
                      x2="620"
                      y1="110"
                      y2="110"
                    />
                    <line
                      stroke="#353534"
                      strokeDasharray="3 3"
                      x1="0"
                      x2="620"
                      y1="165"
                      y2="165"
                    />
                    <line
                      stroke="#353534"
                      x1="0"
                      x2="620"
                      y1="210"
                      y2="210"
                    />
                    {dailyCashFlowData.length > 0 && (() => {
                      const maxDailyValue = Math.max(
                        1,
                        ...dailyCashFlowData.flatMap((bar) => [bar.inc, bar.exp])
                      );
                      return dailyCashFlowData.map((bar, idx) => {
                        const xBase = 12 + idx * 18;
                        const incHeight = (bar.inc / maxDailyValue) * 150;
                        const expHeight = (bar.exp / maxDailyValue) * 150;
                        return (
                          <g key={bar.date || `${bar.dayLabel}-${idx}`}>
                            {bar.inc > 0 && (
                              <rect
                                x={xBase}
                                y={210 - incHeight}
                                width="7"
                                height={incHeight}
                                rx="2"
                                fill="url(#incGrad)"
                              />
                            )}
                            <rect
                              x={bar.inc > 0 ? xBase + 9 : xBase}
                              y={210 - expHeight}
                              width="7"
                              height={expHeight}
                              rx="2"
                              fill="url(#expGrad)"
                            />
                          </g>
                        );
                      });
                    })()}
                  </svg>
                </div>

                <div className="flex justify-between font-mono text-[10px] text-[#BACBB9] pt-2">
                  <span>01 Oct</span>
                  <span>05 Oct</span>
                  <span>10 Oct</span>
                  <span>15 Oct (Catorcena)</span>
                  <span>20 Oct</span>
                  <span>25 Oct</span>
                  <span>31 Oct</span>
                </div>

                <div className="mt-4 bg-[#201F1F] p-3.5 rounded-xl flex items-center justify-between text-xs">
                  <span className="text-[#BACBB9]">
                    Superávit mensual en curso:{' '}
                    <strong className="text-[#75FF9E] font-mono">
                      +GTQ {summary.netCashFlow.toLocaleString('en-US')}.00
                    </strong>
                  </span>
                  <span className="font-mono text-[#BACBB9]">
                    Ratio Ahorro: {summary.savingsRate}%
                  </span>
                </div>
              </div>

              {/* Right 5 Cols: Spending Structure Donut */}
              <div className="xl:col-span-5 bg-[#1C1B1B] border border-white/5 p-6 rounded-xl flex flex-col justify-between">
                <div>
                  <h2 className="text-lg font-bold text-white">
                    Estructura de Gastos
                  </h2>
                  <p className="text-xs text-[#BACBB9]">
                    Distribución categórica del periodo
                  </p>
                </div>

                <div className="flex items-center justify-center my-4 relative">
                  <svg className="w-44 h-44 -rotate-90" viewBox="0 0 100 100">
                    <circle
                      cx="50"
                      cy="50"
                      fill="transparent"
                      r="40"
                      stroke="#2a2a2a"
                      strokeWidth="12"
                    />
                    <circle
                      cx="50"
                      cy="50"
                      fill="transparent"
                      r="40"
                      stroke="#00e676"
                      strokeDasharray="105.5 251.2"
                      strokeDashoffset="0"
                      strokeWidth="12"
                    />
                    <circle
                      cx="50"
                      cy="50"
                      fill="transparent"
                      r="40"
                      stroke="#00dcf5"
                      strokeDasharray="70.3 251.2"
                      strokeDashoffset="-105.5"
                      strokeWidth="12"
                    />
                    <circle
                      cx="50"
                      cy="50"
                      fill="transparent"
                      r="40"
                      stroke="#ffa8a3"
                      strokeDasharray="37.7 251.2"
                      strokeDashoffset="-175.8"
                      strokeWidth="12"
                    />
                    <circle
                      cx="50"
                      cy="50"
                      fill="transparent"
                      r="40"
                      stroke="#a3f1ff"
                      strokeDasharray="37.7 251.2"
                      strokeDashoffset="-213.5"
                      strokeWidth="12"
                    />
                  </svg>
                  <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
                    <span className="text-[10px] text-[#BACBB9] uppercase">
                      Total
                    </span>
                    <span className="text-base font-bold font-mono text-white">
                      GTQ 6.4k
                    </span>
                    <span className="text-[10px] font-mono text-[#75FF9E]">
                      100%
                    </span>
                  </div>
                </div>

                <div className="space-y-2.5 text-xs">
                  {[
                    {
                      name: 'Comida y Bebida',
                      sub: 'Restaurantes, compras súper',
                      amt: 'GTQ 2,700.60',
                      pct: '42%',
                      dot: 'bg-[#00E676]',
                    },
                    {
                      name: 'Servicios e Internet',
                      sub: 'Luz, Agua, Fibra, Celular',
                      amt: 'GTQ 1,800.40',
                      pct: '28%',
                      dot: 'bg-[#00DCF5]',
                    },
                    {
                      name: 'Transporte y Gasolina',
                      sub: 'Combustible, peajes, parqueo',
                      amt: 'GTQ 964.50',
                      pct: '15%',
                      dot: 'bg-[#FFA8A3]',
                    },
                    {
                      name: 'Entretenimiento',
                      sub: 'Streaming, salidas de ocio',
                      amt: 'GTQ 964.50',
                      pct: '15%',
                      dot: 'bg-[#A3F1FF]',
                    },
                  ].map((item) => (
                    <div
                      key={item.name}
                      className="flex items-center justify-between p-2 rounded-lg hover:bg-[#201F1F]"
                    >
                      <div className="flex items-center gap-2.5">
                        <span className={`w-3 h-3 rounded-full ${item.dot}`} />
                        <div>
                          <div className="font-semibold text-white">
                            {item.name}
                          </div>
                          <div className="text-[11px] text-[#BACBB9]">
                            {item.sub}
                          </div>
                        </div>
                      </div>
                      <div className="text-right font-mono">
                        <div className="font-semibold text-white">
                          {item.amt}
                        </div>
                        <div className="text-[11px] text-[#75FF9E]">
                          {item.pct}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Active Budgets Section */}
            <div className="bg-[#1C1B1B] border border-white/5 p-6 rounded-xl space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-lg font-bold text-white">
                    Resumen de Presupuestos Activos
                  </h2>
                  <p className="text-xs text-[#BACBB9]">
                    Monitoreo de topes de gasto configurados para el mes actual
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => setActiveTab('presupuestos')}
                  className="text-xs font-semibold text-[#75FF9E] hover:underline"
                >
                  Gestionar todos los presupuestos →
                </button>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                {budgets.map((b) => {
                  const pct = Math.min(
                    100,
                    Math.round((b.spentAmount / b.limitAmount) * 100)
                  );
                  const remaining = Math.max(0, b.limitAmount - b.spentAmount);
                  return (
                    <div
                      key={b.id}
                      className="bg-[#201F1F] p-4 rounded-xl flex flex-col justify-between border border-white/5"
                    >
                      <div className="flex items-start justify-between">
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 rounded-xl bg-[#2A2A2A] flex items-center justify-center text-[#00DCF5]">
                            {renderCategoryIcon(b.iconName)}
                          </div>
                          <div>
                            <div className="text-sm font-bold text-white">
                              {b.name}
                            </div>
                            <div className="text-xs text-[#BACBB9]">
                              {pct >= 90
                                ? 'Alerta de sobregiro'
                                : 'Ritmo óptimo'}
                            </div>
                          </div>
                        </div>
                        <span className="font-mono text-xs font-bold text-[#75FF9E]">
                          {pct}%
                        </span>
                      </div>

                      <div className="my-4">
                        <div className="flex justify-between items-baseline mb-1.5 text-xs font-mono">
                          <span className="font-bold text-white">
                            GTQ {b.spentAmount.toFixed(2)}
                          </span>
                          <span className="text-[#BACBB9]">
                            de GTQ {b.limitAmount.toFixed(2)}
                          </span>
                        </div>
                        <div className="w-full h-2 rounded-full bg-[#353534] overflow-hidden">
                          <div
                            className={`h-full rounded-full ${
                              pct >= 90
                                ? 'bg-[#FFB3AE]'
                                : pct >= 70
                                ? 'bg-[#00DCF5]'
                                : 'bg-[#75FF9E]'
                            }`}
                            style={{ width: `${pct}%` }}
                          />
                        </div>
                      </div>

                      <div className="flex items-center justify-between text-[11px] text-[#BACBB9]">
                        <span>
                          Disponible:{' '}
                          <strong className="text-white font-mono">
                            GTQ {remaining.toFixed(2)}
                          </strong>
                        </span>
                        <span>11 días restantes</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Detailed Category Table Breakdown */}
            <div className="bg-[#1C1B1B] border border-white/5 p-6 rounded-xl space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-lg font-bold text-white">
                    Desglose Detallado por Rubro
                  </h2>
                  <p className="text-xs text-[#BACBB9]">
                    Comparativo de ejecución mensual frente a las asignaciones
                    de referencia
                  </p>
                </div>
                <span className="text-xs text-[#BACBB9]">
                  Orden: Mayor Impacto
                </span>
              </div>

              <div className="overflow-x-auto">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="bg-[#201F1F] text-[11px] font-semibold text-[#BACBB9] uppercase tracking-wider">
                      <th className="py-3 px-4 rounded-l-lg">Categoría</th>
                      <th className="py-3 px-4">Transacciones</th>
                      <th className="py-3 px-4 text-right">Gasto Total</th>
                      <th className="py-3 px-4 text-right">Porcentaje</th>
                      <th className="py-3 px-4">Relación Presupuesto</th>
                      <th className="py-3 px-4 text-right rounded-r-lg">
                        Acciones
                      </th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/5 text-sm">
                    {[
                      {
                        name: 'Comida y Bebida',
                        sub: 'Supermercados, cafeterías, delivery',
                        icon: 'utensils',
                        movs: '24 movs.',
                        total: 'GTQ 2,700.60',
                        pct: '42.0%',
                        rel: 'Q 2.7k / Q 3.2k',
                        bar: 84,
                        color: 'bg-[#75FF9E]',
                      },
                      {
                        name: 'Servicios e Internet',
                        sub: 'Telecomunicaciones y luz eléctrica',
                        icon: 'wifi',
                        movs: '6 movs.',
                        total: 'GTQ 1,800.40',
                        pct: '28.0%',
                        rel: 'Q 1.8k / Q 2.0k',
                        bar: 90,
                        color: 'bg-[#FFB3AE]',
                      },
                      {
                        name: 'Transporte y Gasolina',
                        sub: 'Estaciones de servicio y TAG peajes',
                        icon: 'fuel',
                        movs: '8 movs.',
                        total: 'GTQ 964.50',
                        pct: '15.0%',
                        rel: 'Q 0.96k / Q 1.5k',
                        bar: 64,
                        color: 'bg-[#75FF9E]',
                      },
                      {
                        name: 'Entretenimiento & Suscripciones',
                        sub: 'Cine, Spotify, eventos culturales',
                        icon: 'film',
                        movs: '5 movs.',
                        total: 'GTQ 964.50',
                        pct: '15.0%',
                        rel: 'Q 0.96k / Q 1.2k',
                        bar: 80,
                        color: 'bg-[#00DCF5]',
                      },
                    ].map((row) => (
                      <tr
                        key={row.name}
                        className="hover:bg-[#201F1F]/60 transition-colors"
                      >
                        <td className="py-3.5 px-4">
                          <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-lg bg-[#252525] flex items-center justify-center text-[#75FF9E]">
                              {renderCategoryIcon(row.icon)}
                            </div>
                            <div>
                              <span className="font-semibold text-white block">
                                {row.name}
                              </span>
                              <span className="text-xs text-[#BACBB9]">
                                {row.sub}
                              </span>
                            </div>
                          </div>
                        </td>
                        <td className="py-3.5 px-4 text-xs font-mono text-[#BACBB9]">
                          {row.movs}
                        </td>
                        <td className="py-3.5 px-4 text-right font-mono font-bold tabular-nums text-white">
                          {row.total}
                        </td>
                        <td className="py-3.5 px-4 text-right font-mono text-xs text-[#75FF9E]">
                          {row.pct}
                        </td>
                        <td className="py-3.5 px-4">
                          <div className="w-36">
                            <div className="flex justify-between text-[11px] font-mono text-[#BACBB9] mb-1">
                              <span>{row.rel}</span>
                              <span>{row.bar}%</span>
                            </div>
                            <div className="w-full h-1.5 bg-[#353534] rounded-full overflow-hidden">
                              <div
                                className={`h-full rounded-full ${row.color}`}
                                style={{ width: `${row.bar}%` }}
                              />
                            </div>
                          </div>
                        </td>
                        <td className="py-3.5 px-4 text-right">
                          <button
                            type="button"
                            onClick={() => setActiveTab('registros')}
                            className="p-1.5 rounded-lg hover:bg-[#2A2A2A] text-[#BACBB9] hover:text-white"
                            title="Ver movimientos"
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* ==================== VIEW 3: REGISTROS (HISTORIAL COMPLETO) ==================== */}
        {activeTab === 'registros' && (
          <div className="space-y-6">
            <div className="bg-[#1C1B1B] border border-white/5 rounded-2xl p-6 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div>
                <h1 className="text-2xl font-bold text-white">
                  Registros e Historial de Transacciones
                </h1>
                <p className="text-xs text-[#BACBB9] mt-1">
                  Consulta y gestiona el historial detallado de tus ingresos, gastos y transferencias.
                </p>
              </div>
              <div className="flex items-center gap-2.5">
                <button
                  type="button"
                  onClick={handleExportCSV}
                  className="px-4 py-2.5 rounded-xl bg-[#252525] hover:bg-[#2E2E2E] text-xs font-semibold text-white flex items-center gap-2"
                >
                  <Download className="w-4 h-4 text-[#00DCF5]" />
                  <span>Exportar CSV</span>
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setCalcInitialType('expense');
                    setIsCalcOpen(true);
                  }}
                  className="px-4 py-2.5 rounded-xl bg-[#00E676] hover:bg-[#62FF96] text-[#003918] text-xs font-bold flex items-center gap-1.5"
                >
                  <Plus className="w-4 h-4" />
                  <span>Nueva Transacción</span>
                </button>
              </div>
            </div>

            <div className="bg-[#1C1B1B] border border-white/5 rounded-2xl p-6 space-y-4">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div className="relative flex-1 min-w-[240px]">
                  <Search className="w-4 h-4 text-[#BACBB9] absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type="search"
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    placeholder="Buscar por comercio, nota, cuenta o categoría..."
                    className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-[#252525] text-xs text-white placeholder-[#BACBB9]/60 border border-white/5 focus:border-[#00E676] focus:outline-none"
                  />
                </div>
                <div className="flex items-center gap-2">
                  <select
                    value={selectedAccountFilter}
                    onChange={(e) => setSelectedAccountFilter(e.target.value)}
                    className="bg-[#252525] text-xs text-white px-3 py-2.5 rounded-xl border border-white/5 focus:outline-none"
                  >
                    <option value="all">Todas las Cuentas</option>
                    {accounts.map((a) => (
                      <option key={a.id} value={a.id}>
                        {a.name}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="divide-y divide-white/5">
                {filteredTransactions.map((tx) => {
                  const isInc = tx.type === 'income';
                  return (
                    <div
                      key={tx.id}
                      className="py-3.5 px-2 flex items-center justify-between hover:bg-[#252525]/50 rounded-xl transition-colors"
                    >
                      <div className="flex items-center gap-3.5 min-w-0">
                        <div
                          className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 ${
                            isInc
                              ? 'bg-[#00E676]/15 text-[#75FF9E]'
                              : 'bg-[#A00118]/25 text-[#FFB3AE]'
                          }`}
                        >
                          {renderCategoryIcon(tx.categoryIcon)}
                        </div>
                        <div className="min-w-0">
                          <div className="text-sm font-semibold text-white truncate">
                            {tx.note}
                          </div>
                          <div className="text-xs text-[#BACBB9] flex items-center gap-1.5 flex-wrap mt-0.5">
                            <span>{tx.accountName}</span>
                            <span>·</span>
                            <span>{tx.categoryName}</span>
                            {tx.subcategory && (
                              <span className="px-1.5 py-0.5 rounded bg-[#00DCF5]/10 text-[10px] text-[#00DCF5] font-semibold border border-[#00DCF5]/20">
                                {tx.subcategory}
                              </span>
                            )}
                            <span>·</span>
                            <span>
                              {new Date(tx.dateIso).toLocaleString('es-GT', {
                                dateStyle: 'medium',
                                timeStyle: 'short',
                              })}
                            </span>
                          </div>
                        </div>
                      </div>

                      <div className="flex items-center gap-2 shrink-0">
                        <span
                          className={`font-mono font-bold tabular-nums text-sm mr-1 ${
                            isInc
                              ? 'text-[#75FF9E]'
                              : tx.type === 'transfer'
                              ? 'text-[#00DCF5]'
                              : 'text-[#FFB3AE]'
                          }`}
                        >
                          {isInc ? '+' : tx.type === 'transfer' ? '⇄ ' : '-'}GTQ{' '}
                          {tx.amount.toFixed(2)}
                        </span>
                        <button
                          type="button"
                          onClick={() => {
                            setEditingTransaction(tx);
                            setIsCalcOpen(true);
                          }}
                          className="p-1.5 rounded-lg hover:bg-[#00DCF5]/20 text-[#BACBB9] hover:text-[#00DCF5]"
                          title="Editar y cuadrar saldo"
                        >
                          <Edit3 className="w-4 h-4" />
                        </button>
                        <button
                          type="button"
                          onClick={() => handleDeleteTransaction(tx)}
                          className="p-1.5 rounded-lg hover:bg-[#A00118]/40 text-[#BACBB9] hover:text-[#FFB3AE]"
                          title="Eliminar y revertir saldo"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        )}

        {/* ==================== VIEW 4: CUENTAS ==================== */}
        {activeTab === 'cuentas' && (
          <div className="space-y-6">
            <div className="bg-[#1C1B1B] border border-white/5 rounded-2xl p-6 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div>
                <h1 className="text-2xl font-bold text-white flex items-center gap-2">
                  <CreditCard className="w-6 h-6 text-[#00DCF5]" />
                  <span>Mis Cuentas en Wallet</span>
                </h1>
                <p className="text-xs text-[#BACBB9] mt-1">
                  Administra tus cuentas bancarias, billeteras de efectivo y tarjetas.
                </p>
              </div>
              <button
                type="button"
                onClick={() => setIsAddAccountOpen(true)}
                className="px-4 py-2.5 rounded-xl bg-[#00E676] hover:bg-[#62FF96] text-[#003918] font-bold text-xs flex items-center gap-1.5 transition-colors whitespace-nowrap"
              >
                <Plus className="w-4 h-4" />
                <span>+ Agregar Cuenta</span>
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
              {accounts.map((acc) => (
                <div
                  key={acc.id}
                  className="bg-[#1C1B1B] border border-white/5 rounded-2xl p-6 flex flex-col justify-between space-y-4 hover:border-white/15 transition-colors"
                >
                  <div className="flex items-start justify-between">
                    <div>
                      <span className="text-xs uppercase tracking-wider text-[#BACBB9]">
                        {acc.type}
                      </span>
                      <h3 className="text-lg font-bold text-white mt-0.5">
                        {acc.name}
                      </h3>
                      <p className="text-xs text-[#A0A0A0] mt-0.5">
                        {acc.subtitle}
                      </p>
                    </div>
                    <div className="flex items-center gap-1.5">
                      <button
                        type="button"
                        onClick={() => handleOpenEditAccount(acc)}
                        className="p-1.5 rounded-lg hover:bg-[#00DCF5]/20 text-[#BACBB9] hover:text-[#00DCF5] transition-colors"
                        title="Editar cuenta"
                      >
                        <Edit3 className="w-4 h-4" />
                      </button>
                      <button
                        type="button"
                        onClick={() => handleDeleteAccount(acc)}
                        className="p-1.5 rounded-lg hover:bg-[#A00118]/40 text-[#BACBB9] hover:text-[#FFB3AE] transition-colors"
                        title="Eliminar cuenta"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                  <div
                    className={`text-2xl font-bold font-mono tabular-nums ${
                      acc.balance < 0 ? 'text-[#FFB3AE]' : 'text-[#75FF9E]'
                    }`}
                  >
                    {acc.balance < 0 ? '-' : ''}GTQ{' '}
                    {Math.abs(acc.balance).toLocaleString('en-US', {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2,
                    })}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* ==================== VIEW: CATEGORÍAS Y SUBCATEGORÍAS ==================== */}
        {activeTab === 'categorias' && (
          <div className="space-y-6">
            <div className="bg-[#1C1B1B] border border-white/5 rounded-2xl p-6 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div>
                <h1 className="text-2xl font-bold text-white flex items-center gap-2">
                  <Layers className="w-6 h-6 text-[#00E676]" />
                  <span>Categorías y Subcategorías</span>
                </h1>
                <p className="text-xs text-[#BACBB9] mt-1">
                  Gestiona tus rubros de gasto e ingreso y las subcategorías que se despliegan al registrar transacciones.
                </p>
              </div>
              <div className="flex items-center gap-2.5">
                <div className="flex items-center bg-[#252525] p-1 rounded-xl">
                  {(['all', 'expense', 'income'] as const).map((tab) => (
                    <button
                      key={tab}
                      type="button"
                      onClick={() => setCatFilterTab(tab)}
                      className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                        catFilterTab === tab ? 'bg-[#353534] text-white shadow-sm' : 'text-[#BACBB9] hover:text-white'
                      }`}
                    >
                      {tab === 'all' ? 'Todas' : tab === 'expense' ? 'Gastos' : 'Ingresos'}
                    </button>
                  ))}
                </div>
                <button
                  type="button"
                  onClick={handleRestoreDefaultCategories}
                  className="px-3 py-2 rounded-xl bg-[#252525] hover:bg-[#303030] text-xs font-semibold text-[#BACBB9] hover:text-white border border-white/5 transition-colors whitespace-nowrap"
                  title="Restablece las categorías y subcategorías genéricas estándar (tanto de ingresos como de gastos)"
                >
                  Restablecer Estándar
                </button>
                <button
                  type="button"
                  onClick={handleOpenAddCategory}
                  className="px-4 py-2.5 rounded-xl bg-[#00E676] hover:bg-[#62FF96] text-[#003918] font-bold text-xs flex items-center gap-1.5 transition-colors whitespace-nowrap"
                >
                  <Plus className="w-4 h-4" />
                  <span>+ Nueva Categoría</span>
                </button>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
              {categories
                .filter((c) => catFilterTab === 'all' || c.type === catFilterTab)
                .map((cat) => (
                  <div
                    key={cat.id}
                    className="bg-[#1C1B1B] border border-white/5 rounded-2xl p-5 flex flex-col justify-between space-y-4 hover:border-white/15 transition-colors"
                  >
                    <div>
                      <div className="flex items-start justify-between">
                        <div className="flex items-center gap-3">
                          <div
                            className="w-12 h-12 rounded-2xl flex items-center justify-center shrink-0"
                            style={{ backgroundColor: `${cat.colorHex}25`, color: cat.colorHex }}
                          >
                            {renderCategoryIcon(cat.iconName)}
                          </div>
                          <div>
                            <div className="flex items-center gap-2">
                              <h3 className="text-base font-bold text-white">{cat.name}</h3>
                              <span
                                className={`text-[10px] uppercase font-bold px-2 py-0.5 rounded-full ${
                                  cat.type === 'income' ? 'bg-[#00E676]/20 text-[#75FF9E]' : 'bg-[#FF5252]/20 text-[#FFB3AE]'
                                }`}
                              >
                                {cat.type === 'income' ? 'Ingreso' : 'Gasto'}
                              </span>
                            </div>
                            <p className="text-xs text-[#A0A0A0] mt-0.5">{cat.subtitle}</p>
                          </div>
                        </div>
                        <div className="flex items-center gap-1">
                          <button
                            type="button"
                            onClick={() => handleOpenEditCategory(cat)}
                            className="p-1.5 rounded-lg hover:bg-[#00DCF5]/20 text-[#BACBB9] hover:text-[#00DCF5] transition-colors"
                            title="Editar categoría y subcategorías"
                          >
                            <Edit3 className="w-4 h-4" />
                          </button>
                          <button
                            type="button"
                            onClick={() => handleDeleteCategory(cat)}
                            className="p-1.5 rounded-lg hover:bg-[#A00118]/40 text-[#BACBB9] hover:text-[#FFB3AE] transition-colors"
                            title="Eliminar categoría"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </div>

                      {/* Subcategories Chip List */}
                      <div className="mt-4 pt-3 border-t border-white/5">
                        <div className="flex items-center justify-between mb-2">
                          <span className="text-[11px] font-semibold text-[#BACBB9] uppercase tracking-wider flex items-center gap-1">
                            <Tag className="w-3 h-3 text-[#00DCF5]" /> Subcategorías ({(cat.subcategories || []).length})
                          </span>
                        </div>
                        <div className="flex flex-wrap gap-1.5">
                          {(cat.subcategories || []).map((sub) => (
                            <span
                              key={sub}
                              className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-[#2A2A2A] text-xs text-[#E5E2E1] border border-white/5"
                            >
                              <span>{sub}</span>
                            </span>
                          ))}
                          {(cat.subcategories || []).length === 0 && (
                            <span className="text-xs text-[#707070] italic">Sin subcategorías específicas (Usa General)</span>
                          )}
                        </div>
                      </div>
                    </div>

                    {/* Quick Add Subcategory Input */}
                    <div className="pt-2">
                      <div className="flex items-center gap-1.5">
                        <input
                          type="text"
                          placeholder="+ Añadir subcategoría..."
                          onKeyDown={(e) => {
                            if (e.key === 'Enter') {
                              const val = (e.target as HTMLInputElement).value;
                              if (val.trim()) {
                                handleQuickAddSubcategoryToCategory(cat, val);
                                (e.target as HTMLInputElement).value = '';
                              }
                            }
                          }}
                          className="flex-1 bg-[#141414] border border-white/10 rounded-lg px-2.5 py-1.5 text-xs text-white placeholder-[#707070] focus:outline-none focus:border-[#00E676]"
                        />
                      </div>
                    </div>
                  </div>
                ))}
            </div>
          </div>
        )}

        {/* ==================== VIEW 5: PRESUPUESTOS ==================== */}
        {activeTab === 'presupuestos' && (
          <div className="space-y-6">
            <div className="bg-[#1C1B1B] border border-white/5 rounded-2xl p-6 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div>
                <h1 className="text-2xl font-bold text-white">
                  Presupuestos Mensuales y Topes de Gasto
                </h1>
                <p className="text-xs text-[#BACBB9] mt-1">
                  Controla tus límites de gasto mensual por categoría y período financiero.
                </p>
              </div>
              <button
                type="button"
                onClick={() => {
                  setNewBudgetPeriod(activeFirestorePeriodId);
                  setIsAddBudgetOpen(true);
                }}
                className="px-4 py-2.5 rounded-xl bg-[#00E676] hover:bg-[#62FF96] text-[#003918] font-bold text-xs flex items-center gap-1.5 transition-colors whitespace-nowrap"
              >
                <Plus className="w-4 h-4" />
                <span>+ Nuevo Presupuesto</span>
              </button>
            </div>

            {budgets.length === 0 ? (
              <div className="bg-[#1C1B1B] border border-white/5 rounded-2xl p-12 text-center">
                <div className="w-14 h-14 rounded-2xl bg-[#00E676]/10 text-[#00E676] flex items-center justify-center mx-auto mb-4">
                  <Wallet className="w-7 h-7" />
                </div>
                <h3 className="text-lg font-bold text-white">No tienes presupuestos creados aún</h3>
                <p className="text-xs text-[#BACBB9] max-w-md mx-auto mt-1 mb-5">
                  Establece un límite de gasto mensual para rubros como Supermercado, Gasolina o Servicios para mantener tus finanzas bajo control.
                </p>
                <button
                  type="button"
                  onClick={() => {
                    setNewBudgetPeriod(activeFirestorePeriodId);
                    setIsAddBudgetOpen(true);
                  }}
                  className="px-5 py-2.5 rounded-xl bg-[#00E676] text-[#003918] font-bold text-xs inline-flex items-center gap-2"
                >
                  <Plus className="w-4 h-4" />
                  <span>Crear mi primer presupuesto</span>
                </button>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
                {budgets.map((b) => {
                  const matchingCategory = categories.find((c) => c.id === b.categoryId);
                  const dynamicSpent = transactions
                    .filter((t) => t.categoryId === b.categoryId && t.type === 'expense' && (t.periodId === b.period || t.yearMonth === b.period))
                    .reduce((acc, t) => acc + t.amount, 0);
                  const displaySpent = dynamicSpent > 0 ? dynamicSpent : b.spentAmount;
                  const pct = Math.min(100, Math.round((displaySpent / b.limitAmount) * 100));

                  return (
                    <div
                      key={b.id}
                      className="bg-[#1C1B1B] border border-white/5 rounded-2xl p-6 space-y-4 hover:border-white/15 transition-colors"
                    >
                      <div className="flex items-start justify-between">
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="text-base font-bold text-white">{b.name}</span>
                            <span className="text-[10px] font-mono font-bold px-2 py-0.5 rounded-full bg-[#00DCF5]/10 text-[#00DCF5] border border-[#00DCF5]/20">
                              {b.period || activeFirestorePeriodId}
                            </span>
                          </div>
                          <span className="text-xs text-[#BACBB9] mt-0.5 block">
                            {matchingCategory?.name || 'Categoría vinculada'}
                          </span>
                        </div>
                        <div className="flex items-center gap-1">
                          <button
                            type="button"
                            onClick={() => handleOpenEditBudget(b)}
                            className="p-1.5 rounded-lg hover:bg-[#00DCF5]/20 text-[#BACBB9] hover:text-[#00DCF5] transition-colors"
                            title="Editar presupuesto"
                          >
                            <Edit3 className="w-4 h-4" />
                          </button>
                          <button
                            type="button"
                            onClick={() => handleDeleteBudget(b)}
                            className="p-1.5 rounded-lg hover:bg-[#A00118]/40 text-[#BACBB9] hover:text-[#FFB3AE] transition-colors"
                            title="Eliminar presupuesto"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </div>

                      <div className="flex justify-between items-baseline text-xs font-mono text-[#BACBB9]">
                        <span>Gastado: GTQ {displaySpent.toFixed(2)}</span>
                        <span className={`font-bold ${pct >= 90 ? 'text-[#FFB3AE]' : 'text-[#75FF9E]'}`}>
                          Límite: GTQ {b.limitAmount.toFixed(2)} ({pct}%)
                        </span>
                      </div>
                      <div className="w-full h-2.5 rounded-full bg-[#353534] overflow-hidden">
                        <div
                          className={`h-full rounded-full transition-all ${
                            pct >= 90
                              ? 'bg-[#FFB3AE]'
                              : pct >= 70
                              ? 'bg-[#00DCF5]'
                              : 'bg-[#75FF9E]'
                          }`}
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}

      </main>

      {deleteConfirmTarget && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/75 backdrop-blur-sm p-4">
          <div className="w-full max-w-md bg-[#1E1E1E] border border-white/10 rounded-2xl p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-bold text-white">Confirmar eliminación</h3>
              <button
                type="button"
                onClick={() => setDeleteConfirmTarget(null)}
                className="p-1 text-[#A0A0A0] hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <p className="text-sm text-[#BACBB9]">
              ¿Deseas eliminar <span className="font-semibold text-white">{deleteConfirmTarget.name}</span>?
            </p>
            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setDeleteConfirmTarget(null)}
                className="px-4 py-2 rounded-xl bg-[#252525] text-xs font-semibold text-[#BACBB9]"
              >
                Cancelar
              </button>
              <button
                type="button"
                onClick={handleDeleteTarget}
                className="px-5 py-2 rounded-xl bg-[#A00118] text-white text-xs font-bold"
              >
                Eliminar
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Footer */}
      <footer className="w-full bg-[#0E0E0E] border-t border-white/5 py-5 mt-12">
        <div className="max-w-[1480px] mx-auto px-4 lg:px-8 flex flex-col sm:flex-row items-center justify-between gap-2 text-xs text-[#BACBB9]">
          <div className="flex items-center gap-2">
            <Lock className="w-3.5 h-3.5 text-[#75FF9E]" />
            <span>Seguridad y privacidad garantizada · Cifrado en la nube</span>
          </div>
          <div>
            © 2026 Wallet. Todos los derechos reservados.
          </div>
        </div>
      </footer>

      {/* Modal 1: BudgetBakers Calculator New / Edit Transaction Modal (#00ACC1) */}
      <NewTransactionModal
        isOpen={isCalcOpen}
        onClose={() => {
          setIsCalcOpen(false);
          setEditingTransaction(null);
        }}
        accounts={accounts}
        categories={categories}
        initialType={calcInitialType}
        editingTransaction={editingTransaction}
        onSaveTransaction={handleSaveTransaction}
      />

      {/* Modal 1B: Dynamic Financial Period Configuration Modal (UserSettingsModel) */}
      {isPeriodSettingsModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4">
          <form
            onSubmit={handleSavePeriodSettings}
            className="w-full max-w-md bg-[#1E1E1E] border border-white/10 rounded-2xl p-6 space-y-4"
          >
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-lg font-bold text-white">
                  Configurar Ciclo Financiero y Quincenas
                </h3>
                <p className="text-xs text-[#BACBB9] mt-0.5">
                  Ajusta tu día de corte de mes y división en dos quincenas.
                </p>
              </div>
              <button
                type="button"
                onClick={() => setIsPeriodSettingsModalOpen(false)}
                className="p-1 text-[#A0A0A0] hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div>
              <label className="block text-xs text-[#BACBB9] mb-1">
                Día de inicio del período financiero (startDayOfMonth: 1 - 31)
              </label>
              <input
                type="number"
                min={1}
                max={31}
                value={userSettings.startDayOfMonth}
                onChange={(e) =>
                  setUserSettings((prev) => ({
                    ...prev,
                    startDayOfMonth: Number(e.target.value),
                  }))
                }
                className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm font-mono text-white border border-white/10 focus:border-[#00DCF5] focus:outline-none"
              />
              <span className="text-[11px] text-[#A0A0A0] mt-1 block">
                Ej. Si te pagan el 27, el 27 de octubre inicia el período
                financiero <strong>2026-11 (period_2026_11)</strong>.
              </span>
            </div>

            <div className="flex items-center justify-between p-3 rounded-xl bg-[#252525] border border-white/5">
              <div>
                <div className="text-xs font-semibold text-white">
                  Dividir período en dos quincenas (enableSplitPeriod)
                </div>
                <div className="text-[11px] text-[#BACBB9]">
                  Habilita filtros de Primera Mitad y Segunda Mitad
                </div>
              </div>
              <input
                type="checkbox"
                checked={userSettings.enableSplitPeriod}
                onChange={(e) =>
                  setUserSettings((prev) => ({
                    ...prev,
                    enableSplitPeriod: e.target.checked,
                  }))
                }
                className="w-4 h-4 accent-[#00E676] rounded cursor-pointer"
              />
            </div>

            {userSettings.enableSplitPeriod && (
              <div>
                <label className="block text-xs text-[#BACBB9] mb-1">
                  Día de inicio de la Segunda Quincena (midMonthDay: 1 - 31)
                </label>
                <input
                  type="number"
                  min={1}
                  max={31}
                  value={userSettings.midMonthDay}
                  onChange={(e) =>
                    setUserSettings((prev) => ({
                      ...prev,
                      midMonthDay: Number(e.target.value),
                    }))
                  }
                  className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm font-mono text-white border border-white/10 focus:border-[#00DCF5] focus:outline-none"
                />
                <span className="text-[11px] text-[#A0A0A0] mt-1 block">
                  Ej. Día 13 divide el ciclo en Primera Mitad (27 Oct - 12 Nov)
                  y Segunda Mitad (13 Nov - 26 Nov).
                </span>
              </div>
            )}

            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setIsPeriodSettingsModalOpen(false)}
                className="px-4 py-2 rounded-xl bg-[#252525] text-xs font-semibold text-[#BACBB9]"
              >
                Cancelar
              </button>
              <button
                type="submit"
                className="px-5 py-2 rounded-xl bg-[#00E676] text-[#003918] text-xs font-bold"
              >
                Guardar Configuración
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Modal 2: Create Account Modal */}
      {isAddAccountOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4">
          <form
            onSubmit={handleCreateAccount}
            className="w-full max-w-md bg-[#1E1E1E] border border-white/10 rounded-2xl p-6 space-y-4"
          >
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-bold text-white">
                Agregar Cuenta o Tarjeta
              </h3>
              <button
                type="button"
                onClick={() => setIsAddAccountOpen(false)}
                className="p-1 text-[#A0A0A0] hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <div>
              <label className="block text-xs text-[#BACBB9] mb-1">
                Nombre de la cuenta (ej. Banrural, Promerica, Efectivo)
              </label>
              <input
                type="text"
                required
                maxLength={80}
                value={newAccName}
                onChange={(e) => setNewAccName(e.target.value)}
                placeholder="Ej. Tarjeta Visa BAC"
                className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10 focus:border-[#00E676] focus:outline-none"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs text-[#BACBB9] mb-1">
                  Tipo de cuenta
                </label>
                <select
                  value={newAccType}
                  onChange={(e) => setNewAccType(e.target.value as AccountType)}
                  className="w-full px-3 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10"
                >
                  <option value="bank">Cuenta Bancaria</option>
                  <option value="cash">Efectivo</option>
                  <option value="credit_card">Tarjeta de Crédito</option>
                  <option value="savings">Ahorros</option>
                </select>
              </div>
              <div>
                <label className="block text-xs text-[#BACBB9] mb-1">
                  Saldo inicial (GTQ)
                </label>
                <input
                  type="number"
                  step="0.01"
                  value={newAccBalance}
                  onChange={(e) => setNewAccBalance(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm font-mono text-white border border-white/10"
                />
              </div>
            </div>
            <div>
              <label className="block text-xs text-[#BACBB9] mb-1">
                Descripción corta / Número o corte
              </label>
              <input
                type="text"
                maxLength={100}
                value={newAccSubtitle}
                onChange={(e) => setNewAccSubtitle(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10"
              />
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setIsAddAccountOpen(false)}
                className="px-4 py-2 rounded-xl bg-[#252525] text-xs font-semibold text-[#BACBB9]"
              >
                Cancelar
              </button>
              <button
                type="submit"
                className="px-5 py-2 rounded-xl bg-[#00E676] text-[#003918] text-xs font-bold"
              >
                Guardar Cuenta
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Modal 3: Create Budget Modal */}
      {isAddBudgetOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4">
          <form
            onSubmit={handleCreateBudget}
            className="w-full max-w-md bg-[#1E1E1E] border border-white/10 rounded-2xl p-6 space-y-4"
          >
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-bold text-white">
                Configurar Nuevo Presupuesto
              </h3>
              <button
                type="button"
                onClick={() => setIsAddBudgetOpen(false)}
                className="p-1 text-[#A0A0A0] hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <div>
              <label className="block text-xs text-[#BACBB9] mb-1">
                Nombre del presupuesto
              </label>
              <input
                type="text"
                required
                maxLength={80}
                value={newBudgetName}
                onChange={(e) => setNewBudgetName(e.target.value)}
                placeholder="Ej. Salidas de Fin de Semana"
                className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs text-[#BACBB9] mb-1">
                  Categoría asociada
                </label>
                <select
                  value={newBudgetCategory}
                  onChange={(e) => setNewBudgetCategory(e.target.value)}
                  className="w-full px-3 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10"
                >
                  {categories.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-xs text-[#BACBB9] mb-1">
                  Tope Mensual (GTQ)
                </label>
                <input
                  type="number"
                  step="any"
                  min="0.01"
                  value={newBudgetLimit}
                  onChange={(e) => setNewBudgetLimit(e.target.value)}
                  placeholder="Ej. 1000.00"
                  className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm font-mono text-white border border-white/10 focus:border-[#00E676] focus:outline-none"
                />
              </div>
            </div>
            <div>
              <label className="block text-xs text-[#BACBB9] mb-1">
                Período Financiero Asociado
              </label>
              <input
                type="text"
                value={newBudgetPeriod || activeFirestorePeriodId}
                onChange={(e) => setNewBudgetPeriod(e.target.value)}
                placeholder="period_2026_11"
                className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm font-mono text-[#75FF9E] border border-white/10"
              />
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setIsAddBudgetOpen(false)}
                className="px-4 py-2 rounded-xl bg-[#252525] text-xs font-semibold text-[#BACBB9]"
              >
                Cancelar
              </button>
              <button
                type="submit"
                className="px-5 py-2 rounded-xl bg-[#00E676] text-[#003918] text-xs font-bold"
              >
                Crear Presupuesto
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Modal: Edit Account Modal */}
      {isEditAccountOpen && editingAccount && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4">
          <form
            onSubmit={handleUpdateAccount}
            className="w-full max-w-md bg-[#1E1E1E] border border-white/10 rounded-2xl p-6 space-y-4"
          >
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-bold text-white">Editar Cuenta</h3>
              <button
                type="button"
                onClick={() => setIsEditAccountOpen(false)}
                className="p-1 text-[#A0A0A0] hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <div>
              <label className="block text-xs text-[#BACBB9] mb-1">Nombre de la cuenta</label>
              <input
                type="text"
                required
                maxLength={80}
                value={editAccName}
                onChange={(e) => setEditAccName(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs text-[#BACBB9] mb-1">Tipo de cuenta</label>
                <select
                  value={editAccType}
                  onChange={(e) => setEditAccType(e.target.value as AccountType)}
                  className="w-full px-3 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10"
                >
                  <option value="cash">Efectivo</option>
                  <option value="bank">Cuenta Bancaria</option>
                  <option value="credit_card">Tarjeta de Crédito</option>
                  <option value="savings">Ahorros</option>
                  <option value="investment">Inversión</option>
                </select>
              </div>
              <div>
                <label className="block text-xs text-[#BACBB9] mb-1">Saldo Actual (GTQ)</label>
                <input
                  type="number"
                  step="0.01"
                  value={editAccBalance}
                  onChange={(e) => setEditAccBalance(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm font-mono text-white border border-white/10"
                />
              </div>
            </div>
            <div>
              <label className="block text-xs text-[#BACBB9] mb-1">Descripción / Subtítulo</label>
              <input
                type="text"
                maxLength={100}
                value={editAccSubtitle}
                onChange={(e) => setEditAccSubtitle(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10"
              />
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setIsEditAccountOpen(false)}
                className="px-4 py-2 rounded-xl bg-[#252525] text-xs font-semibold text-[#BACBB9]"
              >
                Cancelar
              </button>
              <button
                type="submit"
                className="px-5 py-2 rounded-xl bg-[#00E676] text-[#003918] text-xs font-bold"
              >
                Guardar Cambios
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Modal: Add Category Modal */}
      {isAddCategoryOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4">
          <form
            onSubmit={handleCreateCategory}
            className="w-full max-w-md bg-[#1E1E1E] border border-white/10 rounded-2xl p-6 space-y-4"
          >
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                <FolderPlus className="w-5 h-5 text-[#00E676]" />
                <span>Nueva Categoría</span>
              </h3>
              <button
                type="button"
                onClick={() => setIsAddCategoryOpen(false)}
                className="p-1 text-[#A0A0A0] hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <div>
              <label className="block text-xs text-[#BACBB9] mb-1">Nombre de la categoría</label>
              <input
                type="text"
                required
                maxLength={60}
                value={catFormName}
                onChange={(e) => setCatFormName(e.target.value)}
                placeholder="Ej. Mascotas & Veterinaria"
                className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs text-[#BACBB9] mb-1">Tipo de flujo</label>
                <select
                  value={catFormType}
                  onChange={(e) => setCatFormType(e.target.value as 'expense' | 'income')}
                  className="w-full px-3 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10"
                >
                  <option value="expense">Gasto</option>
                  <option value="income">Ingreso</option>
                </select>
              </div>
              <div>
                <label className="block text-xs text-[#BACBB9] mb-1">Icono</label>
                <select
                  value={catFormIcon}
                  onChange={(e) => setCatFormIcon(e.target.value)}
                  className="w-full px-3 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10"
                >
                  <option value="utensils">Comida / Utensilios</option>
                  <option value="shopping_cart">Supermercado</option>
                  <option value="fuel">Gasolina / Auto</option>
                  <option value="wifi">Servicios / Red</option>
                  <option value="film">Entretenimiento</option>
                  <option value="heart_pulse">Salud</option>
                  <option value="briefcase">Trabajo / Nómina</option>
                </select>
              </div>
            </div>
            <div>
              <label className="block text-xs text-[#BACBB9] mb-1">Color representativo</label>
              <div className="flex items-center gap-2">
                {['#00E676', '#00DCF5', '#FF5252', '#FFB300', '#9C27B0', '#75FF9E'].map((c) => (
                  <button
                    key={c}
                    type="button"
                    onClick={() => setCatFormColor(c)}
                    className={`w-7 h-7 rounded-full transition-transform ${catFormColor === c ? 'scale-125 ring-2 ring-white' : 'opacity-80'}`}
                    style={{ backgroundColor: c }}
                  />
                ))}
              </div>
            </div>
            <div>
              <label className="block text-xs text-[#BACBB9] mb-1">Descripción / Subtítulo</label>
              <input
                type="text"
                maxLength={120}
                value={catFormSubtitle}
                onChange={(e) => setCatFormSubtitle(e.target.value)}
                placeholder="Alimento, medicinas, visitas veterinarias"
                className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10"
              />
            </div>

            {/* Subcategorías Editor */}
            <div className="pt-2 border-t border-white/5">
              <label className="block text-xs text-[#BACBB9] mb-1.5 flex items-center justify-between">
                <span>Subcategorías desplegables ({catFormSubcategories.length})</span>
                <span className="text-[11px] text-[#A0A0A0]">Enter para agregar</span>
              </label>
              <div className="flex gap-2 mb-2">
                <input
                  type="text"
                  value={catFormNewSubInput}
                  onChange={(e) => setCatFormNewSubInput(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      e.preventDefault();
                      handleAddSubcategoryTag();
                    }
                  }}
                  placeholder="Ej. Alimento, Vacunas..."
                  className="flex-1 px-3 py-1.5 rounded-lg bg-[#252525] text-xs text-white border border-white/10"
                />
                <button
                  type="button"
                  onClick={handleAddSubcategoryTag}
                  className="px-3 py-1.5 rounded-lg bg-[#333] hover:bg-[#444] text-xs text-white font-semibold"
                >
                  Añadir
                </button>
              </div>
              <div className="flex flex-wrap gap-1.5 max-h-24 overflow-y-auto">
                {catFormSubcategories.map((sub) => (
                  <span
                    key={sub}
                    className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-[#2A2A2A] text-xs text-white border border-white/10"
                  >
                    <span>{sub}</span>
                    <button
                      type="button"
                      onClick={() => handleRemoveSubcategoryTag(sub)}
                      className="hover:text-[#FF5252]"
                    >
                      <X className="w-3 h-3" />
                    </button>
                  </span>
                ))}
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setIsAddCategoryOpen(false)}
                className="px-4 py-2 rounded-xl bg-[#252525] text-xs font-semibold text-[#BACBB9]"
              >
                Cancelar
              </button>
              <button
                type="submit"
                className="px-5 py-2 rounded-xl bg-[#00E676] text-[#003918] text-xs font-bold"
              >
                Crear Categoría
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Modal: Edit Category Modal */}
      {isEditCategoryOpen && editingCategory && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4">
          <form
            onSubmit={handleUpdateCategory}
            className="w-full max-w-md bg-[#1E1E1E] border border-white/10 rounded-2xl p-6 space-y-4"
          >
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                <Edit3 className="w-5 h-5 text-[#00DCF5]" />
                <span>Editar Categoría y Subcategorías</span>
              </h3>
              <button
                type="button"
                onClick={() => setIsEditCategoryOpen(false)}
                className="p-1 text-[#A0A0A0] hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <div>
              <label className="block text-xs text-[#BACBB9] mb-1">Nombre</label>
              <input
                type="text"
                required
                maxLength={60}
                value={catFormName}
                onChange={(e) => setCatFormName(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs text-[#BACBB9] mb-1">Tipo de flujo</label>
                <select
                  value={catFormType}
                  onChange={(e) => setCatFormType(e.target.value as 'expense' | 'income')}
                  className="w-full px-3 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10"
                >
                  <option value="expense">Gasto</option>
                  <option value="income">Ingreso</option>
                </select>
              </div>
              <div>
                <label className="block text-xs text-[#BACBB9] mb-1">Icono</label>
                <select
                  value={catFormIcon}
                  onChange={(e) => setCatFormIcon(e.target.value)}
                  className="w-full px-3 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10"
                >
                  <option value="utensils">Comida / Utensilios</option>
                  <option value="shopping_cart">Supermercado</option>
                  <option value="fuel">Gasolina / Auto</option>
                  <option value="wifi">Servicios / Red</option>
                  <option value="film">Entretenimiento</option>
                  <option value="heart_pulse">Salud</option>
                  <option value="briefcase">Trabajo / Nómina</option>
                </select>
              </div>
            </div>
            <div>
              <label className="block text-xs text-[#BACBB9] mb-1">Descripción</label>
              <input
                type="text"
                maxLength={120}
                value={catFormSubtitle}
                onChange={(e) => setCatFormSubtitle(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10"
              />
            </div>

            {/* Subcategorías Editor */}
            <div className="pt-2 border-t border-white/5">
              <label className="block text-xs text-[#BACBB9] mb-1.5 flex items-center justify-between">
                <span>Subcategorías desplegables ({catFormSubcategories.length})</span>
                <span className="text-[11px] text-[#A0A0A0]">Enter para agregar</span>
              </label>
              <div className="flex gap-2 mb-2">
                <input
                  type="text"
                  value={catFormNewSubInput}
                  onChange={(e) => setCatFormNewSubInput(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      e.preventDefault();
                      handleAddSubcategoryTag();
                    }
                  }}
                  placeholder="Nueva subcategoría..."
                  className="flex-1 px-3 py-1.5 rounded-lg bg-[#252525] text-xs text-white border border-white/10"
                />
                <button
                  type="button"
                  onClick={handleAddSubcategoryTag}
                  className="px-3 py-1.5 rounded-lg bg-[#333] hover:bg-[#444] text-xs text-white font-semibold"
                >
                  Añadir
                </button>
              </div>
              <div className="flex flex-wrap gap-1.5 max-h-28 overflow-y-auto">
                {catFormSubcategories.map((sub) => (
                  <span
                    key={sub}
                    className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-[#2A2A2A] text-xs text-white border border-white/10"
                  >
                    <span>{sub}</span>
                    <button
                      type="button"
                      onClick={() => handleRemoveSubcategoryTag(sub)}
                      className="hover:text-[#FF5252]"
                    >
                      <X className="w-3 h-3" />
                    </button>
                  </span>
                ))}
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setIsEditCategoryOpen(false)}
                className="px-4 py-2 rounded-xl bg-[#252525] text-xs font-semibold text-[#BACBB9]"
              >
                Cancelar
              </button>
              <button
                type="submit"
                className="px-5 py-2 rounded-xl bg-[#00E676] text-[#003918] text-xs font-bold"
              >
                Guardar Cambios
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Modal: Edit Budget Modal */}
      {isEditBudgetOpen && editingBudget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4">
          <form
            onSubmit={handleUpdateBudget}
            className="w-full max-w-md bg-[#1E1E1E] border border-white/10 rounded-2xl p-6 space-y-4"
          >
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-bold text-white">Editar Presupuesto</h3>
              <button
                type="button"
                onClick={() => setIsEditBudgetOpen(false)}
                className="p-1 text-[#A0A0A0] hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <div>
              <label className="block text-xs text-[#BACBB9] mb-1">Nombre</label>
              <input
                type="text"
                required
                maxLength={80}
                value={editBudgetName}
                onChange={(e) => setEditBudgetName(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs text-[#BACBB9] mb-1">Categoría vinculada</label>
                <select
                  value={editBudgetCategory}
                  onChange={(e) => setEditBudgetCategory(e.target.value)}
                  className="w-full px-3 py-2.5 rounded-xl bg-[#252525] text-sm text-white border border-white/10"
                >
                  {categories.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-xs text-[#BACBB9] mb-1">Tope Mensual (GTQ)</label>
                <input
                  type="number"
                  step="any"
                  min="0.01"
                  value={editBudgetLimit}
                  onChange={(e) => setEditBudgetLimit(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm font-mono text-white border border-white/10 focus:border-[#00E676] focus:outline-none"
                />
              </div>
            </div>
            <div>
              <label className="block text-xs text-[#BACBB9] mb-1">Período Financiero</label>
              <input
                type="text"
                value={editBudgetPeriod}
                onChange={(e) => setEditBudgetPeriod(e.target.value)}
                placeholder="period_2026_11"
                className="w-full px-3.5 py-2.5 rounded-xl bg-[#252525] text-sm font-mono text-[#75FF9E] border border-white/10"
              />
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setIsEditBudgetOpen(false)}
                className="px-4 py-2 rounded-xl bg-[#252525] text-xs font-semibold text-[#BACBB9]"
              >
                Cancelar
              </button>
              <button
                type="submit"
                className="px-5 py-2 rounded-xl bg-[#00E676] text-[#003918] text-xs font-bold"
              >
                Guardar Presupuesto
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Modal 4: Split-Screen Login Modal (Matching Image 15.png) */}
      {isLoginModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md p-4">
          <div className="w-full max-w-4xl bg-[#1E1E1E] rounded-3xl overflow-hidden shadow-2xl grid grid-cols-1 md:grid-cols-2 border border-white/10">
            {/* Left Green Panel */}
            <div className="bg-[#169B62] p-8 text-white flex flex-col justify-between">
              <div>
                <span className="text-xs font-bold uppercase tracking-widest opacity-80">
                  Wallet
                </span>
                <h2 className="text-3xl font-bold mt-2 leading-tight">
                  Tus finanzas en un solo lugar
                </h2>
                <p className="text-sm text-white/90 mt-4 leading-relaxed">
                  Lleva el control de tus ingresos, gastos y transferencias, crea presupuestos inteligentes y organiza tus quincenas de forma automática.
                </p>
              </div>
              <div className="mt-8 pt-6 border-t border-white/20 text-xs space-y-2 text-white/95">
                <div className="flex items-center gap-2">
                  <Check className="w-4 h-4 text-white shrink-0" />
                  <span>Control de cuentas de banco, efectivo y tarjetas</span>
                </div>
                <div className="flex items-center gap-2">
                  <Check className="w-4 h-4 text-white shrink-0" />
                  <span>Gestión de quincenas y fechas de corte</span>
                </div>
                <div className="flex items-center gap-2">
                  <Check className="w-4 h-4 text-white shrink-0" />
                  <span>Presupuestos y límites de gasto por categoría</span>
                </div>
                <div className="flex items-center gap-2">
                  <Check className="w-4 h-4 text-white shrink-0" />
                  <span>Sincronización en la nube 100% privada</span>
                </div>
              </div>
            </div>

            {/* Right Auth Panel */}
            <div className="p-8 bg-[#181818] flex flex-col justify-between relative">
              <button
                type="button"
                onClick={() => setIsLoginModalOpen(false)}
                className="absolute top-4 right-4 p-2 rounded-full hover:bg-white/10 text-[#A0A0A0]"
              >
                <X className="w-5 h-5" />
              </button>

              <div className="my-auto space-y-5">
                <div>
                  <h3 className="text-2xl font-bold text-white">
                    Iniciar sesión
                  </h3>
                  <p className="text-xs text-[#A0A0A0] mt-1">
                    Accede con tu cuenta de Google para comenzar a registrar tus finanzas personales desde cero.
                  </p>
                </div>

                <button
                  type="button"
                  onClick={handleGoogleLogin}
                  className="w-full py-3.5 px-4 rounded-full bg-white hover:bg-neutral-100 text-[#121212] font-bold text-sm flex items-center justify-center gap-3 shadow-md transition-colors"
                >
                  <LogIn className="w-4 h-4 text-[#008952]" />
                  <span>Continuar con Google</span>
                </button>

                <button
                  type="button"
                  onClick={() => setIsLoginModalOpen(false)}
                  className="w-full py-3 px-4 rounded-full bg-[#252525] hover:bg-[#2E2E2E] text-white text-xs font-semibold transition-colors"
                >
                  Explorar en Modo Demostración
                </button>
              </div>

              <p className="text-[11px] text-[#A0A0A0] text-center mt-6">
                Tus datos financieros son privados y solo accesibles por ti.
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
