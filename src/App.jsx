import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import logoMetacasa from './assets/logo-metacasa.jpg';
import {
  Settings, Trash2, X, Plus, Minus, History, TrendingUp, PiggyBank,
  BarChart3, PieChart, ArrowUpRight, ArrowDownLeft, FileSpreadsheet,
  ChevronLeft, ChevronRight, Calendar, LogOut, Home, Check,
  AlertCircle, CheckCircle2, Info, Edit3,
  Search, SlidersHorizontal, ArrowUpDown, XCircle
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
// EDIT TRANSACTION MODAL
// ─────────────────────────────────────────────
function EditTransactionModal({ tx, categories, onSave, onClose }) {
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
        <button onClick={handleSave} disabled={saving}
          className="w-full py-5 bg-indigo-600 rounded-2xl font-black text-sm uppercase tracking-widest active:scale-95 transition-all disabled:opacity-50">
          {saving ? 'Guardando…' : 'Guardar cambios'}
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
  const [loadingData,  setLoadingData]  = useState(true);

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

  // BÚSQUEDA Y FILTROS (Historial)
  const [searchQuery,      setSearchQuery]      = useState('');
  const [filterType,       setFilterType]       = useState('ALL');   // ALL | GASTO | INGRESO
  const [filterCategory,   setFilterCategory]   = useState('');      // '' = todas
  const [sortBy,           setSortBy]           = useState('date_desc'); // date_desc | date_asc | amount_desc | amount_asc
  const [allMonths,        setAllMonths]        = useState(false);   // false = solo mes actual

  // FORM
  const [type,       setType]       = useState('GASTO');
  const [amount,     setAmount]     = useState('');
  const [category,   setCategory]   = useState("");
  const [note,       setNote]       = useState("");
  const [txDate,     setTxDate]     = useState(new Date().toISOString().slice(0,10));
  const [newCatName, setNewCatName] = useState("");
  const [savingTx,   setSavingTx]   = useState(false);
  const [savedOk,    setSavedOk]    = useState(false);

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
    setCustomCats(data?.data || null);
  }, [userId]);

  const loadAll = useCallback(async () => {
    setLoadingData(true);
    await Promise.all([loadTransactions(), loadBudgets(), loadStrategy(), loadCategories()]);
    setLoadingData(false);
  }, [loadTransactions, loadBudgets, loadStrategy, loadCategories]);

  useEffect(() => { if (userId) loadAll(); }, [userId, loadAll]);

  const activeCategories = useMemo(() => customCats || INITIAL_CATEGORIES, [customCats]);

  useEffect(() => {
    if (activeCategories[type]?.length > 0) setCategory(activeCategories[type][0]);
  }, [type, activeCategories]);

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

  // ── ACTIONS ──
  const handleSaveTransaction = async () => {
    if (!userId || !amount || !category) return;
    setSavingTx(true);
    const numericAmount = parseFormattedNumber(amount);
    const payload = { user_id: userId, amount: numericAmount, category, type, note: note.trim(), date: new Date(txDate).toISOString() };
    const { error } = await supabase.from('transactions').insert(payload);
    setSavingTx(false);
    if (error) { toast(error.message, 'error'); return; }
    setAmount(''); setNote('');
    setSavedOk(true);
    setTimeout(() => setSavedOk(false), 1800);
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

  const deleteTransaction = async (id) => {
    if (!userId) return;
    const { error } = await supabase.from('transactions').delete().eq('id', id);
    if (error) { toast(error.message, 'error'); return; }
    toast('Movimiento eliminado', 'info');
    await loadTransactions();
  };

  const manageCategory = async (action, name) => {
    if (!userId || !name) return;
    let nc = { ...activeCategories };
    if (!nc[type]) nc[type] = [];
    const clean = name.trim();
    if (!clean) return;
    if (action==='ADD') { if (!nc[type].includes(clean)) nc[type]=[...nc[type],clean]; }
    else nc[type]=nc[type].filter(c=>c!==clean);
    const { error } = await supabase.from('categories').upsert({ user_id: userId, data: nc },{ onConflict: 'user_id' });
    if (error) { toast(error.message, 'error'); return; }
    setNewCatName(""); setCustomCats(nc);
    toast(action==='ADD'?'Categoría agregada':'Categoría eliminada', 'success');
  };

  const updateBudget = async (cat, val) => {
    if (!userId) return;
    const { error } = await supabase.from('budgets').upsert({ user_id: userId, category: cat, amount: Number(val||0) },{ onConflict: 'user_id,category' });
    if (error) { toast(error.message,'error'); return; }
    await loadBudgets();
  };

  const exportExcel = () => {
    if (transactions.length===0) { toast('Sin movimientos para exportar','info'); return; }
    const headers = ["Fecha","Tipo","Categoria","Monto","Detalle/Nota"];
    const rows = transactions.map(t => [new Date(t.date).toLocaleDateString(), t.type, t.category, formatNumber(t.amount), `"${(t.note||"").replace(/"/g,'""')}"`]);
    const csv = "\uFEFF"+[headers.join(";"),...rows.map(r=>r.join(";"))].join("\n");
    const url = URL.createObjectURL(new Blob([csv],{type:'text/csv;charset=utf-8;'}));
    const a = document.createElement("a"); a.href=url; a.download="MetaCasa_Finanzas.csv"; a.click();
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
  }, [transactions, monthTxs, allMonths, filterType, filterCategory, searchQuery, sortBy]);

  // Categorías disponibles según el filtro de tipo actual
  const filterableCats = useMemo(() => {
    const base = allMonths ? transactions : monthTxs;
    const src = filterType === 'ALL' ? base : base.filter(t => t.type === filterType);
    return [...new Set(src.map(t => t.category))].sort();
  }, [transactions, monthTxs, allMonths, filterType]);

  const hasActiveFilters = searchQuery || filterType !== 'ALL' || filterCategory || sortBy !== 'date_desc' || allMonths;

  const clearFilters = () => {
    setSearchQuery(''); setFilterType('ALL'); setFilterCategory('');
    setSortBy('date_desc'); setAllMonths(false);
  };

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
              <button onClick={signOut} className="p-2.5 bg-zinc-900 rounded-xl active:scale-90 transition-transform" title="Cerrar sesión">
                <LogOut className="w-5 h-5 text-zinc-400" />
              </button>
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
                      <SharedSizeText value={stats.available} fontSizeClass="text-5xl" />
                      <div className="mt-6 pt-5 border-t border-white/10 grid grid-cols-2 gap-3">
                        <div className="bg-white/8 rounded-2xl p-4">
                          <span className="flex items-center gap-1 text-xs font-semibold text-emerald-300 mb-1.5">
                            <ArrowUpRight className="w-3.5 h-3.5" /> Ingresos
                          </span>
                          <p className="text-xl font-black tracking-tight">${formatNumber(stats.income)}</p>
                        </div>
                        <div className="bg-white/8 rounded-2xl p-4">
                          <span className="flex items-center gap-1 text-xs font-semibold text-rose-300 mb-1.5">
                            <ArrowDownLeft className="w-3.5 h-3.5" /> Gastos
                          </span>
                          <p className="text-xl font-black tracking-tight">${formatNumber(stats.expenses)}</p>
                        </div>
                      </div>
                    </div>
                    <div className="absolute top-0 right-0 w-48 h-48 bg-white/10 rounded-full blur-[80px] -mr-20 -mt-20" />
                  </div>
                </div>

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

                {/* Top categorías rápido */}
                {chartData.length > 0 && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-4">
                      <p className="text-sm font-bold text-zinc-300">Top gastos</p>
                      <button onClick={()=>{setShowBudgetModal(true);setBudgetChartView(true);}} className="text-xs text-indigo-400 font-semibold">Ver gráfico →</button>
                    </div>
                    <div className="space-y-2">
                      {chartData.sort((a,b)=>b.spent-a.spent).slice(0,3).map((d,i)=>(
                        <div key={i} className="flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <div className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{backgroundColor:d.color}}/>
                            <span className="text-sm font-semibold text-zinc-300">{d.cat}</span>
                          </div>
                          <div className="text-right">
                            <span className="text-sm font-bold">${formatNumber(d.spent)}</span>
                            <span className="text-xs text-zinc-600 ml-1.5">{totalSpent>0?((d.spent/totalSpent)*100).toFixed(0):0}%</span>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

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
            <h2 className="text-xl font-black uppercase tracking-tight">Registrar</h2>

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

              {/* Monto */}
              <div className="space-y-1">
                <input type="text" value={amount?formatNumber(amount):""} onChange={e=>setAmount(e.target.value.replace(/\D/g,''))}
                  placeholder="$ 0"
                  className="w-full bg-transparent text-6xl font-black text-center focus:outline-none placeholder:text-zinc-800"
                  inputMode="numeric" />
                <p className="text-center text-xs text-zinc-600">en {MONTHS[currentDate.getMonth()]} {currentDate.getFullYear()}</p>
              </div>

              {/* Categoría */}
              <select value={category} onChange={e=>setCategory(e.target.value)}
                className="w-full bg-black/60 rounded-2xl p-4 border border-white/10 font-semibold text-sm text-white appearance-none text-center focus:outline-none focus:ring-2 focus:ring-indigo-500/40">
                {activeCategories[type]?.map(c=><option key={c} value={c}>{c}</option>)}
              </select>

              {/* Fecha */}
              <div className="space-y-1">
                <p className="text-xs font-semibold text-zinc-600 ml-1">Fecha</p>
                <input type="date" value={txDate} onChange={e=>setTxDate(e.target.value)}
                  className="w-full bg-black/60 rounded-2xl p-4 border border-white/10 font-semibold text-sm text-white focus:outline-none focus:ring-2 focus:ring-indigo-500/40" />
              </div>

              {/* Nota */}
              <textarea value={note} onChange={e=>setNote(e.target.value)} placeholder="Detalle opcional del movimiento…"
                className="w-full bg-black/40 rounded-2xl p-4 border border-white/10 text-sm text-zinc-400 min-h-[90px] resize-none focus:outline-none focus:border-indigo-500/40 transition-colors" />

              {/* Botón guardar */}
              <button onClick={handleSaveTransaction} disabled={!amount||!category||savingTx}
                className={`w-full py-5 rounded-2xl font-bold text-sm uppercase tracking-wider active:scale-95 transition-all shadow-xl
                  ${savedOk?'bg-emerald-600':(!amount||!category)?'bg-zinc-800/50 text-zinc-600':(type==='GASTO'?'bg-rose-600':'bg-emerald-600')}
                  ${savingTx?'opacity-60':''}`}>
                {savingTx ? 'Guardando…' : savedOk ? '¡Listo! ✓' : 'Confirmar registro'}
              </button>
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
              <h2 className="text-xl font-black uppercase tracking-tight">Historial</h2>
              <button onClick={exportExcel} className="p-2.5 bg-emerald-600 rounded-xl text-white active:scale-90 transition-transform" title="Exportar CSV">
                <FileSpreadsheet className="w-4 h-4" />
              </button>
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

                {/* Toggle mes/todos */}
                <button
                  onClick={()=>setAllMonths(v=>!v)}
                  className={`flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition-all
                    ${allMonths?'bg-white text-black':'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                  <Calendar className="w-3.5 h-3.5"/>
                  {allMonths ? 'Todos los meses' : `${MONTHS[currentDate.getMonth()].slice(0,3)} ${currentDate.getFullYear()}`}
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
                    className={`px-3.5 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition-all
                      ${filterCategory===cat
                        ? 'bg-white text-black'
                        : 'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                    {cat}
                  </button>
                ))}
              </div>
            </div>

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

            {/* Lista */}
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
              ) : (
                <div className="space-y-2.5 pb-4">
                  {filteredTxs.map(t=>(
                    <div key={t.id} className="bg-zinc-900/50 rounded-2xl border border-white/5">
                      <div className="flex items-center gap-3.5 p-4">
                        <div className={`w-11 h-11 rounded-xl flex items-center justify-center text-xs font-black flex-shrink-0
                          ${t.type==='INGRESO'?'bg-emerald-500/15 text-emerald-400':'bg-rose-500/15 text-rose-400'}`}>
                          {t.type==='INGRESO'?'IN':'OUT'}
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-bold text-white truncate">{t.category}</p>
                          <p className="text-xs text-zinc-600">
                            {new Date(t.date).toLocaleDateString('es-AR',{day:'2-digit',month:'short',year:'numeric'})}
                          </p>
                          {t.note && <p className="text-xs text-zinc-500 italic truncate mt-0.5">"{t.note}"</p>}
                        </div>
                        <div className="flex items-center gap-2 flex-shrink-0">
                          <p className={`text-base font-black ${t.type==='INGRESO'?'text-emerald-400':'text-white'}`}>
                            {t.type==='GASTO'?'-':'+'} ${formatNumber(t.amount)}
                          </p>
                          <div className="flex flex-col gap-1">
                            <button onClick={()=>setEditingTx(t)} className="p-1.5 text-zinc-700 active:text-indigo-400 transition-colors">
                              <Edit3 className="w-3.5 h-3.5"/>
                            </button>
                            <button onClick={()=>deleteTransaction(t.id)} className="p-1.5 text-zinc-700 active:text-rose-500 transition-colors">
                              <Trash2 className="w-3.5 h-3.5"/>
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
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
                    <span className="text-sm font-semibold text-zinc-300">{cat}</span>
                    <input type="text" value={formatNumber(budgets[cat]?.amount||0)}
                      onChange={async e=>{ const v=parseFormattedNumber(e.target.value); await updateBudget(cat,v); }}
                      className="bg-transparent text-right font-bold text-sm w-24 focus:outline-none focus:text-indigo-400 transition-colors"
                      inputMode="numeric"/>
                  </div>
                ))}
              </div>
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
            </div>

            {/* Cuenta */}
            <div className="space-y-3">
              <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider ml-1">Cuenta</p>
              <div className="bg-zinc-900/40 rounded-2xl border border-white/5 overflow-hidden">
                <div className="flex items-center justify-between px-5 py-4 border-b border-white/5">
                  <span className="text-sm font-semibold text-zinc-300">Email</span>
                  <span className="text-xs text-zinc-600 truncate max-w-[140px]">{session?.user?.email}</span>
                </div>
                <button onClick={exportExcel} className="flex items-center gap-3 px-5 py-4 w-full border-b border-white/5 active:bg-zinc-900/60 transition-colors">
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
          BOTTOM TAB BAR (iOS-style)
      ════════════════════════════════ */}
      <div className="fixed bottom-0 left-0 right-0 z-[90] bg-black/90 backdrop-blur-xl border-t border-white/8 pb-[env(safe-area-inset-bottom)]">
        <div className="max-w-md mx-auto flex">
          {[
            { id:'home',    icon: Home,         label: 'Inicio'   },
            { id:'add',     icon: Plus,         label: 'Registrar'},
            { id:'history', icon: History,      label: 'Historial'},
            { id:'settings',icon: Settings,     label: 'Ajustes'  },
          ].map(tab=>{
            const Icon = tab.icon;
            const active = activeTab===tab.id;
            const isAdd = tab.id==='add';
            return (
              <button key={tab.id} onClick={()=>setActiveTab(tab.id)}
                className={`flex-1 flex flex-col items-center gap-1 py-3 transition-all active:scale-95
                  ${active?'text-indigo-400':'text-zinc-600'}`}>
                {isAdd ? (
                  <div className={`w-12 h-12 rounded-2xl flex items-center justify-center shadow-lg transition-all
                    ${active?'bg-indigo-600':'bg-zinc-900 border border-white/10'}`}>
                    <Icon className={`w-6 h-6 ${active?'text-white':'text-zinc-500'}`}/>
                  </div>
                ) : (
                  <Icon className={`w-6 h-6 transition-all ${active?'text-indigo-400':'text-zinc-600'}`}/>
                )}
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
                          <div className="w-3 h-3 rounded-full flex-shrink-0" style={{backgroundColor:s.color}}/>
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
                      <div>
                        <h4 className="text-sm font-bold text-white">{cat}</h4>
                        <p className="text-xs text-zinc-600 mt-0.5">Asignado: ${formatNumber(limit)}</p>
                      </div>
                      <div className="text-right">
                        <span className={`text-xs font-bold block mb-0.5 ${isOver?'text-rose-400':'text-emerald-400'}`}>{isOver?'Excedido':'Restante'}</span>
                        <p className={`text-2xl font-black tracking-tight ${isOver?'text-rose-400':'text-white'}`}>${formatNumber(remaining)}</p>
                      </div>
                    </div>
                    <div className="h-2 bg-black rounded-full overflow-hidden">
                      <div className={`h-full rounded-full transition-all duration-700 ${isOver?'bg-rose-600':'bg-indigo-600'}`} style={{width:`${limit>0?progress:0}%`}}/>
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
              <div key={c} className="flex justify-between items-center bg-zinc-900/40 px-5 py-4 rounded-2xl border border-white/5">
                <span className="text-sm font-semibold text-zinc-200">{c}</span>
                <button onClick={()=>manageCategory('DELETE',c)} className="p-2 text-zinc-700 hover:text-rose-500 transition-colors">
                  <Trash2 className="w-4 h-4"/>
                </button>
              </div>
            ))}
          </div>
        </div>
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
