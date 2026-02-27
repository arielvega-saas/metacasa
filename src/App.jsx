import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import logoMetacasa from './assets/logo-metacasa.jpg';
import {
  Settings, Trash2, X, Plus, Minus, History, TrendingUp, PiggyBank,
  BarChart3, PieChart, ArrowUpRight, ArrowDownLeft, FileSpreadsheet,
  ChevronLeft, ChevronRight, Calendar, LogOut, Home, Check,
  AlertCircle, CheckCircle2, Info, Edit3,
  Search, SlidersHorizontal, ArrowUpDown, XCircle,
  Bell, BellRing, Clock, CheckCheck, RefreshCw, ChevronDown,
  Mic, MicOff, Share2, FileText, Sparkles,
  Target, Trophy, Wallet, Copy, Lightbulb, Calculator, Eye, EyeOff
} from 'lucide-react';
import { supabase } from './supabaseClient';

// ─────────────────────────────────────────────
// CONSTANTES
// ─────────────────────────────────────────────
const INITIAL_CATEGORIES = {
  GASTO: ["Vivienda", "Transporte", "Salud", "Ocio", "Alimentación", "Servicios"],
  INGRESO: ["Sueldo", "Inversiones", "Ventas"]
};
const MONTHS = ["ENERO","FEBRERO","MARZO","ABRIL","MAYO","JUNIO","JULIO","AGOSTO","SEPTIEMBRE","OCTUBRE","NOVIEMBRE","DICIEMBRE"];
const CHART_COLORS = ['#6366f1','#f43f5e','#10b981','#f59e0b','#3b82f6','#8b5cf6','#ec4899','#14b8a6','#f97316','#84cc16'];

// Emojis default por nombre de categoría
const DEFAULT_EMOJIS = {
  Vivienda:'🏠', Transporte:'🚗', Salud:'🏥', Ocio:'🎮', Alimentación:'🍽️', Servicios:'⚡',
  Sueldo:'💼', Inversiones:'📈', Ventas:'🛍️',
};
// Paleta de emojis para el picker
const EMOJI_PALETTE = [
  '🏠','🚗','🏥','🎮','🍽️','⚡','💼','📈','🛍️','🎓','✈️','🏋️',
  '🐶','🐱','🌿','🎵','📱','💊','🛒','🎁','🏦','💳','🍕','☕',
  '🚌','⛽','🎬','📚','👕','🏡','🔧','🧹','🌙','☀️','🍺','🎯',
  '💰','💸','🤝','📊','🔑','🏊','🎨','💡','🧘','🌊','🚀','🍎',
];
// Frecuencias para recurrentes
const FREQUENCIES = [
  { v:'daily',   l:'Diario',   icon:'📅' },
  { v:'weekly',  l:'Semanal',  icon:'📆' },
  { v:'monthly', l:'Mensual',  icon:'🗓️' },
  { v:'yearly',  l:'Anual',    icon:'📌' },
];

// Keywords para auto-sugerencia de categoría desde nota/voz
const CATEGORY_KEYWORDS = {
  'Alimentación': ['supermercado','mercado','verdura','carne','comida','almacén','carnicería','panadería','fiambrería','kiosco','pizza','empanada','sushi','chino','ferretería','lácteo','fruta'],
  'Transporte':   ['nafta','combustible','colectivo','uber','taxi','peaje','garage','estacionamiento','subte','tren','moto','auto','patente','seguro auto','acpm'],
  'Salud':        ['médico','farmacia','remedio','medicamento','clínica','hospital','dentista','obra social','turno','consulta','análisis','enfermedad'],
  'Vivienda':     ['alquiler','expensas','reparación','plomero','electricista','pintura','mueble','hogar','silla','mesa'],
  'Ocio':         ['cine','teatro','restaurante','bar','cerveza','netflix','spotify','disney','juego','entretenimiento','viaje','hotel','vacaciones','delivery','pedidosya','rappi'],
  'Servicios':    ['luz','gas','agua','internet','cable','wifi','celular','teléfono','factura','abono','streaming'],
  'Sueldo':       ['sueldo','salario','pago','jornal','honorario','cobré','cobra'],
  'Inversiones':  ['inversión','plazo fijo','cripto','bitcoin','acciones','dividendo','interés','renta'],
  'Ventas':       ['venta','vendí','cobré','facturé'],
};

// Parser de monto desde texto de voz
const parseVoiceAmount = (text) => {
  const digitMatch = text.match(/\b(\d[\d.,]*)\b/);
  if (digitMatch) return parseInt(digitMatch[1].replace(/[.,]/g,''));
  const words = {
    'cien':100,'ciento':100,'doscientos':200,'trescientos':300,'cuatrocientos':400,'quinientos':500,
    'mil':1000,'dos mil':2000,'tres mil':3000,'cuatro mil':4000,'cinco mil':5000,
    'seis mil':6000,'siete mil':7000,'ocho mil':8000,'nueve mil':9000,'diez mil':10000,
    'quince mil':15000,'veinte mil':20000,'treinta mil':30000,'cincuenta mil':50000,'cien mil':100000,
  };
  const lower = text.toLowerCase();
  for (const [phrase,val] of Object.entries(words)) { if (lower.includes(phrase)) return val; }
  return 0;
};

// Emojis para metas de ahorro
const GOAL_EMOJIS = ['🎯','✈️','🏠','🚗','💻','📱','🎓','💍','🏖️','🎪','🎸','🐕','🌍','🏋️','🎮','👶','🏥','🛋️','🌿','⛵'];

// Haptic feedback (solo en dispositivos que lo soportan)
const haptic = (ms = 10) => { try { navigator.vibrate?.(ms); } catch {} };

// Claves localStorage
const GOALS_KEY     = 'metacasa_goals';
const CUOTAS_KEY    = 'metacasa_cuotas';
const MEMO_KEY      = 'metacasa_memos';
const TEMPLATES_KEY = 'metacasa_templates';

// ─────────────────────────────────────────────
// UTILS
// ─────────────────────────────────────────────
const formatNumber = (num) => {
  if (num === undefined || num === null || isNaN(num)) return "0";
  const absNum = Math.abs(Math.floor(Number(num)));
  const formatted = absNum.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  return Number(num) < 0 ? `-${formatted}` : formatted;
};
const parseFormattedNumber = (val) => {
  if (typeof val === 'number') return val;
  if (typeof val === 'string') return parseFloat(val.replace(/\./g, '')) || 0;
  return 0;
};

// ─────────────────────────────────────────────
// TOAST SYSTEM
// ─────────────────────────────────────────────
const ToastContext = React.createContext(null);

function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([]);
  const addToast = useCallback((msg, type = 'success') => {
    const id = Date.now();
    setToasts(t => [...t, { id, msg, type }]);
    setTimeout(() => setToasts(t => t.filter(x => x.id !== id)), 3200);
  }, []);
  const iconMap = { success: <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />, error: <AlertCircle className="w-5 h-5 text-rose-400 flex-shrink-0" />, info: <Info className="w-5 h-5 text-indigo-400 flex-shrink-0" /> };
  return (
    <ToastContext.Provider value={addToast}>
      {children}
      <div className="fixed top-0 left-0 right-0 z-[999] flex flex-col items-center gap-2 pt-[calc(env(safe-area-inset-top)+12px)] px-4 pointer-events-none">
        {toasts.map(t => (
          <div key={t.id} className="w-full max-w-sm bg-zinc-900 border border-white/10 rounded-2xl px-4 py-3.5 flex items-center gap-3 shadow-2xl animate-slide-down">
            {iconMap[t.type]}
            <span className="text-sm font-semibold text-white leading-tight">{t.msg}</span>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}
const useToast = () => React.useContext(ToastContext);

// ─────────────────────────────────────────────
// SKELETON LOADER
// ─────────────────────────────────────────────
function SkeletonCard({ className = "" }) {
  return <div className={`bg-zinc-900/60 rounded-3xl animate-pulse ${className}`} />;
}
function LoadingSkeleton() {
  return (
    <div className="max-w-md mx-auto px-6 pt-6 space-y-6">
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-3">
          <SkeletonCard className="w-10 h-10 rounded-xl" />
          <div className="space-y-2"><SkeletonCard className="w-24 h-4" /><SkeletonCard className="w-16 h-2.5" /></div>
        </div>
        <div className="flex gap-2"><SkeletonCard className="w-11 h-11 rounded-2xl" /><SkeletonCard className="w-11 h-11 rounded-2xl" /></div>
      </div>
      <SkeletonCard className="h-52 rounded-[2.5rem]" />
      <SkeletonCard className="h-72 rounded-[2.5rem]" />
    </div>
  );
}

// ─────────────────────────────────────────────
// PRECISION SELECTOR (Ahorro/Inversión)
// ─────────────────────────────────────────────
const COLOR_MAP = {
  emerald: { bg: "bg-emerald-500", bgSoft: "bg-emerald-500/10", text: "text-emerald-500" },
  indigo:  { bg: "bg-indigo-500",  bgSoft: "bg-indigo-500/10",  text: "text-indigo-500"  }
};
function PrecisionSelector({ label, value, onChange, color, icon: Icon, subtext }) {
  const c = COLOR_MAP[color] || COLOR_MAP.indigo;
  const upd = (v) => onChange(Math.max(0, Math.min(100, v)));
  return (
    <div className="bg-zinc-900/60 rounded-[2rem] p-6 border border-white/5 space-y-4">
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-3">
          <div className={`p-2 rounded-xl ${c.bgSoft}`}><Icon className={`w-5 h-5 ${c.text}`} /></div>
          <div>
            <p className="text-sm font-bold text-white">{label}</p>
            <p className="text-xs text-zinc-500 mt-0.5">{subtext}</p>
          </div>
        </div>
        <div className={`text-2xl font-black ${c.text} tabular-nums`}>{value}%</div>
      </div>
      <div className="flex items-center gap-4">
        <button onClick={() => upd(value - 1)} className="w-12 h-12 rounded-full bg-zinc-800 flex items-center justify-center active:scale-90 transition-transform"><Minus className="w-5 h-5 text-white" /></button>
        <div className="flex-1 h-3 bg-black rounded-full overflow-hidden border border-white/5">
          <div className={`h-full ${c.bg} transition-all duration-300`} style={{ width: `${value}%` }} />
        </div>
        <button onClick={() => upd(value + 1)} className="w-12 h-12 rounded-full bg-zinc-800 flex items-center justify-center active:scale-90 transition-transform"><Plus className="w-5 h-5 text-white" /></button>
      </div>
      <div className="grid grid-cols-5 gap-2">
        {[0,10,20,30,50].map(pct => (
          <button key={pct} onClick={() => upd(pct)} className={`py-2 rounded-lg text-xs font-bold transition-all ${value===pct ? `${c.bg} text-white` : 'bg-zinc-800/50 text-zinc-500'}`}>{pct}%</button>
        ))}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// MONTO RESPONSIVE
// ─────────────────────────────────────────────
function SharedSizeText({ value, prefix = "$", fontSizeClass, className = "" }) {
  return (
    <div className="w-full overflow-hidden flex items-center h-16">
      <h2 className={`${fontSizeClass} font-black tracking-tighter whitespace-nowrap leading-none ${className}`}>
        {prefix}{formatNumber(value)}
      </h2>
    </div>
  );
}

// ─────────────────────────────────────────────
// DONUT CHART (SVG puro)
// ─────────────────────────────────────────────
function DonutChart({ data, total }) {
  const R = 80, r = 52, cx = 100, cy = 100;
  let angle = -Math.PI / 2;
  const slices = data.map(d => {
    const frac = d.spent / (total || 1);
    const a1 = angle, a2 = angle + frac * 2 * Math.PI;
    angle = a2;
    const x1o = cx + R*Math.cos(a1), y1o = cy + R*Math.sin(a1);
    const x2o = cx + R*Math.cos(a2), y2o = cy + R*Math.sin(a2);
    const x1i = cx + r*Math.cos(a2), y1i = cy + r*Math.sin(a2);
    const x2i = cx + r*Math.cos(a1), y2i = cy + r*Math.sin(a1);
    const large = frac > 0.5 ? 1 : 0;
    return { ...d, frac, path: `M${x1o},${y1o} A${R},${R} 0 ${large},1 ${x2o},${y2o} L${x1i},${y1i} A${r},${r} 0 ${large},0 ${x2i},${y2i} Z` };
  });
  return { slices };
}

// ─────────────────────────────────────────────
// BILL CARD
// ─────────────────────────────────────────────
function BillCard({ bill, onPay, onEdit, onDelete, label }) {
  const isPaid = bill.status === 'paid';
  return (
    <div className={`rounded-2xl border p-4 flex items-center gap-3 transition-all ${isPaid ? 'bg-zinc-900/30 border-white/5 opacity-60' : 'bg-zinc-900/60 border-white/8'}`}>
      <button onClick={() => onPay(bill)}
        className={`w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 transition-all active:scale-90
          ${isPaid ? 'bg-emerald-500/20 text-emerald-400' : 'bg-zinc-800 text-zinc-600 border border-white/10'}`}>
        {isPaid ? <CheckCheck className="w-5 h-5"/> : <Check className="w-5 h-5"/>}
      </button>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <p className={`text-sm font-bold truncate ${isPaid ? 'text-zinc-500 line-through' : 'text-white'}`}>{bill.title}</p>
          {bill.recurrence_type && <RefreshCw className="w-3 h-3 text-zinc-600 flex-shrink-0"/>}
        </div>
        <div className="flex items-center gap-2 mt-0.5">
          <span className={`text-xs font-semibold ${label.color}`}>{label.label}</span>
          {bill.category && <span className="text-xs text-zinc-600">· {bill.category}</span>}
        </div>
      </div>
      <div className="flex items-center gap-3 flex-shrink-0">
        <p className={`text-base font-black ${isPaid ? 'text-zinc-600' : 'text-white'}`}>${formatNumber(bill.amount)}</p>
        <div className="flex flex-col gap-0.5">
          <button onClick={onEdit} className="p-1 text-zinc-700 active:text-indigo-400 transition-colors"><Edit3 className="w-3.5 h-3.5"/></button>
          <button onClick={() => onDelete(bill.id)} className="p-1 text-zinc-700 active:text-rose-500 transition-colors"><Trash2 className="w-3.5 h-3.5"/></button>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// BILL FORM (nuevo / editar)
// ─────────────────────────────────────────────
function BillForm({ bill, categories, onSave, onClose }) {
  const [title,     setTitle]     = useState(bill?.title || '');
  const [amount,    setAmount]    = useState(bill ? String(bill.amount) : '');
  const [dueDate,   setDueDate]   = useState(bill?.due_date || new Date().toISOString().slice(0,10));
  const [category,  setCategory]  = useState(bill?.category || categories[0] || '');
  const [recur,     setRecur]     = useState(bill?.recurrence_type || '');
  const [remDays,   setRemDays]   = useState(bill?.reminder_days ?? 3);
  const [saving,    setSaving]    = useState(false);

  const handleSave = async () => {
    if (!title.trim() || !amount) return;
    setSaving(true);
    await onSave({
      id: bill?.id,
      title: title.trim(),
      amount: parseFloat(amount.replace(/\./g,'')) || 0,
      due_date: dueDate,
      category,
      status: bill?.status || 'pending',
      recurrence_type: recur || null,
      reminder_days: Number(remDays),
    });
    setSaving(false);
  };

  return (
    <div className="fixed inset-0 z-[300] bg-black/90 backdrop-blur-xl flex items-end justify-center">
      <div className="w-full max-w-md bg-zinc-950 rounded-t-[2.5rem] border-t border-white/10 p-7 space-y-5 pb-[calc(2rem+env(safe-area-inset-bottom))]">
        <div className="flex justify-between items-center">
          <h3 className="text-lg font-black uppercase tracking-tight">{bill ? 'Editar' : 'Nuevo'} vencimiento</h3>
          <button onClick={onClose} className="p-2 bg-zinc-900 rounded-full"><X className="w-5 h-5"/></button>
        </div>

        <input value={title} onChange={e=>setTitle(e.target.value)} placeholder="Descripción (ej: Alquiler, Internet…)"
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-indigo-500/60"/>

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Monto</p>
            <input value={amount} onChange={e=>setAmount(e.target.value.replace(/\D/g,''))}
              placeholder="$ 0" inputMode="numeric"
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-indigo-500/60"/>
          </div>
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Vence el</p>
            <input type="date" value={dueDate} onChange={e=>setDueDate(e.target.value)}
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-indigo-500/60"/>
          </div>
        </div>

        <div className="space-y-1">
          <p className="text-xs text-zinc-600 ml-1">Categoría</p>
          <select value={category} onChange={e=>setCategory(e.target.value)}
            className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white appearance-none focus:outline-none">
            {categories.map(c=><option key={c} value={c}>{c}</option>)}
          </select>
        </div>

        <div className="space-y-1">
          <p className="text-xs text-zinc-600 ml-1">Recurrencia</p>
          <div className="flex gap-2">
            {[{v:'',l:'Única'},{v:'monthly',l:'Mensual'},{v:'yearly',l:'Anual'}].map(opt=>(
              <button key={opt.v} onClick={()=>setRecur(opt.v)}
                className={`flex-1 py-3 rounded-xl text-xs font-bold transition-all
                  ${recur===opt.v?'bg-indigo-600 text-white':'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
                {opt.l}
              </button>
            ))}
          </div>
        </div>

        <div className="space-y-1">
          <p className="text-xs text-zinc-600 ml-1">Recordarme con anticipación</p>
          <div className="flex gap-2">
            {[{v:1,l:'1 día'},{v:3,l:'3 días'},{v:7,l:'7 días'}].map(opt=>(
              <button key={opt.v} onClick={()=>setRemDays(opt.v)}
                className={`flex-1 py-3 rounded-xl text-xs font-bold transition-all
                  ${remDays===opt.v?'bg-zinc-100 text-black':'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
                {opt.l}
              </button>
            ))}
          </div>
        </div>

        <button onClick={handleSave} disabled={saving||!title.trim()||!amount}
          className="w-full py-5 bg-indigo-600 rounded-2xl font-bold text-sm uppercase tracking-wider active:scale-95 transition-all disabled:opacity-40">
          {saving ? 'Guardando…' : bill ? 'Guardar cambios' : 'Agregar vencimiento'}
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// EDIT TRANSACTION MODAL
// ─────────────────────────────────────────────
function EditTransactionModal({ tx, categories, onSave, onClose, onDuplicate }) {
  const [amount, setAmount]   = useState(String(tx.amount));
  const [categ,  setCateg]    = useState(tx.category);
  const [note,   setNote]     = useState(tx.note || "");
  const [date,   setDate]     = useState(tx.date?.slice(0,10) || new Date().toISOString().slice(0,10));
  const [saving, setSaving]   = useState(false);
  const toast = useToast();

  const handleSave = async () => {
    setSaving(true);
    const { error } = await supabase.from('transactions').update({
      amount: parseFormattedNumber(amount),
      category: categ,
      note: note.trim(),
      date: new Date(date).toISOString()
    }).eq('id', tx.id);
    setSaving(false);
    if (error) { toast(error.message, 'error'); return; }
    toast('Movimiento actualizado', 'success');
    onSave();
    onClose();
  };

  const allCats = [...(categories.GASTO || []), ...(categories.INGRESO || [])];

  return (
    <div className="fixed inset-0 z-[300] bg-black/90 backdrop-blur-xl flex items-end justify-center">
      <div className="w-full max-w-md bg-zinc-950 rounded-t-[2.5rem] border-t border-white/10 p-8 space-y-5 pb-[calc(2rem+env(safe-area-inset-bottom))]">
        <div className="flex justify-between items-center">
          <h3 className="text-lg font-black uppercase tracking-tight">Editar movimiento</h3>
          <button onClick={onClose} className="p-2 bg-zinc-900 rounded-full"><X className="w-5 h-5" /></button>
        </div>
        <input type="text" value={amount} onChange={e => setAmount(e.target.value.replace(/\D/g,''))}
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-2xl font-black text-center focus:outline-none focus:border-indigo-500/60"
          inputMode="numeric" placeholder="$ 0" />
        <select value={categ} onChange={e => setCateg(e.target.value)}
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 font-bold text-sm text-white appearance-none focus:outline-none">
          {allCats.map(c => <option key={c} value={c}>{c}</option>)}
        </select>
        <input type="date" value={date} onChange={e => setDate(e.target.value)}
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 font-bold text-sm text-white focus:outline-none focus:border-indigo-500/60" />
        <textarea value={note} onChange={e => setNote(e.target.value)} placeholder="Detalle..."
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-zinc-400 resize-none min-h-[80px] focus:outline-none focus:border-indigo-500/60" />
        <div className="grid grid-cols-2 gap-3">
          <button onClick={() => onDuplicate && onDuplicate(tx)}
            className="py-4 bg-zinc-900 border border-white/10 rounded-2xl font-bold text-sm text-zinc-400 active:scale-95 transition-all flex items-center justify-center gap-2">
            <Copy className="w-4 h-4"/>Clonar
          </button>
          <button onClick={handleSave} disabled={saving}
            className="py-4 bg-indigo-600 rounded-2xl font-black text-sm uppercase tracking-widest active:scale-95 transition-all disabled:opacity-50">
            {saving ? '…' : 'Guardar'}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
// PLAN EDITOR (inline, no modal)
// ─────────────────────────────────────────────
function PlanEditor({ planMes, onSave, onCancel }) {
  const [inc, setInc] = React.useState(planMes.targetIncome > 0 ? String(planMes.targetIncome) : '');
  const [exp, setExp] = React.useState(planMes.targetExpense > 0 ? String(planMes.targetExpense) : '');
  return (
    <div className="space-y-3">
      <div className="grid grid-cols-2 gap-2">
        <div>
          <p className="text-[10px] text-zinc-600 font-semibold mb-1">Meta de ingreso</p>
          <input type="number" inputMode="numeric" value={inc} onChange={e=>setInc(e.target.value)}
            placeholder="$0"
            className="w-full bg-zinc-900/60 border border-emerald-500/20 rounded-xl px-3 py-2 text-sm font-bold text-emerald-300 focus:outline-none focus:border-emerald-500/40"/>
        </div>
        <div>
          <p className="text-[10px] text-zinc-600 font-semibold mb-1">Límite de gasto</p>
          <input type="number" inputMode="numeric" value={exp} onChange={e=>setExp(e.target.value)}
            placeholder="$0"
            className="w-full bg-zinc-900/60 border border-rose-500/20 rounded-xl px-3 py-2 text-sm font-bold text-rose-300 focus:outline-none focus:border-rose-500/40"/>
        </div>
      </div>
      <div className="flex gap-2">
        <button onClick={() => onSave({ targetIncome: parseInt(inc)||0, targetExpense: parseInt(exp)||0 })}
          className="flex-1 py-2.5 bg-indigo-600 rounded-xl text-xs font-bold active:scale-95 transition-transform">
          Guardar plan
        </button>
        <button onClick={onCancel} className="px-4 py-2.5 bg-zinc-900 rounded-xl text-xs font-bold text-zinc-500 active:scale-95 transition-transform">
          Cancelar
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// GOAL CARD
// ─────────────────────────────────────────────
function GoalCard({ goal, onContribute, onDelete, estimate }) {
  const pct = goal.target > 0 ? Math.min(100, Math.round((goal.current/goal.target)*100)) : 0;
  const daysLeft = goal.deadline
    ? Math.ceil((new Date(goal.deadline) - new Date()) / 86400000)
    : null;
  const done = pct >= 100;
  // ── Estimador ──
  const estimatorMonths = (!done && estimate > 0)
    ? Math.ceil((goal.target - goal.current) / estimate)
    : null;
  const estimatorDate = estimatorMonths ? (() => {
    const d = new Date(); d.setMonth(d.getMonth() + estimatorMonths);
    return d.toLocaleDateString('es-AR', { month: 'short', year: 'numeric' });
  })() : null;
  return (
    <div className={`rounded-2xl p-5 border space-y-3.5 ${done ? 'bg-emerald-500/8 border-emerald-500/20' : 'bg-zinc-900/60 border-white/8'}`}>
      <div className="flex justify-between items-start">
        <div className="flex items-center gap-3 min-w-0">
          <span className="text-2xl flex-shrink-0">{goal.emoji}</span>
          <div className="min-w-0">
            <p className="text-sm font-bold text-white truncate">{goal.name}</p>
            {daysLeft !== null && (
              <p className={`text-xs font-semibold mt-0.5 ${daysLeft < 0 ? 'text-rose-400' : daysLeft < 30 ? 'text-amber-400' : 'text-zinc-600'}`}>
                {daysLeft < 0 ? 'Fecha vencida' : daysLeft === 0 ? 'Vence hoy' : `${daysLeft}d restantes`}
              </p>
            )}
          </div>
        </div>
        <div className="text-right flex-shrink-0 ml-2">
          <p className="text-xs text-zinc-600">Meta</p>
          <p className="text-sm font-black">${formatNumber(goal.target)}</p>
        </div>
      </div>

      <div className="space-y-1.5">
        <div className="flex justify-between text-xs">
          <span className="text-zinc-400 font-semibold">${formatNumber(goal.current)} guardado</span>
          <span className={`font-black ${done ? 'text-emerald-400' : 'text-indigo-400'}`}>{pct}%</span>
        </div>
        <div className="h-3 bg-black/60 rounded-full overflow-hidden">
          <div className={`h-full rounded-full transition-all duration-700 ${done ? 'bg-emerald-500' : 'bg-indigo-600'}`}
            style={{width:`${pct}%`}}/>
        </div>
        <p className="text-xs text-zinc-700">
          {done ? '🎉 ¡Meta alcanzada!' : `Falta $${formatNumber(goal.target - goal.current)}`}
        </p>
        {estimatorMonths && (
          <div className="flex items-center gap-1.5 bg-indigo-600/10 border border-indigo-500/20 rounded-xl px-3 py-2 mt-1">
            <TrendingUp className="w-3 h-3 text-indigo-400 flex-shrink-0"/>
            <p className="text-[10px] font-bold text-indigo-300">
              A este ritmo llegás en{' '}
              <span className="text-white">{estimatorMonths === 1 ? '1 mes' : `${estimatorMonths} meses`}</span>
              {' '}·{' '}<span className="text-indigo-400">{estimatorDate}</span>
            </p>
          </div>
        )}
      </div>

      <div className="flex gap-2">
        {!done && (
          <button onClick={()=>onContribute(goal)}
            className="flex-1 py-3 bg-indigo-600/15 border border-indigo-500/25 rounded-xl text-xs font-bold text-indigo-400 active:scale-95 transition-all flex items-center justify-center gap-1.5">
            <Plus className="w-3.5 h-3.5"/> Sumar aporte
          </button>
        )}
        {done && (
          <div className="flex-1 py-3 bg-emerald-500/10 rounded-xl text-xs font-bold text-emerald-400 flex items-center justify-center gap-1.5">
            <Trophy className="w-3.5 h-3.5"/> ¡Completada!
          </div>
        )}
        <button onClick={()=>onDelete(goal.id)}
          className="p-3 bg-zinc-900 rounded-xl border border-white/8 active:scale-90 transition-all">
          <Trash2 className="w-3.5 h-3.5 text-zinc-600"/>
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// GOAL FORM
// ─────────────────────────────────────────────
function GoalForm({ goal, onSave, onClose }) {
  const [name,     setName]     = useState(goal?.name || '');
  const [target,   setTarget]   = useState(goal ? String(goal.target) : '');
  const [current,  setCurrent]  = useState(goal ? String(goal.current) : '0');
  const [emoji,    setEmoji]    = useState(goal?.emoji || '🎯');
  const [deadline, setDeadline] = useState(goal?.deadline || '');
  const [showPick, setShowPick] = useState(false);

  const handleSave = () => {
    if (!name.trim() || !target) return;
    onSave({
      id: goal?.id || Date.now(),
      name: name.trim(), emoji,
      target: parseInt(target.replace(/\D/g,'')) || 0,
      current: parseInt(current.replace(/\D/g,'')) || 0,
      deadline: deadline || null,
      createdAt: goal?.createdAt || new Date().toISOString().slice(0,10),
    });
  };

  return (
    <div className="fixed inset-0 z-[400] bg-black/90 backdrop-blur-xl flex items-end justify-center">
      <div className="w-full max-w-md bg-zinc-950 rounded-t-[2.5rem] border-t border-white/10 p-7 space-y-5 pb-[calc(2rem+env(safe-area-inset-bottom))]">
        <div className="flex justify-between items-center">
          <h3 className="text-lg font-black uppercase tracking-tight">{goal ? 'Editar' : 'Nueva'} meta</h3>
          <button onClick={onClose} className="p-2 bg-zinc-900 rounded-full"><X className="w-5 h-5"/></button>
        </div>

        {/* Emoji selector */}
        <div className="flex items-center gap-3">
          <button onClick={()=>setShowPick(v=>!v)}
            className="w-14 h-14 rounded-2xl bg-zinc-900 border border-white/10 flex items-center justify-center text-3xl active:scale-90 transition-transform">
            {emoji}
          </button>
          <input value={name} onChange={e=>setName(e.target.value)} placeholder="Nombre de la meta…"
            className="flex-1 bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-indigo-500/60"/>
        </div>
        {showPick && (
          <div className="bg-zinc-900/90 rounded-2xl p-3 border border-white/10">
            <div className="grid grid-cols-10 gap-1">
              {GOAL_EMOJIS.map(e=>(
                <button key={e} onClick={()=>{ setEmoji(e); setShowPick(false); }}
                  className={`w-8 h-8 flex items-center justify-center text-xl rounded-lg active:bg-white/10 transition-colors ${emoji===e?'bg-indigo-600':''}`}>
                  {e}
                </button>
              ))}
            </div>
          </div>
        )}

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Meta ($)</p>
            <input value={target} onChange={e=>setTarget(e.target.value.replace(/\D/g,''))}
              placeholder="0" inputMode="numeric"
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm font-bold text-white focus:outline-none focus:border-indigo-500/60"/>
          </div>
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Ya tengo ($)</p>
            <input value={current} onChange={e=>setCurrent(e.target.value.replace(/\D/g,''))}
              placeholder="0" inputMode="numeric"
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm font-bold text-white focus:outline-none focus:border-indigo-500/60"/>
          </div>
        </div>

        <div className="space-y-1">
          <p className="text-xs text-zinc-600 ml-1">Fecha límite (opcional)</p>
          <input type="date" value={deadline} onChange={e=>setDeadline(e.target.value)}
            className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-indigo-500/60"/>
        </div>

        <button onClick={handleSave} disabled={!name.trim()||!target}
          className="w-full py-5 bg-indigo-600 rounded-2xl font-bold text-sm uppercase tracking-wider active:scale-95 transition-all disabled:opacity-40">
          {goal ? 'Guardar cambios' : 'Crear meta'}
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// CONTRIBUTE SHEET
// ─────────────────────────────────────────────
function ContributeSheet({ goal, onSave, onClose }) {
  const [amount, setAmount] = useState('');
  return (
    <div className="fixed inset-0 z-[400] bg-black/90 backdrop-blur-xl flex items-end justify-center">
      <div className="w-full max-w-md bg-zinc-950 rounded-t-[2.5rem] border-t border-white/10 p-7 space-y-5 pb-[calc(2rem+env(safe-area-inset-bottom))]">
        <div className="flex justify-between items-center">
          <div className="flex items-center gap-2">
            <span className="text-2xl">{goal.emoji}</span>
            <h3 className="text-lg font-black uppercase tracking-tight">{goal.name}</h3>
          </div>
          <button onClick={onClose} className="p-2 bg-zinc-900 rounded-full"><X className="w-5 h-5"/></button>
        </div>
        <p className="text-sm text-zinc-500">Progreso actual: <strong className="text-white">${formatNumber(goal.current)}</strong> / ${formatNumber(goal.target)}</p>
        <input value={amount} onChange={e=>setAmount(e.target.value.replace(/\D/g,''))}
          placeholder="$ Monto a sumar" inputMode="numeric"
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-2xl font-black text-center focus:outline-none focus:border-indigo-500/60"/>
        <div className="grid grid-cols-4 gap-2">
          {[1000,5000,10000,50000].map(v=>(
            <button key={v} onClick={()=>setAmount(String(amount ? parseInt(amount)+v : v))}
              className="py-2.5 bg-zinc-900 rounded-xl text-xs font-bold text-zinc-400 border border-white/8 active:scale-90 transition-all">
              +{formatNumber(v)}
            </button>
          ))}
        </div>
        <button onClick={()=>{ if(amount) onSave(parseInt(amount)); }}
          disabled={!amount}
          className="w-full py-5 bg-emerald-600 rounded-2xl font-bold text-sm uppercase tracking-wider active:scale-95 transition-all disabled:opacity-40">
          Sumar ${formatNumber(parseInt(amount||0))} a la meta
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// CUOTA CARD
// ─────────────────────────────────────────────
function CuotaCard({ cuota, onEdit, onDelete, onPay }) {
  const remaining = cuota.totalCuotas - cuota.paidCuotas;
  const pct = Math.round((cuota.paidCuotas / cuota.totalCuotas) * 100);
  const done = remaining <= 0;
  const totalLeft = remaining * cuota.monthlyAmount;

  return (
    <div className={`rounded-2xl border p-4 space-y-3 transition-all ${done ? 'bg-zinc-900/30 border-white/5 opacity-60' : 'bg-zinc-900/60 border-white/8'}`}>
      <div className="flex justify-between items-start">
        <div className="flex items-center gap-3 min-w-0">
          <span className="text-2xl flex-shrink-0">{cuota.emoji}</span>
          <div className="min-w-0">
            <p className="text-sm font-bold text-white truncate">{cuota.name}</p>
            <p className="text-xs text-zinc-500 mt-0.5">
              {cuota.paidCuotas}/{cuota.totalCuotas} cuotas · ${formatNumber(cuota.monthlyAmount)}/mes
            </p>
          </div>
        </div>
        <div className="text-right flex-shrink-0 ml-2">
          <p className="text-xs text-zinc-600">Resta</p>
          <p className={`text-sm font-black ${done ? 'text-emerald-400' : 'text-white'}`}>
            {done ? '¡Listo!' : `$${formatNumber(totalLeft)}`}
          </p>
        </div>
      </div>

      <div className="space-y-1">
        <div className="h-2 bg-black/60 rounded-full overflow-hidden">
          <div className={`h-full rounded-full transition-all duration-700 ${done ? 'bg-emerald-500' : pct >= 80 ? 'bg-amber-500' : 'bg-indigo-600'}`}
            style={{width:`${pct}%`}}/>
        </div>
        <div className="flex justify-between text-[10px] text-zinc-600 font-semibold">
          <span>{pct}% pagado</span>
          <span>{remaining} cuota{remaining!==1?'s':''} restante{remaining!==1?'s':''}</span>
        </div>
      </div>

      <div className="flex gap-2">
        {!done && (
          <button onClick={()=>onPay(cuota.id)}
            className="flex-1 py-2.5 bg-indigo-600/15 border border-indigo-500/25 rounded-xl text-xs font-bold text-indigo-400 active:scale-95 transition-all flex items-center justify-center gap-1.5">
            <Check className="w-3.5 h-3.5"/> Pagar cuota
          </button>
        )}
        <button onClick={()=>onEdit(cuota)} className="p-2.5 bg-zinc-900 rounded-xl border border-white/8 active:scale-90 transition-all">
          <Edit3 className="w-3.5 h-3.5 text-zinc-600"/>
        </button>
        <button onClick={()=>onDelete(cuota.id)} className="p-2.5 bg-zinc-900 rounded-xl border border-white/8 active:scale-90 transition-all">
          <Trash2 className="w-3.5 h-3.5 text-zinc-600"/>
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// CUOTA FORM
// ─────────────────────────────────────────────
function CuotaForm({ cuota, onSave, onClose }) {
  const [name,        setName]        = useState(cuota?.name || '');
  const [emoji,       setEmoji]       = useState(cuota?.emoji || '💳');
  const [monthly,     setMonthly]     = useState(cuota ? String(cuota.monthlyAmount) : '');
  const [totalCuotas, setTotalCuotas] = useState(cuota ? String(cuota.totalCuotas) : '12');
  const [paidCuotas,  setPaidCuotas]  = useState(cuota ? String(cuota.paidCuotas) : '0');
  const [startDate,   setStartDate]   = useState(cuota?.startDate || new Date().toISOString().slice(0,10));
  const [showPick,    setShowPick]    = useState(false);

  const total = (parseInt(monthly||0) * parseInt(totalCuotas||0));

  const handleSave = () => {
    if (!name.trim() || !monthly || !totalCuotas) return;
    onSave({
      id: cuota?.id || Date.now(),
      name: name.trim(), emoji,
      monthlyAmount: parseInt(monthly.replace(/\D/g,'')) || 0,
      totalCuotas:   parseInt(totalCuotas) || 1,
      paidCuotas:    Math.min(parseInt(paidCuotas)||0, parseInt(totalCuotas)||1),
      startDate,
    });
  };

  const CUOTA_EMOJIS = ['💳','📱','💻','🛋️','🚗','📺','🎸','🧳','👕','🏋️','🎮','🛒','✈️','🏠','💊','🎓','🐕','⌚','📷','🍳'];

  return (
    <div className="fixed inset-0 z-[400] bg-black/90 backdrop-blur-xl flex items-end justify-center">
      <div className="w-full max-w-md bg-zinc-950 rounded-t-[2.5rem] border-t border-white/10 p-7 space-y-5 pb-[calc(2rem+env(safe-area-inset-bottom))] max-h-[92dvh] overflow-y-auto no-scrollbar">
        <div className="flex justify-between items-center">
          <h3 className="text-lg font-black uppercase tracking-tight">{cuota ? 'Editar' : 'Nueva'} cuota</h3>
          <button onClick={onClose} className="p-2 bg-zinc-900 rounded-full"><X className="w-5 h-5"/></button>
        </div>

        <div className="flex items-center gap-3">
          <button onClick={()=>setShowPick(v=>!v)}
            className="w-14 h-14 rounded-2xl bg-zinc-900 border border-white/10 flex items-center justify-center text-3xl active:scale-90 transition-transform">
            {emoji}
          </button>
          <input value={name} onChange={e=>setName(e.target.value)} placeholder="Nombre (ej: TV, Celular…)"
            className="flex-1 bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-indigo-500/60"/>
        </div>
        {showPick && (
          <div className="bg-zinc-900/90 rounded-2xl p-3 border border-white/10">
            <div className="grid grid-cols-10 gap-1">
              {CUOTA_EMOJIS.map(e=>(
                <button key={e} onClick={()=>{ setEmoji(e); setShowPick(false); }}
                  className={`w-8 h-8 flex items-center justify-center text-xl rounded-lg active:bg-white/10 ${emoji===e?'bg-indigo-600':''}`}>
                  {e}
                </button>
              ))}
            </div>
          </div>
        )}

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Valor por cuota ($)</p>
            <input value={monthly} onChange={e=>setMonthly(e.target.value.replace(/\D/g,''))}
              placeholder="0" inputMode="numeric"
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm font-bold text-white focus:outline-none focus:border-indigo-500/60"/>
          </div>
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Total cuotas</p>
            <div className="flex gap-2">
              {['3','6','12','18','24'].map(n=>(
                <button key={n} onClick={()=>setTotalCuotas(n)}
                  className={`flex-1 py-2 rounded-xl text-xs font-black transition-all ${totalCuotas===n?'bg-indigo-600 text-white':'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
                  {n}
                </button>
              ))}
            </div>
          </div>
        </div>

        {total > 0 && (
          <div className="bg-zinc-900/50 rounded-xl p-3 flex justify-between items-center text-sm">
            <span className="text-zinc-500">Total financiado</span>
            <span className="font-black text-white">${formatNumber(total)}</span>
          </div>
        )}

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Ya pagué</p>
            <input value={paidCuotas} onChange={e=>setPaidCuotas(e.target.value.replace(/\D/g,''))}
              placeholder="0" inputMode="numeric"
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm font-bold text-white focus:outline-none focus:border-indigo-500/60"/>
          </div>
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Inicio</p>
            <input type="date" value={startDate} onChange={e=>setStartDate(e.target.value)}
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-indigo-500/60"/>
          </div>
        </div>

        <button onClick={handleSave} disabled={!name.trim()||!monthly||!totalCuotas}
          className="w-full py-5 bg-indigo-600 rounded-2xl font-bold text-sm uppercase tracking-wider active:scale-95 transition-all disabled:opacity-40">
          {cuota ? 'Guardar cambios' : 'Agregar cuota'}
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// DEBT CARD
// ─────────────────────────────────────────────
function DebtCard({ debt, onSettle, onEdit, onDelete }) {
  const isMine = debt.direction === 'i_owe';
  const settled = debt.settled;
  const [showCalc, setShowCalc] = React.useState(false);
  const [monthlyPay, setMonthlyPay] = React.useState('');

  const calcMonths = (() => {
    const pay = parseInt(monthlyPay.replace(/\D/g,'')) || 0;
    if (pay <= 0 || debt.amount <= 0) return null;
    const months = Math.ceil(debt.amount / pay);
    const d = new Date(); d.setMonth(d.getMonth() + months);
    const dateStr = d.toLocaleDateString('es-AR', { month: 'short', year: 'numeric' });
    return { months, dateStr };
  })();

  return (
    <div className={`rounded-2xl border transition-all
      ${settled ? 'bg-zinc-900/30 border-white/5 opacity-55'
        : isMine ? 'bg-rose-500/5 border-rose-500/15'
        : 'bg-emerald-500/5 border-emerald-500/15'}`}>
      <div className="p-4 flex items-center gap-3">
        <div className={`w-11 h-11 rounded-xl flex items-center justify-center text-xl flex-shrink-0
          ${settled ? 'bg-zinc-800' : isMine ? 'bg-rose-500/15' : 'bg-emerald-500/15'}`}>
          {debt.emoji || (isMine ? '💸' : '🤝')}
        </div>
        <div className="flex-1 min-w-0">
          <p className={`text-sm font-bold truncate ${settled ? 'text-zinc-500 line-through' : 'text-white'}`}>{debt.name}</p>
          <p className={`text-xs font-semibold mt-0.5 ${settled ? 'text-zinc-600' : isMine ? 'text-rose-400' : 'text-emerald-400'}`}>
            {settled ? 'Saldada' : isMine ? 'Le debo' : 'Me debe'}
          </p>
          {debt.note ? <p className="text-xs text-zinc-600 italic truncate mt-0.5">"{debt.note}"</p> : null}
        </div>
        <div className="flex items-center gap-2 flex-shrink-0">
          <p className={`text-base font-black ${settled ? 'text-zinc-600' : isMine ? 'text-rose-400' : 'text-emerald-400'}`}>
            ${formatNumber(debt.amount)}
          </p>
          <div className="flex flex-col gap-0.5">
            {!settled && (
              <button onClick={()=>onSettle(debt.id)} className="p-1 text-zinc-600 active:text-emerald-400 transition-colors" title="Marcar saldada">
                <Check className="w-3.5 h-3.5"/>
              </button>
            )}
            {isMine && !settled && (
              <button onClick={()=>setShowCalc(v=>!v)} className={`p-1 transition-colors ${showCalc ? 'text-amber-400' : 'text-zinc-700 active:text-amber-400'}`} title="Calculadora de pago">
                <Calculator className="w-3.5 h-3.5"/>
              </button>
            )}
            <button onClick={()=>onEdit(debt)} className="p-1 text-zinc-700 active:text-indigo-400 transition-colors">
              <Edit3 className="w-3.5 h-3.5"/>
            </button>
            <button onClick={()=>onDelete(debt.id)} className="p-1 text-zinc-700 active:text-rose-500 transition-colors">
              <Trash2 className="w-3.5 h-3.5"/>
            </button>
          </div>
        </div>
      </div>
      {/* ── Calculadora de pago ── */}
      {showCalc && (
        <div className="px-4 pb-4 pt-0">
          <div className="bg-black/30 rounded-xl p-3 space-y-2.5 border border-amber-500/15">
            <p className="text-[10px] font-bold text-amber-400/80 uppercase tracking-wider">Calculadora de pago</p>
            <div className="flex items-center gap-2">
              <span className="text-xs text-zinc-500 font-semibold flex-shrink-0">Cuota mensual $</span>
              <input
                type="number" inputMode="numeric"
                value={monthlyPay}
                onChange={e=>setMonthlyPay(e.target.value)}
                placeholder="0"
                className="flex-1 bg-zinc-900 border border-white/10 rounded-lg px-3 py-1.5 text-sm font-bold text-white text-right focus:outline-none focus:border-amber-500/50"
              />
            </div>
            {calcMonths ? (
              <div className="flex items-center gap-1.5 bg-amber-500/8 rounded-lg px-3 py-2">
                <span className="text-sm">📅</span>
                <p className="text-xs font-bold text-amber-300">
                  Terminás en <span className="text-white">{calcMonths.months === 1 ? '1 mes' : `${calcMonths.months} meses`}</span>
                  {' '}·{' '}<span className="text-amber-400">{calcMonths.dateStr}</span>
                </p>
              </div>
            ) : (
              <p className="text-[10px] text-zinc-700 text-center">Ingresá una cuota para ver el estimado</p>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────
// DEBT FORM
// ─────────────────────────────────────────────
function DebtForm({ debt, onSave, onClose }) {
  const [name,      setName]      = useState(debt?.name || '');
  const [amount,    setAmount]    = useState(debt ? String(debt.amount) : '');
  const [direction, setDirection] = useState(debt?.direction || 'owed_to_me');
  const [note,      setNote]      = useState(debt?.note || '');
  const [date,      setDate]      = useState(debt?.date || new Date().toISOString().slice(0,10));
  const [emoji,     setEmoji]     = useState(debt?.emoji || '');

  const DEBT_EMOJIS = ['🤝','💸','💰','🎁','🍕','🍺','✈️','🏠','📱','🎮','👕','🚗','💊','🎓','🎵'];

  const handleSave = () => {
    if (!name.trim() || !amount) return;
    onSave({
      id: debt?.id || Date.now(),
      name: name.trim(),
      amount: parseInt(amount.replace(/\D/g,'')) || 0,
      direction, note: note.trim(), date,
      emoji: emoji || (direction==='i_owe' ? '💸' : '🤝'),
      settled: debt?.settled || false,
    });
  };

  return (
    <div className="fixed inset-0 z-[400] bg-black/90 backdrop-blur-xl flex items-end justify-center">
      <div className="w-full max-w-md bg-zinc-950 rounded-t-[2.5rem] border-t border-white/10 p-7 space-y-5 pb-[calc(2rem+env(safe-area-inset-bottom))]">
        <div className="flex justify-between items-center">
          <h3 className="text-lg font-black uppercase tracking-tight">{debt ? 'Editar' : 'Nueva'} deuda</h3>
          <button onClick={onClose} className="p-2 bg-zinc-900 rounded-full"><X className="w-5 h-5"/></button>
        </div>

        {/* Dirección */}
        <div className="flex bg-black rounded-2xl p-1.5 border border-white/10">
          {[
            { v:'owed_to_me', l:'Me deben', color:'bg-emerald-600' },
            { v:'i_owe',      l:'Debo yo',  color:'bg-rose-600'    },
          ].map(opt=>(
            <button key={opt.v} onClick={()=>setDirection(opt.v)}
              className={`flex-1 py-2.5 text-sm font-bold rounded-xl transition-all
                ${direction===opt.v ? opt.color+' text-white' : 'text-zinc-500'}`}>
              {opt.l}
            </button>
          ))}
        </div>

        {/* Nombre + Emoji */}
        <div className="flex gap-3">
          <select value={emoji} onChange={e=>setEmoji(e.target.value)}
            className="w-14 h-14 bg-zinc-900 rounded-2xl border border-white/10 text-2xl text-center appearance-none focus:outline-none">
            <option value="">🤝</option>
            {DEBT_EMOJIS.map(e=><option key={e} value={e}>{e}</option>)}
          </select>
          <input value={name} onChange={e=>setName(e.target.value)} placeholder="Nombre de la persona…"
            className="flex-1 bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-indigo-500/60"/>
        </div>

        {/* Monto */}
        <input value={amount} onChange={e=>setAmount(e.target.value.replace(/\D/g,''))}
          placeholder="$ Monto" inputMode="numeric"
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-2xl font-black text-center focus:outline-none focus:border-indigo-500/60"/>

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Fecha</p>
            <input type="date" value={date} onChange={e=>setDate(e.target.value)}
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-indigo-500/60"/>
          </div>
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Nota (opcional)</p>
            <input value={note} onChange={e=>setNote(e.target.value)} placeholder="Por qué…"
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-zinc-400 focus:outline-none focus:border-indigo-500/60"/>
          </div>
        </div>

        <button onClick={handleSave} disabled={!name.trim()||!amount}
          className="w-full py-5 bg-indigo-600 rounded-2xl font-bold text-sm uppercase tracking-wider active:scale-95 transition-all disabled:opacity-40">
          {debt ? 'Guardar cambios' : direction==='i_owe' ? 'Registrar que debo' : 'Registrar que me deben'}
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// SPENDING CALENDAR — mini heatmap mensual
// ─────────────────────────────────────────────
function SpendingCalendar({ transactions, year, month, onDayPress }) {
  const dayExpenses = useMemo(() => {
    const map = {};
    transactions.forEach(t => {
      if (t.type !== 'GASTO') return;
      const d = new Date(t.date + 'T12:00:00');
      if (d.getMonth() !== month || d.getFullYear() !== year) return;
      const day = d.getDate();
      map[day] = (map[day] || 0) + Number(t.amount);
    });
    return map;
  }, [transactions, year, month]);

  const maxExp = useMemo(() => Math.max(1, ...Object.values(dayExpenses).length ? Object.values(dayExpenses) : [1]), [dayExpenses]);

  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const firstDow = new Date(year, month, 1).getDay(); // 0=Dom
  const startOffset = firstDow === 0 ? 6 : firstDow - 1; // Lun=0
  const cells = [];
  for (let i = 0; i < startOffset; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(d);
  while (cells.length % 7 !== 0) cells.push(null);

  const now = new Date();
  const isToday = (day) => day && now.getDate() === day && now.getMonth() === month && now.getFullYear() === year;

  const getColor = (day) => {
    if (!day) return '';
    const exp = dayExpenses[day] || 0;
    if (exp === 0) return 'bg-zinc-900/60 border-white/5 text-zinc-700';
    const ratio = exp / maxExp;
    if (ratio < 0.33) return 'bg-emerald-500/25 border-emerald-500/20 text-emerald-300';
    if (ratio < 0.66) return 'bg-amber-500/30 border-amber-500/20 text-amber-300';
    return 'bg-rose-500/35 border-rose-500/25 text-rose-300';
  };

  const toDateStr = (day) => {
    const m = String(month + 1).padStart(2, '0');
    const d = String(day).padStart(2, '0');
    return `${year}-${m}-${d}`;
  };

  return (
    <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
      <p className="text-sm font-bold text-zinc-300 mb-3 flex items-center gap-2">
        <Calendar className="w-4 h-4 text-indigo-400"/>
        Gastos del mes
      </p>
      <div className="grid grid-cols-7 gap-1 mb-1">
        {['L','M','X','J','V','S','D'].map(d => (
          <div key={d} className="text-center text-[10px] font-bold text-zinc-600">{d}</div>
        ))}
      </div>
      <div className="grid grid-cols-7 gap-1">
        {cells.map((day, i) => (
          <button
            key={i}
            onClick={() => day && dayExpenses[day] && onDayPress(toDateStr(day))}
            disabled={!day || !dayExpenses[day]}
            className={`aspect-square flex items-center justify-center rounded-lg text-[11px] font-bold border transition-all
              ${day ? getColor(day) : 'border-transparent'}
              ${isToday(day) ? 'ring-1 ring-indigo-400/70' : ''}
              ${day && dayExpenses[day] ? 'active:scale-90' : ''}`}>
            {day ? <span className={isToday(day) ? 'text-indigo-300 font-black' : ''}>{day}</span> : null}
          </button>
        ))}
      </div>
      <div className="flex items-center gap-3 mt-3 justify-end">
        <div className="flex items-center gap-1"><div className="w-2.5 h-2.5 rounded-sm bg-emerald-500/30 border border-emerald-500/20"/><span className="text-[10px] text-zinc-600">poco</span></div>
        <div className="flex items-center gap-1"><div className="w-2.5 h-2.5 rounded-sm bg-amber-500/35 border border-amber-500/20"/><span className="text-[10px] text-zinc-600">medio</span></div>
        <div className="flex items-center gap-1"><div className="w-2.5 h-2.5 rounded-sm bg-rose-500/40 border border-rose-500/25"/><span className="text-[10px] text-zinc-600">mucho</span></div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// CONFETTI — celebración al completar una meta
// ─────────────────────────────────────────────
function Confetti({ onDone }) {
  useEffect(() => {
    const t = setTimeout(() => onDone?.(), 2800);
    return () => clearTimeout(t);
  }, [onDone]);
  const particles = useMemo(() =>
    Array.from({ length: 36 }, (_, i) => ({
      id: i,
      x: Math.random() * 100,
      color: ['#6366f1','#10b981','#f43f5e','#f59e0b','#3b82f6','#8b5cf6','#ec4899','#14b8a6'][i % 8],
      delay: (Math.random() * 0.6).toFixed(2),
      dur:   (1.6 + Math.random() * 1.2).toFixed(2),
      size:  Math.floor(6 + Math.random() * 9),
      rot:   Math.floor(Math.random() * 360),
    }))
  , []);
  return (
    <div className="fixed inset-0 z-[900] pointer-events-none overflow-hidden">
      {particles.map(p => (
        <div key={p.id} className="absolute animate-confetti-fall"
          style={{
            left: `${p.x}%`, top: '-20px',
            width: p.size, height: p.size,
            backgroundColor: p.color,
            borderRadius: p.id % 3 === 0 ? '50%' : '2px',
            animationDelay: `${p.delay}s`,
            animationDuration: `${p.dur}s`,
            transform: `rotate(${p.rot}deg)`,
          }}
        />
      ))}
      <div className="absolute inset-x-0 top-1/3 flex justify-center">
        <div className="bg-black/90 border border-white/10 rounded-3xl px-10 py-7 text-center shadow-2xl animate-slide-down">
          <div className="text-5xl mb-3">🏆</div>
          <p className="text-xl font-black text-white">¡Meta alcanzada!</p>
          <p className="text-sm text-zinc-400 mt-1">¡Felicitaciones! 🎉</p>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// ANNUAL MODAL — resumen 12 meses del año
// ─────────────────────────────────────────────
function AnnualModal({ transactions, year, onClose }) {
  const months = useMemo(() => {
    return Array.from({ length: 12 }, (_, m) => {
      const txs = transactions.filter(t => {
        const d = new Date(t.date);
        return d.getMonth() === m && d.getFullYear() === year;
      });
      const income  = txs.filter(t => t.type==='INGRESO').reduce((a,c) => a+Number(c.amount), 0);
      const expense = txs.filter(t => t.type==='GASTO').reduce((a,c) => a+Number(c.amount), 0);
      const balance = income - expense;
      return { m, income, expense, balance, count: txs.length };
    });
  }, [transactions, year]);

  const totals = useMemo(() => ({
    income:  months.reduce((a,r) => a+r.income, 0),
    expense: months.reduce((a,r) => a+r.expense, 0),
    balance: months.reduce((a,r) => a+r.balance, 0),
  }), [months]);

  const maxVal = Math.max(...months.map(r => Math.max(r.income, r.expense)), 1);

  return (
    <div className="fixed inset-0 z-[110] bg-black flex flex-col">
      <div className="px-6 pt-[calc(env(safe-area-inset-top)+16px)] pb-5 flex justify-between items-center border-b border-white/8">
        <div>
          <h3 className="text-xl font-black uppercase tracking-tight">Año {year}</h3>
          <p className="text-xs text-zinc-600 mt-0.5">Resumen anual · 12 meses</p>
        </div>
        <button onClick={onClose} className="p-2.5 bg-zinc-900 rounded-xl"><X className="w-5 h-5"/></button>
      </div>

      <div className="flex-1 overflow-y-auto px-5 py-5 no-scrollbar pb-12 space-y-5">
        {/* Totales del año */}
        <div className="grid grid-cols-3 gap-3">
          <div className="bg-emerald-500/10 border border-emerald-500/20 rounded-2xl p-4 text-center">
            <p className="text-[10px] text-zinc-500 font-semibold mb-1">INGRESOS</p>
            <p className="text-base font-black text-emerald-400">${formatNumber(totals.income)}</p>
          </div>
          <div className="bg-rose-500/10 border border-rose-500/20 rounded-2xl p-4 text-center">
            <p className="text-[10px] text-zinc-500 font-semibold mb-1">GASTOS</p>
            <p className="text-base font-black text-rose-400">${formatNumber(totals.expense)}</p>
          </div>
          <div className={`border rounded-2xl p-4 text-center ${totals.balance>=0?'bg-indigo-500/10 border-indigo-500/20':'bg-zinc-900/60 border-white/5'}`}>
            <p className="text-[10px] text-zinc-500 font-semibold mb-1">BALANCE</p>
            <p className={`text-base font-black ${totals.balance>=0?'text-indigo-300':'text-rose-400'}`}>${formatNumber(totals.balance)}</p>
          </div>
        </div>

        {/* Gráfico SVG barras por mes */}
        <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
          <div className="flex items-center gap-3 mb-3 text-[10px] font-semibold text-zinc-500">
            <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-emerald-500 inline-block"/>Ingresos</span>
            <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-rose-500 inline-block"/>Gastos</span>
          </div>
          <svg viewBox={`0 0 ${12*28} 80`} className="w-full">
            {months.map((row, i) => {
              const h_inc = row.income  > 0 ? Math.round((row.income  / maxVal) * 65) : 0;
              const h_exp = row.expense > 0 ? Math.round((row.expense / maxVal) * 65) : 0;
              const x = i * 28;
              return (
                <g key={i}>
                  {h_inc > 0 && <rect x={x+2}  y={75-h_inc} width={11} height={h_inc} rx="3" fill="#10b981" opacity="0.8"/>}
                  {h_exp > 0 && <rect x={x+15} y={75-h_exp} width={11} height={h_exp} rx="3" fill="#f43f5e" opacity="0.8"/>}
                  <text x={x+14} y="80" textAnchor="middle" fill="#52525b" fontSize="6" fontWeight="700">
                    {MONTHS[row.m].slice(0,3)}
                  </text>
                </g>
              );
            })}
          </svg>
        </div>

        {/* Filas por mes */}
        <div className="space-y-2">
          {months.map(row => (
            row.count === 0 ? null : (
              <div key={row.m} className="bg-zinc-900/50 rounded-2xl border border-white/5 px-4 py-3.5">
                <div className="flex items-center justify-between">
                  <span className="text-sm font-bold text-zinc-300 w-24">{MONTHS[row.m]}</span>
                  <div className="flex items-center gap-4 flex-1 justify-end">
                    <div className="text-right">
                      <p className="text-[10px] text-zinc-600">Ingresos</p>
                      <p className="text-xs font-bold text-emerald-400">${formatNumber(row.income)}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-[10px] text-zinc-600">Gastos</p>
                      <p className="text-xs font-bold text-rose-400">${formatNumber(row.expense)}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-[10px] text-zinc-600">Balance</p>
                      <p className={`text-xs font-black ${row.balance>=0?'text-white':'text-rose-400'}`}>
                        {row.balance>=0?'+':''} ${formatNumber(row.balance)}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            )
          ))}
          {months.every(r=>r.count===0) && (
            <div className="text-center py-16">
              <p className="text-sm font-semibold text-zinc-600">Sin movimientos en {year}</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// REPORT MODAL — snapshot mensual compartible
// ─────────────────────────────────────────────
function ReportModal({ stats, transactions, currentDate, prevMonth, projection, recurring, onClose }) {
  const toast = useToast();
  const month = currentDate.getMonth(), year = currentDate.getFullYear();
  const monthTxs = transactions.filter(t => {
    const d = new Date(t.date);
    return d.getMonth()===month && d.getFullYear()===year;
  });
  const now = new Date();
  const isCurrentMonth = now.getMonth()===month && now.getFullYear()===year;
  const daysInMonth = new Date(year, month+1, 0).getDate();
  const daysPassed = isCurrentMonth ? now.getDate() : daysInMonth;
  const monthProgress = Math.round((daysPassed/daysInMonth)*100);
  const topCats = Object.entries(stats.expenseByCategory).sort((a,b)=>b[1]-a[1]).slice(0,5);

  const handleShare = async () => {
    const lines = [
      `📊 MetaCasa — ${MONTHS[month]} ${year}`,
      ``,
      `💰 Ingresos:   $${formatNumber(stats.income)}`,
      `💸 Gastos:     $${formatNumber(stats.expenses)}`,
      `🐷 Ahorro:     $${formatNumber(stats.savingsAmount)}`,
      `📈 Inversión:  $${formatNumber(stats.investmentAmount)}`,
      `✅ Disponible: $${formatNumber(stats.available)}`,
      ``,
      topCats.length ? `🗂 Top categorías:\n${topCats.map(([c,v])=>`  · ${c}: $${formatNumber(v)}`).join('\n')}` : '',
      ``,
      `Generado con MetaCasa 🏠`,
    ].filter(Boolean).join('\n');
    if (navigator.share) {
      try { await navigator.share({ title: `MetaCasa — ${MONTHS[month]} ${year}`, text: lines }); } catch {}
    } else {
      await navigator.clipboard?.writeText(lines);
      toast('Copiado al portapapeles ✓', 'success');
    }
  };

  return (
    <div className="fixed inset-0 z-[200] bg-black flex flex-col">
      <div className="px-6 pt-[calc(env(safe-area-inset-top)+16px)] pb-5 flex justify-between items-center border-b border-white/8">
        <div>
          <h3 className="text-xl font-black uppercase tracking-tight">Reporte</h3>
          <p className="text-xs text-zinc-500 mt-0.5">{MONTHS[month]} {year} · {monthTxs.length} movimientos</p>
        </div>
        <div className="flex gap-2">
          <button onClick={handleShare} className="p-2.5 bg-indigo-600 rounded-xl active:scale-90 transition-transform" title="Compartir">
            <Share2 className="w-5 h-5"/>
          </button>
          <button onClick={onClose} className="p-2.5 bg-zinc-900 rounded-xl"><X className="w-5 h-5"/></button>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-6 py-5 space-y-5 no-scrollbar pb-12">

        {/* Tarjetas de balance */}
        <div className="grid grid-cols-2 gap-3">
          {[
            { label:'Ingresos',  value:stats.income,          color:'text-emerald-400', bg:'bg-emerald-500/10' },
            { label:'Gastos',    value:stats.expenses,         color:'text-rose-400',    bg:'bg-rose-500/10'    },
            { label:'Ahorro',    value:stats.savingsAmount,    color:'text-emerald-400', bg:'bg-zinc-900/60'    },
            { label:'Inversión', value:stats.investmentAmount, color:'text-indigo-400',  bg:'bg-indigo-500/10'  },
          ].map(item=>(
            <div key={item.label} className={`${item.bg} rounded-2xl p-4 border border-white/5`}>
              <p className="text-xs text-zinc-500 font-semibold">{item.label}</p>
              <p className={`text-xl font-black mt-0.5 ${item.color}`}>${formatNumber(item.value)}</p>
            </div>
          ))}
        </div>

        {/* Saldo disponible */}
        <div className={`rounded-2xl p-5 border ${stats.available>=0?'bg-indigo-600/10 border-indigo-500/20':'bg-rose-600/10 border-rose-500/20'}`}>
          <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider">Saldo disponible</p>
          <p className={`text-4xl font-black mt-1 ${stats.available>=0?'text-white':'text-rose-400'}`}>${formatNumber(stats.available)}</p>
        </div>

        {/* Progreso del mes */}
        <div className="bg-zinc-900/40 rounded-2xl p-4 border border-white/5 space-y-2">
          <div className="flex justify-between items-center">
            <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider">Progreso del mes</p>
            <span className="text-xs font-bold text-zinc-400">{daysPassed}/{daysInMonth} días</span>
          </div>
          <div className="h-2 bg-black rounded-full overflow-hidden">
            <div className="h-full bg-indigo-600 rounded-full" style={{width:`${monthProgress}%`}}/>
          </div>
          <p className="text-xs text-zinc-700 text-right">{monthProgress}% del mes</p>
        </div>

        {/* Top categorías */}
        {topCats.length > 0 && (
          <div className="space-y-2">
            <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider ml-1">Top gastos</p>
            <div className="bg-zinc-900/40 rounded-2xl border border-white/5 overflow-hidden">
              {topCats.map(([cat,val],i)=>{
                const pct = stats.expenses>0 ? Math.round((val/stats.expenses)*100) : 0;
                return (
                  <div key={cat} className={`px-5 py-3.5 ${i<topCats.length-1?'border-b border-white/5':''}`}>
                    <div className="flex justify-between items-center mb-1.5">
                      <span className="text-sm font-semibold text-zinc-200">{cat}</span>
                      <div className="flex items-center gap-2">
                        <span className="text-xs text-zinc-600">{pct}%</span>
                        <span className="text-sm font-black">${formatNumber(val)}</span>
                      </div>
                    </div>
                    <div className="h-1.5 bg-black/60 rounded-full overflow-hidden">
                      <div className="h-full bg-rose-500 rounded-full transition-all duration-700" style={{width:`${pct}%`}}/>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Comparativa mes anterior */}
        {(prevMonth.income>0||prevMonth.expense>0) && (
          <div className="bg-zinc-900/40 rounded-2xl border border-white/5 p-5 space-y-3">
            <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider">vs mes anterior</p>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="text-xs text-zinc-600 mb-0.5">Ingresos ant.</p>
                <p className="text-lg font-black text-zinc-400">${formatNumber(prevMonth.income)}</p>
                {prevMonth.income>0 && <p className={`text-xs font-bold mt-0.5 ${stats.income>=prevMonth.income?'text-emerald-400':'text-rose-400'}`}>
                  {stats.income>=prevMonth.income?'▲':'▼'} {Math.abs(((stats.income-prevMonth.income)/prevMonth.income)*100).toFixed(0)}%
                </p>}
              </div>
              <div>
                <p className="text-xs text-zinc-600 mb-0.5">Gastos ant.</p>
                <p className="text-lg font-black text-zinc-400">${formatNumber(prevMonth.expense)}</p>
                {prevMonth.expense>0 && <p className={`text-xs font-bold mt-0.5 ${stats.expenses<=prevMonth.expense?'text-emerald-400':'text-rose-400'}`}>
                  {stats.expenses<=prevMonth.expense?'▼':'▲'} {Math.abs(((stats.expenses-prevMonth.expense)/prevMonth.expense)*100).toFixed(0)}%
                </p>}
              </div>
            </div>
          </div>
        )}

        {/* Proyección */}
        {projection && (
          <div className={`rounded-2xl p-5 border space-y-2 ${projection.projectedAvailable>=0?'bg-emerald-500/5 border-emerald-500/20':'bg-rose-500/5 border-rose-500/20'}`}>
            <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider">Proyección a fin de mes</p>
            <div className="flex justify-between">
              <div><p className="text-xs text-zinc-600">Gasto estimado</p><p className="text-lg font-black text-rose-400">${formatNumber(projection.projectedExpense)}</p></div>
              <div className="text-right"><p className="text-xs text-zinc-600">Saldo estimado</p><p className={`text-lg font-black ${projection.projectedAvailable>=0?'text-emerald-400':'text-rose-400'}`}>${formatNumber(projection.projectedAvailable)}</p></div>
            </div>
          </div>
        )}

        {/* Recurrentes */}
        {recurring.length > 0 && (
          <div className="space-y-2">
            <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider ml-1">Recurrentes activos ({recurring.length})</p>
            <div className="bg-zinc-900/40 rounded-2xl border border-white/5 overflow-hidden">
              {recurring.map((r,i)=>{
                const freq = FREQUENCIES.find(f=>f.v===r.frequency);
                return (
                  <div key={r.id} className={`flex justify-between items-center px-5 py-3.5 ${i<recurring.length-1?'border-b border-white/5':''}`}>
                    <div>
                      <p className="text-sm font-semibold text-zinc-200">{r.category}</p>
                      <p className="text-xs text-zinc-600">{freq?.l} · próx. {r.next_date}</p>
                    </div>
                    <p className={`text-sm font-black ${r.type==='INGRESO'?'text-emerald-400':'text-zinc-300'}`}>
                      {r.type==='GASTO'?'-':'+'} ${formatNumber(r.amount)}
                    </p>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// TRENDS CHART — área suave + línea últimos 6 meses
// ─────────────────────────────────────────────
function TrendsChart({ transactions }) {
  const months = [];
  for (let i = 5; i >= 0; i--) {
    const d = new Date();
    d.setDate(1);
    d.setMonth(d.getMonth() - i);
    months.push({ month: d.getMonth(), year: d.getFullYear(), label: MONTHS[d.getMonth()].slice(0,3) });
  }
  const data = months.map(({ month, year, label }) => {
    const txs = transactions.filter(t => {
      const d = new Date(t.date);
      return d.getMonth()===month && d.getFullYear()===year;
    });
    const income  = txs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
    const expense = txs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0);
    return { label, income, expense };
  });

  const W=340, H=130, PL=6, PR=6, PT=12, PB=22;
  const innerW = W - PL - PR;
  const innerH = H - PT - PB;
  const n = data.length;
  const stepX = innerW / Math.max(n - 1, 1);
  const maxVal = Math.max(...data.map(d => Math.max(d.income, d.expense)), 1);
  const bottomY = PT + innerH;

  const getX = (i) => PL + i * stepX;
  const getY = (val) => PT + innerH - (val / maxVal) * innerH;

  const buildArea = (series) => {
    const pts = data.map((d, i) => ({ x: getX(i), y: getY(d[series]) }));
    const line = pts.map((p, i) => `${i===0?'M':'L'}${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(' ');
    return line + ` L${pts[n-1].x.toFixed(1)},${bottomY} L${pts[0].x.toFixed(1)},${bottomY} Z`;
  };
  const buildLine = (series) => {
    return data.map((d, i) => `${i===0?'M':'L'}${getX(i).toFixed(1)},${getY(d[series]).toFixed(1)}`).join(' ');
  };

  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="w-full">
      <defs>
        <linearGradient id="tGrad1" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#10b981" stopOpacity="0.28"/>
          <stop offset="100%" stopColor="#10b981" stopOpacity="0.02"/>
        </linearGradient>
        <linearGradient id="tGrad2" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#f43f5e" stopOpacity="0.22"/>
          <stop offset="100%" stopColor="#f43f5e" stopOpacity="0.02"/>
        </linearGradient>
      </defs>

      {/* Grid lines */}
      {[0.33, 0.66, 1].map(f => (
        <line key={f} x1={PL} x2={W-PR}
          y1={(PT + innerH * (1-f)).toFixed(1)} y2={(PT + innerH * (1-f)).toFixed(1)}
          stroke="#27272a" strokeWidth="1"/>
      ))}

      {/* Áreas */}
      <path d={buildArea('income')}  fill="url(#tGrad1)"/>
      <path d={buildArea('expense')} fill="url(#tGrad2)"/>

      {/* Líneas */}
      <path d={buildLine('income')}  fill="none" stroke="#10b981" strokeWidth="2"
        strokeLinecap="round" strokeLinejoin="round"/>
      <path d={buildLine('expense')} fill="none" stroke="#f43f5e" strokeWidth="2"
        strokeLinecap="round" strokeLinejoin="round"/>

      {/* Puntos */}
      {data.map((d, i) => d.income > 0 && (
        <circle key={`i${i}`} cx={getX(i)} cy={getY(d.income)} r="3.5"
          fill="#10b981" stroke="#000" strokeWidth="1.5"/>
      ))}
      {data.map((d, i) => d.expense > 0 && (
        <circle key={`e${i}`} cx={getX(i)} cy={getY(d.expense)} r="3.5"
          fill="#f43f5e" stroke="#000" strokeWidth="1.5"/>
      ))}

      {/* Etiquetas */}
      {data.map((d, i) => (
        <text key={i} x={getX(i).toFixed(1)} y={H-5}
          textAnchor="middle" fill="#52525b" fontSize="8.5" fontWeight="600">
          {d.label}
        </text>
      ))}
    </svg>
  );
}

// ─────────────────────────────────────────────
// RECURRING CARD
// ─────────────────────────────────────────────
function RecurringCard({ rec, onEdit, onDelete, onToggle, getEmoji }) {
  const freq = FREQUENCIES.find(f => f.v === rec.frequency);
  return (
    <div className={`rounded-2xl border p-4 flex items-center gap-3 transition-all ${rec.active ? 'bg-zinc-900/60 border-white/8' : 'bg-zinc-900/30 border-white/5 opacity-50'}`}>
      <div className={`w-11 h-11 rounded-xl flex items-center justify-center text-xl flex-shrink-0
        ${rec.type==='INGRESO' ? 'bg-emerald-500/15' : 'bg-rose-500/15'}`}>
        {getEmoji(rec.category)}
      </div>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <p className={`text-sm font-bold truncate ${rec.active ? 'text-white' : 'text-zinc-500'}`}>{rec.category}</p>
          <span className="text-xs text-zinc-600 flex-shrink-0">{freq?.icon} {freq?.l}</span>
        </div>
        {rec.note ? <p className="text-xs text-zinc-500 italic truncate">"{rec.note}"</p> : null}
        <p className="text-xs text-zinc-600 mt-0.5">Próximo: {rec.next_date}</p>
      </div>
      <div className="flex items-center gap-2 flex-shrink-0">
        <p className={`text-base font-black ${rec.type==='INGRESO'?'text-emerald-400':'text-white'}`}>
          {rec.type==='GASTO'?'-':'+'} ${formatNumber(rec.amount)}
        </p>
        <div className="flex flex-col gap-0.5">
          <button onClick={()=>onToggle(rec)} className={`p-1 transition-colors ${rec.active?'text-indigo-400':'text-zinc-700'}`} title={rec.active?'Pausar':'Activar'}>
            <RefreshCw className="w-3.5 h-3.5"/>
          </button>
          <button onClick={()=>onEdit(rec)} className="p-1 text-zinc-700 active:text-indigo-400 transition-colors">
            <Edit3 className="w-3.5 h-3.5"/>
          </button>
          <button onClick={()=>onDelete(rec.id)} className="p-1 text-zinc-700 active:text-rose-500 transition-colors">
            <Trash2 className="w-3.5 h-3.5"/>
          </button>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// RECURRING FORM
// ─────────────────────────────────────────────
function RecurringForm({ rec, categories, onSave, onClose }) {
  const [type,      setType]      = useState(rec?.type || 'GASTO');
  const [amount,    setAmount]    = useState(rec ? String(rec.amount) : '');
  const [category,  setCategory]  = useState(rec?.category || (categories?.GASTO?.[0] || ''));
  const [frequency, setFrequency] = useState(rec?.frequency || 'monthly');
  const [startDate, setStartDate] = useState(rec?.start_date || new Date().toISOString().slice(0,10));
  const [endDate,   setEndDate]   = useState(rec?.end_date || '');
  const [note,      setNote]      = useState(rec?.note || '');
  const [saving,    setSaving]    = useState(false);

  const currentCats = categories?.[type] || [];

  const handleSave = async () => {
    if (!amount || !category) return;
    setSaving(true);
    await onSave({
      id: rec?.id,
      type,
      amount: parseFloat(amount.replace(/\D/g,'')) || 0,
      category,
      frequency,
      start_date: startDate,
      next_date: rec?.next_date || startDate,
      end_date: endDate || null,
      note: note.trim(),
      active: rec?.active ?? true,
    });
    setSaving(false);
  };

  return (
    <div className="fixed inset-0 z-[300] bg-black/90 backdrop-blur-xl flex items-end justify-center">
      <div className="w-full max-w-md bg-zinc-950 rounded-t-[2.5rem] border-t border-white/10 p-7 space-y-5 pb-[calc(2rem+env(safe-area-inset-bottom))] max-h-[90dvh] overflow-y-auto no-scrollbar">
        <div className="flex justify-between items-center">
          <h3 className="text-lg font-black uppercase tracking-tight">{rec ? 'Editar' : 'Nuevo'} recurrente</h3>
          <button onClick={onClose} className="p-2 bg-zinc-900 rounded-full"><X className="w-5 h-5"/></button>
        </div>

        {/* Tipo */}
        <div className="flex bg-black rounded-2xl p-1.5 border border-white/10">
          {['GASTO','INGRESO'].map(t=>(
            <button key={t} onClick={()=>{ setType(t); setCategory(categories?.[t]?.[0]||''); }}
              className={`flex-1 py-2.5 text-sm font-bold rounded-xl transition-all ${type===t?(t==='GASTO'?'bg-rose-600 text-white':'bg-emerald-600 text-white'):'text-zinc-500'}`}>
              {t}
            </button>
          ))}
        </div>

        {/* Monto */}
        <input value={amount} onChange={e=>setAmount(e.target.value.replace(/\D/g,''))}
          placeholder="$ 0" inputMode="numeric"
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-2xl font-black text-center focus:outline-none focus:border-indigo-500/60"/>

        {/* Categoría */}
        <div className="space-y-2">
          <p className="text-xs text-zinc-600 ml-1">Categoría</p>
          <div className="flex flex-wrap gap-2">
            {currentCats.map(c=>(
              <button key={c} onClick={()=>setCategory(c)}
                className={`px-3.5 py-2 rounded-xl text-xs font-bold transition-all
                  ${category===c?(type==='GASTO'?'bg-rose-600 text-white':'bg-emerald-600 text-white'):'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
                {c}
              </button>
            ))}
          </div>
        </div>

        {/* Frecuencia */}
        <div className="space-y-2">
          <p className="text-xs text-zinc-600 ml-1">Frecuencia</p>
          <div className="grid grid-cols-4 gap-2">
            {FREQUENCIES.map(f=>(
              <button key={f.v} onClick={()=>setFrequency(f.v)}
                className={`py-3 rounded-xl text-xs font-bold transition-all flex flex-col items-center gap-1
                  ${frequency===f.v?'bg-indigo-600 text-white':'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
                <span className="text-base">{f.icon}</span>
                <span>{f.l}</span>
              </button>
            ))}
          </div>
        </div>

        {/* Fechas */}
        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Inicia</p>
            <input type="date" value={startDate} onChange={e=>setStartDate(e.target.value)}
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-indigo-500/60"/>
          </div>
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Termina (opc.)</p>
            <input type="date" value={endDate} onChange={e=>setEndDate(e.target.value)}
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-indigo-500/60"/>
          </div>
        </div>

        {/* Nota */}
        <input value={note} onChange={e=>setNote(e.target.value)} placeholder="Nota (opcional)"
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-zinc-400 focus:outline-none focus:border-indigo-500/60"/>

        <button onClick={handleSave} disabled={saving||!amount||!category}
          className="w-full py-5 bg-indigo-600 rounded-2xl font-bold text-sm uppercase tracking-wider active:scale-95 transition-all disabled:opacity-40">
          {saving ? 'Guardando…' : rec ? 'Guardar cambios' : 'Agregar recurrente'}
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// APP PRINCIPAL
// ─────────────────────────────────────────────
export default function App() {
  // AUTH
  const [session,      setSession]      = useState(null);
  const [authLoading,  setAuthLoading]  = useState(true);
  const [authEmail,    setAuthEmail]    = useState("");
  const [authPassword, setAuthPassword] = useState("");
  const [authMode,     setAuthMode]     = useState("LOGIN");

  // DATA
  const [transactions, setTransactions] = useState([]);
  const [budgets,      setBudgets]      = useState({});
  const [strategy,     setStrategy]     = useState({ savingsPercent: 0, investmentPercent: 0 });
  const [customCats,   setCustomCats]   = useState(null);
  const [catMeta,      setCatMeta]      = useState({}); // { NombreCat: { emoji, color } }
  const [loadingData,  setLoadingData]  = useState(true);
  const [bills,        setBills]        = useState([]);
  const [recurring,    setRecurring]    = useState([]);

  // NAVIGATION
  const [activeTab, setActiveTab] = useState('home'); // home | add | history | settings

  // PERIOD
  const [currentDate, setCurrentDate] = useState(new Date());

  // MODALS
  const [showBudgetModal,  setShowBudgetModal]  = useState(false);
  const [budgetChartView,  setBudgetChartView]  = useState(false);
  const [showCatManager,   setShowCatManager]   = useState(false);
  const [showDatePicker,   setShowDatePicker]   = useState(false);
  const [editingTx,        setEditingTx]        = useState(null);
  const [showBillsModal,     setShowBillsModal]     = useState(false);
  const [showBillForm,       setShowBillForm]        = useState(false);
  const [editingBill,        setEditingBill]         = useState(null);
  const [showRecurringModal, setShowRecurringModal]  = useState(false);
  const [showRecurringForm,  setShowRecurringForm]   = useState(false);
  const [editingRecurring,   setEditingRecurring]    = useState(null);
  const [showEmojiPicker,    setShowEmojiPicker]     = useState(null); // catName being edited
  const [renamingCat,        setRenamingCat]         = useState(null);
  const [renameValue,        setRenameValue]         = useState('');
  const [mergingCat,         setMergingCat]          = useState(null);
  const [showAnnualModal,    setShowAnnualModal]     = useState(false);
  const [showConfetti,       setShowConfetti]        = useState(false);
  const [showScrollTop,      setShowScrollTop]       = useState(false);
  const [deferredInstall,    setDeferredInstall]     = useState(null);
  const [showInstallBanner,  setShowInstallBanner]   = useState(false);

  // BÚSQUEDA Y FILTROS (Historial)
  const [searchQuery,      setSearchQuery]      = useState('');
  const [filterType,       setFilterType]       = useState('ALL');   // ALL | GASTO | INGRESO
  const [filterCategory,   setFilterCategory]   = useState('');      // '' = todas
  const [sortBy,           setSortBy]           = useState('date_desc'); // date_desc | date_asc | amount_desc | amount_asc
  const [allMonths,        setAllMonths]        = useState(false);   // false = solo mes actual
  const [filterDate,       setFilterDate]       = useState('');      // '' | 'YYYY-MM-DD'
  const [filterMin,        setFilterMin]        = useState('');      // '' | number string
  const [filterMax,        setFilterMax]        = useState('');      // '' | number string
  const [filterWeek,       setFilterWeek]       = useState(false);   // true = esta semana
  const [filterDateFrom,   setFilterDateFrom]   = useState('');      // '' | 'YYYY-MM-DD'
  const [filterDateTo,     setFilterDateTo]     = useState('');      // '' | 'YYYY-MM-DD'
  const [showRangeFilter,  setShowRangeFilter]  = useState(false);
  const [compactView,      setCompactView]      = useState(false);
  const [monthMemos,       setMonthMemos]       = useState(() => {
    try { return JSON.parse(localStorage.getItem(MEMO_KEY) || '{}'); } catch { return {}; }
  });

  // FORM
  const [type,       setType]       = useState('GASTO');
  const [amount,     setAmount]     = useState('');
  const [category,   setCategory]   = useState("");
  const [note,       setNote]       = useState("");
  const [txDate,     setTxDate]     = useState(new Date().toISOString().slice(0,10));
  const [newCatName,     setNewCatName]     = useState("");
  const [showInlineCat,  setShowInlineCat]  = useState(false);
  const [inlineCatName,  setInlineCatName]  = useState('');
  const [savingTx,   setSavingTx]   = useState(false);
  const [savedOk,    setSavedOk]    = useState(false);

  // TIPO DE CAMBIO (persiste en localStorage)
  const [exchangeRate, setExchangeRate] = useState(() => {
    const stored = localStorage.getItem('metacasa_usd_rate');
    return stored ? parseFloat(stored) : 0;
  });

  // VOZ + REPORTE
  const [isListening,  setIsListening]  = useState(false);
  const [showReport,   setShowReport]   = useState(false);
  const recognitionRef = useRef(null);
  const voiceSupported = typeof window !== 'undefined' &&
    !!(window.SpeechRecognition || window.webkitSpeechRecognition);

  // METAS DE AHORRO (localStorage)
  const [goals,           setGoals]           = useState(() => {
    try { return JSON.parse(localStorage.getItem(GOALS_KEY) || '[]'); } catch { return []; }
  });
  const [showGoalsModal,  setShowGoalsModal]  = useState(false);
  const [showGoalForm,    setShowGoalForm]    = useState(false);
  const [editingGoal,     setEditingGoal]     = useState(null);
  const [contributeGoal,  setContributeGoal]  = useState(null);

  // DEUDAS
  const [debts,           setDebts]           = useState([]);
  const [showDebtsModal,  setShowDebtsModal]  = useState(false);
  const [showDebtForm,    setShowDebtForm]    = useState(false);
  const [editingDebt,     setEditingDebt]     = useState(null);

  // CUOTAS (localStorage)
  const [cuotas,          setCuotas]          = useState(() => {
    try { return JSON.parse(localStorage.getItem(CUOTAS_KEY) || '[]'); } catch { return []; }
  });
  const [showCuotasModal, setShowCuotasModal] = useState(false);
  const [showCuotaForm,   setShowCuotaForm]   = useState(false);
  const [editingCuota,    setEditingCuota]    = useState(null);

  // ATAJOS RÁPIDOS (templates de transacciones)
  const [templates, setTemplates] = useState(() => {
    try { return JSON.parse(localStorage.getItem(TEMPLATES_KEY) || '[]'); } catch { return []; }
  });
  const saveTemplate = (tpl) => {
    if (templates.length >= 8) { toast('Máximo 8 atajos guardados', 'info'); return; }
    const list = [...templates, { ...tpl, id: Date.now() }];
    setTemplates(list);
    localStorage.setItem(TEMPLATES_KEY, JSON.stringify(list));
    toast('Atajo guardado ✓', 'success');
    haptic(12);
  };
  const deleteTemplate = (id) => {
    const list = templates.filter(t => t.id !== id);
    setTemplates(list);
    localStorage.setItem(TEMPLATES_KEY, JSON.stringify(list));
  };

  // NOTA DEL MES — expand state para el memo existente (currentMemo / saveMemo)
  const [notaExpanded, setNotaExpanded] = useState(false);

  // MODO PRIVACIDAD
  const [privacyMode, setPrivacyMode] = useState(() => localStorage.getItem('metacasa_privacy') === '1');
  const togglePrivacy = () => setPrivacyMode(v => {
    const next = !v;
    localStorage.setItem('metacasa_privacy', next ? '1' : '0');
    haptic(12);
    return next;
  });
  const priv = (val) => privacyMode ? '••••' : val;

  // PLANIFICADOR DE MES (localStorage por YYYY-MM)
  const planMesKey = `metacasa_plan_${currentDate.getFullYear()}-${String(currentDate.getMonth()+1).padStart(2,'0')}`;
  const [planMes,         setPlanMes]         = useState({ targetIncome: 0, targetExpense: 0 });
  const [showPlanEditor,  setShowPlanEditor]  = useState(false);
  useEffect(() => {
    try {
      const stored = JSON.parse(localStorage.getItem(planMesKey) || 'null');
      setPlanMes(stored || { targetIncome: 0, targetExpense: 0 });
    } catch { setPlanMes({ targetIncome: 0, targetExpense: 0 }); }
  }, [planMesKey]);
  const savePlanMes = (plan) => {
    setPlanMes(plan);
    localStorage.setItem(planMesKey, JSON.stringify(plan));
    setShowPlanEditor(false);
    toast('Plan del mes guardado ✓', 'success');
    haptic(12);
  };

  // CONFIRMACIÓN INLINE DE ELIMINACIÓN
  const [pendingDelete,   setPendingDelete]   = useState(null); // { id, type }
  const pendingDeleteRef = useRef(null);

  const toast = useToast();
  const userId = session?.user?.id;
  const mountedRef = useRef(false);

  // ── AUTH ──
  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setAuthLoading(false);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => sub.subscription.unsubscribe();
  }, []);

  const signUp = async () => {
    const { error } = await supabase.auth.signUp({ email: authEmail, password: authPassword });
    if (error) toast(error.message, 'error');
    else toast('Revisá tu email para confirmar la cuenta', 'info');
  };
  const signIn = async () => {
    const { error } = await supabase.auth.signInWithPassword({ email: authEmail, password: authPassword });
    if (error) toast(error.message, 'error');
  };
  const signOut = async () => { await supabase.auth.signOut(); };

  // ── DATA LOADERS ──
  const loadTransactions = useCallback(async () => {
    if (!userId) return;
    const { data, error } = await supabase.from('transactions').select('*')
      .order('date', { ascending: false }).order('created_at', { ascending: false });
    if (error) { console.error(error); return; }
    setTransactions((data || []).map(t => ({ ...t, amount: Number(t.amount || 0), note: t.note || "" })));
  }, [userId]);

  const loadBudgets = useCallback(async () => {
    if (!userId) return;
    const { data, error } = await supabase.from('budgets').select('category, amount');
    if (error) { console.error(error); return; }
    const b = {};
    (data || []).forEach(row => { b[row.category] = { amount: Number(row.amount || 0) }; });
    setBudgets(b);
  }, [userId]);

  const loadStrategy = useCallback(async () => {
    if (!userId) return;
    const { data, error } = await supabase.from('strategy')
      .select('savings_percent, investment_percent').maybeSingle();
    if (error && error.code !== 'PGRST116') { console.error(error); return; }
    setStrategy({ savingsPercent: Number(data?.savings_percent || 0), investmentPercent: Number(data?.investment_percent || 0) });
  }, [userId]);

  const loadCategories = useCallback(async () => {
    if (!userId) return;
    const { data, error } = await supabase.from('categories').select('data').maybeSingle();
    if (error && error.code !== 'PGRST116') { console.error(error); return; }
    const raw = data?.data || null;
    if (raw) {
      const { meta, goals: cloudGoals, cuotas: cloudCuotas, debts: cloudDebts, ...cats } = raw;
      setCustomCats(cats);
      setCatMeta(meta || {});
      // Cloud wins over localStorage
      if (cloudGoals)  { setGoals(cloudGoals);   localStorage.setItem(GOALS_KEY,  JSON.stringify(cloudGoals));  }
      if (cloudCuotas) { setCuotas(cloudCuotas); localStorage.setItem(CUOTAS_KEY, JSON.stringify(cloudCuotas)); }
      if (cloudDebts)  { setDebts(cloudDebts); }
    } else {
      setCustomCats(null);
      setCatMeta({});
    }
  }, [userId]);

  const loadRecurring = useCallback(async () => {
    if (!userId) return;
    const { data, error } = await supabase
      .from('recurring_transactions').select('*')
      .eq('active', true).order('next_date', { ascending: true });
    if (error) { console.error(error); return; }
    setRecurring(data || []);
  }, [userId]);

  // Auto-generador: procesa recurrentes cuyo next_date <= hoy
  const autoGenerateRecurring = useCallback(async (recurringList) => {
    if (!userId || !recurringList.length) return;
    const todayStr = new Date().toISOString().slice(0, 10);
    const due = recurringList.filter(r => r.active && r.next_date <= todayStr);
    if (!due.length) return;
    const inserts = due.map(r => ({
      user_id: userId, amount: r.amount, category: r.category,
      type: r.type, note: r.note || '', date: new Date(r.next_date).toISOString()
    }));
    await supabase.from('transactions').insert(inserts);
    // Avanzar next_date de cada recurrente
    for (const r of due) {
      const nd = new Date(r.next_date);
      if (r.frequency === 'daily')   nd.setDate(nd.getDate() + 1);
      if (r.frequency === 'weekly')  nd.setDate(nd.getDate() + 7);
      if (r.frequency === 'monthly') nd.setMonth(nd.getMonth() + 1);
      if (r.frequency === 'yearly')  nd.setFullYear(nd.getFullYear() + 1);
      const nextStr = nd.toISOString().slice(0, 10);
      const shouldDeactivate = r.end_date && nextStr > r.end_date;
      await supabase.from('recurring_transactions').update({
        next_date: nextStr, active: !shouldDeactivate
      }).eq('id', r.id);
    }
    if (due.length > 0) toast(`${due.length} movimiento${due.length>1?'s':''} recurrente${due.length>1?'s':''} generado${due.length>1?'s':''}`, 'info');
  }, [userId, toast]);

  const loadBills = useCallback(async () => {
    if (!userId) return;
    const { data, error } = await supabase
      .from('bills')
      .select('*')
      .order('due_date', { ascending: true });
    if (error) { console.error(error); return; }
    setBills(data || []);
  }, [userId]);

  const loadAll = useCallback(async () => {
    setLoadingData(true);
    const [,,,,recurringData] = await Promise.all([
      loadTransactions(), loadBudgets(), loadStrategy(), loadCategories(),
      (async () => {
        if (!userId) return [];
        const { data } = await supabase.from('recurring_transactions').select('*').eq('active', true).order('next_date', { ascending: true });
        const list = data || [];
        setRecurring(list);
        return list;
      })(),
      loadBills()
    ]);
    await autoGenerateRecurring(recurringData || []);
    if (recurringData?.length) await loadTransactions(); // recargar si hubo auto-gen
    setLoadingData(false);
  }, [loadTransactions, loadBudgets, loadStrategy, loadCategories, loadBills, autoGenerateRecurring, userId]);

  useEffect(() => { if (userId) loadAll(); }, [userId, loadAll]);

  const activeCategories = useMemo(() => customCats || INITIAL_CATEGORIES, [customCats]);

  useEffect(() => {
    if (activeCategories[type]?.length > 0) setCategory(activeCategories[type][0]);
  }, [type, activeCategories]);

  // Scroll-to-top tracker
  useEffect(() => {
    const onScroll = () => setShowScrollTop(window.scrollY > 250);
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  // PWA install prompt
  useEffect(() => {
    const handler = (e) => { e.preventDefault(); setDeferredInstall(e); setShowInstallBanner(true); };
    window.addEventListener('beforeinstallprompt', handler);
    return () => window.removeEventListener('beforeinstallprompt', handler);
  }, []);

  // ── STATS ──
  const stats = useMemo(() => {
    const m = currentDate.getMonth(), y = currentDate.getFullYear();
    const cur = transactions.filter(t => { const d = new Date(t.date); return d.getMonth()===m && d.getFullYear()===y; });
    const income   = cur.filter(t => t.type==='INGRESO').reduce((a,c) => a+Number(c.amount),0);
    const expenses = cur.filter(t => t.type==='GASTO').reduce((a,c) => a+Number(c.amount),0);
    const expenseByCategory = {};
    cur.filter(t => t.type==='GASTO').forEach(t => { expenseByCategory[t.category]=(expenseByCategory[t.category]||0)+Number(t.amount); });
    const savingsAmount    = (income*(strategy.savingsPercent||0))/100;
    const investmentAmount = (income*(strategy.investmentPercent||0))/100;
    const totalHistoricalIncome    = transactions.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
    const historicalSavingsTotal   = (totalHistoricalIncome*(strategy.savingsPercent||0))/100;
    const historicalInvestmentTotal= (totalHistoricalIncome*(strategy.investmentPercent||0))/100;
    const totalBudgetsAssigned = Object.values(budgets).reduce((a,b)=>a+Number(b.amount||0),0);
    const available = income - savingsAmount - investmentAmount - expenses;
    const availableToAssign = income - savingsAmount - investmentAmount - totalBudgetsAssigned;
    return { income, expenses, available, expenseByCategory, savingsAmount, investmentAmount,
             totalBudgetsAssigned, availableToAssign, historicalSavingsTotal, historicalInvestmentTotal };
  }, [transactions, currentDate, strategy, budgets]);

  // ── PROYECCIÓN FIN DE MES ──
  const projection = useMemo(() => {
    const now = new Date();
    const isCurrentMonth = now.getMonth()===currentDate.getMonth() && now.getFullYear()===currentDate.getFullYear();
    if (!isCurrentMonth) return null;
    const daysPassed = now.getDate();
    const daysInMonth = new Date(now.getFullYear(), now.getMonth()+1, 0).getDate();
    const daysLeft = daysInMonth - daysPassed;
    if (daysPassed === 0 || stats.expenses === 0) return null;
    const dailyRate = stats.expenses / daysPassed;
    const projectedExpense = Math.round(stats.expenses + dailyRate * daysLeft);
    const projectedAvailable = stats.income - projectedExpense - stats.savingsAmount - stats.investmentAmount;
    const trend = stats.expenses > 0 ? ((projectedExpense / stats.expenses - 1) * 100).toFixed(0) : 0;
    return { projectedExpense, projectedAvailable, daysLeft, dailyRate, trend };
  }, [stats, currentDate]);

  // ── COMPARATIVA MES ANTERIOR ──
  const prevMonth = useMemo(() => {
    const prev = new Date(currentDate.getFullYear(), currentDate.getMonth()-1, 1);
    const txs = transactions.filter(t => {
      const d = new Date(t.date);
      return d.getMonth()===prev.getMonth() && d.getFullYear()===prev.getFullYear();
    });
    const income  = txs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
    const expense = txs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0);
    return { income, expense };
  }, [transactions, currentDate]);

  // ── CUOTAS DEL MES ──
  const cuotasMonthly = useMemo(() => {
    const now = new Date();
    return cuotas
      .filter(c => {
        if (c.paidCuotas >= c.totalCuotas) return false;
        const start = new Date(c.startDate);
        const end = new Date(c.startDate);
        end.setMonth(end.getMonth() + c.totalCuotas);
        return now >= start && now < end;
      })
      .reduce((a, c) => a + c.monthlyAmount, 0);
  }, [cuotas]);

  const activeCuotas = cuotas.filter(c => c.paidCuotas < c.totalCuotas);

  // ── DEUDAS COMPUTED ──
  const totalOwedToMe = debts.filter(d => !d.settled && d.direction === 'owed_to_me').reduce((a,d) => a + d.amount, 0);
  const totalIOwe     = debts.filter(d => !d.settled && d.direction === 'i_owe').reduce((a,d) => a + d.amount, 0);
  const pendingDebts  = debts.filter(d => !d.settled);

  // ── PATRIMONIO NETO ──
  const patrimonioNeto = useMemo(() => {
    // Activos: saldo disponible del mes actual + total guardado en metas + lo que me deben
    const activeGoalsSaved = goals.reduce((a, g) => a + g.current, 0);
    const activos = Math.max(0, stats.available) + activeGoalsSaved + totalOwedToMe;
    // Pasivos: total que debo + cuotas pendientes × monto mensual restante
    const cuotasPendientes = cuotas.reduce((a, c) => {
      const rem = Math.max(0, c.totalCuotas - c.paidCuotas);
      return a + rem * c.monthlyAmount;
    }, 0);
    const pasivos = totalIOwe + cuotasPendientes;
    return { activos, pasivos, neto: activos - pasivos };
  }, [stats.available, goals, totalOwedToMe, totalIOwe, cuotas]);

  // ── TIPO DE CAMBIO ──
  const updateExchangeRate = (val) => {
    const n = parseFloat(String(val).replace(/\D/g,'')) || 0;
    setExchangeRate(n);
    localStorage.setItem('metacasa_usd_rate', String(n));
  };

  // ── SYNC EXTRAS → SUPABASE (goals / cuotas / debts en el blob de categories) ──
  const syncExtrasToCloud = useCallback(async (newGoals, newCuotas, newDebts) => {
    if (!userId) return;
    const cats = customCats || INITIAL_CATEGORIES;
    const payload = { ...cats, meta: catMeta, goals: newGoals, cuotas: newCuotas, debts: newDebts };
    const { error } = await supabase.from('categories').upsert(
      { user_id: userId, data: payload }, { onConflict: 'user_id' }
    );
    if (error) console.error('syncExtrasToCloud error:', error);
  }, [userId, customCats, catMeta]);

  // ── VOZ ──
  const startListening = useCallback(() => {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SR) { toast('Tu dispositivo no soporta dictado por voz', 'error'); return; }
    const rec = new SR();
    recognitionRef.current = rec;
    rec.lang = 'es-AR';
    rec.continuous = false;
    rec.interimResults = false;
    rec.maxAlternatives = 1;
    rec.onstart  = () => setIsListening(true);
    rec.onend    = () => setIsListening(false);
    rec.onerror  = (e) => { setIsListening(false); if (e.error !== 'aborted') toast('Error de voz: ' + e.error, 'error'); };
    rec.onresult = (e) => {
      const text = e.results[0][0].transcript;
      const parsed = parseVoiceAmount(text);
      if (parsed > 0) setAmount(String(parsed));
      setNote(text);
      toast('Dictado capturado ✓', 'success');
    };
    rec.start();
  }, [toast]);

  const stopListening = useCallback(() => {
    recognitionRef.current?.stop();
    setIsListening(false);
  }, []);

  // ── METAS CRUD (localStorage + cloud sync) ──
  const persistGoals = (list) => {
    setGoals(list);
    localStorage.setItem(GOALS_KEY, JSON.stringify(list));
    syncExtrasToCloud(list, cuotas, debts);
  };
  const saveGoal = (data) => {
    const exists = goals.find(g => g.id === data.id);
    const updated = exists ? goals.map(g => g.id===data.id ? data : g) : [...goals, data];
    persistGoals(updated);
    haptic(15);
  };
  const deleteGoal = (id) => {
    persistGoals(goals.filter(g => g.id !== id));
    haptic(20);
  };
  const addContribution = (goalId, contributionAmt) => {
    const goalBefore = goals.find(g => g.id === goalId);
    const newCurrent = (goalBefore?.current || 0) + contributionAmt;
    const justCompleted = goalBefore && goalBefore.current < goalBefore.target && newCurrent >= goalBefore.target;
    const updated = goals.map(g => g.id===goalId ? { ...g, current: newCurrent } : g);
    persistGoals(updated);
    if (justCompleted) {
      setShowConfetti(true);
      haptic(50);
    } else {
      haptic(15);
    }
  };

  // ── CUOTAS CRUD (localStorage + cloud sync) ──
  const persistCuotas = (list) => {
    setCuotas(list);
    localStorage.setItem(CUOTAS_KEY, JSON.stringify(list));
    syncExtrasToCloud(goals, list, debts);
  };
  const saveCuota  = (data) => {
    const updated = cuotas.find(c=>c.id===data.id)
      ? cuotas.map(c => c.id===data.id ? data : c)
      : [...cuotas, data];
    persistCuotas(updated);
    haptic(15);
  };
  const deleteCuota = (id) => { persistCuotas(cuotas.filter(c=>c.id!==id)); haptic(20); };
  const payCuota    = (id) => {
    persistCuotas(cuotas.map(c => c.id===id
      ? { ...c, paidCuotas: Math.min(c.paidCuotas+1, c.totalCuotas) }
      : c
    ));
    haptic(15);
  };

  // ── DEUDAS CRUD (localStorage + cloud sync) ──
  const persistDebts = (list) => {
    setDebts(list);
    syncExtrasToCloud(goals, cuotas, list);
  };
  const saveDebt = (data) => {
    const updated = debts.find(d => d.id === data.id)
      ? debts.map(d => d.id===data.id ? data : d)
      : [...debts, data];
    persistDebts(updated);
    haptic(15);
  };
  const deleteDebt = (id) => { persistDebts(debts.filter(d => d.id !== id)); haptic(20); };
  const settleDebt = (id) => {
    persistDebts(debts.map(d => d.id===id ? { ...d, settled: true } : d));
    haptic(15);
    toast('Deuda saldada ✓', 'success');
  };

  // ── DELETE CONFIRM (inline 2-tap) ──
  const requestDelete = (id, type = 'tx') => {
    if (pendingDelete?.id === id && pendingDelete?.type === type) {
      // Second tap → execute
      clearTimeout(pendingDeleteRef.current);
      setPendingDelete(null);
      if (type === 'tx')   deleteTransaction(id);
      if (type === 'bill') deleteBill(id);
      haptic(30);
    } else {
      // First tap → arm
      setPendingDelete({ id, type });
      clearTimeout(pendingDeleteRef.current);
      pendingDeleteRef.current = setTimeout(() => setPendingDelete(null), 3000);
    }
  };

  // ── AUTO-SUGERENCIA DE CATEGORÍA ──
  const catSuggestion = useMemo(() => {
    if (!note.trim() || note.length < 3) return null;
    const lower = note.toLowerCase();
    const allCats = [...(activeCategories.GASTO||[]), ...(activeCategories.INGRESO||[])];
    for (const [catName, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
      if (!allCats.includes(catName)) continue;
      if (keywords.some(kw => lower.includes(kw))) {
        return catName === category ? null : catName;
      }
    }
    return null;
  }, [note, category, activeCategories]);

  // ── INSIGHTS DINÁMICOS ──
  const insights = useMemo(() => {
    if (stats.income === 0 && stats.expenses === 0) return [];
    const result = [];

    // 1. Tendencia de la categoría principal vs mes anterior
    const topCat = Object.entries(stats.expenseByCategory).sort((a,b)=>b[1]-a[1])[0];
    if (topCat && prevMonth.expense > 0) {
      const prev = new Date(currentDate.getFullYear(), currentDate.getMonth()-1, 1);
      const prevSpent = transactions
        .filter(t => { const d = new Date(t.date); return d.getMonth()===prev.getMonth() && d.getFullYear()===prev.getFullYear() && t.category===topCat[0] && t.type==='GASTO'; })
        .reduce((a,c) => a+Number(c.amount), 0);
      if (prevSpent > 0) {
        const pct = Math.round(((topCat[1] - prevSpent) / prevSpent) * 100);
        if (Math.abs(pct) >= 10) result.push({
          emoji: pct > 0 ? '📈' : '📉',
          text: `${topCat[0]}: ${pct>0?'+':''}${pct}% vs mes anterior`,
          color: pct > 0 ? 'text-rose-400' : 'text-emerald-400',
        });
      }
    }

    // 2. Tasa de ahorro
    if (stats.income > 0 && stats.available > 0) {
      const rate = Math.round((stats.available / stats.income) * 100);
      if (rate >= 10) result.push({
        emoji: '🐷',
        text: `Guardás el ${rate}% de tus ingresos este mes`,
        color: 'text-emerald-400',
      });
    }

    // 3. Categoría excedida
    const overspent = (activeCategories.GASTO || []).find(cat => {
      const limit = budgets[cat]?.amount || 0;
      return limit > 0 && (stats.expenseByCategory[cat] || 0) > limit;
    });
    if (overspent) result.push({
      emoji: '⚠️',
      text: `Excediste el límite de ${overspent}`,
      color: 'text-rose-400',
    });

    // 4. Próximo vencimiento en ≤7 días
    const nextBill = [...bills].filter(b=>b.status==='pending').sort((a,b)=>a.due_date.localeCompare(b.due_date))[0];
    if (nextBill) {
      const days = Math.ceil((new Date(nextBill.due_date+'T12:00:00') - new Date()) / 86400000);
      if (days >= 0 && days <= 7) result.push({
        emoji: '📅',
        text: `${nextBill.title} vence ${days===0?'hoy':'en '+days+' día'+(days!==1?'s':'')}`,
        color: days <= 2 ? 'text-rose-400' : 'text-amber-400',
      });
    }

    return result.slice(0, 3);
  }, [stats, prevMonth, transactions, currentDate, bills, budgets, activeCategories]);

  // ── COPIAR MOVIMIENTO AL FORMULARIO ──
  const prefillFromTransaction = useCallback((t) => {
    setType(t.type);
    setCategory(t.category);
    setAmount(String(t.amount));
    setNote(t.note || '');
    setTxDate(new Date().toISOString().slice(0, 10));
    setActiveTab('add');
    haptic(10);
    toast('Movimiento copiado al formulario', 'info');
  }, [toast]);

  // ── ACTIONS ──
  const handleSaveTransaction = async () => {
    if (!userId || !amount || !category) return;
    setSavingTx(true);
    const numericAmount = parseFormattedNumber(amount);

    // Alerta de posible duplicado (mismo monto + categoría en las últimas 2 horas)
    const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString();
    const recentDup = transactions.find(t =>
      t.type === type &&
      Number(t.amount) === numericAmount &&
      t.category === category &&
      t.date > twoHoursAgo
    );
    if (recentDup) {
      setTimeout(() => toast(`⚠️ Posible duplicado: ya registraste $${formatNumber(numericAmount)} en ${category}`, 'info'), 400);
    }
    const payload = { user_id: userId, amount: numericAmount, category, type, note: note.trim(), date: new Date(txDate).toISOString() };
    const { error } = await supabase.from('transactions').insert(payload);
    setSavingTx(false);
    if (error) { toast(error.message, 'error'); return; }

    // ── Alerta de presupuesto ──
    if (type === 'GASTO') {
      const limit = budgets[category]?.amount || 0;
      if (limit > 0) {
        const prevSpent = stats.expenseByCategory[category] || 0;
        const newSpent  = prevSpent + numericAmount;
        const prevPct   = (prevSpent / limit) * 100;
        const newPct    = (newSpent  / limit) * 100;
        if (newPct >= 100 && prevPct < 100) {
          setTimeout(() => toast(`⚠️ Superaste el presupuesto de ${category}`, 'error'), 500);
        } else if (newPct >= 80 && prevPct < 80) {
          setTimeout(() => toast(`⚡ ${category} al ${Math.round(newPct)}% del límite`, 'info'), 500);
        }
      }
    }

    setAmount(''); setNote('');
    setSavedOk(true);
    setTimeout(() => setSavedOk(false), 1800);
    haptic(15);
    toast('Movimiento registrado ✓', 'success');
    await loadTransactions();
  };

  const updateStrategy = async (field, value) => {
    if (!userId) return;
    const ns = { ...strategy, [field]: value };
    setStrategy(ns);
    const { error } = await supabase.from('strategy').upsert({ user_id: userId, savings_percent: Number(ns.savingsPercent||0), investment_percent: Number(ns.investmentPercent||0) }, { onConflict: 'user_id' });
    if (error) toast(error.message, 'error');
  };

  const changeMonth = (offset) => setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth()+offset, 1));

  // ── COMPARTIR RESUMEN MENSUAL ──
  const handleQuickShare = async () => {
    haptic(12);
    const mes = MONTHS[currentDate.getMonth()];
    const anio = currentDate.getFullYear();
    const balance = stats.income - stats.expenses;
    const topCat = Object.entries(stats.expenseByCategory).sort((a,b)=>b[1]-a[1])[0];
    const lines = [
      `📊 MetaCasa — ${mes} ${anio}`,
      `─────────────────────`,
      `💰 Ingresos:  $${formatNumber(stats.income)}`,
      `💸 Gastos:    $${formatNumber(stats.expenses)}`,
      `📈 Balance:   ${balance >= 0 ? '+' : ''}$${formatNumber(balance)}`,
      stats.savingsAmount > 0 ? `🐷 Ahorro:    $${formatNumber(stats.savingsAmount)}` : null,
      topCat ? `🏆 Top gasto: ${topCat[0]} ($${formatNumber(topCat[1])})` : null,
      monthlyAvg?.months >= 2 ? `📅 Prom. mensual: $${formatNumber(monthlyAvg.avgBalance)} balance` : null,
      `─────────────────────`,
      `Generado con MetaCasa 🏠`,
    ].filter(Boolean).join('\n');
    if (navigator.share) {
      try { await navigator.share({ title: `MetaCasa — ${mes} ${anio}`, text: lines }); return; } catch {}
    }
    await navigator.clipboard?.writeText(lines);
    toast('Resumen copiado al portapapeles', 'success');
  };

  const deleteTransaction = async (id) => {
    if (!userId) return;
    const { error } = await supabase.from('transactions').delete().eq('id', id);
    if (error) { toast(error.message, 'error'); return; }
    toast('Movimiento eliminado', 'info');
    await loadTransactions();
  };

  // ── BILLS CRUD ──
  const saveBill = async (data) => {
    if (!userId) return;
    const payload = { ...data, user_id: userId };
    let error;
    if (data.id) {
      const { id, user_id, created_at, ...fields } = payload;
      ({ error } = await supabase.from('bills').update(fields).eq('id', data.id));
    } else {
      ({ error } = await supabase.from('bills').insert(payload));
    }
    if (error) { toast(error.message, 'error'); return false; }
    toast(data.id ? 'Vencimiento actualizado' : 'Vencimiento guardado ✓', 'success');
    await loadBills();
    return true;
  };

  const deleteBill = async (id) => {
    const { error } = await supabase.from('bills').delete().eq('id', id);
    if (error) { toast(error.message, 'error'); return; }
    toast('Vencimiento eliminado', 'info');
    await loadBills();
  };

  const markBillPaid = async (bill) => {
    const isPaid = bill.status === 'paid';
    const { error } = await supabase.from('bills').update({ status: isPaid ? 'pending' : 'paid' }).eq('id', bill.id);
    if (error) { toast(error.message, 'error'); return; }
    // Si es recurrente y se marcó como pagado, crear el próximo
    if (!isPaid && bill.recurrence_type) {
      const nextDate = new Date(bill.due_date);
      if (bill.recurrence_type === 'monthly')  nextDate.setMonth(nextDate.getMonth() + 1);
      if (bill.recurrence_type === 'yearly')   nextDate.setFullYear(nextDate.getFullYear() + 1);
      await supabase.from('bills').insert({
        user_id: userId, title: bill.title, amount: bill.amount,
        due_date: nextDate.toISOString().slice(0, 10),
        category: bill.category, status: 'pending',
        recurrence_type: bill.recurrence_type, reminder_days: bill.reminder_days
      });
    }
    toast(isPaid ? 'Marcado como pendiente' : 'Marcado como pagado ✓', 'success');
    await loadBills();
  };

  // Helper emoji
  const getEmoji = useCallback((catName) =>
    catMeta[catName]?.emoji || DEFAULT_EMOJIS[catName] || '📁'
  , [catMeta]);

  const manageCategory = async (action, name, extra) => {
    if (!userId || !name) return;
    let nc = { ...activeCategories };
    if (!nc[type]) nc[type] = [];
    const clean = name.trim();
    if (!clean) return;
    if (action==='ADD') { if (!nc[type].includes(clean)) nc[type]=[...nc[type],clean]; }
    else if (action==='DELETE') nc[type]=nc[type].filter(c=>c!==clean);
    else if (action==='RENAME') {
      const newName = extra?.trim();
      if (!newName || newName === clean) return;
      ['GASTO','INGRESO'].forEach(t => { if (nc[t]) nc[t] = nc[t].map(c => c === clean ? newName : c); });
      await supabase.from('transactions').update({ category: newName }).eq('user_id', userId).eq('category', clean);
      setRenamingCat(null);
    }
    else if (action==='MERGE') {
      // extra = target category name; move all txs from clean → extra, then delete clean
      const target = extra?.trim();
      if (!target || target === clean) return;
      await supabase.from('transactions').update({ category: target }).eq('user_id', userId).eq('category', clean);
      ['GASTO','INGRESO'].forEach(t => { if (nc[t]) nc[t] = nc[t].filter(c => c !== clean); });
      setMergingCat(null);
    }
    // Guardar también catMeta si hay emoji
    let newMeta = { ...catMeta };
    if (action==='EMOJI') { newMeta[clean] = { ...(newMeta[clean]||{}), emoji: extra }; setCatMeta(newMeta); }
    if (action==='RENAME') {
      const newName = extra?.trim();
      if (newName && newMeta[clean]) { newMeta[newName] = newMeta[clean]; delete newMeta[clean]; setCatMeta(newMeta); }
    }
    if (action==='MERGE') { delete newMeta[clean]; setCatMeta(newMeta); }
    const payload = { ...nc, meta: newMeta };
    const { error } = await supabase.from('categories').upsert({ user_id: userId, data: payload },{ onConflict: 'user_id' });
    if (error) { toast(error.message, 'error'); return; }
    setNewCatName("");
    if (action!=='EMOJI') setCustomCats(nc);
    if (action==='RENAME' || action==='MERGE') await loadTransactions();
    toast(action==='ADD'?'Categoría agregada':action==='DELETE'?'Categoría eliminada':action==='RENAME'?'Categoría renombrada':action==='MERGE'?'Categorías fusionadas':'Emoji actualizado', 'success');
  };

  // ── RECURRING CRUD ──
  const saveRecurring = async (data) => {
    if (!userId) return false;
    const payload = { ...data, user_id: userId };
    let error;
    if (data.id) {
      const { id, user_id, created_at, ...fields } = payload;
      ({ error } = await supabase.from('recurring_transactions').update(fields).eq('id', data.id));
    } else {
      ({ error } = await supabase.from('recurring_transactions').insert(payload));
    }
    if (error) { toast(error.message, 'error'); return false; }
    toast(data.id ? 'Recurrente actualizado' : 'Recurrente guardado ✓', 'success');
    await loadRecurring();
    return true;
  };

  const deleteRecurring = async (id) => {
    const { error } = await supabase.from('recurring_transactions').delete().eq('id', id);
    if (error) { toast(error.message, 'error'); return; }
    toast('Recurrente eliminado', 'info');
    await loadRecurring();
  };

  const toggleRecurring = async (rec) => {
    const { error } = await supabase.from('recurring_transactions').update({ active: !rec.active }).eq('id', rec.id);
    if (error) { toast(error.message, 'error'); return; }
    toast(rec.active ? 'Pausado' : 'Activado', 'info');
    await loadRecurring();
  };

  const updateBudget = async (cat, val) => {
    if (!userId) return;
    const { error } = await supabase.from('budgets').upsert({ user_id: userId, category: cat, amount: Number(val||0) },{ onConflict: 'user_id,category' });
    if (error) { toast(error.message,'error'); return; }
    await loadBudgets();
  };

  const exportExcel = (txList, filename = 'MetaCasa_Finanzas.csv') => {
    if (!txList || txList.length===0) { toast('Sin movimientos para exportar','info'); return; }
    const headers = ["Fecha","Tipo","Categoria","Monto","Detalle/Nota"];
    const rows = txList.map(t => [new Date(t.date).toLocaleDateString(), t.type, t.category, formatNumber(t.amount), `"${(t.note||"").replace(/"/g,'""')}"`]);
    const csv = "\uFEFF"+[headers.join(";"),...rows.map(r=>r.join(";"))].join("\n");
    const url = URL.createObjectURL(new Blob([csv],{type:'text/csv;charset=utf-8;'}));
    const a = document.createElement("a"); a.href=url; a.download=filename; a.click();
  };

  // ─────────────────────────────────────────────
  // RENDER: CARGANDO AUTH
  // ─────────────────────────────────────────────
  if (authLoading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <div className="w-14 h-14 rounded-2xl overflow-hidden shadow-xl"><img src={logoMetacasa} alt="MetaCasa" className="w-full h-full object-cover" /></div>
          <div className="flex gap-1.5">{[0,1,2].map(i=><div key={i} className="w-2 h-2 bg-zinc-700 rounded-full animate-bounce" style={{animationDelay:`${i*0.15}s`}} />)}</div>
        </div>
      </div>
    );
  }

  // ─────────────────────────────────────────────
  // RENDER: LOGIN
  // ─────────────────────────────────────────────
  if (!session) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center px-6">
        <GlobalStyles />
        <div className="w-full max-w-md space-y-8">
          <div className="text-center space-y-4">
            <div className="w-20 h-20 rounded-3xl overflow-hidden mx-auto shadow-2xl border border-white/10">
              <img src={logoMetacasa} alt="MetaCasa" className="w-full h-full object-cover" />
            </div>
            <div>
              <h1 className="text-4xl font-black italic uppercase tracking-tighter">MetaCasa</h1>
              <p className="text-sm text-zinc-500 mt-1">Finanzas del hogar</p>
            </div>
          </div>

          <div className="bg-zinc-900/50 rounded-[2rem] p-7 border border-white/5 space-y-5">
            <div className="flex bg-black rounded-2xl p-1.5 border border-white/10">
              {[{key:"LOGIN",label:"Ingresar"},{key:"SIGNUP",label:"Registrarse"}].map(opt=>(
                <button key={opt.key} onClick={()=>setAuthMode(opt.key)}
                  className={`flex-1 py-3 text-sm font-bold rounded-xl transition-all ${authMode===opt.key?'bg-indigo-600 text-white':'text-zinc-500'}`}>
                  {opt.label}
                </button>
              ))}
            </div>
            <input type="email" value={authEmail} onChange={e=>setAuthEmail(e.target.value)} placeholder="Email"
              className="w-full bg-black/60 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-indigo-500/50 transition-colors" />
            <input type="password" value={authPassword} onChange={e=>setAuthPassword(e.target.value)} placeholder="Contraseña"
              className="w-full bg-black/60 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-indigo-500/50 transition-colors" />
            <button onClick={authMode==="LOGIN"?signIn:signUp}
              className="w-full py-5 rounded-2xl font-bold text-sm uppercase tracking-wider bg-indigo-600 active:scale-95 transition-all shadow-lg">
              {authMode==="LOGIN"?"Ingresar":"Crear cuenta"}
            </button>
            {authMode==="SIGNUP"&&<p className="text-xs text-zinc-600 text-center">Revisá spam/promociones si no llega el email de confirmación.</p>}
          </div>
        </div>
      </div>
    );
  }

  // ─────────────────────────────────────────────
  // RENDER: APP
  // ─────────────────────────────────────────────

  // Transacciones del mes actual
  const monthTxs = transactions.filter(t => {
    const d = new Date(t.date);
    return d.getMonth()===currentDate.getMonth() && d.getFullYear()===currentDate.getFullYear();
  });

  // ── Transacciones filtradas para Historial ──
  const filteredTxs = useMemo(() => {
    let base = allMonths ? transactions : monthTxs;

    // Filtro por tipo
    if (filterType !== 'ALL') base = base.filter(t => t.type === filterType);

    // Filtro por categoría
    if (filterCategory) base = base.filter(t => t.category === filterCategory);

    // Filtro por fecha específica (drill-down desde el calendario)
    if (filterDate) base = base.filter(t => t.date === filterDate);

    // Filtro por rango de monto
    if (filterMin !== '') base = base.filter(t => Number(t.amount) >= Number(filterMin));
    if (filterMax !== '') base = base.filter(t => Number(t.amount) <= Number(filterMax));

    // Filtro "Esta semana"
    if (filterWeek) {
      const now = new Date();
      const dow = now.getDay(); // 0=Dom
      const diffToMon = dow === 0 ? 6 : dow - 1; // días hasta el lunes anterior
      const mon = new Date(now); mon.setDate(now.getDate() - diffToMon); mon.setHours(0,0,0,0);
      const monStr = mon.toISOString().slice(0, 10);
      const todayStr2 = now.toISOString().slice(0, 10);
      base = base.filter(t => t.date.slice(0,10) >= monStr && t.date.slice(0,10) <= todayStr2);
    }

    // Filtro por rango de fechas personalizado
    if (filterDateFrom) base = base.filter(t => t.date.slice(0,10) >= filterDateFrom);
    if (filterDateTo)   base = base.filter(t => t.date.slice(0,10) <= filterDateTo);

    // Búsqueda por texto (categoría, nota, monto)
    if (searchQuery.trim()) {
      const q = searchQuery.trim().toLowerCase();
      base = base.filter(t =>
        t.category.toLowerCase().includes(q) ||
        (t.note || '').toLowerCase().includes(q) ||
        String(t.amount).includes(q)
      );
    }

    // Ordenamiento
    return [...base].sort((a, b) => {
      if (sortBy === 'date_desc')   return new Date(b.date) - new Date(a.date);
      if (sortBy === 'date_asc')    return new Date(a.date) - new Date(b.date);
      if (sortBy === 'amount_desc') return Number(b.amount) - Number(a.amount);
      if (sortBy === 'amount_asc')  return Number(a.amount) - Number(b.amount);
      return 0;
    });
  }, [transactions, monthTxs, allMonths, filterType, filterCategory, filterDate, filterMin, filterMax, filterWeek, filterDateFrom, filterDateTo, searchQuery, sortBy]);

  // Categorías disponibles según el filtro de tipo actual
  const filterableCats = useMemo(() => {
    const base = allMonths ? transactions : monthTxs;
    const src = filterType === 'ALL' ? base : base.filter(t => t.type === filterType);
    return [...new Set(src.map(t => t.category))].sort();
  }, [transactions, monthTxs, allMonths, filterType]);

  const hasActiveFilters = searchQuery || filterType !== 'ALL' || filterCategory || filterDate || filterMin !== '' || filterMax !== '' || filterWeek || filterDateFrom || filterDateTo || sortBy !== 'date_desc' || allMonths;

  const clearFilters = () => {
    setSearchQuery(''); setFilterType('ALL'); setFilterCategory('');
    setFilterDate(''); setFilterMin(''); setFilterMax(''); setFilterWeek(false);
    setFilterDateFrom(''); setFilterDateTo(''); setShowRangeFilter(false);
    setSortBy('date_desc'); setAllMonths(false);
  };

  // ── RESUMEN DEL FILTRO (historial) ──
  const filteredIncome  = useMemo(() => filteredTxs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0), [filteredTxs]);
  const filteredExpense = useMemo(() => filteredTxs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0),   [filteredTxs]);
  const filteredBalance = filteredIncome - filteredExpense;

  // ── RECIENTES — últimas 3 categorías usadas (por tipo actual) ──
  const recentCategories = useMemo(() => {
    const seen = new Set();
    const result = [];
    for (const t of [...transactions].sort((a,b) => new Date(b.date) - new Date(a.date))) {
      if (t.type !== type) continue;
      if (seen.has(t.category)) continue;
      seen.add(t.category);
      result.push(t.category);
      if (result.length >= 4) break;
    }
    return result;
  }, [transactions, type]);

  // ── RACHA DE AHORRO ──
  const savingsStreak = useMemo(() => {
    let streak = 0;
    const now = new Date();
    for (let i = 0; i < 24; i++) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const m = d.getMonth(), y = d.getFullYear();
      const mTxs = transactions.filter(t => {
        const td = new Date(t.date);
        return td.getMonth() === m && td.getFullYear() === y;
      });
      if (mTxs.length === 0) { if (i === 0) continue; break; }
      const inc = mTxs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
      const exp = mTxs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0);
      if (inc > exp) { streak++; } else { break; }
    }
    return streak;
  }, [transactions]);

  // ── ÍNDICE DE SALUD FINANCIERA ──
  const healthScore = useMemo(() => {
    if (stats.income === 0 && stats.expenses === 0) return null;
    let score = 0;
    const breakdown = [];

    // 1. Tasa de ahorro (0-35 pts)
    const rate = stats.income > 0 ? ((stats.income - stats.expenses) / stats.income) * 100 : -100;
    const savPts = rate >= 20 ? 35 : rate >= 10 ? 25 : rate >= 5 ? 15 : rate >= 0 ? 5 : 0;
    score += savPts;
    breakdown.push({ label: 'Tasa de ahorro', pts: savPts, max: 35, detail: `${Math.round(rate)}%` });

    // 2. Presupuestos respetados (0-25 pts)
    const budgetItems = activeCategories.GASTO
      .filter(cat => Number(budgets[cat]?.amount || 0) > 0);
    const budgetPts = budgetItems.length > 0 ? (() => {
      const greenCount = budgetItems.filter(cat => {
        const pct = (stats.expenseByCategory[cat] || 0) / Number(budgets[cat].amount);
        return pct < 0.9;
      }).length;
      return Math.round((greenCount / budgetItems.length) * 25);
    })() : 12; // Sin presupuestos: 12 pts (neutral)
    score += budgetPts;
    breakdown.push({ label: 'Presupuestos', pts: budgetPts, max: 25, detail: budgetItems.length > 0 ? `${budgetItems.length} categ.` : 'Sin límites' });

    // 3. Balance positivo este mes (0-15 pts)
    const balPts = stats.income > stats.expenses ? 15 : 0;
    score += balPts;
    breakdown.push({ label: 'Balance del mes', pts: balPts, max: 15, detail: balPts ? 'Positivo ✓' : 'Negativo' });

    // 4. Racha de ahorro (0-15 pts)
    const streakPts = savingsStreak >= 6 ? 15 : savingsStreak >= 3 ? 10 : savingsStreak >= 1 ? 5 : 0;
    score += streakPts;
    breakdown.push({ label: 'Racha', pts: streakPts, max: 15, detail: savingsStreak > 0 ? `${savingsStreak} meses` : 'Sin racha' });

    // 5. Metas activas con progreso (0-10 pts)
    const activeGoals = goals.filter(g => !g.completed && g.current > 0);
    const goalPts = activeGoals.length > 0 ? 10 : goals.length > 0 ? 5 : 0;
    score += goalPts;
    breakdown.push({ label: 'Metas', pts: goalPts, max: 10, detail: goals.length > 0 ? `${goals.length} meta${goals.length!==1?'s':''}` : 'Sin metas' });

    const grade = score >= 90 ? 'A+' : score >= 80 ? 'A' : score >= 70 ? 'B' : score >= 60 ? 'C' : score >= 50 ? 'D' : 'F';
    const color = score >= 80 ? 'text-emerald-400' : score >= 60 ? 'text-indigo-400' : score >= 40 ? 'text-amber-400' : 'text-rose-400';
    const label = score >= 80 ? 'Excelente' : score >= 60 ? 'Buena' : score >= 40 ? 'Regular' : 'Crítica';
    return { score, grade, color, label, breakdown };
  }, [stats, budgets, activeCategories, savingsStreak, goals]);

  // ── COMPARATIVA AÑO ANTERIOR ──
  const yearAgoComparison = useMemo(() => {
    const prevYear = new Date(currentDate.getFullYear() - 1, currentDate.getMonth(), 1);
    const pY = prevYear.getFullYear(), pM = prevYear.getMonth();
    const prevTxs = transactions.filter(t => {
      const d = new Date(t.date);
      return d.getFullYear() === pY && d.getMonth() === pM;
    });
    if (prevTxs.length === 0) return null;
    const prevIncome  = prevTxs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
    const prevExpense = prevTxs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0);
    const curIncome   = stats.income;
    const curExpense  = stats.expenses;
    const incDiff  = curIncome  - prevIncome;
    const expDiff  = curExpense - prevExpense;
    const balCur   = curIncome  - curExpense;
    const balPrev  = prevIncome - prevExpense;
    const balDiff  = balCur - balPrev;
    return { prevIncome, prevExpense, incDiff, expDiff, balDiff, prevYear: pY };
  }, [transactions, currentDate, stats]);

  // ── DRILL-THROUGH A HISTORIAL POR CATEGORÍA ──
  const goToCategory = useCallback((cat, txType = 'GASTO') => {
    setFilterCategory(cat);
    setFilterType(txType);
    setAllMonths(false);
    setFilterDate('');
    setSortBy('date_desc');
    setSearchQuery('');
    setActiveTab('history');
    haptic(10);
  }, []);

  // ── DRILL-THROUGH A HISTORIAL POR FECHA ──
  const goToDate = useCallback((dateStr) => {
    setFilterDate(dateStr);
    setAllMonths(true);       // necesitamos ver todos los meses para que aparezca la fecha
    setFilterType('ALL');
    setFilterCategory('');
    setSortBy('date_desc');
    setSearchQuery('');
    setActiveTab('history');
    haptic(10);
  }, []);

  // ── MEMO MENSUAL ──
  const saveMemo = useCallback((text) => {
    const key = `${currentDate.getFullYear()}-${String(currentDate.getMonth()+1).padStart(2,'0')}`;
    const updated = { ...monthMemos, [key]: text };
    setMonthMemos(updated);
    localStorage.setItem(MEMO_KEY, JSON.stringify(updated));
  }, [currentDate, monthMemos]);

  const currentMemo = useMemo(() => {
    const key = `${currentDate.getFullYear()}-${String(currentDate.getMonth()+1).padStart(2,'0')}`;
    return monthMemos[key] || '';
  }, [monthMemos, currentDate]);

  // ── SPARKLINE ÚLTIMOS 7 DÍAS ──
  const last7DaysData = useMemo(() => {
    return Array.from({ length: 7 }, (_, i) => {
      const d = new Date();
      d.setDate(d.getDate() - (6 - i));
      const dateStr = d.toISOString().slice(0, 10);
      const expense = transactions
        .filter(t => t.date.slice(0, 10) === dateStr && t.type === 'GASTO')
        .reduce((a, c) => a + Number(c.amount), 0);
      const label = i === 6 ? 'Hoy' : i === 5 ? 'Ayer'
        : d.toLocaleDateString('es-AR', { weekday: 'short' }).replace('.','').slice(0,2);
      return { dateStr, expense, label };
    });
  }, [transactions]);

  // ── ESTADÍSTICAS DEL MES ──
  const monthStats = useMemo(() => {
    if (monthTxs.length === 0) return null;
    const dayMap = {};
    monthTxs.forEach(t => {
      const d = t.date.slice(0, 10);
      if (!dayMap[d]) dayMap[d] = { income: 0, expense: 0 };
      if (t.type === 'INGRESO') dayMap[d].income += Number(t.amount);
      if (t.type === 'GASTO')   dayMap[d].expense += Number(t.amount);
    });
    const days = Object.entries(dayMap);
    const activeDays = days.length;
    const daysInMonth = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0).getDate();
    const expDays = days.filter(([, v]) => v.expense > 0).sort(([, a], [, b]) => b.expense - a.expense);
    const maxExpDay = expDays[0] || null;
    const totalExp = monthTxs.filter(t => t.type === 'GASTO').reduce((a, c) => a + Number(c.amount), 0);
    const avgDaily = expDays.length > 0 ? Math.round(totalExp / expDays.length) : 0;
    const noSpendDays = Math.max(0, daysInMonth - expDays.length);
    return {
      activeDays, daysInMonth, avgDaily, noSpendDays,
      maxExpDay: maxExpDay ? { date: maxExpDay[0], amount: maxExpDay[1].expense } : null,
    };
  }, [monthTxs, currentDate]);

  // Resumen año a la fecha (YTD)
  const monthlyAvg = useMemo(() => {
    if (transactions.length === 0) return null;
    const byMonth = {};
    transactions.forEach(t => {
      const key = t.date.slice(0, 7); // YYYY-MM
      if (!byMonth[key]) byMonth[key] = { income: 0, expense: 0 };
      if (t.type === 'INGRESO') byMonth[key].income += Number(t.amount);
      if (t.type === 'GASTO')   byMonth[key].expense += Number(t.amount);
    });
    const months = Object.values(byMonth);
    if (months.length === 0) return null;
    const n = months.length;
    const avgIncome  = Math.round(months.reduce((a, m) => a + m.income, 0)  / n);
    const avgExpense = Math.round(months.reduce((a, m) => a + m.expense, 0) / n);
    const avgBalance = avgIncome - avgExpense;
    return { avgIncome, avgExpense, avgBalance, months: n };
  }, [transactions]);

  const savingsRateData = useMemo(() => {
    if (stats.income === 0) return null;
    const rate = Math.round(((stats.income - stats.expenses) / stats.income) * 100);
    const prevRate = prevMonth.income > 0
      ? Math.round(((prevMonth.income - prevMonth.expense) / prevMonth.income) * 100)
      : null;
    const diff = prevRate !== null ? rate - prevRate : null;
    return { rate, prevRate, diff };
  }, [stats, prevMonth]);

  const catTrends = useMemo(() => {
    if (chartData.length === 0) return null;
    const months3 = [2, 1, 0].map(offset => {
      const d = new Date(currentDate.getFullYear(), currentDate.getMonth() - offset, 1);
      return { year: d.getFullYear(), month: d.getMonth(), label: MONTHS[d.getMonth()].slice(0, 3) };
    });
    const top4 = [...chartData].sort((a, b) => b.spent - a.spent).slice(0, 4);
    return top4.map(cat => ({
      cat: cat.cat,
      color: cat.color,
      amounts: months3.map(m =>
        transactions
          .filter(t => t.type === 'GASTO' && t.category === cat.cat
            && new Date(t.date).getMonth() === m.month
            && new Date(t.date).getFullYear() === m.year)
          .reduce((a, c) => a + Number(c.amount), 0)
      ),
      labels: months3.map(m => m.label),
    }));
  }, [chartData, transactions, currentDate]);

  const yearHeatmap = useMemo(() => {
    const year = currentDate.getFullYear();
    const dayMap = {};
    transactions.forEach(t => {
      if (t.type !== 'GASTO') return;
      const d = new Date(t.date + 'T12:00:00');
      if (d.getFullYear() !== year) return;
      const key = t.date.slice(0, 10);
      dayMap[key] = (dayMap[key] || 0) + Number(t.amount);
    });
    const values = Object.values(dayMap);
    if (values.length === 0) return null;
    const maxVal = Math.max(...values);
    const jan1 = new Date(year, 0, 1);
    const startOffset = jan1.getDay(); // 0=Dom
    const cells = Array.from({ length: 53 * 7 }, (_, i) => {
      const dayNum = i - startOffset;
      if (dayNum < 0) return null;
      const d = new Date(year, 0, 1 + dayNum);
      if (d.getFullYear() !== year) return null;
      const key = d.toISOString().slice(0, 10);
      const val = dayMap[key] || 0;
      const today = new Date().toISOString().slice(0, 10);
      return { key, val, isToday: key === today };
    });
    return { cells, maxVal };
  }, [transactions, currentDate]);

  const yearStats = useMemo(() => {
    const year = currentDate.getFullYear();
    const ytx = transactions.filter(t => new Date(t.date).getFullYear() === year);
    if (ytx.length === 0) return null;
    const income  = ytx.filter(t => t.type==='INGRESO').reduce((a,c) => a+Number(c.amount), 0);
    const expense = ytx.filter(t => t.type==='GASTO').reduce((a,c) => a+Number(c.amount), 0);
    const balance = income - expense;
    const monthData = Array.from({ length: 12 }, (_, m) => {
      const mTxs = ytx.filter(t => new Date(t.date).getMonth() === m);
      const mInc = mTxs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
      const mExp = mTxs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0);
      return { m, balance: mInc - mExp, count: mTxs.length };
    }).filter(r => r.count > 0);
    const posMonths = monthData.filter(r => r.balance >= 0).length;
    const bestMonth = monthData.reduce((best, r) => (!best || r.balance > best.balance) ? r : best, null);
    return { income, expense, balance, posMonths, total: monthData.length, bestMonth };
  }, [transactions, currentDate]);

  // Distribución de gastos por día de la semana (últimos 90 días)
  const weekdaySpending = useMemo(() => {
    const DAYS = ['Dom','Lun','Mar','Mié','Jue','Vie','Sáb'];
    const cutoff = new Date(); cutoff.setDate(cutoff.getDate() - 90);
    const recent = transactions.filter(t => t.type === 'GASTO' && new Date(t.date) >= cutoff);
    if (recent.length === 0) return null;
    const totals = Array(7).fill(0);
    const counts = Array(7).fill(0);
    recent.forEach(t => {
      const dow = new Date(t.date + 'T12:00:00').getDay(); // 0=Dom
      totals[dow] += Number(t.amount);
      counts[dow]++;
    });
    const avgs = totals.map((s, i) => counts[i] > 0 ? Math.round(s / counts[i]) : 0);
    const max = Math.max(...avgs);
    const peakDay = avgs.indexOf(max);
    return { avgs, days: DAYS, max, peakDay };
  }, [transactions]);

  const burnRate = useMemo(() => {
    if (stats.expenses === 0) return null;
    const dayOfMonth = currentDate.getDate();
    const daysInMonth = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0).getDate();
    const daysLeft = daysInMonth - dayOfMonth;
    const dailyRate = dayOfMonth > 0 ? stats.expenses / dayOfMonth : 0;
    const projected = Math.round(dailyRate * daysInMonth);
    const totalBudget = Object.values(budgets).reduce((a, c) => a + (Number(c.amount) || 0), 0);
    const remaining = totalBudget > 0 ? Math.max(0, totalBudget - stats.expenses) : null;
    const safeDaily = (daysLeft > 0 && remaining !== null) ? Math.round(remaining / daysLeft) : null;
    const pct = totalBudget > 0 ? Math.round((projected / totalBudget) * 100) : null;
    return { dailyRate: Math.round(dailyRate), projected, totalBudget, daysLeft, safeDaily, pct, dayOfMonth, daysInMonth };
  }, [stats.expenses, budgets, currentDate]);

  // ── BALANCE SEMANAL (últimos 7 días vs 7 anteriores) ──
  const weekBalance = useMemo(() => {
    const now = new Date();
    const ms7  = 7  * 86400000;
    const ms14 = 14 * 86400000;
    const cur7Start  = new Date(now - ms7);
    const prev7Start = new Date(now - ms14);
    const cur  = transactions.filter(t => { const d = new Date(t.date+'T12:00:00'); return t.type==='GASTO' && d >= cur7Start  && d <= now; }).reduce((a,c)=>a+Number(c.amount),0);
    const prev = transactions.filter(t => { const d = new Date(t.date+'T12:00:00'); return t.type==='GASTO' && d >= prev7Start && d <  cur7Start; }).reduce((a,c)=>a+Number(c.amount),0);
    if (cur === 0 && prev === 0) return null;
    const diff = cur - prev;
    const pct  = prev > 0 ? Math.round((diff / prev) * 100) : null;
    return { cur, prev, diff, pct };
  }, [transactions]);

  // ── GRÁFICO BARRAS 6 MESES (ingresos vs gastos) ──
  const sixMonthBars = useMemo(() => {
    const months = Array.from({ length: 6 }, (_, i) => {
      const d = new Date(currentDate.getFullYear(), currentDate.getMonth() - (5 - i), 1);
      return { year: d.getFullYear(), month: d.getMonth(), label: MONTHS[d.getMonth()].slice(0, 3) };
    });
    const data = months.map(m => {
      const mTxs = transactions.filter(t => {
        const d = new Date(t.date);
        return d.getMonth() === m.month && d.getFullYear() === m.year;
      });
      return {
        label: m.label,
        income:  mTxs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0),
        expense: mTxs.filter(t=>t.type==='GASTO'  ).reduce((a,c)=>a+Number(c.amount),0),
      };
    });
    if (data.every(d => d.income === 0 && d.expense === 0)) return null;
    const maxVal = Math.max(...data.map(d => Math.max(d.income, d.expense)), 1);
    return { data, maxVal };
  }, [transactions, currentDate]);

  // ── PATRIMONIO ACUMULADO (balance mensual acumulado, últimos 12 meses) ──
  const patrimonioData = useMemo(() => {
    if (transactions.length === 0) return null;
    const byMonth = {};
    transactions.forEach(t => {
      const key = t.date.slice(0, 7);
      if (!byMonth[key]) byMonth[key] = { income: 0, expense: 0 };
      if (t.type === 'INGRESO') byMonth[key].income += Number(t.amount);
      if (t.type === 'GASTO')   byMonth[key].expense += Number(t.amount);
    });
    const allMonthsSorted = Object.keys(byMonth).sort();
    if (allMonthsSorted.length < 2) return null;
    // Compute running cumulative balance over ALL history, then take last 12 visible points
    let running = 0;
    const allPoints = allMonthsSorted.map(key => {
      const m = byMonth[key];
      running += (m.income - m.expense);
      const [y, mo] = key.split('-').map(Number);
      return { key, value: running, label: MONTHS[mo - 1].slice(0, 3) + ' ' + String(y).slice(2) };
    });
    const points = allPoints.slice(-12);
    const values = points.map(p => p.value);
    const min = Math.min(...values);
    const max = Math.max(...values);
    const range = max - min || 1;
    const W = 280, H = 60, PAD = 4;
    const toX = (i) => PAD + (i / (points.length - 1)) * (W - PAD * 2);
    const toY = (v) => H - PAD - ((v - min) / range) * (H - PAD * 2);
    const pathD = points.map((p, i) => `${i === 0 ? 'M' : 'L'}${toX(i).toFixed(1)},${toY(p.value).toFixed(1)}`).join(' ');
    const areaD = pathD + ` L${toX(points.length-1).toFixed(1)},${H} L${toX(0).toFixed(1)},${H} Z`;
    const trend = points.length >= 2 ? points[points.length-1].value - points[0].value : 0;
    const lastVal = points[points.length - 1].value;
    return { points, pathD, areaD, min, max, W, H, trend, lastVal };
  }, [transactions]);

  // ── BILLS helpers ──
  const today = new Date(); today.setHours(0,0,0,0);
  const billsDue = useMemo(() => {
    const pending = bills.filter(b => b.status === 'pending');
    return {
      overdue:  pending.filter(b => new Date(b.due_date) < today),
      today:    pending.filter(b => new Date(b.due_date).toDateString() === today.toDateString()),
      soon:     pending.filter(b => { const d = new Date(b.due_date); return d > today && (d - today) <= 3*86400000; }),
      upcoming: pending.filter(b => { const d = new Date(b.due_date); return d > today && (d - today) > 3*86400000 && (d - today) <= 30*86400000; }),
    };
  }, [bills]);
  const urgentCount = billsDue.overdue.length + billsDue.today.length + billsDue.soon.length;

  const billDaysLabel = (due_date) => {
    const d = new Date(due_date); d.setHours(0,0,0,0);
    const diff = Math.round((d - today) / 86400000);
    if (diff < 0)  return { label: `Vencido hace ${Math.abs(diff)}d`, color: 'text-rose-400' };
    if (diff === 0) return { label: 'Vence hoy', color: 'text-amber-400' };
    if (diff <= 3) return { label: `En ${diff}d`, color: 'text-amber-400' };
    return { label: `En ${diff}d`, color: 'text-zinc-500' };
  };

  // ── CATEGORÍAS FRECUENTES (últimos 30 días, por tipo) ──
  const frecuentesCats = useMemo(() => {
    const cutoff = new Date(); cutoff.setDate(cutoff.getDate() - 30);
    const freq = {};
    transactions.forEach(t => {
      if (new Date(t.date + 'T12:00:00') < cutoff) return;
      const key = `${t.type}::${t.category}`;
      freq[key] = (freq[key] || 0) + 1;
    });
    const top = (type) => Object.entries(freq)
      .filter(([k]) => k.startsWith(type + '::'))
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([k]) => k.split('::')[1]);
    return { GASTO: top('GASTO'), INGRESO: top('INGRESO') };
  }, [transactions]);

  // ── GASTO DE HOY ──
  const gastosHoy = useMemo(() => {
    const todayStr = new Date().toISOString().slice(0, 10);
    const hoy = transactions.filter(t => t.date.slice(0, 10) === todayStr);
    const income  = hoy.filter(t => t.type === 'INGRESO').reduce((a, c) => a + Number(c.amount), 0);
    const expense = hoy.filter(t => t.type === 'GASTO').reduce((a, c) => a + Number(c.amount), 0);
    const count   = hoy.length;
    return count > 0 ? { income, expense, count } : null;
  }, [transactions]);

  // ── SEMÁFORO DE PRESUPUESTOS ──
  const budgetSemaforo = useMemo(() => {
    const items = activeCategories.GASTO
      .map(cat => {
        const limit = Number(budgets[cat]?.amount || 0);
        if (limit <= 0) return null;
        const spent = stats.expenseByCategory[cat] || 0;
        const pct = Math.round((spent / limit) * 100);
        const color = pct >= 100 ? 'red' : pct >= 80 ? 'amber' : 'green';
        return { cat, spent, limit, pct, color };
      })
      .filter(Boolean);
    return items.length > 0 ? items : null;
  }, [activeCategories, budgets, stats]);

  // ── FIN DE SEMANA VS DÍAS LABORABLES (últimos 30 días) ──
  const weekendAnalysis = useMemo(() => {
    const cutoff = new Date(); cutoff.setDate(cutoff.getDate() - 30);
    let weekday = 0, weekend = 0, wdCount = 0, weCount = 0;
    transactions.forEach(t => {
      if (t.type !== 'GASTO') return;
      const d = new Date(t.date + 'T12:00:00');
      if (d < cutoff) return;
      const dow = d.getDay(); // 0=Dom, 6=Sáb
      if (dow === 0 || dow === 6) { weekend += Number(t.amount); weCount++; }
      else { weekday += Number(t.amount); wdCount++; }
    });
    if (weekday === 0 && weekend === 0) return null;
    const total = weekday + weekend;
    const wdPct = total > 0 ? Math.round((weekday / total) * 100) : 0;
    const wePct = 100 - wdPct;
    return { weekday, weekend, wdCount, weCount, wdPct, wePct };
  }, [transactions]);

  // Donut data
  const chartData = activeCategories.GASTO
    .map((cat,i)=>({cat,spent:stats.expenseByCategory[cat]||0,color:CHART_COLORS[i%CHART_COLORS.length]}))
    .filter(d=>d.spent>0);
  const totalSpent = chartData.reduce((s,d)=>s+d.spent,0);
  const { slices } = DonutChart({ data: chartData, total: totalSpent });

  return (
    <div className="min-h-screen bg-black text-white font-sans overflow-x-hidden">
      <GlobalStyles />

      {/* ── TAB CONTENT ── */}
      <div className="max-w-md mx-auto pb-28">

        {/* ════════════════════════════════
            TAB: INICIO (Dashboard)
        ════════════════════════════════ */}
        {activeTab==='home' && (
          <div className="px-5 pt-5 space-y-5">
            {/* Header */}
            <header className="flex justify-between items-center">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl overflow-hidden border border-white/10">
                  <img src={logoMetacasa} alt="MetaCasa" className="w-full h-full object-cover" />
                </div>
                <div>
                  <h1 className="text-lg font-black italic uppercase tracking-tight leading-none">MetaCasa</h1>
                  <button onClick={()=>setShowDatePicker(true)}
                    className="flex items-center gap-1 text-xs font-semibold text-indigo-400 mt-0.5 active:opacity-60">
                    <Calendar className="w-3 h-3" />
                    {MONTHS[currentDate.getMonth()]} {currentDate.getFullYear()}
                  </button>
                </div>
              </div>
              <div className="flex gap-2">
                <button onClick={togglePrivacy} className={`p-2.5 rounded-xl active:scale-90 transition-transform ${privacyMode ? 'bg-amber-500/20' : 'bg-zinc-900'}`} title={privacyMode ? 'Mostrar montos' : 'Ocultar montos'}>
                  {privacyMode ? <EyeOff className="w-5 h-5 text-amber-400"/> : <Eye className="w-5 h-5 text-zinc-400"/>}
                </button>
                <button onClick={handleQuickShare} className="p-2.5 bg-zinc-900 rounded-xl active:scale-90 transition-transform" title="Compartir resumen">
                  <Share2 className="w-5 h-5 text-indigo-400" />
                </button>
                <button onClick={signOut} className="p-2.5 bg-zinc-900 rounded-xl active:scale-90 transition-transform" title="Cerrar sesión">
                  <LogOut className="w-5 h-5 text-zinc-400" />
                </button>
              </div>
            </header>

            {/* Balance Card */}
            {loadingData ? <LoadingSkeleton /> : (
              <>
                <div className="space-y-3">
                  <div className="flex items-center justify-between px-1">
                    <button onClick={()=>changeMonth(-1)} className="p-2 bg-zinc-900/70 rounded-full text-zinc-500 active:scale-90 transition-transform">
                      <ChevronLeft className="w-5 h-5" />
                    </button>
                    <span className="text-xs font-semibold text-zinc-600 uppercase tracking-wider">Balance del período</span>
                    <button onClick={()=>changeMonth(1)} className="p-2 bg-zinc-900/70 rounded-full text-zinc-500 active:scale-90 transition-transform">
                      <ChevronRight className="w-5 h-5" />
                    </button>
                  </div>

                  <div className="bg-gradient-to-br from-indigo-600 to-indigo-900 rounded-[2rem] p-7 shadow-2xl relative overflow-hidden">
                    <div className="relative z-10">
                      <p className="text-xs font-semibold text-indigo-200/60 uppercase tracking-wider">Saldo disponible</p>
                      {privacyMode
                        ? <p className="text-5xl font-black text-white tracking-tight my-1">••••</p>
                        : <SharedSizeText value={stats.available} fontSizeClass="text-5xl" />
                      }
                      {!privacyMode && exchangeRate > 0 && (
                        <p className="text-sm font-bold text-indigo-300/70 -mt-3">
                          ≈ USD {formatNumber(Math.round(stats.available / exchangeRate))}
                        </p>
                      )}
                      <div className="mt-6 pt-5 border-t border-white/10 grid grid-cols-2 gap-3">
                        <div className="bg-white/8 rounded-2xl p-4">
                          <span className="flex items-center gap-1 text-xs font-semibold text-emerald-300 mb-1.5">
                            <ArrowUpRight className="w-3.5 h-3.5" /> Ingresos
                          </span>
                          <p className="text-xl font-black tracking-tight">${priv(formatNumber(stats.income))}</p>
                        </div>
                        <div className="bg-white/8 rounded-2xl p-4">
                          <span className="flex items-center gap-1 text-xs font-semibold text-rose-300 mb-1.5">
                            <ArrowDownLeft className="w-3.5 h-3.5" /> Gastos
                          </span>
                          <p className="text-xl font-black tracking-tight">${priv(formatNumber(stats.expenses))}</p>
                        </div>
                        {cuotasMonthly > 0 && (
                          <div className="col-span-2 bg-amber-500/10 rounded-2xl p-3 flex justify-between items-center">
                            <span className="flex items-center gap-1.5 text-xs font-semibold text-amber-300">
                              <Wallet className="w-3.5 h-3.5"/> Cuotas del mes
                            </span>
                            <span className="text-sm font-black text-amber-300">${priv(formatNumber(cuotasMonthly))}</span>
                          </div>
                        )}
                      </div>
                    </div>
                    <div className="absolute top-0 right-0 w-48 h-48 bg-white/10 rounded-full blur-[80px] -mr-20 -mt-20" />
                  </div>
                </div>

                {/* ── Plan del mes ── */}
                {(planMes.targetIncome > 0 || planMes.targetExpense > 0 || showPlanEditor) ? (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5 space-y-3">
                    <div className="flex justify-between items-center">
                      <p className="text-sm font-bold text-zinc-300">Plan de {MONTHS[currentDate.getMonth()]}</p>
                      <button onClick={() => setShowPlanEditor(v=>!v)} className="text-[10px] font-bold text-indigo-400 active:opacity-60">
                        {showPlanEditor ? 'Cerrar' : 'Editar →'}
                      </button>
                    </div>
                    {showPlanEditor ? (
                      <PlanEditor planMes={planMes} onSave={savePlanMes} onCancel={()=>setShowPlanEditor(false)}/>
                    ) : (
                      <div className="space-y-2.5">
                        {planMes.targetIncome > 0 && (
                          <div>
                            <div className="flex justify-between text-xs mb-1">
                              <span className="text-zinc-500 font-semibold">Ingreso meta</span>
                              <span className="font-black text-emerald-400">${priv(formatNumber(stats.income))} / ${formatNumber(planMes.targetIncome)}</span>
                            </div>
                            <div className="h-2 bg-black/40 rounded-full overflow-hidden">
                              <div className="h-full rounded-full bg-emerald-500 transition-all duration-700"
                                style={{width:`${Math.min(100,Math.round((stats.income/planMes.targetIncome)*100))}%`}}/>
                            </div>
                          </div>
                        )}
                        {planMes.targetExpense > 0 && (
                          <div>
                            <div className="flex justify-between text-xs mb-1">
                              <span className="text-zinc-500 font-semibold">Gasto límite</span>
                              <span className={`font-black ${stats.expenses > planMes.targetExpense ? 'text-rose-400' : 'text-indigo-400'}`}>
                                ${priv(formatNumber(stats.expenses))} / ${formatNumber(planMes.targetExpense)}
                              </span>
                            </div>
                            <div className="h-2 bg-black/40 rounded-full overflow-hidden">
                              <div className={`h-full rounded-full transition-all duration-700 ${stats.expenses > planMes.targetExpense ? 'bg-rose-500' : 'bg-indigo-500'}`}
                                style={{width:`${Math.min(100,Math.round((stats.expenses/planMes.targetExpense)*100))}%`}}/>
                            </div>
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                ) : (
                  <button onClick={() => setShowPlanEditor(true)}
                    className="w-full py-3 bg-zinc-900/20 border border-dashed border-white/10 rounded-[1.5rem] text-xs font-bold text-zinc-600 active:text-zinc-400 active:border-white/20 transition-all flex items-center justify-center gap-2">
                    <span>📋</span> Establecer plan para {MONTHS[currentDate.getMonth()]}
                  </button>
                )}

                {/* ── Gasto de hoy ── */}
                {gastosHoy && (
                  <button onClick={() => { goToDate(new Date().toISOString().slice(0,10)); setActiveTab('history'); }}
                    className="w-full bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-4 flex items-center gap-4 active:bg-zinc-900/70 transition-colors">
                    <div className="w-10 h-10 bg-indigo-600/15 rounded-xl flex items-center justify-center flex-shrink-0">
                      <span className="text-lg leading-none">📅</span>
                    </div>
                    <div className="flex-1 text-left">
                      <p className="text-xs font-bold text-zinc-400">Hoy — {new Date().toLocaleDateString('es-AR',{weekday:'long',day:'numeric',month:'short'})}</p>
                      <p className="text-xs text-zinc-600 mt-0.5">{gastosHoy.count} movimiento{gastosHoy.count!==1?'s':''}</p>
                    </div>
                    <div className="text-right flex-shrink-0">
                      {gastosHoy.expense > 0 && <p className="text-sm font-black text-rose-300">−${priv(formatNumber(gastosHoy.expense))}</p>}
                      {gastosHoy.income  > 0 && <p className="text-sm font-black text-emerald-400">+${priv(formatNumber(gastosHoy.income))}</p>}
                    </div>
                  </button>
                )}

                {/* Resumen Ahorro/Inversión */}
                {(strategy.savingsPercent > 0 || strategy.investmentPercent > 0) && (
                  <div className="grid grid-cols-2 gap-3">
                    {strategy.savingsPercent>0 && (
                      <div className="bg-zinc-900/60 rounded-2xl p-4 border border-white/5">
                        <p className="text-xs text-emerald-400 font-semibold flex items-center gap-1 mb-1"><PiggyBank className="w-3.5 h-3.5"/>Ahorro</p>
                        <p className="text-lg font-black">${formatNumber(stats.savingsAmount)}</p>
                        <p className="text-xs text-zinc-600">{strategy.savingsPercent}% ingresos</p>
                      </div>
                    )}
                    {strategy.investmentPercent>0 && (
                      <div className="bg-zinc-900/60 rounded-2xl p-4 border border-white/5">
                        <p className="text-xs text-indigo-400 font-semibold flex items-center gap-1 mb-1"><TrendingUp className="w-3.5 h-3.5"/>Inversión</p>
                        <p className="text-lg font-black">${formatNumber(stats.investmentAmount)}</p>
                        <p className="text-xs text-zinc-600">{strategy.investmentPercent}% ingresos</p>
                      </div>
                    )}
                  </div>
                )}

                {/* Distribución de gastos — donut + leyenda interactiva */}
                {chartData.length > 0 && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-4">
                      <p className="text-sm font-bold text-zinc-300">Distribución de gastos</p>
                      <button onClick={()=>{ setShowBudgetModal(true); setBudgetChartView(true); }}
                        className="text-xs text-indigo-400 font-semibold">
                        Ver detalle →
                      </button>
                    </div>
                    <div className="flex items-center gap-4">
                      {/* Donut SVG */}
                      <div className="relative flex-shrink-0 w-[108px] h-[108px]">
                        <svg viewBox="0 0 200 200" className="w-full h-full -rotate-90">
                          {slices.map((s, i) => <path key={i} d={s.path} fill={s.color}/>)}
                        </svg>
                        <div className="absolute inset-0 flex items-center justify-center">
                          <div className="text-center">
                            <p className="text-base font-black text-white leading-tight">${formatNumber(totalSpent)}</p>
                            <p className="text-[9px] text-zinc-600 mt-0.5">gastos</p>
                          </div>
                        </div>
                      </div>
                      {/* Leyenda clickeable */}
                      <div className="flex-1 space-y-2">
                        {[...chartData].sort((a,b)=>b.spent-a.spent).slice(0,5).map((d,i)=>(
                          <button key={i} onClick={()=>goToCategory(d.cat,'GASTO')}
                            className="w-full flex items-center gap-2 active:opacity-60 transition-opacity">
                            <div className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{backgroundColor:d.color}}/>
                            <span className="text-xs text-zinc-300 truncate flex-1 text-left">{d.cat}</span>
                            <span className="text-[11px] font-black text-zinc-400">
                              {totalSpent>0?Math.round((d.spent/totalSpent)*100):0}%
                            </span>
                          </button>
                        ))}
                      </div>
                    </div>
                  </div>
                )}

                {/* Insights dinámicos */}
                {insights.length > 0 && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 flex items-center gap-2 mb-3">
                      <Lightbulb className="w-4 h-4 text-amber-400"/> Insights
                    </p>
                    <div className="space-y-2.5">
                      {insights.map((ins, i) => (
                        <div key={i} className="flex items-center gap-3">
                          <span className="text-lg leading-none flex-shrink-0">{ins.emoji}</span>
                          <span className={`text-xs font-semibold ${ins.color}`}>{ins.text}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Calendario de gastos del mes */}
                {monthTxs.filter(t=>t.type==='GASTO').length > 0 && (
                  <SpendingCalendar
                    transactions={transactions}
                    year={currentDate.getFullYear()}
                    month={currentDate.getMonth()}
                    onDayPress={goToDate}
                  />
                )}

                {/* Sparkline — últimos 7 días de gasto */}
                {last7DaysData.some(d => d.expense > 0) && (() => {
                  const maxD = Math.max(...last7DaysData.map(d => d.expense));
                  return (
                    <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                      <p className="text-sm font-bold text-zinc-300 mb-4 flex items-center gap-2">
                        <TrendingUp className="w-4 h-4 text-rose-400"/> Últimos 7 días
                      </p>
                      <div className="flex items-end gap-1.5 h-14">
                        {last7DaysData.map((d, i) => {
                          const barH = maxD > 0 ? Math.max(3, Math.round((d.expense / maxD) * 48)) : 3;
                          const isToday = i === 6;
                          return (
                            <button key={d.dateStr}
                              onClick={() => d.expense > 0 && goToDate(d.dateStr)}
                              disabled={d.expense === 0}
                              className="flex-1 flex flex-col items-center gap-1 group">
                              <div
                                className={`w-full rounded-t-md transition-all group-active:opacity-70
                                  ${isToday ? 'bg-indigo-500' : d.expense > 0 ? 'bg-rose-500/55' : 'bg-zinc-800/50'}`}
                                style={{ height: `${barH}px` }}
                              />
                              <span className={`text-[9px] font-bold leading-none
                                ${isToday ? 'text-indigo-400' : d.expense > 0 ? 'text-zinc-500' : 'text-zinc-800'}`}>
                                {d.label}
                              </span>
                            </button>
                          );
                        })}
                      </div>
                    </div>
                  );
                })()}

                {/* Este mes en números */}
                {monthStats && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-3">Este mes en números</p>
                    <div className="grid grid-cols-2 gap-2.5">
                      <div className="bg-black/30 rounded-2xl p-3.5">
                        <p className="text-[10px] text-zinc-600 mb-1">Días activos</p>
                        <p className="text-xl font-black text-white">
                          {monthStats.activeDays}
                          <span className="text-xs font-semibold text-zinc-600 ml-1">/ {monthStats.daysInMonth}</span>
                        </p>
                      </div>
                      <div className="bg-black/30 rounded-2xl p-3.5">
                        <p className="text-[10px] text-zinc-600 mb-1">Días sin gastos</p>
                        <p className="text-xl font-black text-emerald-400">
                          {monthStats.noSpendDays}
                          <span className="text-xs font-semibold text-zinc-600 ml-1">días</span>
                        </p>
                      </div>
                      <div className="bg-black/30 rounded-2xl p-3.5">
                        <p className="text-[10px] text-zinc-600 mb-1">Promedio por día</p>
                        <p className="text-base font-black text-white">${formatNumber(monthStats.avgDaily)}</p>
                      </div>
                      {monthStats.maxExpDay && (
                        <button onClick={() => goToDate(monthStats.maxExpDay.date)}
                          className="bg-black/30 rounded-2xl p-3.5 text-left active:scale-[0.97] transition-transform">
                          <p className="text-[10px] text-zinc-600 mb-1">Mayor gasto</p>
                          <p className="text-base font-black text-rose-400">${formatNumber(monthStats.maxExpDay.amount)}</p>
                          <p className="text-[9px] text-zinc-700 mt-0.5">
                            {new Date(monthStats.maxExpDay.date + 'T12:00:00')
                              .toLocaleDateString('es-AR', { day: 'numeric', month: 'short' })}
                          </p>
                        </button>
                      )}
                    </div>
                  </div>
                )}

                {/* Tasa de ahorro */}
                {savingsRateData && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex items-center gap-5">
                      {/* Arc SVG */}
                      <div className="relative flex-shrink-0 w-[88px] h-[88px]">
                        <svg viewBox="0 0 100 100" className="w-full h-full -rotate-90">
                          <circle cx="50" cy="50" r="38" fill="none" stroke="#27272a" strokeWidth="10"/>
                          <circle cx="50" cy="50" r="38" fill="none"
                            stroke={savingsRateData.rate >= 20 ? '#10b981' : savingsRateData.rate >= 0 ? '#f59e0b' : '#f43f5e'}
                            strokeWidth="10" strokeLinecap="round"
                            strokeDasharray={`${Math.max(0, Math.min(100, savingsRateData.rate)) * 2.39} 239`}/>
                        </svg>
                        <div className="absolute inset-0 flex items-center justify-center">
                          <p className={`text-lg font-black leading-none ${savingsRateData.rate >= 20 ? 'text-emerald-400' : savingsRateData.rate >= 0 ? 'text-amber-400' : 'text-rose-400'}`}>
                            {savingsRateData.rate}%
                          </p>
                        </div>
                      </div>
                      <div className="flex-1">
                        <p className="text-sm font-bold text-zinc-300 mb-1">Tasa de ahorro</p>
                        <p className="text-xs text-zinc-500 mb-2">
                          {savingsRateData.rate >= 20 ? '🟢 Excelente' : savingsRateData.rate >= 10 ? '🟡 Buena' : savingsRateData.rate >= 0 ? '🟠 Ajustada' : '🔴 Déficit'}
                        </p>
                        {savingsRateData.diff !== null && (
                          <span className={`text-[11px] font-black px-2 py-1 rounded-full ${savingsRateData.diff > 0 ? 'bg-emerald-500/15 text-emerald-400' : savingsRateData.diff < 0 ? 'bg-rose-500/15 text-rose-400' : 'bg-zinc-800 text-zinc-500'}`}>
                            {savingsRateData.diff > 0 ? '▲' : savingsRateData.diff < 0 ? '▼' : '='} {Math.abs(savingsRateData.diff)}pp vs mes ant.
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                )}

                {/* ── Semáforo de presupuestos ── */}
                {budgetSemaforo && (
                  <button onClick={() => setShowBudgetModal(true)} className="w-full text-left">
                    <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                      <div className="flex justify-between items-center mb-3">
                        <p className="text-sm font-bold text-zinc-300">Presupuestos por categoría</p>
                        <span className="text-[10px] text-zinc-600 font-semibold">Ver detalle →</span>
                      </div>
                      <div className="space-y-2">
                        {budgetSemaforo.map(({ cat, pct, color, spent, limit }) => (
                          <div key={cat} className="flex items-center gap-3">
                            <span className="text-sm leading-none w-5 flex-shrink-0">{getEmoji(cat)}</span>
                            <span className="text-xs text-zinc-400 font-semibold w-20 truncate flex-shrink-0">{cat}</span>
                            <div className="flex-1 h-1.5 bg-black/40 rounded-full overflow-hidden">
                              <div className="h-full rounded-full transition-all duration-500"
                                style={{
                                  width: `${Math.min(100, pct)}%`,
                                  backgroundColor: color==='red'?'#f43f5e':color==='amber'?'#f59e0b':'#10b981'
                                }}/>
                            </div>
                            <span className={`text-[10px] font-black w-8 text-right flex-shrink-0 ${color==='red'?'text-rose-400':color==='amber'?'text-amber-400':'text-emerald-400'}`}>
                              {pct}%
                            </span>
                          </div>
                        ))}
                      </div>
                    </div>
                  </button>
                )}

                {/* Barra de presupuesto global */}
                {stats.totalBudgetsAssigned > 0 && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    {(() => {
                      const spent = stats.expenses;
                      const total = stats.totalBudgetsAssigned;
                      const pct = Math.round((spent / total) * 100);
                      const isOver = spent > total;
                      const barColor = isOver ? '#f43f5e' : pct >= 90 ? '#f59e0b' : pct >= 70 ? '#6366f1' : '#10b981';
                      return (
                        <>
                          <div className="flex justify-between items-center mb-2">
                            <p className="text-sm font-bold text-zinc-300">Presupuesto mensual</p>
                            <span className={`text-[10px] font-black px-2 py-1 rounded-full ${isOver ? 'bg-rose-500/15 text-rose-400' : pct >= 90 ? 'bg-amber-500/15 text-amber-400' : 'bg-emerald-500/15 text-emerald-400'}`}>
                              {pct}%
                            </span>
                          </div>
                          <div className="h-2.5 bg-black/40 rounded-full overflow-hidden mb-2">
                            <div className="h-full rounded-full transition-all duration-700"
                              style={{ width: `${Math.min(100, pct)}%`, backgroundColor: barColor }}/>
                          </div>
                          <div className="flex justify-between text-xs">
                            <span className="text-zinc-400 font-bold">${formatNumber(spent)}</span>
                            <span className="text-zinc-600">de ${formatNumber(total)}</span>
                          </div>
                          {isOver && (
                            <p className="text-[10px] text-rose-400 font-semibold mt-1.5">
                              Excediste el presupuesto en ${formatNumber(spent - total)}
                            </p>
                          )}
                        </>
                      );
                    })()}
                  </div>
                )}

                {/* Tendencia de categorías */}
                {catTrends && catTrends.length > 0 && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-4">Top categorías · 3 meses</p>
                    <div className="space-y-3.5">
                      {catTrends.map(c => {
                        const maxAmt = Math.max(...c.amounts, 1);
                        return (
                          <button key={c.cat} onClick={() => goToCategory(c.cat, 'GASTO')}
                            className="w-full flex items-center gap-3 active:opacity-60 transition-opacity">
                            <div className="w-2 h-2 rounded-full flex-shrink-0" style={{ backgroundColor: c.color }}/>
                            <span className="text-xs text-zinc-400 w-[72px] truncate text-left">{c.cat}</span>
                            <div className="flex-1 flex items-end gap-1" style={{ height: '28px' }}>
                              {c.amounts.map((amt, i) => (
                                <div key={i} className="flex-1 flex flex-col items-center gap-0.5">
                                  <div className="w-full rounded-sm"
                                    style={{
                                      height: `${Math.max((amt / maxAmt) * 22, amt > 0 ? 3 : 0)}px`,
                                      backgroundColor: c.color,
                                      opacity: 0.35 + i * 0.3,
                                    }}/>
                                </div>
                              ))}
                            </div>
                            <div className="text-right">
                              <p className="text-xs font-black text-zinc-300">${formatNumber(c.amounts[2])}</p>
                              <p className="text-[9px] text-zinc-700">{c.labels[2]}</p>
                            </div>
                          </button>
                        );
                      })}
                    </div>
                    <div className="flex justify-between mt-3 pt-2 border-t border-white/5">
                      {catTrends[0]?.labels.map((l, i) => (
                        <span key={i} className="text-[9px] text-zinc-700 flex-1 text-center">{l}</span>
                      ))}
                    </div>
                  </div>
                )}

                {/* Gasto por día de semana */}
                {weekdaySpending && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-4">
                      <p className="text-sm font-bold text-zinc-300">¿Cuándo gastás más?</p>
                      <span className="text-[10px] font-bold text-zinc-600">últimos 90 días</span>
                    </div>
                    <div className="flex items-end gap-1.5 h-16">
                      {weekdaySpending.avgs.map((avg, i) => {
                        const pct = weekdaySpending.max > 0 ? (avg / weekdaySpending.max) * 100 : 0;
                        const isPeak = i === weekdaySpending.peakDay;
                        return (
                          <div key={i} className="flex-1 flex flex-col items-center gap-1">
                            <div className="w-full flex items-end" style={{ height: '44px' }}>
                              <div
                                className={`w-full rounded-t-lg transition-all ${isPeak ? 'bg-rose-500' : 'bg-zinc-700'}`}
                                style={{ height: `${Math.max(pct, 4)}%` }}
                              />
                            </div>
                            <span className={`text-[9px] font-bold ${isPeak ? 'text-rose-400' : 'text-zinc-600'}`}>
                              {weekdaySpending.days[i]}
                            </span>
                          </div>
                        );
                      })}
                    </div>
                    <p className="text-[10px] text-zinc-600 mt-3 text-center">
                      Pico: <span className="text-rose-400 font-bold">{weekdaySpending.days[weekdaySpending.peakDay]}</span>
                      {' · '}prom. ${formatNumber(weekdaySpending.avgs[weekdaySpending.peakDay])}/movimiento
                    </p>
                  </div>
                )}

                {/* Promedio mensual histórico */}
                {monthlyAvg && monthlyAvg.months >= 2 && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">Promedio mensual</p>
                      <span className="text-[10px] text-zinc-600 font-semibold">{monthlyAvg.months} meses de datos</span>
                    </div>
                    <div className="grid grid-cols-3 gap-2">
                      <div className="bg-black/30 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-600 font-semibold mb-1">Ingresos</p>
                        <p className="text-sm font-black text-emerald-400">${formatNumber(monthlyAvg.avgIncome)}</p>
                      </div>
                      <div className="bg-black/30 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-600 font-semibold mb-1">Gastos</p>
                        <p className="text-sm font-black text-rose-400">${formatNumber(monthlyAvg.avgExpense)}</p>
                      </div>
                      <div className="bg-black/30 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-600 font-semibold mb-1">Balance</p>
                        <p className={`text-sm font-black ${monthlyAvg.avgBalance >= 0 ? 'text-indigo-300' : 'text-rose-400'}`}>
                          {monthlyAvg.avgBalance >= 0 ? '+' : ''}${formatNumber(Math.abs(monthlyAvg.avgBalance))}
                        </p>
                      </div>
                    </div>
                  </div>
                )}

                {/* Resumen anual (YTD) */}
                {yearStats && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">{currentDate.getFullYear()} hasta hoy</p>
                      <button onClick={() => setShowAnnualModal(true)}
                        className="text-[10px] font-bold text-indigo-400 active:opacity-60">
                        Ver completo →
                      </button>
                    </div>
                    <div className="grid grid-cols-3 gap-2 mb-3">
                      <div className="bg-black/30 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-600 font-semibold mb-1">Ingresos</p>
                        <p className="text-sm font-black text-emerald-400">${formatNumber(yearStats.income)}</p>
                      </div>
                      <div className="bg-black/30 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-600 font-semibold mb-1">Gastos</p>
                        <p className="text-sm font-black text-rose-400">${formatNumber(yearStats.expense)}</p>
                      </div>
                      <div className="bg-black/30 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-600 font-semibold mb-1">Balance</p>
                        <p className={`text-sm font-black ${yearStats.balance >= 0 ? 'text-indigo-300' : 'text-rose-400'}`}>
                          {yearStats.balance >= 0 ? '+' : ''}{formatNumber(yearStats.balance) === '0' ? '$0' : `$${formatNumber(Math.abs(yearStats.balance))}`}
                        </p>
                      </div>
                    </div>
                    <div className="flex items-center justify-between text-[10px] text-zinc-600">
                      <span>
                        <span className="text-emerald-400 font-bold">{yearStats.posMonths}</span>/{yearStats.total} meses positivos
                      </span>
                      {yearStats.bestMonth && (
                        <span>
                          Mejor: <span className="text-zinc-400 font-bold">{MONTHS[yearStats.bestMonth.m]}</span>
                        </span>
                      )}
                    </div>
                  </div>
                )}

                {/* ── Comparativa año anterior ── */}
                {yearAgoComparison && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-3">
                      vs {MONTHS[currentDate.getMonth()]} {yearAgoComparison.prevYear}
                    </p>
                    <div className="grid grid-cols-3 gap-2">
                      {[
                        { label:'Ingresos', diff: yearAgoComparison.incDiff,  positive: yearAgoComparison.incDiff >= 0 },
                        { label:'Gastos',   diff: yearAgoComparison.expDiff,  positive: yearAgoComparison.expDiff <= 0 },
                        { label:'Balance',  diff: yearAgoComparison.balDiff,  positive: yearAgoComparison.balDiff >= 0 },
                      ].map(({ label, diff, positive }) => (
                        <div key={label} className="bg-black/30 rounded-xl p-3 text-center">
                          <p className="text-[10px] text-zinc-600 font-semibold mb-1">{label}</p>
                          <p className={`text-xs font-black ${positive ? 'text-emerald-400' : 'text-rose-400'}`}>
                            {diff >= 0 ? '▲' : '▼'} ${priv(formatNumber(Math.abs(diff)))}
                          </p>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* ── Índice de salud financiera ── */}
                {healthScore && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex items-center justify-between mb-4">
                      <p className="text-sm font-bold text-zinc-300">Salud financiera</p>
                      <span className={`text-2xl font-black ${healthScore.color}`}>{healthScore.grade}</span>
                    </div>
                    <div className="flex items-center gap-4 mb-4">
                      <div className="relative w-16 h-16 flex-shrink-0">
                        <svg viewBox="0 0 100 100" className="w-full h-full -rotate-90">
                          <circle cx="50" cy="50" r="40" fill="none" stroke="#27272a" strokeWidth="12"/>
                          <circle cx="50" cy="50" r="40" fill="none"
                            stroke={healthScore.score>=80?'#10b981':healthScore.score>=60?'#6366f1':healthScore.score>=40?'#f59e0b':'#f43f5e'}
                            strokeWidth="12" strokeLinecap="round"
                            strokeDasharray={`${healthScore.score * 2.513} 251.3`}/>
                        </svg>
                        <div className="absolute inset-0 flex items-center justify-center">
                          <span className={`text-base font-black ${healthScore.color}`}>{healthScore.score}</span>
                        </div>
                      </div>
                      <div className="flex-1 space-y-1.5">
                        {healthScore.breakdown.map(b => (
                          <div key={b.label} className="flex items-center gap-2">
                            <div className="flex-1 h-1 bg-black/40 rounded-full overflow-hidden">
                              <div className="h-full bg-indigo-500 rounded-full" style={{width:`${(b.pts/b.max)*100}%`}}/>
                            </div>
                            <span className="text-[10px] text-zinc-500 w-20 truncate">{b.label}</span>
                            <span className="text-[10px] font-bold text-zinc-400 w-8 text-right">{b.pts}/{b.max}</span>
                          </div>
                        ))}
                      </div>
                    </div>
                    <p className={`text-xs font-bold text-center ${healthScore.color}`}>{healthScore.label}</p>
                  </div>
                )}

                {/* Mapa de calor anual */}
                {yearHeatmap && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">Gastos {currentDate.getFullYear()}</p>
                      <button onClick={() => setShowAnnualModal(true)}
                        className="text-[10px] font-bold text-indigo-400 active:opacity-60">
                        Detalle →
                      </button>
                    </div>
                    <div className="overflow-x-auto no-scrollbar">
                      <svg viewBox="0 0 371 58" className="w-full min-w-[320px]">
                        {/* Etiquetas de mes */}
                        {[0,1,2,3,4,5,6,7,8,9,10,11].map(m => {
                          const d = new Date(currentDate.getFullYear(), m, 1);
                          const weekIdx = Math.floor((d - new Date(currentDate.getFullYear(), 0, 1) + d.getDay() * 86400000) / (7 * 86400000));
                          return <text key={m} x={weekIdx * 7 + 1} y="7" fontSize="4.5" fill="#52525b" fontWeight="600">{MONTHS[m].slice(0,3)}</text>;
                        })}
                        {/* Celdas */}
                        {yearHeatmap.cells.map((cell, i) => {
                          const col = Math.floor(i / 7);
                          const row = i % 7;
                          const x = col * 7 + 1;
                          const y = row * 7 + 10;
                          if (!cell) return <rect key={i} x={x} y={y} width="5.5" height="5.5" rx="1" fill="#18181b"/>;
                          const intensity = yearHeatmap.maxVal > 0 ? cell.val / yearHeatmap.maxVal : 0;
                          const fill = cell.isToday ? '#6366f1'
                            : cell.val === 0 ? '#18181b'
                            : intensity < 0.25 ? '#064e3b'
                            : intensity < 0.5  ? '#059669'
                            : intensity < 0.75 ? '#f59e0b'
                            : '#f43f5e';
                          return (
                            <rect key={i} x={x} y={y} width="5.5" height="5.5" rx="1" fill={fill}
                              onClick={() => cell.val > 0 && goToDate(cell.key)}>
                            </rect>
                          );
                        })}
                      </svg>
                    </div>
                    <div className="flex items-center gap-2 mt-2 justify-end">
                      {[['#18181b','Sin gasto'],['#064e3b','Bajo'],['#059669','Medio'],['#f59e0b','Alto'],['#f43f5e','Pico']].map(([c,l]) => (
                        <div key={l} className="flex items-center gap-1">
                          <div className="w-2 h-2 rounded-sm" style={{backgroundColor:c}}/>
                          <span className="text-[8px] text-zinc-700">{l}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* ── Balance semanal ── */}
                {weekBalance && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-3">Balance semanal</p>
                    <div className="grid grid-cols-2 gap-3">
                      <div className="bg-black/30 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-600 font-semibold mb-1">Esta semana</p>
                        <p className="text-sm font-black text-rose-300">${formatNumber(weekBalance.cur)}</p>
                      </div>
                      <div className="bg-black/30 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-600 font-semibold mb-1">Semana anterior</p>
                        <p className="text-sm font-black text-zinc-400">${formatNumber(weekBalance.prev)}</p>
                      </div>
                    </div>
                    {weekBalance.pct !== null && (
                      <div className={`mt-3 flex items-center justify-center gap-2 py-2 rounded-xl ${weekBalance.diff <= 0 ? 'bg-emerald-500/8 border border-emerald-500/15' : 'bg-rose-500/8 border border-rose-500/15'}`}>
                        <span className={`text-sm ${weekBalance.diff <= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                          {weekBalance.diff <= 0 ? '▼' : '▲'}
                        </span>
                        <p className={`text-xs font-bold ${weekBalance.diff <= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                          {Math.abs(weekBalance.pct)}% vs semana pasada
                          {weekBalance.diff <= 0 ? ' — ¡gastaste menos!' : ''}
                        </p>
                      </div>
                    )}
                  </div>
                )}

                {/* ── Fin de semana vs días laborables ── */}
                {weekendAnalysis && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-3">Gastos últimos 30 días</p>
                    <div className="flex items-center gap-2 mb-3">
                      <div className="flex-1 h-3 bg-black/40 rounded-full overflow-hidden flex">
                        <div className="h-full bg-indigo-500 rounded-l-full transition-all duration-700"
                          style={{width:`${weekendAnalysis.wdPct}%`}}/>
                        <div className="h-full bg-violet-400 rounded-r-full transition-all duration-700"
                          style={{width:`${weekendAnalysis.wePct}%`}}/>
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <div className="bg-indigo-500/8 border border-indigo-500/15 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-500 font-semibold mb-1">Lun–Vie</p>
                        <p className="text-sm font-black text-indigo-300">${priv(formatNumber(weekendAnalysis.weekday))}</p>
                        <p className="text-[10px] text-zinc-600 mt-0.5">{weekendAnalysis.wdPct}% del gasto</p>
                      </div>
                      <div className="bg-violet-500/8 border border-violet-500/15 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-500 font-semibold mb-1">Sáb–Dom</p>
                        <p className="text-sm font-black text-violet-300">${priv(formatNumber(weekendAnalysis.weekend))}</p>
                        <p className="text-[10px] text-zinc-600 mt-0.5">{weekendAnalysis.wePct}% del gasto</p>
                      </div>
                    </div>
                  </div>
                )}

                {/* ── Gráfico barras 6 meses ── */}
                {sixMonthBars && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-4">Ingresos vs Gastos — últimos 6 meses</p>
                    <div className="flex items-end justify-between gap-1.5 h-28">
                      {sixMonthBars.data.map((m, i) => {
                        const incH = Math.round((m.income  / sixMonthBars.maxVal) * 88);
                        const expH = Math.round((m.expense / sixMonthBars.maxVal) * 88);
                        const isCurrentMonth = i === 5;
                        return (
                          <div key={i} className="flex-1 flex flex-col items-center gap-1">
                            <div className="flex items-end gap-0.5 w-full justify-center" style={{height:'88px'}}>
                              <div
                                className={`flex-1 rounded-t-md transition-all duration-500 ${isCurrentMonth ? 'bg-emerald-400' : 'bg-emerald-700/60'}`}
                                style={{height: incH > 0 ? `${incH}px` : '2px'}}
                              />
                              <div
                                className={`flex-1 rounded-t-md transition-all duration-500 ${isCurrentMonth ? 'bg-rose-400' : 'bg-rose-700/60'}`}
                                style={{height: expH > 0 ? `${expH}px` : '2px'}}
                              />
                            </div>
                            <p className={`text-[9px] font-bold ${isCurrentMonth ? 'text-zinc-300' : 'text-zinc-600'}`}>{m.label}</p>
                          </div>
                        );
                      })}
                    </div>
                    <div className="flex justify-end gap-3 mt-2">
                      <div className="flex items-center gap-1.5">
                        <div className="w-2.5 h-2.5 rounded-sm bg-emerald-500"/>
                        <span className="text-[10px] text-zinc-600 font-semibold">Ingresos</span>
                      </div>
                      <div className="flex items-center gap-1.5">
                        <div className="w-2.5 h-2.5 rounded-sm bg-rose-500"/>
                        <span className="text-[10px] text-zinc-600 font-semibold">Gastos</span>
                      </div>
                    </div>
                  </div>
                )}

                {/* ── Patrimonio acumulado ── */}
                {patrimonioData && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">Patrimonio acumulado</p>
                      <div className="flex items-center gap-1.5">
                        <span className={`text-[10px] font-black ${patrimonioData.trend >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                          {patrimonioData.trend >= 0 ? '▲' : '▼'} ${priv(formatNumber(Math.abs(patrimonioData.trend)))}
                        </span>
                        <span className="text-[10px] text-zinc-600">último año</span>
                      </div>
                    </div>
                    <div className="overflow-hidden">
                      <svg viewBox={`0 0 ${patrimonioData.W} ${patrimonioData.H}`} className="w-full h-14" preserveAspectRatio="none">
                        <defs>
                          <linearGradient id="patriGrad" x1="0" y1="0" x2="0" y2="1">
                            <stop offset="0%" stopColor={patrimonioData.lastVal >= 0 ? '#10b981' : '#f43f5e'} stopOpacity="0.3"/>
                            <stop offset="100%" stopColor={patrimonioData.lastVal >= 0 ? '#10b981' : '#f43f5e'} stopOpacity="0.02"/>
                          </linearGradient>
                        </defs>
                        <path d={patrimonioData.areaD} fill="url(#patriGrad)"/>
                        <path d={patrimonioData.pathD} fill="none"
                          stroke={patrimonioData.lastVal >= 0 ? '#10b981' : '#f43f5e'}
                          strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                      </svg>
                    </div>
                    <div className="flex justify-between mt-2">
                      <p className="text-[10px] text-zinc-600">{patrimonioData.points[0]?.label}</p>
                      <p className={`text-xs font-black ${patrimonioData.lastVal >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                        ${priv(formatNumber(Math.abs(patrimonioData.lastVal)))}
                      </p>
                    </div>
                  </div>
                )}

                {/* Racha de ahorro */}
                {savingsStreak >= 1 && (
                  <div className={`rounded-[1.5rem] p-5 border ${savingsStreak >= 6 ? 'bg-amber-500/8 border-amber-500/20' : 'bg-zinc-900/40 border-white/5'}`}>
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <span className="text-3xl leading-none">{savingsStreak >= 6 ? '🔥' : savingsStreak >= 3 ? '🌟' : '✨'}</span>
                        <div>
                          <p className="text-sm font-bold text-white">Racha de ahorro</p>
                          <p className="text-xs text-zinc-500 mt-0.5">
                            {savingsStreak === 1 ? '1 mes con balance positivo' : `${savingsStreak} meses seguidos en positivo`}
                          </p>
                        </div>
                      </div>
                      <span className={`text-4xl font-black tabular-nums ${savingsStreak >= 6 ? 'text-amber-400' : savingsStreak >= 3 ? 'text-indigo-400' : 'text-zinc-400'}`}>
                        {savingsStreak}
                      </span>
                    </div>
                  </div>
                )}

                {/* Metas de ahorro — preview en Home */}
                {goals.filter(g=>!g.completed).length > 0 && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-4">
                      <p className="text-sm font-bold text-zinc-300 flex items-center gap-2">
                        <Target className="w-4 h-4 text-indigo-400"/> Metas
                      </p>
                      <button onClick={()=>setShowGoalsModal(true)} className="text-xs text-indigo-400 font-semibold">Ver todas →</button>
                    </div>
                    <div className="space-y-3">
                      {goals.filter(g=>!g.completed).slice(0,2).map(g=>{
                        const pct = g.target>0?Math.min(100,Math.round((g.current/g.target)*100)):0;
                        return (
                          <div key={g.id} className="space-y-1.5">
                            <div className="flex justify-between items-center">
                              <span className="text-sm font-semibold text-zinc-300 flex items-center gap-1.5">
                                <span>{g.emoji}</span>{g.name}
                              </span>
                              <span className="text-xs font-bold text-indigo-400">{pct}%</span>
                            </div>
                            <div className="h-2 bg-black/60 rounded-full overflow-hidden">
                              <div className="h-full bg-indigo-600 rounded-full" style={{width:`${pct}%`}}/>
                            </div>
                            <p className="text-xs text-zinc-700">${formatNumber(g.current)} / ${formatNumber(g.target)}</p>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}

                {/* Cuotas activas — preview en Home */}
                {activeCuotas.length > 0 && (
                  <button onClick={()=>setShowCuotasModal(true)} className="w-full text-left">
                    <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                      <div className="flex justify-between items-center mb-3">
                        <p className="text-sm font-bold text-zinc-300 flex items-center gap-2">
                          <Wallet className="w-4 h-4 text-amber-400"/> Cuotas
                        </p>
                        <div className="text-right">
                          <p className="text-xs text-zinc-600">{activeCuotas.length} en curso</p>
                          <p className="text-sm font-black text-amber-400">${formatNumber(cuotasMonthly)}/mes</p>
                        </div>
                      </div>
                      <div className="space-y-2">
                        {activeCuotas.slice(0,3).map(c=>{
                          const rem = c.totalCuotas - c.paidCuotas;
                          return (
                            <div key={c.id} className="flex items-center justify-between">
                              <span className="text-sm text-zinc-400 flex items-center gap-1.5">
                                <span>{c.emoji}</span>{c.name}
                              </span>
                              <span className="text-xs text-zinc-600">{rem} cuota{rem!==1?'s':''} · ${formatNumber(c.monthlyAmount)}</span>
                            </div>
                          );
                        })}
                        {activeCuotas.length > 3 && <p className="text-xs text-zinc-700 text-center">+{activeCuotas.length-3} más →</p>}
                      </div>
                    </div>
                  </button>
                )}

                {/* Deudas — preview en Home */}
                {pendingDebts.length > 0 && (
                  <button onClick={()=>setShowDebtsModal(true)} className="w-full text-left">
                    <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                      <div className="flex justify-between items-center mb-3">
                        <p className="text-sm font-bold text-zinc-300 flex items-center gap-2">
                          🤝 Deudas
                        </p>
                        <span className="text-xs text-zinc-500">{pendingDebts.length} activa{pendingDebts.length!==1?'s':''} →</span>
                      </div>
                      <div className="grid grid-cols-2 gap-2 mb-3">
                        {totalOwedToMe > 0 && (
                          <div className="bg-emerald-500/10 rounded-xl p-2.5 text-center">
                            <p className="text-[10px] text-zinc-500 font-semibold">Me deben</p>
                            <p className="text-sm font-black text-emerald-400">${formatNumber(totalOwedToMe)}</p>
                          </div>
                        )}
                        {totalIOwe > 0 && (
                          <div className="bg-rose-500/10 rounded-xl p-2.5 text-center">
                            <p className="text-[10px] text-zinc-500 font-semibold">Debo yo</p>
                            <p className="text-sm font-black text-rose-400">${formatNumber(totalIOwe)}</p>
                          </div>
                        )}
                      </div>
                      <div className="space-y-1.5">
                        {pendingDebts.slice(0,3).map(d=>(
                          <div key={d.id} className="flex items-center justify-between">
                            <span className="text-sm text-zinc-400 flex items-center gap-1.5 min-w-0 truncate">
                              <span>{d.emoji}</span><span className="truncate">{d.name}</span>
                            </span>
                            <span className={`text-xs font-black flex-shrink-0 ml-2 ${d.direction==='i_owe'?'text-rose-400':'text-emerald-400'}`}>
                              {d.direction==='i_owe'?'-':'+'} ${formatNumber(d.amount)}
                            </span>
                          </div>
                        ))}
                        {pendingDebts.length > 3 && <p className="text-xs text-zinc-700 text-center">+{pendingDebts.length-3} más →</p>}
                      </div>
                    </div>
                  </button>
                )}

                {/* Tendencias 6 meses */}
                {transactions.length > 0 && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">Últimos 6 meses</p>
                      <div className="flex items-center gap-3 text-[10px] font-semibold text-zinc-500">
                        <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-emerald-500 inline-block"/>Ing.</span>
                        <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-rose-500 inline-block"/>Gas.</span>
                      </div>
                    </div>
                    <TrendsChart transactions={transactions}/>
                    {prevMonth.expense > 0 && (
                      <div className="mt-3 pt-3 border-t border-white/5 flex justify-between text-xs">
                        <span className="text-zinc-600">vs mes anterior · gastos</span>
                        <span className={`font-bold ${stats.expenses > prevMonth.expense ? 'text-rose-400' : 'text-emerald-400'}`}>
                          {stats.expenses > prevMonth.expense ? '▲' : '▼'}
                          {prevMonth.expense > 0 ? Math.abs(((stats.expenses-prevMonth.expense)/prevMonth.expense)*100).toFixed(0) : 0}%
                        </span>
                      </div>
                    )}
                  </div>
                )}

                {/* Comparador: este mes vs mes anterior */}
                {(prevMonth.income > 0 || prevMonth.expense > 0) && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-4">Este mes vs anterior</p>
                    {[
                      { label: 'Ingresos', cur: stats.income,    prev: prevMonth.income,   betterIfHigher: true  },
                      { label: 'Gastos',   cur: stats.expenses,  prev: prevMonth.expense,  betterIfHigher: false },
                      { label: 'Balance',  cur: stats.available, prev: prevMonth.income - prevMonth.expense, betterIfHigher: true },
                    ].map(row => {
                      const diff = row.prev > 0 ? Math.round(((row.cur - row.prev) / row.prev) * 100) : null;
                      const isUp = diff !== null && diff > 0;
                      const goodChange = row.betterIfHigher ? isUp : !isUp;
                      const trendColor = diff === null ? 'text-zinc-600'
                        : diff === 0 ? 'text-zinc-500'
                        : goodChange ? 'text-emerald-400' : 'text-rose-400';
                      return (
                        <div key={row.label} className="flex items-center justify-between py-1.5 border-b border-white/4 last:border-0">
                          <span className="text-xs font-semibold text-zinc-500 w-14">{row.label}</span>
                          <span className="text-xs text-zinc-600 flex-1 text-right">${formatNumber(row.prev)}</span>
                          <span className={`text-[10px] font-black mx-3 tabular-nums ${trendColor}`}>
                            {diff === null ? '—' : diff === 0 ? '=' : (isUp ? '▲' : '▼') + Math.abs(diff) + '%'}
                          </span>
                          <span className="text-sm font-black text-white w-20 text-right">${formatNumber(row.cur)}</span>
                        </div>
                      );
                    })}
                    <div className="flex justify-between text-[9px] text-zinc-700 mt-3 pt-2 border-t border-white/5">
                      <span>{MONTHS[currentDate.getMonth()===0?11:currentDate.getMonth()-1]} (ant.)</span>
                      <span>{MONTHS[currentDate.getMonth()]} (actual)</span>
                    </div>
                  </div>
                )}

                {/* Velocímetro de gastos */}
                {burnRate && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">Ritmo de gastos</p>
                      <span className={`text-[10px] font-black px-2.5 py-1 rounded-full ${
                        burnRate.pct === null ? 'bg-zinc-800 text-zinc-500'
                        : burnRate.pct > 110 ? 'bg-rose-500/15 text-rose-400'
                        : burnRate.pct > 90  ? 'bg-amber-500/15 text-amber-400'
                        : 'bg-emerald-500/15 text-emerald-400'}`}>
                        {burnRate.pct !== null ? `${burnRate.pct}% del presup.` : `${burnRate.daysLeft}d restantes`}
                      </span>
                    </div>
                    <div className="grid grid-cols-3 gap-2">
                      <div className="bg-black/30 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-600 font-semibold mb-1">Prom/día</p>
                        <p className="text-base font-black text-rose-400">${formatNumber(burnRate.dailyRate)}</p>
                      </div>
                      <div className="bg-black/30 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-600 font-semibold mb-1">Proyectado</p>
                        <p className={`text-base font-black ${burnRate.pct !== null && burnRate.pct > 100 ? 'text-rose-400' : 'text-zinc-200'}`}>
                          ${formatNumber(burnRate.projected)}
                        </p>
                      </div>
                      <div className="bg-black/30 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-600 font-semibold mb-1">
                          {burnRate.safeDaily !== null ? 'Presup./día' : 'Días rest.'}
                        </p>
                        <p className={`text-base font-black ${
                          burnRate.safeDaily !== null
                            ? (burnRate.dailyRate > burnRate.safeDaily ? 'text-rose-400' : 'text-emerald-400')
                            : 'text-zinc-400'}`}>
                          {burnRate.safeDaily !== null ? `$${formatNumber(burnRate.safeDaily)}` : burnRate.daysLeft}
                        </p>
                      </div>
                    </div>
                  </div>
                )}

                {/* Proyección fin de mes */}
                {projection && (
                  <div className="bg-zinc-900/40 rounded-2xl p-5 border border-white/5">
                    <div className="flex justify-between items-start mb-3">
                      <div>
                        <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider">Proyección fin de mes</p>
                        <p className="text-xs text-zinc-700 mt-0.5">Quedan {projection.daysLeft} días · ${formatNumber(Math.round(projection.dailyRate))}/día</p>
                      </div>
                      <span className={`text-[10px] font-black px-2 py-1 rounded-full ${projection.projectedAvailable >= 0 ? 'bg-emerald-500/10 text-emerald-400' : 'bg-rose-500/10 text-rose-400'}`}>
                        {projection.projectedAvailable >= 0 ? 'OK' : '⚠️ DÉFICIT'}
                      </span>
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <div className="bg-black/30 rounded-xl p-3">
                        <p className="text-[10px] text-zinc-600 font-semibold">Gasto proyectado</p>
                        <p className="text-lg font-black text-rose-400 mt-0.5">${formatNumber(projection.projectedExpense)}</p>
                      </div>
                      <div className="bg-black/30 rounded-xl p-3">
                        <p className="text-[10px] text-zinc-600 font-semibold">Saldo proyectado</p>
                        <p className={`text-lg font-black mt-0.5 ${projection.projectedAvailable>=0?'text-emerald-400':'text-rose-400'}`}>
                          ${formatNumber(projection.projectedAvailable)}
                        </p>
                      </div>
                    </div>
                  </div>
                )}

                {/* Patrimonio Neto */}
                {(patrimonioNeto.activos > 0 || patrimonioNeto.pasivos > 0) && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-4">
                      <p className="text-sm font-bold text-zinc-300">Patrimonio neto</p>
                      <span className={`text-sm font-black ${patrimonioNeto.neto >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                        {patrimonioNeto.neto >= 0 ? '+' : ''} ${formatNumber(patrimonioNeto.neto)}
                      </span>
                    </div>
                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <span className="text-xs text-zinc-500 font-semibold flex items-center gap-1.5">
                          <span className="w-2 h-2 rounded-full bg-emerald-500 inline-block"/>Activos
                        </span>
                        <span className="text-xs font-bold text-emerald-400">${formatNumber(patrimonioNeto.activos)}</span>
                      </div>
                      <div className="flex items-center justify-between">
                        <span className="text-xs text-zinc-500 font-semibold flex items-center gap-1.5">
                          <span className="w-2 h-2 rounded-full bg-rose-500 inline-block"/>Pasivos
                        </span>
                        <span className="text-xs font-bold text-rose-400">${formatNumber(patrimonioNeto.pasivos)}</span>
                      </div>
                      {patrimonioNeto.activos > 0 && (
                        <div className="h-2 bg-black/60 rounded-full overflow-hidden mt-2">
                          <div className="h-full bg-gradient-to-r from-emerald-500 to-indigo-500 rounded-full transition-all duration-700"
                            style={{width:`${Math.min(100, (patrimonioNeto.activos / (patrimonioNeto.activos + patrimonioNeto.pasivos)) * 100).toFixed(0)}%`}}/>
                        </div>
                      )}
                    </div>
                  </div>
                )}

                {/* Vencimientos urgentes en Home */}
                {(billsDue.overdue.length > 0 || billsDue.today.length > 0 || billsDue.soon.length > 0) && (
                  <button onClick={()=>setShowBillsModal(true)} className="w-full text-left">
                    <div className="bg-amber-500/8 border border-amber-500/20 rounded-[1.5rem] p-5">
                      <div className="flex items-center justify-between mb-3">
                        <div className="flex items-center gap-2">
                          <BellRing className="w-4 h-4 text-amber-400"/>
                          <span className="text-sm font-bold text-amber-400">Vencimientos próximos</span>
                        </div>
                        <span className="text-xs text-zinc-500">Ver todos →</span>
                      </div>
                      <div className="space-y-2">
                        {[...billsDue.overdue, ...billsDue.today, ...billsDue.soon].slice(0,3).map(b => {
                          const { label, color } = billDaysLabel(b.due_date);
                          return (
                            <div key={b.id} className="flex items-center justify-between">
                              <div className="flex items-center gap-2 min-w-0">
                                <div className={`w-1.5 h-1.5 rounded-full flex-shrink-0 ${new Date(b.due_date) < today ? 'bg-rose-500' : 'bg-amber-400'}`}/>
                                <span className="text-sm font-semibold text-zinc-200 truncate">{b.title}</span>
                              </div>
                              <div className="flex items-center gap-2 flex-shrink-0 ml-2">
                                <span className={`text-xs font-bold ${color}`}>{label}</span>
                                <span className="text-sm font-black text-white">${formatNumber(b.amount)}</span>
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  </button>
                )}

                {/* Nota del mes */}
                <div className={`rounded-[1.5rem] border transition-all ${currentMemo.trim() || notaExpanded ? 'bg-amber-500/5 border-amber-500/20' : 'bg-zinc-900/30 border-white/5'}`}>
                  <button
                    onClick={() => { setNotaExpanded(v=>!v); haptic(8); }}
                    className="w-full flex items-center gap-3 px-5 py-3.5">
                    <span className="text-base leading-none flex-shrink-0">📝</span>
                    <span className={`text-xs font-bold flex-1 text-left truncate ${currentMemo.trim() ? 'text-amber-300' : 'text-zinc-500'}`}>
                      {currentMemo.trim() ? currentMemo.split('\n')[0].slice(0,60) : `Nota de ${MONTHS[currentDate.getMonth()]}…`}
                    </span>
                    <ChevronDown className={`w-3.5 h-3.5 text-zinc-600 transition-transform flex-shrink-0 ${notaExpanded ? 'rotate-180' : ''}`}/>
                  </button>
                  {notaExpanded && (
                    <div className="px-5 pb-4">
                      <textarea
                        value={currentMemo}
                        onChange={e => saveMemo(e.target.value)}
                        placeholder={`Anotá el contexto de ${MONTHS[currentDate.getMonth()]}…\nEj: mes del aguinaldo, vacaciones, sueldo doble…`}
                        rows={3}
                        className="w-full bg-black/30 border border-white/8 rounded-xl px-3 py-2.5 text-sm text-white placeholder-zinc-600 resize-none focus:outline-none focus:border-amber-500/40"
                      />
                    </div>
                  )}
                </div>

                {/* Empty state */}
                {monthTxs.length===0 && (
                  <div className="text-center py-10 space-y-3">
                    <div className="w-16 h-16 bg-zinc-900 rounded-full flex items-center justify-center mx-auto">
                      <ArrowUpRight className="w-7 h-7 text-zinc-700" />
                    </div>
                    <p className="text-sm font-semibold text-zinc-600">Sin movimientos en {MONTHS[currentDate.getMonth()]}</p>
                    <button onClick={()=>setActiveTab('add')} className="text-sm font-bold text-indigo-400 active:opacity-60">
                      + Registrar el primero
                    </button>
                  </div>
                )}
              </>
            )}
          </div>
        )}

        {/* ════════════════════════════════
            TAB: REGISTRAR
        ════════════════════════════════ */}
        {activeTab==='add' && (
          <div className="px-5 pt-5 space-y-5">
            <div className="flex items-center justify-between">
              <h2 className="text-xl font-black uppercase tracking-tight">Registrar</h2>
            </div>

            {/* ── Atajos rápidos ── */}
            {templates.length > 0 && (
              <div className="space-y-2">
                <p className="text-[10px] font-bold text-zinc-600 uppercase tracking-wider ml-1">Atajos rápidos</p>
                <div className="flex gap-2 overflow-x-auto no-scrollbar pb-1">
                  {templates.map(tpl => (
                    <div key={tpl.id} className="relative flex-shrink-0">
                      <button
                        onClick={() => { setType(tpl.type); setCategory(tpl.category); setAmount(String(tpl.amount)); setNote(tpl.note||''); haptic(8); }}
                        className={`flex flex-col items-center gap-1 px-3 py-2.5 rounded-xl border transition-all active:scale-95
                          ${tpl.type==='GASTO' ? 'bg-rose-600/10 border-rose-500/20' : 'bg-emerald-600/10 border-emerald-500/20'}`}>
                        <span className="text-lg leading-none">{getEmoji(tpl.category)}</span>
                        <span className="text-[10px] font-bold text-zinc-400 max-w-[56px] truncate text-center">{tpl.category}</span>
                        <span className={`text-[10px] font-black ${tpl.type==='GASTO'?'text-rose-300':'text-emerald-300'}`}>
                          ${formatNumber(tpl.amount)}
                        </span>
                      </button>
                      <button
                        onClick={() => deleteTemplate(tpl.id)}
                        className="absolute -top-1 -right-1 w-4 h-4 bg-zinc-800 border border-white/10 rounded-full flex items-center justify-center active:bg-rose-900">
                        <X className="w-2.5 h-2.5 text-zinc-500"/>
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}

            <div className="bg-zinc-900/40 rounded-[2rem] p-6 border border-white/5 space-y-5">
              {/* Tipo GASTO/INGRESO */}
              <div className="flex bg-black rounded-2xl p-1.5 border border-white/10">
                {['GASTO','INGRESO'].map(t=>(
                  <button key={t} onClick={()=>setType(t)}
                    className={`flex-1 py-3 text-sm font-bold rounded-xl transition-all ${type===t?(t==='GASTO'?'bg-rose-600 text-white':'bg-emerald-600 text-white'):'text-zinc-500'}`}>
                    {t}
                  </button>
                ))}
              </div>

              {/* Monto + Voz */}
              <div className="space-y-3">
                <input type="text" value={amount?formatNumber(amount):""} onChange={e=>setAmount(e.target.value.replace(/\D/g,''))}
                  placeholder="$ 0"
                  className="w-full bg-transparent text-6xl font-black text-center focus:outline-none placeholder:text-zinc-800"
                  inputMode="numeric"
                  onKeyDown={e => { if (e.key==='Enter' && amount && category && !savingTx) { e.target.blur(); handleSaveTransaction(); } }} />

                {/* Montos rápidos */}
                <div className="overflow-x-auto no-scrollbar -mx-1">
                  <div className="flex gap-2 px-1" style={{width:'max-content'}}>
                    {[100,500,1000,2000,5000,10000,20000,50000].map(v=>(
                      <button key={v} onClick={()=>setAmount(String(v))}
                        className={`px-4 py-2 rounded-xl text-xs font-black whitespace-nowrap transition-all active:scale-95
                          ${amount===String(v)
                            ? type==='GASTO'?'bg-rose-600 text-white':'bg-emerald-600 text-white'
                            : 'bg-zinc-900/80 text-zinc-400 border border-white/8'}`}>
                        {v>=1000?`${v/1000}k`:v}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="flex items-center justify-center gap-3">
                  <p className="text-xs text-zinc-600">en {MONTHS[currentDate.getMonth()]} {currentDate.getFullYear()}</p>
                  {voiceSupported && (
                    <button onClick={isListening ? stopListening : startListening}
                      className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold transition-all active:scale-95
                        ${isListening
                          ? 'bg-rose-600 text-white'
                          : 'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
                      {isListening
                        ? <><MicOff className="w-3.5 h-3.5"/><span className="animate-pulse">Escuchando…</span></>
                        : <><Mic className="w-3.5 h-3.5"/>Dictado</>}
                    </button>
                  )}
                </div>
              </div>

              {/* Recientes + Categoría — chip grid con emojis */}
              <div className="space-y-3">
                {recentCategories.length > 0 && (
                  <div className="space-y-1.5">
                    <p className="text-xs font-semibold text-zinc-600 ml-1">Recientes</p>
                    <div className="flex gap-2 flex-wrap">
                      {recentCategories.map(cat=>(
                        <button key={cat} onClick={()=>setCategory(cat)}
                          className={`flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold transition-all active:scale-95
                            ${category===cat
                              ? type==='GASTO'?'bg-rose-600 text-white':'bg-emerald-600 text-white'
                              : 'bg-zinc-900/80 text-zinc-500 border border-white/8'}`}>
                          <span>{getEmoji(cat)}</span>
                          <span>{cat}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                )}
                {/* ── Categorías frecuentes ── */}
                {frecuentesCats[type]?.length > 0 && (
                  <div className="space-y-1.5">
                    <p className="text-[10px] font-bold text-zinc-600 uppercase tracking-wider ml-1">Frecuentes</p>
                    <div className="flex gap-2 flex-wrap">
                      {frecuentesCats[type].map(c => (
                        <button key={c} onClick={() => { setCategory(c); haptic(8); }}
                          className={`flex items-center gap-1.5 px-3.5 py-2.5 rounded-xl text-sm font-bold transition-all active:scale-95
                            ${category === c
                              ? type==='GASTO' ? 'bg-rose-600 text-white shadow-lg ring-2 ring-rose-400/30' : 'bg-emerald-600 text-white shadow-lg ring-2 ring-emerald-400/30'
                              : type==='GASTO' ? 'bg-rose-600/10 text-rose-300 border border-rose-500/20' : 'bg-emerald-600/10 text-emerald-300 border border-emerald-500/20'}`}>
                          <span className="text-base leading-none">{getEmoji(c)}</span>
                          <span>{c}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                )}
                <div className="space-y-1.5">
                  <p className="text-xs font-semibold text-zinc-600 ml-1">Categoría</p>
                  <div className="flex flex-wrap gap-2">
                    {activeCategories[type]?.map(c=>(
                      <button key={c} onClick={()=>setCategory(c)}
                        className={`flex items-center gap-1.5 px-3.5 py-2.5 rounded-xl text-sm font-semibold transition-all active:scale-95
                          ${category===c
                            ? type==='GASTO' ? 'bg-rose-600 text-white shadow-lg' : 'bg-emerald-600 text-white shadow-lg'
                            : 'bg-zinc-900/80 text-zinc-400 border border-white/8'}`}>
                        <span className="text-base leading-none">{getEmoji(c)}</span>
                        <span>{c}</span>
                      </button>
                    ))}
                    {/* Nueva categoría inline */}
                    {showInlineCat ? (
                      <div className="flex items-center gap-1.5 w-full mt-1">
                        <input
                          autoFocus
                          value={inlineCatName}
                          onChange={e => setInlineCatName(e.target.value)}
                          onKeyDown={e => {
                            if (e.key === 'Enter' && inlineCatName.trim()) {
                              manageCategory('ADD', inlineCatName.trim());
                              setCategory(inlineCatName.trim());
                              setInlineCatName(''); setShowInlineCat(false);
                            }
                            if (e.key === 'Escape') { setShowInlineCat(false); setInlineCatName(''); }
                          }}
                          placeholder="Nombre de la categoría…"
                          className="flex-1 bg-zinc-900/80 border border-white/10 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-indigo-500/40 transition-colors placeholder:text-zinc-700"
                        />
                        <button
                          onClick={() => {
                            if (inlineCatName.trim()) {
                              manageCategory('ADD', inlineCatName.trim());
                              setCategory(inlineCatName.trim());
                            }
                            setInlineCatName(''); setShowInlineCat(false);
                          }}
                          className="px-3 py-2 bg-indigo-600 rounded-xl text-sm font-bold active:scale-95 transition-all">
                          OK
                        </button>
                        <button onClick={() => { setShowInlineCat(false); setInlineCatName(''); }}
                          className="p-2 bg-zinc-900/80 rounded-xl active:scale-95">
                          <X className="w-4 h-4 text-zinc-500"/>
                        </button>
                      </div>
                    ) : (
                      <button onClick={() => setShowInlineCat(true)}
                        className="flex items-center gap-1 px-3.5 py-2.5 rounded-xl text-sm font-semibold text-zinc-600 bg-zinc-900/60 border border-dashed border-white/10 active:scale-95 transition-all">
                        <Plus className="w-3.5 h-3.5"/><span>Nueva</span>
                      </button>
                    )}
                  </div>
                </div>
              </div>

              {/* Hint de presupuesto al seleccionar categoría GASTO */}
              {category && type === 'GASTO' && (() => {
                const spent = stats.expenseByCategory[category] || 0;
                const limit = budgets[category]?.amount || 0;
                const catColor = chartData.find(d=>d.cat===category)?.color || '#6366f1';
                if (spent === 0 && limit === 0) return null;
                const pct = limit > 0 ? Math.round((spent/limit)*100) : null;
                return (
                  <div className="flex items-center gap-2 px-1 py-1.5 rounded-xl"
                    style={{backgroundColor:`${catColor}12`}}>
                    <div className="w-1.5 h-1.5 rounded-full flex-shrink-0" style={{backgroundColor:catColor}}/>
                    <span className="text-xs text-zinc-400">
                      Este mes en <strong className="text-white">{category}</strong>: ${formatNumber(spent)}
                      {limit > 0 && (
                        <span className={`ml-1 font-bold ${pct >= 100 ? 'text-rose-400' : pct >= 80 ? 'text-amber-400' : 'text-zinc-500'}`}>
                          · {pct}% del límite
                        </span>
                      )}
                    </span>
                  </div>
                );
              })()}

              {/* Fecha */}
              <div className="space-y-1.5">
                <div className="flex items-center justify-between ml-1">
                  <p className="text-xs font-semibold text-zinc-600">Fecha</p>
                  <div className="flex gap-1.5">
                    {['Hoy', 'Ayer'].map((label, i) => {
                      const d = new Date();
                      d.setDate(d.getDate() - i);
                      const dStr = d.toISOString().slice(0, 10);
                      return (
                        <button key={label} onClick={() => setTxDate(dStr)}
                          className={`px-2.5 py-1 rounded-lg text-xs font-bold transition-all active:scale-95
                            ${txDate === dStr
                              ? 'bg-indigo-600 text-white'
                              : 'bg-zinc-900/80 text-zinc-500 border border-white/8'}`}>
                          {label}
                        </button>
                      );
                    })}
                  </div>
                </div>
                <input type="date" value={txDate} onChange={e=>setTxDate(e.target.value)}
                  className="w-full bg-black/60 rounded-2xl p-4 border border-white/10 font-semibold text-sm text-white focus:outline-none focus:ring-2 focus:ring-indigo-500/40" />
              </div>

              {/* Nota */}
              <textarea value={note} onChange={e=>setNote(e.target.value)} placeholder="Detalle opcional del movimiento…"
                className="w-full bg-black/40 rounded-2xl p-4 border border-white/10 text-sm text-zinc-400 min-h-[90px] resize-none focus:outline-none focus:border-indigo-500/40 transition-colors" />

              {/* Auto-sugerencia de categoría */}
              {catSuggestion && (
                <button onClick={()=>setCategory(catSuggestion)}
                  className="w-full flex items-center gap-2 px-4 py-3 rounded-2xl bg-indigo-600/10 border border-indigo-500/25 text-left active:scale-[0.98] transition-all">
                  <Sparkles className="w-4 h-4 text-indigo-400 flex-shrink-0"/>
                  <span className="text-xs font-semibold text-indigo-300 flex-1">
                    ¿Categoría sugerida: <strong className="text-white">{catSuggestion}</strong>?
                  </span>
                  <span className="text-xs text-indigo-500 font-bold flex-shrink-0">Aplicar →</span>
                </button>
              )}

              {/* Botón guardar */}
              <button onClick={handleSaveTransaction} disabled={!amount||!category||savingTx}
                className={`w-full py-5 rounded-2xl font-bold text-sm uppercase tracking-wider active:scale-95 transition-all shadow-xl
                  ${savedOk?'bg-emerald-600':(!amount||!category)?'bg-zinc-800/50 text-zinc-600':(type==='GASTO'?'bg-rose-600':'bg-emerald-600')}
                  ${savingTx?'opacity-60':''}`}>
                {savingTx ? 'Guardando…' : savedOk ? '¡Listo! ✓' : 'Confirmar registro'}
              </button>

              {/* Guardar como atajo */}
              {amount && category && (
                <button
                  onClick={() => saveTemplate({ type, category, amount: parseInt(amount)||0, note })}
                  className="w-full py-2.5 rounded-xl bg-zinc-900/60 border border-white/8 text-xs font-bold text-zinc-500 active:text-zinc-300 active:scale-95 transition-all flex items-center justify-center gap-1.5">
                  ⚡ Guardar como atajo rápido
                </button>
              )}
            </div>
          </div>
        )}

        {/* ════════════════════════════════
            TAB: HISTORIAL
        ════════════════════════════════ */}
        {activeTab==='history' && (
          <div className="pt-5 space-y-4">
            {/* Header */}
            <div className="px-5 flex justify-between items-center">
              <div className="flex items-center gap-2">
                <h2 className="text-xl font-black uppercase tracking-tight">Historial</h2>
                {allMonths && !filterDate && (
                  <button onClick={() => { setAllMonths(false); haptic(10); }}
                    className="text-xs font-bold text-indigo-400 active:opacity-60">
                    Ir a hoy →
                  </button>
                )}
              </div>
              <div className="flex items-center gap-2">
                {hasActiveFilters && filteredTxs.length > 0 && (
                  <button
                    onClick={() => exportExcel(filteredTxs, `MetaCasa_Filtrado_${new Date().toISOString().slice(0,10)}.csv`)}
                    className="flex items-center gap-1.5 px-3 py-2 bg-zinc-800 rounded-xl text-xs font-bold text-zinc-400 active:scale-90 transition-transform border border-white/8"
                    title="Exportar filtrado">
                    <FileSpreadsheet className="w-3.5 h-3.5 text-emerald-400"/>
                    {filteredTxs.length}
                  </button>
                )}
                <button onClick={() => { setCompactView(v => !v); haptic(8); }}
                  className={`p-2.5 rounded-xl active:scale-90 transition-transform ${compactView ? 'bg-indigo-600 text-white' : 'bg-zinc-900 text-zinc-500 border border-white/8'}`}
                  title={compactView ? 'Vista normal' : 'Vista compacta'}>
                  <SlidersHorizontal className="w-4 h-4"/>
                </button>
                <button onClick={() => exportExcel(transactions)} className="p-2.5 bg-emerald-600 rounded-xl text-white active:scale-90 transition-transform" title="Exportar todo">
                  <FileSpreadsheet className="w-4 h-4" />
                </button>
              </div>
            </div>

            {/* Barra de búsqueda */}
            <div className="px-5">
              <div className="flex items-center gap-2 bg-zinc-900/70 border border-white/8 rounded-2xl px-4 py-3">
                <Search className="w-4 h-4 text-zinc-500 flex-shrink-0"/>
                <input
                  type="text"
                  value={searchQuery}
                  onChange={e => setSearchQuery(e.target.value)}
                  placeholder="Buscar por categoría, nota o monto…"
                  className="flex-1 bg-transparent text-sm text-white placeholder:text-zinc-600 focus:outline-none"
                />
                {searchQuery && (
                  <button onClick={()=>setSearchQuery('')} className="active:opacity-60">
                    <XCircle className="w-4 h-4 text-zinc-600"/>
                  </button>
                )}
              </div>
            </div>

            {/* Filtros rápidos — scroll horizontal */}
            <div className="overflow-x-auto no-scrollbar">
              <div className="flex gap-2 px-5 pb-1" style={{width:'max-content'}}>

                {/* Chip de fecha activa (drill-down desde calendario) */}
                {filterDate && (
                  <button onClick={() => { setFilterDate(''); setAllMonths(false); haptic(10); }}
                    className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold whitespace-nowrap bg-indigo-600 text-white">
                    <Calendar className="w-3.5 h-3.5"/>
                    {(() => { const p = filterDate.split('-'); return `${p[2]}/${p[1]}/${p[0]}`; })()}
                    <X className="w-3 h-3 opacity-70"/>
                  </button>
                )}

                {/* Esta semana */}
                <button
                  onClick={() => { setFilterWeek(v => !v); if (!filterWeek) setAllMonths(true); haptic(8); }}
                  className={`flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition-all
                    ${filterWeek ? 'bg-indigo-600 text-white' : 'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                  <Clock className="w-3.5 h-3.5"/>
                  Esta semana
                </button>

                {/* Rango de fechas */}
                <button
                  onClick={() => { setShowRangeFilter(v=>!v); haptic(8); }}
                  className={`flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition-all
                    ${(filterDateFrom || filterDateTo) ? 'bg-violet-600 text-white' : showRangeFilter ? 'bg-zinc-800 text-zinc-300 border border-white/20' : 'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                  <Calendar className="w-3.5 h-3.5"/>
                  {(filterDateFrom || filterDateTo) ? 'Rango activo' : 'Rango'}
                </button>

                {/* Toggle mes/todos */}
                {!filterDate && !filterWeek && !(filterDateFrom || filterDateTo) && (
                <button
                  onClick={()=>setAllMonths(v=>!v)}
                  className={`flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition-all
                    ${allMonths?'bg-white text-black':'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                  <Calendar className="w-3.5 h-3.5"/>
                  {allMonths ? 'Todos los meses' : `${MONTHS[currentDate.getMonth()].slice(0,3)} ${currentDate.getFullYear()}`}
                </button>
                )}

                {/* Filtro monto chip */}
                <button
                  onClick={() => setFilterMin(filterMin === '' && filterMax === '' ? '0' : '')}
                  className={`flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition-all
                    ${filterMin !== '' || filterMax !== '' ? 'bg-white text-black' : 'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                  <SlidersHorizontal className="w-3.5 h-3.5"/>
                  {filterMin !== '' || filterMax !== ''
                    ? `$${filterMin||'0'}–${filterMax ? '$'+filterMax : '∞'}`
                    : 'Monto'}
                </button>

                {/* Separador */}
                <div className="w-px bg-white/10 self-stretch my-1"/>

                {/* Tipo */}
                {['ALL','GASTO','INGRESO'].map(t=>(
                  <button key={t}
                    onClick={()=>{ setFilterType(t); setFilterCategory(''); }}
                    className={`px-3.5 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition-all
                      ${filterType===t
                        ? t==='GASTO' ? 'bg-rose-600 text-white'
                          : t==='INGRESO' ? 'bg-emerald-600 text-white'
                          : 'bg-indigo-600 text-white'
                        : 'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                    {t==='ALL'?'Todos':t}
                  </button>
                ))}

                {/* Separador */}
                {filterableCats.length > 0 && <div className="w-px bg-white/10 self-stretch my-1"/>}

                {/* Chips de categoría */}
                {filterableCats.map(cat=>(
                  <button key={cat}
                    onClick={()=>setFilterCategory(fc=>fc===cat?'':cat)}
                    className={`flex items-center gap-1 px-3.5 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition-all
                      ${filterCategory===cat
                        ? 'bg-white text-black'
                        : 'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                    <span>{getEmoji(cat)}</span><span>{cat}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* Filtro por rango de fechas */}
            {showRangeFilter && (
              <div className="px-5">
                <div className="bg-violet-600/8 border border-violet-500/20 rounded-2xl px-4 py-3 space-y-2.5">
                  <p className="text-[10px] font-bold text-violet-400 uppercase tracking-wider">Rango personalizado</p>
                  <div className="flex items-center gap-2">
                    <div className="flex-1">
                      <p className="text-[10px] text-zinc-600 font-semibold mb-1">Desde</p>
                      <input type="date" value={filterDateFrom}
                        onChange={e => { setFilterDateFrom(e.target.value); setAllMonths(true); }}
                        className="w-full bg-zinc-900/60 border border-white/10 rounded-xl px-3 py-2 text-xs font-bold text-zinc-200 focus:outline-none focus:border-violet-500/40"/>
                    </div>
                    <span className="text-zinc-600 text-sm mt-4">→</span>
                    <div className="flex-1">
                      <p className="text-[10px] text-zinc-600 font-semibold mb-1">Hasta</p>
                      <input type="date" value={filterDateTo}
                        onChange={e => { setFilterDateTo(e.target.value); setAllMonths(true); }}
                        className="w-full bg-zinc-900/60 border border-white/10 rounded-xl px-3 py-2 text-xs font-bold text-zinc-200 focus:outline-none focus:border-violet-500/40"/>
                    </div>
                    {(filterDateFrom || filterDateTo) && (
                      <button onClick={()=>{ setFilterDateFrom(''); setFilterDateTo(''); }} className="p-1.5 mt-4 active:opacity-60">
                        <X className="w-3.5 h-3.5 text-zinc-600"/>
                      </button>
                    )}
                  </div>
                </div>
              </div>
            )}

            {/* Filtro por rango de monto */}
            {(filterMin !== '' || filterMax !== '') ? (
              <div className="px-5">
                <div className="flex items-center gap-2 bg-zinc-900/40 rounded-2xl px-4 py-3 border border-white/5">
                  <span className="text-xs text-zinc-500 font-semibold whitespace-nowrap">Monto</span>
                  <input type="text" inputMode="numeric" value={filterMin}
                    onChange={e => setFilterMin(e.target.value.replace(/\D/g,''))}
                    placeholder="Mín"
                    className="flex-1 bg-transparent text-xs font-bold text-zinc-300 text-center focus:outline-none placeholder:text-zinc-700 min-w-0"/>
                  <span className="text-zinc-700">—</span>
                  <input type="text" inputMode="numeric" value={filterMax}
                    onChange={e => setFilterMax(e.target.value.replace(/\D/g,''))}
                    placeholder="Máx"
                    className="flex-1 bg-transparent text-xs font-bold text-zinc-300 text-center focus:outline-none placeholder:text-zinc-700 min-w-0"/>
                  <button onClick={()=>{ setFilterMin(''); setFilterMax(''); }} className="p-1 active:opacity-60">
                    <X className="w-3.5 h-3.5 text-zinc-600"/>
                  </button>
                </div>
              </div>
            ) : null}

            {/* Sort + resultado count */}
            <div className="px-5 flex items-center justify-between">
              <div className="flex items-center gap-1.5">
                {loadingData
                  ? <span className="text-xs text-zinc-600">Cargando…</span>
                  : <span className="text-xs text-zinc-500">{filteredTxs.length} movimiento{filteredTxs.length!==1?'s':''}</span>
                }
                {hasActiveFilters && (
                  <button onClick={clearFilters} className="text-xs text-indigo-400 font-semibold ml-2 active:opacity-60">
                    Limpiar
                  </button>
                )}
              </div>
              <div className="relative">
                <select
                  value={sortBy}
                  onChange={e=>setSortBy(e.target.value)}
                  className="appearance-none bg-zinc-900/60 border border-white/8 rounded-xl pl-3 pr-7 py-2 text-xs font-semibold text-zinc-400 focus:outline-none">
                  <option value="date_desc">Más reciente</option>
                  <option value="date_asc">Más antiguo</option>
                  <option value="amount_desc">Mayor monto</option>
                  <option value="amount_asc">Menor monto</option>
                </select>
                <ArrowUpDown className="w-3 h-3 text-zinc-600 absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none"/>
              </div>
            </div>

            {/* Stats de categoría filtrada */}
            {filterCategory && filteredTxs.length > 0 && !loadingData && (() => {
              const catColor = chartData.find(d=>d.cat===filterCategory)?.color || '#6366f1';
              const total = filteredTxs.reduce((a,c)=>a+Number(c.amount),0);
              const avg = filteredTxs.length > 0 ? Math.round(total/filteredTxs.length) : 0;
              const budget = budgets[filterCategory]?.amount || 0;
              return (
                <div className="px-5">
                  <div className="rounded-2xl p-4 border"
                    style={{backgroundColor:`${catColor}12`, borderColor:`${catColor}30`}}>
                    <div className="flex items-center gap-2 mb-3">
                      <div className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{backgroundColor:catColor}}/>
                      <span className="text-sm font-bold text-zinc-200">{filterCategory}</span>
                      {budget > 0 && (
                        <span className="ml-auto text-xs font-semibold text-zinc-500">
                          {Math.round((total/budget)*100)}% del límite
                        </span>
                      )}
                    </div>
                    <div className="grid grid-cols-3 gap-3">
                      <div>
                        <p className="text-[10px] text-zinc-600 mb-0.5">Total</p>
                        <p className="text-sm font-black text-white">${formatNumber(total)}</p>
                      </div>
                      <div>
                        <p className="text-[10px] text-zinc-600 mb-0.5">Movimientos</p>
                        <p className="text-sm font-black text-white">{filteredTxs.length}</p>
                      </div>
                      <div>
                        <p className="text-[10px] text-zinc-600 mb-0.5">Promedio</p>
                        <p className="text-sm font-black text-white">${formatNumber(avg)}</p>
                      </div>
                    </div>
                    {budget > 0 && (
                      <div className="mt-3 h-1.5 bg-black/40 rounded-full overflow-hidden">
                        <div className="h-full rounded-full transition-all duration-500"
                          style={{width:`${Math.min(100,Math.round((total/budget)*100))}%`, backgroundColor:catColor}}/>
                      </div>
                    )}
                  </div>
                </div>
              );
            })()}

            {/* Banda resumen del filtro */}
            {filteredTxs.length > 0 && !loadingData && (
              <div className="px-5 grid grid-cols-3 gap-2">
                <div className="bg-emerald-500/10 rounded-xl p-2.5 text-center">
                  <p className="text-[9px] text-zinc-500 font-semibold tracking-wider uppercase">Ingresos</p>
                  <p className="text-sm font-black text-emerald-400 mt-0.5">${formatNumber(filteredIncome)}</p>
                </div>
                <div className="bg-rose-500/10 rounded-xl p-2.5 text-center">
                  <p className="text-[9px] text-zinc-500 font-semibold tracking-wider uppercase">Gastos</p>
                  <p className="text-sm font-black text-rose-400 mt-0.5">${formatNumber(filteredExpense)}</p>
                </div>
                <div className={`rounded-xl p-2.5 text-center ${filteredBalance >= 0 ? 'bg-indigo-500/10' : 'bg-zinc-900/60'}`}>
                  <p className="text-[9px] text-zinc-500 font-semibold tracking-wider uppercase">Balance</p>
                  <p className={`text-sm font-black mt-0.5 ${filteredBalance >= 0 ? 'text-indigo-300' : 'text-rose-400'}`}>
                    {filteredBalance >= 0 ? '+' : ''} ${formatNumber(filteredBalance)}
                  </p>
                </div>
              </div>
            )}

            {/* Lista — agrupada por fecha */}
            <div className="px-5">
              {loadingData ? (
                <div className="space-y-3">{[1,2,3].map(i=><SkeletonCard key={i} className="h-20"/>)}</div>
              ) : filteredTxs.length===0 ? (
                <div className="text-center py-16 space-y-3">
                  <div className="w-16 h-16 bg-zinc-900 rounded-full flex items-center justify-center mx-auto">
                    {searchQuery || hasActiveFilters
                      ? <Search className="w-7 h-7 text-zinc-700"/>
                      : <History className="w-7 h-7 text-zinc-700"/>}
                  </div>
                  <p className="text-sm font-semibold text-zinc-600">
                    {searchQuery || hasActiveFilters ? 'Sin resultados para esa búsqueda' : 'Sin movimientos este mes'}
                  </p>
                  {hasActiveFilters
                    ? <button onClick={clearFilters} className="text-sm font-bold text-indigo-400">Limpiar filtros</button>
                    : <button onClick={()=>setActiveTab('add')} className="text-sm font-bold text-indigo-400">+ Registrar uno</button>
                  }
                </div>
              ) : (() => {
                // Agrupar por fecha (YYYY-MM-DD)
                const groups = {};
                filteredTxs.forEach(t => {
                  const key = t.date.slice(0,10);
                  if (!groups[key]) groups[key] = [];
                  groups[key].push(t);
                });
                const sortedDays = Object.keys(groups).sort((a,b) =>
                  sortBy==='date_asc' ? a.localeCompare(b) : b.localeCompare(a)
                );
                const today = new Date().toISOString().slice(0,10);
                const yesterday = new Date(Date.now()-86400000).toISOString().slice(0,10);
                const dayLabel = (key) => {
                  if (key===today) return 'Hoy';
                  if (key===yesterday) return 'Ayer';
                  return new Date(key+'T12:00:00').toLocaleDateString('es-AR',{weekday:'long',day:'numeric',month:'long'});
                };
                return (
                  <div className="space-y-5 pb-6">
                    {sortedDays.map(day => {
                      const txs = groups[day];
                      const dayInc = txs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
                      const dayExp = txs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0);
                      const dayBal = dayInc - dayExp;
                      return (
                        <div key={day}>
                          {/* Separador de fecha */}
                          <div className="flex items-center justify-between mb-2.5 px-1">
                            <span className="text-xs font-bold text-zinc-500 capitalize">{dayLabel(day)}</span>
                            <span className={`text-xs font-black ${dayBal>=0?'text-emerald-500':'text-rose-400'}`}>
                              {dayBal>=0?'+':''} ${formatNumber(dayBal)}
                            </span>
                          </div>
                          {/* Filas del día */}
                          <div className={compactView ? 'space-y-0.5' : 'space-y-2'}>
                            {txs.map(t=> compactView ? (
                              /* ── Vista compacta ── */
                              <button key={t.id} onClick={() => setEditingTx(t)}
                                className="w-full flex items-center gap-2.5 px-3 py-2.5 bg-zinc-900/40 rounded-xl border border-white/4 active:bg-zinc-800/60 transition-colors">
                                <span className="text-sm leading-none flex-shrink-0">{getEmoji(t.category)}</span>
                                <span className="text-xs font-semibold text-zinc-300 flex-1 truncate text-left">{t.category}</span>
                                {t.note && <span className="text-[10px] text-zinc-600 italic truncate max-w-[80px]">{t.note}</span>}
                                <span className={`text-xs font-black flex-shrink-0 ${t.type==='INGRESO'?'text-emerald-400':'text-rose-300'}`}>
                                  {t.type==='GASTO'?'−':'+'}${formatNumber(t.amount)}
                                </span>
                              </button>
                            ) : (
                              /* ── Vista normal ── */
                              <div key={t.id} className="bg-zinc-900/50 rounded-2xl border border-white/5">
                                <div className="flex items-center gap-3.5 p-4">
                                  <div className={`w-11 h-11 rounded-xl flex items-center justify-center text-xl flex-shrink-0
                                    ${t.type==='INGRESO'?'bg-emerald-500/15':'bg-rose-500/15'}`}>
                                    {getEmoji(t.category)}
                                  </div>
                                  <div className="flex-1 min-w-0">
                                    <p className="text-sm font-bold text-white truncate">{t.category}</p>
                                    {t.note && <p className="text-xs text-zinc-500 italic truncate mt-0.5">"{t.note}"</p>}
                                  </div>
                                  <div className="flex items-center gap-2 flex-shrink-0">
                                    <p className={`text-base font-black ${t.type==='INGRESO'?'text-emerald-400':'text-white'}`}>
                                      {t.type==='GASTO'?'-':'+'} ${formatNumber(t.amount)}
                                    </p>
                                    <div className="flex flex-col gap-1">
                                      <button onClick={()=>prefillFromTransaction(t)} className="p-1.5 text-zinc-700 active:text-indigo-400 transition-colors" title="Copiar como nuevo">
                                        <Copy className="w-3.5 h-3.5"/>
                                      </button>
                                      <button onClick={()=>setEditingTx(t)} className="p-1.5 text-zinc-700 active:text-indigo-400 transition-colors" title="Editar">
                                        <Edit3 className="w-3.5 h-3.5"/>
                                      </button>
                                      <button onClick={()=>requestDelete(t.id,'tx')}
                                        className={`p-1.5 transition-colors rounded ${pendingDelete?.id===t.id&&pendingDelete?.type==='tx' ? 'text-rose-500 bg-rose-500/15' : 'text-zinc-700 active:text-rose-500'}`}>
                                        {pendingDelete?.id===t.id&&pendingDelete?.type==='tx'
                                          ? <Check className="w-3.5 h-3.5"/>
                                          : <Trash2 className="w-3.5 h-3.5"/>}
                                      </button>
                                    </div>
                                  </div>
                                </div>
                              </div>
                            ))}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                );
              })()}
            </div>
          </div>
        )}

        {/* ════════════════════════════════
            TAB: AJUSTES
        ════════════════════════════════ */}
        {activeTab==='settings' && (
          <div className="px-5 pt-5 space-y-6">
            <h2 className="text-xl font-black uppercase tracking-tight">Ajustes</h2>

            {/* Estrategia */}
            <div className="space-y-3">
              <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider ml-1">Estrategia financiera</p>
              <div className="bg-zinc-900/40 rounded-[1.75rem] p-5 border border-white/5 space-y-2">
                <div className="flex items-center gap-2 mb-4">
                  <TrendingUp className="w-4 h-4 text-indigo-400"/>
                  <span className="text-sm font-semibold text-zinc-400">Patrimonio histórico</span>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-0.5">
                    <p className="text-xs text-emerald-400 font-semibold">Ahorro total</p>
                    <p className="text-xl font-black">${formatNumber(stats.historicalSavingsTotal)}</p>
                  </div>
                  <div className="space-y-0.5">
                    <p className="text-xs text-indigo-400 font-semibold">Inversión total</p>
                    <p className="text-xl font-black">${formatNumber(stats.historicalInvestmentTotal)}</p>
                  </div>
                </div>
              </div>
              <PrecisionSelector label="Ahorro mensual" subtext={`Este mes: $${formatNumber(stats.savingsAmount)}`}
                value={strategy.savingsPercent||0} onChange={v=>updateStrategy('savingsPercent',v)} color="emerald" icon={PiggyBank}/>
              <PrecisionSelector label="Inversión mensual" subtext={`Este mes: $${formatNumber(stats.investmentAmount)}`}
                value={strategy.investmentPercent||0} onChange={v=>updateStrategy('investmentPercent',v)} color="indigo" icon={TrendingUp}/>
            </div>

            {/* Presupuesto por categoría */}
            <div className="space-y-3">
              <div className="flex justify-between items-center ml-1">
                <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider">Límites de categorías</p>
                <span className={`text-xs font-bold px-2.5 py-1 rounded-full ${stats.availableToAssign<0?'bg-rose-500/10 text-rose-400':'bg-emerald-500/10 text-emerald-400'}`}>
                  Sobra: ${formatNumber(stats.availableToAssign)}
                </span>
              </div>
              <div className="bg-zinc-900/40 rounded-[1.75rem] border border-white/5 overflow-hidden">
                {activeCategories.GASTO.map((cat,i)=>(
                  <div key={cat} className={`flex items-center justify-between px-5 py-4 ${i<activeCategories.GASTO.length-1?'border-b border-white/5':''}`}>
                    <div className="flex items-center gap-2.5">
                      <span className="text-lg leading-none">{getEmoji(cat)}</span>
                      <span className="text-sm font-semibold text-zinc-300">{cat}</span>
                    </div>
                    <input type="text" value={formatNumber(budgets[cat]?.amount||0)}
                      onChange={async e=>{ const v=parseFormattedNumber(e.target.value); await updateBudget(cat,v); }}
                      className="bg-transparent text-right font-bold text-sm w-24 focus:outline-none focus:text-indigo-400 transition-colors"
                      inputMode="numeric"/>
                  </div>
                ))}
              </div>
            </div>

            {/* Cuotas */}
            <div className="space-y-3">
              <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider ml-1">Cuotas en curso</p>
              <button onClick={()=>setShowCuotasModal(true)}
                className="w-full py-4 bg-zinc-900/40 border border-white/5 rounded-2xl text-sm font-semibold text-zinc-400 active:bg-zinc-900 transition-colors flex items-center justify-center gap-2">
                <Wallet className="w-4 h-4 text-amber-400"/>
                Administrar cuotas
                {activeCuotas.length>0 && <span className="bg-amber-500 text-black text-[10px] font-black px-2 py-0.5 rounded-full">{activeCuotas.length}</span>}
              </button>
            </div>

            {/* Metas de Ahorro */}
            <div className="space-y-3">
              <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider ml-1">Metas de ahorro</p>
              <button onClick={()=>setShowGoalsModal(true)}
                className="w-full py-4 bg-zinc-900/40 border border-white/5 rounded-2xl text-sm font-semibold text-zinc-400 active:bg-zinc-900 transition-colors flex items-center justify-center gap-2">
                <Target className="w-4 h-4 text-indigo-400"/>
                Administrar metas
                {goals.length>0 && <span className="bg-indigo-600 text-white text-[10px] font-black px-2 py-0.5 rounded-full">{goals.length}</span>}
              </button>
            </div>

            {/* Deudas y Préstamos */}
            <div className="space-y-3">
              <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider ml-1">Deudas y préstamos</p>
              <button onClick={()=>setShowDebtsModal(true)}
                className="w-full py-4 bg-zinc-900/40 border border-white/5 rounded-2xl text-sm font-semibold text-zinc-400 active:bg-zinc-900 transition-colors flex items-center justify-center gap-2">
                <span className="text-base leading-none">🤝</span>
                Administrar deudas
                {pendingDebts.length>0 && <span className="bg-emerald-600 text-white text-[10px] font-black px-2 py-0.5 rounded-full">{pendingDebts.length}</span>}
              </button>
            </div>

            {/* Movimientos Recurrentes */}
            <div className="space-y-3">
              <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider ml-1">Automatización</p>
              <button onClick={()=>setShowRecurringModal(true)}
                className="w-full py-4 bg-zinc-900/40 border border-white/5 rounded-2xl text-sm font-semibold text-zinc-400 active:bg-zinc-900 transition-colors flex items-center justify-center gap-2">
                <RefreshCw className="w-4 h-4 text-indigo-400"/>
                Movimientos recurrentes
                {recurring.length > 0 && <span className="bg-indigo-600 text-white text-[10px] font-black px-2 py-0.5 rounded-full">{recurring.length}</span>}
              </button>
            </div>

            {/* Categorías */}
            <div className="space-y-3">
              <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider ml-1">Categorías</p>
              <button onClick={()=>setShowCatManager(true)}
                className="w-full py-4 bg-zinc-900/40 border border-white/5 rounded-2xl text-sm font-semibold text-zinc-400 active:bg-zinc-900 transition-colors text-center">
                Editar categorías →
              </button>
              <button onClick={()=>setShowBudgetModal(true)}
                className="w-full py-4 bg-zinc-900/40 border border-white/5 rounded-2xl text-sm font-semibold text-zinc-400 active:bg-zinc-900 transition-colors text-center">
                Ver gráfico de gastos →
              </button>
              <button onClick={()=>setShowBillsModal(true)}
                className="w-full py-4 bg-zinc-900/40 border border-white/5 rounded-2xl text-sm font-semibold text-zinc-400 active:bg-zinc-900 transition-colors flex items-center justify-center gap-2">
                <Bell className="w-4 h-4"/>
                Vencimientos y alertas
                {urgentCount > 0 && <span className="bg-rose-500 text-white text-[10px] font-black px-2 py-0.5 rounded-full">{urgentCount}</span>}
              </button>
              <button onClick={()=>setShowReport(true)}
                className="w-full py-4 bg-zinc-900/40 border border-white/5 rounded-2xl text-sm font-semibold text-zinc-400 active:bg-zinc-900 transition-colors flex items-center justify-center gap-2">
                <FileText className="w-4 h-4 text-indigo-400"/>
                Reporte de {MONTHS[currentDate.getMonth()]}
              </button>
              <button onClick={()=>setShowAnnualModal(true)}
                className="w-full py-4 bg-zinc-900/40 border border-white/5 rounded-2xl text-sm font-semibold text-zinc-400 active:bg-zinc-900 transition-colors flex items-center justify-center gap-2">
                <BarChart3 className="w-4 h-4 text-indigo-400"/>
                Vista anual {currentDate.getFullYear()}
              </button>
            </div>

            {/* Tipo de cambio */}
            <div className="space-y-3">
              <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider ml-1">Tipo de cambio</p>
              <div className="bg-zinc-900/40 rounded-2xl border border-white/5 p-5 space-y-3">
                <div className="flex items-center justify-between gap-4">
                  <div>
                    <p className="text-sm font-bold text-white">USD → ARS</p>
                    <p className="text-xs text-zinc-600 mt-0.5">Ingresá el valor del dólar manualmente</p>
                  </div>
                  <div className="flex items-center gap-2 flex-shrink-0">
                    <span className="text-xs text-zinc-600 font-semibold">$</span>
                    <input
                      type="text"
                      value={exchangeRate || ''}
                      onChange={e=>updateExchangeRate(e.target.value)}
                      placeholder="0"
                      inputMode="numeric"
                      className="bg-black/60 rounded-xl px-3 py-2.5 w-24 text-right font-black text-sm text-white focus:outline-none border border-white/10 focus:border-indigo-500/60 transition-colors"
                    />
                  </div>
                </div>
                {exchangeRate > 0 ? (
                  <div className="flex items-center justify-between text-xs bg-black/30 rounded-xl px-3 py-2">
                    <span className="text-zinc-500">$1.000 ARS =</span>
                    <span className="font-bold text-indigo-300">USD {(1000/exchangeRate).toFixed(2)}</span>
                  </div>
                ) : (
                  <p className="text-xs text-zinc-700">Al configurarlo aparecerá el equivalente en USD en el balance.</p>
                )}
              </div>
            </div>

            {/* Cuenta */}
            <div className="space-y-3">
              <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider ml-1">Cuenta</p>
              <div className="bg-zinc-900/40 rounded-2xl border border-white/5 overflow-hidden">
                <div className="flex items-center justify-between px-5 py-4 border-b border-white/5">
                  <span className="text-sm font-semibold text-zinc-300">Email</span>
                  <span className="text-xs text-zinc-600 truncate max-w-[140px]">{session?.user?.email}</span>
                </div>
                <button onClick={() => exportExcel(transactions)} className="flex items-center gap-3 px-5 py-4 w-full border-b border-white/5 active:bg-zinc-900/60 transition-colors">
                  <FileSpreadsheet className="w-4 h-4 text-emerald-400"/>
                  <span className="text-sm font-semibold text-zinc-300">Exportar CSV</span>
                </button>
                <button onClick={signOut} className="flex items-center gap-3 px-5 py-4 w-full active:bg-zinc-900/60 transition-colors">
                  <LogOut className="w-4 h-4 text-rose-400"/>
                  <span className="text-sm font-semibold text-rose-400">Cerrar sesión</span>
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* ════════════════════════════════
          FAB — Registrar rápido
      ════════════════════════════════ */}
      {(activeTab === 'home' || activeTab === 'history') && (
        <button
          onClick={() => { setActiveTab('add'); haptic(12); }}
          className="fixed z-[85] right-5 bottom-[calc(env(safe-area-inset-bottom)+72px)] w-14 h-14 bg-indigo-600 rounded-full shadow-2xl flex items-center justify-center active:scale-90 transition-transform border-2 border-indigo-400/30">
          <Plus className="w-7 h-7 text-white"/>
        </button>
      )}

      {/* Scroll to top */}
      {activeTab === 'history' && showScrollTop && (
        <button
          onClick={() => { window.scrollTo({ top: 0, behavior: 'smooth' }); haptic(8); }}
          className="fixed z-[85] left-5 bottom-[calc(env(safe-area-inset-bottom)+72px)] w-11 h-11 bg-zinc-800/90 backdrop-blur-sm rounded-full shadow-xl flex items-center justify-center active:scale-90 transition-all border border-white/10">
          <ChevronLeft className="w-4 h-4 text-zinc-300 -rotate-90"/>
        </button>
      )}

      {/* PWA install banner */}
      {showInstallBanner && (
        <div className="fixed bottom-[calc(env(safe-area-inset-bottom)+60px)] left-4 right-4 z-[95] bg-zinc-900 border border-indigo-500/30 rounded-2xl p-4 shadow-2xl flex items-center gap-3 max-w-md mx-auto">
          <div className="w-10 h-10 rounded-xl overflow-hidden flex-shrink-0">
            <img src={logoMetacasa} alt="MetaCasa" className="w-full h-full object-cover"/>
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-bold text-white leading-tight">Instalá MetaCasa</p>
            <p className="text-[11px] text-zinc-500 mt-0.5">Acceso rápido sin el navegador</p>
          </div>
          <button
            onClick={async () => {
              if (!deferredInstall) return;
              deferredInstall.prompt();
              const { outcome } = await deferredInstall.userChoice;
              if (outcome === 'accepted') toast('¡Aplicación instalada! ✓', 'success');
              setDeferredInstall(null); setShowInstallBanner(false);
            }}
            className="px-3.5 py-2 bg-indigo-600 rounded-xl text-xs font-black active:scale-95 transition-transform">
            Instalar
          </button>
          <button onClick={() => setShowInstallBanner(false)} className="p-1.5 active:opacity-60">
            <X className="w-4 h-4 text-zinc-600"/>
          </button>
        </div>
      )}

      {/* ════════════════════════════════
          BOTTOM TAB BAR (iOS-style)
      ════════════════════════════════ */}
      <div className="fixed bottom-0 left-0 right-0 z-[90] bg-black/90 backdrop-blur-xl border-t border-white/8 pb-[env(safe-area-inset-bottom)]">
        <div className="max-w-md mx-auto flex">
          {[
            { id:'home',    icon: Home,    label: 'Inicio'   },
            { id:'add',     icon: Plus,    label: 'Registrar'},
            { id:'history', icon: History, label: 'Historial'},
            { id:'settings',icon: Settings,label: 'Ajustes'  },
          ].map(tab=>{
            const Icon = tab.icon;
            const active = activeTab===tab.id;
            const isAdd = tab.id==='add';
            const isHome = tab.id==='home';
            return (
              <button key={tab.id} onClick={()=>setActiveTab(tab.id)}
                className={`flex-1 flex flex-col items-center gap-1 py-3 transition-all active:scale-95
                  ${active?'text-indigo-400':'text-zinc-600'}`}>
                <div className="relative">
                  {isAdd ? (
                    <div className={`w-12 h-12 rounded-2xl flex items-center justify-center shadow-lg transition-all
                      ${active?'bg-indigo-600':'bg-zinc-900 border border-white/10'}`}>
                      <Icon className={`w-6 h-6 ${active?'text-white':'text-zinc-500'}`}/>
                    </div>
                  ) : (
                    <Icon className={`w-6 h-6 transition-all ${active?'text-indigo-400':'text-zinc-600'}`}/>
                  )}
                  {isHome && urgentCount > 0 && (
                    <span className="absolute -top-1 -right-1.5 w-4 h-4 bg-rose-500 rounded-full flex items-center justify-center text-[9px] font-black text-white leading-none">
                      {urgentCount > 9 ? '9+' : urgentCount}
                    </span>
                  )}
                </div>
                <span className={`text-[10px] font-semibold transition-all ${active?'text-indigo-400':'text-zinc-600'} ${isAdd&&!active?'opacity-0':''}`}>
                  {tab.label}
                </span>
              </button>
            );
          })}
        </div>
      </div>

      {/* ════════════════════════════════
          MODAL: Período
      ════════════════════════════════ */}
      {showDatePicker && (
        <div className="fixed inset-0 z-[200] bg-black/80 backdrop-blur-xl flex items-center justify-center p-8">
          <div className="w-full max-w-xs bg-zinc-950 rounded-[2rem] border border-white/10 p-7 space-y-5">
            <div className="flex justify-between items-center">
              <span className="text-sm font-bold text-white">Elegir período</span>
              <button onClick={()=>setShowDatePicker(false)} className="p-1.5"><X className="w-5 h-5"/></button>
            </div>
            <div className="space-y-3">
              <div className="space-y-1">
                <p className="text-xs font-semibold text-zinc-600 ml-1">Mes</p>
                <select value={currentDate.getMonth()} onChange={e=>setCurrentDate(new Date(currentDate.getFullYear(),parseInt(e.target.value),1))}
                  className="w-full bg-zinc-900 py-4 rounded-xl font-semibold text-sm text-white text-center appearance-none focus:outline-none">
                  {MONTHS.map((m,i)=><option key={m} value={i}>{m}</option>)}
                </select>
              </div>
              <div className="space-y-1">
                <p className="text-xs font-semibold text-zinc-600 ml-1">Año</p>
                <select value={currentDate.getFullYear()} onChange={e=>setCurrentDate(new Date(parseInt(e.target.value),currentDate.getMonth(),1))}
                  className="w-full bg-zinc-900 py-4 rounded-xl font-semibold text-sm text-white text-center appearance-none focus:outline-none">
                  {[2024,2025,2026,2027].map(y=><option key={y} value={y}>{y}</option>)}
                </select>
              </div>
            </div>
            <button onClick={()=>setShowDatePicker(false)} className="w-full py-4 bg-indigo-600 rounded-2xl font-bold text-sm active:scale-95 transition-all">
              Aplicar
            </button>
          </div>
        </div>
      )}

      {/* ════════════════════════════════
          MODAL: Categorías + Gráfico
      ════════════════════════════════ */}
      {showBudgetModal && (
        <div className="fixed inset-0 z-[110] bg-black flex flex-col">
          <div className="px-6 pt-[calc(env(safe-area-inset-top)+16px)] pb-5 flex justify-between items-center border-b border-white/8">
            <div>
              <h3 className="text-xl font-black uppercase tracking-tight">Categorías</h3>
              <p className="text-xs text-zinc-600 mt-0.5">{MONTHS[currentDate.getMonth()]} {currentDate.getFullYear()}</p>
            </div>
            <div className="flex items-center gap-2">
              <button onClick={()=>setBudgetChartView(v=>!v)}
                className={`p-2.5 rounded-xl transition-all ${budgetChartView?'bg-indigo-600 text-white':'bg-zinc-900 text-zinc-400'}`}>
                {budgetChartView?<BarChart3 className="w-5 h-5"/>:<PieChart className="w-5 h-5"/>}
              </button>
              <button onClick={()=>setShowBudgetModal(false)} className="p-2.5 bg-zinc-900 rounded-xl"><X className="w-5 h-5"/></button>
            </div>
          </div>

          <div className="flex-1 overflow-y-auto px-6 py-6 pb-10 space-y-4 no-scrollbar">
            {budgetChartView ? (
              totalSpent===0 ? (
                <div className="text-center py-20">
                  <p className="text-sm font-semibold text-zinc-600">Sin gastos registrados este mes</p>
                </div>
              ) : (
                <>
                  <div className="flex justify-center py-4">
                    <svg viewBox="0 0 200 200" className="w-52 h-52">
                      {slices.map((s,i)=><path key={i} d={s.path} fill={s.color}/>)}
                      <text x="100" y="95" textAnchor="middle" fill="white" fontSize="8" fontWeight="700">TOTAL GASTOS</text>
                      <text x="100" y="113" textAnchor="middle" fill="white" fontSize="14" fontWeight="900">${formatNumber(totalSpent)}</text>
                    </svg>
                  </div>
                  <div className="space-y-2">
                    {slices.sort((a,b)=>b.spent-a.spent).map((s,i)=>(
                      <div key={i} className="flex items-center justify-between bg-zinc-900/50 rounded-2xl px-4 py-3.5 border border-white/5">
                        <div className="flex items-center gap-3">
                          <span className="text-lg leading-none">{getEmoji(s.cat)}</span>
                          <span className="text-sm font-semibold">{s.cat}</span>
                        </div>
                        <div className="text-right">
                          <p className="text-sm font-black">${formatNumber(s.spent)}</p>
                          <p className="text-xs text-zinc-500">{(s.frac*100).toFixed(1)}%</p>
                        </div>
                      </div>
                    ))}
                  </div>
                </>
              )
            ) : (
              activeCategories.GASTO.map(cat=>{
                const limit=budgets[cat]?.amount||0, spent=stats.expenseByCategory[cat]||0;
                const remaining=limit-spent, progress=limit>0?Math.min(100,(spent/limit)*100):0;
                const isOver=remaining<0;
                return (
                  <div key={cat} className="bg-zinc-900/50 rounded-[1.75rem] p-6 border border-white/5 space-y-4">
                    <div className="flex justify-between items-start">
                      <button className="flex items-center gap-3 active:opacity-60 transition-opacity text-left"
                        onClick={()=>{ setShowBudgetModal(false); goToCategory(cat,'GASTO'); }}>
                        <span className="text-2xl leading-none">{getEmoji(cat)}</span>
                        <div>
                          <h4 className="text-sm font-bold text-white">{cat}</h4>
                          <p className="text-xs text-zinc-600 mt-0.5">Asignado: ${formatNumber(limit)} · Ver →</p>
                        </div>
                      </button>
                      <div className="text-right">
                        <span className={`text-xs font-bold block mb-0.5 ${isOver?'text-rose-400':'text-emerald-400'}`}>{isOver?'Excedido':'Restante'}</span>
                        <p className={`text-2xl font-black tracking-tight ${isOver?'text-rose-400':'text-white'}`}>${formatNumber(remaining)}</p>
                      </div>
                    </div>
                    <div className="h-2 bg-black rounded-full overflow-hidden">
                      <div className="h-full rounded-full transition-all duration-700"
                        style={{
                          width: `${limit>0?progress:0}%`,
                          backgroundColor: isOver ? '#f43f5e'
                            : chartData.find(d=>d.cat===cat)?.color ?? '#6366f1',
                        }}/>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      )}

      {/* ════════════════════════════════
          MODAL: Gestionar Categorías
      ════════════════════════════════ */}
      {showCatManager && (
        <div className="fixed inset-0 z-[160] bg-black/95 backdrop-blur-3xl flex flex-col">
          <div className="px-6 pt-[calc(env(safe-area-inset-top)+16px)] pb-5 flex justify-between items-center border-b border-white/8">
            <h3 className="text-xl font-black uppercase tracking-tight">Categorías</h3>
            <button onClick={()=>setShowCatManager(false)} className="p-2.5 bg-zinc-900 rounded-xl"><X className="w-5 h-5"/></button>
          </div>

          <div className="px-6 py-5 border-b border-white/5">
            <div className="flex bg-black rounded-2xl p-1.5 border border-white/10">
              {['GASTO','INGRESO'].map(t=>(
                <button key={t} onClick={()=>setType(t)}
                  className={`flex-1 py-2.5 text-sm font-bold rounded-xl transition-all ${type===t?(t==='GASTO'?'bg-rose-600 text-white':'bg-emerald-600 text-white'):'text-zinc-500'}`}>
                  {t}
                </button>
              ))}
            </div>
          </div>

          <div className="px-6 py-4 flex gap-3">
            <input value={newCatName} onChange={e=>setNewCatName(e.target.value)} placeholder="Nueva categoría…"
              className="flex-1 bg-zinc-900/60 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-indigo-500/50" />
            <button onClick={()=>manageCategory('ADD',newCatName)} className="bg-indigo-600 px-5 rounded-2xl active:scale-95 transition-all">
              <Plus className="w-5 h-5"/>
            </button>
          </div>

          <div className="flex-1 overflow-y-auto px-6 pb-10 space-y-2 no-scrollbar">
            {activeCategories[type]?.map(c=>(
              <div key={c} className="space-y-2">
                <div className="flex justify-between items-center bg-zinc-900/40 px-4 py-3.5 rounded-2xl border border-white/5">
                  {renamingCat === c ? (
                    <div className="flex items-center gap-2 w-full">
                      <input autoFocus value={renameValue}
                        onChange={e => setRenameValue(e.target.value)}
                        onKeyDown={e => {
                          if (e.key === 'Enter' && renameValue.trim()) manageCategory('RENAME', c, renameValue.trim());
                          if (e.key === 'Escape') setRenamingCat(null);
                        }}
                        className="flex-1 bg-zinc-900 rounded-xl px-3 py-2 text-sm text-white focus:outline-none border border-indigo-500/50"
                      />
                      <button onClick={() => { if (renameValue.trim()) manageCategory('RENAME', c, renameValue.trim()); else setRenamingCat(null); }}
                        className="px-3 py-2 bg-indigo-600 rounded-xl text-sm font-bold active:scale-95 transition-transform">OK</button>
                      <button onClick={() => setRenamingCat(null)}
                        className="p-2 bg-zinc-800 rounded-xl active:scale-95 transition-transform"><X className="w-4 h-4 text-zinc-500"/></button>
                    </div>
                  ) : (
                    <>
                      <div className="flex items-center gap-3">
                        <button
                          onClick={()=>setShowEmojiPicker(showEmojiPicker===c ? null : c)}
                          className="w-10 h-10 rounded-xl bg-zinc-800 border border-white/8 flex items-center justify-center text-xl active:scale-90 transition-transform"
                          title="Cambiar emoji">
                          {getEmoji(c)}
                        </button>
                        <span className="text-sm font-semibold text-zinc-200">{c}</span>
                      </div>
                      <div className="flex items-center gap-0.5">
                        <button onClick={() => { setRenamingCat(c); setRenameValue(c); setMergingCat(null); }}
                          className="p-2 text-zinc-700 active:text-indigo-400 transition-colors" title="Renombrar">
                          <Edit3 className="w-4 h-4"/>
                        </button>
                        <button onClick={() => { setMergingCat(mergingCat===c ? null : c); setRenamingCat(null); }}
                          className={`p-2 transition-colors ${mergingCat===c ? 'text-amber-400' : 'text-zinc-700 active:text-amber-400'}`} title="Fusionar">
                          <Share2 className="w-4 h-4"/>
                        </button>
                        <button onClick={()=>manageCategory('DELETE',c)} className="p-2 text-zinc-700 active:text-rose-500 transition-colors">
                          <Trash2 className="w-4 h-4"/>
                        </button>
                      </div>
                    </>
                  )}
                </div>
                {showEmojiPicker===c && (
                  <div className="bg-zinc-900/90 rounded-2xl p-3 border border-white/10">
                    <p className="text-[10px] font-semibold text-zinc-600 uppercase tracking-wider mb-2 ml-1">Elegir emoji para {c}</p>
                    <div className="grid grid-cols-8 gap-1">
                      {EMOJI_PALETTE.map(emoji=>(
                        <button key={emoji}
                          onClick={()=>{ manageCategory('EMOJI', c, emoji); setShowEmojiPicker(null); }}
                          className={`w-9 h-9 flex items-center justify-center text-lg rounded-xl transition-all active:scale-90
                            ${getEmoji(c)===emoji ? 'bg-indigo-600' : 'active:bg-white/10'}`}>
                          {emoji}
                        </button>
                      ))}
                    </div>
                  </div>
                )}
                {mergingCat===c && (
                  <div className="bg-zinc-900/90 rounded-2xl p-3 border border-amber-500/20">
                    <p className="text-[10px] font-semibold text-amber-500/70 uppercase tracking-wider mb-2 ml-1">
                      Fusionar "{c}" con…
                    </p>
                    <div className="space-y-1">
                      {(activeCategories[type]||[]).filter(cat => cat !== c).map(target => (
                        <button key={target}
                          onClick={() => manageCategory('MERGE', c, target)}
                          className="w-full flex items-center gap-2 px-3 py-2.5 rounded-xl bg-zinc-800 border border-white/8 active:bg-amber-500/15 transition-colors">
                          <span className="text-base leading-none">{getEmoji(target)}</span>
                          <span className="text-sm font-semibold text-zinc-300">{target}</span>
                        </button>
                      ))}
                    </div>
                    <button onClick={() => setMergingCat(null)} className="w-full mt-2 py-2 text-xs text-zinc-600 active:opacity-60">
                      Cancelar
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ════════════════════════════════
          MODAL: VENCIMIENTOS
      ════════════════════════════════ */}
      {showBillsModal && (
        <div className="fixed inset-0 z-[110] bg-black flex flex-col">
          <div className="px-6 pt-[calc(env(safe-area-inset-top)+16px)] pb-5 flex justify-between items-center border-b border-white/8">
            <div>
              <h3 className="text-xl font-black uppercase tracking-tight flex items-center gap-2">
                <Bell className="w-5 h-5 text-amber-400"/> Vencimientos
              </h3>
              {urgentCount > 0 && <p className="text-xs text-rose-400 font-semibold mt-0.5">{urgentCount} requieren atención</p>}
            </div>
            <div className="flex gap-2">
              <button onClick={()=>{ setEditingBill(null); setShowBillForm(true); }}
                className="p-2.5 bg-indigo-600 rounded-xl active:scale-90 transition-transform">
                <Plus className="w-5 h-5"/>
              </button>
              <button onClick={()=>setShowBillsModal(false)} className="p-2.5 bg-zinc-900 rounded-xl">
                <X className="w-5 h-5"/>
              </button>
            </div>
          </div>

          <div className="flex-1 overflow-y-auto px-6 py-5 space-y-6 no-scrollbar pb-10">

            {/* Sección: Vencidos */}
            {billsDue.overdue.length > 0 && (
              <div className="space-y-2">
                <p className="text-xs font-bold text-rose-400 uppercase tracking-wider flex items-center gap-1.5">
                  <AlertCircle className="w-3.5 h-3.5"/> Vencidos ({billsDue.overdue.length})
                </p>
                {billsDue.overdue.map(b => <BillCard key={b.id} bill={b} onPay={markBillPaid} onEdit={()=>{setEditingBill(b);setShowBillForm(true);}} onDelete={deleteBill} label={billDaysLabel(b.due_date)}/>)}
              </div>
            )}

            {/* Sección: Hoy */}
            {billsDue.today.length > 0 && (
              <div className="space-y-2">
                <p className="text-xs font-bold text-amber-400 uppercase tracking-wider flex items-center gap-1.5">
                  <Clock className="w-3.5 h-3.5"/> Hoy ({billsDue.today.length})
                </p>
                {billsDue.today.map(b => <BillCard key={b.id} bill={b} onPay={markBillPaid} onEdit={()=>{setEditingBill(b);setShowBillForm(true);}} onDelete={deleteBill} label={billDaysLabel(b.due_date)}/>)}
              </div>
            )}

            {/* Sección: Próximos 3 días */}
            {billsDue.soon.length > 0 && (
              <div className="space-y-2">
                <p className="text-xs font-bold text-zinc-400 uppercase tracking-wider flex items-center gap-1.5">
                  <BellRing className="w-3.5 h-3.5"/> Próximos 3 días ({billsDue.soon.length})
                </p>
                {billsDue.soon.map(b => <BillCard key={b.id} bill={b} onPay={markBillPaid} onEdit={()=>{setEditingBill(b);setShowBillForm(true);}} onDelete={deleteBill} label={billDaysLabel(b.due_date)}/>)}
              </div>
            )}

            {/* Sección: Este mes */}
            {billsDue.upcoming.length > 0 && (
              <div className="space-y-2">
                <p className="text-xs font-bold text-zinc-500 uppercase tracking-wider">Este mes ({billsDue.upcoming.length})</p>
                {billsDue.upcoming.map(b => <BillCard key={b.id} bill={b} onPay={markBillPaid} onEdit={()=>{setEditingBill(b);setShowBillForm(true);}} onDelete={deleteBill} label={billDaysLabel(b.due_date)}/>)}
              </div>
            )}

            {/* Sección: Pagados */}
            {bills.filter(b=>b.status==='paid').length > 0 && (
              <div className="space-y-2">
                <p className="text-xs font-bold text-zinc-600 uppercase tracking-wider flex items-center gap-1.5">
                  <CheckCheck className="w-3.5 h-3.5"/> Pagados este ciclo
                </p>
                {bills.filter(b=>b.status==='paid').map(b => (
                  <BillCard key={b.id} bill={b} onPay={markBillPaid} onEdit={()=>{setEditingBill(b);setShowBillForm(true);}} onDelete={deleteBill} label={{label:'Pagado',color:'text-emerald-500'}}/>
                ))}
              </div>
            )}

            {/* Empty */}
            {bills.length === 0 && (
              <div className="text-center py-20 space-y-4">
                <div className="w-16 h-16 bg-zinc-900 rounded-full flex items-center justify-center mx-auto">
                  <Bell className="w-7 h-7 text-zinc-700"/>
                </div>
                <p className="text-sm font-semibold text-zinc-600">Sin vencimientos cargados</p>
                <button onClick={()=>{setEditingBill(null);setShowBillForm(true);}} className="text-sm font-bold text-indigo-400">
                  + Agregar el primero
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* FORM: Nuevo/Editar Vencimiento */}
      {showBillForm && (
        <BillForm
          bill={editingBill}
          categories={[...activeCategories.GASTO, ...activeCategories.INGRESO]}
          onSave={async (data) => { const ok = await saveBill(data); if(ok) setShowBillForm(false); }}
          onClose={()=>setShowBillForm(false)}
        />
      )}

      {/* ════════════════════════════════
          MODAL: Recurrentes
      ════════════════════════════════ */}
      {showRecurringModal && (
        <div className="fixed inset-0 z-[110] bg-black flex flex-col">
          <div className="px-6 pt-[calc(env(safe-area-inset-top)+16px)] pb-5 flex justify-between items-center border-b border-white/8">
            <div>
              <h3 className="text-xl font-black uppercase tracking-tight flex items-center gap-2">
                <RefreshCw className="w-5 h-5 text-indigo-400"/> Recurrentes
              </h3>
              <p className="text-xs text-zinc-600 mt-0.5">{recurring.length} activo{recurring.length!==1?'s':''}</p>
            </div>
            <div className="flex gap-2">
              <button onClick={()=>{ setEditingRecurring(null); setShowRecurringForm(true); }}
                className="p-2.5 bg-indigo-600 rounded-xl active:scale-90 transition-transform">
                <Plus className="w-5 h-5"/>
              </button>
              <button onClick={()=>setShowRecurringModal(false)} className="p-2.5 bg-zinc-900 rounded-xl">
                <X className="w-5 h-5"/>
              </button>
            </div>
          </div>

          <div className="flex-1 overflow-y-auto px-6 py-5 space-y-3 no-scrollbar pb-10">
            {recurring.length === 0 ? (
              <div className="text-center py-20 space-y-4">
                <div className="w-16 h-16 bg-zinc-900 rounded-full flex items-center justify-center mx-auto">
                  <RefreshCw className="w-7 h-7 text-zinc-700"/>
                </div>
                <p className="text-sm font-semibold text-zinc-600">Sin movimientos recurrentes</p>
                <p className="text-xs text-zinc-700">Sueldos, alquileres, suscripciones…</p>
                <button onClick={()=>{ setEditingRecurring(null); setShowRecurringForm(true); }}
                  className="text-sm font-bold text-indigo-400">
                  + Agregar el primero
                </button>
              </div>
            ) : (
              recurring.map(rec=>(
                <RecurringCard key={rec.id} rec={rec} getEmoji={getEmoji}
                  onEdit={(r)=>{ setEditingRecurring(r); setShowRecurringForm(true); }}
                  onDelete={deleteRecurring}
                  onToggle={toggleRecurring}
                />
              ))
            )}
          </div>
        </div>
      )}

      {/* FORM: Nuevo/Editar Recurrente */}
      {showRecurringForm && (
        <RecurringForm
          rec={editingRecurring}
          categories={activeCategories}
          onSave={async (data)=>{ const ok = await saveRecurring(data); if(ok) setShowRecurringForm(false); }}
          onClose={()=>setShowRecurringForm(false)}
        />
      )}

      {/* ════════════════════════════════
          MODAL: Editar Transacción
      ════════════════════════════════ */}
      {editingTx && (
        <EditTransactionModal
          tx={editingTx}
          categories={activeCategories}
          onSave={loadTransactions}
          onClose={()=>setEditingTx(null)}
          onDuplicate={(tx) => {
            setEditingTx(null);
            setType(tx.type);
            setAmount(String(tx.amount));
            setCategory(tx.category);
            setNote(tx.note || '');
            setTxDate(new Date().toISOString().slice(0,10));
            setActiveTab('add');
            haptic(12);
          }}
        />
      )}

      {/* ════════════════════════════════
          MODAL: Cuotas
      ════════════════════════════════ */}
      {showCuotasModal && (
        <div className="fixed inset-0 z-[110] bg-black flex flex-col">
          <div className="px-6 pt-[calc(env(safe-area-inset-top)+16px)] pb-5 flex justify-between items-center border-b border-white/8">
            <div>
              <h3 className="text-xl font-black uppercase tracking-tight flex items-center gap-2">
                <Wallet className="w-5 h-5 text-amber-400"/> Cuotas
              </h3>
              <p className="text-xs text-zinc-600 mt-0.5">
                {activeCuotas.length} activa{activeCuotas.length!==1?'s':''} · ${formatNumber(cuotasMonthly)}/mes
              </p>
            </div>
            <div className="flex gap-2">
              <button onClick={()=>{ setEditingCuota(null); setShowCuotaForm(true); }}
                className="p-2.5 bg-indigo-600 rounded-xl active:scale-90 transition-transform">
                <Plus className="w-5 h-5"/>
              </button>
              <button onClick={()=>setShowCuotasModal(false)} className="p-2.5 bg-zinc-900 rounded-xl">
                <X className="w-5 h-5"/>
              </button>
            </div>
          </div>

          <div className="flex-1 overflow-y-auto px-6 py-5 space-y-4 no-scrollbar pb-12">
            {cuotas.length === 0 ? (
              <div className="text-center py-20 space-y-4">
                <div className="w-16 h-16 bg-zinc-900 rounded-full flex items-center justify-center mx-auto">
                  <Wallet className="w-7 h-7 text-zinc-700"/>
                </div>
                <p className="text-sm font-semibold text-zinc-600">Sin cuotas registradas</p>
                <p className="text-xs text-zinc-700">Electrónicos, muebles, ropa…</p>
                <button onClick={()=>{ setEditingCuota(null); setShowCuotaForm(true); }}
                  className="text-sm font-bold text-indigo-400">+ Agregar la primera</button>
              </div>
            ) : (
              <>
                {/* Resumen */}
                {cuotasMonthly > 0 && (
                  <div className="bg-amber-500/8 border border-amber-500/20 rounded-2xl p-4 flex justify-between items-center">
                    <div>
                      <p className="text-xs text-zinc-500 font-semibold">Compromiso mensual</p>
                      <p className="text-xl font-black text-amber-400">${formatNumber(cuotasMonthly)}/mes</p>
                    </div>
                    <div className="text-right">
                      <p className="text-xs text-zinc-500 font-semibold">Total restante</p>
                      <p className="text-lg font-black">${formatNumber(cuotas.reduce((a,c)=>a+(c.totalCuotas-c.paidCuotas)*c.monthlyAmount,0))}</p>
                    </div>
                  </div>
                )}
                {/* Activas */}
                {activeCuotas.length > 0 && (
                  <div className="space-y-3">
                    <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider ml-1">En curso ({activeCuotas.length})</p>
                    {activeCuotas.map(c=>(
                      <CuotaCard key={c.id} cuota={c}
                        onEdit={(c)=>{ setEditingCuota(c); setShowCuotaForm(true); }}
                        onDelete={deleteCuota}
                        onPay={payCuota}
                      />
                    ))}
                  </div>
                )}
                {/* Completadas */}
                {cuotas.filter(c=>c.paidCuotas>=c.totalCuotas).length > 0 && (
                  <div className="space-y-3">
                    <p className="text-xs font-semibold text-zinc-600 uppercase tracking-wider ml-1">Completadas</p>
                    {cuotas.filter(c=>c.paidCuotas>=c.totalCuotas).map(c=>(
                      <CuotaCard key={c.id} cuota={c}
                        onEdit={(c)=>{ setEditingCuota(c); setShowCuotaForm(true); }}
                        onDelete={deleteCuota}
                        onPay={payCuota}
                      />
                    ))}
                  </div>
                )}
              </>
            )}
          </div>
        </div>
      )}

      {showCuotaForm && (
        <CuotaForm
          cuota={editingCuota}
          onSave={(data)=>{ saveCuota(data); setShowCuotaForm(false); }}
          onClose={()=>setShowCuotaForm(false)}
        />
      )}

      {/* ════════════════════════════════
          MODAL: Metas de Ahorro
      ════════════════════════════════ */}
      {showGoalsModal && (
        <div className="fixed inset-0 z-[110] bg-black flex flex-col">
          <div className="px-6 pt-[calc(env(safe-area-inset-top)+16px)] pb-5 flex justify-between items-center border-b border-white/8">
            <div>
              <h3 className="text-xl font-black uppercase tracking-tight flex items-center gap-2">
                <Target className="w-5 h-5 text-indigo-400"/> Metas de ahorro
              </h3>
              <p className="text-xs text-zinc-600 mt-0.5">{goals.length} meta{goals.length!==1?'s':''}</p>
            </div>
            <div className="flex gap-2">
              <button onClick={()=>{ setEditingGoal(null); setShowGoalForm(true); }}
                className="p-2.5 bg-indigo-600 rounded-xl active:scale-90 transition-transform">
                <Plus className="w-5 h-5"/>
              </button>
              <button onClick={()=>setShowGoalsModal(false)} className="p-2.5 bg-zinc-900 rounded-xl">
                <X className="w-5 h-5"/>
              </button>
            </div>
          </div>

          <div className="flex-1 overflow-y-auto px-6 py-5 space-y-4 no-scrollbar pb-12">
            {goals.length === 0 ? (
              <div className="text-center py-20 space-y-4">
                <div className="w-16 h-16 bg-zinc-900 rounded-full flex items-center justify-center mx-auto">
                  <Target className="w-7 h-7 text-zinc-700"/>
                </div>
                <p className="text-sm font-semibold text-zinc-600">Sin metas de ahorro</p>
                <p className="text-xs text-zinc-700">Vacaciones, auto, electrónico…</p>
                <button onClick={()=>{ setEditingGoal(null); setShowGoalForm(true); }}
                  className="text-sm font-bold text-indigo-400">+ Crear la primera</button>
              </div>
            ) : (
              <>
                {/* Resumen total */}
                <div className="bg-indigo-600/10 border border-indigo-500/20 rounded-2xl p-4 flex justify-between items-center">
                  <div>
                    <p className="text-xs text-zinc-500 font-semibold">Total guardado</p>
                    <p className="text-xl font-black text-indigo-300">${formatNumber(goals.reduce((a,g)=>a+g.current,0))}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-xs text-zinc-500 font-semibold">Total metas</p>
                    <p className="text-xl font-black">${formatNumber(goals.reduce((a,g)=>a+g.target,0))}</p>
                  </div>
                </div>
                {goals.map(g=>(
                  <GoalCard key={g.id} goal={g}
                    onContribute={(goal)=>setContributeGoal(goal)}
                    onDelete={deleteGoal}
                    estimate={monthlyAvg?.avgBalance > 0 ? monthlyAvg.avgBalance : 0}
                  />
                ))}
              </>
            )}
          </div>
        </div>
      )}

      {showGoalForm && (
        <GoalForm
          goal={editingGoal}
          onSave={(data)=>{ saveGoal(data); setShowGoalForm(false); }}
          onClose={()=>setShowGoalForm(false)}
        />
      )}

      {contributeGoal && (
        <ContributeSheet
          goal={contributeGoal}
          onSave={(amt)=>{ addContribution(contributeGoal.id, amt); setContributeGoal(null); }}
          onClose={()=>setContributeGoal(null)}
        />
      )}

      {/* ════════════════════════════════
          MODAL: Deudas y Préstamos
      ════════════════════════════════ */}
      {showDebtsModal && (
        <div className="fixed inset-0 z-[110] bg-black flex flex-col">
          <div className="px-6 pt-[calc(env(safe-area-inset-top)+16px)] pb-5 flex justify-between items-center border-b border-white/8">
            <div>
              <h3 className="text-xl font-black uppercase tracking-tight flex items-center gap-2">
                🤝 Deudas
              </h3>
              <p className="text-xs text-zinc-600 mt-0.5">{pendingDebts.length} activa{pendingDebts.length!==1?'s':''}</p>
            </div>
            <div className="flex gap-2">
              <button onClick={()=>{ setEditingDebt(null); setShowDebtForm(true); }}
                className="p-2.5 bg-indigo-600 rounded-xl active:scale-90 transition-transform">
                <Plus className="w-5 h-5"/>
              </button>
              <button onClick={()=>setShowDebtsModal(false)} className="p-2.5 bg-zinc-900 rounded-xl">
                <X className="w-5 h-5"/>
              </button>
            </div>
          </div>

          <div className="flex-1 overflow-y-auto px-6 py-5 space-y-4 no-scrollbar pb-12">
            {debts.length === 0 ? (
              <div className="text-center py-20 space-y-4">
                <div className="w-16 h-16 bg-zinc-900 rounded-full flex items-center justify-center mx-auto text-3xl">🤝</div>
                <p className="text-sm font-semibold text-zinc-600">Sin deudas registradas</p>
                <p className="text-xs text-zinc-700">Llevá el registro de lo que te deben y lo que debés</p>
                <button onClick={()=>{ setEditingDebt(null); setShowDebtForm(true); }}
                  className="text-sm font-bold text-indigo-400">+ Agregar la primera</button>
              </div>
            ) : (
              <>
                {/* Resumen */}
                {(totalOwedToMe > 0 || totalIOwe > 0) && (
                  <div className="grid grid-cols-2 gap-3">
                    <div className="bg-emerald-500/10 border border-emerald-500/20 rounded-2xl p-4 text-center">
                      <p className="text-xs text-zinc-500 font-semibold mb-1">Me deben</p>
                      <p className="text-xl font-black text-emerald-400">${formatNumber(totalOwedToMe)}</p>
                    </div>
                    <div className="bg-rose-500/10 border border-rose-500/20 rounded-2xl p-4 text-center">
                      <p className="text-xs text-zinc-500 font-semibold mb-1">Debo yo</p>
                      <p className="text-xl font-black text-rose-400">${formatNumber(totalIOwe)}</p>
                    </div>
                  </div>
                )}
                {/* Activas */}
                {pendingDebts.length > 0 && (
                  <div className="space-y-3">
                    <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider ml-1">Activas</p>
                    {pendingDebts.map(d=>(
                      <DebtCard key={d.id} debt={d}
                        onSettle={settleDebt}
                        onEdit={(debt)=>{ setEditingDebt(debt); setShowDebtForm(true); }}
                        onDelete={deleteDebt}
                      />
                    ))}
                  </div>
                )}
                {/* Saldadas */}
                {debts.filter(d=>d.settled).length > 0 && (
                  <div className="space-y-3">
                    <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider ml-1">Saldadas</p>
                    {debts.filter(d=>d.settled).map(d=>(
                      <DebtCard key={d.id} debt={d}
                        onSettle={settleDebt}
                        onEdit={(debt)=>{ setEditingDebt(debt); setShowDebtForm(true); }}
                        onDelete={deleteDebt}
                      />
                    ))}
                  </div>
                )}
              </>
            )}
          </div>
        </div>
      )}

      {showDebtForm && (
        <DebtForm
          debt={editingDebt}
          onSave={(data)=>{ saveDebt(data); setShowDebtForm(false); }}
          onClose={()=>setShowDebtForm(false)}
        />
      )}

      {/* ════════════════════════════════
          CONFETTI — celebración de meta
      ════════════════════════════════ */}
      {showConfetti && (
        <Confetti onDone={() => setShowConfetti(false)} />
      )}

      {/* ════════════════════════════════
          MODAL: Vista Anual
      ════════════════════════════════ */}
      {showAnnualModal && (
        <AnnualModal
          transactions={transactions}
          year={currentDate.getFullYear()}
          onClose={()=>setShowAnnualModal(false)}
        />
      )}

      {/* ════════════════════════════════
          MODAL: Reporte mensual
      ════════════════════════════════ */}
      {showReport && (
        <ReportModal
          stats={stats}
          transactions={transactions}
          currentDate={currentDate}
          prevMonth={prevMonth}
          projection={projection}
          recurring={recurring}
          onClose={()=>setShowReport(false)}
        />
      )}
    </div>
  );
}

// ─────────────────────────────────────────────
// GLOBAL STYLES (injected once)
// ─────────────────────────────────────────────
function GlobalStyles() {
  return (
    <style>{`
      * { -webkit-tap-highlight-color: transparent; }
      :root { --sat: env(safe-area-inset-top); --sab: env(safe-area-inset-bottom); }
      input, select, textarea { font-size: 16px !important; }
      .no-scrollbar::-webkit-scrollbar { display: none; }
      @keyframes slide-down {
        from { opacity: 0; transform: translateY(-16px) scale(0.97); }
        to   { opacity: 1; transform: translateY(0)     scale(1);    }
      }
      .animate-slide-down { animation: slide-down 0.28s cubic-bezier(.22,.68,0,1.2) forwards; }
      @keyframes bounce {
        0%,100% { transform: translateY(0); }
        50%      { transform: translateY(-6px); }
      }
      .animate-bounce { animation: bounce 0.9s infinite; }
      @keyframes confetti-fall {
        0%   { transform: translateY(0) rotate(0deg);    opacity: 1; }
        100% { transform: translateY(110vh) rotate(540deg); opacity: 0; }
      }
      .animate-confetti-fall { animation: confetti-fall ease-in forwards; }
    `}</style>
  );
}

// ─────────────────────────────────────────────
// ROOT WRAPPER con ToastProvider
// ─────────────────────────────────────────────
export function AppWithProviders() {
  return (
    <ToastProvider>
      <App />
    </ToastProvider>
  );
}
