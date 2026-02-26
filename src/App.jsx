import React, { useEffect, useMemo, useRef, useState } from 'react';
import logoMetacasa from './assets/logo-metacasa.jpg';
import {
  Wallet,
  Settings,
  Trash2,
  X,
  Plus,
  Minus,
  History,
  TrendingUp,
  PiggyBank,
  BarChart3,
  PieChart,
  ArrowUpRight,
  ArrowDownLeft,
  FileSpreadsheet,
  ChevronLeft,
  ChevronRight,
  Calendar,
  LogOut
} from 'lucide-react';

import { supabase } from './supabaseClient';

const INITIAL_CATEGORIES = {
  GASTO: ["Vivienda", "Transporte", "Salud", "Ocio", "Alimentación", "Servicios"],
  INGRESO: ["Sueldo", "Inversiones", "Ventas"]
};

const MONTHS = ["ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO", "JULIO", "AGOSTO", "SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE"];

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
// MAPA DE COLORES PARA TAILWIND (EVITA CLASES DINÁMICAS)
const COLOR_MAP = {
  emerald: {
    bg: "bg-emerald-500",
    bgSoft: "bg-emerald-500/10",
    text: "text-emerald-500"
  },
  indigo: {
    bg: "bg-indigo-500",
    bgSoft: "bg-indigo-500/10",
    text: "text-indigo-500"
  }
};

// Componente de Selector de Precisión
const PrecisionSelector = ({ label, value, onChange, color, icon: Icon, subtext }) => {
  const c = COLOR_MAP[color] || COLOR_MAP.indigo;

  const updateValue = (newValue) => {
    const clamped = Math.max(0, Math.min(100, newValue));
    onChange(clamped);
  };

  return (
    <div className="bg-zinc-900/60 rounded-[2rem] p-6 border border-white/5 space-y-4">
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-3">
          <div className={`p-2 rounded-xl ${c.bgSoft}`}>
            <Icon className={`w-5 h-5 ${c.text}`} />
          </div>
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-white">
              {label}
            </p>
            <p className="text-[9px] font-bold text-zinc-600 uppercase italic">
              {subtext}
            </p>
          </div>
        </div>
        <div className={`text-2xl font-black ${c.text} tabular-nums`}>
          {value}%
        </div>
      </div>

      <div className="flex items-center gap-4">
        <button
          onClick={() => updateValue(value - 1)}
          className="w-12 h-12 rounded-full bg-zinc-800 flex items-center justify-center active:scale-90 transition-transform"
        >
          <Minus className="w-5 h-5 text-white" />
        </button>

        <div className="flex-1 h-3 bg-black rounded-full overflow-hidden border border-white/5 relative">
          <div
            className={`h-full ${c.bg} transition-all duration-300 shadow-[0_0_15px_rgba(0,0,0,0.5)]`}
            style={{ width: `${value}%` }}
          />
        </div>

        <button
          onClick={() => updateValue(value + 1)}
          className="w-12 h-12 rounded-full bg-zinc-800 flex items-center justify-center active:scale-90 transition-transform"
        >
          <Plus className="w-5 h-5 text-white" />
        </button>
      </div>

      <div className="grid grid-cols-5 gap-2">
        {[0, 10, 20, 30, 50].map(pct => (
          <button
            key={pct}
            onClick={() => updateValue(pct)}
            className={`py-2 rounded-lg text-[9px] font-black transition-all ${
              value === pct
                ? `${c.bg} text-white`
                : 'bg-zinc-800/50 text-zinc-500'
            }`}
          >
            {pct}%
          </button>
        ))}
      </div>
    </div>
  );
};

const SharedSizeText = ({ value, prefix = "$", fontSizeClass, className = "" }) => {
  const text = `${prefix}${formatNumber(value)}`;
  return (
    <div className="w-full overflow-hidden flex items-center h-16">
      <h2 className={`${fontSizeClass} font-black tracking-tighter transition-all duration-300 whitespace-nowrap leading-none ${className}`}>
        {text}
      </h2>
    </div>
  );
};

export default function App() {
  // --- AUTH (SUPABASE) ---
  const [session, setSession] = useState(null);
  const [authLoading, setAuthLoading] = useState(true);
  const [authEmail, setAuthEmail] = useState("");
  const [authPassword, setAuthPassword] = useState("");
  const [authMode, setAuthMode] = useState("LOGIN"); // LOGIN | SIGNUP

  // --- APP STATE ---
  const [transactions, setTransactions] = useState([]);
  const [budgets, setBudgets] = useState({});
  const [strategy, setStrategy] = useState({ savingsPercent: 0, investmentPercent: 0 });
  const [customCats, setCustomCats] = useState(null);
  const [currentDate, setCurrentDate] = useState(new Date());

  const [showBudgetModal, setShowBudgetModal] = useState(false);
  const [budgetChartView, setBudgetChartView] = useState(false);
  const [showHistoryModal, setShowHistoryModal] = useState(false);
  const [showCatManager, setShowCatManager] = useState(false);
  const [showSettingsModal, setShowSettingsModal] = useState(false);
  const [showDatePicker, setShowDatePicker] = useState(false);

  const [type, setType] = useState('GASTO');
  const [amount, setAmount] = useState('');
  const [category, setCategory] = useState("");
  const [note, setNote] = useState("");
  const [newCatName, setNewCatName] = useState("");

  const mountedRef = useRef(false);

  const userId = session?.user?.id || null;

  // --------- AUTH INIT ----------
  useEffect(() => {
    mountedRef.current = true;

    supabase.auth.getSession().then(({ data }) => {
      if (!mountedRef.current) return;
      setSession(data?.session || null);
      setAuthLoading(false);
    });

    const { data: sub } = supabase.auth.onAuthStateChange((_event, newSession) => {
      setSession(newSession);
    });

    return () => {
      mountedRef.current = false;
      sub?.subscription?.unsubscribe?.();
    };
  }, []);

  const signUp = async () => {
    const { error } = await supabase.auth.signUp({
      email: authEmail.trim(),
      password: authPassword
    });
    if (error) return alert(error.message);
    alert("Revisá tu email para confirmar la cuenta (si tenés confirmación activada).");
  };

  const signIn = async () => {
    const { error } = await supabase.auth.signInWithPassword({
      email: authEmail.trim(),
      password: authPassword
    });
    if (error) return alert(error.message);
  };

  const signOut = async () => {
    await supabase.auth.signOut();
  };

  // --------- DATA LOADERS (SUPABASE) ----------
  const loadTransactions = async () => {
    if (!userId) return;
    const { data, error } = await supabase
      .from('transactions')
      .select('*')
      .order('date', { ascending: false })
      .order('created_at', { ascending: false });

    if (error) {
      console.error(error);
      return;
    }
    setTransactions((data || []).map(t => ({
      ...t,
      // compat: tu UI espera "id, amount, category, type, note, date"
      amount: Number(t.amount || 0),
      note: t.note || ""
    })));
  };

  const loadBudgets = async () => {
    if (!userId) return;
    const { data, error } = await supabase
      .from('budgets')
      .select('category, amount');

    if (error) {
      console.error(error);
      return;
    }
    const b = {};
    (data || []).forEach(row => {
      b[row.category] = { amount: Number(row.amount || 0) };
    });
    setBudgets(b);
  };

  const loadStrategy = async () => {
    if (!userId) return;
    const { data, error } = await supabase
      .from('strategy')
      .select('savings_percent, investment_percent')
      .maybeSingle();

    if (error && error.code !== 'PGRST116') {
      console.error(error);
      return;
    }

    setStrategy({
      savingsPercent: Number(data?.savings_percent || 0),
      investmentPercent: Number(data?.investment_percent || 0)
    });
  };

  const loadCategories = async () => {
    if (!userId) return;
    const { data, error } = await supabase
      .from('categories')
      .select('data')
      .maybeSingle();

    if (error && error.code !== 'PGRST116') {
      console.error(error);
      return;
    }

    if (data?.data) setCustomCats(data.data);
    else setCustomCats(null);
  };

  const loadAll = async () => {
    await Promise.all([loadTransactions(), loadBudgets(), loadStrategy(), loadCategories()]);
  };

  // cuando hay sesión, cargar datos
  useEffect(() => {
    if (!userId) return;
    loadAll();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId]);

  const activeCategories = useMemo(() => customCats || INITIAL_CATEGORIES, [customCats]);

  useEffect(() => {
    if (activeCategories[type]?.length > 0) {
      setCategory(activeCategories[type][0]);
    }
  }, [type, activeCategories]);

  const stats = useMemo(() => {
    const m = currentDate.getMonth();
    const y = currentDate.getFullYear();

    const currentMonthTrans = transactions.filter(t => {
      const d = new Date(t.date);
      return d.getMonth() === m && d.getFullYear() === y;
    });

    const income = currentMonthTrans
      .filter(t => t.type === 'INGRESO')
      .reduce((acc, c) => acc + Number(c.amount), 0);

    const expenses = currentMonthTrans
      .filter(t => t.type === 'GASTO')
      .reduce((acc, c) => acc + Number(c.amount), 0);

    const expenseByCategory = {};
    currentMonthTrans.filter(t => t.type === 'GASTO').forEach(t => {
      expenseByCategory[t.category] = (expenseByCategory[t.category] || 0) + Number(t.amount);
    });

    const savingsAmount = (income * (strategy.savingsPercent || 0)) / 100;
    const investmentAmount = (income * (strategy.investmentPercent || 0)) / 100;

    const totalHistoricalIncome = transactions
      .filter(t => t.type === 'INGRESO')
      .reduce((acc, c) => acc + Number(c.amount), 0);

    const historicalSavingsTotal = (totalHistoricalIncome * (strategy.savingsPercent || 0)) / 100;
    const historicalInvestmentTotal = (totalHistoricalIncome * (strategy.investmentPercent || 0)) / 100;

    const totalBudgetsAssigned = Object.values(budgets).reduce((acc, b) => acc + (Number(b.amount) || 0), 0);

    const available = income - savingsAmount - investmentAmount - expenses;
    const availableToAssign = income - savingsAmount - investmentAmount - totalBudgetsAssigned;

    return {
      income, expenses, available, expenseByCategory,
      savingsAmount, investmentAmount, totalBudgetsAssigned,
      availableToAssign, historicalSavingsTotal, historicalInvestmentTotal
    };
  }, [transactions, currentDate, strategy, budgets]);

  const handleSaveTransaction = async () => {
    if (!userId || !amount || !category) return;

    const numericAmount = parseFormattedNumber(amount);

    // Guardar transacción con la fecha del período actual (o ahora si es el mes actual)
    const now = new Date();
    let finalDate;
    if (currentDate.getMonth() === now.getMonth() && currentDate.getFullYear() === now.getFullYear()) {
      finalDate = now.toISOString();
    } else {
      finalDate = new Date(currentDate.getFullYear(), currentDate.getMonth(), 15).toISOString();
    }

    const payload = {
      user_id: userId,
      amount: numericAmount,
      category,
      type,
      note: note.trim(),
      date: finalDate
    };

    const { error } = await supabase.from('transactions').insert(payload);
    if (error) {
      console.error(error);
      alert(error.message);
      return;
    }

    setAmount('');
    setNote('');
    alert('Movimiento guardado');
    await loadTransactions();
  };

  const updateStrategy = async (field, value) => {
    if (!userId) return;

    const newStrategy = { ...strategy, [field]: value };
    setStrategy(newStrategy);

    const payload = {
      user_id: userId,
      savings_percent: Number(newStrategy.savingsPercent || 0),
      investment_percent: Number(newStrategy.investmentPercent || 0)
    };

    const { error } = await supabase.from('strategy').upsert(payload, { onConflict: 'user_id' });
    if (error) console.error(error);
  };

  const changeMonth = (offset) => {
    setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() + offset, 1));
  };

  const deleteTransaction = async (id) => {
    if (!userId) return;
    const { error } = await supabase
      .from('transactions')
      .delete()
      .eq('id', id);

    if (error) {
      console.error(error);
      alert(error.message);
      return;
    }
    await loadTransactions();
  };

  const manageCategory = async (action, name) => {
    if (!userId || !name) return;

    let newCats = { ...activeCategories };
    if (!newCats[type]) newCats[type] = [];

    const clean = name.trim();
    if (!clean) return;

    if (action === 'ADD') {
      if (!newCats[type].includes(clean)) newCats[type] = [...newCats[type], clean];
    } else {
      newCats[type] = newCats[type].filter(c => c !== clean);
    }

    const { error } = await supabase
      .from('categories')
      .upsert({ user_id: userId, data: newCats }, { onConflict: 'user_id' });

    if (error) {
      console.error(error);
      alert(error.message);
      return;
    }

    setNewCatName("");
    setCustomCats(newCats);
  };

  const updateBudget = async (cat, val) => {
    if (!userId) return;
    const payload = { user_id: userId, category: cat, amount: Number(val || 0) };
    const { error } = await supabase.from('budgets').upsert(payload, { onConflict: 'user_id,category' });
    if (error) {
      console.error(error);
      alert(error.message);
      return;
    }
    await loadBudgets();
  };

  const exportExcel = () => {
    if (transactions.length === 0) return;
    const headers = ["Fecha", "Tipo", "Categoria", "Monto", "Detalle/Nota"];
    const rows = transactions.map(t => [
      new Date(t.date).toLocaleDateString(),
      t.type,
      t.category,
      formatNumber(t.amount),
      `"${(t.note || "").replace(/"/g, '""')}"`
    ]);
    const csvContent = "\uFEFF" + [headers.join(";"), ...rows.map(r => r.join(";"))].join("\n");
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `MetaCasa_Finanzas.csv`;
    link.click();
  };

  // ---------- UI: LOADING ----------
  if (authLoading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center text-zinc-500 font-black uppercase text-[10px] tracking-[0.2em]">
        MetaCasa Engine
      </div>
    );
  }

  // ---------- UI: LOGIN (MISMA ESTÉTICA, NEGRO, MODERNA) ----------
  if (!session) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center px-6">
        <style>{`
          input, select, textarea { font-size: 16px !important; }
          .bg-emerald-500 { background-color: #10b981; }
          .text-emerald-500 { color: #10b981; }
          .bg-indigo-500 { background-color: #6366f1; }
          .text-indigo-500 { color: #6366f1; }
        `}</style>

        <div className="w-full max-w-md">
          <div className="bg-zinc-900/40 rounded-[2.5rem] p-8 border border-white/5 space-y-6">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 bg-white rounded-2xl flex items-center justify-center">
                <Wallet className="w-6 h-6 text-black" />
              </div>
              <div>
                <h1 className="text-3xl font-black italic uppercase tracking-tighter leading-none">MetaCasa</h1>
                <p className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-600 mt-1">
                  Acceso seguro
                </p>
              </div>
            </div>

            <div className="flex bg-black rounded-2xl p-1.5 border border-white/10 shadow-inner">
              {[
                { key: "LOGIN", label: "Ingresar" },
                { key: "SIGNUP", label: "Registrarse" }
              ].map(opt => (
                <button
                  key={opt.key}
                  onClick={() => setAuthMode(opt.key)}
                  className={`flex-1 py-3 text-[10px] font-black rounded-xl transition-all tracking-[0.1em] ${
                    authMode === opt.key ? 'bg-indigo-600 text-white' : 'text-zinc-600'
                  }`}
                >
                  {opt.label}
                </button>
              ))}
            </div>

            <div className="space-y-4">
              <input
                type="email"
                value={authEmail}
                onChange={(e) => setAuthEmail(e.target.value)}
                placeholder="Email"
                className="w-full bg-black/60 rounded-2xl p-5 border border-white/10 font-bold text-sm text-white focus:outline-none focus:border-indigo-500/50 transition-colors"
              />
              <input
                type="password"
                value={authPassword}
                onChange={(e) => setAuthPassword(e.target.value)}
                placeholder="Contraseña"
                className="w-full bg-black/60 rounded-2xl p-5 border border-white/10 font-bold text-sm text-white focus:outline-none focus:border-indigo-500/50 transition-colors"
              />
            </div>

            <button
              onClick={authMode === "LOGIN" ? signIn : signUp}
              className="w-full py-6 rounded-2xl font-black text-xs uppercase tracking-[0.25em] ios-tap shadow-2xl transition-all bg-indigo-600"
            >
              {authMode === "LOGIN" ? "Ingresar" : "Crear cuenta"}
            </button>

            <p className="text-[10px] font-bold text-zinc-600">
              Si al registrarte te pide confirmar email, revisá spam/promociones.
            </p>
          </div>
        </div>
      </div>
    );
  }

  // ---------- UI: APP (TU INTERFAZ) ----------
  return (
    <div className="min-h-screen bg-black text-white font-sans safe-area-inset overflow-x-hidden">
      <style>{`
        :root { --sat: env(safe-area-inset-top); --sab: env(safe-area-inset-bottom); }
        .safe-area-inset { padding-top: var(--sat); padding-bottom: var(--sab); }
        input, select, textarea { font-size: 16px !important; }
        .no-scrollbar::-webkit-scrollbar { display: none; }
        .ios-tap:active { transform: scale(0.96); opacity: 0.8; }
        .bg-emerald-500 { background-color: #10b981; }
        .text-emerald-500 { color: #10b981; }
        .bg-indigo-500 { background-color: #6366f1; }
        .text-indigo-500 { color: #6366f1; }
      `}</style>

      <div className="max-w-md mx-auto px-6 py-4 pb-32 space-y-8">
        {/* Header con Selector de Fecha */}
        <header className="flex justify-between items-center">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl overflow-hidden">
              <img src={logoMetacasa} alt="MetaCasa" className="w-full h-full object-cover" />
            </div>
            <div>
              <h1 className="text-xl font-black italic uppercase tracking-tighter leading-none">
                MetaCasa
              </h1>
              <button
                onClick={() => setShowDatePicker(true)}
                className="flex items-center gap-1 text-[9px] font-black text-indigo-500 uppercase tracking-widest mt-1 ios-tap"
              >
                <Calendar className="w-3 h-3" />
                {MONTHS[currentDate.getMonth()]} {currentDate.getFullYear()}
              </button>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={signOut}
              className="p-3 bg-zinc-900 rounded-2xl shadow-lg active:scale-90 transition-transform"
              title="Cerrar sesión"
            >
              <LogOut className="w-5 h-5 text-zinc-400" />
            </button>

            <button onClick={() => setShowSettingsModal(true)} className="p-3 bg-zinc-900 rounded-2xl relative shadow-lg">
              <Settings className="w-5 h-5 text-zinc-400" />
              {stats.availableToAssign < 0 && <span className="absolute top-2 right-2 w-2 h-2 bg-rose-600 rounded-full animate-pulse"></span>}
            </button>
          </div>
        </header>

        {/* Dash Principal con Flechas */}
        <div className="space-y-4">
          <div className="flex items-center justify-between px-2">
            <button onClick={() => changeMonth(-1)} className="p-2 bg-zinc-900/50 rounded-full text-zinc-500 ios-tap">
              <ChevronLeft className="w-5 h-5" />
            </button>
            <span className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-700 italic">Balance de Período</span>
            <button onClick={() => changeMonth(1)} className="p-2 bg-zinc-900/50 rounded-full text-zinc-500 ios-tap">
              <ChevronRight className="w-5 h-5" />
            </button>
          </div>

          <div className="bg-gradient-to-br from-indigo-600 to-indigo-900 rounded-[2.5rem] p-8 shadow-2xl relative overflow-hidden group">
            <div className="relative z-10">
              <div className="flex justify-between items-center mb-1">
                <span className="text-[10px] font-black uppercase tracking-[0.2em] text-indigo-200/50 block">Saldo Real Disponible</span>
                <span className="text-[10px] font-black text-indigo-300 uppercase tracking-widest">{MONTHS[currentDate.getMonth()]}</span>
              </div>
              <SharedSizeText value={stats.available} fontSizeClass="text-5xl" />

              <div className="mt-8 pt-6 border-t border-white/10 grid grid-cols-2 gap-4">
                <div className="bg-white/5 rounded-2xl p-4">
                  <span className="flex items-center gap-1 text-[9px] font-black text-emerald-300 uppercase mb-2 tracking-tighter">
                    <ArrowUpRight className="w-3 h-3" /> Ingresos
                  </span>
                  <p className="text-xl font-black tracking-tighter">${formatNumber(stats.income)}</p>
                </div>
                <div className="bg-white/5 rounded-2xl p-4">
                  <span className="flex items-center gap-1 text-[9px] font-black text-rose-300 uppercase mb-2 tracking-tighter">
                    <ArrowDownLeft className="w-3 h-3" /> Gastos
                  </span>
                  <p className="text-xl font-black tracking-tighter">${formatNumber(stats.expenses)}</p>
                </div>
              </div>
            </div>
            <div className="absolute top-0 right-0 w-48 h-48 bg-white/10 rounded-full blur-[80px] -mr-24 -mt-24 group-hover:bg-white/20 transition-all"></div>
          </div>
        </div>

        {/* Quick Add Form */}
        <div className="bg-zinc-900/40 rounded-[2.5rem] p-7 border border-white/5 space-y-6 backdrop-blur-sm">
          <div className="flex bg-black rounded-2xl p-1.5 border border-white/10 shadow-inner">
            {['GASTO', 'INGRESO'].map(t => (
              <button
                key={t}
                onClick={() => setType(t)}
                className={`flex-1 py-3 text-[10px] font-black rounded-xl transition-all tracking-[0.1em] ${type === t ? (t === 'GASTO' ? 'bg-rose-600 text-white' : 'bg-emerald-600 text-white') : 'text-zinc-600'}`}
              >
                {t}
              </button>
            ))}
          </div>

          <div className="space-y-1">
            <input
              type="text"
              value={amount ? formatNumber(amount) : ""}
              onChange={(e) => setAmount(e.target.value.replace(/\D/g, ''))}
              placeholder="$ 0"
              className="w-full bg-transparent text-6xl font-black text-center focus:outline-none placeholder:text-zinc-800 transition-all"
              inputMode="numeric"
            />
            <p className="text-center text-[9px] font-black text-zinc-700 uppercase tracking-[0.2em]">Registrar en {MONTHS[currentDate.getMonth()]}</p>
          </div>

          <div className="space-y-4">
            <div className="relative group">
              <select
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                className="w-full bg-black/60 rounded-2xl p-5 border border-white/10 font-black text-xs uppercase appearance-none text-center text-white focus:ring-2 focus:ring-indigo-500/50 outline-none transition-all"
              >
                {activeCategories[type]?.map(c => <option key={c} value={c}>{c}</option>)}
              </select>
              <div className="absolute inset-y-0 right-5 flex items-center pointer-events-none opacity-30">
                <Plus className="w-4 h-4" />
              </div>
            </div>

            <textarea
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder="Añadir detalle del movimiento..."
              className="w-full bg-black/40 rounded-2xl p-5 border border-white/10 font-bold text-xs focus:outline-none text-zinc-400 min-h-[100px] resize-none focus:border-indigo-500/50 transition-colors"
            />
          </div>

          <button
            onClick={handleSaveTransaction}
            disabled={!amount || !category}
            className={`w-full py-6 rounded-2xl font-black text-xs uppercase tracking-[0.25em] ios-tap shadow-2xl transition-all ${(!amount || !category) ? 'bg-zinc-800/50 text-zinc-700' : (type === 'GASTO' ? 'bg-rose-600' : 'bg-emerald-600')}`}
          >
            Confirmar Registro
          </button>
        </div>

        {/* Tab Bar */}
        <div className="fixed bottom-0 left-0 right-0 p-6 bg-gradient-to-t from-black via-black/95 to-transparent pt-16 z-[90]">
          <div className="max-w-md mx-auto flex gap-4">
            <button onClick={() => setShowHistoryModal(true)} className="flex-1 bg-zinc-900 border border-white/5 text-white py-5 rounded-2xl flex items-center justify-center gap-2 font-black text-[10px] uppercase tracking-widest ios-tap shadow-xl">
              <History className="w-4 h-4 text-zinc-500" /> Historial
            </button>
            <button onClick={() => setShowBudgetModal(true)} className="flex-1 bg-white text-black py-5 rounded-2xl flex items-center justify-center gap-2 font-black text-[10px] uppercase tracking-widest ios-tap shadow-2xl">
              <BarChart3 className="w-4 h-4" /> Categorías
            </button>
          </div>
        </div>

        {/* MODAL: Selector de Período Temporal */}
        {showDatePicker && (
          <div className="fixed inset-0 z-[200] bg-black/80 backdrop-blur-xl flex items-center justify-center p-8">
            <div className="w-full max-w-xs bg-zinc-900 rounded-[2.5rem] border border-white/10 p-8 space-y-6">
              <div className="flex justify-between items-center">
                <span className="text-[10px] font-black uppercase text-zinc-500 tracking-widest">Elegir Período</span>
                <button onClick={() => setShowDatePicker(false)} className="p-2"><X className="w-5 h-5" /></button>
              </div>
              <div className="space-y-4">
                <div className="space-y-1">
                  <p className="text-[9px] font-black text-zinc-600 uppercase tracking-widest ml-1">Mes</p>
                  <select
                    value={currentDate.getMonth()}
                    onChange={(e) => setCurrentDate(new Date(currentDate.getFullYear(), parseInt(e.target.value, 10), 1))}
                    className="w-full bg-black py-4 rounded-xl font-black text-center text-xs uppercase appearance-none"
                  >
                    {MONTHS.map((m, i) => <option key={m} value={i}>{m}</option>)}
                  </select>
                </div>
                <div className="space-y-1">
                  <p className="text-[9px] font-black text-zinc-600 uppercase tracking-widest ml-1">Año</p>
                  <select
                    value={currentDate.getFullYear()}
                    onChange={(e) => setCurrentDate(new Date(parseInt(e.target.value, 10), currentDate.getMonth(), 1))}
                    className="w-full bg-black py-4 rounded-xl font-black text-center text-xs appearance-none"
                  >
                    {[2024, 2025, 2026, 2027].map(y => <option key={y} value={y}>{y}</option>)}
                  </select>
                </div>
              </div>
              <button
                onClick={() => setShowDatePicker(false)}
                className="w-full py-5 bg-indigo-600 rounded-2xl font-black text-[10px] uppercase tracking-widest ios-tap"
              >
                Aplicar Período
              </button>
            </div>
          </div>
        )}

        {/* MODAL: Estrategia */}
        {showSettingsModal && (
          <div className="fixed inset-0 z-[120] bg-black flex flex-col pt-12">
            <div className="px-8 pb-8 flex justify-between items-center border-b border-white/10">
              <div>
                <h3 className="text-2xl font-black italic uppercase leading-none">Estrategia</h3>
                <p className="text-[9px] font-bold text-zinc-600 uppercase mt-1 tracking-widest italic">Optimización Patrimonial</p>
              </div>
              <button onClick={() => setShowSettingsModal(false)} className="p-3 bg-zinc-900 rounded-full shadow-lg active:scale-90 transition-transform">
                <X className="w-6 h-6" />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto px-8 py-8 space-y-10 no-scrollbar pb-32">
              <div className="relative p-7 rounded-[2.5rem] bg-gradient-to-br from-zinc-900 to-black border border-white/5 shadow-2xl overflow-hidden group">
                <div className="relative z-10 flex flex-col gap-6">
                  <div className="flex items-center gap-2">
                    <TrendingUp className="w-4 h-4 text-indigo-500" />
                    <span className="text-[10px] font-black uppercase tracking-widest text-zinc-400">Patrimonio Histórico</span>
                  </div>
                  <div className="grid grid-cols-2 gap-8">
                    <div className="space-y-1">
                      <p className="text-[9px] font-bold text-emerald-500 uppercase">Ahorro Total</p>
                      <p className="text-2xl font-black tracking-tighter">${formatNumber(stats.historicalSavingsTotal)}</p>
                    </div>
                    <div className="space-y-1">
                      <p className="text-[9px] font-bold text-indigo-400 uppercase">Inversión Total</p>
                      <p className="text-2xl font-black tracking-tighter">${formatNumber(stats.historicalInvestmentTotal)}</p>
                    </div>
                  </div>
                </div>
              </div>

              <div className="space-y-6">
                <PrecisionSelector
                  label="Ahorro Mensual"
                  subtext={`Hoy: -$${formatNumber(stats.savingsAmount)}`}
                  value={strategy.savingsPercent || 0}
                  onChange={(val) => updateStrategy('savingsPercent', val)}
                  color="emerald"
                  icon={PiggyBank}
                />
                <PrecisionSelector
                  label="Inversión Mensual"
                  subtext={`Hoy: -$${formatNumber(stats.investmentAmount)}`}
                  value={strategy.investmentPercent || 0}
                  onChange={(val) => updateStrategy('investmentPercent', val)}
                  color="indigo"
                  icon={TrendingUp}
                />
              </div>

              <div className="space-y-4">
                <div className="flex justify-between items-center">
                  <p className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-500 italic">Límites de Categorías</p>
                  <p className={`text-[10px] font-black uppercase px-3 py-1 rounded-full ${stats.availableToAssign < 0 ? 'bg-rose-500/10 text-rose-500' : 'bg-emerald-500/10 text-emerald-500'}`}>
                    Sobra: ${formatNumber(stats.availableToAssign)}
                  </p>
                </div>
                <div className="space-y-2">
                  {activeCategories.GASTO.map(cat => (
                    <div key={cat} className="flex items-center justify-between bg-zinc-900/40 p-5 rounded-2xl border border-white/5">
                      <span className="text-[10px] font-black uppercase text-zinc-300">{cat}</span>
                      <input
                        type="text"
                        value={formatNumber(budgets[cat]?.amount || 0)}
                        onChange={async (e) => {
                          const val = parseFormattedNumber(e.target.value);
                          await updateBudget(cat, val);
                        }}
                        className="bg-transparent text-right font-black text-sm w-24 focus:outline-none focus:text-indigo-400 transition-colors"
                        inputMode="numeric"
                      />
                    </div>
                  ))}
                </div>
              </div>

              <button onClick={() => setShowCatManager(true)} className="w-full py-5 border border-zinc-800 rounded-2xl text-[10px] font-black uppercase tracking-[0.2em] text-zinc-600 active:bg-zinc-900 transition-colors">
                Editar Nombres de Categorías
              </button>
            </div>
          </div>
        )}

        {/* MODAL: Historial */}
        {showHistoryModal && (
          <div className="fixed inset-0 z-[100] bg-black flex flex-col pt-12">
            <div className="px-8 pb-6 flex justify-between items-center border-b border-white/10">
              <h3 className="text-2xl font-black italic uppercase">Historial</h3>
              <div className="flex gap-2">
                <button onClick={exportExcel} className="p-3 bg-emerald-500 rounded-full text-black active:scale-90 transition-transform">
                  <FileSpreadsheet className="w-5 h-5" />
                </button>
                <button onClick={() => setShowHistoryModal(false)} className="p-3 bg-zinc-900 rounded-full active:scale-90 transition-transform"><X className="w-6 h-6" /></button>
              </div>
            </div>

            <div className="flex-1 overflow-y-auto px-6 py-6 space-y-4 no-scrollbar pb-24">
              {transactions.filter(t => {
                const d = new Date(t.date);
                return d.getMonth() === currentDate.getMonth() && d.getFullYear() === currentDate.getFullYear();
              }).length === 0 ? (
                <div className="pt-20 text-center space-y-4">
                  <p className="text-zinc-700 font-black uppercase text-[10px] tracking-[0.3em]">Sin movimientos en este período</p>
                </div>
              ) : transactions.filter(t => {
                const d = new Date(t.date);
                return d.getMonth() === currentDate.getMonth() && d.getFullYear() === currentDate.getFullYear();
              }).map(t => (
                <div key={t.id} className="bg-zinc-900/40 p-6 rounded-3xl border border-white/5 flex flex-col gap-4">
                  <div className="flex justify-between items-start">
                    <div className="flex items-center gap-4">
                      <div className={`w-12 h-12 rounded-2xl flex items-center justify-center font-black text-[10px] shadow-lg ${t.type === 'INGRESO' ? 'bg-emerald-500/20 text-emerald-500' : 'bg-rose-500/20 text-rose-500'}`}>
                        {t.type === 'INGRESO' ? 'IN' : 'OUT'}
                      </div>
                      <div>
                        <p className="text-[11px] font-black uppercase text-white tracking-wider mb-1">{t.category}</p>
                        <p className="text-[9px] font-bold text-zinc-600 uppercase italic">
                          {new Date(t.date).toLocaleDateString()}
                        </p>
                      </div>
                    </div>
                    <div className="flex flex-col items-end gap-2">
                      <p className={`text-xl font-black tracking-tighter ${t.type === 'INGRESO' ? 'text-emerald-500' : 'text-white'}`}>
                        ${formatNumber(t.amount)}
                      </p>
                      <button onClick={() => deleteTransaction(t.id)} className="p-2 text-rose-900/30 hover:text-rose-600 transition-colors">
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                  {t.note && (
                    <div className="px-4 py-3 bg-black/40 rounded-2xl border border-white/5">
                      <p className="text-[10px] font-medium text-zinc-500 italic">"{t.note}"</p>
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* MODAL: Categorías */}
        {showBudgetModal && (() => {
          const CHART_COLORS = ['#6366f1','#f43f5e','#10b981','#f59e0b','#3b82f6','#8b5cf6','#ec4899','#14b8a6','#f97316','#84cc16'];
          const chartData = activeCategories.GASTO
            .map((cat, i) => ({ cat, spent: stats.expenseByCategory[cat] || 0, color: CHART_COLORS[i % CHART_COLORS.length] }))
            .filter(d => d.spent > 0);
          const totalSpent = chartData.reduce((s, d) => s + d.spent, 0);

          // SVG donut
          const R = 80, r = 52, cx = 100, cy = 100;
          let angle = -Math.PI / 2;
          const slices = chartData.map(d => {
            const frac = d.spent / (totalSpent || 1);
            const a1 = angle, a2 = angle + frac * 2 * Math.PI;
            angle = a2;
            const x1o = cx + R * Math.cos(a1), y1o = cy + R * Math.sin(a1);
            const x2o = cx + R * Math.cos(a2), y2o = cy + R * Math.sin(a2);
            const x1i = cx + r * Math.cos(a2), y1i = cy + r * Math.sin(a2);
            const x2i = cx + r * Math.cos(a1), y2i = cy + r * Math.sin(a1);
            const large = frac > 0.5 ? 1 : 0;
            return { ...d, frac, path: `M${x1o},${y1o} A${R},${R} 0 ${large},1 ${x2o},${y2o} L${x1i},${y1i} A${r},${r} 0 ${large},0 ${x2i},${y2i} Z` };
          });

          return (
            <div className="fixed inset-0 z-[110] bg-black flex flex-col pt-12">
              <div className="px-8 pb-6 flex justify-between items-end border-b border-white/10">
                <div>
                  <h3 className="text-2xl font-black italic uppercase">Categorías</h3>
                  <p className="text-[9px] font-bold text-zinc-600 uppercase mt-1 tracking-widest italic">{MONTHS[currentDate.getMonth()]}</p>
                </div>
                <div className="flex items-center gap-3">
                  <button
                    onClick={() => setBudgetChartView(v => !v)}
                    className={`p-3 rounded-full transition-all active:scale-90 ${budgetChartView ? 'bg-indigo-600 text-white' : 'bg-zinc-900 text-zinc-400'}`}
                  >
                    {budgetChartView ? <BarChart3 className="w-5 h-5" /> : <PieChart className="w-5 h-5" />}
                  </button>
                  <button onClick={() => setShowBudgetModal(false)} className="p-3 bg-zinc-900 rounded-full active:scale-90 transition-transform"><X className="w-6 h-6" /></button>
                </div>
              </div>

              <div className="flex-1 overflow-y-auto px-8 py-8 no-scrollbar pb-32">
                {budgetChartView ? (
                  /* ── VISTA GRÁFICO ── */
                  <div className="space-y-8">
                    {totalSpent === 0 ? (
                      <p className="text-zinc-600 text-center text-xs mt-16 uppercase tracking-widest">Sin gastos este mes</p>
                    ) : (
                      <>
                        <div className="flex justify-center">
                          <svg viewBox="0 0 200 200" className="w-56 h-56">
                            {slices.map((s, i) => (
                              <path key={i} d={s.path} fill={s.color} />
                            ))}
                            <text x="100" y="96" textAnchor="middle" fill="white" fontSize="9" fontWeight="900" fontStyle="italic" className="uppercase tracking-widest">TOTAL</text>
                            <text x="100" y="112" textAnchor="middle" fill="white" fontSize="13" fontWeight="900">${formatNumber(totalSpent)}</text>
                          </svg>
                        </div>
                        <div className="space-y-3">
                          {slices.map((s, i) => (
                            <div key={i} className="flex items-center justify-between bg-zinc-900/40 rounded-2xl px-5 py-4 border border-white/5">
                              <div className="flex items-center gap-3">
                                <div className="w-3 h-3 rounded-full flex-shrink-0" style={{ backgroundColor: s.color }} />
                                <span className="text-xs font-black uppercase tracking-wider">{s.cat}</span>
                              </div>
                              <div className="text-right">
                                <p className="text-sm font-black">${formatNumber(s.spent)}</p>
                                <p className="text-[10px] text-zinc-500 font-bold">{(s.frac * 100).toFixed(1)}%</p>
                              </div>
                            </div>
                          ))}
                        </div>
                      </>
                    )}
                  </div>
                ) : (
                  /* ── VISTA BARRAS ── */
                  <div className="space-y-6">
                    {activeCategories.GASTO.map(cat => {
                      const limit = budgets[cat]?.amount || 0;
                      const spent = stats.expenseByCategory[cat] || 0;
                      const remaining = limit - spent;
                      const progress = limit > 0 ? Math.min(100, (spent / limit) * 100) : 0;
                      const isOver = remaining < 0;
                      return (
                        <div key={cat} className="bg-zinc-900/40 rounded-[2rem] p-7 border border-white/5 space-y-5 shadow-xl">
                          <div className="flex justify-between items-start">
                            <div className="space-y-1">
                              <h4 className="text-xs font-black uppercase tracking-[0.15em] text-white">{cat}</h4>
                              <p className="text-[10px] font-bold text-zinc-600 italic">Asignado: ${formatNumber(limit)}</p>
                            </div>
                            <div className="text-right">
                              <span className={`text-[9px] font-black uppercase block mb-1 tracking-widest ${isOver ? 'text-rose-500' : 'text-emerald-500'}`}>
                                {isOver ? 'Excedido' : 'Restante'}
                              </span>
                              <p className={`text-2xl font-black tracking-tighter ${isOver ? 'text-rose-500' : 'text-white'}`}>
                                ${formatNumber(remaining)}
                              </p>
                            </div>
                          </div>
                          <div className="h-2.5 bg-black rounded-full overflow-hidden border border-white/5 p-0.5">
                            <div
                              className={`h-full rounded-full transition-all duration-1000 shadow-lg ${isOver ? 'bg-rose-600' : 'bg-indigo-600'}`}
                              style={{ width: `${limit > 0 ? progress : 0}%` }}
                            />
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </div>
          );
        })()}

        {/* Modal Manager Categorías */}
        {showCatManager && (
          <div className="fixed inset-0 z-[160] bg-black/95 backdrop-blur-3xl flex flex-col pt-12 px-8">
            <div className="flex justify-between items-center mb-12">
              <h3 className="text-xl font-black uppercase italic">Nombres</h3>
              <button onClick={() => setShowCatManager(false)} className="p-3 bg-zinc-900 rounded-full active:scale-90 transition-transform"><X className="w-6 h-6" /></button>
            </div>
            <div className="flex gap-3 mb-10">
              <input
                value={newCatName}
                onChange={(e) => setNewCatName(e.target.value)}
                placeholder="Nueva categoría..."
                className="flex-1 bg-zinc-900/50 rounded-2xl p-5 border border-white/10 focus:outline-none font-bold text-sm text-white"
              />
              <button onClick={() => manageCategory('ADD', newCatName)} className="bg-indigo-600 p-5 rounded-2xl shadow-xl active:scale-95 transition-all"><Plus className="w-6 h-6 text-white" /></button>
            </div>
            <div className="space-y-3 overflow-y-auto no-scrollbar pb-10">
              {activeCategories[type]?.map(c => (
                <div key={c} className="flex justify-between items-center bg-zinc-900/30 p-6 rounded-2xl border border-white/5">
                  <span className="text-[11px] font-black uppercase tracking-widest text-zinc-300">{c}</span>
                  <button onClick={() => manageCategory('DELETE', c)} className="text-zinc-700 hover:text-rose-500 transition-colors">
                    <Trash2 className="w-5 h-5" />
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}

      </div>
    </div>
  );
}