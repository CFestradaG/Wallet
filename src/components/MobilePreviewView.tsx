import React, { useState } from 'react';
import {
  Menu,
  Bell,
  Plus,
  Home,
  Wallet,
  ReceiptText,
  PieChart,
  LayoutGrid,
  ArrowUpRight,
  ArrowDownLeft,
  ArrowLeftRight,
  Search,
  Calendar,
  ChevronRight,
  X,
  Star,
  Utensils,
  ShoppingCart,
  Fuel,
  Zap,
  Film,
  HeartPulse,
  Briefcase,
} from 'lucide-react';
import {
  WalletAccount,
  WalletTransaction,
  WalletBudget,
  TransactionType,
} from '../types/wallet';

interface MobilePreviewViewProps {
  userName: string;
  accounts: WalletAccount[];
  transactions: WalletTransaction[];
  budgets: WalletBudget[];
  totalIncome: number;
  totalExpense: number;
  netWorth: number;
  onOpenCalculator: (type?: TransactionType) => void;
  onOpenAddAccount: () => void;
}

export const MobilePreviewView: React.FC<MobilePreviewViewProps> = ({
  userName,
  accounts,
  transactions,
  budgets,
  totalIncome,
  totalExpense,
  netWorth,
  onOpenCalculator,
  onOpenAddAccount,
}) => {
  const [mobileTab, setMobileTab] = useState<'inicio' | 'registros' | 'cuentas'>('inicio');
  const [drawerOpen, setDrawerOpen] = useState<boolean>(false);
  const [searchQuery, setSearchQuery] = useState<string>('');

  const filteredTx = transactions.filter(
    (t) =>
      t.note.toLowerCase().includes(searchQuery.toLowerCase()) ||
      t.categoryName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      t.accountName.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const renderCategoryIcon = (iconName: string) => {
    switch (iconName) {
      case 'shopping_cart':
        return <ShoppingCart className="w-5 h-5" />;
      case 'fuel':
        return <Fuel className="w-5 h-5" />;
      case 'wifi':
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

  return (
    <div className="flex flex-col lg:flex-row items-start justify-center gap-8 py-4">
      {/* Mobile Device 1: Home / Active Interactive Simulator */}
      <div className="w-full max-w-[390px] mx-auto bg-[#121212] rounded-[40px] border-[6px] border-[#2A2A2A] shadow-2xl overflow-hidden relative flex flex-col min-h-[790px]">
        {/* Simulated iOS Status Bar (6:07) */}
        <div className="pt-3 pb-2 px-6 flex items-center justify-between text-xs font-semibold text-neutral-300 bg-[#121212] select-none">
          <span>6:07</span>
          <div className="w-24 h-5 bg-black rounded-full flex items-center justify-end pr-2 space-x-1.5">
            <span className="w-2 h-2 rounded-full bg-[#00E676]" />
            <span className="w-2 h-2 rounded-full bg-neutral-800" />
          </div>
          <span className="text-[11px] font-mono">5G · 68%</span>
        </div>

        {/* Navigation Drawer Overlay (Matching Image 12.jpeg) */}
        {drawerOpen && (
          <div className="absolute inset-0 z-40 flex">
            <div className="w-4/5 bg-[#161616] h-full p-5 flex flex-col justify-between border-r border-white/10 shadow-2xl">
              <div>
                <div className="flex items-center justify-between pb-5 border-b border-white/10">
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 rounded-full bg-neutral-700 flex items-center justify-center text-white font-bold text-base">
                      {userName.slice(0, 2).toUpperCase()}
                    </div>
                    <div>
                      <div className="font-bold text-white text-base">
                        {userName}
                      </div>
                      <div className="text-xs text-neutral-400">Mi Wallet</div>
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => setDrawerOpen(false)}
                    className="p-1.5 rounded-full hover:bg-white/10 text-neutral-400"
                  >
                    <X className="w-5 h-5" />
                  </button>
                </div>

                <nav className="mt-4 space-y-1 text-sm">
                  {[
                    { id: 'inicio', label: 'Inicio', color: 'text-[#FF5252]' },
                    { id: 'cuentas', label: 'Cuentas', color: 'text-[#00DCF5]' },
                    { id: 'registros', label: 'Registros', color: 'text-[#FFB300]' },
                  ].map((item) => (
                    <button
                      key={item.id}
                      type="button"
                      onClick={() => {
                        setMobileTab(item.id as 'inicio' | 'registros' | 'cuentas');
                        setDrawerOpen(false);
                      }}
                      className={`w-full flex items-center justify-between px-4 py-3 rounded-full transition-colors ${
                        mobileTab === item.id
                          ? 'bg-[#28354A] text-white font-semibold'
                          : 'text-neutral-300 hover:bg-white/5'
                      }`}
                    >
                      <span>{item.label}</span>
                      <ChevronRight className="w-4 h-4 opacity-60" />
                    </button>
                  ))}
                  <div className="pt-2 border-t border-white/5 mt-2 space-y-1">
                    <div className="px-4 py-2.5 text-neutral-400 flex items-center justify-between">
                      <span>Sincronización bancaria</span>
                      <span className="text-[10px] font-mono text-[#00E676]">
                        ACTIVA
                      </span>
                    </div>
                    <div className="px-4 py-2.5 text-neutral-400 flex items-center justify-between">
                      <span>Inversiones</span>
                      <span className="text-[10px] font-semibold text-[#00DCF5]">
                        Nuevo
                      </span>
                    </div>
                    <div className="px-4 py-2.5 text-neutral-400">
                      Pagos planificados
                    </div>
                    <div className="px-4 py-2.5 text-neutral-400">
                      Presupuestos y Metas
                    </div>
                  </div>
                </nav>
              </div>

              <div className="text-[11px] text-neutral-500 font-mono">
                Cloud Firestore · Modo Offline Activo
              </div>
            </div>
            <div
              className="flex-1 bg-black/60"
              onClick={() => setDrawerOpen(false)}
            />
          </div>
        )}

        {/* Mobile Top Bar */}
        <div className="px-4 py-2.5 flex items-center justify-between border-b border-white/5">
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => setDrawerOpen(true)}
              className="p-1.5 rounded-lg hover:bg-white/10 text-white"
              aria-label="Abrir menú"
            >
              <Menu className="w-5 h-5" />
            </button>
            <span className="text-lg font-bold text-white">
              {mobileTab === 'inicio'
                ? 'Inicio'
                : mobileTab === 'registros'
                ? 'Registros'
                : 'Cuentas'}
            </span>
          </div>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => setMobileTab('registros')}
              className="p-1.5 rounded-full hover:bg-white/10 text-neutral-300 relative"
            >
              <Bell className="w-5 h-5" />
              <span className="w-2 h-2 rounded-full bg-[#FF5252] absolute top-1.5 right-1.5" />
            </button>
            <div className="w-8 h-8 rounded-full bg-[#004D40] border border-[#00E676] flex items-center justify-center text-xs font-bold text-white">
              {userName.slice(0, 2).toUpperCase()}
            </div>
          </div>
        </div>

        {/* Scrollable Mobile Content */}
        <div className="flex-1 overflow-y-auto px-4 py-3 space-y-4 pb-24">
          {mobileTab === 'inicio' && (
            <>
              {/* Patrimonio Neto Total Hero Card (Image 3.png) */}
              <div className="bg-[#1B221F] border border-[#00E676]/20 rounded-2xl p-4">
                <div className="flex items-center justify-between">
                  <span className="text-[11px] uppercase tracking-wider text-neutral-400 font-semibold">
                    Patrimonio Neto Total
                  </span>
                  <span className="text-xs font-mono font-bold text-[#00E676]">
                    ↗ +4.2%
                  </span>
                </div>
                <div className="text-2xl font-bold font-mono tabular-nums text-white mt-1">
                  GTQ{' '}
                  {netWorth.toLocaleString('en-US', {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2,
                  })}
                </div>
                <div className="flex items-center justify-between mt-3 pt-2 border-t border-white/5 text-[11px] text-neutral-400">
                  <span>Sincronizado con Firestore</span>
                  <span className="text-[#00E676] font-mono">● En línea</span>
                </div>
              </div>

              {/* Mis cuentas en Wallet (Image 3 & Image 11) */}
              <div>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm font-bold text-white">
                    Mis cuentas en Wallet
                  </span>
                  <button
                    type="button"
                    onClick={onOpenAddAccount}
                    className="text-xs text-[#00DCF5] font-semibold hover:underline"
                  >
                    + Agregar cuenta
                  </button>
                </div>
                <div className="grid grid-cols-2 gap-2.5">
                  {accounts.map((acc) => {
                    const isCash = acc.type === 'cash';
                    const isNeg = acc.balance < 0;
                    return (
                      <div
                        key={acc.id}
                        className={`p-3 rounded-2xl border transition-transform ${
                          isCash
                            ? 'bg-gradient-to-br from-[#00ACC1] to-[#007C91] border-white/15 text-white'
                            : 'bg-[#1E1E1E] border-white/10 text-white'
                        }`}
                      >
                        <div className="text-xs font-medium opacity-90 truncate">
                          {acc.name}
                        </div>
                        <div className="text-[10px] uppercase opacity-70 mt-1">
                          {acc.type === 'credit_card'
                            ? 'Tarjeta Crédito'
                            : 'Saldo Disponible'}
                        </div>
                        <div
                          className={`text-sm font-bold font-mono tabular-nums mt-0.5 ${
                            !isCash && isNeg ? 'text-[#FF5252]' : 'text-white'
                          }`}
                        >
                          {acc.balance < 0 ? '-' : ''}GTQ{' '}
                          {Math.abs(acc.balance).toLocaleString('en-US', {
                            minimumFractionDigits: 2,
                            maximumFractionDigits: 2,
                          })}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Estructura de gastos card */}
              <div className="bg-[#1E1E1E] border border-white/5 rounded-2xl p-4 space-y-3">
                <div className="flex items-center justify-between">
                  <div>
                    <h3 className="text-sm font-bold text-white">
                      Estructura de gastos
                    </h3>
                    <span className="text-[11px] text-neutral-400 uppercase">
                      Octubre 2026
                    </span>
                  </div>
                  <div className="text-right">
                    <div className="text-lg font-bold font-mono tabular-nums text-white">
                      GTQ{' '}
                      {totalExpense.toLocaleString('en-US', {
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2,
                      })}
                    </div>
                  </div>
                </div>

                {/* Quick Action Buttons: Gasto | Ingreso | Transferir */}
                <div className="grid grid-cols-3 gap-2 pt-1">
                  <button
                    type="button"
                    onClick={() => onOpenCalculator('expense')}
                    className="py-2 px-2 rounded-xl bg-[#252525] hover:bg-[#2E2E2E] text-[#FF5252] text-xs font-semibold flex items-center justify-center gap-1"
                  >
                    <ArrowUpRight className="w-3.5 h-3.5" />
                    <span>Gasto</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => onOpenCalculator('income')}
                    className="py-2 px-2 rounded-xl bg-[#252525] hover:bg-[#2E2E2E] text-[#00E676] text-xs font-semibold flex items-center justify-center gap-1"
                  >
                    <ArrowDownLeft className="w-3.5 h-3.5" />
                    <span>Ingreso</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => onOpenCalculator('transfer')}
                    className="py-2 px-2 rounded-xl bg-[#252525] hover:bg-[#2E2E2E] text-[#00DCF5] text-xs font-semibold flex items-center justify-center gap-1"
                  >
                    <ArrowLeftRight className="w-3.5 h-3.5" />
                    <span>Transferir</span>
                  </button>
                </div>
              </div>

              {/* Últimos registros list */}
              <div className="bg-[#1E1E1E] border border-white/5 rounded-2xl p-4">
                <div className="flex items-center justify-between mb-3">
                  <span className="text-sm font-bold text-white">
                    Últimos registros
                  </span>
                  <button
                    type="button"
                    onClick={() => setMobileTab('registros')}
                    className="text-xs text-[#00E676] font-semibold"
                  >
                    Ver todos
                  </button>
                </div>
                <div className="space-y-3">
                  {transactions.slice(0, 5).map((tx) => (
                    <div
                      key={tx.id}
                      className="flex items-center justify-between text-xs"
                    >
                      <div className="flex items-center gap-2.5 min-w-0">
                        <div className="w-9 h-9 rounded-full bg-[#252525] flex items-center justify-center text-[#00DCF5] shrink-0">
                          {renderCategoryIcon(tx.categoryIcon)}
                        </div>
                        <div className="min-w-0">
                          <div className="font-semibold text-white truncate">
                            {tx.note.split('·')[0]}
                          </div>
                          <div className="text-[11px] text-neutral-400 truncate">
                            {tx.accountName} · {tx.categoryName}
                          </div>
                        </div>
                      </div>
                      <span
                        className={`font-mono font-bold tabular-nums shrink-0 ml-2 ${
                          tx.type === 'income'
                            ? 'text-[#00E676]'
                            : 'text-[#FF5252]'
                        }`}
                      >
                        {tx.type === 'income' ? '+' : '-'}GTQ{' '}
                        {tx.amount.toFixed(2)}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            </>
          )}

          {mobileTab === 'registros' && (
            <>
              {/* Search Bar (Image 7.png) */}
              <div className="relative">
                <Search className="w-4 h-4 text-neutral-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="search"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Buscar transacciones, comercios..."
                  className="w-full bg-[#1E1E1E] text-xs text-white placeholder-neutral-500 pl-9 pr-4 py-2.5 rounded-2xl border border-white/5 focus:border-[#00E676] focus:outline-none"
                />
              </div>

              {/* Monthly Summary Card (Image 7.png) */}
              <div className="bg-gradient-to-br from-[#282828] to-[#1E1E1E] p-3.5 rounded-2xl border border-white/5">
                <div className="flex items-center justify-between pb-2 border-b border-white/5 text-[11px] text-neutral-400">
                  <span className="uppercase font-semibold">
                    Resumen de Octubre 2026
                  </span>
                  <span>31 días</span>
                </div>
                <div className="grid grid-cols-3 gap-2 pt-2.5 text-center">
                  <div>
                    <span className="text-[10px] text-neutral-400 block">
                      ↓ Ingresos
                    </span>
                    <span className="text-xs font-bold font-mono text-[#00E676]">
                      +Q {totalIncome.toLocaleString('en-US')}
                    </span>
                  </div>
                  <div className="border-x border-white/5">
                    <span className="text-[10px] text-neutral-400 block">
                      ↑ Gastos
                    </span>
                    <span className="text-xs font-bold font-mono text-[#FF5252]">
                      -Q {totalExpense.toLocaleString('en-US')}
                    </span>
                  </div>
                  <div>
                    <span className="text-[10px] text-neutral-400 block">
                      Balance Neto
                    </span>
                    <span className="text-xs font-bold font-mono text-white">
                      Q {(totalIncome - totalExpense).toLocaleString('en-US')}
                    </span>
                  </div>
                </div>
              </div>

              {/* Transaction List */}
              <div className="bg-[#1E1E1E] rounded-2xl border border-white/5 divide-y divide-white/5 overflow-hidden">
                {filteredTx.map((tx) => (
                  <div
                    key={tx.id}
                    className="p-3 flex items-center justify-between hover:bg-white/5 transition-colors"
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="w-10 h-10 rounded-2xl bg-[#252525] flex items-center justify-center text-[#00E676] shrink-0">
                        {renderCategoryIcon(tx.categoryIcon)}
                      </div>
                      <div className="min-w-0">
                        <div className="text-xs font-semibold text-white truncate">
                          {tx.note}
                        </div>
                        <div className="text-[11px] text-neutral-400 truncate">
                          {tx.accountName} · {tx.categoryName}
                        </div>
                      </div>
                    </div>
                    <div className="text-right shrink-0 ml-2">
                      <span
                        className={`text-xs font-bold font-mono tabular-nums ${
                          tx.type === 'income'
                            ? 'text-[#00E676]'
                            : 'text-[#FF5252]'
                        }`}
                      >
                        {tx.type === 'income' ? '+' : '-'}GTQ{' '}
                        {tx.amount.toFixed(2)}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </>
          )}

          {mobileTab === 'cuentas' && (
            <div className="space-y-3">
              {accounts.map((acc) => (
                <div
                  key={acc.id}
                  className="bg-[#1E1E1E] border border-white/5 rounded-2xl p-4 flex items-center justify-between"
                >
                  <div>
                    <div className="text-sm font-bold text-white">
                      {acc.name}
                    </div>
                    <div className="text-xs text-neutral-400">
                      {acc.subtitle}
                    </div>
                  </div>
                  <div
                    className={`text-base font-bold font-mono tabular-nums ${
                      acc.balance < 0 ? 'text-[#FF5252]' : 'text-[#00E676]'
                    }`}
                  >
                    {acc.balance < 0 ? '-' : ''}GTQ{' '}
                    {Math.abs(acc.balance).toFixed(2)}
                  </div>
                </div>
              ))}
              <button
                type="button"
                onClick={onOpenAddAccount}
                className="w-full py-3 rounded-2xl bg-[#252525] hover:bg-[#2E2E2E] text-xs font-semibold text-[#00E676] border border-white/10"
              >
                + Agregar nueva cuenta bancaria o efectivo
              </button>
            </div>
          )}
        </div>

        {/* Floating Action Button (+) */}
        <button
          type="button"
          onClick={() => onOpenCalculator('expense')}
          className="absolute bottom-20 right-5 w-13 h-13 rounded-2xl bg-[#00E676] text-[#003918] shadow-lg flex items-center justify-center hover:scale-105 active:scale-95 transition-transform"
          aria-label="Nueva transacción"
        >
          <Plus className="w-7 h-7 stroke-[2.5]" />
        </button>

        {/* Bottom Navigation Bar */}
        <nav className="bg-[#181818] border-t border-white/10 grid grid-cols-4 h-16 items-center px-2">
          <button
            type="button"
            onClick={() => setMobileTab('inicio')}
            className={`flex flex-col items-center justify-center ${
              mobileTab === 'inicio' ? 'text-[#00E676]' : 'text-neutral-400'
            }`}
          >
            <Home className="w-5 h-5" />
            <span className="text-[10px] mt-0.5 font-medium">Inicio</span>
          </button>
          <button
            type="button"
            onClick={() => setMobileTab('cuentas')}
            className={`flex flex-col items-center justify-center ${
              mobileTab === 'cuentas' ? 'text-[#00E676]' : 'text-neutral-400'
            }`}
          >
            <Wallet className="w-5 h-5" />
            <span className="text-[10px] mt-0.5 font-medium">Cuentas</span>
          </button>
          <button
            type="button"
            onClick={() => setMobileTab('registros')}
            className={`flex flex-col items-center justify-center ${
              mobileTab === 'registros' ? 'text-[#00E676]' : 'text-neutral-400'
            }`}
          >
            <ReceiptText className="w-5 h-5" />
            <span className="text-[10px] mt-0.5 font-medium">Registros</span>
          </button>
          <button
            type="button"
            onClick={() => setDrawerOpen(true)}
            className="flex flex-col items-center justify-center text-neutral-400"
          >
            <LayoutGrid className="w-5 h-5" />
            <span className="text-[10px] mt-0.5 font-medium">Más</span>
          </button>
        </nav>
      </div>

      {/* Right Column: Mobile Feature Companion & Budgets Summary */}
      <div className="flex-1 max-w-xl space-y-5">
        <div className="bg-[#1C1B1B] border border-white/5 rounded-2xl p-6">
          <h2 className="text-lg font-bold text-white">
            Simulador Móvil Interactivo (Material 3 · #121212)
          </h2>
          <p className="text-sm text-[#A0A0A0] mt-1">
            Esta vista replica fielmente los diseños móviles de Stitch (pantallas{' '}
            <strong className="text-white">Inicio</strong>,{' '}
            <strong className="text-white">Registros</strong>,{' '}
            <strong className="text-white">Drawer Lateral</strong> y{' '}
            <strong className="text-white">Calculadora de Nueva Transacción</strong>)
            conectados en tiempo real a las mismas subcolecciones de Cloud Firestore.
          </p>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-5">
            <button
              type="button"
              onClick={() => onOpenCalculator('expense')}
              className="py-3 px-4 rounded-xl bg-[#00acc1] hover:bg-[#00bcd4] text-white font-semibold text-xs flex items-center justify-center gap-2 transition-colors"
            >
              <Plus className="w-4 h-4" />
              <span>Abrir Calculadora (#00ACC1)</span>
            </button>
            <button
              type="button"
              onClick={() => setDrawerOpen(true)}
              className="py-3 px-4 rounded-xl bg-[#252525] hover:bg-[#2E2E2E] text-white font-semibold text-xs flex items-center justify-center gap-2 border border-white/10 transition-colors"
            >
              <Menu className="w-4 h-4 text-[#00E676]" />
              <span>Abrir Menú Lateral (Drawer)</span>
            </button>
          </div>
        </div>

        {/* Active Budgets in Mobile Preview */}
        <div className="bg-[#1C1B1B] border border-white/5 rounded-2xl p-6 space-y-4">
          <h3 className="text-base font-bold text-white">
            Presupuestos Sincronizados (/users/&#123;uid&#125;/budgets)
          </h3>
          {budgets.map((b) => {
            const pct = Math.min(
              100,
              Math.round((b.spentAmount / b.limitAmount) * 100)
            );
            return (
              <div key={b.id} className="bg-[#201F1F] p-4 rounded-xl space-y-2">
                <div className="flex items-center justify-between text-sm">
                  <span className="font-semibold text-white">{b.name}</span>
                  <span className="font-mono text-xs text-[#A0A0A0]">
                    GTQ {b.spentAmount.toFixed(2)} / GTQ {b.limitAmount.toFixed(2)} (
                    {pct}%)
                  </span>
                </div>
                <div className="w-full h-2 rounded-full bg-[#353534] overflow-hidden">
                  <div
                    className={`h-full rounded-full ${
                      pct >= 90
                        ? 'bg-[#FF5252]'
                        : pct >= 70
                        ? 'bg-[#00DCF5]'
                        : 'bg-[#00E676]'
                    }`}
                    style={{ width: `${pct}%` }}
                  />
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};
