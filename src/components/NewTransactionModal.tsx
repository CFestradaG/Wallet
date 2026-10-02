import React, { useState, useEffect } from 'react';
import {
  X,
  Check,
  Wallet,
  Utensils,
  ShoppingCart,
  Fuel,
  Film,
  HeartPulse,
  Briefcase,
  Calendar,
  FileText,
  Delete,
  ChevronDown,
  ArrowRight,
  Layers,
  Tag,
  ChevronLeft,
} from 'lucide-react';
import {
  WalletAccount,
  WalletCategory,
  WalletTransaction,
  TransactionType,
  INITIAL_CATEGORIES_SEED,
} from '../types/wallet';

interface NewTransactionModalProps {
  isOpen: boolean;
  onClose: () => void;
  accounts: WalletAccount[];
  categories: WalletCategory[];
  initialType?: TransactionType;
  editingTransaction?: WalletTransaction | null;
  onSaveTransaction: (data: {
    id?: string;
    type: TransactionType;
    amount: number;
    accountId: string;
    toAccountId?: string;
    categoryId: string;
    subcategory?: string;
    note: string;
    dateIso: string;
  }) => Promise<void>;
}

export const NewTransactionModal: React.FC<NewTransactionModalProps> = ({
  isOpen,
  onClose,
  accounts,
  categories,
  initialType = 'expense',
  editingTransaction = null,
  onSaveTransaction,
}) => {
  const [txType, setTxType] = useState<TransactionType>(initialType);
  const [expression, setExpression] = useState<string>('0.00');
  const [isDefaultVal, setIsDefaultVal] = useState<boolean>(true);
  const [selectedAccountId, setSelectedAccountId] = useState<string>(
    accounts[0]?.id || 'acc_efectivo'
  );
  const [selectedToAccountId, setSelectedToAccountId] = useState<string>(
    accounts[1]?.id || 'acc_banco'
  );
  const [selectedCategoryId, setSelectedCategoryId] = useState<string>('');
  const [isCategoryChosen, setIsCategoryChosen] = useState<boolean>(false);
  const [selectedSubcategory, setSelectedSubcategory] = useState<string>('');
  const [note, setNote] = useState<string>('');
  const [txDateIso, setTxDateIso] = useState<string>(() =>
    new Date().toISOString().slice(0, 10)
  );
  const [isSaving, setIsSaving] = useState<boolean>(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  // Asegurar que siempre existan categorías base genéricas si la subcolección aún no cargó
  const safeCategories =
    categories && categories.length > 0
      ? categories
      : (INITIAL_CATEGORIES_SEED as unknown as WalletCategory[]);

  const filteredCategories = safeCategories.filter((c) =>
    txType === 'income' ? c.type === 'income' : c.type === 'expense'
  );

  const displayCategories: WalletCategory[] =
    filteredCategories.length > 0
      ? filteredCategories
      : (INITIAL_CATEGORIES_SEED.filter(
          (c) => c.type === txType
        ) as unknown as WalletCategory[]);

  useEffect(() => {
    if (!isOpen) return;
    setErrorMsg(null);

    if (editingTransaction) {
      setTxType(editingTransaction.type);
      setExpression(editingTransaction.amount.toFixed(2));
      setIsDefaultVal(false);
      setSelectedAccountId(editingTransaction.accountId);
      setSelectedToAccountId(
        editingTransaction.toAccountId ||
          accounts.find((a) => a.id !== editingTransaction.accountId)?.id ||
          accounts[0]?.id ||
          'acc_banco'
      );
      setSelectedCategoryId(editingTransaction.categoryId);
      setSelectedSubcategory(editingTransaction.subcategory || '');
      setIsCategoryChosen(true);
      setNote(editingTransaction.note);
      setTxDateIso(editingTransaction.dateIso.slice(0, 10));
    } else {
      setTxType(initialType);
      setExpression('0.00');
      setIsDefaultVal(true);
      setSelectedAccountId(accounts[0]?.id || 'acc_efectivo');
      setSelectedToAccountId(
        accounts[1]?.id || accounts[0]?.id || 'acc_banco'
      );
      // Flujo: El usuario empieza viendo las categorías para seleccionar una
      setSelectedCategoryId('');
      setIsCategoryChosen(false);
      setSelectedSubcategory('');
      setNote('');
      setTxDateIso(new Date().toISOString().slice(0, 10));
    }
  }, [isOpen, editingTransaction, initialType, accounts, categories]);

  if (!isOpen) return null;

  const activeAccount =
    accounts.find((a) => a.id === selectedAccountId) || accounts[0];
  const activeToAccount =
    accounts.find((a) => a.id === selectedToAccountId) ||
    accounts.find((a) => a.id !== activeAccount?.id) ||
    accounts[0];

  const activeCategory =
    displayCategories.find((c) => c.id === selectedCategoryId) || null;

  const currentSubcategories = activeCategory?.subcategories || [];

  const handleSelectCategory = (cat: WalletCategory) => {
    setSelectedCategoryId(cat.id);
    setSelectedSubcategory(cat.subcategories?.[0] || '');
    setIsCategoryChosen(true);
    setErrorMsg(null);
  };

  const handleResetCategorySelection = () => {
    setIsCategoryChosen(false);
  };

  const evaluateExpression = (expr: string): number => {
    try {
      const sanitized = expr.replace(/[^0-9.+\-*/]/g, '');
      if (!sanitized) return 0;
      const cleanEnd = sanitized.replace(/[+\-*/.]$/, '');
      if (!cleanEnd) return 0;
      const tokens = cleanEnd.split(/([+\-*/])/).filter(Boolean);
      let current = parseFloat(tokens[0]) || 0;
      for (let i = 1; i < tokens.length; i += 2) {
        const op = tokens[i];
        const nextVal = parseFloat(tokens[i + 1]) || 0;
        if (op === '+') current += nextVal;
        if (op === '-') current -= nextVal;
        if (op === '*') current *= nextVal;
        if (op === '/') current = nextVal !== 0 ? current / nextVal : current;
      }
      return Math.max(0, Number(current.toFixed(2)));
    } catch {
      return 0;
    }
  };

  const handleKeyPress = (key: string) => {
    setErrorMsg(null);
    if (key === 'backspace') {
      if (expression.length > 1) {
        setExpression(expression.slice(0, -1));
      } else {
        setExpression('0');
        setIsDefaultVal(true);
      }
      return;
    }

    if (key === '=') {
      const val = evaluateExpression(expression);
      setExpression(val.toFixed(2));
      setIsDefaultVal(true);
      return;
    }

    if (['+', '-', '*', '/'].includes(key)) {
      setIsDefaultVal(false);
      if (['+', '-', '*', '/'].some((op) => expression.endsWith(op))) {
        setExpression(expression.slice(0, -1) + key);
      } else {
        setExpression(expression + key);
      }
      return;
    }

    if (key === '.') {
      const parts = expression.split(/[+\-*/]/);
      const lastPart = parts[parts.length - 1];
      if (!lastPart.includes('.')) {
        setExpression(expression + '.');
        setIsDefaultVal(false);
      }
      return;
    }

    if (isDefaultVal || expression === '0' || expression === '0.00') {
      setExpression(key);
      setIsDefaultVal(false);
    } else if (expression.length < 14) {
      setExpression(expression + key);
    }
  };

  const activeAccountBalance = Number(
    activeAccount?.currentBalance ?? activeAccount?.balance ?? 0
  );
  const currentEvaluatedAmount = evaluateExpression(expression);
  const isBalanceExceeded =
    (txType === 'expense' || txType === 'transfer') &&
    activeAccount?.type !== 'credit_card' &&
    currentEvaluatedAmount > activeAccountBalance;

  const handleSave = async () => {
    const evaluatedAmount = evaluateExpression(expression);
    if (evaluatedAmount <= 0) {
      setErrorMsg('Ingresa un monto mayor a Q 0.00');
      return;
    }
    if (!activeAccount) {
      setErrorMsg('Selecciona una cuenta válida');
      return;
    }
    if (
      (txType === 'expense' || txType === 'transfer') &&
      activeAccount.type !== 'credit_card' &&
      evaluatedAmount > activeAccountBalance
    ) {
      setErrorMsg(
        `El monto (Q ${evaluatedAmount.toFixed(2)}) supera el saldo disponible (Q ${activeAccountBalance.toFixed(2)}) de ${activeAccount.name}. Operación no permitida.`
      );
      return;
    }
    if (txType !== 'transfer' && !activeCategory) {
      setErrorMsg('Por favor selecciona una categoría antes de guardar');
      return;
    }
    if (
      txType === 'transfer' &&
      (!activeToAccount || activeToAccount.id === activeAccount.id)
    ) {
      setErrorMsg(
        'Para una transferencia, selecciona una cuenta destino distinta a la cuenta origen'
      );
      return;
    }

    setIsSaving(true);
    setErrorMsg(null);
    try {
      await onSaveTransaction({
        id: editingTransaction ? editingTransaction.id : undefined,
        type: txType,
        amount: evaluatedAmount,
        accountId: activeAccount.id,
        toAccountId: txType === 'transfer' ? activeToAccount?.id : undefined,
        categoryId: activeCategory?.id || 'cat_otros',
        subcategory: selectedSubcategory || undefined,
        note: note.trim(),
        dateIso: txDateIso,
      });
      onClose();
    } catch (err: unknown) {
      const e = err as Error;
      setErrorMsg(e.message || 'Error al guardar el movimiento');
    } finally {
      setIsSaving(false);
    }
  };

  const renderCategoryIcon = (iconName: string) => {
    switch (iconName) {
      case 'shopping_cart':
        return <ShoppingCart className="w-3.5 h-3.5" />;
      case 'fuel':
        return <Fuel className="w-3.5 h-3.5" />;
      case 'film':
        return <Film className="w-3.5 h-3.5" />;
      case 'heart_pulse':
        return <HeartPulse className="w-3.5 h-3.5" />;
      case 'briefcase':
        return <Briefcase className="w-3.5 h-3.5" />;
      default:
        return <Utensils className="w-3.5 h-3.5" />;
    }
  };

  const headerBg =
    txType === 'income'
      ? 'bg-[#169B62]'
      : txType === 'expense'
      ? 'bg-[#00838F]'
      : 'bg-[#5C6BC0]';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md p-0 sm:p-4">
      <div className="w-full max-w-lg h-full sm:h-auto sm:max-h-[94vh] bg-[#121212] sm:rounded-3xl border border-white/10 shadow-2xl flex flex-col overflow-hidden select-none">
        {/* Header Cyan / Emerald Style */}
        <header className={`${headerBg} text-white transition-colors duration-200 shrink-0`}>
          <div className="px-4 py-3 flex items-center justify-between">
            <button
              type="button"
              onClick={onClose}
              className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-black/15 active:bg-black/25 transition-colors"
              aria-label="Cerrar"
            >
              <X className="w-6 h-6" />
            </button>
            <div className="text-center">
              <span className="text-xs font-bold tracking-widest uppercase block">
                {editingTransaction ? 'Editar Registro' : 'Registrar Movimiento'}
              </span>
              {txType !== 'transfer' && (
                <span className="text-[11px] opacity-90 truncate max-w-[220px] block font-medium">
                  {activeCategory ? activeCategory.name : '› Selecciona Categoría'}
                  {selectedSubcategory ? ` › ${selectedSubcategory}` : ''}
                </span>
              )}
            </div>
            <button
              type="button"
              onClick={handleSave}
              disabled={isSaving || isBalanceExceeded}
              className={`w-10 h-10 flex items-center justify-center rounded-full transition-colors ${
                isBalanceExceeded
                  ? 'opacity-40 cursor-not-allowed bg-red-900/50 text-red-200'
                  : 'hover:bg-black/15 active:bg-black/25'
              }`}
              title={
                isBalanceExceeded
                  ? 'Operación bloqueada: supera el saldo disponible'
                  : 'Guardar movimiento'
              }
              aria-label="Confirmar"
            >
              <Check className="w-6 h-6" />
            </button>
          </div>

          {/* Segmented Tabs: GASTO | INGRESO | TRANSFERENCIA */}
          <nav className="flex border-b border-black/15 text-[11px] font-bold tracking-wider uppercase">
            <button
              type="button"
              onClick={() => {
                setTxType('expense');
                setIsCategoryChosen(false);
                setSelectedCategoryId('');
                setSelectedSubcategory('');
                setErrorMsg(null);
              }}
              className={`flex-1 py-3 text-center transition-all whitespace-nowrap ${
                txType === 'expense'
                  ? 'border-b-4 border-white bg-black/15 font-extrabold text-white'
                  : 'opacity-75 hover:opacity-100'
              }`}
            >
              Gasto
            </button>
            <button
              type="button"
              onClick={() => {
                setTxType('income');
                setIsCategoryChosen(false);
                setSelectedCategoryId('');
                setSelectedSubcategory('');
                setErrorMsg(null);
              }}
              className={`flex-1 py-3 text-center transition-all whitespace-nowrap ${
                txType === 'income'
                  ? 'border-b-4 border-white bg-black/15 font-extrabold text-white'
                  : 'opacity-75 hover:opacity-100'
              }`}
            >
              Ingresos
            </button>
            <button
              type="button"
              onClick={() => {
                setTxType('transfer');
                setIsCategoryChosen(false);
                setErrorMsg(null);
              }}
              className={`flex-1 py-3 text-center transition-all whitespace-nowrap ${
                txType === 'transfer'
                  ? 'border-b-4 border-white bg-black/15 font-extrabold text-white'
                  : 'opacity-75 hover:opacity-100'
              }`}
            >
              Transferencia
            </button>
          </nav>

          {/* Big Amount Calculator Display */}
          <div className="px-6 py-4 flex flex-col items-center justify-center">
            <div className="text-3xl sm:text-4xl font-extrabold font-mono tracking-tight flex items-baseline gap-1.5">
              <span className="opacity-70 text-2xl font-sans">
                {txType === 'income' ? '+' : txType === 'expense' ? '-' : '⇄'}
              </span>
              <span className="tabular-nums">
                {expression}
              </span>
              <span className="text-sm font-semibold opacity-80 uppercase tracking-widest ml-1">
                {activeAccount?.currency || 'GTQ'}
              </span>
            </div>

            {/* Quick Pickers Bar */}
            <div className="mt-3.5 flex flex-col items-center gap-2 w-full text-xs">
              <div className="flex items-center justify-center gap-4 w-full">
                {/* Account Selector */}
                <div className="flex-1 flex flex-col items-center">
                  <span className="text-[10px] uppercase font-semibold tracking-wider opacity-80">
                    {txType === 'transfer' ? 'Cuenta Origen (-)' : 'Cuenta'}
                  </span>
                  <div className="relative mt-0.5 w-full max-w-[190px]">
                    <select
                      value={activeAccount?.id || ''}
                      onChange={(e) => setSelectedAccountId(e.target.value)}
                      className="w-full appearance-none bg-black/25 hover:bg-black/35 text-white font-bold text-xs uppercase px-3 py-1.5 pr-6 rounded-lg cursor-pointer focus:outline-none text-center truncate"
                    >
                      {accounts.map((acc) => (
                        <option
                          key={acc.id}
                          value={acc.id}
                          className="bg-[#1E1E1E] text-white"
                        >
                          {acc.name} (Q{Number(acc.currentBalance ?? acc.balance ?? 0).toFixed(2)})
                        </option>
                      ))}
                    </select>
                    <ChevronDown className="w-3.5 h-3.5 absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none opacity-80" />
                  </div>
                </div>

                {/* Transfer Destination Account */}
                {txType === 'transfer' && (
                  <div className="flex-1 flex flex-col items-center">
                    <span className="text-[10px] uppercase font-semibold tracking-wider opacity-80 flex items-center gap-1">
                      <ArrowRight className="w-3 h-3" /> Destino (+)
                    </span>
                    <div className="relative mt-0.5 w-full max-w-[190px]">
                      <select
                        value={activeToAccount?.id || ''}
                        onChange={(e) => setSelectedToAccountId(e.target.value)}
                        className="w-full appearance-none bg-black/25 hover:bg-black/35 text-[#75FF9E] font-bold text-xs uppercase px-3 py-1.5 pr-6 rounded-lg cursor-pointer focus:outline-none text-center truncate"
                      >
                        {accounts.map((acc) => (
                          <option
                            key={acc.id}
                            value={acc.id}
                            disabled={acc.id === activeAccount?.id}
                            className="bg-[#1E1E1E] text-white"
                          >
                            {acc.name} (Q{Number(acc.currentBalance ?? acc.balance ?? 0).toFixed(2)})
                          </option>
                        ))}
                      </select>
                      <ChevronDown className="w-3.5 h-3.5 absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none opacity-80" />
                    </div>
                  </div>
                )}
              </div>

              {/* Account Balance Badge */}
              <div className="flex items-center gap-2">
                <span className="text-[11px] font-mono font-medium px-2.5 py-0.5 rounded-full bg-black/30 border border-white/10 text-white/90">
                  Saldo en cuenta: <strong className="text-white">Q {activeAccountBalance.toLocaleString('es-GT', { minimumFractionDigits: 2 })}</strong>
                </span>
                {activeAccount?.type === 'credit_card' && (
                  <span className="text-[10px] uppercase tracking-wider px-1.5 py-0.5 rounded bg-amber-500/20 text-amber-200">
                    Crédito
                  </span>
                )}
              </div>
            </div>

            {/* Warning if amount exceeds balance */}
            {isBalanceExceeded && (
              <div className="mt-2.5 px-3 py-1 rounded-lg bg-red-950/90 border border-red-500/40 text-red-200 text-[11px] font-semibold flex items-center gap-1.5 animate-pulse">
                <span>⚠️ Saldo insuficiente: Operación excede los Q {activeAccountBalance.toFixed(2)} disponibles</span>
              </div>
            )}
          </div>
        </header>

        {/* Main Body */}
        <div className="flex-1 flex flex-col bg-[#121212] overflow-y-auto">
          {/* FLUJO REQUERIDO: Categorías iniciales y al seleccionar, ocultar categorías y desplegar subcategorías con botón Regresar */}
          {txType !== 'transfer' && (
            <div className="border-b border-neutral-800 bg-[#161616]">
              {!isCategoryChosen || !activeCategory ? (
                /* PASO 1: MOSTRAR PRIMERO TODAS LAS CATEGORÍAS DISPONIBLES */
                <div className="py-2.5 px-4">
                  <div className="flex items-center justify-between mb-1.5">
                    <div className="flex items-center gap-1.5 text-[10px] font-bold tracking-wider uppercase text-neutral-400">
                      <Layers className="w-3.5 h-3.5 text-[#00acc1]" />
                      <span>1. Elige una categoría:</span>
                    </div>
                    <span className="text-[10px] text-[#00acc1] font-semibold">
                      {displayCategories.length} disponibles
                    </span>
                  </div>

                  <div className="grid grid-cols-4 sm:grid-cols-4 gap-1.5 max-h-[140px] overflow-y-auto p-0.5 scrollbar-thin">
                    {displayCategories.map((cat) => (
                      <button
                        key={cat.id}
                        type="button"
                        onClick={() => handleSelectCategory(cat)}
                        className="flex flex-col items-center p-1.5 rounded-lg bg-neutral-900 border border-neutral-800 hover:border-[#00acc1]/60 hover:bg-neutral-800 active:scale-95 transition-all text-center group"
                      >
                        <div
                          className="w-7 h-7 rounded-lg flex items-center justify-center mb-1 transition-transform group-hover:scale-105 shrink-0"
                          style={{
                            backgroundColor: `${cat.colorHex}25`,
                            color: cat.colorHex,
                          }}
                        >
                          {renderCategoryIcon(cat.iconName)}
                        </div>
                        <span className="text-[10px] font-semibold text-neutral-200 line-clamp-1 w-full">
                          {cat.name}
                        </span>
                        <span className="text-[8px] text-neutral-500 font-medium">
                          {(cat.subcategories || []).length} subs
                        </span>
                      </button>
                    ))}
                  </div>
                </div>
              ) : (
                /* PASO 2: CATEGORÍA SELECCIONADA (OCULTA LAS DEMÁS), BOTÓN REGRESAR Y SUBCATEGORÍAS HIJAS */
                <div className="py-2.5 px-4 bg-[#181818] space-y-2">
                  {/* Tarjeta de Categoría Elegida con Botón Regresar */}
                  <div className="flex items-center justify-between bg-[#222222] border border-white/10 rounded-xl p-2 shadow-sm">
                    <div className="flex items-center gap-2">
                      <div
                        className="w-7 h-7 rounded-lg flex items-center justify-center shrink-0"
                        style={{
                          backgroundColor: `${activeCategory.colorHex}30`,
                          color: activeCategory.colorHex,
                        }}
                      >
                        {renderCategoryIcon(activeCategory.iconName)}
                      </div>
                      <div>
                        <div className="flex items-center gap-1.5">
                          <span className="text-[10px] uppercase font-bold tracking-wider text-neutral-400">
                            Categoría:
                          </span>
                          <span className="text-xs font-bold text-white">
                            {activeCategory.name}
                          </span>
                        </div>
                        <p className="text-[10px] text-neutral-400">
                          {selectedSubcategory
                            ? `Subcategoría: ${selectedSubcategory}`
                            : 'Subcategoría: General'}
                        </p>
                      </div>
                    </div>

                    <button
                      type="button"
                      onClick={handleResetCategorySelection}
                      className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-[#2E2E2E] hover:bg-[#3A3A3A] active:scale-95 text-xs font-semibold text-[#00DCF5] border border-white/10 transition-colors"
                      title="Volver a ver todas las categorías"
                    >
                      <ChevronLeft className="w-3.5 h-3.5" />
                      <span>Regresar</span>
                    </button>
                  </div>

                  {/* Subcategorías Hijas Desplegadas */}
                  <div>
                    <div className="flex items-center justify-between mb-1.5 px-1">
                      <span className="text-[10px] font-bold tracking-wider uppercase text-[#BACBB9] flex items-center gap-1">
                        <Tag className="w-3 h-3 text-[#75FF9E]" />
                        <span>Subcategorías Hijas:</span>
                      </span>
                      {selectedSubcategory && (
                        <span className="text-[10px] text-[#75FF9E] font-mono font-bold bg-[#75FF9E]/10 px-2 py-0.5 rounded-full border border-[#75FF9E]/20">
                          ✓ {selectedSubcategory}
                        </span>
                      )}
                    </div>

                    <div className="flex flex-wrap gap-1.5 items-center">
                      {/* Opción General */}
                      <button
                        type="button"
                        onClick={() => setSelectedSubcategory('')}
                        className={`px-3 py-1.5 rounded-full text-xs font-semibold transition-all ${
                          selectedSubcategory === ''
                            ? 'bg-[#75FF9E] text-[#003918] shadow-sm font-bold ring-1 ring-white/30'
                            : 'bg-[#262626] text-neutral-300 hover:bg-[#323232] border border-white/5'
                        }`}
                      >
                        General
                      </button>

                      {/* Chips de Subcategorías Hijas */}
                      {currentSubcategories.map((sub) => {
                        const isSubSelected = selectedSubcategory === sub;
                        return (
                          <button
                            key={sub}
                            type="button"
                            onClick={() => setSelectedSubcategory(sub)}
                            className={`px-3 py-1.5 rounded-full text-xs font-semibold transition-all ${
                              isSubSelected
                                ? 'bg-[#00acc1] text-black shadow-sm font-bold ring-1 ring-white/30'
                                : 'bg-[#262626] text-neutral-300 hover:bg-[#323232] border border-white/5'
                            }`}
                          >
                            {sub}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* Date & Note Input */}
          <section className="p-3 space-y-2 bg-[#141414] border-b border-neutral-800 text-xs shrink-0">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              <div className="flex items-center justify-between px-3 py-2 bg-neutral-900/90 rounded-lg border border-neutral-800">
                <div className="flex items-center space-x-2 text-neutral-300">
                  <Calendar className="w-4 h-4 text-[#00acc1]" />
                  <span className="font-medium">Fecha:</span>
                </div>
                <input
                  type="date"
                  value={txDateIso}
                  onChange={(e) => setTxDateIso(e.target.value)}
                  className="bg-[#202020] text-white font-mono text-xs px-2.5 py-1 rounded border border-white/10 focus:outline-none focus:border-[#00acc1]"
                />
              </div>

              <div className="flex items-center px-3 py-2 bg-neutral-900/90 rounded-lg border border-neutral-800 focus-within:border-[#00acc1] transition-colors">
                <FileText className="w-4 h-4 text-neutral-400 mr-2 shrink-0" />
                <input
                  type="text"
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  maxLength={200}
                  placeholder="Nota / Detalle opcional..."
                  className="w-full bg-transparent border-0 p-0 text-xs text-neutral-200 placeholder-neutral-500 focus:ring-0 focus:outline-none"
                />
              </div>
            </div>

            {errorMsg && (
              <p className="text-xs text-[#FF5252] px-1 font-medium">
                {errorMsg}
              </p>
            )}
          </section>

          {/* 4x4 Calculator Keypad */}
          <section className="flex-1 grid grid-cols-4 bg-[#181818] divide-x divide-y divide-neutral-800/90 min-h-[200px]">
            {['7', '8', '9', '/'].map((k) => (
              <button
                key={k}
                type="button"
                onClick={() => handleKeyPress(k)}
                className={`h-11 sm:h-12 flex items-center justify-center text-xl font-light active:bg-neutral-800 transition-colors ${
                  k === '/'
                    ? 'bg-neutral-900/60 text-neutral-400 font-normal'
                    : 'text-neutral-200'
                }`}
              >
                {k === '/' ? '÷' : k}
              </button>
            ))}
            {['4', '5', '6', '*'].map((k) => (
              <button
                key={k}
                type="button"
                onClick={() => handleKeyPress(k)}
                className={`h-11 sm:h-12 flex items-center justify-center text-xl font-light active:bg-neutral-800 transition-colors ${
                  k === '*'
                    ? 'bg-neutral-900/60 text-neutral-400 font-normal'
                    : 'text-neutral-200'
                }`}
              >
                {k === '*' ? '×' : k}
              </button>
            ))}
            {['1', '2', '3', '-'].map((k) => (
              <button
                key={k}
                type="button"
                onClick={() => handleKeyPress(k)}
                className={`h-11 sm:h-12 flex items-center justify-center text-xl font-light active:bg-neutral-800 transition-colors ${
                  k === '-'
                    ? 'bg-neutral-900/60 text-neutral-400 font-normal'
                    : 'text-neutral-200'
                }`}
              >
                {k}
              </button>
            ))}
            {['.', '0', 'backspace', '+'].map((k) => (
              <button
                key={k}
                type="button"
                onClick={() => handleKeyPress(k)}
                className={`h-11 sm:h-12 flex items-center justify-center text-xl font-light active:bg-neutral-800 transition-colors ${
                  k === '+'
                    ? 'bg-neutral-900/60 text-neutral-400 font-normal'
                    : k === 'backspace'
                    ? 'bg-neutral-900/40 text-neutral-400 text-sm'
                    : 'text-neutral-200'
                }`}
              >
                {k === 'backspace' ? <Delete className="w-5 h-5" /> : k}
              </button>
            ))}
          </section>
        </div>
      </div>
    </div>
  );
};
