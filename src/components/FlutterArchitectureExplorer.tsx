import React, { useState } from 'react';
import {
  Copy,
  Check,
  FolderTree,
  FileCode,
  Database,
  ShieldCheck,
  Layers,
  Terminal,
} from 'lucide-react';
import {
  FLUTTER_FOLDER_TREE,
  FLUTTER_FILES_DOCS,
  FlutterFileDoc,
} from '../data/flutterCleanArchDocs';

export const FlutterArchitectureExplorer: React.FC = () => {
  const [selectedFile, setSelectedFile] = useState<FlutterFileDoc>(
    FLUTTER_FILES_DOCS[0]
  );
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const handleCopy = (id: string, text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  return (
    <div className="flex flex-col gap-6">
      {/* Architecture Header Banner */}
      <div className="bg-[#1C1B1B] border border-white/5 rounded-2xl p-6 flex flex-col lg:flex-row lg:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 text-xs font-mono text-[#00E676] mb-1">
            <span>FLUTTER 3.24+ · MATERIAL 3 (#121212)</span>
            <span>·</span>
            <span>RIVERPOD 2.6</span>
            <span>·</span>
            <span>CLOUD FIRESTORE + GO_ROUTER</span>
          </div>
          <h1 className="text-2xl font-bold text-white tracking-tight">
            Arquitectura Clean Architecture & Configuración Inicial Flutter
          </h1>
          <p className="text-sm text-[#A0A0A0] mt-1 max-w-3xl">
            Estructura modular completa (Tarea 1) y archivos de arranque (Tarea 2:{' '}
            <code className="text-[#75FF9E] font-mono">main.dart</code>,{' '}
            <code className="text-[#75FF9E] font-mono">theme.dart</code>,{' '}
            <code className="text-[#75FF9E] font-mono">app_router.dart</code>)
            conectados a las 5 subcolecciones por usuario en Cloud Firestore.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={() => handleCopy('tree', FLUTTER_FOLDER_TREE)}
            className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-[#252525] hover:bg-[#2E2E2E] text-white text-xs font-semibold border border-white/10 transition-colors whitespace-nowrap"
          >
            {copiedId === 'tree' ? (
              <Check className="w-4 h-4 text-[#00E676]" />
            ) : (
              <FolderTree className="w-4 h-4 text-[#00DCF5]" />
            )}
            <span>
              {copiedId === 'tree' ? 'Árbol Copiado' : 'Copiar Árbol de Carpetas'}
            </span>
          </button>
          <button
            type="button"
            onClick={() => handleCopy(selectedFile.id, selectedFile.code)}
            className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-[#00E676] hover:bg-[#62FF96] text-[#003918] text-xs font-bold transition-colors whitespace-nowrap"
          >
            {copiedId === selectedFile.id ? (
              <Check className="w-4 h-4" />
            ) : (
              <Copy className="w-4 h-4" />
            )}
            <span>
              {copiedId === selectedFile.id
                ? `¡${selectedFile.filename} Copiado!`
                : `Copiar ${selectedFile.filename}`}
            </span>
          </button>
        </div>
      </div>

      {/* Firestore Subcollections Schema Cards */}
      <div className="grid grid-cols-1 md:grid-cols-5 gap-3">
        {[
          {
            sub: '/accounts',
            path: '/users/{userId}/accounts/{accId}',
            desc: 'Efectivo, BAC Credomatic, Banco Industrial BI',
            accent: 'text-[#00DCF5]',
          },
          {
            sub: '/transactions',
            path: '/users/{userId}/transactions/{txId}',
            desc: 'Ingresos, Gastos y Transferencias con fecha ISO',
            accent: 'text-[#00E676]',
          },
          {
            sub: '/categories',
            path: '/users/{userId}/categories/{catId}',
            desc: 'Comida, Servicios, Gasolina, Ocio, Nómina',
            accent: 'text-[#FFB3AE]',
          },
          {
            sub: '/budgets',
            path: '/users/{userId}/budgets/{budgetId}',
            desc: 'Topes mensuales (Supermercado, Gasolina, Hogar)',
            accent: 'text-[#A3F1FF]',
          },
          {
            sub: '/summaries/{ym}',
            path: '/users/{userId}/summaries/{year_month}',
            desc: 'Agregado mensual (ej. 2026_10) para carga O(1)',
            accent: 'text-[#75FF9E]',
          },
        ].map((item) => (
          <div
            key={item.sub}
            className="bg-[#1C1B1B] border border-white/5 rounded-xl p-4 flex flex-col justify-between"
          >
            <div>
              <div className="flex items-center justify-between mb-1.5">
                <span className={`font-mono text-xs font-bold ${item.accent}`}>
                  {item.sub}
                </span>
                <Database className="w-3.5 h-3.5 text-[#859585]" />
              </div>
              <div className="font-mono text-[11px] text-white/90 break-all mb-1.5">
                {item.path}
              </div>
            </div>
            <p className="text-xs text-[#A0A0A0]">{item.desc}</p>
          </div>
        ))}
      </div>

      {/* Main Split Grid: Tarea 1 (Folder Structure) & Tarea 2 (Dart Code Files) */}
      <div className="grid grid-cols-1 xl:grid-cols-12 gap-6">
        {/* Left Column: Tarea 1 - Complete Clean Architecture Folder Tree */}
        <div className="xl:col-span-5 bg-[#1C1B1B] border border-white/5 rounded-2xl p-5 flex flex-col">
          <div className="flex items-center justify-between pb-4 mb-4 border-b border-white/5">
            <div className="flex items-center gap-2.5">
              <Layers className="w-5 h-5 text-[#00E676]" />
              <div>
                <h2 className="text-base font-bold text-white">
                  Tarea 1: Estructura Clean Architecture
                </h2>
                <p className="text-xs text-[#A0A0A0]">
                  Separación estricta: core/, domain/, data/, presentation/
                </p>
              </div>
            </div>
            <button
              type="button"
              onClick={() => handleCopy('tree_box', FLUTTER_FOLDER_TREE)}
              className="px-2.5 py-1 rounded-lg bg-[#252525] hover:bg-[#2E2E2E] text-xs text-white font-mono flex items-center gap-1.5 transition-colors"
            >
              {copiedId === 'tree_box' ? (
                <Check className="w-3.5 h-3.5 text-[#00E676]" />
              ) : (
                <Copy className="w-3.5 h-3.5 text-[#A0A0A0]" />
              )}
              <span>Copiar</span>
            </button>
          </div>

          <pre className="flex-1 font-mono text-[11.5px] leading-relaxed text-[#E5E2E1] bg-[#121212] p-4 rounded-xl border border-white/5 overflow-x-auto max-h-[620px]">
            {FLUTTER_FOLDER_TREE}
          </pre>
        </div>

        {/* Right Column: Tarea 2 - Initial Configuration Dart Files */}
        <div className="xl:col-span-7 bg-[#1C1B1B] border border-white/5 rounded-2xl p-5 flex flex-col">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-4 mb-4 border-b border-white/5">
            <div className="flex items-center gap-2.5">
              <FileCode className="w-5 h-5 text-[#00DCF5]" />
              <div>
                <h2 className="text-base font-bold text-white">
                  Tarea 2: Archivos de Configuración Inicial Flutter
                </h2>
                <p className="text-xs text-[#A0A0A0]">
                  Selecciona un archivo para inspeccionar o copiar su código Dart
                </p>
              </div>
            </div>

            {/* File Selector Tabs */}
            <div className="flex flex-wrap gap-1.5 bg-[#121212] p-1 rounded-xl border border-white/5">
              {FLUTTER_FILES_DOCS.map((doc) => {
                const active = selectedFile.id === doc.id;
                return (
                  <button
                    key={doc.id}
                    type="button"
                    onClick={() => setSelectedFile(doc)}
                    className={`px-3 py-1.5 rounded-lg font-mono text-xs transition-colors whitespace-nowrap ${
                      active
                        ? 'bg-[#00E676] text-[#003918] font-bold'
                        : 'text-[#A0A0A0] hover:text-white hover:bg-[#201F1F]'
                    }`}
                  >
                    {doc.filename}
                  </button>
                );
              })}
            </div>
          </div>

          {/* File Metadata Bar */}
          <div className="bg-[#252525] rounded-xl p-3.5 mb-3 flex flex-col sm:flex-row sm:items-center justify-between gap-2 border border-white/5">
            <div>
              <div className="flex items-center gap-2">
                <Terminal className="w-4 h-4 text-[#00E676]" />
                <span className="font-mono text-xs font-bold text-white">
                  {selectedFile.path}
                </span>
              </div>
              <p className="text-xs text-[#A0A0A0] mt-1">
                {selectedFile.description}
              </p>
            </div>
            <button
              type="button"
              onClick={() => handleCopy(selectedFile.id, selectedFile.code)}
              className="shrink-0 inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-[#121212] hover:bg-black text-[#75FF9E] font-mono text-xs border border-[#00E676]/30 transition-colors"
            >
              {copiedId === selectedFile.id ? (
                <Check className="w-3.5 h-3.5" />
              ) : (
                <Copy className="w-3.5 h-3.5" />
              )}
              <span>
                {copiedId === selectedFile.id ? 'Copiado' : 'Copiar Código'}
              </span>
            </button>
          </div>

          {/* Dart Code Viewer */}
          <pre className="flex-1 font-mono text-xs leading-relaxed text-[#E5E2E1] bg-[#121212] p-4 rounded-xl border border-white/5 overflow-x-auto max-h-[540px]">
            <code>{selectedFile.code}</code>
          </pre>
        </div>
      </div>

      {/* Security Rules & Firestore Sync Footer Banner */}
      <div className="bg-[#1C1B1B] border border-white/5 rounded-xl p-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-[#00E676]/15 flex items-center justify-center text-[#00E676] shrink-0">
            <ShieldCheck className="w-5 h-5" />
          </div>
          <div>
            <div className="text-sm font-semibold text-white">
              Archivos generados también en el proyecto local (/flutter_wallet_app/lib/...)
            </div>
            <div className="text-xs text-[#A0A0A0]">
              Incluye reglas de seguridad Zero-Trust desplegadas en{' '}
              <span className="font-mono text-[#E5E2E1]">firestore.rules</span>{' '}
              para las 5 subcolecciones de cada usuario.
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
