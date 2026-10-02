import React, { useState, useEffect } from 'react';
import {
  X,
  Check,
  Wallet,
  Utensils,
  ShoppingCart,
  Fuel,
  Zap,
  Film,
  HeartPulse,
  Briefcase,
  Calendar,
  FileText,
  Delete,
  Bookmark,
  ChevronDown,
  ArrowRight,
} from 'lucide-react';
import {
  WalletAccount,
  WalletCategory,
  WalletTransaction,
  TransactionType,
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
    note: string;
    dateIso: string;
  }) => Promise<void>;
}

const TEMPLATES = [
  { label: 'Almuerzo Ejecutivo', amount: '50.00', type: 'expense' as TransactionType, note: 'Compra de almuerzo ejecutiva' },
  { label: 'Café Barista', amount: '35.00', type: 'expense' as TransactionType, note: 'Café Barista · Reunión' },
  { label: 'Gasolina V-Power', amount: '200.00', type: 'expense' as TransactionType, note: 'Gasolina Shell Las Américas' },
  { label: 'Supermercado La Torre', amount: '280.00', type: 'expense' as TransactionType, note: 'Supermercado La Torre · Despensa' },
  { label: 'Quincena Nómina', amount: '6250.00', type: 'income' as TransactionType, note: 'Depósito de nómina quincenal' },
];

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
  const [expression, setExpression] = useState<string>('150.00');
  const [isDefaultVal, setIsDefaultVal] = useState<boolean>(true);
  const [selectedAccountId, setSelectedAccountId] = useState<string>(
    accounts[0]?.id || 'acc_efectivo'
  );
  const [selectedToAccountId, setSelectedToAccountId] = useState<string>(
    accounts[1]?.id || 'acc_bac'
  );
  const [selectedCategoryId, setSelectedCategoryId] = useState<string>(
    categories[0]?.id || 'cat_comida'
  );
  const [note, setNote] = useState<string>('');
  const [txDateIso, setTxDateIso] = useState<string>(() =>
    new Date('2026-10-28T12:00:00.000Z').toISOString().slice(0, 10)
  );
  const [showTemplates, setShowTemplates] = useState<boolean>(false);
  const [isSaving, setIsSaving] = useState<boolean>(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

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
          'acc_bac'
      );
      setSelectedCategoryId(editingTransaction.categoryId);
      setNote(editingTransaction.note);
      setTxDateIso(editingTransaction.dateIso.slice(0, 10));
    } else {
      setTxType(initialType);
      setExpression('150.00');
      setIsDefaultVal(true);
      setSelectedAccountId(accounts[0]?.id || 'acc_efectivo');
      setSelectedToAccountId(
        accounts[1]?.id || accounts[0]?.id || 'acc_bac'
      );
      const defaultCat = categories.find((c) =>
        initialType === 'income' ? c.type === 'income' : c.type === 'expense'
      );
      setSelectedCategoryId(defaultCat?.id || categories[0]?.id || 'cat_comida');
      setNote('');
      setTxDateIso('2026-10-28');
    }
  }, [isOpen, editingTransaction, initialType, accounts, categories]);

  if (!isOpen) return null;

  const activeAccount =
    accounts.find((a) => a.id === selectedAccountId) || accounts[0];
  const activeToAccount =
    accounts.find((a) => a.id === selectedToAccountId) ||
    accounts.find((a) => a.id !== activeAccount?.id) ||
    accounts[0];

  const filteredCategories = categories.filter((c) =>
    txType === 'income' ? c.type === 'income' : c.type === 'expense'
  );
  const activeCategory =
    filteredCategories.find((c) => c.id === selectedCategoryId) ||
    filteredCategories[0] ||
    categories[0];

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

    if (isDefaultVal || expression === '0') {
      setExpression(key);
      setIsDefaultVal(false);
    } else if (expression.length < 14) {
      setExpression(expression + key);
    }
  };

  const handleSave = async () => {
    const evaluatedAmount = evaluateExpression(expression);
    if (evaluatedAmount <= 0) {
      setErrorMsg('Ingresa un monto mayor a Q 0.00');
      return;
    }
    if (!activeAccount || !activeCategory) {
      setErrorMsg('Selecciona una cuenta y categoría válidas');
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
      const fullDateIso = new Date(`${txDateIso}T12:00:00.000Z`).toISOString();
      await onSaveTransaction({
        id: editingTransaction?.id,
        type: txType,
        amount: evaluatedAmount,
        accountId: activeAccount.id,
        toAccountId: txType === 'transfer' ? activeToAccount?.id : undefined,
        categoryId: activeCategory.id,
        note:
          note.trim() ||
          (txType === 'transfer'
            ? `Transferencia: ${activeAccount.name} → ${activeToAccount?.name}`
            : `${activeCategory.name} · ${activeAccount.name}`),
        dateIso: fullDateIso,
      });
      onClose();
    } catch (err) {
      setErrorMsg(
        err instanceof Error ? err.message : 'Error al guardar la transacción'
      );
    } finally {
      setIsSaving(false);
    }
  };

  const renderCategoryIcon = (iconName: string) => {
    switch (iconName) {
      case 'utensils':
        return <Utensils className="w-5 h-5" />;
      case 'shopping_cart':
        return <ShoppingCart className="w-5 h-5" />;
      case 'fuel':
        return <Fuel className="w-5 h-5" />;
      case 'wifi':
      case 'zap':
        return <Zap className="w-5 h-5" />;
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

  const headerBg =
    txType === 'income'
      ? 'bg-[#00a859]'
      : txType === 'transfer'
      ? 'bg-[#0277bd]'
      : 'bg-[#00acc1]';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md p-0 sm:p-4">
      <div className="w-full max-w-md h-full sm:h-auto sm:max-h-[92vh] bg-[#121212] sm:rounded-3xl border border-white/10 shadow-2xl flex flex-col overflow-hidden select-none">
        {/* Header Cyan / Emerald Stitch Style */}
        <header className={`${headerBg} text-white transition-colors duration-200`}>
          <div className="px-4 py-3 flex items-center justify-between">
            <button
              type="button"
              onClick={onClose}
              className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-black/15 active:bg-black/25 transition-colors"
              aria-label="Cerrar"
            >
              <X className="w-6 h-6" />
            </button>
            <span className="text-xs font-bold tracking-widest uppercase">
              {editingTransaction
                ? 'Editar Transacción (Atómica)'
                : 'Nueva Transacción'}
            </span>
            <button
              type="button"
              onClick={handleSave}
              disabled={isSaving}
              className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-black/15 active:bg-black/25 transition-colors"
              aria-label="Confirmar"
            >
              <Check className="w-6 h-6" />
            </button>
          </div>

          {/* Segmented Tabs: INGRESOS | GASTO | TRANSFERENCIA */}
          <nav className="flex border-b border-black/15 text-[11px] font-bold tracking-wider uppercase">
            <button
              type="button"
              onClick={() => {
                setTxType('income');
                const incCat = categories.find((c) => c.type === 'income');
                if (incCat) setSelectedCategoryId(incCat.id);
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
                setTxType('expense');
                const expCat = categories.find((c) => c.type === 'expense');
                if (expCat) setSelectedCategoryId(expCat.id);
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
                setTxType('transfer');
                if (selectedToAccountId === selectedAccountId) {
                  const other = accounts.find(
                    (a) => a.id !== selectedAccountId
                  );
                  if (other) setSelectedToAccountId(other.id);
                }
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

          {/* Main Numeric Display */}
          <div className="px-6 pt-5 pb-4 flex flex-col items-center justify-center relative">
            <div className="flex items-baseline justify-center w-full space-x-2">
              <span className="text-3xl font-light opacity-90">
                {txType === 'income' ? '+' : txType === 'expense' ? '-' : '⇄'}
              </span>
              <span className="text-5xl font-light tracking-tight font-mono tabular-nums truncate max-w-[240px]">
                {expression}
              </span>
              <span className="text-xl font-medium opacity-90 ml-1">GTQ</span>
            </div>

            {/* Quick Account & Destination / Category Selector Row */}
            <div className="w-full grid grid-cols-2 gap-3 mt-5 pt-2.5 border-t border-white/20">
              <div className="flex flex-col items-center">
                <span className="text-[10px] uppercase font-medium tracking-wider opacity-80">
                  {txType === 'transfer' ? 'Cuenta Origen (-)' : 'Cuenta'}
                </span>
                <div className="relative mt-0.5">
                  <select
                    value={activeAccount?.id || ''}
                    onChange={(e) => {
                      const newOrigin = e.target.value;
                      setSelectedAccountId(newOrigin);
                      if (txType === 'transfer' && newOrigin === selectedToAccountId) {
                        const alt = accounts.find((a) => a.id !== newOrigin);
                        if (alt) setSelectedToAccountId(alt.id);
                      }
                    }}
                    className="appearance-none bg-black/15 hover:bg-black/25 text-white font-bold text-xs uppercase tracking-wide px-3 py-1.5 pr-6 rounded-lg cursor-pointer focus:outline-none"
                  >
                    {accounts.map((acc) => (
                      <option
                        key={acc.id}
                        value={acc.id}
                        className="bg-[#1E1E1E] text-white"
                      >
                        {acc.name}
                      </option>
                    ))}
                  </select>
                  <ChevronDown className="w-3.5 h-3.5 absolute right-1.5 top-1/2 -translate-y-1/2 pointer-events-none opacity-80" />
                </div>
              </div>

              {txType === 'transfer' ? (
                <div className="flex flex-col items-center">
                  <span className="text-[10px] uppercase font-medium tracking-wider opacity-80 flex items-center gap-1">
                    <ArrowRight className="w-3 h-3" /> Cuenta Destino (+)
                  </span>
                  <div className="relative mt-0.5">
                    <select
                      value={activeToAccount?.id || ''}
                      onChange={(e) => setSelectedToAccountId(e.target.value)}
                      className="appearance-none bg-black/20 hover:bg-black/30 text-[#75FF9E] font-bold text-xs uppercase tracking-wide px-3 py-1.5 pr-6 rounded-lg cursor-pointer focus:outline-none"
                    >
                      {accounts.map((acc) => (
                        <option
                          key={acc.id}
                          value={acc.id}
                          disabled={acc.id === activeAccount?.id}
                          className="bg-[#1E1E1E] text-white"
                        >
                          {acc.name}
                        </option>
                      ))}
                    </select>
                    <ChevronDown className="w-3.5 h-3.5 absolute right-1.5 top-1/2 -translate-y-1/2 pointer-events-none opacity-80" />
                  </div>
                </div>
              ) : (
                <div className="flex flex-col items-center">
                  <span className="text-[10px] uppercase font-medium tracking-wider opacity-80">
                    Categoría
                  </span>
                  <div className="flex items-center space-x-1 font-bold text-xs uppercase tracking-wide mt-1 px-2 py-1 rounded-lg bg-black/10">
                    <Wallet className="w-3.5 h-3.5 mr-1 shrink-0" />
                    <span className="truncate max-w-[120px]">
                      {activeCategory?.name || 'Almuerzo'}
                    </span>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Plantillas Bar */}
          <button
            type="button"
            onClick={() => setShowTemplates(!showTemplates)}
            className="w-full bg-black/20 hover:bg-black/30 py-2 px-4 flex items-center justify-center space-x-2 transition-colors"
          >
            <Bookmark className="w-3.5 h-3.5 text-white/90" />
            <span className="text-[10px] font-bold tracking-widest text-white uppercase">
              {showTemplates ? 'Ocultar Plantillas Rápidas' : 'Plantillas Rápidas'}
            </span>
          </button>
        </header>

        {/* Templates Drawer if open */}
        {showTemplates && (
          <div className="bg-[#1A1A1A] px-3 py-2.5 border-b border-neutral-800 flex gap-2 overflow-x-auto">
            {TEMPLATES.map((tpl) => (
              <button
                key={tpl.label}
                type="button"
                onClick={() => {
                  setTxType(tpl.type);
                  setExpression(tpl.amount);
                  setNote(tpl.note);
                  setIsDefaultVal(false);
                  setShowTemplates(false);
                }}
                className="shrink-0 px-3 py-1.5 rounded-lg bg-[#252525] hover:bg-[#2E2E2E] border border-white/10 text-left transition-colors"
              >
                <div className="text-xs font-semibold text-white whitespace-nowrap">
                  {tpl.label}
                </div>
                <div className="text-[11px] font-mono text-[#00E676]">
                  Q {tpl.amount}
                </div>
              </button>
            ))}
          </div>
        )}

        {/* Main Body */}
        <div className="flex-1 flex flex-col bg-[#121212] overflow-y-auto">
          {/* Horizontal Category Slider */}
          <section className="py-3 px-3 border-b border-neutral-800 bg-[#181818]">
            <div className="flex items-center justify-between px-1 mb-2">
              <span className="text-[11px] font-semibold tracking-wider uppercase text-neutral-400">
                Seleccionar Categoría
              </span>
              <span className="text-[11px] text-[#00acc1] font-medium">
                {filteredCategories.length} rubros
              </span>
            </div>
            <div className="flex space-x-3 overflow-x-auto py-1 px-1">
              {filteredCategories.map((cat) => {
                const isSelected = activeCategory?.id === cat.id;
                return (
                  <button
                    key={cat.id}
                    type="button"
                    onClick={() => setSelectedCategoryId(cat.id)}
                    className="flex flex-col items-center min-w-[66px] group"
                  >
                    <div
                      className={`w-12 h-12 rounded-full flex items-center justify-center mb-1.5 transition-transform ${
                        isSelected
                          ? 'bg-[#00acc1]/20 border-2 border-[#00acc1] text-[#00acc1] scale-105'
                          : 'bg-neutral-800 border border-neutral-700 text-neutral-300 group-hover:bg-neutral-700'
                      }`}
                    >
                      {renderCategoryIcon(cat.iconName)}
                    </div>
                    <span
                      className={`text-[11px] truncate w-full text-center ${
                        isSelected
                          ? 'text-[#00acc1] font-semibold'
                          : 'text-neutral-400'
                      }`}
                    >
                      {cat.name.split(' ')[0]}
                    </span>
                  </button>
                );
              })}
            </div>
          </section>

          {/* Date & Note Input */}
          <section className="p-3 space-y-2 bg-[#141414] border-b border-neutral-800/80 text-xs">
            <div className="flex items-center justify-between px-3 py-2 bg-neutral-900/90 rounded-lg border border-neutral-800">
              <div className="flex items-center space-x-2.5 text-neutral-300">
                <Calendar className="w-4 h-4 text-[#00acc1]" />
                <span className="font-medium">Fecha del movimiento:</span>
              </div>
              <input
                type="date"
                value={txDateIso}
                onChange={(e) => setTxDateIso(e.target.value)}
                className="bg-[#202020] text-white font-mono text-xs px-2.5 py-1 rounded border border-white/10 focus:outline-none focus:border-[#00acc1]"
              />
            </div>

            <div className="flex items-center px-3 py-2 bg-neutral-900/90 rounded-lg border border-neutral-800 focus-within:border-[#00acc1] transition-colors">
              <FileText className="w-4 h-4 text-neutral-400 mr-2.5 shrink-0" />
              <input
                type="text"
                value={note}
                onChange={(e) => setNote(e.target.value)}
                maxLength={200}
                placeholder="Nota / Descripción (ej. Almuerzo con clientes)"
                className="w-full bg-transparent border-0 p-0 text-xs text-neutral-200 placeholder-neutral-500 focus:ring-0 focus:outline-none"
              />
            </div>
            {errorMsg && (
              <p className="text-xs text-[#FF5252] px-1 font-medium">
                {errorMsg}
              </p>
            )}
          </section>

          {/* 4x4 BudgetBakers Calculator Keypad */}
          <section className="flex-1 grid grid-cols-4 bg-[#181818] divide-x divide-y divide-neutral-800/90 min-h-[210px]">
            {['7', '8', '9', '/'].map((k) => (
              <button
                key={k}
                type="button"
                onClick={() => handleKeyPress(k)}
                className={`h-12 sm:h-13 flex items-center justify-center text-xl font-light active:bg-neutral-800 transition-colors ${
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
                className={`h-12 sm:h-13 flex items-center justify-center text-xl font-light active:bg-neutral-800 transition-colors ${
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
                className={`h-12 sm:h-13 flex items-center justify-center text-xl font-light active:bg-neutral-800 transition-colors ${
                  k === '-'
                    ? 'bg-neutral-900/60 text-neutral-400 font-normal'
                    : 'text-neutral-200'
                }`}
              >
                {k === '-' ? '−' : k}
              </button>
            ))}
            <button
              type="button"
              onClick={() => handleKeyPress('.')}
              className="h-12 sm:h-13 flex items-center justify-center text-xl font-light text-neutral-300 active:bg-neutral-800"
            >
              .
            </button>
            <button
              type="button"
              onClick={() => handleKeyPress('0')}
              className="h-12 sm:h-13 flex items-center justify-center text-xl font-light text-neutral-200 active:bg-neutral-800"
            >
              0
            </button>
            <button
              type="button"
              onClick={() => handleKeyPress('backspace')}
              className="h-12 sm:h-13 flex items-center justify-center text-neutral-300 active:bg-neutral-800"
              aria-label="Borrar"
            >
              <Delete className="w-5 h-5" />
            </button>
            <button
              type="button"
              onClick={() =>
                ['+', '-', '*', '/'].some((op) => expression.slice(1).includes(op))
                  ? handleKeyPress('=')
                  : handleKeyPress('+')
              }
              className="h-12 sm:h-13 flex items-center justify-center text-xl text-neutral-300 bg-neutral-900/60 active:bg-neutral-800 font-normal"
            >
              {['+', '-', '*', '/'].some((op) => expression.slice(1).includes(op))
                ? '='
                : '+'}
            </button>
          </section>
        </div>

        {/* Bottom Confirm Button */}
        <footer className="p-3 bg-[#141414] border-t border-neutral-800">
          <button
            type="button"
            onClick={handleSave}
            disabled={isSaving}
            className="w-full py-3.5 px-4 bg-gradient-to-r from-[#00acc1] to-[#00838f] hover:from-[#00bcd4] hover:to-[#0097a7] text-white font-semibold text-sm rounded-xl shadow-lg flex items-center justify-center space-x-2 transition-all disabled:opacity-50"
          >
            <Check className="w-4 h-4 stroke-[2.5]" />
            <span>
              {isSaving
                ? 'Ejecutando runTransaction atómica...'
                : editingTransaction
                ? 'Actualizar y Cuadrar Saldos'
                : 'Guardar Transacción Atómica'}
            </span>
          </button>
        </footer>
      </div>
    </div>
  );
};
