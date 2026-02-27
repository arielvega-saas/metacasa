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
  Target, Trophy, Wallet, Copy, Lightbulb, Calculator, Eye, EyeOff, LayoutGrid
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
const HIDDEN_WIDGETS_KEY = 'metacasa_hidden_widgets';
const WIDGET_LIST = [
  { id: 'planMes',          label: 'Plan del mes',              icon: '📋' },
  { id: 'dailyBudget',      label: 'Presupuesto diario',        icon: '💰' },
  { id: 'topTxs',           label: 'Top gastos del mes',        icon: '🏆' },
  { id: 'monthProjection',  label: 'Proyección fin de mes',     icon: '📈' },
  { id: 'recurringAlerts',  label: 'Recordatorio recurrentes',  icon: '🔔' },
  { id: 'semaforo',         label: 'Semáforo presupuestos',     icon: '🚦' },
  { id: 'spendingAlerts',   label: 'Alertas gasto inusual',     icon: '⚠️' },
  { id: 'weekBalance',      label: 'Balance semanal',           icon: '📅' },
  { id: 'weekendAnalysis',  label: 'Análisis fin de semana',    icon: '🏖️' },
  { id: 'runningBalance',   label: 'Balance acumulado',         icon: '〰️' },
  { id: 'weeklyBreakdown',  label: 'Desglose semanal',          icon: '🗓️' },
  { id: 'catVsLastMonth',   label: 'Categorías vs mes ant.',    icon: '↕️' },
  { id: 'healthScore',      label: 'Índice de salud',           icon: '🏥' },
  { id: 'registroStreak',   label: 'Racha de registro',         icon: '📝' },
  { id: 'rule503020',       label: 'Regla 50/30/20',            icon: '⚖️' },
  { id: 'yearProgress',     label: 'Progreso del año',          icon: '📆' },
  { id: 'yoyAnalysis',      label: 'Inflación personal',        icon: '📉' },
  { id: 'nextMonthForecast',label: 'Proyección próximo mes',    icon: '🔮' },
  { id: 'netPosition',      label: 'Posición neta',             icon: '⚡' },
  { id: 'activityHeatmap',  label: 'Heatmap de actividad',      icon: '🗓️' },
  { id: 'unbudgetedCats',   label: 'Cats sin presupuesto',      icon: '⚠️' },
  { id: 'surplusAllocation',label: 'Distribuir superávit',      icon: '🎯' },
  { id: 'debtPayoff',       label: 'Plan de pago deudas',       icon: '🤝' },
  { id: 'microSpends',      label: 'Gastos hormiga',            icon: '🐜' },
  { id: 'incomeDiversity',  label: 'Fuentes de ingreso',        icon: '💼' },
  { id: 'goalETA',          label: 'ETA de meta',               icon: '🎯' },
  { id: 'quincenal',        label: 'Análisis quincena',         icon: '🗓️' },
  { id: 'usdSavings',       label: 'Ahorro en USD',             icon: '💵' },
  { id: 'topSpenderDay',    label: 'Días costosos del mes',     icon: '📆' },
  { id: 'nextPayments',     label: 'Próximos pagos 14 días',    icon: '💳' },
  { id: 'monthlyPattern',   label: 'Patrón estacional',         icon: '🌡️' },
  { id: 'largestTx',        label: 'Mayor gasto del mes',       icon: '💸' },
  { id: 'threeMonthForecast',label: 'Pronóstico 3 meses',       icon: '🔭' },
  { id: 'budgetWins',       label: 'Victorias de presupuesto',  icon: '🏆' },
  { id: 'balanceTrend',     label: 'Tendencia de balance',      icon: '📊' },
  { id: 'expenseRatioGauge',label: 'Gauge gasto/ingreso',       icon: '🎯' },
  { id: 'debtTimeline',     label: 'Timeline de deudas',        icon: '🧱' },
  { id: 'savingsProjection',label: 'Proyección de ahorro',      icon: '🚀' },
  { id: 'categoryVariance', label: 'Categorías impredecibles',  icon: '📉' },
  { id: 'incomeExpectation',label: 'Ingresos esperados',        icon: '📬' },
  { id: 'paretoExpenses',   label: 'Pareto de gastos',          icon: '🍰' },
  { id: 'weeklyHeatmap',   label: 'Heatmap semanal',           icon: '🟧' },
  { id: 'liquidityRatio',  label: 'Ratio de liquidez',         icon: '💧' },
  { id: 'categoryLifecycle',label:'Ciclo de categorías',       icon: '🔄' },
  { id: 'rule503020',       label: 'Regla 50/30/20',           icon: '📐' },
  { id: 'noSpendStreak',    label: 'Racha sin gastos',          icon: '🔥' },
  { id: 'topIncomeMonths',  label: 'Mejores meses de ingreso',  icon: '📊' },
  { id: 'burnRate',         label: 'Velocidad de gasto',        icon: '⚡' },
  { id: 'amountHistogram',  label: 'Histograma de montos',      icon: '🗂️' },
  { id: 'topDescriptions',  label: 'Notas frecuentes',          icon: '💬' },
  { id: 'todaySummary',     label: 'Resumen de hoy',            icon: '📅' },
  { id: 'prevMonthCompare', label: 'Comparativa mes anterior',  icon: '⚖️' },
  { id: 'budgetCoverage',   label: 'Cobertura de presupuesto',  icon: '🧩' },
  { id: 'weekOverWeek',     label: 'Semana vs semana',          icon: '🌓' },
  { id: 'savingsMomentum',  label: 'Momentum de ahorro',        icon: '📈' },
  { id: 'surpriseCategory', label: 'Categoría sorpresa',        icon: '🏷️' },
  { id: 'monthlyTip',       label: 'Consejo del mes',           icon: '💡' },
  { id: 'txCounter',        label: 'Contador de transacciones', icon: '🔢' },
  { id: 'worstWeek',        label: 'Peor semana del mes',       icon: '📉' },
];

// Categorías clasificadas como "necesidades" para regla 50/30/20
const NEEDS_CATS = new Set(['Vivienda','Transporte','Salud','Servicios','Alimentación']);

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
  const [inc,  setInc]  = React.useState(planMes.targetIncome  > 0 ? String(planMes.targetIncome)  : '');
  const [exp,  setExp]  = React.useState(planMes.targetExpense > 0 ? String(planMes.targetExpense) : '');
  const [note, setNote] = React.useState(planMes.note || '');
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
      <textarea value={note} onChange={e=>setNote(e.target.value)}
        placeholder="Nota del mes… (mudanza, vacaciones, gasto extra…)"
        rows={2}
        className="w-full bg-zinc-900/40 border border-white/8 rounded-xl px-3 py-2 text-xs text-zinc-400 resize-none focus:outline-none focus:border-indigo-500/30 transition-colors placeholder:text-zinc-700"/>
      <div className="flex gap-2">
        <button onClick={() => onSave({ targetIncome: parseInt(inc)||0, targetExpense: parseInt(exp)||0, note: note.trim() })}
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
// CATEGORY DETAIL MODAL
// ─────────────────────────────────────────────
function CategoryDetailModal({ cat, transactions, currentDate, getEmoji, formatNumber, MONTHS, onClose, onGoToHistory }) {
  const sixMonths = React.useMemo(() => Array.from({ length: 6 }, (_, i) => {
    const d = new Date(currentDate.getFullYear(), currentDate.getMonth() - (5 - i), 1);
    const y = d.getFullYear(), m = d.getMonth();
    const amount = transactions
      .filter(t => { const td = new Date(t.date); return t.type==='GASTO' && t.category===cat && td.getFullYear()===y && td.getMonth()===m; })
      .reduce((a, c) => a + Number(c.amount), 0);
    return { label: MONTHS[m].slice(0,3), amount, isCurrent: y===currentDate.getFullYear() && m===currentDate.getMonth() };
  }), [transactions, cat, currentDate]);

  const maxVal = Math.max(...sixMonths.map(m => m.amount), 1);
  const prevMonths = sixMonths.slice(0, 5).filter(m => m.amount > 0);
  const avg = prevMonths.length > 0 ? Math.round(prevMonths.reduce((a,c)=>a+c.amount,0) / prevMonths.length) : 0;

  const currentMonthTxs = React.useMemo(() => transactions
    .filter(t => { const d = new Date(t.date); return t.type==='GASTO' && t.category===cat && d.getFullYear()===currentDate.getFullYear() && d.getMonth()===currentDate.getMonth(); })
    .sort((a,b) => Number(b.amount) - Number(a.amount)), [transactions, cat, currentDate]);

  const currentTotal = currentMonthTxs.reduce((a,c)=>a+Number(c.amount),0);

  return (
    <div className="fixed inset-0 z-[120] bg-black flex flex-col">
      <div className="px-6 pt-[calc(env(safe-area-inset-top)+16px)] pb-5 flex justify-between items-center border-b border-white/8">
        <div className="flex items-center gap-3">
          <span className="text-3xl leading-none">{getEmoji(cat)}</span>
          <div>
            <h3 className="text-xl font-black uppercase tracking-tight">{cat}</h3>
            <p className="text-xs text-zinc-500 mt-0.5">{MONTHS[currentDate.getMonth()]} {currentDate.getFullYear()}</p>
          </div>
        </div>
        <button onClick={onClose} className="p-2.5 bg-zinc-900 rounded-xl"><X className="w-5 h-5"/></button>
      </div>
      <div className="flex-1 overflow-y-auto px-6 py-5 space-y-4">
        {/* Total del mes + promedio */}
        <div className="bg-zinc-900/40 rounded-2xl p-4 flex items-center justify-between">
          <div>
            <p className="text-[10px] text-zinc-600 font-semibold mb-0.5">Este mes</p>
            <p className="text-2xl font-black text-white">${formatNumber(currentTotal)}</p>
          </div>
          {avg > 0 && (
            <div className="text-right">
              <p className="text-[10px] text-zinc-600 font-semibold mb-0.5">Promedio mensual</p>
              <p className={`text-lg font-black ${currentTotal > avg * 1.5 ? 'text-rose-400' : currentTotal > avg ? 'text-amber-400' : 'text-emerald-400'}`}>
                ${formatNumber(avg)}
              </p>
              {avg > 0 && (
                <p className={`text-[9px] font-bold mt-0.5 ${currentTotal > avg ? 'text-rose-500' : 'text-emerald-500'}`}>
                  {currentTotal > avg ? `+${formatNumber(currentTotal - avg)} vs prom.` : `−${formatNumber(avg - currentTotal)} vs prom.`}
                </p>
              )}
            </div>
          )}
        </div>
        {/* 6-month bars */}
        <div className="bg-zinc-900/40 rounded-2xl p-4">
          <p className="text-xs font-bold text-zinc-400 mb-3">Últimos 6 meses</p>
          <div className="flex items-end gap-1.5 h-20">
            {sixMonths.map((m, i) => {
              const barH = m.amount > 0 ? Math.max(4, Math.round((m.amount / maxVal) * 64)) : 0;
              return (
                <div key={i} className="flex-1 flex flex-col items-center justify-end gap-1.5">
                  <div className={`w-full rounded-t-md transition-all duration-500 ${m.isCurrent ? 'bg-rose-400' : 'bg-rose-800/60'}`}
                    style={{height: barH > 0 ? `${barH}px` : '2px'}}/>
                  <span className="text-[9px] text-zinc-600">{m.label}</span>
                </div>
              );
            })}
          </div>
        </div>
        {/* Transacciones del mes */}
        {currentMonthTxs.length > 0 ? (
          <div>
            <p className="text-xs font-bold text-zinc-400 mb-3">{currentMonthTxs.length} movimiento{currentMonthTxs.length!==1?'s':''} este mes</p>
            <div className="space-y-2">
              {currentMonthTxs.slice(0, 12).map(t => (
                <div key={t.id} className="flex items-center gap-3 bg-zinc-900/40 rounded-xl px-4 py-3">
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-semibold text-zinc-300 truncate">{t.note || cat}</p>
                    <p className="text-[10px] text-zinc-600 mt-0.5">
                      {new Date(t.date+'T12:00:00').toLocaleDateString('es-AR',{weekday:'short',day:'numeric',month:'short'})}
                    </p>
                  </div>
                  <p className="text-sm font-black text-white">${formatNumber(t.amount)}</p>
                </div>
              ))}
            </div>
          </div>
        ) : (
          <p className="text-center text-sm text-zinc-600 py-6">Sin gastos este mes</p>
        )}
      </div>
      <div className="px-6 pb-[calc(env(safe-area-inset-bottom)+16px)] pt-4 border-t border-white/8">
        <button onClick={onGoToHistory}
          className="w-full py-3.5 bg-indigo-600 rounded-2xl text-sm font-bold active:scale-95 transition-transform">
          Ver todos en historial →
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// COMPARE MODAL
// ─────────────────────────────────────────────
function CompareModal({ transactions, MONTHS, formatNumber, onClose }) {
  const now = new Date();
  const prev = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const [monthA, setMonthA] = React.useState({ year: now.getFullYear(),  month: now.getMonth() });
  const [monthB, setMonthB] = React.useState({ year: prev.getFullYear(), month: prev.getMonth() });

  const availableMonths = React.useMemo(() => {
    const set = new Set(transactions.map(t => t.date.slice(0,7)));
    return [...set].sort().reverse().slice(0,24).map(key => {
      const [y, m] = key.split('-').map(Number);
      return { year: y, month: m - 1, key };
    });
  }, [transactions]);

  const getStats = (y, m) => {
    const txs = transactions.filter(t => { const d = new Date(t.date); return d.getFullYear()===y && d.getMonth()===m; });
    const income  = txs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
    const expense = txs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0);
    const balance = income - expense;
    const rate = income > 0 ? Math.round(((income-expense)/income)*100) : 0;
    const bycat = {};
    txs.filter(t=>t.type==='GASTO').forEach(t=>{bycat[t.category]=(bycat[t.category]||0)+Number(t.amount);});
    const top3 = Object.entries(bycat).sort((a,b)=>b[1]-a[1]).slice(0,3);
    return { income, expense, balance, rate, top3, count: txs.length };
  };

  const sA = React.useMemo(()=>getStats(monthA.year,monthA.month),[transactions,monthA]);
  const sB = React.useMemo(()=>getStats(monthB.year,monthB.month),[transactions,monthB]);

  const CompRow = ({ label, vA, vB, higherIsBetter }) => {
    const aWins = higherIsBetter ? (parseFloat(String(vA).replace(/[^0-9.-]/g,'')) >= parseFloat(String(vB).replace(/[^0-9.-]/g,''))) : (parseFloat(String(vA).replace(/[^0-9.-]/g,'')) <= parseFloat(String(vB).replace(/[^0-9.-]/g,'')));
    return (
      <div className="grid grid-cols-3 items-center py-2.5 border-b border-white/5">
        <span className={`text-xs font-black text-right pr-2 ${aWins ? 'text-emerald-400' : 'text-zinc-300'}`}>{vA}</span>
        <span className="text-[10px] text-zinc-600 text-center font-semibold">{label}</span>
        <span className={`text-xs font-black text-left pl-2 ${!aWins ? 'text-emerald-400' : 'text-zinc-300'}`}>{vB}</span>
      </div>
    );
  };

  return (
    <div className="fixed inset-0 z-[120] bg-black flex flex-col">
      <div className="px-6 pt-[calc(env(safe-area-inset-top)+16px)] pb-5 flex justify-between items-center border-b border-white/8">
        <h3 className="text-xl font-black uppercase tracking-tight">Comparar meses</h3>
        <button onClick={onClose} className="p-2.5 bg-zinc-900 rounded-xl"><X className="w-5 h-5"/></button>
      </div>
      {/* Pickers */}
      <div className="px-6 py-4 grid grid-cols-2 gap-3 border-b border-white/5">
        {[{ label:'Mes A', state: monthA, set: setMonthA, color:'text-indigo-400' },
          { label:'Mes B', state: monthB, set: setMonthB, color:'text-violet-400' }].map(({ label, state, set, color }) => (
          <div key={label}>
            <p className={`text-[10px] font-bold mb-1.5 ${color}`}>{label}</p>
            <select value={`${state.year}-${state.month}`}
              onChange={e => { const [y,m]=e.target.value.split('-').map(Number); set({year:y,month:m}); }}
              className="w-full bg-zinc-900 border border-white/10 rounded-xl px-3 py-2.5 text-xs font-bold text-white focus:outline-none appearance-none">
              {availableMonths.map(m => (
                <option key={m.key} value={`${m.year}-${m.month}`}>
                  {MONTHS[m.month].slice(0,3)} {m.year}
                </option>
              ))}
            </select>
          </div>
        ))}
      </div>
      <div className="flex-1 overflow-y-auto px-6 py-5">
        {/* Column headers */}
        <div className="grid grid-cols-3 items-center mb-2">
          <p className="text-xs font-black text-indigo-400 text-right pr-2">{MONTHS[monthA.month].slice(0,3)} {monthA.year}</p>
          <div/>
          <p className="text-xs font-black text-violet-400 text-left pl-2">{MONTHS[monthB.month].slice(0,3)} {monthB.year}</p>
        </div>
        <CompRow label="Ingresos"    vA={`$${formatNumber(sA.income)}`}  vB={`$${formatNumber(sB.income)}`}  higherIsBetter={true}/>
        <CompRow label="Gastos"      vA={`$${formatNumber(sA.expense)}`} vB={`$${formatNumber(sB.expense)}`} higherIsBetter={false}/>
        <CompRow label="Balance"     vA={`$${formatNumber(sA.balance)}`} vB={`$${formatNumber(sB.balance)}`} higherIsBetter={true}/>
        <CompRow label="Tasa ahorro" vA={`${sA.rate}%`}  vB={`${sB.rate}%`}  higherIsBetter={true}/>
        <CompRow label="Movimientos" vA={String(sA.count)} vB={String(sB.count)} higherIsBetter={false}/>
        {/* Top cats */}
        <div className="mt-5 grid grid-cols-2 gap-4">
          {[{s:sA,label:MONTHS[monthA.month].slice(0,3),col:'text-indigo-400'},{s:sB,label:MONTHS[monthB.month].slice(0,3),col:'text-violet-400'}].map(({s,label,col})=>(
            <div key={label}>
              <p className={`text-[10px] font-bold mb-2 ${col}`}>Top — {label}</p>
              {s.top3.length > 0 ? s.top3.map(([cat,amt])=>(
                <div key={cat} className="flex justify-between items-center py-1.5 border-b border-white/5">
                  <span className="text-xs text-zinc-400 truncate">{cat}</span>
                  <span className="text-xs font-black text-white ml-2 flex-shrink-0">${formatNumber(amt)}</span>
                </div>
              )) : <p className="text-xs text-zinc-700">Sin gastos</p>}
            </div>
          ))}
        </div>
      </div>
    </div>
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
  const [selectedCatDetail,  setSelectedCatDetail]  = useState(null);  // catName | null
  const [showWidgetEditor,   setShowWidgetEditor]   = useState(false);
  const [showCompareModal,   setShowCompareModal]   = useState(false);
  const [showSearch,         setShowSearch]         = useState(false);
  const [searchQuery,        setSearchQuery]        = useState('');
  const [calendarView,       setCalendarView]       = useState(false);
  const [showPlazoFijo,      setShowPlazoFijo]      = useState(false);
  const [hiddenWidgets,      setHiddenWidgets]      = useState(() => {
    try { return new Set(JSON.parse(localStorage.getItem(HIDDEN_WIDGETS_KEY) || '[]')); }
    catch { return new Set(); }
  });
  const isHidden   = (id) => hiddenWidgets.has(id);
  const toggleWidget = (id) => {
    setHiddenWidgets(prev => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      localStorage.setItem(HIDDEN_WIDGETS_KEY, JSON.stringify([...next]));
      haptic(8);
      return next;
    });
  };
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
  const mountedRef     = useRef(false);
  const importFileRef  = useRef(null);

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

  const suggestBudgets = async () => {
    if (!userId) return;
    const now = new Date();
    const rows = [];
    activeCategories.GASTO.forEach(cat => {
      const amounts = [];
      for (let i = 1; i <= 3; i++) {
        const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
        const y = d.getFullYear(), m = d.getMonth();
        const total = transactions
          .filter(t => { const td = new Date(t.date); return t.type==='GASTO' && t.category===cat && td.getFullYear()===y && td.getMonth()===m; })
          .reduce((a, c) => a + Number(c.amount), 0);
        if (total > 0) amounts.push(total);
      }
      if (amounts.length > 0) {
        const avg = amounts.reduce((a,b)=>a+b,0) / amounts.length;
        rows.push({ user_id: userId, category: cat, amount: Math.round(avg * 1.05) });
      }
    });
    if (rows.length === 0) { toast('Sin historial para sugerir presupuestos','info'); return; }
    const { error } = await supabase.from('budgets').upsert(rows, { onConflict: 'user_id,category' });
    if (error) { toast(error.message,'error'); return; }
    await loadBudgets();
    toast(`✓ Sugerencias aplicadas para ${rows.length} categorías (+5% buffer)`, 'success');
    haptic(20);
  };

  const exportAllJSON = () => {
    const data = {
      exportDate: new Date().toISOString(),
      version: '1.0',
      transactions,
      budgets,
      goals,
      debts,
      cuotas,
      strategy,
    };
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement('a');
    a.href     = url;
    a.download = `MetaCasa_Backup_${new Date().toISOString().slice(0,10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
    toast('Backup descargado ✓', 'success');
    haptic(12);
  };

  const importJSON = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    e.target.value = '';
    try {
      const text = await file.text();
      const data = JSON.parse(text);
      if (!data.transactions && !data.budgets) { toast('Archivo inválido o vacío', 'error'); return; }
      let txCount = 0;
      // Importar transacciones en lotes de 100
      if (Array.isArray(data.transactions) && data.transactions.length > 0) {
        const rows = data.transactions.map(t => ({
          user_id: userId,
          amount: Number(t.amount),
          category: t.category,
          type: t.type,
          note: t.note || '',
          date: t.date,
          ...(t.id ? { id: t.id } : {}),
        }));
        for (let i = 0; i < rows.length; i += 100) {
          await supabase.from('transactions').upsert(rows.slice(i, i + 100), { onConflict: 'id', ignoreDuplicates: true });
        }
        txCount = rows.length;
      }
      // Importar presupuestos
      if (data.budgets && typeof data.budgets === 'object') {
        const budgetRows = Object.entries(data.budgets)
          .map(([cat, b]) => ({ user_id: userId, category: cat, amount: Number(b?.amount ?? b ?? 0) }))
          .filter(r => r.amount > 0);
        if (budgetRows.length) await supabase.from('budgets').upsert(budgetRows, { onConflict: 'user_id,category' });
      }
      // Importar metas, cuotas, deudas
      const newGoals  = Array.isArray(data.goals)  ? data.goals  : goals;
      const newCuotas = Array.isArray(data.cuotas) ? data.cuotas : cuotas;
      const newDebts  = Array.isArray(data.debts)  ? data.debts  : debts;
      setGoals(newGoals);
      setCuotas(newCuotas);
      setDebts(newDebts);
      localStorage.setItem(GOALS_KEY,  JSON.stringify(newGoals));
      localStorage.setItem(CUOTAS_KEY, JSON.stringify(newCuotas));
      await syncExtrasToCloud(newGoals, newCuotas, newDebts);
      await loadTransactions();
      await loadBudgets();
      toast(`✓ Backup restaurado — ${txCount} movimientos importados`, 'success');
      haptic(20);
    } catch (err) {
      toast('Error al leer el archivo: ' + err.message, 'error');
    }
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

  // ── MONTOS FRECUENTES POR CATEGORÍA ──
  const frequentAmounts = useMemo(() => {
    const freq = {};
    transactions.forEach(t => {
      const key = `${t.type}::${t.category}`;
      const amt = Math.round(Number(t.amount));
      if (amt <= 0) return;
      if (!freq[key]) freq[key] = {};
      freq[key][amt] = (freq[key][amt] || 0) + 1;
    });
    const result = {};
    Object.entries(freq).forEach(([key, amtMap]) => {
      result[key] = Object.entries(amtMap)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .map(([a]) => Number(a));
    });
    return result;
  }, [transactions]);

  // ── PROGRESO ANUAL ──
  const yearProgress = useMemo(() => {
    if (transactions.length === 0) return null;
    const year = currentDate.getFullYear();
    const now  = new Date();
    const maxMonth = now.getFullYear() === year ? now.getMonth() : 11;
    const months = Array.from({ length: maxMonth + 1 }, (_, m) => {
      const txs = transactions.filter(t => { const d = new Date(t.date); return d.getFullYear()===year && d.getMonth()===m; });
      const income  = txs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
      const expense = txs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0);
      return { m, income, expense, balance: income - expense };
    });
    if (months.every(m => m.income===0 && m.expense===0)) return null;
    const totalBalance = months.reduce((a,m)=>a+m.balance, 0);
    const totalIncome  = months.reduce((a,m)=>a+m.income,  0);
    const totalExpense = months.reduce((a,m)=>a+m.expense,  0);
    const maxVal = Math.max(...months.map(m=>Math.max(m.income,m.expense,1)), 1);
    const savedMonths = months.filter(m=>m.balance>0).length;
    return { months, totalBalance, totalIncome, totalExpense, maxVal, year, savedMonths, maxMonth };
  }, [transactions, currentDate]);

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

  // ── PROYECCIÓN FIN DE MES ──
  const monthProjection = useMemo(() => {
    const now = new Date();
    if (currentDate.getFullYear() !== now.getFullYear() || currentDate.getMonth() !== now.getMonth()) return null;
    const day = now.getDate();
    const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
    if (day < 3 || day >= daysInMonth - 1) return null;
    if (stats.expenses === 0) return null;
    const projectedExpense = Math.round((stats.expenses / day) * daysInMonth);
    const projectedIncome  = stats.income > 0 ? Math.round((stats.income  / day) * daysInMonth) : 0;
    const projectedBalance = projectedIncome - projectedExpense;
    const daysLeft = daysInMonth - day;
    let vsLimit = null;
    if (planMes.targetExpense > 0) {
      vsLimit = { over: projectedExpense > planMes.targetExpense, diff: Math.abs(projectedExpense - planMes.targetExpense) };
    }
    return { projectedExpense, projectedIncome, projectedBalance, daysLeft, day, daysInMonth, vsLimit };
  }, [stats, currentDate, planMes]);

  // ── ALERTAS DE GASTO INUSUAL ──
  const spendingAlerts = useMemo(() => {
    const now = new Date();
    if (currentDate.getFullYear() !== now.getFullYear() || currentDate.getMonth() !== now.getMonth()) return null;
    const alerts = [];
    activeCategories.GASTO.forEach(cat => {
      const cur = stats.expenseByCategory[cat] || 0;
      if (cur === 0) return;
      const prevAmounts = [];
      for (let i = 1; i <= 3; i++) {
        const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
        const pY = d.getFullYear(), pM = d.getMonth();
        const prev = transactions
          .filter(t => { const td = new Date(t.date); return t.type==='GASTO' && t.category===cat && td.getFullYear()===pY && td.getMonth()===pM; })
          .reduce((a, c) => a + Number(c.amount), 0);
        if (prev > 0) prevAmounts.push(prev);
      }
      if (prevAmounts.length < 1) return;
      const avg = prevAmounts.reduce((a, b) => a + b, 0) / prevAmounts.length;
      const ratio = cur / avg;
      if (ratio >= 1.5 && avg >= 1000) alerts.push({ cat, cur, avg: Math.round(avg), ratio: Math.round(ratio * 10) / 10 });
    });
    return alerts.length > 0 ? alerts.sort((a, b) => b.ratio - a.ratio).slice(0, 4) : null;
  }, [stats, activeCategories, transactions, currentDate]);

  // ── CATEGORÍAS VS MES ANTERIOR ──
  const catVsLastMonth = useMemo(() => {
    if (stats.expenses === 0) return null;
    const now = new Date();
    const prev = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const pY = prev.getFullYear(), pM = prev.getMonth();
    const prevByCat = {};
    transactions.forEach(t => {
      const d = new Date(t.date);
      if (t.type==='GASTO' && d.getFullYear()===pY && d.getMonth()===pM) {
        prevByCat[t.category] = (prevByCat[t.category] || 0) + Number(t.amount);
      }
    });
    if (Object.keys(prevByCat).length === 0) return null;
    const changes = activeCategories.GASTO
      .map(cat => {
        const cur = stats.expenseByCategory[cat] || 0;
        const prv = prevByCat[cat] || 0;
        if (cur === 0 && prv === 0) return null;
        const diff = cur - prv;
        const pct  = prv > 0 ? Math.round((diff / prv) * 100) : null;
        return { cat, cur, prev: prv, diff, pct };
      })
      .filter(Boolean);
    const withPct = changes.filter(c => c.pct !== null && c.prev > 0);
    const increases = [...withPct].sort((a, b) => b.pct - a.pct).slice(0, 3).filter(c => c.pct > 0);
    const decreases = [...withPct].sort((a, b) => a.pct - b.pct).slice(0, 3).filter(c => c.pct < 0);
    if (increases.length === 0 && decreases.length === 0) return null;
    return { increases, decreases, prevMonthLabel: MONTHS[pM] };
  }, [stats, activeCategories, transactions, currentDate]);

  // ── BARRAS DIARIAS DEL MES ──
  const dailyBars = useMemo(() => {
    const daysInMonth = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0).getDate();
    const todayStr = new Date().toISOString().slice(0, 10);
    const days = Array.from({ length: daysInMonth }, (_, i) => {
      const d = i + 1;
      const key = `${currentDate.getFullYear()}-${String(currentDate.getMonth()+1).padStart(2,'0')}-${String(d).padStart(2,'0')}`;
      const txDay = monthTxs.filter(t => t.date.slice(0,10) === key);
      const expense = txDay.filter(t => t.type === 'GASTO').reduce((a, c) => a + Number(c.amount), 0);
      const income  = txDay.filter(t => t.type === 'INGRESO').reduce((a, c) => a + Number(c.amount), 0);
      return { d, key, expense, income, isToday: key === todayStr };
    });
    if (days.every(d => d.expense === 0 && d.income === 0)) return null;
    const maxVal = Math.max(...days.map(d => Math.max(d.expense, d.income)), 1);
    return { days, maxVal, daysInMonth };
  }, [monthTxs, currentDate]);

  // ── TOP 5 GASTOS INDIVIDUALES ──
  const topTxs = useMemo(() => {
    const top = [...monthTxs]
      .filter(t => t.type === 'GASTO')
      .sort((a, b) => Number(b.amount) - Number(a.amount))
      .slice(0, 5);
    return top.length > 0 ? top : null;
  }, [monthTxs]);

  // ── RACHA DE REGISTRO ──
  const registroStreak = useMemo(() => {
    if (transactions.length === 0) return 0;
    const daysWithTx = new Set(transactions.map(t => t.date.slice(0, 10)));
    let streak = 0;
    const d = new Date();
    // If nothing today, start checking from yesterday
    const todayStr = d.toISOString().slice(0, 10);
    if (!daysWithTx.has(todayStr)) d.setDate(d.getDate() - 1);
    while (true) {
      const key = d.toISOString().slice(0, 10);
      if (!daysWithTx.has(key)) break;
      streak++;
      d.setDate(d.getDate() - 1);
      if (streak > 365) break;
    }
    return streak;
  }, [transactions]);

  // ── PRESUPUESTO DIARIO DISPONIBLE ──
  const dailyBudget = useMemo(() => {
    const now = new Date();
    if (currentDate.getFullYear() !== now.getFullYear() || currentDate.getMonth() !== now.getMonth()) return null;
    const totalBudget = planMes.targetExpense > 0 ? planMes.targetExpense : stats.totalBudgetsAssigned;
    if (totalBudget <= 0) return null;
    const day = now.getDate();
    const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
    const daysLeft = daysInMonth - day + 1;
    const remaining = totalBudget - stats.expenses;
    const daily = remaining > 0 ? Math.round(remaining / daysLeft) : 0;
    const pct = Math.min(100, Math.round((stats.expenses / totalBudget) * 100));
    return { daily, remaining, totalBudget, daysLeft, pct, isOver: remaining < 0 };
  }, [stats, currentDate, planMes]);

  // ── DESGLOSE FUENTES DE INGRESO ──
  const incomeSourceBreakdown = useMemo(() => {
    if (stats.income === 0) return null;
    const sources = (activeCategories.INGRESO || [])
      .map(cat => ({ cat, amount: monthTxs.filter(t => t.type==='INGRESO' && t.category===cat).reduce((a,c)=>a+Number(c.amount),0) }))
      .filter(s => s.amount > 0)
      .sort((a, b) => b.amount - a.amount);
    return sources.length >= 2 ? sources : null;
  }, [stats, activeCategories, monthTxs]);

  // ── BALANCE ACUMULADO DEL MES ──
  const runningBalance = useMemo(() => {
    const now = new Date();
    if (currentDate.getFullYear() !== now.getFullYear() || currentDate.getMonth() !== now.getMonth()) return null;
    const day = now.getDate();
    if (day < 3) return null;
    let cumulative = 0;
    const points = [];
    for (let d = 1; d <= day; d++) {
      const key = `${currentDate.getFullYear()}-${String(currentDate.getMonth()+1).padStart(2,'0')}-${String(d).padStart(2,'0')}`;
      const dayTxs = monthTxs.filter(t => t.date.slice(0,10) === key);
      cumulative += dayTxs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0)
                  - dayTxs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0);
      points.push({ d, balance: cumulative });
    }
    if (points.length < 3) return null;
    const values = points.map(p => p.balance);
    const min = Math.min(...values, 0);
    const max = Math.max(...values, 1);
    const range = max - min || 1;
    const W = 280, H = 56, PAD = 4;
    const toX = (i) => PAD + (i / Math.max(points.length - 1, 1)) * (W - PAD * 2);
    const toY = (v) => H - PAD - ((v - min) / range) * (H - PAD * 2);
    const pathD = points.map((p, i) => `${i===0?'M':'L'}${toX(i).toFixed(1)},${toY(p.balance).toFixed(1)}`).join(' ');
    const zeroY = toY(0).toFixed(1);
    const areaD = pathD + ` L${toX(points.length-1).toFixed(1)},${H} L${toX(0).toFixed(1)},${H} Z`;
    const lastVal = points[points.length-1].balance;
    const trend = lastVal - points[0].balance;
    return { points, pathD, areaD, W, H, zeroY, lastVal, trend, day };
  }, [monthTxs, currentDate]);

  // ── MICRO-ESTADÍSTICAS DEL MES ──
  const monthStats = useMemo(() => {
    if (monthTxs.length === 0) return null;
    const now = new Date();
    const daysElapsed = (currentDate.getFullYear() === now.getFullYear() && currentDate.getMonth() === now.getMonth())
      ? now.getDate() : new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0).getDate();
    const daysInMonth = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0).getDate();
    const avgDaily = daysElapsed > 0 ? Math.round(stats.expenses / daysElapsed) : 0;
    // Day with most expense
    const byDay = {};
    monthTxs.forEach(t => { if (t.type==='GASTO') byDay[t.date.slice(0,10)] = (byDay[t.date.slice(0,10)]||0) + Number(t.amount); });
    const peakDay = Object.entries(byDay).sort((a,b)=>b[1]-a[1])[0];
    const peakLabel = peakDay ? new Date(peakDay[0]+'T12:00:00').toLocaleDateString('es-AR',{day:'numeric',month:'short'}) : null;
    // Days with no expense
    const daysNoExp = Array.from({length:daysElapsed},(_,i)=>{
      const key = `${currentDate.getFullYear()}-${String(currentDate.getMonth()+1).padStart(2,'0')}-${String(i+1).padStart(2,'0')}`;
      return !byDay[key];
    }).filter(Boolean).length;
    return { avgDaily, peakLabel, peakAmount: peakDay ? peakDay[1] : 0, daysNoExp, totalTxs: monthTxs.length, daysElapsed, daysInMonth };
  }, [monthTxs, stats, currentDate]);

  // ── DESGLOSE SEMANAL DEL MES ──
  const weeklyBreakdown = useMemo(() => {
    if (monthTxs.length === 0) return null;
    const weeks = [];
    let weekStart = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1);
    const monthEnd = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0);
    let wNum = 1;
    while (weekStart <= monthEnd) {
      const weekEnd = new Date(weekStart); weekEnd.setDate(weekEnd.getDate() + 6);
      if (weekEnd > monthEnd) weekEnd.setDate(monthEnd.getDate());
      const s = weekStart.toISOString().slice(0,10), e = weekEnd.toISOString().slice(0,10);
      const wTxs = monthTxs.filter(t => t.date.slice(0,10) >= s && t.date.slice(0,10) <= e);
      const expense = wTxs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0);
      const income  = wTxs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
      const startD = weekStart.getDate(), endD = weekEnd.getDate();
      weeks.push({ wNum, label: `${startD}–${endD}`, expense, income });
      weekStart = new Date(weekEnd); weekStart.setDate(weekStart.getDate() + 1);
      wNum++;
    }
    if (weeks.every(w => w.expense === 0 && w.income === 0)) return null;
    const maxVal = Math.max(...weeks.map(w => Math.max(w.expense, w.income)), 1);
    return { weeks, maxVal };
  }, [monthTxs, currentDate]);

  // ── TENDENCIA DE SALUD (últimos 5 meses cerrados) ──
  const healthTrend = useMemo(() => {
    if (transactions.length === 0) return null;
    const now = new Date();
    const months = Array.from({ length: 5 }, (_, i) => {
      const d = new Date(now.getFullYear(), now.getMonth() - (5 - i), 1);
      const y = d.getFullYear(), m = d.getMonth();
      const txs = transactions.filter(t => { const td = new Date(t.date); return td.getFullYear()===y && td.getMonth()===m; });
      if (txs.length === 0) return null;
      const income  = txs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
      const expense = txs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0);
      if (income === 0 && expense === 0) return null;
      const rate = income > 0 ? ((income - expense) / income) * 100 : -100;
      const score = rate >= 20 ? 80 : rate >= 10 ? 65 : rate >= 5 ? 50 : rate >= 0 ? 35 : 15;
      const color = score >= 65 ? '#10b981' : score >= 50 ? '#6366f1' : score >= 35 ? '#f59e0b' : '#f43f5e';
      return { label: MONTHS[m].slice(0,3), score, color };
    }).filter(Boolean);
    return months.length >= 2 ? months : null;
  }, [transactions]);

  // ── RECORDATORIO DE RECURRENTES SIN REGISTRAR ──
  const recurringAlerts = useMemo(() => {
    const now = new Date();
    if (currentDate.getFullYear() !== now.getFullYear() || currentDate.getMonth() !== now.getMonth()) return null;
    const active = recurring.filter(r => r.active);
    if (active.length === 0) return null;
    const alerts = active.filter(r => !monthTxs.some(t => t.type===r.type && t.category===r.category)).slice(0, 4);
    return alerts.length > 0 ? alerts : null;
  }, [recurring, monthTxs, currentDate]);

  // ── REGLA 50/30/20 ──
  const rule503020 = useMemo(() => {
    if (stats.income === 0 || stats.expenses === 0) return null;
    const needs   = activeCategories.GASTO.filter(c => NEEDS_CATS.has(c)).reduce((a,c) => a + (stats.expenseByCategory[c]||0), 0);
    const wants   = activeCategories.GASTO.filter(c => !NEEDS_CATS.has(c)).reduce((a,c) => a + (stats.expenseByCategory[c]||0), 0);
    const savings = Math.max(0, stats.income - stats.expenses);
    const base    = stats.income;
    const needsPct   = Math.round((needs   / base) * 100);
    const wantsPct   = Math.round((wants   / base) * 100);
    const savingsPct = Math.round((savings / base) * 100);
    const getStatus = (val, target) => Math.abs(val - target) <= 10 ? 'ok' : val > target ? 'over' : 'low';
    return {
      needs, wants, savings, base,
      needsPct, wantsPct, savingsPct,
      needsStatus:   getStatus(needsPct,   50),
      wantsStatus:   getStatus(wantsPct,   30),
      savingsStatus: getStatus(savingsPct, 20),
    };
  }, [stats, activeCategories]);

  // ── SPARKLINES POR CATEGORÍA (3 meses) ──
  const catSparklines = useMemo(() => {
    const now = new Date();
    const result = {};
    activeCategories.GASTO.forEach(cat => {
      const vals = [3, 2, 1].map(i => {
        const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
        const y = d.getFullYear(), m = d.getMonth();
        return transactions
          .filter(t => { const td = new Date(t.date); return t.type==='GASTO' && t.category===cat && td.getFullYear()===y && td.getMonth()===m; })
          .reduce((a, c) => a + Number(c.amount), 0);
      });
      const maxVal = Math.max(...vals, 1);
      result[cat] = { vals, maxVal };
    });
    return result;
  }, [transactions, activeCategories]);

  // ── INFLACIÓN PERSONAL (YoY) ──
  const yoyAnalysis = useMemo(() => {
    const now = new Date();
    const curYear  = now.getFullYear();
    const lastYear = curYear - 1;
    const maxMonth = now.getMonth(); // 0-based, inclusive
    const catChanges = activeCategories.GASTO.map(cat => {
      const sum = (y) => {
        let total = 0, months = 0;
        for (let m = 0; m <= maxMonth; m++) {
          const s = transactions
            .filter(t => { const d = new Date(t.date); return t.type==='GASTO' && t.category===cat && d.getFullYear()===y && d.getMonth()===m; })
            .reduce((a, c) => a + Number(c.amount), 0);
          if (s > 0) { total += s; months++; }
        }
        return months > 0 ? Math.round(total / months) : 0;
      };
      const curAvg  = sum(curYear);
      const prevAvg = sum(lastYear);
      if (curAvg === 0 || prevAvg === 0) return null;
      const pct = Math.round(((curAvg - prevAvg) / prevAvg) * 100);
      return { cat, curAvg, prevAvg, pct };
    }).filter(Boolean);
    if (catChanges.length < 2) return null;
    const totalCur  = catChanges.reduce((a, c) => a + c.curAvg,  0);
    const totalPrev = catChanges.reduce((a, c) => a + c.prevAvg, 0);
    const totalPct  = totalPrev > 0 ? Math.round(((totalCur - totalPrev) / totalPrev) * 100) : null;
    const sorted = [...catChanges].sort((a, b) => b.pct - a.pct);
    return { categories: sorted, totalCur, totalPrev, totalPct, curYear, lastYear };
  }, [transactions, activeCategories]);

  // ── PROYECCIÓN DEL PRÓXIMO MES (recurrentes) ──
  const nextMonthForecast = useMemo(() => {
    const active = recurring.filter(r => r.active);
    if (active.length === 0) return null;
    const getMonthlyAmt = (r) => {
      const n = Number(r.amount);
      if (r.frequency === 'monthly') return n;
      if (r.frequency === 'weekly')  return Math.round(n * 52 / 12);
      if (r.frequency === 'daily')   return Math.round(n * 30);
      if (r.frequency === 'yearly')  return Math.round(n / 12);
      return n;
    };
    const now = new Date();
    const nextM = new Date(now.getFullYear(), now.getMonth() + 1, 1);
    const applicable = active.filter(r => {
      if (r.frequency === 'yearly') {
        const nd = new Date(r.next_date);
        return nd.getFullYear() === nextM.getFullYear() && nd.getMonth() === nextM.getMonth();
      }
      return true;
    });
    if (applicable.length === 0) return null;
    const income  = applicable.filter(r => r.type === 'INGRESO').reduce((a, r) => a + getMonthlyAmt(r), 0);
    const expense = applicable.filter(r => r.type === 'GASTO').reduce((a, r) => a + getMonthlyAmt(r), 0);
    const balance = income - expense;
    return { income, expense, balance, monthLabel: MONTHS[nextM.getMonth()], count: applicable.length };
  }, [recurring]);

  // ── GASTOS FIJOS (% comprometido en recurrentes) ──
  const recurringFixed = useMemo(() => {
    const active = recurring.filter(r => r.active && r.type === 'GASTO');
    if (active.length === 0) return null;
    const getAmt = (r) => {
      const n = Number(r.amount);
      if (r.frequency === 'monthly') return n;
      if (r.frequency === 'weekly')  return Math.round(n * 52 / 12);
      if (r.frequency === 'daily')   return Math.round(n * 30);
      if (r.frequency === 'yearly')  return Math.round(n / 12);
      return n;
    };
    const fixedExpense = active.reduce((a, r) => a + getAmt(r), 0);
    const base = stats.income > 0 ? stats.income : (planMes.targetIncome > 0 ? planMes.targetIncome : 0);
    const pct  = base > 0 ? Math.round((fixedExpense / base) * 100) : null;
    return { fixedExpense, pct, count: active.length };
  }, [recurring, stats, planMes]);

  // ── POSICIÓN NETA ──
  const netPosition = useMemo(() => {
    const goalsAssets = goals.reduce((a, g) => a + (g.current || 0), 0);
    const monthBalance = Math.max(0, stats.income - stats.expenses);
    const totalAssets  = goalsAssets + monthBalance;
    const pendingDebtTotal     = debts.filter(d => !d.settled).reduce((a, d) => a + (Number(d.amount) || 0), 0);
    const remainingCuotasTotal = activeCuotas.reduce((a, c) => a + (c.totalCuotas - c.paidCuotas) * c.monthlyAmount, 0);
    const totalLiabilities = pendingDebtTotal + remainingCuotasTotal;
    if (totalAssets === 0 && totalLiabilities === 0) return null;
    const netPos = totalAssets - totalLiabilities;
    const netPct = totalAssets > 0 ? Math.round((netPos / totalAssets) * 100) : null;
    return { totalAssets, totalLiabilities, netPos, netPct, goalsAssets, monthBalance, pendingDebtTotal, remainingCuotasTotal };
  }, [goals, stats, debts, activeCuotas]);

  // ── HEATMAP DE ACTIVIDAD (8 semanas) ──
  const activityHeatmap = useMemo(() => {
    const WEEKS = 8;
    const now   = new Date();
    // alinear al domingo anterior para que la grilla quede en columnas de 7
    const startDay = new Date(now);
    startDay.setDate(startDay.getDate() - (WEEKS * 7 - 1));
    const totalDays = WEEKS * 7;
    const cells = Array.from({ length: totalDays }, (_, i) => {
      const d = new Date(startDay);
      d.setDate(d.getDate() + i);
      const key = d.toISOString().slice(0, 10);
      const dayTxs  = transactions.filter(t => t.date.slice(0, 10) === key);
      const expense = dayTxs.filter(t => t.type === 'GASTO').reduce((a, c) => a + Number(c.amount), 0);
      const count   = dayTxs.length;
      const isToday = key === now.toISOString().slice(0, 10);
      return { key, expense, count, isToday, dayOfWeek: d.getDay() };
    });
    if (cells.every(c => c.count === 0)) return null;
    const maxExpense = Math.max(...cells.map(c => c.expense), 1);
    // Agrupar en semanas (columnas)
    const weeks = [];
    for (let w = 0; w < WEEKS; w++) {
      weeks.push(cells.slice(w * 7, (w + 1) * 7));
    }
    return { weeks, maxExpense, WEEKS };
  }, [transactions]);

  // ── CATEGORÍAS SIN PRESUPUESTO ──
  const unbudgetedCats = useMemo(() => {
    if (stats.expenses === 0) return null;
    const cats = activeCategories.GASTO.filter(cat => {
      const spent  = stats.expenseByCategory[cat] || 0;
      const budget = budgets[cat]?.amount || 0;
      return spent > 0 && budget === 0;
    });
    if (cats.length === 0) return null;
    const totalUnbudgeted = cats.reduce((a, cat) => a + (stats.expenseByCategory[cat] || 0), 0);
    return { cats, totalUnbudgeted };
  }, [stats, activeCategories, budgets]);

  // ── DISTRIBUCIÓN DEL SUPERÁVIT EN METAS ──
  const surplusAllocation = useMemo(() => {
    const surplus = stats.income - stats.expenses;
    if (surplus <= 500) return null;
    const pendingGoals = goals.filter(g => g.current < g.target);
    if (pendingGoals.length === 0) return null;
    const totalRemaining = pendingGoals.reduce((a, g) => a + (g.target - g.current), 0);
    if (totalRemaining === 0) return null;
    const allocations = pendingGoals
      .map(g => ({ ...g, suggested: Math.round(((g.target - g.current) / totalRemaining) * surplus) }))
      .filter(a => a.suggested > 0);
    return { surplus, allocations };
  }, [stats, goals]);

  // ── PLAN DE PAGO DE DEUDAS ──
  const debtPayoff = useMemo(() => {
    const pending = debts.filter(d => !d.settled && Number(d.amount) > 0);
    if (pending.length === 0) return null;
    const totalDebt = pending.reduce((a, d) => a + Number(d.amount), 0);
    const monthlySavings = Math.max(0, stats.income - stats.expenses);
    const debtPayment  = monthlySavings > 0 ? Math.min(monthlySavings * 0.6, totalDebt) : 0;
    const monthsToPayoff = debtPayment > 0 ? Math.ceil(totalDebt / debtPayment) : null;
    const topDebt = [...pending].sort((a, b) => Number(b.amount) - Number(a.amount))[0];
    return { pending, totalDebt, monthlySavings, monthsToPayoff, topDebt };
  }, [debts, stats]);

  // ── GASTOS HORMIGA ──
  const microSpends = useMemo(() => {
    const THRESHOLD = 5000;
    const m = currentDate.getMonth(), y = currentDate.getFullYear();
    const small = transactions.filter(t => {
      const d = new Date(t.date);
      return t.type === 'GASTO' && d.getMonth() === m && d.getFullYear() === y && Number(t.amount) < THRESHOLD;
    });
    if (small.length < 3) return null;
    const catMap = {};
    small.forEach(t => {
      if (!catMap[t.category]) catMap[t.category] = { total: 0, count: 0 };
      catMap[t.category].total += Number(t.amount);
      catMap[t.category].count++;
    });
    const total = small.reduce((a, t) => a + Number(t.amount), 0);
    if (total < 2000) return null;
    const items = Object.entries(catMap)
      .map(([cat, d]) => ({ cat, total: Math.round(d.total), count: d.count }))
      .sort((a, b) => b.total - a.total)
      .slice(0, 4);
    return { items, total: Math.round(total), annual: Math.round(total * 12), threshold: THRESHOLD };
  }, [transactions, currentDate]);

  // ── DIVERSIFICACIÓN DE INGRESOS ──
  const incomeDiversity = useMemo(() => {
    if (stats.income === 0) return null;
    const m = currentDate.getMonth(), y = currentDate.getFullYear();
    const incTxs = transactions.filter(t => {
      const d = new Date(t.date);
      return t.type === 'INGRESO' && d.getMonth() === m && d.getFullYear() === y;
    });
    if (incTxs.length === 0) return null;
    const catMap = {};
    incTxs.forEach(t => { catMap[t.category] = (catMap[t.category] || 0) + Number(t.amount); });
    const sources = Object.entries(catMap)
      .map(([cat, amount]) => ({ cat, amount: Math.round(amount), pct: Math.round((amount / stats.income) * 100) }))
      .sort((a, b) => b.amount - a.amount);
    const isConcentrated = sources.length === 1;
    return { sources, total: stats.income, topSource: sources[0], isConcentrated };
  }, [transactions, currentDate, stats.income]);

  // ── ETA DE META ──
  const goalETA = useMemo(() => {
    const active = goals.filter(g => !g.completed && g.target > 0 && g.current < g.target);
    if (active.length === 0) return null;
    const now = new Date();
    let totalSav = 0, months = 0;
    for (let i = 1; i <= 3; i++) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const mo = d.getMonth(), yr = d.getFullYear();
      const mTxs = transactions.filter(t => { const td = new Date(t.date); return td.getMonth() === mo && td.getFullYear() === yr; });
      const mInc = mTxs.filter(t => t.type === 'INGRESO').reduce((a, c) => a + Number(c.amount), 0);
      const mExp = mTxs.filter(t => t.type === 'GASTO').reduce((a, c) => a + Number(c.amount), 0);
      if (mInc > 0 || mExp > 0) { totalSav += Math.max(0, mInc - mExp); months++; }
    }
    const monthlySavings = months > 0 ? Math.round(totalSav / months) : 0;
    if (monthlySavings <= 0) return null;
    const closest = [...active].sort((a, b) => (a.target - a.current) - (b.target - b.current))[0];
    const remaining = closest.target - closest.current;
    const monthsLeft = Math.ceil(remaining / monthlySavings);
    const eta = new Date(now.getFullYear(), now.getMonth() + monthsLeft, 1);
    return { goal: closest, remaining, monthlySavings, monthsLeft, etaLabel: `${MONTHS[eta.getMonth()]} ${eta.getFullYear()}`, allGoalsCount: active.length };
  }, [goals, transactions]);

  // ── ANÁLISIS QUINCENA ──
  const quincenal = useMemo(() => {
    const m = currentDate.getMonth(), y = currentDate.getFullYear();
    const monthTxs = transactions.filter(t => { const d = new Date(t.date); return d.getMonth() === m && d.getFullYear() === y; });
    if (monthTxs.length === 0) return null;
    const first  = monthTxs.filter(t => parseInt(t.date.slice(8,10)) <= 15);
    const second = monthTxs.filter(t => parseInt(t.date.slice(8,10)) >  15);
    if (first.length === 0 || second.length === 0) return null;
    const half = (txs) => {
      const inc = txs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
      const exp = txs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0);
      return { income: inc, expense: exp, balance: inc - exp };
    };
    const h1 = half(first), h2 = half(second);
    if (h1.income === 0 && h1.expense === 0) return null;
    const heavierHalf = h1.expense >= h2.expense ? '1ª' : '2ª';
    const maxExp = Math.max(h1.expense, h2.expense, 1);
    return { h1, h2, heavierHalf, maxExp };
  }, [transactions, currentDate]);

  // ── AHORRO EN USD ──
  const usdSavings = useMemo(() => {
    if (!exchangeRate || exchangeRate <= 0 || stats.income === 0) return null;
    const balance = stats.income - stats.expenses;
    const fmt2 = (n) => (Math.round(n * 100) / 100).toLocaleString('es-AR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    const balUSD  = balance / exchangeRate;
    const incUSD  = stats.income  / exchangeRate;
    const expUSD  = stats.expenses / exchangeRate;
    const annualUSD = balUSD * 12;
    return { balance, balUSD, incUSD, expUSD, annualUSD, rate: exchangeRate, fmt2, isPositive: balance >= 0 };
  }, [stats.income, stats.expenses, exchangeRate]);

  // ── DÍAS MÁS COSTOSOS ──
  const topSpenderDay = useMemo(() => {
    const gasto = transactions.filter(t => t.type === 'GASTO');
    if (gasto.length < 10) return null;
    const dayMap = {};
    gasto.forEach(t => {
      const day = parseInt(t.date.slice(8,10));
      const mon = t.date.slice(0,7);
      if (!dayMap[day]) dayMap[day] = { total: 0, months: new Set() };
      dayMap[day].total += Number(t.amount);
      dayMap[day].months.add(mon);
    });
    const days = Object.entries(dayMap)
      .filter(([,d]) => d.months.size >= 2)
      .map(([day, d]) => ({ day: parseInt(day), avg: Math.round(d.total / d.months.size), months: d.months.size }))
      .sort((a, b) => b.avg - a.avg)
      .slice(0, 3);
    if (days.length === 0) return null;
    const maxAvg = days[0].avg;
    return { days, maxAvg };
  }, [transactions]);

  // ── PRÓXIMOS PAGOS (14 días) ──
  const nextPayments = useMemo(() => {
    const now = new Date(); now.setHours(0,0,0,0);
    const cutoff = new Date(now.getTime() + 14 * 86400000);
    const payments = [];
    bills.filter(b => b.status === 'pending').forEach(b => {
      const d = new Date(b.due_date + 'T12:00:00');
      if (d >= now && d <= cutoff) {
        const days = Math.ceil((d - now) / 86400000);
        payments.push({ id: `bill-${b.id}`, label: b.title, amount: Number(b.amount)||0, date: b.due_date, days, isIncome: false, emoji: '📅' });
      }
    });
    recurring.filter(r => r.active && r.next_date).forEach(r => {
      const d = new Date(r.next_date + 'T12:00:00');
      if (d >= now && d <= cutoff) {
        const days = Math.ceil((d - now) / 86400000);
        payments.push({ id: `rec-${r.id}`, label: r.name, amount: Number(r.amount)||0, date: r.next_date, days, isIncome: r.type==='INGRESO', emoji: r.type==='INGRESO' ? '💰' : '🔄' });
      }
    });
    if (payments.length === 0) return null;
    const sorted = payments.sort((a,b) => a.date.localeCompare(b.date));
    const totalOut = sorted.filter(p=>!p.isIncome).reduce((a,p)=>a+p.amount, 0);
    return { payments: sorted, totalOut };
  }, [bills, recurring]);

  // ── PATRÓN ESTACIONAL DE GASTOS ──
  const monthlyPattern = useMemo(() => {
    const gasto = transactions.filter(t => t.type === 'GASTO');
    if (gasto.length < 15) return null;
    const byYM = {};
    gasto.forEach(t => {
      const key = t.date.slice(0,7);
      if (!byYM[key]) byYM[key] = { m: parseInt(key.slice(5,7))-1, total: 0 };
      byYM[key].total += Number(t.amount);
    });
    const sums = Array(12).fill(0), cnts = Array(12).fill(0);
    Object.values(byYM).forEach(({ m, total }) => { sums[m] += total; cnts[m]++; });
    const avgs = sums.map((s,i) => cnts[i] > 0 ? Math.round(s / cnts[i]) : null);
    const valid = avgs.filter(v => v !== null);
    if (valid.length < 3) return null;
    const maxAvg = Math.max(...valid);
    const peakMonth = avgs.indexOf(maxAvg);
    const overallAvg = Math.round(valid.reduce((a,v)=>a+v,0)/valid.length);
    return { avgs, maxAvg, peakMonth, overallAvg };
  }, [transactions]);

  // ── MAYOR GASTO DEL MES ──
  const largestTx = useMemo(() => {
    const m = currentDate.getMonth(), y = currentDate.getFullYear();
    const monthExp = transactions.filter(t => { const d = new Date(t.date); return t.type==='GASTO' && d.getMonth()===m && d.getFullYear()===y; });
    if (monthExp.length === 0) return null;
    const largest = [...monthExp].sort((a,b) => Number(b.amount)-Number(a.amount))[0];
    const total   = monthExp.reduce((a,c)=>a+Number(c.amount),0);
    const pct     = total > 0 ? Math.round((Number(largest.amount)/total)*100) : 0;
    const dateLabel = new Date(largest.date+'T12:00:00').toLocaleDateString('es-AR',{day:'numeric',month:'short'});
    return { tx: largest, pct, dateLabel, total };
  }, [transactions, currentDate]);

  // ── PRONÓSTICO 3 MESES (recurrentes) ──
  const threeMonthForecast = useMemo(() => {
    const active = recurring.filter(r => r.active);
    if (active.length < 2) return null;
    const getAmt = (r) => {
      const n = Number(r.amount);
      if (r.frequency === 'monthly') return n;
      if (r.frequency === 'weekly')  return Math.round(n * 52/12);
      if (r.frequency === 'daily')   return Math.round(n * 30);
      if (r.frequency === 'yearly')  return Math.round(n/12);
      return n;
    };
    const now = new Date();
    const months = Array.from({length: 3}, (_, i) => {
      const d = new Date(now.getFullYear(), now.getMonth() + 1 + i, 1);
      const mo = d.getMonth(), yr = d.getFullYear();
      const forMonth = active.filter(r => r.frequency !== 'yearly' || (new Date(r.next_date).getMonth() === mo && new Date(r.next_date).getFullYear() === yr));
      const income  = forMonth.filter(r => r.type==='INGRESO').reduce((a,r)=>a+getAmt(r),0);
      const expense = forMonth.filter(r => r.type==='GASTO').reduce((a,r)=>a+getAmt(r),0);
      return { label: MONTHS[mo].slice(0,3), income, expense, balance: income - expense };
    });
    if (months.every(m => m.income===0 && m.expense===0)) return null;
    const maxVal = Math.max(...months.map(m => Math.max(m.income, m.expense)), 1);
    return { months, maxVal };
  }, [recurring]);

  // ── VICTORIAS DE PRESUPUESTO ──
  const budgetWins = useMemo(() => {
    const budgeted = activeCategories.GASTO.filter(cat => (budgets[cat]?.amount||0) > 0);
    if (budgeted.length === 0) return null;
    const wins = budgeted
      .map(cat => {
        const budget = Number(budgets[cat].amount);
        const spent  = stats.expenseByCategory[cat] || 0;
        const saved  = budget - spent;
        const pct    = Math.round((saved / budget) * 100);
        return { cat, budget, spent, saved, pct };
      })
      .filter(w => w.saved > 0 && w.pct >= 10)
      .sort((a, b) => b.saved - a.saved)
      .slice(0, 4);
    if (wins.length === 0) return null;
    const totalSaved = wins.reduce((a, w) => a + w.saved, 0);
    return { wins, totalSaved };
  }, [activeCategories, budgets, stats]);

  // ── TENDENCIA DE BALANCE 6 MESES ──
  const balanceTrend = useMemo(() => {
    const now = new Date();
    const months = Array.from({length: 6}, (_, i) => {
      const d = new Date(now.getFullYear(), now.getMonth() - 5 + i, 1);
      const y = d.getFullYear(), m = d.getMonth();
      const txs = transactions.filter(t => { const td = new Date(t.date); return td.getFullYear()===y && td.getMonth()===m; });
      const income  = txs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
      const expense = txs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0);
      const balance = income - expense;
      return { label: MONTHS[m].slice(0,3), balance, hasData: income>0||expense>0 };
    });
    const withData = months.filter(m => m.hasData);
    if (withData.length < 2) return null;
    const avg = Math.round(withData.reduce((a,m)=>a+m.balance,0) / withData.length);
    const last  = withData[withData.length-1].balance;
    const prev  = withData[withData.length-2].balance;
    const trend = last > prev ? 'up' : last < prev ? 'down' : 'flat';
    const maxAbs = Math.max(...months.map(m => Math.abs(m.balance)), 1);
    return { months, avg, last, trend, maxAbs };
  }, [transactions]);

  // ── GAUGE RATIO GASTO/INGRESO ──
  const expenseRatioGauge = useMemo(() => {
    if (stats.income === 0) return null;
    const pct = Math.round((stats.expenses / stats.income) * 100);
    const zone = pct <= 70 ? 'excellent' : pct <= 85 ? 'good' : pct <= 100 ? 'warning' : 'danger';
    const color = zone === 'excellent' ? '#10b981' : zone === 'good' ? '#6366f1' : zone === 'warning' ? '#f59e0b' : '#ef4444';
    const msg   = zone === 'excellent' ? `Ahorrás el ${100-Math.min(pct,100)}% de tus ingresos` : zone === 'good' ? 'Gastos bien controlados' : zone === 'warning' ? 'Cerca del límite de ingreso' : 'Gastos superan los ingresos';
    // Needle angle: 0% → -90° (left), 100% → 0° (top), 150%+ → 90° (right)
    const clamped = Math.min(pct, 150);
    const angle = -90 + (clamped / 150) * 180;
    return { pct, zone, color, msg, angle };
  }, [stats.income, stats.expenses]);

  // ── TIMELINE DE DEUDAS ──
  const debtTimeline = useMemo(() => {
    const pending = debts.filter(d => !d.settled && Number(d.amount) > 0);
    if (pending.length === 0) return null;
    const sorted = [...pending].sort((a, b) => Number(a.amount) - Number(b.amount));
    const maxAmount = Math.max(...sorted.map(d => Number(d.amount)), 1);
    const totalDebt = sorted.reduce((a, d) => a + Number(d.amount), 0);
    const monthlySavings = Math.max(0, stats.income - stats.expenses);
    const debtPayment = monthlySavings > 0 ? monthlySavings * 0.6 : 0;
    // Estimate months to pay each debt using avalanche method (highest first is standard, but sorted smallest first for visual)
    let cumulative = 0;
    const withETA = sorted.map(d => {
      const amt = Number(d.amount);
      const monthsFromNow = debtPayment > 0 ? Math.ceil((cumulative + amt) / debtPayment) : null;
      cumulative += amt;
      return { ...d, amount: amt, monthsFromNow };
    });
    return { debts: withETA, maxAmount, totalDebt, monthlySavings };
  }, [debts, stats]);

  // ── PROYECCIÓN DE AHORRO ──
  const savingsProjection = useMemo(() => {
    if (stats.income === 0) return null;
    const monthly = Math.max(0, stats.income - stats.expenses);
    if (monthly === 0) return null;
    const goalsTotal = goals.filter(g => !g.completed).reduce((a, g) => a + (g.target - Math.min(g.current, g.target)), 0);
    const milestones = [1, 3, 6, 12].map(m => ({ months: m, amount: Math.round(monthly * m), label: m === 1 ? '1 mes' : m === 3 ? '3 meses' : m === 6 ? '6 meses' : '1 año' }));
    const yearAmount = milestones[3].amount;
    const max = yearAmount;
    return { monthly, milestones, max, goalsTotal };
  }, [stats.income, stats.expenses, goals]);

  // ── VARIANZA POR CATEGORÍA ──
  const categoryVariance = useMemo(() => {
    const now = new Date();
    const results = activeCategories.GASTO.map(cat => {
      const sums = [];
      for (let i = 0; i < 6; i++) {
        const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
        const y = d.getFullYear(), m = d.getMonth();
        const s = transactions.filter(t => { const td = new Date(t.date); return t.type==='GASTO' && t.category===cat && td.getFullYear()===y && td.getMonth()===m; }).reduce((a,c)=>a+Number(c.amount),0);
        if (s > 0) sums.push(s);
      }
      if (sums.length < 3) return null;
      const avg = sums.reduce((a,v)=>a+v,0) / sums.length;
      const stdDev = Math.sqrt(sums.reduce((a,v)=>a+Math.pow(v-avg,2),0) / sums.length);
      const cv = avg > 0 ? Math.round((stdDev / avg) * 100) : 0;
      return { cat, avg: Math.round(avg), stdDev: Math.round(stdDev), cv };
    }).filter(Boolean);
    if (results.length < 2) return null;
    const top3 = [...results].sort((a,b) => b.cv - a.cv).slice(0,3);
    return { categories: top3 };
  }, [transactions, activeCategories]);

  // ── INGRESOS ESPERADOS VS RECIBIDOS ──
  const incomeExpectation = useMemo(() => {
    const recInc = recurring.filter(r => r.active && r.type === 'INGRESO');
    if (recInc.length === 0) return null;
    const m = currentDate.getMonth(), y = currentDate.getFullYear();
    const getAmt = (r) => { const n=Number(r.amount); if(r.frequency==='monthly')return n; if(r.frequency==='weekly')return Math.round(n*52/12); if(r.frequency==='daily')return Math.round(n*30); if(r.frequency==='yearly')return Math.round(n/12); return n; };
    const forMonth = recInc.filter(r => r.frequency !== 'yearly' || (new Date(r.next_date).getMonth()===m && new Date(r.next_date).getFullYear()===y));
    const expected = forMonth.reduce((a,r)=>a+getAmt(r),0);
    if (expected === 0) return null;
    const actual    = stats.income;
    const remaining = Math.max(0, expected - actual);
    const pct       = Math.min(100, Math.round((actual / expected) * 100));
    const items     = forMonth.map(r => ({ name: r.name, expected: getAmt(r) }));
    return { expected, actual, remaining, pct, items: items.slice(0,4), isComplete: actual >= expected };
  }, [recurring, currentDate, stats.income]);

  // ── PARETO DE GASTOS (80/20) ──
  const paretoExpenses = useMemo(() => {
    if (stats.expenses === 0) return null;
    const cats = activeCategories.GASTO
      .map(cat => ({ cat, amount: stats.expenseByCategory[cat]||0 }))
      .filter(c => c.amount > 0)
      .sort((a,b) => b.amount - a.amount);
    if (cats.length < 3) return null;
    let cumulative = 0;
    const withCum = cats.map(c => {
      cumulative += c.amount;
      return { ...c, cumPct: Math.round((cumulative / stats.expenses) * 100) };
    });
    const paretoIdx = withCum.findIndex(c => c.cumPct >= 80);
    const paretoCount = paretoIdx >= 0 ? paretoIdx + 1 : cats.length;
    const paretoPct   = Math.round((paretoCount / cats.length) * 100);
    const top = withCum.slice(0, Math.min(paretoCount + 1, 5));
    return { items: top, paretoCount, paretoPct, totalCats: cats.length };
  }, [stats, activeCategories]);

  // weeklyHeatmap — promedio de gasto por día de la semana (últimas 8 semanas)
  const weeklyHeatmap = useMemo(() => {
    const gasto = transactions.filter(t => t.type === 'GASTO');
    if (gasto.length < 7) return null;
    const now = new Date(); now.setHours(0,0,0,0);
    const cutoff = new Date(now.getTime() - 8 * 7 * 86400000);
    const recent = gasto.filter(t => { const d=new Date(t.date+'T12:00:00'); return d>=cutoff&&d<=now; });
    if (recent.length < 5) return null;
    const dowTotals = Array(7).fill(0);
    recent.forEach(t => { const d=new Date(t.date+'T12:00:00'); dowTotals[d.getDay()]+=Number(t.amount); });
    const avgs = dowTotals.map(s => Math.round(s / 8));
    const maxAvg = Math.max(...avgs, 1);
    const peakDow = avgs.indexOf(Math.max(...avgs));
    const DOW_LABELS = ['D','L','M','X','J','V','S'];
    return { avgs, maxAvg, peakDow, labels: DOW_LABELS };
  }, [transactions]);

  // liquidityRatio — meses de reserva: balance acumulado / gasto mensual promedio
  const liquidityRatio = useMemo(() => {
    if (transactions.length < 10) return null;
    const now = new Date();
    let totalExp = 0, monthCount = 0;
    for (let i = 1; i <= 3; i++) {
      const d=new Date(now.getFullYear(),now.getMonth()-i,1);
      const m=d.getMonth(), y=d.getFullYear();
      const mExp=transactions.filter(t=>{const td=new Date(t.date);return t.type==='GASTO'&&td.getMonth()===m&&td.getFullYear()===y;}).reduce((a,c)=>a+Number(c.amount),0);
      if (mExp > 0) { totalExp+=mExp; monthCount++; }
    }
    if (monthCount === 0) return null;
    const avgMonthlyExp = Math.round(totalExp / monthCount);
    if (avgMonthlyExp === 0) return null;
    const totalNet = transactions.reduce((a,t)=>t.type==='INGRESO'?a+Number(t.amount):a-Number(t.amount),0);
    const ratio = totalNet > 0 ? totalNet / avgMonthlyExp : 0;
    const zone = ratio >= 6 ? 'excellent' : ratio >= 3 ? 'good' : ratio >= 1 ? 'warning' : 'danger';
    const msg = zone==='excellent'?'Reserva sólida':zone==='good'?'Colchón saludable':zone==='warning'?'Reserva ajustada':'Sin colchón';
    const color = zone==='excellent'?'#10b981':zone==='good'?'#6366f1':zone==='warning'?'#f59e0b':'#ef4444';
    return { ratio: Math.round(ratio * 10) / 10, zone, avgMonthlyExp, totalNet: Math.round(totalNet), msg, color };
  }, [transactions]);

  // categoryLifecycle — nueva / activa / dormida por actividad últimos 6 meses
  const categoryLifecycle = useMemo(() => {
    const now = new Date();
    const months6 = Array.from({length:6},(_,i)=>{const d=new Date(now.getFullYear(),now.getMonth()-i,1);return`${d.getFullYear()}-${d.getMonth()}`;});
    const catActivity = {};
    transactions.filter(t=>t.type==='GASTO').forEach(t=>{
      const td=new Date(t.date); const key=`${td.getFullYear()}-${td.getMonth()}`;
      if(!catActivity[t.category])catActivity[t.category]=new Set();
      catActivity[t.category].add(key);
    });
    const recentKeys = months6.slice(0,2);
    const olderKeys  = months6.slice(2);
    const newCats=[], activeCats=[], dormantCats=[];
    activeCategories.GASTO.forEach(cat=>{
      const actv=catActivity[cat]||new Set();
      const hasRecent=recentKeys.some(k=>actv.has(k));
      const hasOlder =olderKeys.some(k=>actv.has(k));
      if(hasRecent&&!hasOlder) newCats.push(cat);
      else if(hasRecent&&hasOlder) activeCats.push(cat);
      else if(!hasRecent&&hasOlder) dormantCats.push(cat);
    });
    if(newCats.length===0&&dormantCats.length===0) return null;
    return { newCats, activeCats, dormantCats };
  }, [transactions, activeCategories]);

  // rule503020 — regla 50% necesidades / 30% deseos / 20% ahorro
  const rule503020 = useMemo(() => {
    if (stats.income === 0) return null;
    const needs   = activeCategories.GASTO.filter(c=>NEEDS_CATS.has(c)).reduce((a,c)=>a+(stats.expenseByCategory[c]||0),0);
    const wants   = activeCategories.GASTO.filter(c=>!NEEDS_CATS.has(c)).reduce((a,c)=>a+(stats.expenseByCategory[c]||0),0);
    const savings = Math.max(0, stats.income - stats.expenses);
    const needsPct   = Math.round((needs   / stats.income) * 100);
    const wantsPct   = Math.round((wants   / stats.income) * 100);
    const savingsPct = Math.round((savings / stats.income) * 100);
    return {
      needs:   { amount: Math.round(needs),   actual: needsPct,   target: 50 },
      wants:   { amount: Math.round(wants),   actual: wantsPct,   target: 30 },
      savings: { amount: Math.round(savings), actual: savingsPct, target: 20 },
      income:  stats.income,
    };
  }, [stats, activeCategories]);

  // noSpendStreak — racha de días consecutivos sin gastos
  const noSpendStreak = useMemo(() => {
    if (transactions.length === 0) return null;
    const spendDays = new Set(transactions.filter(t=>t.type==='GASTO').map(t=>t.date.slice(0,10)));
    if (spendDays.size === 0) return null;
    const today = new Date(); today.setHours(0,0,0,0);
    let current = 0;
    for (let d=new Date(today); current<=365; d.setDate(d.getDate()-1)) {
      const key=d.toISOString().slice(0,10);
      if(spendDays.has(key)) break;
      current++;
    }
    const allSpend=[...spendDays].sort();
    const minDate=new Date(allSpend[0]+'T12:00:00');
    let record=0, streak=0;
    for (let d=new Date(minDate); d<=today; d.setDate(d.getDate()+1)) {
      if(spendDays.has(d.toISOString().slice(0,10))){ if(streak>record)record=streak; streak=0; }
      else streak++;
    }
    if(streak>record) record=streak;
    if(current===0&&record===0) return null;
    return { current, record };
  }, [transactions]);

  // topIncomeMonths — top 3 meses por ingreso en los últimos 12 meses
  const topIncomeMonths = useMemo(() => {
    const now=new Date();
    const months=[];
    for(let i=0;i<12;i++){
      const d=new Date(now.getFullYear(),now.getMonth()-i,1);
      const y=d.getFullYear(), m=d.getMonth();
      const income=transactions.filter(t=>{const td=new Date(t.date);return t.type==='INGRESO'&&td.getFullYear()===y&&td.getMonth()===m;}).reduce((a,c)=>a+Number(c.amount),0);
      if(income>0) months.push({label:`${MONTHS[m].slice(0,3)} ${y}`,income,m,y});
    }
    if(months.length<2) return null;
    const avg=Math.round(months.reduce((a,m)=>a+m.income,0)/months.length);
    const top3=[...months].sort((a,b)=>b.income-a.income).slice(0,3);
    return { top3, avg, maxIncome: top3[0].income };
  }, [transactions]);

  // burnRate — gasto diario promedio del mes vs histórico, proyección fin de mes
  const burnRate = useMemo(() => {
    const now=new Date();
    const m=currentDate.getMonth(), y=currentDate.getFullYear();
    const daysInMonth=new Date(y,m+1,0).getDate();
    const daysPassed=(m===now.getMonth()&&y===now.getFullYear())?now.getDate():daysInMonth;
    if(daysPassed===0) return null;
    const monthExp=transactions.filter(t=>{const d=new Date(t.date);return t.type==='GASTO'&&d.getMonth()===m&&d.getFullYear()===y;});
    const totalSpent=monthExp.reduce((a,c)=>a+Number(c.amount),0);
    if(totalSpent===0) return null;
    const dailyRate=totalSpent/daysPassed;
    const projected=Math.round(dailyRate*daysInMonth);
    let histTotal=0, histDays=0;
    for(let i=1;i<=3;i++){
      const d=new Date(y,m-i,1); const hm=d.getMonth(), hy=d.getFullYear();
      const hDays=new Date(hy,hm+1,0).getDate();
      const hSpent=transactions.filter(t=>{const td=new Date(t.date);return t.type==='GASTO'&&td.getMonth()===hm&&td.getFullYear()===hy;}).reduce((a,c)=>a+Number(c.amount),0);
      if(hSpent>0){histTotal+=hSpent;histDays+=hDays;}
    }
    const histDailyRate=histDays>0?histTotal/histDays:0;
    const changeVsHist=histDailyRate>0?Math.round(((dailyRate-histDailyRate)/histDailyRate)*100):null;
    return{dailyRate:Math.round(dailyRate),projected,daysPassed,daysInMonth,totalSpent:Math.round(totalSpent),histDailyRate:Math.round(histDailyRate),changeVsHist};
  }, [transactions, currentDate]);

  // amountHistogram — distribución de gastos por rango de monto (mes actual)
  const amountHistogram = useMemo(() => {
    const m=currentDate.getMonth(), y=currentDate.getFullYear();
    const monthExp=transactions.filter(t=>{const d=new Date(t.date);return t.type==='GASTO'&&d.getMonth()===m&&d.getFullYear()===y;});
    if(monthExp.length<5) return null;
    const RANGES=[
      {label:'< $1k',   min:0,     max:1000},
      {label:'$1k–5k',  min:1000,  max:5000},
      {label:'$5k–20k', min:5000,  max:20000},
      {label:'$20k+',   min:20000, max:Infinity},
    ];
    const buckets=RANGES.map(r=>{
      const items=monthExp.filter(t=>Number(t.amount)>=r.min&&Number(t.amount)<r.max);
      const count=items.length;
      const total=Math.round(items.reduce((a,c)=>a+Number(c.amount),0));
      const pct=Math.round((count/monthExp.length)*100);
      return{label:r.label,count,total,pct};
    }).filter(b=>b.count>0);
    if(buckets.length<2) return null;
    const maxCount=Math.max(...buckets.map(b=>b.count),1);
    return{buckets,total:monthExp.length,maxCount};
  }, [transactions, currentDate]);

  // topDescriptions — notas/memos más repetidos del mes actual
  const topDescriptions = useMemo(() => {
    const m=currentDate.getMonth(), y=currentDate.getFullYear();
    const monthTxs=transactions.filter(t=>{const d=new Date(t.date);return d.getMonth()===m&&d.getFullYear()===y&&t.note&&t.note.trim().length>1;});
    if(monthTxs.length<3) return null;
    const noteMap={};
    monthTxs.forEach(t=>{
      const key=t.note.trim().toLowerCase();
      if(!noteMap[key])noteMap[key]={note:t.note.trim(),count:0,total:0};
      noteMap[key].count++;
      noteMap[key].total+=Number(t.amount);
    });
    const top5=Object.values(noteMap).filter(n=>n.count>1).sort((a,b)=>b.count-a.count).slice(0,5);
    if(top5.length===0) return null;
    return{items:top5,maxCount:top5[0].count};
  }, [transactions, currentDate]);

  // todaySummary — ingresos, gastos y últimas 3 transacciones del día de hoy
  const todaySummary = useMemo(() => {
    const todayKey = new Date().toISOString().slice(0, 10);
    const todayTxs = transactions.filter(t => t.date.slice(0, 10) === todayKey);
    if (todayTxs.length === 0) return null;
    const income  = todayTxs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
    const expense = todayTxs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0);
    const last3   = [...todayTxs].sort((a,b)=>(b.id||0)-(a.id||0)).slice(0,3);
    return { income, expense, balance: income - expense, txCount: todayTxs.length, last3 };
  }, [transactions]);

  // prevMonthCompare — comparativa mes actual vs mes anterior (ingresos, gastos, balance)
  const prevMonthCompare = useMemo(() => {
    if (prevMonth.income === 0 && prevMonth.expense === 0) return null;
    const pctChg = (curr, prev) => prev > 0 ? Math.round(((curr-prev)/prev)*100) : null;
    const currBal = stats.income - stats.expenses;
    const prevBal = prevMonth.income - prevMonth.expense;
    const balChange = prevBal !== 0 ? Math.round(((currBal-prevBal)/Math.abs(prevBal))*100) : null;
    const prevD = new Date(currentDate.getFullYear(), currentDate.getMonth()-1, 1);
    return {
      curr: { income: stats.income, expense: stats.expenses, balance: currBal, label: MONTHS[currentDate.getMonth()].slice(0,3) },
      prev: { income: prevMonth.income, expense: prevMonth.expense, balance: prevBal, label: MONTHS[prevD.getMonth()].slice(0,3) },
      incChange: pctChg(stats.income, prevMonth.income),
      expChange: pctChg(stats.expenses, prevMonth.expense),
      balChange,
    };
  }, [stats, prevMonth, currentDate]);

  // budgetCoverage — % de categorías con gasto que tienen presupuesto asignado
  const budgetCoverage = useMemo(() => {
    const activeCats = activeCategories.GASTO.filter(cat => (stats.expenseByCategory[cat]||0) > 0);
    if (activeCats.length === 0) return null;
    const withBudget = activeCats.filter(cat => Number(budgets[cat]?.amount||0) > 0);
    const noBudget   = activeCats.filter(cat => !(Number(budgets[cat]?.amount||0) > 0));
    const pct = Math.round((withBudget.length / activeCats.length) * 100);
    return { total: activeCats.length, covered: withBudget.length, noBudget, pct };
  }, [activeCategories, stats, budgets]);

  // weekOverWeek — gasto semana actual (lun–hoy) vs mismos días semana anterior
  const weekOverWeek = useMemo(() => {
    const now=new Date(); now.setHours(0,0,0,0);
    const dow=(now.getDay()+6)%7; // 0=lun, 6=dom
    const monday=new Date(now.getTime()-dow*86400000);
    const lastMonday=new Date(monday.getTime()-7*86400000);
    const gasto=transactions.filter(t=>t.type==='GASTO');
    const sumRange=(start,end)=>gasto.filter(t=>{const d=new Date(t.date+'T12:00:00');return d>=start&&d<=end;}).reduce((a,c)=>a+Number(c.amount),0);
    const curr=sumRange(monday,now);
    const prev=sumRange(lastMonday,new Date(now.getTime()-7*86400000));
    if(curr===0&&prev===0) return null;
    const pct=prev>0?Math.round(((curr-prev)/prev)*100):null;
    const days=[];
    for(let i=0;i<=dow;i++){
      const d=new Date(monday.getTime()+i*86400000);
      const key=d.toISOString().slice(0,10);
      days.push(gasto.filter(t=>t.date.slice(0,10)===key).reduce((a,c)=>a+Number(c.amount),0));
    }
    const DOW=['L','M','X','J','V','S','D'];
    return{curr:Math.round(curr),prev:Math.round(prev),diff:Math.round(curr-prev),pct,isUp:curr>prev,days,labels:DOW.slice(0,dow+1),maxDay:Math.max(...days,1)};
  }, [transactions]);

  // savingsMomentum — tendencia mensual de ahorro (últimos 4 meses)
  const savingsMomentum = useMemo(() => {
    const now=new Date();
    const savings=[];
    for(let i=4;i>=1;i--){
      const d=new Date(now.getFullYear(),now.getMonth()-i,1);
      const m=d.getMonth(), y=d.getFullYear();
      const txs=transactions.filter(t=>{const td=new Date(t.date);return td.getMonth()===m&&td.getFullYear()===y;});
      const inc=txs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
      const exp=txs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0);
      if(inc>0||exp>0) savings.push({label:MONTHS[m].slice(0,3),value:Math.round(inc-exp)});
    }
    if(savings.length<2) return null;
    const last=savings[savings.length-1].value, prev=savings[savings.length-2].value;
    const change=last-prev;
    const trend=change>500?'up':change<-500?'down':'flat';
    const avg=Math.round(savings.reduce((a,s)=>a+s.value,0)/savings.length);
    const maxAbs=Math.max(...savings.map(s=>Math.abs(s.value)),1);
    return{savings,last,prev,change,trend,avg,maxAbs};
  }, [transactions]);

  // surpriseCategory — categoría con mayor desvío positivo vs su promedio de 3 meses
  const surpriseCategory = useMemo(() => {
    const m=currentDate.getMonth(), y=currentDate.getFullYear();
    const results=activeCategories.GASTO.map(cat=>{
      const currSpent=stats.expenseByCategory[cat]||0;
      if(currSpent===0) return null;
      const prevSums=[];
      for(let i=1;i<=3;i++){
        const d=new Date(y,m-i,1); const pm=d.getMonth(), py=d.getFullYear();
        const s=transactions.filter(t=>{const td=new Date(t.date);return t.type==='GASTO'&&t.category===cat&&td.getMonth()===pm&&td.getFullYear()===py;}).reduce((a,c)=>a+Number(c.amount),0);
        if(s>0) prevSums.push(s);
      }
      if(prevSums.length===0) return null;
      const avg=prevSums.reduce((a,v)=>a+v,0)/prevSums.length;
      const ratio=avg>0?currSpent/avg:null;
      if(!ratio||ratio<1.5) return null;
      return{cat,currSpent,avg:Math.round(avg),ratio:Math.round(ratio*10)/10};
    }).filter(Boolean);
    if(results.length===0) return null;
    return results.sort((a,b)=>b.ratio-a.ratio)[0];
  }, [transactions, currentDate, stats, activeCategories]);

  // monthlyTip — consejo personalizado basado en los datos del mes
  const monthlyTip = useMemo(() => {
    if (stats.income === 0) return null;
    const tips = [];
    const rate = Math.round(((stats.income - stats.expenses) / stats.income) * 100);
    if (stats.expenses > stats.income) {
      const over = Math.round(((stats.expenses - stats.income) / stats.income) * 100);
      tips.push({ emoji: '🚨', text: `Tus gastos superan tus ingresos en un ${over}%. Revisá en qué podés recortar.`, priority: 10 });
    } else if (rate < 10) {
      tips.push({ emoji: '⚠️', text: `Estás ahorrando solo el ${rate}% de tus ingresos. La meta recomendada es al menos el 20%.`, priority: 8 });
    }
    if (surpriseCategory) {
      tips.push({ emoji: '📌', text: `Gastaste ${surpriseCategory.ratio}× más de lo habitual en "${surpriseCategory.cat}" este mes.`, priority: 7 });
    }
    if (budgetCoverage && budgetCoverage.pct < 50) {
      tips.push({ emoji: '🗓️', text: `Solo el ${budgetCoverage.pct}% de tus categorías tiene presupuesto. Asignar límites te ayuda a controlar mejor.`, priority: 6 });
    }
    if (noSpendStreak && noSpendStreak.current >= 3) {
      tips.push({ emoji: '🔥', text: `¡Llevas ${noSpendStreak.current} días seguidos sin gastar! Seguí así.`, priority: 5 });
    }
    if (rate >= 20) {
      tips.push({ emoji: '✅', text: `¡Excelente! Estás ahorrando el ${rate}% de tus ingresos este mes, por encima del 20% recomendado.`, priority: 4 });
    }
    if (tips.length === 0) return null;
    return tips.sort((a, b) => b.priority - a.priority)[0];
  }, [stats, surpriseCategory, budgetCoverage, noSpendStreak]);

  // txCounter — cantidad de transacciones del mes, comparativa vs mes anterior
  const txCounter = useMemo(() => {
    const m=currentDate.getMonth(), y=currentDate.getFullYear();
    const monthTxs=transactions.filter(t=>{const d=new Date(t.date);return d.getMonth()===m&&d.getFullYear()===y;});
    if(monthTxs.length===0) return null;
    const incCount=monthTxs.filter(t=>t.type==='INGRESO').length;
    const expCount=monthTxs.filter(t=>t.type==='GASTO').length;
    const prevD=new Date(y,m-1,1);
    const prevCount=transactions.filter(t=>{const d=new Date(t.date);return d.getMonth()===prevD.getMonth()&&d.getFullYear()===prevD.getFullYear();}).length;
    const countChange=prevCount>0?Math.round(((monthTxs.length-prevCount)/prevCount)*100):null;
    const now=new Date();
    const daysPassed=(m===now.getMonth()&&y===now.getFullYear())?now.getDate():new Date(y,m+1,0).getDate();
    const avgPerDay=Math.round((monthTxs.length/daysPassed)*10)/10;
    return{total:monthTxs.length,incCount,expCount,prevCount,countChange,avgPerDay};
  }, [transactions, currentDate]);

  // worstWeek — semana del mes con mayor gasto total + top 2 categorías
  const worstWeek = useMemo(() => {
    const m=currentDate.getMonth(), y=currentDate.getFullYear();
    const daysInMonth=new Date(y,m+1,0).getDate();
    const monthExp=transactions.filter(t=>{const d=new Date(t.date);return t.type==='GASTO'&&d.getMonth()===m&&d.getFullYear()===y;});
    if(monthExp.length<3) return null;
    const weeks=[[],[],[],[],[]];
    monthExp.forEach(t=>{const day=parseInt(t.date.slice(8,10));weeks[Math.min(4,Math.floor((day-1)/7))].push(t);});
    const weekData=weeks.map((wTxs,i)=>{
      const total=wTxs.reduce((a,c)=>a+Number(c.amount),0);
      if(total===0) return null;
      const catMap={};
      wTxs.forEach(t=>{catMap[t.category]=(catMap[t.category]||0)+Number(t.amount);});
      const top2=Object.entries(catMap).sort((a,b)=>b[1]-a[1]).slice(0,2).map(([cat,amt])=>({cat,amt:Math.round(amt)}));
      const startDay=i*7+1;
      const endDay=Math.min(i===4?99:(i+1)*7,daysInMonth);
      return{week:i+1,label:`${startDay}–${endDay}`,total:Math.round(total),top2};
    }).filter(Boolean);
    if(weekData.length<2) return null;
    const worst=[...weekData].sort((a,b)=>b.total-a.total)[0];
    return{worst,weeks:weekData,maxTotal:worst.total};
  }, [transactions, currentDate]);

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
                <button onClick={()=>{ haptic(8); setShowSearch(true); }}
                  className="p-2.5 bg-zinc-900 rounded-xl active:scale-90 transition-transform" title="Buscar transacciones">
                  <Search className="w-5 h-5 text-zinc-400"/>
                </button>
                <button onClick={()=>{ haptic(8); setShowWidgetEditor(true); }}
                  className={`p-2.5 rounded-xl active:scale-90 transition-transform ${hiddenWidgets.size > 0 ? 'bg-indigo-600/20' : 'bg-zinc-900'}`} title="Personalizar widgets">
                  <LayoutGrid className={`w-5 h-5 ${hiddenWidgets.size > 0 ? 'text-indigo-400' : 'text-zinc-400'}`}/>
                </button>
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
                  {/* Acceso rápido a meses recientes */}
                  <div className="overflow-x-auto no-scrollbar -mx-1">
                    <div className="flex gap-2 px-1" style={{width:'max-content'}}>
                      {[5,4,3,2,1,0].map(i => {
                        const d = new Date(); d.setDate(1); d.setMonth(d.getMonth()-i);
                        const isSel = d.getFullYear()===currentDate.getFullYear() && d.getMonth()===currentDate.getMonth();
                        const hasData = transactions.some(t => { const td = new Date(t.date); return td.getFullYear()===d.getFullYear() && td.getMonth()===d.getMonth(); });
                        if (!hasData && i > 0) return null;
                        return (
                          <button key={i} onClick={()=>{ setCurrentDate(new Date(d.getFullYear(),d.getMonth(),1)); haptic(8); }}
                            className={`flex-shrink-0 px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all active:scale-95
                              ${isSel ? 'bg-indigo-600 text-white shadow-md' : 'bg-zinc-900/80 text-zinc-500 border border-white/8'}`}>
                            {MONTHS[d.getMonth()].slice(0,3)}{d.getFullYear()!==new Date().getFullYear()?` ${d.getFullYear()}`:''}
                          </button>
                        );
                      }).filter(Boolean)}
                    </div>
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
                      {planMes.note && (
                        <p className="text-xs text-zinc-600 italic mt-2 px-1 border-t border-white/5 pt-2">
                          💬 {planMes.note}
                        </p>
                      )}
                    )}
                  </div>
                ) : (
                  <button onClick={() => setShowPlanEditor(true)}
                    className="w-full py-3 bg-zinc-900/20 border border-dashed border-white/10 rounded-[1.5rem] text-xs font-bold text-zinc-600 active:text-zinc-400 active:border-white/20 transition-all flex items-center justify-center gap-2">
                    <span>📋</span> Establecer plan para {MONTHS[currentDate.getMonth()]}
                  </button>
                )}

                {/* ── Gastos fijos comprometidos ── */}
                {recurringFixed && (
                  <button onClick={()=>setShowRecurringModal(true)}
                    className="flex items-center gap-3 w-full px-4 py-3 bg-zinc-900/30 rounded-2xl border border-white/5 active:bg-zinc-900/50 transition-colors">
                    <span className="text-base leading-none flex-shrink-0">📌</span>
                    <div className="flex-1 min-w-0 text-left">
                      <p className="text-xs font-bold text-zinc-400">
                        Gastos fijos recurrentes · {recurringFixed.count} ítem{recurringFixed.count!==1?'s':''}
                      </p>
                      {recurringFixed.pct !== null && (
                        <p className="text-[10px] text-zinc-600 mt-0.5">
                          {recurringFixed.pct}% de los ingresos comprometido
                        </p>
                      )}
                    </div>
                    <p className="text-sm font-black text-amber-400 flex-shrink-0">
                      ${priv(formatNumber(recurringFixed.fixedExpense))}/mes
                    </p>
                  </button>
                )}

                {/* ── Recordatorio de recurrentes ── */}
                {!isHidden('recurringAlerts') && recurringAlerts && (
                  <button onClick={()=>setShowRecurringModal(true)} className="w-full text-left">
                    <div className="bg-violet-500/6 rounded-[1.5rem] p-4 border border-violet-500/15">
                      <div className="flex items-center gap-2 mb-2.5">
                        <span className="text-base leading-none">🔔</span>
                        <p className="text-xs font-bold text-violet-300">Recurrentes sin registrar este mes</p>
                        <span className="ml-auto text-[10px] text-zinc-600">Ver →</span>
                      </div>
                      <div className="flex flex-wrap gap-2">
                        {recurringAlerts.map(r => (
                          <span key={r.id} className="flex items-center gap-1.5 bg-zinc-900/60 rounded-xl px-3 py-1.5 text-[10px] font-semibold text-zinc-300">
                            <span className="leading-none">{getEmoji(r.category)}</span>
                            {r.category}
                            {r.amount > 0 && <span className="text-violet-400 font-black">${formatNumber(r.amount)}</span>}
                          </span>
                        ))}
                      </div>
                    </div>
                  </button>
                )}

                {/* ── Regla 50/30/20 ── */}
                {!isHidden('rule503020') && rule503020 && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">⚖️</span>
                      <p className="text-xs font-bold text-zinc-300">Regla 50 / 30 / 20</p>
                      <span className="ml-auto text-[10px] text-zinc-600">sobre ingresos del mes</span>
                    </div>
                    {[
                      { label: 'Necesidades', val: rule503020.needsPct,   amount: rule503020.needs,   target: 50, status: rule503020.needsStatus   },
                      { label: 'Deseos',      val: rule503020.wantsPct,   amount: rule503020.wants,   target: 30, status: rule503020.wantsStatus   },
                      { label: 'Ahorro',      val: rule503020.savingsPct, amount: rule503020.savings, target: 20, status: rule503020.savingsStatus },
                    ].map(({ label, val, amount, target, status }) => {
                      const barColor = status === 'ok' ? '#10b981' : status === 'over' ? '#f43f5e' : '#f59e0b';
                      const textColor = status === 'ok' ? 'text-emerald-400' : status === 'over' ? 'text-rose-400' : 'text-amber-400';
                      return (
                        <div key={label} className="mb-2 last:mb-0">
                          <div className="flex items-center justify-between mb-1">
                            <span className="text-[11px] font-semibold text-zinc-400">{label}</span>
                            <div className="flex items-center gap-2">
                              <span className="text-[10px] text-zinc-600">meta {target}%</span>
                              <span className={`text-[11px] font-black ${textColor}`}>{val}%</span>
                            </div>
                          </div>
                          <div className="relative h-1.5 bg-black/40 rounded-full overflow-hidden">
                            <div className="absolute inset-y-0 left-0 rounded-full transition-all duration-700"
                              style={{ width: `${Math.min(val, 100)}%`, backgroundColor: barColor }}/>
                            <div className="absolute inset-y-0 w-px bg-white/20"
                              style={{ left: `${target}%` }}/>
                          </div>
                        </div>
                      );
                    })}
                    {rule503020.savingsStatus !== 'ok' && (
                      <p className="text-[10px] text-zinc-700 mt-2.5">
                        {rule503020.savingsPct < 20
                          ? `Ahorrás ${20 - rule503020.savingsPct}pp menos de lo ideal — intentá reducir ${rule503020.needsStatus==='over'?'necesidades':'deseos'}`
                          : `¡Superás el 20% de ahorro! 🎉`}
                      </p>
                    )}
                  </div>
                )}

                {/* ── Presupuesto diario disponible ── */}
                {!isHidden('dailyBudget') && dailyBudget && (
                  <div className={`rounded-[1.5rem] p-4 border flex items-center gap-4
                    ${dailyBudget.isOver ? 'bg-rose-500/8 border-rose-500/20' : dailyBudget.pct >= 85 ? 'bg-amber-500/8 border-amber-500/15' : 'bg-zinc-900/40 border-white/5'}`}>
                    <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 text-xl leading-none"
                      style={{background: dailyBudget.isOver ? 'rgba(244,63,94,0.12)' : 'rgba(99,102,241,0.12)'}}>
                      {dailyBudget.isOver ? '🚨' : dailyBudget.pct >= 85 ? '⚠️' : '💰'}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-xs font-bold text-zinc-400">
                        {dailyBudget.isOver ? 'Presupuesto excedido' : `Disponible por día — ${dailyBudget.daysLeft} días`}
                      </p>
                      <div className="w-full h-1 bg-black/40 rounded-full mt-1.5 overflow-hidden">
                        <div className={`h-full rounded-full transition-all duration-700 ${dailyBudget.isOver ? 'bg-rose-500' : dailyBudget.pct >= 85 ? 'bg-amber-400' : 'bg-indigo-500'}`}
                          style={{width:`${dailyBudget.pct}%`}}/>
                      </div>
                    </div>
                    <div className="text-right flex-shrink-0">
                      <p className={`text-base font-black ${dailyBudget.isOver ? 'text-rose-400' : dailyBudget.pct >= 85 ? 'text-amber-400' : 'text-indigo-300'}`}>
                        {dailyBudget.isOver ? `−${priv(formatNumber(Math.abs(dailyBudget.remaining)))}` : `$${priv(formatNumber(dailyBudget.daily))}`}
                      </p>
                      <p className="text-[9px] text-zinc-600 mt-0.5">{dailyBudget.pct}% del presupuesto</p>
                    </div>
                  </div>
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

                {/* ── Proyección fin de mes ── */}
                {!isHidden('monthProjection') && monthProjection && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">Proyección al {monthProjection.daysInMonth}</p>
                      <span className="text-[10px] text-zinc-600 font-semibold">{monthProjection.daysLeft} días restantes</span>
                    </div>
                    <div className="grid grid-cols-3 gap-2 mb-3">
                      {monthProjection.projectedIncome > 0 && (
                        <div className="bg-black/30 rounded-xl p-2.5 text-center">
                          <p className="text-[10px] text-zinc-600 mb-1">Ingresos est.</p>
                          <p className="text-xs font-black text-emerald-400">${priv(formatNumber(monthProjection.projectedIncome))}</p>
                        </div>
                      )}
                      <div className="bg-black/30 rounded-xl p-2.5 text-center">
                        <p className="text-[10px] text-zinc-600 mb-1">Gastos est.</p>
                        <p className="text-xs font-black text-rose-300">${priv(formatNumber(monthProjection.projectedExpense))}</p>
                      </div>
                      <div className={`rounded-xl p-2.5 text-center ${monthProjection.projectedBalance >= 0 ? 'bg-emerald-500/8 border border-emerald-500/15' : 'bg-rose-500/8 border border-rose-500/15'}`}>
                        <p className="text-[10px] text-zinc-600 mb-1">Balance est.</p>
                        <p className={`text-xs font-black ${monthProjection.projectedBalance >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                          {monthProjection.projectedBalance >= 0 ? '+' : ''}{priv(formatNumber(monthProjection.projectedBalance))}
                        </p>
                      </div>
                    </div>
                    {monthProjection.vsLimit && (
                      <div className={`flex items-center gap-2 text-[10px] font-bold px-3 py-2 rounded-xl ${monthProjection.vsLimit.over ? 'bg-rose-500/10 text-rose-400' : 'bg-emerald-500/10 text-emerald-400'}`}>
                        <span>{monthProjection.vsLimit.over ? '⚠️' : '✅'}</span>
                        {monthProjection.vsLimit.over
                          ? `Proyección supera el límite de gastos por $${formatNumber(monthProjection.vsLimit.diff)}`
                          : `Proyección ${formatNumber(monthProjection.vsLimit.diff)} bajo el límite de gastos`}
                      </div>
                    )}
                  </div>
                )}

                {/* ── Micro-estadísticas del mes ── */}
                {monthStats && (
                  <div className="overflow-x-auto no-scrollbar -mx-1 px-1">
                    <div className="flex gap-2.5" style={{minWidth:'max-content'}}>
                      {[
                        { icon:'📊', label:'Prom. diario', val:`$${priv(formatNumber(monthStats.avgDaily))}` },
                        { icon:'🔢', label:'Movimientos', val:String(monthStats.totalTxs) },
                        { icon:'🕊️', label:'Días en cero', val:`${monthStats.daysNoExp} de ${monthStats.daysElapsed}` },
                        ...(monthStats.peakLabel ? [{ icon:'📍', label:`Pico ${monthStats.peakLabel}`, val:`$${priv(formatNumber(monthStats.peakAmount))}` }] : []),
                      ].map(({ icon, label, val }) => (
                        <div key={label} className="bg-zinc-900/50 border border-white/6 rounded-2xl px-4 py-3 flex-shrink-0">
                          <p className="text-[9px] text-zinc-600 font-semibold mb-0.5 flex items-center gap-1">
                            <span>{icon}</span>{label}
                          </p>
                          <p className="text-sm font-black text-white">{val}</p>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* ── Top gastos del mes ── */}
                {!isHidden('topTxs') && topTxs && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-3">Top gastos del mes</p>
                    <div className="space-y-2">
                      {topTxs.map((t, i) => (
                        <button key={t.id} onClick={() => setEditingTx(t)}
                          className="w-full flex items-center gap-3 active:bg-zinc-800/40 rounded-xl px-1 py-0.5 transition-colors">
                          <span className={`text-[10px] font-black w-4 flex-shrink-0 ${i===0?'text-amber-400':i===1?'text-zinc-400':i===2?'text-orange-700':'text-zinc-700'}`}>
                            #{i+1}
                          </span>
                          <span className="text-sm leading-none flex-shrink-0">{getEmoji(t.category)}</span>
                          <span className="text-xs text-zinc-400 flex-1 truncate text-left">{t.note || t.category}</span>
                          <span className="text-xs text-zinc-600 flex-shrink-0 mr-2">
                            {new Date(t.date+'T12:00:00').toLocaleDateString('es-AR',{day:'numeric',month:'short'})}
                          </span>
                          <span className="text-sm font-black text-white flex-shrink-0">
                            ${priv(formatNumber(t.amount))}
                          </span>
                        </button>
                      ))}
                    </div>
                  </div>
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

                {/* ── Desglose fuentes de ingreso ── */}
                {incomeSourceBreakdown && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-3">Fuentes de ingreso</p>
                    <div className="space-y-2.5">
                      {incomeSourceBreakdown.map(({ cat, amount }) => {
                        const pct = Math.round((amount / stats.income) * 100);
                        return (
                          <div key={cat} className="flex items-center gap-3">
                            <span className="text-sm leading-none w-5 flex-shrink-0">{getEmoji(cat)}</span>
                            <div className="flex-1 min-w-0">
                              <div className="flex justify-between items-center mb-1">
                                <span className="text-xs text-zinc-400 font-semibold truncate">{cat}</span>
                                <span className="text-[10px] font-black text-emerald-400 ml-2">${priv(formatNumber(amount))}</span>
                              </div>
                              <div className="h-1.5 bg-black/40 rounded-full overflow-hidden">
                                <div className="h-full bg-emerald-500/60 rounded-full transition-all duration-500" style={{width:`${pct}%`}}/>
                              </div>
                            </div>
                            <span className="text-[10px] text-zinc-600 font-semibold w-8 text-right flex-shrink-0">{pct}%</span>
                          </div>
                        );
                      })}
                    </div>
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
                          <button key={i} onClick={()=>{ haptic(8); setSelectedCatDetail(d.cat); }}
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
                {!isHidden('semaforo') && budgetSemaforo && (
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

                {/* ── Alertas de gasto inusual ── */}
                {!isHidden('spendingAlerts') && spendingAlerts && (
                  <div className="bg-amber-500/5 rounded-[1.5rem] p-5 border border-amber-500/15">
                    <p className="text-sm font-bold text-amber-300 mb-3 flex items-center gap-2">
                      <span>⚠️</span> Gasto inusual este mes
                    </p>
                    <div className="space-y-2">
                      {spendingAlerts.map(({ cat, cur, avg, ratio }) => (
                        <div key={cat} className="flex items-center gap-3">
                          <span className="text-sm leading-none w-5 flex-shrink-0">{getEmoji(cat)}</span>
                          <span className="text-xs text-zinc-400 font-semibold flex-1 truncate">{cat}</span>
                          <div className="flex items-center gap-1.5 flex-shrink-0">
                            <span className="text-[10px] text-zinc-600">${formatNumber(avg)} prom.</span>
                            <span className="text-[10px] font-black text-amber-400">→ {ratio}×</span>
                            <span className="text-[10px] font-black text-rose-300">${priv(formatNumber(cur))}</span>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
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

                {/* ── Categorías vs mes anterior ── */}
                {!isHidden('catVsLastMonth') && catVsLastMonth && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-3">
                      Categorías vs {catVsLastMonth.prevMonthLabel}
                    </p>
                    <div className="space-y-2">
                      {[...catVsLastMonth.increases, ...catVsLastMonth.decreases].map(({ cat, pct }) => (
                        <div key={cat} className="flex items-center gap-3">
                          <span className="text-sm leading-none w-5 flex-shrink-0">{getEmoji(cat)}</span>
                          <span className="text-xs text-zinc-400 font-semibold flex-1 truncate">{cat}</span>
                          <div className={`flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-black flex-shrink-0
                            ${pct > 0 ? 'bg-rose-500/12 text-rose-400' : 'bg-emerald-500/12 text-emerald-400'}`}>
                            {pct > 0 ? '▲' : '▼'} {Math.abs(pct)}%
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* ── Índice de salud financiera ── */}
                {!isHidden('healthScore') && healthScore && (
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
                    {healthTrend && (
                      <div className="flex items-center justify-center gap-2 mt-3 pt-3 border-t border-white/5">
                        <span className="text-[9px] text-zinc-700 mr-1">Tendencia</span>
                        {healthTrend.map((m, i) => (
                          <div key={i} className="flex flex-col items-center gap-1">
                            <div className="w-3 h-3 rounded-full border-2" style={{backgroundColor: m.color, borderColor: m.color + '40'}}/>
                            <span className="text-[8px] text-zinc-700">{m.label}</span>
                          </div>
                        ))}
                        <div className="flex flex-col items-center gap-1 ml-1">
                          <div className="w-3 h-3 rounded-full border-2 border-white/20 bg-white/10 flex items-center justify-center">
                            <div className="w-1.5 h-1.5 rounded-full bg-white/40"/>
                          </div>
                          <span className="text-[8px] text-zinc-500 font-bold">hoy</span>
                        </div>
                      </div>
                    )}
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
                {!isHidden('weekBalance') && weekBalance && (
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
                {!isHidden('weekendAnalysis') && weekendAnalysis && (
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

                {/* ── Barras diarias del mes ── */}
                {dailyBars && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">Gastos por día — {MONTHS[currentDate.getMonth()]}</p>
                    </div>
                    <div className="overflow-x-auto no-scrollbar">
                      <div className="flex items-end gap-px" style={{minWidth: `${dailyBars.daysInMonth * 14}px`, height: '56px'}}>
                        {dailyBars.days.map(({ d, expense, income, isToday }) => {
                          const expH = expense > 0 ? Math.max(3, Math.round((expense / dailyBars.maxVal) * 48)) : 0;
                          const incH = income  > 0 ? Math.max(3, Math.round((income  / dailyBars.maxVal) * 48)) : 0;
                          return (
                            <div key={d} className="flex-1 flex flex-col items-center justify-end gap-px" style={{height:'56px'}}>
                              {incH > 0 && <div style={{height:`${incH}px`}} className={`w-full rounded-t-sm ${isToday?'bg-emerald-400':'bg-emerald-700/50'}`}/>}
                              {expH > 0 && <div style={{height:`${expH}px`}} className={`w-full ${incH>0?'':'rounded-t-sm'} ${isToday?'bg-rose-400':'bg-rose-700/50'}`}/>}
                              {expH === 0 && incH === 0 && <div style={{height:'2px'}} className="w-full bg-zinc-800/60 rounded-full mt-auto"/>}
                            </div>
                          );
                        })}
                      </div>
                    </div>
                    <div className="flex justify-between items-center mt-2">
                      <span className="text-[9px] text-zinc-700">1</span>
                      <div className="flex items-center gap-3">
                        <div className="flex items-center gap-1"><div className="w-2 h-2 rounded-sm bg-rose-500/70"/><span className="text-[9px] text-zinc-700">Gasto</span></div>
                        <div className="flex items-center gap-1"><div className="w-2 h-2 rounded-sm bg-emerald-500/70"/><span className="text-[9px] text-zinc-700">Ingreso</span></div>
                      </div>
                      <span className="text-[9px] text-zinc-700">{dailyBars.daysInMonth}</span>
                    </div>
                  </div>
                )}

                {/* ── Balance acumulado del mes ── */}
                {!isHidden('runningBalance') && runningBalance && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">Balance acumulado — día {runningBalance.day}</p>
                      <span className={`text-xs font-black px-2 py-0.5 rounded-full ${runningBalance.lastVal >= 0 ? 'bg-emerald-500/15 text-emerald-400' : 'bg-rose-500/15 text-rose-400'}`}>
                        {runningBalance.lastVal >= 0 ? '+' : ''}{priv(formatNumber(runningBalance.lastVal))}
                      </span>
                    </div>
                    <svg viewBox={`0 0 ${runningBalance.W} ${runningBalance.H}`} className="w-full h-14" preserveAspectRatio="none">
                      <defs>
                        <linearGradient id="rbGrad" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor={runningBalance.lastVal >= 0 ? '#10b981' : '#f43f5e'} stopOpacity="0.25"/>
                          <stop offset="100%" stopColor={runningBalance.lastVal >= 0 ? '#10b981' : '#f43f5e'} stopOpacity="0.02"/>
                        </linearGradient>
                      </defs>
                      {/* Zero line */}
                      {runningBalance.min < 0 && runningBalance.max > 0 && (
                        <line x1={String(4)} y1={runningBalance.zeroY} x2={String(runningBalance.W - 4)} y2={runningBalance.zeroY}
                          stroke="#3f3f46" strokeWidth="0.5" strokeDasharray="3,3"/>
                      )}
                      <path d={runningBalance.areaD} fill="url(#rbGrad)"/>
                      <path d={runningBalance.pathD} fill="none"
                        stroke={runningBalance.lastVal >= 0 ? '#10b981' : '#f43f5e'} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                    </svg>
                    <div className="flex justify-between mt-1">
                      <span className="text-[9px] text-zinc-700">1</span>
                      <span className={`text-[9px] font-bold ${runningBalance.trend >= 0 ? 'text-emerald-600' : 'text-rose-600'}`}>
                        {runningBalance.trend >= 0 ? '▲' : '▼'} tendencia
                      </span>
                      <span className="text-[9px] text-zinc-700">hoy</span>
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

                {/* ── Desglose semanal del mes ── */}
                {!isHidden('weeklyBreakdown') && weeklyBreakdown && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-3">Por semana — {MONTHS[currentDate.getMonth()]}</p>
                    <div className="space-y-2">
                      {weeklyBreakdown.weeks.map(({ wNum, label, expense, income }) => {
                        const expW = expense > 0 ? Math.max(4, Math.round((expense / weeklyBreakdown.maxVal) * 100)) : 0;
                        const incW = income  > 0 ? Math.max(4, Math.round((income  / weeklyBreakdown.maxVal) * 100)) : 0;
                        return (
                          <div key={wNum} className="flex items-center gap-3">
                            <span className="text-[10px] text-zinc-600 font-semibold w-10 flex-shrink-0">Sem {wNum}</span>
                            <div className="flex-1 space-y-1">
                              {incW > 0 && <div className="h-1.5 bg-emerald-600/50 rounded-full" style={{width:`${incW}%`}}/>}
                              {expW > 0 && <div className="h-1.5 bg-rose-600/50 rounded-full"    style={{width:`${expW}%`}}/>}
                            </div>
                            <div className="text-right flex-shrink-0 w-20">
                              {expense > 0 && <p className="text-[10px] font-black text-rose-300">−${priv(formatNumber(expense))}</p>}
                              {income  > 0 && <p className="text-[10px] font-black text-emerald-400">+${priv(formatNumber(income))}</p>}
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}

                {/* ── Progreso del año ── */}
                {!isHidden('yearProgress') && yearProgress && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex items-center justify-between mb-3">
                      <p className="text-sm font-bold text-zinc-300">Balance {yearProgress.year}</p>
                      <span className={`text-sm font-black ${yearProgress.totalBalance >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                        {yearProgress.totalBalance >= 0 ? '+' : ''}${priv(formatNumber(yearProgress.totalBalance))}
                      </span>
                    </div>
                    <div className="flex items-end gap-1.5" style={{height:'44px'}}>
                      {yearProgress.months.map(({ m, income, expense, balance }) => {
                        const incH = income  > 0 ? Math.max(3, Math.round((income  / yearProgress.maxVal) * 40)) : 0;
                        const expH = expense > 0 ? Math.max(3, Math.round((expense / yearProgress.maxVal) * 40)) : 0;
                        const isCur = m === yearProgress.maxMonth;
                        return (
                          <div key={m} className="flex-1 flex flex-col items-center gap-0.5">
                            <div className="w-full flex flex-col-reverse gap-0.5" style={{height:'40px'}}>
                              {incH > 0 && (
                                <div className={`w-full rounded-sm ${isCur ? 'bg-emerald-500' : 'bg-emerald-700/50'}`}
                                  style={{height:`${incH}px`}}/>
                              )}
                              {expH > 0 && (
                                <div className={`w-full rounded-sm ${isCur ? 'bg-rose-500' : 'bg-rose-700/40'}`}
                                  style={{height:`${expH}px`}}/>
                              )}
                              {incH === 0 && expH === 0 && (
                                <div className="w-full rounded-sm bg-zinc-800/40" style={{height:'3px'}}/>
                              )}
                            </div>
                            <span className={`text-[8px] font-semibold ${isCur ? 'text-zinc-300' : 'text-zinc-700'}`}>
                              {MONTHS[m].slice(0,3)}
                            </span>
                          </div>
                        );
                      })}
                    </div>
                    <div className="flex justify-between mt-2.5 pt-2 border-t border-white/5">
                      <div>
                        <p className="text-[9px] text-zinc-600">Ingresado</p>
                        <p className="text-xs font-black text-emerald-400">+${priv(formatNumber(yearProgress.totalIncome))}</p>
                      </div>
                      <div className="text-center">
                        <p className="text-[9px] text-zinc-600">Meses con ahorro</p>
                        <p className="text-xs font-black text-indigo-300">{yearProgress.savedMonths}/{yearProgress.months.length}</p>
                      </div>
                      <div className="text-right">
                        <p className="text-[9px] text-zinc-600">Gastado</p>
                        <p className="text-xs font-black text-rose-400">−${priv(formatNumber(yearProgress.totalExpense))}</p>
                      </div>
                    </div>
                  </div>
                )}

                {/* ── Proyección próximo mes ── */}
                {!isHidden('nextMonthForecast') && nextMonthForecast && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">🔮</span>
                      <p className="text-xs font-bold text-zinc-300">Proyección {nextMonthForecast.monthLabel} (recurrentes)</p>
                      <span className="ml-auto text-[10px] text-zinc-600">{nextMonthForecast.count} activos</span>
                    </div>
                    <div className="grid grid-cols-3 gap-3">
                      <div className="bg-emerald-500/8 rounded-2xl p-3 text-center">
                        <p className="text-[9px] text-zinc-600 mb-1">Ingresos</p>
                        <p className="text-sm font-black text-emerald-400">+${priv(formatNumber(nextMonthForecast.income))}</p>
                      </div>
                      <div className="bg-rose-500/8 rounded-2xl p-3 text-center">
                        <p className="text-[9px] text-zinc-600 mb-1">Gastos</p>
                        <p className="text-sm font-black text-rose-400">−${priv(formatNumber(nextMonthForecast.expense))}</p>
                      </div>
                      <div className={`${nextMonthForecast.balance >= 0 ? 'bg-indigo-500/8' : 'bg-rose-500/8'} rounded-2xl p-3 text-center`}>
                        <p className="text-[9px] text-zinc-600 mb-1">Balance</p>
                        <p className={`text-sm font-black ${nextMonthForecast.balance >= 0 ? 'text-indigo-300' : 'text-rose-400'}`}>
                          {nextMonthForecast.balance >= 0 ? '+' : ''}${priv(formatNumber(nextMonthForecast.balance))}
                        </p>
                      </div>
                    </div>
                  </div>
                )}

                {/* ── Inflación personal (YoY) ── */}
                {!isHidden('yoyAnalysis') && yoyAnalysis && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                    <div className="flex items-center justify-between mb-3">
                      <div className="flex items-center gap-2">
                        <span className="text-base leading-none">📉</span>
                        <p className="text-xs font-bold text-zinc-300">Inflación personal</p>
                      </div>
                      <div className="flex items-center gap-1.5">
                        <span className="text-[10px] text-zinc-600">{yoyAnalysis.lastYear} → {yoyAnalysis.curYear}</span>
                        {yoyAnalysis.totalPct !== null && (
                          <span className={`text-[11px] font-black px-2 py-0.5 rounded-full ${yoyAnalysis.totalPct > 0 ? 'bg-rose-500/15 text-rose-400' : 'bg-emerald-500/15 text-emerald-400'}`}>
                            {yoyAnalysis.totalPct > 0 ? '+' : ''}{yoyAnalysis.totalPct}%
                          </span>
                        )}
                      </div>
                    </div>
                    <div className="space-y-2">
                      {yoyAnalysis.categories.slice(0,5).map(({ cat, curAvg, prevAvg, pct }) => {
                        const barW = Math.min(100, Math.abs(pct));
                        const isUp = pct > 0;
                        return (
                          <div key={cat} className="flex items-center gap-2">
                            <span className="text-sm leading-none flex-shrink-0">{getEmoji(cat)}</span>
                            <div className="flex-1 min-w-0">
                              <div className="flex items-center justify-between mb-0.5">
                                <span className="text-[11px] text-zinc-500 truncate">{cat}</span>
                                <span className={`text-[11px] font-black ml-2 flex-shrink-0 ${isUp ? 'text-rose-400' : 'text-emerald-400'}`}>
                                  {isUp ? '+' : ''}{pct}%
                                </span>
                              </div>
                              <div className="h-1 bg-black/40 rounded-full overflow-hidden">
                                <div className={`h-full rounded-full ${isUp ? 'bg-rose-500/60' : 'bg-emerald-500/60'}`}
                                  style={{width:`${barW}%`}}/>
                              </div>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                    <p className="text-[10px] text-zinc-700 mt-2.5">
                      Promedio mensual comparado con mismo período de {yoyAnalysis.lastYear}
                    </p>
                  </div>
                )}

                {/* ── Posición neta ── */}
                {!isHidden('netPosition') && netPosition && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                    <div className="flex items-center justify-between mb-3">
                      <div className="flex items-center gap-2">
                        <span className="text-base leading-none">⚡</span>
                        <p className="text-xs font-bold text-zinc-300">Posición neta</p>
                      </div>
                      <span className={`text-sm font-black ${netPosition.netPos >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                        {netPosition.netPos >= 0 ? '+' : ''}${priv(formatNumber(netPosition.netPos))}
                      </span>
                    </div>
                    <div className="grid grid-cols-2 gap-2 mb-2">
                      <div className="bg-emerald-500/6 rounded-xl p-2.5">
                        <p className="text-[9px] text-zinc-600 mb-1">Activos</p>
                        <p className="text-xs font-black text-emerald-400">${priv(formatNumber(netPosition.totalAssets))}</p>
                        <div className="mt-1 space-y-0.5">
                          {netPosition.goalsAssets > 0 && (
                            <p className="text-[9px] text-zinc-700">Metas: ${priv(formatNumber(netPosition.goalsAssets))}</p>
                          )}
                          {netPosition.monthBalance > 0 && (
                            <p className="text-[9px] text-zinc-700">Balance mes: ${priv(formatNumber(netPosition.monthBalance))}</p>
                          )}
                        </div>
                      </div>
                      <div className="bg-rose-500/6 rounded-xl p-2.5">
                        <p className="text-[9px] text-zinc-600 mb-1">Pasivos</p>
                        <p className="text-xs font-black text-rose-400">${priv(formatNumber(netPosition.totalLiabilities))}</p>
                        <div className="mt-1 space-y-0.5">
                          {netPosition.pendingDebtTotal > 0 && (
                            <p className="text-[9px] text-zinc-700">Deudas: ${priv(formatNumber(netPosition.pendingDebtTotal))}</p>
                          )}
                          {netPosition.remainingCuotasTotal > 0 && (
                            <p className="text-[9px] text-zinc-700">Cuotas: ${priv(formatNumber(netPosition.remainingCuotasTotal))}</p>
                          )}
                        </div>
                      </div>
                    </div>
                    {netPosition.netPct !== null && (
                      <div className="h-1.5 bg-black/40 rounded-full overflow-hidden">
                        <div className={`h-full rounded-full transition-all duration-700 ${netPosition.netPos >= 0 ? 'bg-emerald-500' : 'bg-rose-500'}`}
                          style={{width:`${Math.min(100, Math.abs(netPosition.netPct))}%`}}/>
                      </div>
                    )}
                  </div>
                )}

                {/* ── Heatmap de actividad ── */}
                {!isHidden('activityHeatmap') && activityHeatmap && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">🗓️</span>
                      <p className="text-xs font-bold text-zinc-300">Actividad — últimas 8 semanas</p>
                    </div>
                    <div className="flex gap-1">
                      {activityHeatmap.weeks.map((week, wi) => (
                        <div key={wi} className="flex flex-col gap-1 flex-1">
                          {week.map((cell, di) => {
                            const intensity = cell.expense > 0
                              ? Math.max(0.15, cell.expense / activityHeatmap.maxExpense)
                              : 0;
                            const bg = intensity > 0
                              ? `rgba(244, 63, 94, ${intensity.toFixed(2)})`
                              : cell.count > 0 ? 'rgba(99,102,241,0.3)' : 'rgba(255,255,255,0.04)';
                            return (
                              <div key={di}
                                className="rounded-sm aspect-square"
                                style={{ backgroundColor: bg, outline: cell.isToday ? '1.5px solid rgba(255,255,255,0.4)' : 'none' }}
                                title={cell.expense > 0 ? `${cell.key}: $${Math.round(cell.expense)}` : cell.key}
                              />
                            );
                          })}
                        </div>
                      ))}
                    </div>
                    <div className="flex items-center justify-between mt-2">
                      <div className="flex items-center gap-1.5">
                        <div className="w-2.5 h-2.5 rounded-sm" style={{backgroundColor:'rgba(244,63,94,0.15)'}}/>
                        <span className="text-[9px] text-zinc-700">poco gasto</span>
                        <div className="w-2.5 h-2.5 rounded-sm" style={{backgroundColor:'rgba(244,63,94,0.8)'}}/>
                        <span className="text-[9px] text-zinc-700">mucho</span>
                      </div>
                      <div className="flex items-center gap-1">
                        <div className="w-2 h-2 rounded-sm outline outline-[1.5px] outline-white/40"/>
                        <span className="text-[9px] text-zinc-700">hoy</span>
                      </div>
                    </div>
                  </div>
                )}

                {/* ── Categorías sin presupuesto ── */}
                {!isHidden('unbudgetedCats') && unbudgetedCats && (
                  <button onClick={()=>{ setActiveTab('settings'); haptic(8); }}
                    className="w-full text-left bg-amber-500/6 rounded-[1.5rem] p-4 border border-amber-500/15 active:bg-amber-500/10 transition-colors">
                    <div className="flex items-center gap-2 mb-2">
                      <span className="text-base leading-none">⚠️</span>
                      <p className="text-xs font-bold text-amber-300">
                        {unbudgetedCats.cats.length} categoría{unbudgetedCats.cats.length!==1?'s':''} sin presupuesto
                      </p>
                      <span className="ml-auto text-[10px] text-zinc-600">Asignar →</span>
                    </div>
                    <div className="flex flex-wrap gap-1.5">
                      {unbudgetedCats.cats.slice(0,6).map(cat=>(
                        <span key={cat} className="flex items-center gap-1 bg-zinc-900/60 rounded-lg px-2.5 py-1 text-[10px] font-semibold text-zinc-400">
                          <span>{getEmoji(cat)}</span>{cat}
                          <span className="text-amber-400 font-black">·${formatNumber(stats.expenseByCategory[cat]||0)}</span>
                        </span>
                      ))}
                    </div>
                    <p className="text-[10px] text-zinc-700 mt-2">
                      Total sin controlar este mes: ${priv(formatNumber(unbudgetedCats.totalUnbudgeted))}
                    </p>
                  </button>
                )}

                {/* ── Distribuir superávit en metas ── */}
                {!isHidden('surplusAllocation') && surplusAllocation && (
                  <div className="bg-indigo-500/6 rounded-[1.5rem] p-4 border border-indigo-500/15">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">🎯</span>
                      <p className="text-xs font-bold text-indigo-300">Sugerencia de ahorro</p>
                      <span className="ml-auto text-[10px] text-zinc-600">
                        Superávit: +${priv(formatNumber(surplusAllocation.surplus))}
                      </span>
                    </div>
                    <div className="space-y-2">
                      {surplusAllocation.allocations.slice(0,4).map(g=>{
                        const pct = Math.round((g.current / g.target) * 100);
                        return (
                          <div key={g.id} className="flex items-center gap-3">
                            <span className="text-lg leading-none flex-shrink-0">{g.emoji}</span>
                            <div className="flex-1 min-w-0">
                              <div className="flex justify-between text-[10px] mb-0.5">
                                <span className="text-zinc-400 truncate">{g.name}</span>
                                <span className="text-zinc-600 ml-1">{pct}%</span>
                              </div>
                              <div className="h-1 bg-black/40 rounded-full overflow-hidden">
                                <div className="h-full bg-indigo-600/50 rounded-full" style={{width:`${pct}%`}}/>
                              </div>
                            </div>
                            <span className="text-xs font-black text-indigo-300 flex-shrink-0">
                              +${priv(formatNumber(g.suggested))}
                            </span>
                          </div>
                        );
                      })}
                    </div>
                    <p className="text-[10px] text-zinc-700 mt-2.5">Distribución proporcional según saldo pendiente de cada meta</p>
                  </div>
                )}

                {/* ── Plan de pago de deudas ── */}
                {!isHidden('debtPayoff') && debtPayoff && debtPayoff.monthsToPayoff !== null && (
                  <button onClick={()=>setShowDebtsModal(true)} className="w-full text-left">
                    <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                      <div className="flex items-center gap-2 mb-2.5">
                        <span className="text-base leading-none">🤝</span>
                        <p className="text-xs font-bold text-zinc-300">Plan de pago — deudas</p>
                        <span className="ml-auto text-[10px] text-zinc-600">Ver →</span>
                      </div>
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="text-[10px] text-zinc-600">Total pendiente</p>
                          <p className="text-base font-black text-rose-400">${priv(formatNumber(debtPayoff.totalDebt))}</p>
                        </div>
                        <div className="text-center">
                          <p className="text-[10px] text-zinc-600">Pagando 60% del ahorro</p>
                          <p className="text-xs font-black text-zinc-400">${priv(formatNumber(Math.min(debtPayoff.monthlySavings * 0.6, debtPayoff.totalDebt)))}/mes</p>
                        </div>
                        <div className="text-right">
                          <p className="text-[10px] text-zinc-600">Libre en</p>
                          <p className="text-base font-black text-emerald-400">
                            {debtPayoff.monthsToPayoff === 1 ? '1 mes' : `${debtPayoff.monthsToPayoff} meses`}
                          </p>
                        </div>
                      </div>
                    </div>
                  </button>
                )}

                {/* ── Gastos hormiga ── */}
                {!isHidden('microSpends') && microSpends && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">🐜</span>
                      <p className="text-xs font-bold text-zinc-300">Gastos hormiga</p>
                      <span className="ml-auto text-[10px] text-zinc-600">&lt; ${formatNumber(microSpends.threshold)}/mov.</span>
                    </div>
                    <div className="space-y-2.5 mb-3">
                      {microSpends.items.map(item => (
                        <div key={item.cat} className="flex items-center gap-2">
                          <span className="text-sm w-5 text-center flex-shrink-0">{getEmoji(item.cat)}</span>
                          <div className="flex-1 min-w-0">
                            <div className="flex justify-between text-xs mb-0.5">
                              <span className="text-zinc-400 truncate">{item.cat}</span>
                              <span className="text-zinc-200 font-semibold ml-2 flex-shrink-0">${priv(formatNumber(item.total))}</span>
                            </div>
                            <div className="h-1 bg-zinc-800 rounded-full overflow-hidden">
                              <div className="h-full bg-amber-500/60 rounded-full transition-all"
                                style={{width:`${Math.round((item.total/microSpends.total)*100)}%`}}/>
                            </div>
                          </div>
                          <span className="text-[10px] text-zinc-600 w-6 text-right flex-shrink-0">{item.count}×</span>
                        </div>
                      ))}
                    </div>
                    <div className="space-y-1 pt-2 border-t border-white/5">
                      <div className="flex items-center justify-between text-xs">
                        <span className="text-zinc-500">Total mensual</span>
                        <span className="font-bold text-amber-400">${priv(formatNumber(microSpends.total))}</span>
                      </div>
                      <div className="flex items-center justify-between text-xs">
                        <span className="text-zinc-700">Impacto anual estimado</span>
                        <span className="font-bold text-rose-400/70">${priv(formatNumber(microSpends.annual))}</span>
                      </div>
                    </div>
                  </div>
                )}

                {/* ── Diversificación de ingresos ── */}
                {!isHidden('incomeDiversity') && incomeDiversity && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">💼</span>
                      <p className="text-xs font-bold text-zinc-300">Fuentes de ingreso</p>
                      {incomeDiversity.isConcentrated && (
                        <span className="ml-auto text-[10px] bg-amber-500/15 text-amber-400 px-2 py-0.5 rounded-full font-semibold">1 fuente</span>
                      )}
                    </div>
                    <div className="space-y-2.5">
                      {incomeDiversity.sources.map(s => (
                        <div key={s.cat}>
                          <div className="flex items-center justify-between text-xs mb-1">
                            <span className="flex items-center gap-1.5">
                              <span className="text-sm">{getEmoji(s.cat)}</span>
                              <span className="text-zinc-300">{s.cat}</span>
                            </span>
                            <div className="flex items-center gap-2 flex-shrink-0">
                              <span className="text-zinc-500">${priv(formatNumber(s.amount))}</span>
                              <span className="text-emerald-400 font-bold w-8 text-right">{s.pct}%</span>
                            </div>
                          </div>
                          <div className="h-1.5 bg-zinc-800 rounded-full overflow-hidden">
                            <div className="h-full bg-emerald-500/50 rounded-full transition-all" style={{width:`${s.pct}%`}}/>
                          </div>
                        </div>
                      ))}
                    </div>
                    {incomeDiversity.isConcentrated && (
                      <p className="text-[10px] text-amber-400/70 mt-3 text-center italic">
                        Diversificar fuentes reduce el riesgo financiero
                      </p>
                    )}
                  </div>
                )}

                {/* ── ETA de meta ── */}
                {!isHidden('goalETA') && goalETA && (
                  <button onClick={() => setShowGoalsModal(true)} className="w-full text-left">
                    <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                      <div className="flex items-center gap-2 mb-3">
                        <span className="text-base leading-none">🎯</span>
                        <p className="text-xs font-bold text-zinc-300">ETA — Meta más cercana</p>
                        <span className="ml-auto text-[10px] text-zinc-600">Ver →</span>
                      </div>
                      <div className="flex items-center gap-3">
                        <span className="text-3xl leading-none flex-shrink-0">{goalETA.goal.emoji}</span>
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-bold text-white truncate">{goalETA.goal.name}</p>
                          <p className="text-[11px] text-zinc-500 mt-0.5">
                            Falta ${priv(formatNumber(goalETA.remaining))} · ahorrando ${priv(formatNumber(goalETA.monthlySavings))}/mes
                          </p>
                        </div>
                        <div className="text-right flex-shrink-0">
                          <p className="text-xs font-black text-indigo-300">{goalETA.etaLabel}</p>
                          <p className="text-[10px] text-zinc-600">
                            {goalETA.monthsLeft === 1 ? 'en 1 mes' : `en ${goalETA.monthsLeft} meses`}
                          </p>
                        </div>
                      </div>
                      {goalETA.allGoalsCount > 1 && (
                        <p className="text-[10px] text-zinc-700 mt-2.5 text-center">
                          +{goalETA.allGoalsCount - 1} meta{goalETA.allGoalsCount > 2 ? 's' : ''} activa{goalETA.allGoalsCount > 2 ? 's' : ''} más
                        </p>
                      )}
                    </div>
                  </button>
                )}

                {/* ── Análisis quincena ── */}
                {!isHidden('quincenal') && quincenal && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">🗓️</span>
                      <p className="text-xs font-bold text-zinc-300">Análisis quincena</p>
                      <span className="ml-auto text-[10px] text-rose-400/70 font-semibold">
                        Más gasto: {quincenal.heavierHalf} quincena
                      </span>
                    </div>
                    <div className="grid grid-cols-2 gap-2.5">
                      {[
                        { label: '1–15', data: quincenal.h1 },
                        { label: '16–fin', data: quincenal.h2 },
                      ].map(({ label, data }) => (
                        <div key={label}
                          className={`rounded-xl p-3 border ${data.expense === quincenal.maxExp ? 'bg-rose-500/8 border-rose-500/20' : 'bg-zinc-900/60 border-white/5'}`}>
                          <p className="text-[10px] font-bold text-zinc-500 mb-2">{label}</p>
                          <div className="space-y-1">
                            {data.income > 0 && (
                              <div className="flex justify-between text-xs">
                                <span className="text-zinc-600">Ing.</span>
                                <span className="text-emerald-400 font-semibold">${priv(formatNumber(data.income))}</span>
                              </div>
                            )}
                            <div className="flex justify-between text-xs">
                              <span className="text-zinc-600">Gasto</span>
                              <span className="text-rose-300 font-semibold">${priv(formatNumber(data.expense))}</span>
                            </div>
                            <div className="h-px bg-white/5 my-1"/>
                            <div className="flex justify-between text-xs">
                              <span className="text-zinc-600">Balance</span>
                              <span className={`font-black ${data.balance >= 0 ? 'text-indigo-300' : 'text-rose-400'}`}>
                                {data.balance >= 0 ? '+' : ''}${priv(formatNumber(data.balance))}
                              </span>
                            </div>
                          </div>
                          <div className="mt-2 h-1 bg-zinc-800 rounded-full overflow-hidden">
                            <div className="h-full bg-rose-500/60 rounded-full"
                              style={{width:`${Math.round((data.expense / quincenal.maxExp) * 100)}%`}}/>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* ── Ahorro en USD ── */}
                {!isHidden('usdSavings') && usdSavings && (
                  <div className={`rounded-[1.5rem] p-4 border ${usdSavings.isPositive ? 'bg-emerald-500/6 border-emerald-500/15' : 'bg-rose-500/6 border-rose-500/15'}`}>
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">💵</span>
                      <p className="text-xs font-bold text-zinc-300">Balance en USD</p>
                      <span className="ml-auto text-[10px] text-zinc-600">1 USD = ${formatNumber(usdSavings.rate)}</span>
                    </div>
                    <div className="flex items-end justify-between mb-3">
                      <div>
                        <p className="text-[10px] text-zinc-500 mb-0.5">Este mes</p>
                        <p className={`text-3xl font-black tabular-nums ${usdSavings.isPositive ? 'text-emerald-400' : 'text-rose-400'}`}>
                          {usdSavings.isPositive ? '+' : ''}USD {privacyMode ? '***' : usdSavings.fmt2(usdSavings.balUSD)}
                        </p>
                      </div>
                      <div className="text-right">
                        <p className="text-[10px] text-zinc-600">Proyección anual</p>
                        <p className={`text-sm font-black ${usdSavings.annualUSD >= 0 ? 'text-emerald-300' : 'text-rose-400'}`}>
                          {usdSavings.annualUSD >= 0 ? '+' : ''}USD {privacyMode ? '***' : usdSavings.fmt2(usdSavings.annualUSD)}
                        </p>
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-2 text-xs">
                      <div className="bg-black/20 rounded-xl px-3 py-2">
                        <p className="text-[10px] text-zinc-600 mb-0.5">Ingresos</p>
                        <p className="font-bold text-zinc-300">USD {privacyMode ? '***' : usdSavings.fmt2(usdSavings.incUSD)}</p>
                      </div>
                      <div className="bg-black/20 rounded-xl px-3 py-2">
                        <p className="text-[10px] text-zinc-600 mb-0.5">Gastos</p>
                        <p className="font-bold text-zinc-300">USD {privacyMode ? '***' : usdSavings.fmt2(usdSavings.expUSD)}</p>
                      </div>
                    </div>
                  </div>
                )}

                {/* ── Días más costosos ── */}
                {!isHidden('topSpenderDay') && topSpenderDay && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">📆</span>
                      <p className="text-xs font-bold text-zinc-300">Días más costosos del mes</p>
                    </div>
                    <div className="space-y-2.5">
                      {topSpenderDay.days.map((d, i) => (
                        <div key={d.day} className="flex items-center gap-3">
                          <div className={`w-8 h-8 rounded-xl flex items-center justify-center font-black text-sm flex-shrink-0
                            ${i === 0 ? 'bg-rose-500/20 text-rose-300' : i === 1 ? 'bg-amber-500/15 text-amber-400' : 'bg-zinc-800 text-zinc-400'}`}>
                            {d.day}
                          </div>
                          <div className="flex-1 min-w-0">
                            <div className="h-1.5 bg-zinc-800 rounded-full overflow-hidden">
                              <div className={`h-full rounded-full ${i === 0 ? 'bg-rose-500/70' : i === 1 ? 'bg-amber-500/60' : 'bg-zinc-600/60'}`}
                                style={{width:`${Math.round((d.avg / topSpenderDay.maxAvg) * 100)}%`}}/>
                            </div>
                          </div>
                          <div className="text-right flex-shrink-0">
                            <p className="text-xs font-black text-zinc-200">${priv(formatNumber(d.avg))}</p>
                            <p className="text-[9px] text-zinc-600">prom. {d.months} meses</p>
                          </div>
                        </div>
                      ))}
                    </div>
                    <p className="text-[10px] text-zinc-700 mt-3 text-center">Promedio de gasto histórico por día del mes</p>
                  </div>
                )}

                {/* ── Próximos pagos 14 días ── */}
                {!isHidden('nextPayments') && nextPayments && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">💳</span>
                      <p className="text-xs font-bold text-zinc-300">Próximos 14 días</p>
                      {nextPayments.totalOut > 0 && (
                        <span className="ml-auto text-xs font-black text-rose-400">${priv(formatNumber(nextPayments.totalOut))}</span>
                      )}
                    </div>
                    <div className="space-y-2">
                      {nextPayments.payments.map(p => (
                        <div key={p.id} className="flex items-center gap-2.5">
                          <div className={`w-9 h-9 rounded-xl flex items-center justify-center text-base flex-shrink-0
                            ${p.days === 0 ? 'bg-rose-500/20' : p.days <= 3 ? 'bg-amber-500/15' : 'bg-zinc-800/60'}`}>
                            {p.emoji}
                          </div>
                          <div className="flex-1 min-w-0">
                            <p className="text-xs font-semibold text-zinc-200 truncate">{p.label}</p>
                            <p className={`text-[10px] font-semibold ${p.days === 0 ? 'text-rose-400' : p.days <= 3 ? 'text-amber-400' : 'text-zinc-600'}`}>
                              {p.days === 0 ? 'Hoy' : p.days === 1 ? 'Mañana' : `en ${p.days} días`}
                            </p>
                          </div>
                          <p className={`text-xs font-black flex-shrink-0 ${p.isIncome ? 'text-emerald-400' : 'text-zinc-200'}`}>
                            {p.isIncome ? '+' : '−'}${priv(formatNumber(p.amount))}
                          </p>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* ── Patrón estacional ── */}
                {!isHidden('monthlyPattern') && monthlyPattern && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">🌡️</span>
                      <p className="text-xs font-bold text-zinc-300">Patrón estacional</p>
                      <span className="ml-auto text-[10px] text-zinc-600">
                        Pico: {MONTHS[monthlyPattern.peakMonth].slice(0,3)}
                      </span>
                    </div>
                    <div className="flex items-end gap-0.5 h-14">
                      {monthlyPattern.avgs.map((avg, i) => {
                        const h = avg !== null ? Math.round((avg / monthlyPattern.maxAvg) * 100) : 0;
                        const isPeak = i === monthlyPattern.peakMonth;
                        const isCur = i === currentDate.getMonth();
                        return (
                          <div key={i} className="flex-1 flex flex-col items-center gap-0.5">
                            <div className="w-full rounded-t-sm transition-all"
                              style={{
                                height: `${h}%`,
                                minHeight: avg !== null ? '2px' : '0',
                                backgroundColor: isPeak ? 'rgba(239,68,68,0.7)' : isCur ? 'rgba(99,102,241,0.8)' : avg !== null ? 'rgba(113,113,122,0.5)' : 'transparent',
                              }}/>
                          </div>
                        );
                      })}
                    </div>
                    <div className="flex items-center justify-between mt-1.5">
                      {['E','F','M','A','M','J','J','A','S','O','N','D'].map((l,i) => (
                        <span key={i} className={`text-[8px] flex-1 text-center font-bold
                          ${i === monthlyPattern.peakMonth ? 'text-rose-400' : i === currentDate.getMonth() ? 'text-indigo-400' : 'text-zinc-700'}`}>
                          {l}
                        </span>
                      ))}
                    </div>
                    <div className="flex items-center justify-center gap-4 mt-2 text-[9px] text-zinc-600">
                      <span><span className="text-rose-400">■</span> Pico histórico</span>
                      <span><span className="text-indigo-400">■</span> Mes actual</span>
                      <span>Prom. ${priv(formatNumber(monthlyPattern.overallAvg))}/mes</span>
                    </div>
                  </div>
                )}

                {/* ── Mayor gasto del mes ── */}
                {!isHidden('largestTx') && largestTx && (
                  <button onClick={() => setEditingTx(largestTx.tx)} className="w-full text-left">
                    <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                      <div className="flex items-center gap-2 mb-3">
                        <span className="text-base leading-none">💸</span>
                        <p className="text-xs font-bold text-zinc-300">Mayor gasto del mes</p>
                        <span className="ml-auto text-[10px] text-zinc-600">Editar →</span>
                      </div>
                      <div className="flex items-center gap-3">
                        <div className="w-12 h-12 bg-rose-500/15 rounded-xl flex items-center justify-center text-2xl flex-shrink-0">
                          {getEmoji(largestTx.tx.category)}
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-bold text-white">{largestTx.tx.category}</p>
                          {largestTx.tx.note && <p className="text-[11px] text-zinc-500 truncate italic mt-0.5">"{largestTx.tx.note}"</p>}
                          <p className="text-[10px] text-zinc-600 mt-0.5">{largestTx.dateLabel}</p>
                        </div>
                        <div className="text-right flex-shrink-0">
                          <p className="text-xl font-black text-white">${priv(formatNumber(largestTx.tx.amount))}</p>
                          <p className="text-[10px] text-rose-400 font-semibold">{largestTx.pct}% del total</p>
                        </div>
                      </div>
                    </div>
                  </button>
                )}

                {/* ── Pronóstico 3 meses ── */}
                {!isHidden('threeMonthForecast') && threeMonthForecast && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">🔭</span>
                      <p className="text-xs font-bold text-zinc-300">Pronóstico 3 meses</p>
                      <span className="ml-auto text-[10px] text-zinc-600">basado en recurrentes</span>
                    </div>
                    <div className="grid grid-cols-3 gap-2">
                      {threeMonthForecast.months.map((m, i) => (
                        <div key={i} className={`rounded-xl p-3 border ${m.balance >= 0 ? 'bg-indigo-500/6 border-indigo-500/15' : 'bg-rose-500/6 border-rose-500/15'}`}>
                          <p className="text-[10px] font-bold text-zinc-500 mb-2 text-center">{m.label}</p>
                          {m.income > 0 && (
                            <div className="flex justify-between text-[10px] mb-1">
                              <span className="text-zinc-700">Ing</span>
                              <span className="text-emerald-400 font-semibold">${priv(formatNumber(m.income))}</span>
                            </div>
                          )}
                          <div className="flex justify-between text-[10px] mb-1.5">
                            <span className="text-zinc-700">Gas</span>
                            <span className="text-rose-400 font-semibold">${priv(formatNumber(m.expense))}</span>
                          </div>
                          <div className="h-px bg-white/5 mb-1.5"/>
                          <p className={`text-xs font-black text-center ${m.balance >= 0 ? 'text-indigo-300' : 'text-rose-400'}`}>
                            {m.balance >= 0 ? '+' : ''}${priv(formatNumber(m.balance))}
                          </p>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* ── Victorias de presupuesto ── */}
                {!isHidden('budgetWins') && budgetWins && (
                  <div className="bg-emerald-500/6 rounded-[1.5rem] p-4 border border-emerald-500/15">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">🏆</span>
                      <p className="text-xs font-bold text-zinc-300">Victorias de presupuesto</p>
                      <span className="ml-auto text-xs font-black text-emerald-400">+${priv(formatNumber(budgetWins.totalSaved))}</span>
                    </div>
                    <div className="space-y-2.5">
                      {budgetWins.wins.map(w => (
                        <div key={w.cat}>
                          <div className="flex items-center justify-between text-xs mb-1">
                            <span className="flex items-center gap-1.5">
                              <span>{getEmoji(w.cat)}</span>
                              <span className="text-zinc-300">{w.cat}</span>
                            </span>
                            <div className="flex items-center gap-2 flex-shrink-0">
                              <span className="text-zinc-600">${priv(formatNumber(w.spent))} / ${priv(formatNumber(w.budget))}</span>
                              <span className="text-emerald-400 font-bold w-8 text-right">−{w.pct}%</span>
                            </div>
                          </div>
                          <div className="h-1.5 bg-zinc-800 rounded-full overflow-hidden">
                            <div className="h-full bg-emerald-500/50 rounded-full"
                              style={{width:`${Math.round((w.spent/w.budget)*100)}%`}}/>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* ── Tendencia de balance ── */}
                {!isHidden('balanceTrend') && balanceTrend && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">📊</span>
                      <p className="text-xs font-bold text-zinc-300">Tendencia de balance</p>
                      <span className={`ml-auto text-sm font-black ${balanceTrend.trend === 'up' ? 'text-emerald-400' : balanceTrend.trend === 'down' ? 'text-rose-400' : 'text-zinc-500'}`}>
                        {balanceTrend.trend === 'up' ? '↗' : balanceTrend.trend === 'down' ? '↘' : '→'}
                      </span>
                    </div>
                    {/* SVG sparkline */}
                    <svg viewBox="0 0 280 52" className="w-full h-14" preserveAspectRatio="none">
                      <defs>
                        <linearGradient id="btGrad" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor={balanceTrend.avg>=0?'#10b981':'#f43f5e'} stopOpacity="0.25"/>
                          <stop offset="100%" stopColor={balanceTrend.avg>=0?'#10b981':'#f43f5e'} stopOpacity="0.02"/>
                        </linearGradient>
                      </defs>
                      {/* Zero line */}
                      <line x1="0" y1="26" x2="280" y2="26" stroke="rgba(255,255,255,0.05)" strokeWidth="1"/>
                      {(() => {
                        const W = 280, H = 52, mid = H/2;
                        const pts = balanceTrend.months.map((m, i) => {
                          const x = (i / (balanceTrend.months.length - 1)) * W;
                          const y = mid - (m.balance / balanceTrend.maxAbs) * (mid - 4);
                          return `${x},${y}`;
                        });
                        const path = `M ${pts.join(' L ')}`;
                        const area = `M 0,${mid} L ${pts.join(' L ')} L ${W},${mid} Z`;
                        const color = balanceTrend.avg >= 0 ? '#10b981' : '#f43f5e';
                        return (
                          <>
                            <path d={area} fill="url(#btGrad)"/>
                            <path d={path} fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                            {balanceTrend.months.map((m, i) => {
                              const x = (i / (balanceTrend.months.length - 1)) * W;
                              const y = mid - (m.balance / balanceTrend.maxAbs) * (mid - 4);
                              return m.hasData ? <circle key={i} cx={x} cy={y} r="3" fill={color} opacity="0.8"/> : null;
                            })}
                          </>
                        );
                      })()}
                    </svg>
                    <div className="flex items-center justify-between mt-1.5">
                      {balanceTrend.months.map((m, i) => (
                        <span key={i} className={`text-[9px] font-bold flex-1 text-center ${m.hasData ? 'text-zinc-600' : 'text-zinc-800'}`}>{m.label}</span>
                      ))}
                    </div>
                    <div className="flex items-center justify-center gap-3 mt-2 text-[10px]">
                      <span className="text-zinc-600">Promedio</span>
                      <span className={`font-black ${balanceTrend.avg >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                        {balanceTrend.avg >= 0 ? '+' : ''}${priv(formatNumber(balanceTrend.avg))}/mes
                      </span>
                    </div>
                  </div>
                )}

                {/* ── Gauge gasto/ingreso ── */}
                {!isHidden('expenseRatioGauge') && expenseRatioGauge && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-base leading-none">🎯</span>
                      <p className="text-xs font-bold text-zinc-300">Ratio gasto / ingreso</p>
                    </div>
                    <div className="flex flex-col items-center py-2">
                      {/* Semicircle SVG gauge */}
                      <svg viewBox="0 0 140 78" className="w-40 h-auto">
                        {/* Background arc segments */}
                        {[
                          { start: -180, end: -108, color: 'rgba(16,185,129,0.25)' },
                          { start: -108, end:  -54, color: 'rgba(99,102,241,0.25)' },
                          { start:  -54, end:    0, color: 'rgba(245,158,11,0.25)' },
                          { start:    0, end:   90, color: 'rgba(239,68,68,0.25)'  },
                        ].map((seg, i) => {
                          const toRad = (deg) => (deg * Math.PI) / 180;
                          const cx = 70, cy = 70, r = 52;
                          const x1 = cx + r * Math.cos(toRad(seg.start));
                          const y1 = cy + r * Math.sin(toRad(seg.start));
                          const x2 = cx + r * Math.cos(toRad(seg.end));
                          const y2 = cy + r * Math.sin(toRad(seg.end));
                          const large = seg.end - seg.start > 180 ? 1 : 0;
                          return <path key={i} d={`M ${cx},${cy} L ${x1},${y1} A ${r},${r} 0 ${large},1 ${x2},${y2} Z`} fill={seg.color}/>;
                        })}
                        {/* Arc outline */}
                        <path d="M 18,70 A 52,52 0 0,1 122,70" fill="none" stroke="rgba(255,255,255,0.05)" strokeWidth="2"/>
                        {/* Needle */}
                        {(() => {
                          const rad = (expenseRatioGauge.angle * Math.PI) / 180;
                          const cx = 70, cy = 70, len = 44;
                          return <line x1={cx} y1={cy} x2={cx + len * Math.cos(rad)} y2={cy + len * Math.sin(rad)}
                            stroke={expenseRatioGauge.color} strokeWidth="2.5" strokeLinecap="round"/>;
                        })()}
                        <circle cx="70" cy="70" r="4" fill={expenseRatioGauge.color}/>
                        {/* Percentage text */}
                        <text x="70" y="62" textAnchor="middle" fill="white" fontSize="13" fontWeight="900">
                          {privacyMode ? '–' : `${expenseRatioGauge.pct}%`}
                        </text>
                      </svg>
                      <p className={`text-xs font-bold mt-1`} style={{color: expenseRatioGauge.color}}>
                        {expenseRatioGauge.msg}
                      </p>
                      <div className="flex items-center gap-4 mt-2 text-[10px] text-zinc-600">
                        <span><span className="text-emerald-400">■</span> &lt;70%</span>
                        <span><span className="text-indigo-400">■</span> 70–85%</span>
                        <span><span className="text-amber-400">■</span> 85–100%</span>
                        <span><span className="text-rose-400">■</span> &gt;100%</span>
                      </div>
                    </div>
                  </div>
                )}

                {/* ── Timeline de deudas ── */}
                {!isHidden('debtTimeline') && debtTimeline && (
                  <button onClick={() => setShowDebtsModal(true)} className="w-full text-left">
                    <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                      <div className="flex items-center gap-2 mb-3">
                        <span className="text-base leading-none">🧱</span>
                        <p className="text-xs font-bold text-zinc-300">Deudas pendientes</p>
                        <span className="ml-auto text-[10px] text-zinc-600">Ver →</span>
                      </div>
                      <div className="space-y-2.5">
                        {debtTimeline.debts.map((d, i) => (
                          <div key={d.id || i}>
                            <div className="flex items-center justify-between text-xs mb-1">
                              <span className="text-zinc-300 truncate max-w-[140px]">{d.name || d.creditor || `Deuda ${i+1}`}</span>
                              <div className="flex items-center gap-2 flex-shrink-0">
                                {d.monthsFromNow !== null && (
                                  <span className="text-zinc-600">{d.monthsFromNow === 1 ? '~1 mes' : `~${d.monthsFromNow} meses`}</span>
                                )}
                                <span className="text-rose-300 font-black">${priv(formatNumber(d.amount))}</span>
                              </div>
                            </div>
                            <div className="h-1.5 bg-zinc-800 rounded-full overflow-hidden">
                              <div className="h-full rounded-full"
                                style={{
                                  width: `${Math.round((d.amount / debtTimeline.maxAmount) * 100)}%`,
                                  backgroundColor: `rgba(239,68,68,${0.3 + (d.amount/debtTimeline.maxAmount)*0.5})`,
                                }}/>
                            </div>
                          </div>
                        ))}
                      </div>
                      <div className="flex items-center justify-between mt-3 pt-2.5 border-t border-white/5 text-xs">
                        <span className="text-zinc-500">Total pendiente</span>
                        <span className="font-black text-rose-400">${priv(formatNumber(debtTimeline.totalDebt))}</span>
                      </div>
                    </div>
                  </button>
                )}

                {/* ── Proyección de ahorro ── */}
                {!isHidden('savingsProjection') && savingsProjection && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">🚀</span>
                      <p className="text-xs font-bold text-zinc-300">Proyección de ahorro</p>
                      <span className="ml-auto text-[10px] text-zinc-600">${priv(formatNumber(savingsProjection.monthly))}/mes</span>
                    </div>
                    <div className="grid grid-cols-4 gap-2">
                      {savingsProjection.milestones.map((m, i) => (
                        <div key={m.months}
                          className={`rounded-xl p-2.5 border text-center transition-all
                            ${i === 3 ? 'bg-indigo-600/15 border-indigo-500/25' : 'bg-zinc-900/60 border-white/5'}`}>
                          <p className="text-[10px] text-zinc-500 mb-1">{m.label}</p>
                          <div className="mx-auto mb-1.5 rounded-sm"
                            style={{
                              width: '100%',
                              height: `${Math.round((m.amount / savingsProjection.max) * 32) + 4}px`,
                              backgroundColor: `rgba(99,102,241,${0.2 + (i / 3) * 0.5})`,
                            }}/>
                          <p className={`text-[10px] font-black ${i === 3 ? 'text-indigo-300' : 'text-zinc-300'}`}>
                            ${priv(formatNumber(m.amount))}
                          </p>
                        </div>
                      ))}
                    </div>
                    {savingsProjection.goalsTotal > 0 && (
                      <p className="text-[10px] text-zinc-700 mt-2.5 text-center">
                        Meta total pendiente: ${priv(formatNumber(savingsProjection.goalsTotal))}
                        {savingsProjection.milestones[3].amount >= savingsProjection.goalsTotal ? ' ✓ alcanzable en 1 año' : ''}
                      </p>
                    )}
                  </div>
                )}

                {/* ── Categorías impredecibles ── */}
                {!isHidden('categoryVariance') && categoryVariance && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">📉</span>
                      <p className="text-xs font-bold text-zinc-300">Categorías impredecibles</p>
                      <span className="ml-auto text-[10px] text-zinc-600">últimos 6 meses</span>
                    </div>
                    <div className="space-y-3">
                      {categoryVariance.categories.map((c, i) => (
                        <div key={c.cat}>
                          <div className="flex items-center justify-between text-xs mb-1">
                            <span className="flex items-center gap-1.5">
                              <span>{getEmoji(c.cat)}</span>
                              <span className="text-zinc-300">{c.cat}</span>
                            </span>
                            <div className="flex items-center gap-2 flex-shrink-0">
                              <span className="text-zinc-600">prom. ${priv(formatNumber(c.avg))}</span>
                              <span className={`font-bold w-10 text-right ${c.cv > 50 ? 'text-rose-400' : c.cv > 30 ? 'text-amber-400' : 'text-zinc-400'}`}>
                                ±{c.cv}%
                              </span>
                            </div>
                          </div>
                          <div className="h-1 bg-zinc-800 rounded-full overflow-hidden">
                            <div className={`h-full rounded-full ${c.cv > 50 ? 'bg-rose-500/60' : c.cv > 30 ? 'bg-amber-500/50' : 'bg-zinc-500/50'}`}
                              style={{width:`${Math.min(c.cv, 100)}%`}}/>
                          </div>
                        </div>
                      ))}
                    </div>
                    <p className="text-[10px] text-zinc-700 mt-3 text-center">Mayor variación → más difícil de presupuestar</p>
                  </div>
                )}

                {/* ── Ingresos esperados ── */}
                {!isHidden('incomeExpectation') && incomeExpectation && (
                  <div className={`rounded-[1.5rem] p-4 border ${incomeExpectation.isComplete ? 'bg-emerald-500/6 border-emerald-500/15' : 'bg-zinc-900/40 border-white/5'}`}>
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">📬</span>
                      <p className="text-xs font-bold text-zinc-300">Ingresos esperados</p>
                      <span className={`ml-auto text-xs font-black ${incomeExpectation.isComplete ? 'text-emerald-400' : 'text-amber-400'}`}>
                        {incomeExpectation.pct}%
                      </span>
                    </div>
                    <div className="h-2 bg-zinc-800 rounded-full overflow-hidden mb-3">
                      <div className={`h-full rounded-full transition-all ${incomeExpectation.isComplete ? 'bg-emerald-500' : 'bg-amber-500/70'}`}
                        style={{width:`${incomeExpectation.pct}%`}}/>
                    </div>
                    <div className="grid grid-cols-2 gap-2 mb-3">
                      <div className="bg-zinc-900/60 rounded-xl px-3 py-2">
                        <p className="text-[10px] text-zinc-600 mb-0.5">Esperado</p>
                        <p className="text-sm font-black text-zinc-300">${priv(formatNumber(incomeExpectation.expected))}</p>
                      </div>
                      <div className="bg-zinc-900/60 rounded-xl px-3 py-2">
                        <p className="text-[10px] text-zinc-600 mb-0.5">{incomeExpectation.isComplete ? 'Recibido ✓' : 'Recibido'}</p>
                        <p className={`text-sm font-black ${incomeExpectation.isComplete ? 'text-emerald-400' : 'text-zinc-300'}`}>
                          ${priv(formatNumber(incomeExpectation.actual))}
                        </p>
                      </div>
                    </div>
                    {!incomeExpectation.isComplete && incomeExpectation.remaining > 0 && (
                      <p className="text-[10px] text-amber-400/80 text-center">
                        Pendiente de recibir: ${priv(formatNumber(incomeExpectation.remaining))}
                      </p>
                    )}
                  </div>
                )}

                {/* ── Pareto de gastos ── */}
                {!isHidden('paretoExpenses') && paretoExpenses && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-4 border border-white/5">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">🍰</span>
                      <p className="text-xs font-bold text-zinc-300">Pareto de gastos</p>
                      <span className="ml-auto text-[10px] text-zinc-600">
                        {paretoExpenses.paretoCount}/{paretoExpenses.totalCats} categ. = 80%
                      </span>
                    </div>
                    <div className="space-y-1.5">
                      {paretoExpenses.items.map((item, i) => {
                        const isParetoLine = i === paretoExpenses.paretoCount - 1;
                        return (
                          <div key={item.cat}>
                            <div className="flex items-center gap-2">
                              <span className="text-sm w-5 text-center flex-shrink-0">{getEmoji(item.cat)}</span>
                              <div className="flex-1 min-w-0">
                                <div className="h-1.5 bg-zinc-800 rounded-full overflow-hidden">
                                  <div className="h-full rounded-full bg-indigo-500/60"
                                    style={{width:`${Math.round((item.amount/stats.expenses)*100)}%`}}/>
                                </div>
                              </div>
                              <span className="text-[10px] text-zinc-400 font-semibold w-8 text-right flex-shrink-0">
                                {Math.round((item.amount/stats.expenses)*100)}%
                              </span>
                              <span className="text-[10px] text-indigo-300 font-bold w-8 text-right flex-shrink-0">
                                {item.cumPct}%
                              </span>
                            </div>
                            {isParetoLine && i < paretoExpenses.items.length - 1 && (
                              <div className="flex items-center gap-2 my-1">
                                <div className="flex-1 h-px bg-indigo-500/30"/>
                                <span className="text-[9px] text-indigo-400 font-bold">80% acumulado</span>
                                <div className="flex-1 h-px bg-indigo-500/30"/>
                              </div>
                            )}
                          </div>
                        );
                      })}
                    </div>
                    <p className="text-[10px] text-zinc-700 mt-3 text-center">
                      El {paretoExpenses.paretoPct}% de tus categorías genera el 80% del gasto
                    </p>
                  </div>
                )}

                {/* ── Heatmap semanal ── */}
                {!isHidden('weeklyHeatmap') && weeklyHeatmap && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-4">
                      <p className="text-sm font-bold text-zinc-300">🟧 Heatmap semanal</p>
                      <span className="text-[10px] text-zinc-600 bg-zinc-800 px-2 py-0.5 rounded-full">últ. 8 semanas</span>
                    </div>
                    <div className="flex gap-2 items-end justify-between">
                      {weeklyHeatmap.avgs.map((avg, i) => {
                        const intensity = Math.round((avg / weeklyHeatmap.maxAvg) * 100);
                        const isPeak = i === weeklyHeatmap.peakDow;
                        const bg = isPeak
                          ? 'bg-orange-500'
                          : intensity >= 70 ? 'bg-orange-400/70'
                          : intensity >= 40 ? 'bg-orange-400/40'
                          : intensity >= 15 ? 'bg-orange-400/20'
                          : 'bg-zinc-800';
                        const h = Math.max(8, Math.round((avg / weeklyHeatmap.maxAvg) * 56));
                        return (
                          <div key={i} className="flex flex-col items-center gap-1.5 flex-1">
                            <div className={`w-full rounded-lg ${bg} transition-all`} style={{height:`${h}px`}}/>
                            <span className={`text-[10px] font-semibold ${isPeak?'text-orange-400':'text-zinc-500'}`}>
                              {weeklyHeatmap.labels[i]}
                            </span>
                          </div>
                        );
                      })}
                    </div>
                    <p className="text-[10px] text-zinc-600 mt-3 text-center">
                      Día pico: <span className="text-orange-400 font-semibold">{['Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado'][weeklyHeatmap.peakDow]}</span>
                      {' · '}prom. <span className="text-zinc-400">{priv(`$${formatNumber(weeklyHeatmap.avgs[weeklyHeatmap.peakDow])}`)}</span>
                    </p>
                  </div>
                )}

                {/* ── Ratio de liquidez ── */}
                {!isHidden('liquidityRatio') && liquidityRatio && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">💧 Ratio de liquidez</p>
                      <span className="text-[10px] px-2 py-0.5 rounded-full font-semibold"
                        style={{background:`${liquidityRatio.color}22`,color:liquidityRatio.color}}>
                        {liquidityRatio.msg}
                      </span>
                    </div>
                    <div className="flex items-end gap-3 mb-3">
                      <span className="text-4xl font-black" style={{color:liquidityRatio.color}}>
                        {priv(`${liquidityRatio.ratio}×`)}
                      </span>
                      <span className="text-xs text-zinc-500 mb-1.5">meses de reserva</span>
                    </div>
                    <div className="w-full bg-zinc-800 rounded-full h-2 mb-3 overflow-hidden">
                      <div className="h-2 rounded-full transition-all"
                        style={{width:`${Math.min(100, Math.round((liquidityRatio.ratio/6)*100))}%`, background:liquidityRatio.color}}/>
                    </div>
                    <div className="flex justify-between text-[10px] text-zinc-600">
                      <span>Balance: <span className="text-zinc-400">{priv(`$${formatNumber(liquidityRatio.totalNet)}`)}</span></span>
                      <span>Gasto/mes: <span className="text-zinc-400">{priv(`$${formatNumber(liquidityRatio.avgMonthlyExp)}`)}</span></span>
                    </div>
                    <p className="text-[10px] text-zinc-700 mt-2 text-center">Objetivo saludable: 3–6 meses</p>
                  </div>
                )}

                {/* ── Ciclo de categorías ── */}
                {!isHidden('categoryLifecycle') && categoryLifecycle && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-3">🔄 Ciclo de categorías</p>
                    {categoryLifecycle.newCats.length > 0 && (
                      <div className="mb-3">
                        <p className="text-[10px] text-emerald-400 font-semibold uppercase tracking-wide mb-1.5">🆕 Emergentes</p>
                        <div className="flex flex-wrap gap-1.5">
                          {categoryLifecycle.newCats.map(cat => (
                            <span key={cat} className="text-[11px] bg-emerald-500/15 text-emerald-400 border border-emerald-500/20 px-2.5 py-0.5 rounded-full">{cat}</span>
                          ))}
                        </div>
                      </div>
                    )}
                    {categoryLifecycle.activeCats.length > 0 && (
                      <div className="mb-3">
                        <p className="text-[10px] text-indigo-400 font-semibold uppercase tracking-wide mb-1.5">✅ Activas ({categoryLifecycle.activeCats.length})</p>
                        <div className="flex flex-wrap gap-1.5">
                          {categoryLifecycle.activeCats.slice(0,5).map(cat => (
                            <span key={cat} className="text-[11px] bg-indigo-500/10 text-indigo-400/80 border border-indigo-500/15 px-2 py-0.5 rounded-full">{cat}</span>
                          ))}
                          {categoryLifecycle.activeCats.length > 5 && (
                            <span className="text-[11px] text-zinc-600">+{categoryLifecycle.activeCats.length-5} más</span>
                          )}
                        </div>
                      </div>
                    )}
                    {categoryLifecycle.dormantCats.length > 0 && (
                      <div>
                        <p className="text-[10px] text-zinc-500 font-semibold uppercase tracking-wide mb-1.5">💤 Dormidas</p>
                        <div className="flex flex-wrap gap-1.5">
                          {categoryLifecycle.dormantCats.map(cat => (
                            <span key={cat} className="text-[11px] bg-zinc-800 text-zinc-600 border border-zinc-700/50 px-2 py-0.5 rounded-full">{cat}</span>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                )}

                {/* ── Regla 50/30/20 ── */}
                {!isHidden('rule503020') && rule503020 && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-4">📐 Regla 50/30/20</p>
                    {[
                      { key: 'needs',   label: 'Necesidades', emoji: '🏠', color: '#6366f1' },
                      { key: 'wants',   label: 'Deseos',      emoji: '🛍️', color: '#f59e0b' },
                      { key: 'savings', label: 'Ahorro',      emoji: '💰', color: '#10b981' },
                    ].map(({ key, label, emoji, color }) => {
                      const d = rule503020[key];
                      const diff = d.actual - d.target;
                      const isOk = key === 'savings' ? diff >= 0 : diff <= 0;
                      return (
                        <div key={key} className="mb-3 last:mb-0">
                          <div className="flex justify-between items-center mb-1">
                            <span className="text-xs text-zinc-400">{emoji} {label}</span>
                            <div className="flex items-center gap-2">
                              <span className="text-xs font-semibold" style={{color}}>{d.actual}%</span>
                              <span className={`text-[10px] ${isOk?'text-emerald-400':'text-rose-400'}`}>
                                {diff>0?'+':''}{diff}% vs {d.target}%
                              </span>
                            </div>
                          </div>
                          <div className="w-full bg-zinc-800 rounded-full h-1.5 overflow-hidden">
                            <div className="h-1.5 rounded-full transition-all"
                              style={{width:`${Math.min(100,d.actual)}%`, background: isOk ? color : '#ef4444'}}/>
                          </div>
                        </div>
                      );
                    })}
                    <p className="text-[10px] text-zinc-700 mt-3 text-center">
                      {priv(`Ingresos: $${formatNumber(rule503020.income)}`)}
                    </p>
                  </div>
                )}

                {/* ── Racha sin gastos ── */}
                {!isHidden('noSpendStreak') && noSpendStreak && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">🔥 Racha sin gastos</p>
                      {noSpendStreak.record > 0 && (
                        <span className="text-[10px] bg-amber-500/15 text-amber-400 border border-amber-500/20 px-2 py-0.5 rounded-full">
                          🏆 récord: {noSpendStreak.record}d
                        </span>
                      )}
                    </div>
                    <div className="flex items-end gap-2 mb-2">
                      <span className="text-5xl font-black text-white">{noSpendStreak.current}</span>
                      <span className="text-sm text-zinc-500 mb-2">días seguidos</span>
                    </div>
                    <p className="text-xs text-zinc-500">
                      {noSpendStreak.current === 0
                        ? 'Hoy registraste un gasto'
                        : noSpendStreak.current >= noSpendStreak.record
                        ? '¡Igualaste o superaste tu récord! 🎉'
                        : `${noSpendStreak.record - noSpendStreak.current} días para el récord`}
                    </p>
                  </div>
                )}

                {/* ── Top 3 meses de ingreso ── */}
                {!isHidden('topIncomeMonths') && topIncomeMonths && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-4">
                      <p className="text-sm font-bold text-zinc-300">📊 Mejores meses de ingreso</p>
                      <span className="text-[10px] text-zinc-600">últ. 12 meses</span>
                    </div>
                    {topIncomeMonths.top3.map((mo, i) => {
                      const pct    = Math.round((mo.income / topIncomeMonths.maxIncome) * 100);
                      const vsAvg  = Math.round(((mo.income - topIncomeMonths.avg) / topIncomeMonths.avg) * 100);
                      const medals = ['🥇','🥈','🥉'];
                      return (
                        <div key={i} className="flex items-center gap-3 mb-3 last:mb-0">
                          <span className="text-lg">{medals[i]}</span>
                          <div className="flex-1">
                            <div className="flex justify-between items-center mb-1">
                              <span className="text-xs text-zinc-400">{mo.label}</span>
                              <span className="text-xs font-semibold text-zinc-200">{priv(`$${formatNumber(mo.income)}`)}</span>
                            </div>
                            <div className="w-full bg-zinc-800 rounded-full h-1.5 overflow-hidden">
                              <div className="h-1.5 bg-indigo-500 rounded-full" style={{width:`${pct}%`}}/>
                            </div>
                          </div>
                          <span className={`text-[10px] w-12 text-right ${vsAvg>=0?'text-emerald-400':'text-rose-400'}`}>
                            {vsAvg>=0?'+':''}{vsAvg}%
                          </span>
                        </div>
                      );
                    })}
                    <p className="text-[10px] text-zinc-700 mt-2 text-center">
                      Promedio 12m: {priv(`$${formatNumber(topIncomeMonths.avg)}`)}
                    </p>
                  </div>
                )}

                {/* ── Velocidad de gasto ── */}
                {!isHidden('burnRate') && burnRate && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">⚡ Velocidad de gasto</p>
                      <span className="text-[10px] text-zinc-600 bg-zinc-800 px-2 py-0.5 rounded-full">
                        día {burnRate.daysPassed}/{burnRate.daysInMonth}
                      </span>
                    </div>
                    <div className="flex items-end gap-2 mb-3">
                      <span className="text-3xl font-black text-white">{priv(`$${formatNumber(burnRate.dailyRate)}`)}</span>
                      <span className="text-xs text-zinc-500 mb-1">/ día</span>
                    </div>
                    {burnRate.changeVsHist !== null && (
                      <p className={`text-xs mb-3 ${burnRate.changeVsHist > 0 ? 'text-rose-400' : 'text-emerald-400'}`}>
                        {burnRate.changeVsHist > 0 ? '▲' : '▼'} {Math.abs(burnRate.changeVsHist)}% vs prom. histórico ({priv(`$${formatNumber(burnRate.histDailyRate)}`)} /día)
                      </p>
                    )}
                    <div className="w-full bg-zinc-800 rounded-full h-1.5 overflow-hidden mb-3">
                      <div className="h-1.5 bg-violet-500 rounded-full"
                        style={{width:`${Math.round((burnRate.daysPassed/burnRate.daysInMonth)*100)}%`}}/>
                    </div>
                    <p className="text-[10px] text-zinc-600 text-center">
                      Proyección fin de mes: {priv(`$${formatNumber(burnRate.projected)}`)}
                    </p>
                  </div>
                )}

                {/* ── Histograma de montos ── */}
                {!isHidden('amountHistogram') && amountHistogram && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-4">
                      <p className="text-sm font-bold text-zinc-300">🗂️ Histograma de montos</p>
                      <span className="text-[10px] text-zinc-600">{amountHistogram.total} gastos</span>
                    </div>
                    <div className="space-y-2.5">
                      {amountHistogram.buckets.map((b, i) => (
                        <div key={i}>
                          <div className="flex justify-between items-center mb-1">
                            <span className="text-xs text-zinc-400">{b.label}</span>
                            <span className="text-[10px] text-zinc-500">{b.count} op. · {b.pct}%</span>
                          </div>
                          <div className="w-full bg-zinc-800 rounded-full h-2 overflow-hidden">
                            <div className="h-2 bg-indigo-500/70 rounded-full"
                              style={{width:`${Math.round((b.count/amountHistogram.maxCount)*100)}%`}}/>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* ── Notas frecuentes ── */}
                {!isHidden('topDescriptions') && topDescriptions && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-3">💬 Notas frecuentes</p>
                    <div className="space-y-2">
                      {topDescriptions.items.map((item, i) => (
                        <div key={i} className="flex items-center gap-2.5">
                          <div className="flex-1 bg-zinc-800 rounded-full h-6 overflow-hidden relative">
                            <div className="h-6 bg-violet-500/25 rounded-full absolute top-0 left-0"
                              style={{width:`${Math.round((item.count/topDescriptions.maxCount)*100)}%`}}/>
                            <span className="absolute left-3 top-0 bottom-0 flex items-center text-[11px] text-zinc-300 truncate pr-2">
                              "{item.note}"
                            </span>
                          </div>
                          <span className="text-xs font-semibold text-zinc-400 w-6 text-right shrink-0">{item.count}×</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* ── Resumen de hoy ── */}
                {!isHidden('todaySummary') && todaySummary && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">📅 Hoy</p>
                      <span className="text-[10px] text-zinc-600 bg-zinc-800 px-2 py-0.5 rounded-full">
                        {todaySummary.txCount} movimiento{todaySummary.txCount !== 1 ? 's' : ''}
                      </span>
                    </div>
                    <div className="flex gap-3 mb-3">
                      {todaySummary.income > 0 && (
                        <div className="flex-1 bg-emerald-500/10 rounded-xl p-3 border border-emerald-500/15">
                          <p className="text-[10px] text-emerald-400 mb-0.5">Ingresos</p>
                          <p className="text-sm font-bold text-emerald-300">{priv(`$${formatNumber(todaySummary.income)}`)}</p>
                        </div>
                      )}
                      {todaySummary.expense > 0 && (
                        <div className="flex-1 bg-rose-500/10 rounded-xl p-3 border border-rose-500/15">
                          <p className="text-[10px] text-rose-400 mb-0.5">Gastos</p>
                          <p className="text-sm font-bold text-rose-300">{priv(`$${formatNumber(todaySummary.expense)}`)}</p>
                        </div>
                      )}
                    </div>
                    <div className="space-y-1.5">
                      {todaySummary.last3.map((t, i) => (
                        <div key={i} className="flex justify-between items-center py-1 border-b border-white/5 last:border-0">
                          <span className="text-[11px] text-zinc-400 truncate flex-1">{t.note || t.category}</span>
                          <span className={`text-[11px] font-semibold ml-2 shrink-0 ${t.type==='INGRESO'?'text-emerald-400':'text-rose-400'}`}>
                            {t.type==='INGRESO'?'+':'-'}{priv(`$${formatNumber(Number(t.amount))}`)}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* ── Comparativa mes anterior ── */}
                {!isHidden('prevMonthCompare') && prevMonthCompare && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-4">⚖️ Comparativa mes anterior</p>
                    <div className="grid grid-cols-3 gap-1 text-center mb-2">
                      <div/>
                      <div className="text-[10px] text-zinc-500 font-semibold uppercase">{prevMonthCompare.prev.label}</div>
                      <div className="text-[10px] text-indigo-400 font-semibold uppercase">{prevMonthCompare.curr.label}</div>
                    </div>
                    {[
                      { label: 'Ingresos', prev: prevMonthCompare.prev.income,  curr: prevMonthCompare.curr.income,  chg: prevMonthCompare.incChange, goodIfUp: true  },
                      { label: 'Gastos',   prev: prevMonthCompare.prev.expense, curr: prevMonthCompare.curr.expense, chg: prevMonthCompare.expChange, goodIfUp: false },
                      { label: 'Balance',  prev: prevMonthCompare.prev.balance, curr: prevMonthCompare.curr.balance, chg: prevMonthCompare.balChange, goodIfUp: true  },
                    ].map(row => {
                      const isGood = row.chg !== null && (row.goodIfUp ? row.chg >= 0 : row.chg <= 0);
                      return (
                        <div key={row.label} className="grid grid-cols-3 gap-1 items-center py-2 border-b border-white/5 last:border-0">
                          <span className="text-[11px] text-zinc-500">{row.label}</span>
                          <span className="text-[11px] text-zinc-400 text-center">{priv(`$${formatNumber(row.prev)}`)}</span>
                          <div className="flex items-center justify-center gap-1">
                            <span className="text-[11px] font-semibold text-zinc-200">{priv(`$${formatNumber(row.curr)}`)}</span>
                            {row.chg !== null && (
                              <span className={`text-[9px] font-bold ${isGood ? 'text-emerald-400' : 'text-rose-400'}`}>
                                {row.chg > 0 ? '▲' : '▼'}{Math.abs(row.chg)}%
                              </span>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}

                {/* ── Cobertura de presupuesto ── */}
                {!isHidden('budgetCoverage') && budgetCoverage && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">🧩 Cobertura de presupuesto</p>
                      <span className={`text-[11px] font-bold px-2 py-0.5 rounded-full ${budgetCoverage.pct >= 80 ? 'bg-emerald-500/15 text-emerald-400' : budgetCoverage.pct >= 50 ? 'bg-amber-500/15 text-amber-400' : 'bg-rose-500/15 text-rose-400'}`}>
                        {budgetCoverage.pct}%
                      </span>
                    </div>
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-2xl font-black text-white">{budgetCoverage.covered}</span>
                      <span className="text-xs text-zinc-500">/ {budgetCoverage.total} categorías con presupuesto</span>
                    </div>
                    <div className="w-full bg-zinc-800 rounded-full h-2 overflow-hidden mb-3">
                      <div className="h-2 rounded-full transition-all"
                        style={{width:`${budgetCoverage.pct}%`, background: budgetCoverage.pct >= 80 ? '#10b981' : budgetCoverage.pct >= 50 ? '#f59e0b' : '#ef4444'}}/>
                    </div>
                    {budgetCoverage.noBudget.length > 0 && (
                      <div>
                        <p className="text-[10px] text-zinc-600 mb-1.5">Sin presupuesto:</p>
                        <div className="flex flex-wrap gap-1.5">
                          {budgetCoverage.noBudget.map(cat => (
                            <span key={cat} className="text-[11px] bg-zinc-800 text-zinc-500 border border-zinc-700/50 px-2 py-0.5 rounded-full">{cat}</span>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                )}

                {/* ── Semana vs semana ── */}
                {!isHidden('weekOverWeek') && weekOverWeek && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">🌓 Semana vs semana</p>
                      {weekOverWeek.pct !== null && (
                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${weekOverWeek.isUp ? 'bg-rose-500/15 text-rose-400' : 'bg-emerald-500/15 text-emerald-400'}`}>
                          {weekOverWeek.isUp ? '▲' : '▼'} {Math.abs(weekOverWeek.pct)}%
                        </span>
                      )}
                    </div>
                    <div className="flex gap-4 mb-4">
                      <div>
                        <p className="text-[10px] text-zinc-500 mb-0.5">Esta semana</p>
                        <p className="text-xl font-black text-white">{priv(`$${formatNumber(weekOverWeek.curr)}`)}</p>
                      </div>
                      <div className="border-l border-white/8 pl-4">
                        <p className="text-[10px] text-zinc-500 mb-0.5">Semana pasada</p>
                        <p className="text-xl font-black text-zinc-500">{priv(`$${formatNumber(weekOverWeek.prev)}`)}</p>
                      </div>
                    </div>
                    <div className="flex gap-1.5 items-end">
                      {weekOverWeek.days.map((d, i) => {
                        const h = Math.max(6, Math.round((d / weekOverWeek.maxDay) * 44));
                        const isToday = i === weekOverWeek.days.length - 1;
                        return (
                          <div key={i} className="flex flex-col items-center gap-1 flex-1">
                            <div className={`w-full rounded-md ${isToday ? 'bg-indigo-500' : 'bg-zinc-700'}`} style={{height:`${h}px`}}/>
                            <span className={`text-[9px] ${isToday ? 'text-indigo-400' : 'text-zinc-600'}`}>{weekOverWeek.labels[i]}</span>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}

                {/* ── Momentum de ahorro ── */}
                {!isHidden('savingsMomentum') && savingsMomentum && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-3">📈 Momentum de ahorro</p>
                    <div className="flex items-center gap-3 mb-4">
                      <span className={`text-3xl ${savingsMomentum.trend==='up'?'text-emerald-400':savingsMomentum.trend==='down'?'text-rose-400':'text-zinc-400'}`}>
                        {savingsMomentum.trend==='up'?'↗':savingsMomentum.trend==='down'?'↘':'→'}
                      </span>
                      <div>
                        <p className="text-lg font-black text-white">{priv(`$${formatNumber(savingsMomentum.last)}`)}</p>
                        <p className={`text-xs ${savingsMomentum.change>=0?'text-emerald-400':'text-rose-400'}`}>
                          {savingsMomentum.change>=0?'+':''}{priv(`$${formatNumber(savingsMomentum.change)}`)} vs mes anterior
                        </p>
                      </div>
                    </div>
                    <div className="flex gap-1.5 items-end">
                      {savingsMomentum.savings.map((s, i) => {
                        const isPos = s.value >= 0;
                        const h = Math.max(4, Math.round((Math.abs(s.value) / savingsMomentum.maxAbs) * 40));
                        const isLast = i === savingsMomentum.savings.length - 1;
                        return (
                          <div key={i} className="flex flex-col items-center gap-1 flex-1">
                            <div className={`w-full rounded-md ${isPos ? (isLast ? 'bg-emerald-500' : 'bg-emerald-500/40') : (isLast ? 'bg-rose-500' : 'bg-rose-500/40')}`} style={{height:`${h}px`}}/>
                            <span className="text-[9px] text-zinc-600">{s.label}</span>
                          </div>
                        );
                      })}
                    </div>
                    <p className="text-[10px] text-zinc-700 mt-2 text-center">
                      Promedio: {priv(`$${formatNumber(savingsMomentum.avg)}`)} / mes
                    </p>
                  </div>
                )}

                {/* ── Categoría sorpresa ── */}
                {!isHidden('surpriseCategory') && surpriseCategory && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-3">🏷️ Categoría sorpresa</p>
                    <div className="flex items-center gap-3 mb-3">
                      <span className="text-3xl bg-amber-500/15 rounded-xl p-2">⚠️</span>
                      <div>
                        <p className="text-base font-bold text-amber-300">{surpriseCategory.cat}</p>
                        <p className="text-xs text-zinc-400">
                          {surpriseCategory.ratio}× tu promedio habitual
                        </p>
                      </div>
                    </div>
                    <div className="flex gap-3">
                      <div className="flex-1 bg-zinc-800 rounded-xl p-3">
                        <p className="text-[10px] text-zinc-500 mb-0.5">Este mes</p>
                        <p className="text-sm font-bold text-amber-300">{priv(`$${formatNumber(surpriseCategory.currSpent)}`)}</p>
                      </div>
                      <div className="flex-1 bg-zinc-800 rounded-xl p-3">
                        <p className="text-[10px] text-zinc-500 mb-0.5">Prom. 3 meses</p>
                        <p className="text-sm font-bold text-zinc-400">{priv(`$${formatNumber(surpriseCategory.avg)}`)}</p>
                      </div>
                    </div>
                  </div>
                )}

                {/* ── Consejo del mes ── */}
                {!isHidden('monthlyTip') && monthlyTip && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-3">💡 Consejo del mes</p>
                    <div className="flex gap-3 items-start">
                      <span className="text-2xl shrink-0">{monthlyTip.emoji}</span>
                      <p className="text-sm text-zinc-400 leading-relaxed">{monthlyTip.text}</p>
                    </div>
                  </div>
                )}

                {/* ── Contador de transacciones ── */}
                {!isHidden('txCounter') && txCounter && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">🔢 Transacciones del mes</p>
                      {txCounter.countChange !== null && (
                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${txCounter.countChange > 0 ? 'bg-rose-500/15 text-rose-400' : 'bg-emerald-500/15 text-emerald-400'}`}>
                          {txCounter.countChange > 0 ? '▲' : '▼'} {Math.abs(txCounter.countChange)}% vs mes ant.
                        </span>
                      )}
                    </div>
                    <div className="flex items-end gap-2 mb-3">
                      <span className="text-4xl font-black text-white">{txCounter.total}</span>
                      <span className="text-xs text-zinc-500 mb-1.5">operaciones</span>
                    </div>
                    <div className="flex gap-3 mb-3">
                      <div className="flex-1 flex items-center gap-2">
                        <div className="w-2 h-2 rounded-full bg-emerald-500 shrink-0"/>
                        <span className="text-xs text-zinc-400">{txCounter.incCount} ingresos</span>
                      </div>
                      <div className="flex-1 flex items-center gap-2">
                        <div className="w-2 h-2 rounded-full bg-rose-500 shrink-0"/>
                        <span className="text-xs text-zinc-400">{txCounter.expCount} gastos</span>
                      </div>
                    </div>
                    <p className="text-[10px] text-zinc-600 text-center">
                      Promedio: {txCounter.avgPerDay} operaciones/día
                      {txCounter.prevCount > 0 && ` · mes anterior: ${txCounter.prevCount}`}
                    </p>
                  </div>
                )}

                {/* ── Peor semana del mes ── */}
                {!isHidden('worstWeek') && worstWeek && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-3">📉 Peor semana del mes</p>
                    <div className="flex items-center gap-3 mb-4">
                      <span className="text-xs text-zinc-500 bg-zinc-800 px-2.5 py-1 rounded-full">
                        días {worstWeek.worst.label}
                      </span>
                      <span className="text-lg font-black text-rose-400">{priv(`$${formatNumber(worstWeek.worst.total)}`)}</span>
                    </div>
                    <div className="flex gap-1.5 items-end mb-3">
                      {worstWeek.weeks.map((w, i) => {
                        const h = Math.max(6, Math.round((w.total / worstWeek.maxTotal) * 48));
                        const isWorst = w.week === worstWeek.worst.week;
                        return (
                          <div key={i} className="flex flex-col items-center gap-1 flex-1">
                            <div className={`w-full rounded-md ${isWorst ? 'bg-rose-500' : 'bg-zinc-700'}`} style={{height:`${h}px`}}/>
                            <span className={`text-[9px] ${isWorst ? 'text-rose-400' : 'text-zinc-600'}`}>S{w.week}</span>
                          </div>
                        );
                      })}
                    </div>
                    {worstWeek.worst.top2.length > 0 && (
                      <div>
                        <p className="text-[10px] text-zinc-600 mb-1.5">Categorías que más aportaron:</p>
                        <div className="flex gap-2">
                          {worstWeek.worst.top2.map((c, i) => (
                            <div key={i} className="flex-1 bg-zinc-800 rounded-xl p-2.5">
                              <p className="text-[10px] text-zinc-400 truncate">{c.cat}</p>
                              <p className="text-xs font-semibold text-zinc-300">{priv(`$${formatNumber(c.amt)}`)}</p>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
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

                {/* ── Racha de registro ── */}
                {!isHidden('registroStreak') && registroStreak >= 2 && (
                  <div className={`rounded-[1.5rem] p-4 border flex items-center gap-3
                    ${registroStreak >= 14 ? 'bg-violet-500/8 border-violet-500/20' : registroStreak >= 7 ? 'bg-indigo-500/8 border-indigo-500/15' : 'bg-zinc-900/30 border-white/5'}`}>
                    <span className="text-2xl leading-none flex-shrink-0">
                      {registroStreak >= 14 ? '💜' : registroStreak >= 7 ? '⚡' : '📝'}
                    </span>
                    <div className="flex-1 min-w-0">
                      <p className="text-xs font-bold text-white">Racha de registro</p>
                      <p className="text-[10px] text-zinc-500 mt-0.5">
                        {registroStreak >= 14 ? '¡Registrando a diario!' : 'Seguís registrando tus movimientos'}
                      </p>
                    </div>
                    <span className={`text-3xl font-black tabular-nums flex-shrink-0
                      ${registroStreak >= 14 ? 'text-violet-400' : registroStreak >= 7 ? 'text-indigo-400' : 'text-zinc-400'}`}>
                      {registroStreak}
                    </span>
                    <span className="text-[9px] text-zinc-600 flex-shrink-0 self-end mb-1">días</span>
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

                {/* Montos frecuentes para la categoría seleccionada */}
                {category && (() => {
                  const key = `${type}::${category}`;
                  const freqs = frequentAmounts[key];
                  if (!freqs || freqs.length === 0) return null;
                  return (
                    <div className="overflow-x-auto no-scrollbar -mx-1">
                      <div className="flex gap-2 px-1 items-center" style={{width:'max-content'}}>
                        <span className="text-[10px] text-zinc-700 font-semibold flex-shrink-0">Usados en {category}:</span>
                        {freqs.map(v=>(
                          <button key={v} onClick={()=>{ setAmount(String(v)); haptic(8); }}
                            className={`px-3.5 py-1.5 rounded-xl text-xs font-black whitespace-nowrap transition-all active:scale-95 flex items-center gap-1
                              ${amount===String(v)
                                ? type==='GASTO'?'bg-rose-600 text-white':'bg-emerald-600 text-white'
                                : 'bg-indigo-600/15 text-indigo-300 border border-indigo-500/25'}`}>
                            <span className="text-[9px]">★</span>${formatNumber(v)}
                          </button>
                        ))}
                      </div>
                    </div>
                  );
                })()}

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
                <button onClick={() => { setCalendarView(v => !v); haptic(8); }}
                  className={`p-2.5 rounded-xl active:scale-90 transition-transform ${calendarView ? 'bg-violet-600 text-white' : 'bg-zinc-900 text-zinc-500 border border-white/8'}`}
                  title={calendarView ? 'Vista lista' : 'Vista calendario'}>
                  <Calendar className="w-4 h-4"/>
                </button>
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

            {/* Vista Calendario */}
            {calendarView && (() => {
              const cyear = currentDate.getFullYear(), cmonth = currentDate.getMonth();
              const firstDow = new Date(cyear, cmonth, 1).getDay();
              const daysInMon = new Date(cyear, cmonth + 1, 0).getDate();
              const todayKey  = new Date().toISOString().slice(0, 10);
              const dayMap = {};
              filteredTxs.forEach(t => {
                const k = t.date.slice(0, 10);
                if (!dayMap[k]) dayMap[k] = { income: 0, expense: 0 };
                if (t.type === 'INGRESO') dayMap[k].income += Number(t.amount);
                else dayMap[k].expense += Number(t.amount);
              });
              const maxExp = Math.max(...Object.values(dayMap).map(d => d.expense), 1);
              const DOW = ['D','L','M','M','J','V','S'];
              const cells = [];
              for (let i = 0; i < firstDow; i++) cells.push(null);
              for (let d = 1; d <= daysInMon; d++) cells.push(d);
              return (
                <div className="px-5">
                  <div className="bg-zinc-900/40 rounded-2xl border border-white/5 p-4 space-y-3">
                    <div className="grid grid-cols-7 gap-1">
                      {DOW.map((d,i) => (
                        <div key={i} className="text-center text-[10px] font-bold text-zinc-600 pb-1">{d}</div>
                      ))}
                      {cells.map((day, i) => {
                        if (!day) return <div key={`ep-${i}`}/>;
                        const key = `${cyear}-${String(cmonth+1).padStart(2,'0')}-${String(day).padStart(2,'0')}`;
                        const data = dayMap[key];
                        const isToday    = key === todayKey;
                        const isSelected = filterDate === key;
                        const intensity  = data ? Math.min(1, data.expense / maxExp) : 0;
                        const hasExpense = data?.expense > 0;
                        const hasIncome  = data?.income > 0 && !hasExpense;
                        return (
                          <button key={key}
                            onClick={() => { setFilterDate(isSelected ? '' : key); if (!isSelected) setAllMonths(true); haptic(8); }}
                            className={`aspect-square flex flex-col items-center justify-center rounded-xl transition-all active:scale-90
                              ${isSelected ? 'ring-2 ring-indigo-400' : ''}
                              ${isToday    ? 'ring-1 ring-white/30'   : ''}`}
                            style={{ backgroundColor: hasExpense ? `rgba(239,68,68,${0.08+intensity*0.52})` : hasIncome ? 'rgba(52,211,153,0.15)' : 'transparent' }}>
                            <span className={`text-[11px] font-bold leading-none
                              ${isSelected ? 'text-white' : isToday ? 'text-indigo-300' : data ? 'text-zinc-200' : 'text-zinc-600'}`}>
                              {day}
                            </span>
                            {data && (
                              <span className="w-1 h-1 rounded-full mt-0.5"
                                style={{ backgroundColor: hasExpense ? `rgba(239,68,68,${0.5+intensity*0.5})` : 'rgba(52,211,153,0.7)' }}/>
                            )}
                          </button>
                        );
                      })}
                    </div>
                    <div className="flex items-center justify-center gap-4 text-[10px] text-zinc-600 pt-1">
                      <span className="flex items-center gap-1.5">
                        <span className="w-2.5 h-2.5 rounded-sm bg-rose-500/40 inline-block"/>Gastos
                      </span>
                      <span className="flex items-center gap-1.5">
                        <span className="w-2.5 h-2.5 rounded-sm bg-emerald-500/40 inline-block"/>Solo ingresos
                      </span>
                      {filterDate && (
                        <button onClick={()=>{ setFilterDate(''); haptic(8); }}
                          className="font-bold text-indigo-400 active:opacity-60">
                          × Limpiar día
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              );
            })()}

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
                {activeCategories.GASTO.map((cat,i)=>{
                  const spark = catSparklines[cat];
                  return (
                  <div key={cat} className={`flex items-center gap-3 px-5 py-3.5 ${i<activeCategories.GASTO.length-1?'border-b border-white/5':''}`}>
                    <div className="flex items-center gap-2 flex-1 min-w-0">
                      <span className="text-lg leading-none flex-shrink-0">{getEmoji(cat)}</span>
                      <div className="min-w-0">
                        <span className="text-sm font-semibold text-zinc-300 block truncate">{cat}</span>
                        {spark && spark.vals.some(v=>v>0) && (
                          <svg width="36" height="14" className="mt-0.5">
                            {spark.vals.map((v,idx)=>{
                              const barH = Math.max(2, Math.round((v/spark.maxVal)*12));
                              const x = idx * 13;
                              const isCur = idx === 2;
                              return <rect key={idx} x={x} y={14-barH} width={10} height={barH}
                                rx="2" fill={isCur ? '#6366f1' : '#3f3f46'}/>;
                            })}
                          </svg>
                        )}
                      </div>
                    </div>
                    <input type="text" value={formatNumber(budgets[cat]?.amount||0)}
                      onChange={async e=>{ const v=parseFormattedNumber(e.target.value); await updateBudget(cat,v); }}
                      className="bg-transparent text-right font-bold text-sm w-24 focus:outline-none focus:text-indigo-400 transition-colors flex-shrink-0"
                      inputMode="numeric"/>
                  </div>
                  );
                })}
              </div>
              <button onClick={suggestBudgets}
                className="w-full py-3.5 bg-indigo-600/15 border border-indigo-500/25 rounded-2xl text-sm font-semibold text-indigo-400 active:bg-indigo-600/25 transition-colors flex items-center justify-center gap-2">
                <span className="text-base leading-none">🪄</span>
                Sugerir del historial (+5% buffer)
              </button>
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
              <button onClick={()=>{ haptic(10); setShowCompareModal(true); }}
                className="w-full py-4 bg-zinc-900/40 border border-white/5 rounded-2xl text-sm font-semibold text-zinc-400 active:bg-zinc-900 transition-colors flex items-center justify-center gap-2">
                <span className="text-base leading-none">⚖️</span>
                Comparar dos meses
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
                <button onClick={exportAllJSON} className="flex items-center gap-3 px-5 py-4 w-full border-b border-white/5 active:bg-zinc-900/60 transition-colors">
                  <span className="text-base leading-none w-4 text-center">📦</span>
                  <span className="text-sm font-semibold text-zinc-300">Backup JSON completo</span>
                </button>
                <button onClick={()=>importFileRef.current?.click()} className="flex items-center gap-3 px-5 py-4 w-full border-b border-white/5 active:bg-zinc-900/60 transition-colors">
                  <span className="text-base leading-none w-4 text-center">📥</span>
                  <span className="text-sm font-semibold text-zinc-300">Restaurar backup JSON</span>
                </button>
                <button onClick={() => setShowPlazoFijo(true)} className="flex items-center gap-3 px-5 py-4 w-full border-b border-white/5 active:bg-zinc-900/60 transition-colors">
                  <span className="text-base leading-none w-4 text-center">🏦</span>
                  <span className="text-sm font-semibold text-zinc-300">Calculadora plazo fijo</span>
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
          MODAL: Detalle de categoría
      ════════════════════════════════ */}
      {selectedCatDetail && (
        <CategoryDetailModal
          cat={selectedCatDetail}
          transactions={transactions}
          currentDate={currentDate}
          getEmoji={getEmoji}
          formatNumber={formatNumber}
          MONTHS={MONTHS}
          onClose={() => setSelectedCatDetail(null)}
          onGoToHistory={() => { setSelectedCatDetail(null); goToCategory(selectedCatDetail, 'GASTO'); }}
        />
      )}

      {/* ════════════════════════════════
          MODAL: Editor de widgets
      ════════════════════════════════ */}
      {showWidgetEditor && (
        <div className="fixed inset-0 z-[130] flex items-end" onClick={()=>setShowWidgetEditor(false)}>
          <div className="w-full max-w-md mx-auto bg-zinc-950 rounded-t-[2rem] border-t border-white/8 pb-[calc(env(safe-area-inset-bottom)+16px)]"
            onClick={e=>e.stopPropagation()}>
            <div className="flex items-center justify-between px-6 pt-5 pb-4 border-b border-white/8">
              <div>
                <h3 className="text-lg font-black uppercase tracking-tight flex items-center gap-2">
                  <LayoutGrid className="w-5 h-5 text-indigo-400"/> Personalizar Home
                </h3>
                <p className="text-xs text-zinc-600 mt-0.5">Ocultá los widgets que no usás</p>
              </div>
              <button onClick={()=>setShowWidgetEditor(false)} className="p-2 bg-zinc-900 rounded-xl">
                <X className="w-4 h-4"/>
              </button>
            </div>
            <div className="overflow-y-auto max-h-[60vh] px-6 py-4 space-y-2">
              {WIDGET_LIST.map(({ id, label, icon }) => {
                const hidden = isHidden(id);
                return (
                  <button key={id} onClick={()=>toggleWidget(id)}
                    className={`w-full flex items-center gap-3 px-4 py-3.5 rounded-2xl border transition-all active:scale-95
                      ${hidden ? 'bg-zinc-900/30 border-white/5 opacity-50' : 'bg-zinc-900/50 border-white/8'}`}>
                    <span className="text-lg leading-none flex-shrink-0">{icon}</span>
                    <span className={`text-sm font-semibold flex-1 text-left ${hidden ? 'text-zinc-600' : 'text-zinc-300'}`}>{label}</span>
                    <div className={`w-10 h-5 rounded-full transition-all flex-shrink-0 flex items-center px-0.5
                      ${hidden ? 'bg-zinc-800 justify-start' : 'bg-indigo-600 justify-end'}`}>
                      <div className="w-4 h-4 rounded-full bg-white shadow-sm"/>
                    </div>
                  </button>
                );
              })}
            </div>
            {hiddenWidgets.size > 0 && (
              <div className="px-6 pt-3 border-t border-white/8">
                <button onClick={() => { setHiddenWidgets(new Set()); localStorage.removeItem(HIDDEN_WIDGETS_KEY); haptic(12); }}
                  className="w-full py-3 text-xs font-bold text-indigo-400 active:opacity-60">
                  Mostrar todos los widgets
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ════════════════════════════════
          MODAL: Comparar dos meses
      ════════════════════════════════ */}
      {showCompareModal && (
        <CompareModal
          transactions={transactions}
          MONTHS={MONTHS}
          formatNumber={formatNumber}
          onClose={() => setShowCompareModal(false)}
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

      {/* ════════════════════════════════
          OVERLAY: Búsqueda rápida
      ════════════════════════════════ */}
      {showSearch && (
        <div className="fixed inset-0 z-[140] bg-black/80 backdrop-blur-sm flex flex-col"
          onClick={()=>{ setShowSearch(false); setSearchQuery(''); }}>
          <div className="w-full max-w-md mx-auto"
            onClick={e=>e.stopPropagation()}>
            <div className="px-5 pt-[calc(env(safe-area-inset-top)+12px)] pb-3">
              <div className="flex items-center gap-3 bg-zinc-900 border border-white/10 rounded-2xl px-4 py-3">
                <Search className="w-5 h-5 text-zinc-500 flex-shrink-0"/>
                <input
                  autoFocus
                  type="text"
                  value={searchQuery}
                  onChange={e=>setSearchQuery(e.target.value)}
                  placeholder="Buscá por categoría, nota o monto…"
                  className="flex-1 bg-transparent text-sm text-white placeholder:text-zinc-600 focus:outline-none"
                />
                {searchQuery && (
                  <button onClick={()=>setSearchQuery('')} className="p-1 text-zinc-600 active:text-zinc-300">
                    <X className="w-4 h-4"/>
                  </button>
                )}
              </div>
            </div>
            {(() => {
              const q = searchQuery.trim().toLowerCase();
              if (!q) return (
                <div className="px-5 py-8 text-center">
                  <p className="text-sm text-zinc-600">Escribí para buscar en tus movimientos</p>
                </div>
              );
              const results = transactions
                .filter(t =>
                  t.category.toLowerCase().includes(q) ||
                  (t.note||'').toLowerCase().includes(q) ||
                  String(Math.round(Number(t.amount))).includes(q)
                )
                .sort((a,b)=>new Date(b.date)-new Date(a.date))
                .slice(0,25);
              if (results.length === 0) return (
                <div className="px-5 py-8 text-center">
                  <p className="text-sm text-zinc-600">Sin resultados para "{searchQuery}"</p>
                </div>
              );
              return (
                <div className="overflow-y-auto max-h-[72vh] pb-8">
                  <p className="text-[10px] text-zinc-700 px-6 mb-2">{results.length} resultado{results.length!==1?'s':''}</p>
                  {results.map(t=>(
                    <button key={t.id} className="w-full flex items-center gap-3 px-5 py-3 border-b border-white/5 active:bg-zinc-900/60"
                      onClick={()=>{
                        setShowSearch(false); setSearchQuery('');
                        goToCategory(t.category, t.type);
                        haptic(8);
                      }}>
                      <div className={`w-8 h-8 rounded-xl flex items-center justify-center text-lg flex-shrink-0 ${t.type==='GASTO'?'bg-rose-500/15':'bg-emerald-500/15'}`}>
                        {getEmoji(t.category)}
                      </div>
                      <div className="flex-1 min-w-0 text-left">
                        <p className="text-sm font-semibold text-zinc-200 truncate">{t.category}</p>
                        {t.note && <p className="text-[11px] text-zinc-600 truncate">{t.note}</p>}
                      </div>
                      <div className="text-right flex-shrink-0">
                        <p className={`text-sm font-black ${t.type==='GASTO'?'text-rose-400':'text-emerald-400'}`}>
                          {t.type==='GASTO'?'−':'+'}${formatNumber(t.amount)}
                        </p>
                        <p className="text-[10px] text-zinc-700">{new Date(t.date).toLocaleDateString('es-AR',{day:'2-digit',month:'short'})}</p>
                      </div>
                    </button>
                  ))}
                </div>
              );
            })()}
          </div>
        </div>
      )}

      {/* Calculadora Plazo Fijo */}
      {showPlazoFijo && (
        <PlazoFijoCalc onClose={() => setShowPlazoFijo(false)} />
      )}

      {/* Input oculto para importar JSON */}
      <input
        ref={importFileRef}
        type="file"
        accept=".json"
        className="hidden"
        onChange={importJSON}
      />
    </div>
  );
}

// ─────────────────────────────────────────────
// PLAZO FIJO CALCULATOR
// ─────────────────────────────────────────────
function PlazoFijoCalc({ onClose }) {
  const [monto, setMonto] = React.useState('');
  const [tna,   setTna]   = React.useState('');
  const [dias,  setDias]  = React.useState('30');

  const result = React.useMemo(() => {
    const m = Number(monto.replace(/\D/g, ''));
    const t = parseFloat(tna.replace(',', '.'));
    const d = parseInt(dias);
    if (!m || !t || !d || m <= 0 || t <= 0 || d <= 0) return null;
    const interesBruto = m * (t / 100) * (d / 365);
    const retenciones  = interesBruto * 0.07;
    const interesNeto  = interesBruto - retenciones;
    const totalNeto    = m + interesNeto;
    const tnaEfNeta    = (interesNeto / m) * (365 / d) * 100;
    return { interesBruto, interesNeto, totalNeto, retenciones, tnaEfNeta };
  }, [monto, tna, dias]);

  const fmt = (n) => Math.round(n).toLocaleString('es-AR');
  const montoNum = Number(monto.replace(/\D/g, ''));
  const tnaNum   = parseFloat(tna.replace(',', '.'));

  return (
    <div className="fixed inset-0 z-[210] bg-black/95 backdrop-blur-xl flex flex-col">
      {/* Header */}
      <div className="px-6 pt-[calc(env(safe-area-inset-top)+16px)] pb-4 flex items-center justify-between border-b border-white/8">
        <div className="flex items-center gap-3">
          <span className="text-2xl">🏦</span>
          <div>
            <h3 className="text-base font-black uppercase tracking-tight">Plazo Fijo</h3>
            <p className="text-[11px] text-zinc-500">Calculadora de rendimiento</p>
          </div>
        </div>
        <button onClick={onClose} className="p-2.5 bg-zinc-900 rounded-xl active:scale-90 transition-transform">
          <X className="w-5 h-5"/>
        </button>
      </div>

      <div className="flex-1 overflow-y-auto no-scrollbar px-6 py-6 space-y-5">
        {/* Capital */}
        <div className="space-y-1.5">
          <label className="text-xs font-bold text-zinc-400 ml-1">Capital a invertir ($)</label>
          <input
            type="text" inputMode="numeric" value={monto ? Number(monto).toLocaleString('es-AR') : ''}
            onChange={e => setMonto(e.target.value.replace(/\D/g, ''))}
            placeholder="0"
            className="w-full bg-zinc-900/60 border border-white/10 rounded-2xl px-4 py-4 text-xl font-black text-white focus:outline-none focus:border-indigo-500/50 placeholder:text-zinc-700"/>
        </div>

        {/* TNA + Días */}
        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <label className="text-xs font-bold text-zinc-400 ml-1">TNA (%)</label>
            <input
              type="text" inputMode="decimal" value={tna}
              onChange={e => setTna(e.target.value)}
              placeholder="100"
              className="w-full bg-zinc-900/60 border border-white/10 rounded-2xl px-4 py-4 text-lg font-black text-white focus:outline-none focus:border-indigo-500/50 placeholder:text-zinc-700"/>
          </div>
          <div className="space-y-1.5">
            <label className="text-xs font-bold text-zinc-400 ml-1">Plazo</label>
            <div className="flex gap-1.5">
              {['30','60','90'].map(d => (
                <button key={d} onClick={() => setDias(d)}
                  className={`flex-1 py-4 rounded-2xl text-xs font-black transition-all active:scale-90
                    ${dias === d ? 'bg-indigo-600 text-white shadow-lg' : 'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
                  {d}d
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Resultado */}
        {result ? (
          <div className="space-y-3">
            {/* Bloque interés */}
            <div className="bg-emerald-500/10 border border-emerald-500/20 rounded-2xl p-4 space-y-2.5">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-zinc-500 uppercase tracking-wider">Interés bruto</span>
                <span className="text-base font-black text-emerald-400">+${fmt(result.interesBruto)}</span>
              </div>
              <div className="flex items-center justify-between text-xs">
                <span className="text-zinc-600">Retenciones (7% ganancias)</span>
                <span className="text-rose-400 font-semibold">−${fmt(result.retenciones)}</span>
              </div>
              <div className="h-px bg-emerald-500/20"/>
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-emerald-300 uppercase tracking-wider">Interés neto</span>
                <span className="text-xl font-black text-emerald-300">+${fmt(result.interesNeto)}</span>
              </div>
            </div>

            {/* Total a cobrar */}
            <div className="bg-indigo-500/10 border border-indigo-500/20 rounded-2xl p-4">
              <div className="flex items-center justify-between mb-1.5">
                <span className="text-xs font-bold text-zinc-400 uppercase tracking-wider">Total a cobrar</span>
                <span className="text-2xl font-black text-white">${fmt(result.totalNeto)}</span>
              </div>
              <div className="flex items-center justify-between text-xs text-zinc-600">
                <span>TNA efectiva neta</span>
                <span className="text-indigo-300 font-bold">{result.tnaEfNeta.toFixed(2)}%</span>
              </div>
            </div>

            {/* Comparativa plazos */}
            {montoNum > 0 && tnaNum > 0 && (
              <div className="grid grid-cols-3 gap-2">
                {['30','60','90'].map(d => {
                  const di = parseInt(d);
                  const ib = montoNum * (tnaNum / 100) * (di / 365);
                  const ni = ib * 0.93;
                  return (
                    <div key={d}
                      className={`rounded-xl p-3 border text-center transition-all
                        ${d === dias ? 'bg-indigo-600/20 border-indigo-500/30' : 'bg-zinc-900/40 border-white/5'}`}>
                      <p className="text-[10px] text-zinc-500 font-semibold">{d} días</p>
                      <p className="text-sm font-black text-white mt-1">+${fmt(ni)}</p>
                      <p className="text-[9px] text-zinc-600 mt-0.5">neto</p>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        ) : (
          <div className="text-center py-14 space-y-3">
            <p className="text-5xl">🏦</p>
            <p className="text-sm font-semibold text-zinc-500">
              Ingresá el capital y la TNA<br/>para calcular el rendimiento
            </p>
            <p className="text-xs text-zinc-700 max-w-[220px] mx-auto">
              Se descuenta el 7% de retención de ganancias sobre los intereses (normativa AFIP)
            </p>
          </div>
        )}
      </div>
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
