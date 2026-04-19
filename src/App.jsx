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
  Target, Trophy, Wallet, Copy, Lightbulb, Calculator, Eye, EyeOff, LayoutGrid,
  GripVertical, BookOpen, MessageCircle, Send
} from 'lucide-react';
import { supabase } from './supabaseClient';
import {
  DndContext, closestCenter,
  PointerSensor, TouchSensor, KeyboardSensor,
  useSensor, useSensors
} from '@dnd-kit/core';
import {
  SortableContext, sortableKeyboardCoordinates,
  verticalListSortingStrategy, useSortable, arrayMove
} from '@dnd-kit/sortable';
import { CSS as DndCSS } from '@dnd-kit/utilities';

// Modulos extraidos en Fase 2 refactor
import {
  INITIAL_CATEGORIES, MONTHS, CHART_COLORS, DEFAULT_EMOJIS, EMOJI_PALETTE,
  FREQUENCIES, CATEGORY_KEYWORDS, GOAL_EMOJIS, DEFAULT_NEEDS_CATS, loadNeedsCats,
  GOALS_KEY, CUOTAS_KEY, MEMO_KEY, TEMPLATES_KEY,
  HIDDEN_WIDGETS_KEY, WIDGET_ORDER_KEY, WIDGET_SIZES_KEY,
  FIXED_TX_KEY, BUDGET_MODE_KEY, ACCOUNTS_KEY, ACCOUNT_TYPES_KEY,
  ALLOCATIONS_KEY, SAVINGS_ACCOUNT_KEY, CURRENCY_KEY, LANG_KEY,
  NEEDS_CATS_KEY, THEME_KEY, AI_CONFIG_KEY,
} from './lib/constants';
import {
  CURRENCIES, getCurrencyShortName, getCurrencyArticle,
  ACTIVE_CURRENCIES_KEY, DEFAULT_ACTIVE_CURRENCIES,
} from './lib/currencies';
import {
  formatNumber, formatNumberWithDecimals, parseFormattedNumber,
  parseVoiceAmount, haptic,
} from './lib/format';
import {
  WALLET_PROXY, SUPABASE_ANON_KEY, MP_OAUTH_CLIENT_ID, MP_OAUTH_REDIRECT,
  WALLET_PROVIDERS, createWalletAdapter,
} from './services/wallets';
import { fxGetRate } from './services/fx';
import { ToastProvider, useToast } from './contexts/ToastContext';
import { WalletLogo } from './components/WalletLogo';
import {
  AiIconOpenAI, AiIconGemini, AiIconClaude, AiIconCustom, AI_PROVIDERS,
} from './components/AiIcons';
import { SkeletonCard, LoadingSkeleton } from './components/Skeletons';

// Constantes, wallet providers, AI providers, etc. ahora viven en src/lib/ y src/components/.
// Ver imports al inicio del archivo.

// Wallet proxy config + createWalletAdapter ahora viven en src/services/wallets.js.
// fxGetRate vive en src/services/fx.js.

// ─── Traducciones (i18n básico) ────────────────────────────────────────────
const TRANSLATIONS = {
  es: {
    // Auth / Login
    loginTab: 'Ingresar', signupTab: 'Registrarse', loginBtn: 'Ingresar',
    createAccountBtn: 'Crear cuenta', forgotPassword: '¿Olvidaste tu contraseña?',
    checkSpam: 'Revisá spam/promociones si no llega el email de confirmación.',
    homeFinance: 'Finanzas del hogar',
    // Nav tabs
    home: 'Inicio', add: 'Registrar', history: 'Historial',
    stats: 'Estadísticas', budget: 'Presupuesto', settings: 'Ajustes',
    // Common
    income: 'Ingreso', expense: 'Gasto', available: 'Disponible',
    save: 'Guardar', cancel: 'Cancelar', delete: 'Eliminar', edit: 'Editar',
    account: 'Cuenta', subcategory: 'Subcategoría', category: 'Categoría',
    note: 'Nota', date: 'Fecha', amount: 'Monto', type: 'Tipo',
    all: 'Todos', noAccount: 'Sin cuenta',
    language: 'Idioma', currency: 'Moneda',
    accounts: 'Cuentas', addAccount: 'Agregar cuenta',
    total: 'Total', average: 'Promedio', balance: 'Balance',
    loading: 'Cargando…', saving: 'Guardando…', done: '¡Listo! ✓',
    close: 'Cerrar', confirm: 'Confirmar', apply: 'Aplicar →',
    movements: 'movimientos', movement: 'movimiento',
    today: 'Hoy', yesterday: 'Ayer', previous: 'anterior', next: 'próximo', current: 'actual',
    // Months
    january: 'Enero', february: 'Febrero', march: 'Marzo', april: 'Abril',
    may: 'Mayo', june: 'Junio', july: 'Julio', august: 'Agosto',
    september: 'Septiembre', october: 'Octubre', november: 'Noviembre', december: 'Diciembre',
    // Add tab
    quickShortcuts: 'Atajos rápidos',
    listening: 'Escuchando…', dictate: 'Dictado',
    transactionDate: 'Fecha del movimiento',
    registerIn: 'Registrar en el período de',
    diffFromReal: '≠ fecha real',
    optionalNote: 'Detalle opcional del movimiento…',
    suggestedCat: '¿Categoría sugerida',
    monthlyFixed: 'Gasto fijo mensual', monthlyFixedIncome: 'Ingreso fijo mensual',
    autoRegisterEachMonth: 'Se registrará automáticamente cada mes',
    activateToReplicate: 'Activar para replicar cada mes',
    confirmRegister: 'Confirmar registro',
    saveAsShortcut: 'Guardar como atajo rápido',
    noAccountSpecified: 'Sin especificar',
    general: 'General', newCategory: 'Nueva',
    // History tab
    search: 'Buscar por categoría, nota o monto…',
    thisWeek: 'Esta semana', activeRange: 'Rango activo', range: 'Rango',
    allMonths: 'Todos los meses',
    customRange: 'Rango personalizado', from: 'Desde', to: 'Hasta',
    clear: 'Limpiar', clearDay: '× Limpiar día',
    mostRecent: 'Más reciente', oldest: 'Más antiguo',
    highestAmount: 'Mayor monto', lowestAmount: 'Menor monto',
    noResults: 'Sin resultados para esa búsqueda',
    noMovementsMonth: 'Sin movimientos este mes',
    registerOne: '+ Registrar uno',
    goToToday: 'Ir a hoy →',
    expenses: 'Gastos', incomes: 'Ingresos',
    // Stats tab
    monthlyReport: 'Informe mensual', fullSummary: 'Resumen completo',
    reports: 'Reportes',
    financialHealth: 'Índice de salud financiera',
    spendingSpeed: 'Velocidad de gasto',
    topExpenses: 'Top gastos del mes', worstWeek: 'Peor semana',
    savingsMomentum: 'Momentum de ahorro',
    trends: 'Tendencias', balanceTrend: 'Tendencia de balance',
    weekVsWeek: 'Semana vs semana', thisWeekLabel: 'Esta semana', prevWeek: 'Semana anterior',
    vsLastMonth: 'Comparativa mes anterior',
    weeklyHeatmap: 'Heatmap semanal (promedio)',
    categoryCycle: 'Ciclo de categorías',
    achievementsUnlocked: 'Logros desbloqueados',
    byAccount: '👥 Por cuenta',
    // Budget tab
    totalIncome: 'Total ingresado',
    noIncomeThisPeriod: 'Sin ingresos en este período',
    budgetedAvailable: 'Disponible presupuestado',
    accordingToPlan: 'según plan',
    realAvailable: 'Disponible real',
    accordingToExpenses: 'según gastos reales',
    fixedExpenses: 'Gastos fijos',
    noFixedExpenses: 'Sin gastos fijos configurados',
    markFixedToAdd: "Marcá 'Fijo' al cargar un gasto para agregarlo aquí",
    paidFixed: 'Fijos pagados este período',
    billsAndInstallments: 'Vencimientos y cuotas',
    noBills: 'Sin vencimientos ni cuotas este período',
    manageBillsInSettings: 'Gestioná vencimientos en Ajustes',
    strategy: 'Estrategia',
    savingsThisPeriod: 'Ahorro este período', investmentThisPeriod: 'Inversión este período',
    categoryLimits: 'Límites de categorías',
    suggestFromHistory: 'Sugerir del historial (+5% buffer)',
    // Settings tab
    activeInstallments: 'Cuotas en curso', manageInstallments: 'Administrar cuotas',
    savingsGoals: 'Metas de ahorro', manageSavingsGoals: 'Administrar metas',
    debtsLoans: 'Deudas y préstamos', manageDebts: 'Administrar deudas',
    automation: 'Automatización', recurringMovements: 'Movimientos recurrentes',
    categories: 'Categorías',
    editCategories: 'Editar categorías →', viewExpenseChart: 'Ver gráfico de gastos →',
    billsAndAlerts: 'Vencimientos y alertas',
    exchangeRate: 'Tipo de cambio',
    exportCsv: 'Exportar CSV', backupJson: 'Backup JSON completo',
    restoreJson: 'Restaurar backup JSON',
    signOut: 'Cerrar sesión',
    fixedTermCalc: 'Calculadora plazo fijo',
    helpCenter: 'Centro de ayuda',
    helpTopics: 'Temas',
    helpSearch: 'Buscar',
    helpChat: 'Chat IA',
    helpSearchPlaceholder: 'Buscar en la ayuda...',
    helpNoResults: 'Sin resultados para esa búsqueda',
    helpChatPlaceholder: 'Preguntale algo sobre MetaCasa...',
    helpChatWelcome: '¡Hola! Soy el asistente de MetaCasa. Preguntame lo que quieras sobre la app.',
    helpChatError: 'Hubo un error. Intentá de nuevo.',
    helpBackToTopics: '← Volver a temas',
    helpTipPrefix: 'Tip:',
    aiConfigTitle: 'Configurar IA',
    aiSelectProvider: 'Proveedor de IA',
    aiModel: 'Modelo',
    aiOptional: 'opcional',
    aiTestConnection: 'Probar conexión',
    aiTesting: 'Probando…',
    aiConnectionOk: 'Conexión exitosa',
    aiDisconnect: 'Desconectar IA',
    aiConfigured: 'Configurado',
    aiNotConfigured: 'IA no configurada',
    aiSetupPrompt: 'Conectá tu propia API key para activar el chat con IA.',
    aiSetupButton: 'Configurar IA →',
    newName: 'Nuevo nombre…',
    usdToArs: 'USD → ARS', enterDollarValue: 'Ingresá el valor del dólar manualmente',
    // Budget items
    dueDay: 'Vence día', monthly: 'Mensual', installment: 'Cuota',
    day: 'Día',
    // Common actions
    editArrow: 'Editar →', seeAll: 'Ver todas →', seeAllArrow: 'Ver →',
    // Home tab
    periodBalance: 'Balance del período',
    availableBalance: 'Saldo disponible',
    seeDetailByCategory: 'Ver detalle por categoría →',
    seeDetail: 'Ver detalle →',
    monthInstallments: 'Cuotas del mes',
    topExpensesMonth: 'Top gastos del mes',
    savings: 'Ahorro', investment: 'Inversión',
    incomeSources: 'Fuentes de ingreso',
    expenseDistribution: 'Distribución de gastos',
    expensesLabel: 'gastos',
    incomesLabel: 'Ingresos', expensesTitle: 'Gastos',
    prevIncome: 'Ingresos ant.', prevExpenses: 'Gastos ant.',
    estIncome: 'Ingresos est.', estExpenses: 'Gastos est.',
    ofIncome: '% ingresos',
    recurringFixed: 'Gastos fijos recurrentes',
    expensesMonth: 'Gastos del mes',
    last6months: 'Ingresos vs Gastos — últimos 6 meses',
    incomeVsExpenses: 'Ingresos vs Gastos',
    expectedIncome: 'Ingresos esperados', expected: 'Esperado',
    received: 'Recibido ✓', pending: 'Pendiente de recibir',
    incomePerDay: '📗 Ingresos por día', expenseDistDay: 'Gastos por día',
    antExpenses: 'Gastos ant.', antIncome: 'Ingresos ant.',
  },
  en: {
    // Auth / Login
    loginTab: 'Sign In', signupTab: 'Sign Up', loginBtn: 'Sign In',
    createAccountBtn: 'Create Account', forgotPassword: 'Forgot your password?',
    checkSpam: 'Check spam/promotions if you don\'t receive the confirmation email.',
    homeFinance: 'Home finances',
    // Nav tabs
    home: 'Home', add: 'Add', history: 'History',
    stats: 'Stats', budget: 'Budget', settings: 'Settings',
    // Common
    income: 'Income', expense: 'Expense', available: 'Available',
    save: 'Save', cancel: 'Cancel', delete: 'Delete', edit: 'Edit',
    account: 'Account', subcategory: 'Subcategory', category: 'Category',
    note: 'Note', date: 'Date', amount: 'Amount', type: 'Type',
    all: 'All', noAccount: 'No account',
    language: 'Language', currency: 'Currency',
    accounts: 'Accounts', addAccount: 'Add account',
    total: 'Total', average: 'Average', balance: 'Balance',
    loading: 'Loading…', saving: 'Saving…', done: 'Done! ✓',
    close: 'Close', confirm: 'Confirm', apply: 'Apply →',
    movements: 'transactions', movement: 'transaction',
    today: 'Today', yesterday: 'Yesterday', previous: 'previous', next: 'next', current: 'current',
    // Months
    january: 'January', february: 'February', march: 'March', april: 'April',
    may: 'May', june: 'June', july: 'July', august: 'August',
    september: 'September', october: 'October', november: 'November', december: 'December',
    // Add tab
    quickShortcuts: 'Quick shortcuts',
    listening: 'Listening…', dictate: 'Dictate',
    transactionDate: 'Transaction date',
    registerIn: 'Assign to period',
    diffFromReal: '≠ real date',
    optionalNote: 'Optional transaction detail…',
    suggestedCat: 'Suggested category',
    monthlyFixed: 'Monthly fixed expense', monthlyFixedIncome: 'Monthly fixed income',
    autoRegisterEachMonth: 'Will be registered automatically each month',
    activateToReplicate: 'Activate to replicate each month',
    confirmRegister: 'Confirm',
    saveAsShortcut: 'Save as quick shortcut',
    noAccountSpecified: 'Not specified',
    general: 'General', newCategory: 'New',
    // History tab
    search: 'Search by category, note or amount…',
    thisWeek: 'This week', activeRange: 'Active range', range: 'Range',
    allMonths: 'All months',
    customRange: 'Custom range', from: 'From', to: 'To',
    clear: 'Clear', clearDay: '× Clear day',
    mostRecent: 'Most recent', oldest: 'Oldest',
    highestAmount: 'Highest amount', lowestAmount: 'Lowest amount',
    noResults: 'No results for that search',
    noMovementsMonth: 'No movements this month',
    registerOne: '+ Add one',
    goToToday: 'Go to today →',
    expenses: 'Expenses', incomes: 'Income',
    // Stats tab
    monthlyReport: 'Monthly report', fullSummary: 'Full summary',
    reports: 'Reports',
    financialHealth: 'Financial health index',
    spendingSpeed: 'Spending speed',
    topExpenses: 'Top expenses this month', worstWeek: 'Worst week',
    savingsMomentum: 'Savings momentum',
    trends: 'Trends', balanceTrend: 'Balance trend',
    weekVsWeek: 'Week vs week', thisWeekLabel: 'This week', prevWeek: 'Previous week',
    vsLastMonth: 'vs last month',
    weeklyHeatmap: 'Weekly heatmap (average)',
    categoryCycle: 'Category cycle',
    achievementsUnlocked: 'Achievements unlocked',
    byAccount: '👥 By account',
    // Budget tab
    totalIncome: 'Total income',
    noIncomeThisPeriod: 'No income this period',
    budgetedAvailable: 'Budgeted available',
    accordingToPlan: 'according to plan',
    realAvailable: 'Real available',
    accordingToExpenses: 'according to real expenses',
    fixedExpenses: 'Fixed expenses',
    noFixedExpenses: 'No fixed expenses configured',
    markFixedToAdd: "Mark 'Fixed' when adding an expense to include it here",
    paidFixed: 'Fixed expenses paid this period',
    billsAndInstallments: 'Bills and installments',
    noBills: 'No bills or installments this period',
    manageBillsInSettings: 'Manage bills in Settings',
    strategy: 'Strategy',
    savingsThisPeriod: 'Savings this period', investmentThisPeriod: 'Investment this period',
    categoryLimits: 'Category limits',
    suggestFromHistory: 'Suggest from history (+5% buffer)',
    // Settings tab
    activeInstallments: 'Active installments', manageInstallments: 'Manage installments',
    savingsGoals: 'Savings goals', manageSavingsGoals: 'Manage savings goals',
    debtsLoans: 'Debts & loans', manageDebts: 'Manage debts',
    automation: 'Automation', recurringMovements: 'Recurring transactions',
    categories: 'Categories',
    editCategories: 'Edit categories →', viewExpenseChart: 'View expense chart →',
    billsAndAlerts: 'Bills and alerts',
    exchangeRate: 'Exchange rate',
    exportCsv: 'Export CSV', backupJson: 'Full JSON backup',
    restoreJson: 'Restore JSON backup',
    signOut: 'Sign out',
    fixedTermCalc: 'Fixed term calculator',
    helpCenter: 'Help Center',
    helpTopics: 'Topics',
    helpSearch: 'Search',
    helpChat: 'AI Chat',
    helpSearchPlaceholder: 'Search help...',
    helpNoResults: 'No results for that search',
    helpChatPlaceholder: 'Ask anything about MetaCasa...',
    helpChatWelcome: 'Hi! I\'m the MetaCasa assistant. Ask me anything about the app.',
    helpChatError: 'There was an error. Please try again.',
    helpBackToTopics: '← Back to topics',
    helpTipPrefix: 'Tip:',
    aiConfigTitle: 'Configure AI',
    aiSelectProvider: 'AI Provider',
    aiModel: 'Model',
    aiOptional: 'optional',
    aiTestConnection: 'Test connection',
    aiTesting: 'Testing…',
    aiConnectionOk: 'Connection successful',
    aiDisconnect: 'Disconnect AI',
    aiConfigured: 'Configured',
    aiNotConfigured: 'AI not configured',
    aiSetupPrompt: 'Connect your own API key to enable the AI chat.',
    aiSetupButton: 'Configure AI →',
    newName: 'New name…',
    usdToArs: 'USD → ARS', enterDollarValue: 'Enter the dollar value manually',
    // Budget items
    dueDay: 'Due day', monthly: 'Monthly', installment: 'Installment',
    day: 'Day',
    // Common actions
    editArrow: 'Edit →', seeAll: 'See all →', seeAllArrow: 'See →',
    // Home tab
    periodBalance: 'Period balance',
    availableBalance: 'Available balance',
    seeDetailByCategory: 'See detail by category →',
    seeDetail: 'See detail →',
    monthInstallments: 'Monthly installments',
    topExpensesMonth: 'Top expenses',
    savings: 'Savings', investment: 'Investment',
    incomeSources: 'Income sources',
    expenseDistribution: 'Expense distribution',
    expensesLabel: 'expenses',
    incomesLabel: 'Income', expensesTitle: 'Expenses',
    prevIncome: 'Prev. income', prevExpenses: 'Prev. expenses',
    estIncome: 'Est. income', estExpenses: 'Est. expenses',
    ofIncome: '% of income',
    recurringFixed: 'Recurring fixed expenses',
    expensesMonth: 'Monthly expenses',
    last6months: 'Income vs Expenses — last 6 months',
    incomeVsExpenses: 'Income vs Expenses',
    expectedIncome: 'Expected income', expected: 'Expected',
    received: 'Received ✓', pending: 'Pending receipt',
    incomePerDay: '📗 Income per day', expenseDistDay: 'Expenses per day',
    antExpenses: 'Prev. expenses', antIncome: 'Prev. income',
  },
};
// Helper de traducción: t(lang, 'key')
const t = (lang, key) => TRANSLATIONS[lang]?.[key] ?? TRANSLATIONS['es'][key] ?? key;

// ─── Help Center: contenido del manual ──────────────────────────────────────
const HELP_CONTENT = (lng) => {
  const es = lng === 'es';
  return [
    { id:'dashboard', icon:'🏠', title: es?'Inicio / Dashboard':'Home / Dashboard', subtitle: es?'Balance, widgets y vista general':'Balance, widgets and overview', keywords:['inicio','home','dashboard','balance','saldo','widget','resumen'],
      sections:[
        { heading: es?'Vista general':'Overview', body: es?'La pantalla de inicio muestra tu balance del período actual, un resumen de ingresos vs gastos, y widgets personalizables. Podés cambiar el período con las flechas en la parte superior.':'The home screen shows your current period balance, an income vs expenses summary, and customizable widgets. Change the period with the top arrows.' },
        { heading: es?'Widgets personalizables':'Customizable widgets', body: es?'Tocá el botón de grilla (⊞) para abrir el editor de widgets. Podés mostrar/ocultar cada widget, cambiar su tamaño (S/M/L) y reordenarlos.':'Tap the grid button (⊞) to open the widget editor. Show/hide each widget, change its size (S/M/L) and reorder them.' },
        { heading: es?'Plan del mes (Waterfall)':'Monthly plan (Waterfall)', body: es?'El widget "Plan del mes" muestra: Ingresos → Gastos fijos → Vencimientos → Ahorro/Inversión → Disponible. Te da una foto clara de cuánto tenés libre.':'The "Monthly plan" widget shows: Income → Fixed expenses → Bills → Savings/Investment → Available. A clear picture of free funds.' },
      ], tip: es?'Mantené presionado un widget para ver opciones de tamaño.':'Long press a widget to see size options.' },
    { id:'addTransaction', icon:'➕', title: es?'Registrar movimiento':'Add transaction', subtitle: es?'Gastos, ingresos, voz, atajos rápidos':'Expenses, income, voice, quick shortcuts', keywords:['agregar','registrar','gasto','ingreso','add','transaction','voz','voice','atajo','shortcut','fijo'],
      sections:[
        { heading: es?'Registrar un gasto o ingreso':'Add an expense or income', body: es?'Elegí tipo (Gasto/Ingreso), ingresá monto, seleccioná categoría y opcionalmente una nota. Podés asignar cuenta y fecha diferente.':'Choose type (Expense/Income), enter amount, select category and optionally a note. Assign an account and different date.' },
        { heading: es?'Dictado por voz':'Voice dictation', body: es?'Tocá el ícono de micrófono y dictá "mil pesos en supermercado". La app detecta monto y sugiere categoría.':'Tap the mic icon and say "50 dollars groceries". The app detects the amount and suggests a category.' },
        { heading: es?'Atajos rápidos':'Quick shortcuts', body: es?'Movimientos frecuentes guardados. Activá "Guardar como atajo rápido" al registrar. Aparecen como botones de un solo toque.':'Saved frequent transactions. Enable "Save as quick shortcut" when registering. They appear as one-tap buttons.' },
        { heading: es?'Gastos fijos mensuales':'Monthly fixed expenses', body: es?'Activá "Gasto fijo mensual" para crear un template. Cada mes aparece en el presupuesto con un tilde para marcar como pagado.':'Enable "Monthly fixed expense" to create a template. Each month it appears in the budget with a checkbox to mark as paid.' },
        { heading: es?'Multi-moneda':'Multi-currency', body: es?'Registrá en otra moneda y se convierte automáticamente a tu moneda base con el tipo de cambio de Ajustes.':'Register in another currency and it converts automatically to your base currency with the exchange rate from Settings.' },
      ], tip: es?'Asigná la cuenta correcta (Personal o Compartida) a cada gasto.':'Assign the correct account (Personal or Shared) to each expense.' },
    { id:'budget', icon:'🐷', title: es?'Presupuesto':'Budget', subtitle: es?'Waterfall, límites, gastos fijos, estrategia':'Waterfall, limits, fixed expenses, strategy', keywords:['presupuesto','budget','límite','limit','waterfall','cascada','semáforo','disponible'],
      sections:[
        { heading: es?'Modelo Waterfall':'Waterfall model', body: es?'Del ingreso total se deducen: 1) gastos fijos, 2) vencimientos/cuotas, 3) ahorro, 4) inversión. El sobrante se distribuye entre cuentas personales.':'From total income: 1) fixed expenses, 2) bills/installments, 3) savings, 4) investment are deducted. Remainder goes to personal accounts.' },
        { heading: es?'Límites por categoría':'Category limits', body: es?'Asigná un límite en $ o % a cada categoría. Semáforo: verde = OK, amarillo = cerca, rojo = pasado. Solo se muestran categorías con gastos en esa cuenta.':'Set a $ or % limit per category. Traffic light: green = OK, yellow = close, red = over. Only categories with expenses in that account are shown.' },
        { heading: es?'Gastos fijos en presupuesto':'Fixed expenses in budget', body: es?'Los gastos "fijos" aparecen con tilde para marcar pagado. Al tildar se crea la transacción real en tu saldo.':'Fixed expenses appear with a checkbox to mark paid. Checking creates the real transaction in your balance.' },
        { heading: es?'Estrategia ahorro/inversión':'Savings/investment strategy', body: es?'Definí % de ingreso para ahorro e inversión. Se deduce automáticamente antes del disponible.':'Set income % for savings and investment. Automatically deducted before available funds.' },
      ], tip: es?'Tocá "Sugerir del historial" para límites basados en gastos pasados.':'Tap "Suggest from history" for limits based on past spending.' },
    { id:'accounts', icon:'👥', title: es?'Cuentas (Personal / Compartida)':'Accounts (Personal / Shared)', subtitle: es?'Gestión de cuentas y vista Hogar':'Account management and Home view', keywords:['cuenta','account','personal','compartida','shared','hogar','pareja','couple'],
      sections:[
        { heading: es?'Tipos de cuenta':'Account types', body: es?'Personal (ej: "Ariel") para gastos individuales. Compartida (ej: "Casa") para gastos del hogar.':'Personal (e.g. "Ariel") for individual expenses. Shared (e.g. "Home") for household expenses.' },
        { heading: es?'Vista Hogar':'Household view', body: es?'En Presupuesto, "Hogar" consolida todos los ingresos y muestra el waterfall completo. Vistas personales muestran solo tu porción.':'In Budget, "Household" consolidates all income and shows the full waterfall. Personal views show only your portion.' },
        { heading: es?'Distribución':'Distribution', body: es?'Elegí: "Igual" (50/50), "Proporcional" (según ingreso de cada uno) o montos fijos.':'Choose: "Equal" (50/50), "Proportional" (by each person\'s income) or custom fixed amounts.' },
      ], tip: es?'Creá 3 cuentas: una personal por persona + una compartida.':'Create 3 accounts: one personal per person + one shared.' },
    { id:'bills', icon:'🔔', title: es?'Vencimientos y alertas':'Bills & due dates', subtitle: es?'Vencimientos recurrentes, calendario':'Recurring bills, calendar, alerts', keywords:['vencimiento','bill','alerta','alert','vence','due','calendario','calendar'],
      sections:[
        { heading: es?'Agregar vencimientos':'Add bills', body: es?'En Ajustes → Vencimientos y alertas, agregá facturas con fecha y monto. Configurá como mensuales, anuales o únicas.':'In Settings → Bills and alerts, add bills with date and amount. Set as monthly, yearly or one-time.' },
        { heading: es?'Calendario':'Calendar', body: es?'En Presupuesto, tocá 📅 para ver el calendario visual con vencimientos marcados. Tocá un día para ver detalles.':'In Budget, tap 📅 to see a visual calendar with marked due dates. Tap a day to see details.' },
        { heading: es?'Indicadores de estado':'Status indicators', body: es?'Normal = gris, próximo (3 días) = amarillo, vencido = rojo.':'Normal = gray, upcoming (3 days) = yellow, overdue = red.' },
      ], tip: es?'Las cuotas y vencimientos se deducen automáticamente del disponible.':'Installments and bills are auto-deducted from available funds.' },
    { id:'installments', icon:'💳', title: es?'Cuotas':'Installments', subtitle: es?'Seguimiento de pagos en cuotas':'Installment tracking', keywords:['cuota','installment','pago','payment','tarjeta','card'],
      sections:[
        { heading: es?'Registrar cuotas':'Register installments', body: es?'En Ajustes → Cuotas, agregá compras con monto por cuota, total y pagadas. Se calcula cuánto falta.':'In Settings → Installments, add purchases with per-installment amount, total and paid. Remaining is auto-calculated.' },
        { heading: es?'En el presupuesto':'In the budget', body: es?'Las cuotas activas aparecen en "Vencimientos y cuotas" y se deducen del disponible.':'Active installments appear in "Bills and installments" and are deducted from available funds.' },
      ], tip: es?'La barra de progreso muestra cuántas cuotas faltan.':'The progress bar shows how many installments remain.' },
    { id:'goals', icon:'🎯', title: es?'Metas de ahorro':'Savings goals', subtitle: es?'Objetivos y progreso':'Targets and progress', keywords:['meta','goal','ahorro','saving','objetivo','target','progreso'],
      sections:[
        { heading: es?'Crear y gestionar metas':'Create and manage goals', body: es?'En Ajustes → Metas de ahorro, creá metas con nombre, monto objetivo y fecha opcional. Registrá contribuciones parciales.':'In Settings → Savings goals, create goals with name, target amount and optional deadline. Register partial contributions.' },
      ], tip: es?'Las metas aparecen como widget en el Dashboard.':'Goals appear as a widget on the Dashboard.' },
    { id:'debts', icon:'🤝', title: es?'Deudas y préstamos':'Debts & loans', subtitle: es?'Quién le debe a quién':'Track who owes whom', keywords:['deuda','debt','préstamo','loan','debe','owe','cobrar'],
      sections:[
        { heading: es?'Registrar deudas':'Register debts', body: es?'En Ajustes → Deudas, registrá lo que te deben o lo que debés. Marcá pagos parciales y seguí el saldo pendiente.':'In Settings → Debts, register what is owed to you or what you owe. Mark partial payments and track pending balance.' },
      ], tip: es?'Las deudas pendientes aparecen como widget en el Home.':'Pending debts appear as a widget on the Home screen.' },
    { id:'recurring', icon:'🔄', title: es?'Movimientos recurrentes':'Recurring transactions', subtitle: es?'Templates automáticos':'Automatic templates', keywords:['recurrente','recurring','automático','repetir','frecuencia'],
      sections:[
        { heading: es?'Configurar recurrentes':'Set up recurring', body: es?'En Ajustes → Recurrentes, creá templates automáticos (diario, semanal, mensual, anual). Ideal para sueldos, alquileres, suscripciones.':'In Settings → Recurring, create auto templates (daily, weekly, monthly, yearly). Ideal for salaries, rent, subscriptions.' },
      ], tip: es?'El widget "Recordatorio recurrentes" avisa cuando hay pendientes.':'The "Recurring reminders" widget alerts when there are pending items.' },
    { id:'fixedExpenses', icon:'📌', title: es?'Gastos fijos':'Fixed expenses', subtitle: es?'Templates mensuales, control de pago':'Monthly templates, payment tracking', keywords:['fijo','fixed','mensual','monthly','template','pagado','tilde'],
      sections:[
        { heading: es?'Cómo funcionan':'How they work', body: es?'Al registrar un gasto, activá "Gasto fijo mensual". Cada mes aparece en el presupuesto de la cuenta asignada con tilde para marcar pagado.':'When registering, enable "Monthly fixed expense". Each month it appears in the assigned account\'s budget with a checkbox to mark paid.' },
        { heading: es?'Asignación a cuenta':'Account assignment', body: es?'Los gastos fijos se asocian a la cuenta donde los registraste. Si lo registrás en "Casa", aparece en el presupuesto de "Casa".':'Fixed expenses are linked to the account where you registered them. If registered in "Home", it appears in "Home" budget.' },
      ], tip: es?'Al tildar como pagado se crea automáticamente la transacción real.':'Marking as paid automatically creates the real transaction.' },
    { id:'stats', icon:'📊', title: es?'Estadísticas y reportes':'Analytics & reports', subtitle: es?'Salud financiera, Pareto, tendencias':'Financial health, Pareto, trends', keywords:['estadísticas','stats','analytics','reporte','report','salud','health','tendencia','trend','pareto'],
      sections:[
        { heading: es?'Índice de salud financiera':'Financial health index', body: es?'Score 0-100: relación ingreso/gasto, constancia de registro, diversificación y cumplimiento de presupuesto. Calificación A-F.':'Score 0-100: income/expense ratio, registration consistency, diversification and budget compliance. Letter grade A-F.' },
        { heading: es?'Reportes mensuales':'Monthly reports', body: es?'Informe con top gastos, velocidad de gasto, Pareto (80/20) y comparativa con meses anteriores.':'Report with top expenses, spending speed, Pareto (80/20) and comparison with previous months.' },
        { heading: es?'Tendencias':'Trends', body: es?'Evolución de balance, semana a semana, heatmap de gastos y ciclo de categorías.':'Balance evolution, week-to-week, spending heatmap and category cycle.' },
      ], tip: es?'En Ajustes accedé al reporte mensual y vista anual.':'In Settings access the monthly report and annual view.' },
    { id:'wallets', icon:'💼', title: es?'Billeteras':'Wallets', subtitle: es?'Mercado Pago, PayPal, saldo manual':'Mercado Pago, PayPal, manual balance', keywords:['billetera','wallet','mercadopago','paypal','saldo','balance','conectar','sincronizar'],
      sections:[
        { heading: es?'Conectar billeteras':'Connect wallets', body: es?'En Billeteras, conectá Mercado Pago (OAuth o token), PayPal u otras. Sincronización automática.':'In Wallets, connect Mercado Pago (OAuth or token), PayPal or others. Automatic sync.' },
        { heading: es?'Saldo manual':'Manual balance', body: es?'Creá billeteras manuales para efectivo o cuentas sin integración.':'Create manual wallets for cash or accounts without integration.' },
      ], tip: es?'Importá movimientos individuales tocando "Importar →".':'Import individual transactions by tapping "Import →".' },
    { id:'exportImport', icon:'📦', title: es?'Exportar e importar':'Export & import', subtitle: es?'CSV, backup JSON, restaurar':'CSV, JSON backup, restore', keywords:['exportar','export','importar','import','backup','csv','json','restaurar','restore'],
      sections:[
        { heading: es?'Exportar CSV':'Export CSV', body: es?'En Ajustes → Exportar CSV: archivo compatible con Excel/Google Sheets.':'In Settings → Export CSV: file compatible with Excel/Google Sheets.' },
        { heading: es?'Backup JSON':'JSON backup', body: es?'Incluye todo: movimientos, categorías, metas, deudas, cuotas, cuentas y config. Restaurá en otro dispositivo.':'Includes everything: transactions, categories, goals, debts, installments, accounts and config. Restore on another device.' },
      ], tip: es?'Hacé backup periódico para proteger tus datos.':'Make periodic backups to protect your data.' },
    { id:'settings', icon:'⚙️', title: es?'Ajustes generales':'General settings', subtitle: es?'Tema, idioma, moneda':'Theme, language, currency', keywords:['ajustes','settings','tema','theme','idioma','language','moneda','currency','cambio','exchange','oscuro','dark','claro','light'],
      sections:[
        { heading: es?'Idioma':'Language', body: es?'Español o English. Cambio instantáneo.':'Español or English. Instant switch.' },
        { heading: es?'Apariencia':'Appearance', body: es?'Modo Oscuro, Claro o Automático (sigue el sistema).':'Dark, Light or Auto mode (follows system).' },
        { heading: es?'Moneda y tipo de cambio':'Currency and exchange rate', body: es?'Configurá moneda base y otras activas. Tipos de cambio manuales (blue, oficial, MEP).':'Set base currency and active ones. Manual exchange rates (parallel, official).' },
      ], tip: es?'Activá múltiples monedas para viajes.':'Enable multiple currencies for travel.' },
    { id:'waterfall', icon:'🌊', title: es?'Presupuesto para parejas':'Budget for couples', subtitle: es?'Ingresos conjuntos, distribución':'Joint income, distribution', keywords:['pareja','couple','waterfall','conjunto','joint','distribución','compartido'],
      sections:[
        { heading: es?'Cómo funciona':'How it works', body: es?'Ambos sueldos entran al pool del hogar. Se deducen gastos fijos compartidos, vencimientos, cuotas, ahorro e inversión. El sobrante se reparte entre cuentas personales.':'Both salaries enter the household pool. Shared fixed expenses, bills, installments, savings and investment are deducted. Remainder is distributed among personal accounts.' },
        { heading: es?'Configuración':'Setup', body: es?'1. Creá cuentas personales + una compartida. 2. Configurá distribución en Ajustes → Sistema Hogar. 3. Registrá ingresos y gastos con la cuenta correcta.':'1. Create personal accounts + one shared. 2. Configure distribution in Settings → Home System. 3. Register income and expenses with the correct account.' },
      ], tip: es?'Cada persona ve su disponible personal después de cubrir los gastos compartidos.':'Each person sees their available amount after covering shared expenses.' },
  ];
};

// Helper: returns the budget period (year, 0-based month) for a transaction.
// Uses period_year/period_month when set (cross-month assignment), else falls back to the real date.
const txBudgetPeriod = (t) => {
  if (t.period_year != null) return { year: t.period_year, month: t.period_month };
  const d = new Date(t.date);
  return { year: d.getFullYear(), month: d.getMonth() };
};
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
  { id: 'monthlySavingsGoal',label:'Meta de ahorro mensual',   icon: '💰' },
  { id: 'quarterSummary',   label: 'Resumen trimestral',        icon: '🗃️' },
  { id: 'healthCheckList',  label: 'Chequeo financiero',        icon: '📋' },
  { id: 'achievements',     label: 'Logros desbloqueados',      icon: '🏅' },
  { id: 'incomeByDow',      label: 'Ingresos por día de semana',icon: '📗' },
  { id: 'stabilityIndex',   label: 'Índice de estabilidad',     icon: '🧭' },
  { id: 'recurringFixed', label: 'Gastos fijos recurrentes', icon: '📌' },
  { id: 'gastosHoy',      label: 'Gasto de hoy',            icon: '📅' },
  { id: 'monthStats',     label: 'Mini estadísticas',        icon: '📊' },
  // Secciones hardcodeadas — ahora configurables
  { id: 'savings',        label: 'Ahorro e inversión',       icon: '🐷' },
  { id: 'donutChart',     label: 'Distribución de gastos',   icon: '🥧' },
  { id: 'insights',       label: 'Insights dinámicos',       icon: '💡' },
  { id: 'spendingCal',    label: 'Calendario de gastos',     icon: '📅' },
  { id: 'sparkline7d',    label: 'Últimos 7 días',           icon: '📊' },
  { id: 'esteMesGrid',    label: 'Este mes en números',      icon: '🔢' },
  { id: 'savingsRate',    label: 'Tasa de ahorro',           icon: '💚' },
  { id: 'globalBudget',   label: 'Barra de presupuesto',     icon: '📏' },
  { id: 'catTrends3m',    label: 'Top categorías 3 meses',   icon: '📈' },
  { id: 'weekdayChart',   label: '¿Cuándo gastás más?',      icon: '📆' },
  { id: 'monthlyAvg',     label: 'Promedio mensual',         icon: '📉' },
  { id: 'ytdSummary',     label: 'Resumen anual (YTD)',      icon: '🗃️' },
  { id: 'yearAgoComp',    label: 'vs Año anterior',          icon: '⏮️' },
  { id: 'goalsWidget',    label: 'Metas de ahorro',          icon: '🎯' },
  { id: 'cuotasWidget',   label: 'Cuotas activas',           icon: '💳' },
  { id: 'debtsWidget',    label: 'Deudas',                   icon: '🤝' },
  { id: 'trends6m',       label: 'Tendencias 6 meses',       icon: '〰️' },
  { id: 'vsLastMonth',    label: 'Este mes vs anterior',     icon: '↔️' },
  { id: 'ritmoGastos',    label: 'Velocímetro de gastos',    icon: '⚡' },
  { id: 'projection2',    label: 'Proyección fin de mes',    icon: '🔮' },
  { id: 'patrimonio',     label: 'Patrimonio neto',          icon: '🏦' },
  { id: 'vencimientos',          label: 'Vencimientos próximos',    icon: '🔔' },
  // Secciones adicionales sin guard — corregidas
  { id: 'incomeSourceBreakdown', label: 'Fuentes de ingreso (gráf)', icon: '💼' },
  { id: 'yearHeatmap',           label: 'Mapa calor anual',          icon: '🗓️' },
  { id: 'dailyBars',             label: 'Gastos por día (barras)',   icon: '📊' },
  { id: 'sixMonthBars',          label: 'Ingresos vs Gastos 6m',    icon: '📈' },
  { id: 'savingsStreak',         label: 'Racha de ahorro',           icon: '🔥' },
  { id: 'notaDelMes',            label: 'Nota del mes',              icon: '📝' },
  { id: 'patrimonioAcumulado',   label: 'Patrimonio acumulado',      icon: '🏦' },
];

// Categorías clasificadas como "necesidades" para regla 50/30/20 (configurable)
// DEFAULT_NEEDS_CATS + loadNeedsCats viven en src/lib/constants.js.
// WalletLogo vive en src/components/WalletLogo.jsx.
// formatNumber, formatNumberWithDecimals, parseFormattedNumber viven en src/lib/format.js.
// ToastProvider, useToast viven en src/contexts/ToastContext.jsx.
// SkeletonCard, LoadingSkeleton viven en src/components/Skeletons.jsx.

// ─────────────────────────────────────────────
// PRECISION SELECTOR (Ahorro/Inversión)
// ─────────────────────────────────────────────
const COLOR_MAP = {
  emerald: { bg: "bg-emerald-500", bgSoft: "bg-emerald-500/10", text: "text-emerald-500" },
  violet:  { bg: "bg-violet-500",  bgSoft: "bg-violet-500/10",  text: "text-violet-500"  },
  indigo:  { bg: "bg-violet-500",  bgSoft: "bg-violet-500/10",  text: "text-violet-500"  }
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
          <button onClick={onEdit} className="p-1 text-zinc-700 active:text-violet-400 transition-colors"><Edit3 className="w-3.5 h-3.5"/></button>
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
  const [amount,    setAmount]    = useState(() => {
    if (!bill) return '';
    const n = Number(bill.amount);
    const int = Math.floor(n);
    const dec = Math.round((n % 1) * 100);
    const fmt = String(int).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
    return dec > 0 ? fmt + ',' + String(dec).padStart(2, '0') : fmt;
  });
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
      amount: parseFloat((amount || '0').replace(/\./g,'').replace(',','.')) || 0,
      due_date: dueDate,
      category,
      status: bill?.status || 'pending',
      recurrence_type: recur || null,
      reminder_days: Number(remDays),
    });
    setSaving(false);
  };

  return (
    <div className="fixed inset-0 z-[300] bg-black/80 backdrop-blur-2xl flex items-end justify-center">
      <div className="anim-slide-up w-full max-w-md bg-zinc-950 rounded-t-[2.5rem] border-t border-white/10 p-7 space-y-5 pb-[calc(2rem+env(safe-area-inset-bottom))]">
        <div className="flex justify-between items-center">
          <h3 className="text-lg font-black uppercase tracking-tight">{bill ? 'Editar' : 'Nuevo'} vencimiento</h3>
          <button onClick={onClose} className="p-2 bg-zinc-900 rounded-full"><X className="w-5 h-5"/></button>
        </div>

        <input value={title} onChange={e=>setTitle(e.target.value)} placeholder="Descripción (ej: Alquiler, Internet…)"
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-violet-500/60"/>

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Monto</p>
            <div className="relative">
              <span className="absolute left-4 top-1/2 -translate-y-1/2 font-bold text-zinc-400 text-sm pointer-events-none select-none">$</span>
              <input value={amount}
                onChange={e => {
                  const raw = e.target.value.replace(/[^\d,]/g, '');
                  const ci = raw.indexOf(',');
                  let intStr, decStr;
                  if (ci === -1) { intStr = raw; decStr = undefined; }
                  else { intStr = raw.slice(0, ci); decStr = raw.slice(ci+1).replace(/\D/g,'').slice(0,2); }
                  const fmt = intStr ? intStr.replace(/\B(?=(\d{3})+(?!\d))/g, '.') : '';
                  setAmount(decStr !== undefined ? fmt + ',' + decStr : fmt);
                }}
                placeholder="0" inputMode="decimal"
                className="w-full bg-zinc-900 rounded-2xl p-4 pl-8 border border-white/10 text-sm text-white focus:outline-none focus:border-violet-500/60"/>
            </div>
          </div>
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Vence el</p>
            <input type="date" value={dueDate} onChange={e=>setDueDate(e.target.value)}
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-violet-500/60"/>
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
                  ${recur===opt.v?'bg-violet-600 text-white':'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
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
          className="w-full py-5 bg-violet-600 rounded-2xl font-bold text-sm uppercase tracking-wider active:scale-95 transition-all disabled:opacity-40">
          {saving ? 'Guardando…' : bill ? 'Guardar cambios' : 'Agregar vencimiento'}
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// EDIT TRANSACTION MODAL
// ─────────────────────────────────────────────
function EditTransactionModal({ tx, categories, accounts: accs, onSave, onClose, onDuplicate, onFixedTxsChange }) {
  const txDateStr = tx.date?.slice(0,10) || new Date().toISOString().slice(0,10);
  const [amount,      setAmount]      = useState(formatNumber(tx.amount));
  const [categ,       setCateg]       = useState(tx.category);
  const [subcateg,    setSubcateg]    = useState(tx.subcategory || '');
  const [acctVal,     setAcctVal]     = useState(tx.account || '');
  const [note,        setNote]        = useState(tx.note || "");
  const [date,        setDate]        = useState(txDateStr);
  const [saving,      setSaving]      = useState(false);
  const accountList = accs || ['Ariel', 'Yami'];
  const [isFixed, setIsFixed] = useState(() => {
    try {
      const tpls = JSON.parse(localStorage.getItem(FIXED_TX_KEY) || '[]');
      return tpls.some(t => t.category === tx.category && t.type === tx.type);
    } catch { return false; }
  });
  const [mesAsignado, setMesAsignado] = useState(() => {
    // If tx was already saved with a period override, restore it; else use real date month
    if (tx.period_year != null) return { year: tx.period_year, month: tx.period_month };
    const d = new Date(txDateStr + 'T12:00:00');
    return { year: d.getFullYear(), month: d.getMonth() };
  });
  const toast = useToast();

  const handleSave = async () => {
    setSaving(true);
    const txDateObj = new Date(date + 'T12:00:00');
    // Guardar la fecha real; si el período asignado difiere, almacenar en period_year/period_month
    const realDate = new Date(date + 'T12:00:00').toISOString();
    const periodDiffers = mesAsignado.year !== txDateObj.getFullYear() || mesAsignado.month !== txDateObj.getMonth();
    const numericAmount = parseFormattedNumber(amount);
    const { error } = await supabase.from('transactions').update({
      amount: numericAmount,
      category: categ,
      note: note.trim(),
      date: realDate,
      period_year:  periodDiffers ? mesAsignado.year  : null,
      period_month: periodDiffers ? mesAsignado.month : null,
      account:      acctVal || null,
      subcategory:  subcateg || null,
    }).eq('id', tx.id);
    setSaving(false);
    if (error) { toast(error.message, 'error'); return; }
    // Manejar template de gasto fijo
    const templates = JSON.parse(localStorage.getItem(FIXED_TX_KEY) || '[]');
    const existIdx = templates.findIndex(t => t.category === categ && t.type === tx.type);
    if (isFixed) {
      const tpl = {
        id: existIdx >= 0 ? templates[existIdx].id : Date.now(),
        category: categ, type: tx.type,
        amount: numericAmount,
        note: note.trim(),
        dayOfMonth: new Date(date + 'T12:00:00').getDate(),
      };
      if (existIdx >= 0) templates[existIdx] = tpl; else templates.push(tpl);
    } else if (existIdx >= 0) {
      templates.splice(existIdx, 1);
    }
    localStorage.setItem(FIXED_TX_KEY, JSON.stringify(templates));
    if (onFixedTxsChange) onFixedTxsChange(templates);
    toast('Movimiento actualizado', 'success');
    onSave();
    onClose();
  };

  const allCats = [...(categories.GASTO || []), ...(categories.INGRESO || [])];
  const mesDisferente = mesAsignado.year !== new Date(date+'T12:00:00').getFullYear() ||
    mesAsignado.month !== new Date(date+'T12:00:00').getMonth();

  return (
    <div className="fixed inset-0 z-[300] bg-black/80 backdrop-blur-2xl flex items-end justify-center">
      <div className="anim-slide-up w-full max-w-md bg-zinc-950 rounded-t-[2.5rem] border-t border-white/10 px-6 pt-6 pb-[calc(2rem+env(safe-area-inset-bottom))] space-y-4 overflow-y-auto max-h-[92vh]">
        <div className="flex justify-between items-center">
          <h3 className="text-lg font-black uppercase tracking-tight">Editar movimiento</h3>
          <button onClick={onClose} className="p-2 bg-zinc-900 rounded-full"><X className="w-5 h-5" /></button>
        </div>
        {/* Monto */}
        <input type="text" value={amount}
          onChange={e=>{const raw=e.target.value.replace(/\D/g,'');setAmount(raw?raw.replace(/\B(?=(\d{3})+(?!\d))/g,'.'):'');}}
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-2xl font-black text-center focus:outline-none focus:border-violet-500/60"
          inputMode="numeric" placeholder="$ 0" />
        {/* Multi-currency info */}
        {tx.currency_original && tx.currency_original !== 'ARS' && (
          <div className="flex items-center gap-2 bg-violet-500/8 rounded-xl px-3 py-2.5 border border-violet-500/20">
            <span className="text-sm">💱</span>
            <p className="text-xs text-violet-300 leading-tight">
              Original: <strong>{CURRENCIES[tx.currency_original]?.symbol || tx.currency_original} {formatNumber(tx.amount_original)}</strong>
              {' · '}Tipo: <strong>1 {tx.currency_original} = ${formatNumber(tx.fx_rate_to_base)} ARS</strong>
              {tx.fx_status === 'ESTIMATED' && <span className="text-amber-400"> · cotización estimada</span>}
            </p>
          </div>
        )}
        {/* Categoría */}
        <select value={categ} onChange={e => setCateg(e.target.value)}
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 font-bold text-sm text-white appearance-none focus:outline-none">
          {allCats.map(c => <option key={c} value={c}>{c}</option>)}
        </select>
        {/* Fecha */}
        <input type="date" value={date} onChange={e => setDate(e.target.value)}
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 font-bold text-sm text-white focus:outline-none focus:border-violet-500/60" />
        {/* Selector de mes */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <p className="text-[11px] font-semibold text-zinc-600 uppercase tracking-wide">Registrar en el período de</p>
            {mesDisferente && <span className="text-[10px] text-amber-400 font-bold">≠ fecha real</span>}
          </div>
          <div className="flex gap-2">
            {[-1, 0, 1].map(offset => {
              const now = new Date();
              const rawM = now.getMonth() + offset;
              const y = now.getFullYear() + (rawM < 0 ? -1 : rawM > 11 ? 1 : 0);
              const m = ((rawM % 12) + 12) % 12;
              const isSel = mesAsignado.year === y && mesAsignado.month === m;
              return (
                <button key={offset}
                  onClick={() => setMesAsignado({ year: y, month: m })}
                  className={`flex-1 py-2.5 rounded-xl text-xs font-bold transition-all active:scale-95 text-center border
                    ${isSel ? 'bg-violet-600 text-white border-violet-500/40 shadow-md' : 'bg-zinc-900 text-zinc-500 border-white/8'}`}>
                  <span className="block text-sm">{MONTHS[m].slice(0,3)}</span>
                  <span className={`block text-[9px] mt-0.5 ${isSel?'text-violet-200':'text-zinc-700'}`}>
                    {offset < 0 ? 'anterior' : offset > 0 ? 'próximo' : 'actual'}
                  </span>
                </button>
              );
            })}
          </div>
          {mesDisferente && (
            <div className="flex items-center gap-2 bg-amber-500/8 rounded-xl px-3 py-2 border border-amber-500/20">
              <span className="text-sm">⚠️</span>
              <p className="text-[11px] text-amber-300 leading-tight">
                La fecha es <strong>{new Date(date+'T12:00:00').toLocaleDateString('es-AR',{day:'numeric',month:'short'})}</strong> pero
                se registrará en <strong>{MONTHS[mesAsignado.month]} {mesAsignado.year}</strong>
              </p>
            </div>
          )}
        </div>
        {/* Cuenta (quién pagó) */}
        {accountList.length > 0 && (
          <div className="space-y-2">
            <p className="text-[11px] font-semibold text-zinc-600 uppercase tracking-wider">Cuenta</p>
            <div className="flex flex-wrap gap-2">
              <button onClick={() => setAcctVal('')}
                className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition-all
                  ${!acctVal ? 'bg-violet-600 text-white' : 'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                Sin especificar
              </button>
              {accountList.map(a => (
                <button key={a} onClick={() => setAcctVal(a)}
                  className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition-all
                    ${acctVal === a ? 'bg-violet-600 text-white' : 'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                  {a}
                </button>
              ))}
            </div>
          </div>
        )}
        {/* Subcategoría */}
        {(() => {
          const catData = JSON.parse(localStorage.getItem('metacasa_categories') || 'null');
          const subcats = catData?.subcategories?.[categ] || [];
          if (subcats.length === 0) return null;
          return (
            <div className="space-y-2">
              <p className="text-[11px] font-semibold text-zinc-600 uppercase tracking-wider">Subcategoría</p>
              <div className="flex flex-wrap gap-2">
                <button onClick={() => setSubcateg('')}
                  className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition-all
                    ${!subcateg ? 'bg-zinc-700 text-white' : 'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                  General
                </button>
                {subcats.map(sc => (
                  <button key={sc} onClick={() => setSubcateg(sc)}
                    className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition-all
                      ${subcateg === sc ? 'bg-teal-600 text-white' : 'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                    {sc}
                  </button>
                ))}
              </div>
            </div>
          );
        })()}
        {/* Nota */}
        <textarea value={note} onChange={e => setNote(e.target.value)} placeholder="Detalle..."
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-zinc-400 resize-none min-h-[72px] focus:outline-none focus:border-violet-500/60" />
        {/* Toggle fijo */}
        <button
          onClick={() => setIsFixed(v => !v)}
          className={`w-full flex items-center gap-3 px-4 py-3.5 rounded-2xl border transition-all active:scale-[0.98]
            ${isFixed ? 'bg-amber-500/10 border-amber-500/30' : 'bg-zinc-900/40 border-white/8'}`}>
          <span className="text-lg leading-none">📌</span>
          <div className="flex-1 text-left">
            <p className={`text-sm font-bold ${isFixed ? 'text-amber-300' : 'text-zinc-400'}`}>
              {tx.type === 'GASTO' ? 'Gasto fijo mensual' : 'Ingreso fijo mensual'}
            </p>
            <p className="text-[10px] text-zinc-600 mt-0.5">
              {isFixed ? 'Se registrará automáticamente cada mes' : 'Activar para replicar cada mes'}
            </p>
          </div>
          <div className={`w-10 h-5 rounded-full flex items-center px-0.5 transition-all flex-shrink-0
            ${isFixed ? 'bg-amber-500 justify-end' : 'bg-zinc-700 justify-start'}`}>
            <div className="w-4 h-4 rounded-full bg-white shadow-sm"/>
          </div>
        </button>
        {/* Botones */}
        <div className="grid grid-cols-2 gap-3">
          <button onClick={() => onDuplicate && onDuplicate(tx)}
            className="py-4 bg-zinc-900 border border-white/10 rounded-2xl font-bold text-sm text-zinc-400 active:scale-95 transition-all flex items-center justify-center gap-2">
            <Copy className="w-4 h-4"/>Clonar
          </button>
          <button onClick={handleSave} disabled={saving}
            className="py-4 bg-violet-600 rounded-2xl font-black text-sm uppercase tracking-widest active:scale-95 transition-all disabled:opacity-50">
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
        className="w-full bg-zinc-900/40 border border-white/8 rounded-xl px-3 py-2 text-xs text-zinc-400 resize-none focus:outline-none focus:border-violet-500/30 transition-colors placeholder:text-zinc-700"/>
      <div className="flex gap-2">
        <button onClick={() => onSave({ targetIncome: parseInt(inc)||0, targetExpense: parseInt(exp)||0, note: note.trim() })}
          className="flex-1 py-2.5 bg-violet-600 rounded-xl text-xs font-bold active:scale-95 transition-transform">
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
          <span className={`font-black ${done ? 'text-emerald-400' : 'text-violet-400'}`}>{pct}%</span>
        </div>
        <div className="h-3 bg-black/60 rounded-full overflow-hidden">
          <div className={`h-full rounded-full transition-all duration-700 ${done ? 'bg-emerald-500' : 'bg-violet-600'}`}
            style={{width:`${pct}%`}}/>
        </div>
        <p className="text-xs text-zinc-700">
          {done ? '🎉 ¡Meta alcanzada!' : `Falta $${formatNumber(goal.target - goal.current)}`}
        </p>
        {estimatorMonths && (
          <div className="flex items-center gap-1.5 bg-violet-600/10 border border-violet-500/20 rounded-xl px-3 py-2 mt-1">
            <TrendingUp className="w-3 h-3 text-violet-400 flex-shrink-0"/>
            <p className="text-[10px] font-bold text-violet-300">
              A este ritmo llegás en{' '}
              <span className="text-white">{estimatorMonths === 1 ? '1 mes' : `${estimatorMonths} meses`}</span>
              {' '}·{' '}<span className="text-violet-400">{estimatorDate}</span>
            </p>
          </div>
        )}
      </div>

      <div className="flex gap-2">
        {!done && (
          <button onClick={()=>onContribute(goal)}
            className="flex-1 py-3 bg-violet-700/12 border border-violet-500/25 rounded-xl text-xs font-bold text-violet-400 active:scale-95 transition-all flex items-center justify-center gap-1.5">
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
    <div className="fixed inset-0 z-[400] bg-black/80 backdrop-blur-2xl flex items-end justify-center">
      <div className="anim-slide-up w-full max-w-md bg-zinc-950 rounded-t-[2.5rem] border-t border-white/10 p-7 space-y-5 pb-[calc(2rem+env(safe-area-inset-bottom))]">
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
            className="flex-1 bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-violet-500/60"/>
        </div>
        {showPick && (
          <div className="bg-zinc-900/90 rounded-2xl p-3 border border-white/10">
            <div className="grid grid-cols-10 gap-1">
              {GOAL_EMOJIS.map(e=>(
                <button key={e} onClick={()=>{ setEmoji(e); setShowPick(false); }}
                  className={`w-8 h-8 flex items-center justify-center text-xl rounded-lg active:bg-white/10 transition-colors ${emoji===e?'bg-violet-600':''}`}>
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
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm font-bold text-white focus:outline-none focus:border-violet-500/60"/>
          </div>
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Ya tengo ($)</p>
            <input value={current} onChange={e=>setCurrent(e.target.value.replace(/\D/g,''))}
              placeholder="0" inputMode="numeric"
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm font-bold text-white focus:outline-none focus:border-violet-500/60"/>
          </div>
        </div>

        <div className="space-y-1">
          <p className="text-xs text-zinc-600 ml-1">Fecha límite (opcional)</p>
          <input type="date" value={deadline} onChange={e=>setDeadline(e.target.value)}
            className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-violet-500/60"/>
        </div>

        <button onClick={handleSave} disabled={!name.trim()||!target}
          className="w-full py-5 bg-violet-600 rounded-2xl font-bold text-sm uppercase tracking-wider active:scale-95 transition-all disabled:opacity-40">
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
    <div className="fixed inset-0 z-[400] bg-black/80 backdrop-blur-2xl flex items-end justify-center">
      <div className="anim-slide-up w-full max-w-md bg-zinc-950 rounded-t-[2.5rem] border-t border-white/10 p-7 space-y-5 pb-[calc(2rem+env(safe-area-inset-bottom))]">
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
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-2xl font-black text-center focus:outline-none focus:border-violet-500/60"/>
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
function CuotaCard({ cuota, onEdit, onDelete, onPay, baseCurrency }) {
  const remaining = cuota.totalCuotas - cuota.paidCuotas;
  const pct = Math.round((cuota.paidCuotas / cuota.totalCuotas) * 100);
  const done = remaining <= 0;
  const totalLeft = remaining * cuota.monthlyAmount;
  const sym = CURRENCIES[cuota.currency || baseCurrency]?.symbol || '$';

  return (
    <div className={`rounded-2xl border p-4 space-y-3 transition-all ${done ? 'bg-zinc-900/30 border-white/5 opacity-60' : 'bg-zinc-900/60 border-white/8'}`}>
      <div className="flex justify-between items-start">
        <div className="flex items-center gap-3 min-w-0">
          <span className="text-2xl flex-shrink-0">{cuota.emoji}</span>
          <div className="min-w-0">
            <p className="text-sm font-bold text-white truncate">{cuota.name}</p>
            <p className="text-xs text-zinc-500 mt-0.5">
              {cuota.paidCuotas}/{cuota.totalCuotas} cuotas · {sym}{formatNumberWithDecimals(cuota.monthlyAmount)}/mes
            </p>
          </div>
        </div>
        <div className="text-right flex-shrink-0 ml-2">
          <p className="text-xs text-zinc-600">Resta</p>
          <p className={`text-sm font-black ${done ? 'text-emerald-400' : 'text-white'}`}>
            {done ? '¡Listo!' : `${sym}${formatNumberWithDecimals(totalLeft)}`}
          </p>
        </div>
      </div>

      <div className="space-y-1">
        <div className="h-2 bg-black/60 rounded-full overflow-hidden">
          <div className={`h-full rounded-full transition-all duration-700 ${done ? 'bg-emerald-500' : pct >= 80 ? 'bg-amber-500' : 'bg-violet-600'}`}
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
            className="flex-1 py-2.5 bg-violet-700/12 border border-violet-500/25 rounded-xl text-xs font-bold text-violet-400 active:scale-95 transition-all flex items-center justify-center gap-1.5">
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
function CuotaForm({ cuota, onSave, onClose, baseCurrency, activeCurrencies: actCurrs, categories: cats, accounts: accts, getEmoji: gEmoji }) {
  const [name,        setName]        = useState(cuota?.name || '');
  const [emoji,       setEmoji]       = useState(cuota?.emoji || '💳');
  const [monthly,     setMonthly]     = useState(() => {
    if (!cuota) return '';
    const v = cuota.monthlyAmount;
    if (!v) return '';
    const dec = v % 1;
    if (dec) { const intP = Math.floor(v).toString().replace(/\B(?=(\d{3})+(?!\d))/g,'.'); return intP + ',' + v.toFixed(2).split('.')[1]; }
    return Math.floor(v).toString().replace(/\B(?=(\d{3})+(?!\d))/g,'.');
  });
  const [cuotaCurrency, setCuotaCurrency] = useState(cuota?.currency || baseCurrency || 'ARS');
  const [totalCuotas, setTotalCuotas] = useState(cuota ? String(cuota.totalCuotas) : '12');
  const [paidCuotas,  setPaidCuotas]  = useState(cuota ? String(cuota.paidCuotas) : '0');
  const [startDate,   setStartDate]   = useState(cuota?.startDate || new Date().toISOString().slice(0,10));
  const [showPick,    setShowPick]    = useState(false);
  const [cuotaCategory,    setCuotaCategory]    = useState(cuota?.category || '');
  const [cuotaSubcategory, setCuotaSubcategory] = useState(cuota?.subcategory || '');
  const [cuotaAccount,     setCuotaAccount]     = useState(cuota?.account || '');

  const parseMonthly = (str) => {
    if (!str) return 0;
    const clean = str.replace(/\./g,'').replace(',','.');
    return parseFloat(clean) || 0;
  };
  const monthlyNum = parseMonthly(monthly);
  const total = monthlyNum * (parseInt(totalCuotas||0));
  const sym = CURRENCIES[cuotaCurrency]?.symbol || '$';

  // Subcategorías dinámicas
  const subcats = (() => {
    if (!cuotaCategory) return [];
    try {
      const catData = JSON.parse(localStorage.getItem('metacasa_categories') || 'null');
      return catData?.subcategories?.[cuotaCategory] || [];
    } catch { return []; }
  })();

  const handleSave = () => {
    if (!name.trim() || !monthly || !totalCuotas) return;
    onSave({
      id: cuota?.id || Date.now(),
      name: name.trim(), emoji,
      monthlyAmount: monthlyNum,
      totalCuotas:   parseInt(totalCuotas) || 1,
      paidCuotas:    Math.min(parseInt(paidCuotas)||0, parseInt(totalCuotas)||1),
      startDate,
      currency: cuotaCurrency,
      category: cuotaCategory,
      subcategory: cuotaSubcategory,
      account: cuotaAccount,
    });
  };

  const CUOTA_EMOJIS = ['💳','📱','💻','🛋️','🚗','📺','🎸','🧳','👕','🏋️','🎮','🛒','✈️','🏠','💊','🎓','🐕','⌚','📷','🍳'];

  return (
    <div className="fixed inset-0 z-[400] bg-black/80 backdrop-blur-2xl flex items-end justify-center">
      <div className="anim-slide-up w-full max-w-md bg-zinc-950 rounded-t-[2.5rem] border-t border-white/10 p-7 space-y-5 pb-[calc(2rem+env(safe-area-inset-bottom))] max-h-[92dvh] overflow-y-auto no-scrollbar">
        <div className="flex justify-between items-center">
          <h3 className="text-lg font-black uppercase tracking-tight">{cuota ? 'Editar' : 'Nueva'} cuota</h3>
          <button onClick={onClose} className="p-2 bg-zinc-900 rounded-full"><X className="w-5 h-5"/></button>
        </div>

        <div className="flex items-center gap-3">
          <button onClick={()=>setShowPick(v=>!v)}
            className="w-14 h-14 rounded-2xl bg-zinc-900 border border-white/10 flex items-center justify-center text-3xl active:scale-90 transition-transform">
            {emoji}
          </button>
          <input value={name} onChange={e=>setName(e.target.value)} placeholder="Nombre (ej: TV, Celular...)"
            className="flex-1 bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-violet-500/60"/>
        </div>
        {showPick && (
          <div className="bg-zinc-900/90 rounded-2xl p-3 border border-white/10">
            <div className="grid grid-cols-10 gap-1">
              {CUOTA_EMOJIS.map(e=>(
                <button key={e} onClick={()=>{ setEmoji(e); setShowPick(false); }}
                  className={`w-8 h-8 flex items-center justify-center text-xl rounded-lg active:bg-white/10 ${emoji===e?'bg-violet-600':''}`}>
                  {e}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Currency selector */}
        {actCurrs && actCurrs.length > 1 && (
          <div className="flex gap-1.5 flex-wrap">
            {actCurrs.map(code => {
              const cfg = CURRENCIES[code];
              if (!cfg) return null;
              return (
                <button key={code} onClick={() => setCuotaCurrency(code)}
                  className={`flex items-center gap-1 px-3 py-1.5 rounded-xl text-xs font-bold transition-all active:scale-95 border
                    ${cuotaCurrency === code
                      ? 'bg-violet-600 text-white border-violet-500/40'
                      : 'bg-zinc-900/80 text-zinc-500 border-white/8'}`}>
                  <span>{cfg.flag}</span>
                  <span>{code}</span>
                </button>
              );
            })}
          </div>
        )}

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Valor por cuota ({sym})</p>
            <div className="relative">
              <span className="absolute left-4 top-1/2 -translate-y-1/2 text-sm text-zinc-500 font-bold">{sym}</span>
              <input value={monthly}
                onChange={e => {
                  const raw = e.target.value.replace(/[^\d,]/g, '');
                  const ci = raw.indexOf(',');
                  let intStr, decStr;
                  if (ci === -1) { intStr = raw; decStr = undefined; }
                  else { intStr = raw.slice(0, ci); decStr = raw.slice(ci+1).replace(/\D/g,'').slice(0,2); }
                  const fmt = intStr ? intStr.replace(/\B(?=(\d{3})+(?!\d))/g, '.') : '';
                  setMonthly(decStr !== undefined ? fmt + ',' + decStr : fmt);
                }}
                placeholder="0" inputMode="decimal"
                className="w-full bg-zinc-900 rounded-2xl p-4 pl-10 border border-white/10 text-sm font-bold text-white focus:outline-none focus:border-violet-500/60"/>
            </div>
          </div>
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Total cuotas</p>
            <div className="flex gap-2">
              {['3','6','12','18','24'].map(n=>(
                <button key={n} onClick={()=>setTotalCuotas(n)}
                  className={`flex-1 py-2 rounded-xl text-xs font-black transition-all ${totalCuotas===n?'bg-violet-600 text-white':'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
                  {n}
                </button>
              ))}
            </div>
          </div>
        </div>

        {total > 0 && (
          <div className="bg-zinc-900/50 rounded-xl p-3 flex justify-between items-center text-sm">
            <span className="text-zinc-500">Total financiado</span>
            <span className="font-black text-white">{sym}{formatNumberWithDecimals(total)}</span>
          </div>
        )}

        {/* Categoria */}
        {cats?.GASTO && cats.GASTO.length > 0 && (
          <div className="space-y-1.5">
            <p className="text-xs text-zinc-600 ml-1 font-semibold">Categoria</p>
            <div className="flex flex-wrap gap-2">
              {cats.GASTO.map(c => (
                <button key={c} onClick={() => { setCuotaCategory(c); setCuotaSubcategory(''); }}
                  className={`flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold transition-all active:scale-90
                    ${cuotaCategory === c
                      ? 'bg-rose-600 text-white shadow-lg'
                      : 'bg-zinc-900/80 text-zinc-400 border border-white/8'}`}>
                  {gEmoji && <span className="text-sm leading-none">{gEmoji(c)}</span>}
                  <span>{c}</span>
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Subcategoria */}
        {cuotaCategory && subcats.length > 0 && (
          <div className="space-y-1.5">
            <p className="text-xs text-zinc-600 ml-1 font-semibold">Subcategoria</p>
            <div className="flex flex-wrap gap-2">
              <button onClick={() => setCuotaSubcategory('')}
                className={`px-3 py-2 rounded-xl text-xs font-semibold transition-all active:scale-95
                  ${!cuotaSubcategory ? 'bg-zinc-700 text-white' : 'bg-zinc-900/80 text-zinc-400 border border-white/8'}`}>
                General
              </button>
              {subcats.map(sc => (
                <button key={sc} onClick={() => setCuotaSubcategory(sc)}
                  className={`px-3 py-2 rounded-xl text-xs font-semibold transition-all active:scale-95
                    ${cuotaSubcategory === sc ? 'bg-teal-600 text-white' : 'bg-zinc-900/80 text-zinc-400 border border-white/8'}`}>
                  {sc}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Cuenta */}
        {accts && accts.length > 0 && (
          <div className="space-y-1.5">
            <p className="text-xs text-zinc-600 ml-1 font-semibold">Cuenta</p>
            <div className="flex flex-wrap gap-2">
              <button onClick={() => setCuotaAccount('')}
                className={`px-3 py-2 rounded-xl text-xs font-semibold transition-all active:scale-95
                  ${!cuotaAccount ? 'bg-violet-600 text-white shadow-md' : 'bg-zinc-900/80 text-zinc-400 border border-white/8'}`}>
                Sin especificar
              </button>
              {accts.map(acc => (
                <button key={acc} onClick={() => setCuotaAccount(acc)}
                  className={`px-3 py-2 rounded-xl text-xs font-semibold transition-all active:scale-95
                    ${cuotaAccount === acc ? 'bg-violet-600 text-white shadow-md' : 'bg-zinc-900/80 text-zinc-400 border border-white/8'}`}>
                  {acc}
                </button>
              ))}
            </div>
          </div>
        )}

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Ya pague</p>
            <input value={paidCuotas} onChange={e=>setPaidCuotas(e.target.value.replace(/\D/g,''))}
              placeholder="0" inputMode="numeric"
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm font-bold text-white focus:outline-none focus:border-violet-500/60"/>
          </div>
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Inicio</p>
            <input type="date" value={startDate} onChange={e=>setStartDate(e.target.value)}
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-violet-500/60"/>
          </div>
        </div>

        <button onClick={handleSave} disabled={!name.trim()||!monthly||!totalCuotas}
          className="w-full py-5 bg-violet-600 rounded-2xl font-bold text-sm uppercase tracking-wider active:scale-95 transition-all disabled:opacity-40">
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
            <button onClick={()=>onEdit(debt)} className="p-1 text-zinc-700 active:text-violet-400 transition-colors">
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
    <div className="fixed inset-0 z-[400] bg-black/80 backdrop-blur-2xl flex items-end justify-center">
      <div className="anim-slide-up w-full max-w-md bg-zinc-950 rounded-t-[2.5rem] border-t border-white/10 p-7 space-y-5 pb-[calc(2rem+env(safe-area-inset-bottom))]">
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
            className="flex-1 bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-violet-500/60"/>
        </div>

        {/* Monto */}
        <input value={amount} onChange={e=>setAmount(e.target.value.replace(/\D/g,''))}
          placeholder="$ Monto" inputMode="numeric"
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-2xl font-black text-center focus:outline-none focus:border-violet-500/60"/>

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Fecha</p>
            <input type="date" value={date} onChange={e=>setDate(e.target.value)}
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-violet-500/60"/>
          </div>
          <div className="space-y-1">
            <p className="text-xs text-zinc-600 ml-1">Nota (opcional)</p>
            <input value={note} onChange={e=>setNote(e.target.value)} placeholder="Por qué…"
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-zinc-400 focus:outline-none focus:border-violet-500/60"/>
          </div>
        </div>

        <button onClick={handleSave} disabled={!name.trim()||!amount}
          className="w-full py-5 bg-violet-600 rounded-2xl font-bold text-sm uppercase tracking-wider active:scale-95 transition-all disabled:opacity-40">
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
        <Calendar className="w-4 h-4 text-violet-400"/>
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
              ${isToday(day) ? 'ring-1 ring-violet-400/70' : ''}
              ${day && dayExpenses[day] ? 'active:scale-90' : ''}`}>
            {day ? <span className={isToday(day) ? 'text-violet-300 font-black' : ''}>{day}</span> : null}
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
        const p = txBudgetPeriod(t);
        return p.month === m && p.year === year;
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
          <div className={`border rounded-2xl p-4 text-center ${totals.balance>=0?'bg-violet-500/10 border-violet-500/20':'bg-zinc-900/60 border-white/5'}`}>
            <p className="text-[10px] text-zinc-500 font-semibold mb-1">BALANCE</p>
            <p className={`text-base font-black ${totals.balance>=0?'text-violet-300':'text-rose-400'}`}>${formatNumber(totals.balance)}</p>
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
    const p = txBudgetPeriod(t);
    return p.month===month && p.year===year;
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
          <button onClick={handleShare} className="p-2.5 bg-violet-600 rounded-xl active:scale-90 transition-transform" title="Compartir">
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
            { label:'Inversión', value:stats.investmentAmount, color:'text-violet-400',  bg:'bg-violet-500/10'  },
          ].map(item=>(
            <div key={item.label} className={`${item.bg} rounded-2xl p-4 border border-white/5`}>
              <p className="text-xs text-zinc-500 font-semibold">{item.label}</p>
              <p className={`text-xl font-black mt-0.5 ${item.color}`}>${formatNumber(item.value)}</p>
            </div>
          ))}
        </div>

        {/* Saldo disponible */}
        <div className={`rounded-2xl p-5 border ${stats.available>=0?'bg-violet-600/10 border-violet-500/20':'bg-rose-600/10 border-rose-500/20'}`}>
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
            <div className="h-full bg-violet-600 rounded-full" style={{width:`${monthProgress}%`}}/>
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
      const p = txBudgetPeriod(t);
      return p.month===month && p.year===year;
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
  // ── Mes navegable (independiente del mes principal) ──────────────────────
  const [viewDate, setViewDate] = React.useState({ year: currentDate.getFullYear(), month: currentDate.getMonth() });
  const changeViewMonth = (offset) => {
    setViewDate(prev => {
      const d = new Date(prev.year, prev.month + offset, 1);
      return { year: d.getFullYear(), month: d.getMonth() };
    });
  };

  const sixMonths = React.useMemo(() => Array.from({ length: 6 }, (_, i) => {
    const d = new Date(viewDate.year, viewDate.month - (5 - i), 1);
    const y = d.getFullYear(), m = d.getMonth();
    const amount = transactions
      .filter(t => { const p = txBudgetPeriod(t); return t.type==='GASTO' && t.category===cat && p.year===y && p.month===m; })
      .reduce((a, c) => a + Number(c.amount), 0);
    return { label: MONTHS[m].slice(0,3), amount, isCurrent: y===viewDate.year && m===viewDate.month };
  }), [transactions, cat, viewDate]);

  const maxVal = Math.max(...sixMonths.map(m => m.amount), 1);
  const prevMonths = sixMonths.slice(0, 5).filter(m => m.amount > 0);
  const avg = prevMonths.length > 0 ? Math.round(prevMonths.reduce((a,c)=>a+c.amount,0) / prevMonths.length) : 0;

  const viewMonthTxs = React.useMemo(() => transactions
    .filter(t => { const p = txBudgetPeriod(t); return t.type==='GASTO' && t.category===cat && p.year===viewDate.year && p.month===viewDate.month; })
    .sort((a,b) => new Date(b.date) - new Date(a.date)), [transactions, cat, viewDate]);

  const viewTotal = viewMonthTxs.reduce((a,c)=>a+Number(c.amount),0);
  const isCurrentMonth = viewDate.year === currentDate.getFullYear() && viewDate.month === currentDate.getMonth();

  return (
    <div className="fixed inset-0 z-[120] bg-black flex flex-col">
      <div className="px-6 pt-[calc(env(safe-area-inset-top)+16px)] pb-4 flex justify-between items-center border-b border-white/8">
        <div className="flex items-center gap-3">
          <span className="text-3xl leading-none">{getEmoji(cat)}</span>
          <div>
            <h3 className="text-xl font-black uppercase tracking-tight">{cat}</h3>
            <p className="text-xs text-zinc-500 mt-0.5">{MONTHS[viewDate.month]} {viewDate.year}</p>
          </div>
        </div>
        <button onClick={onClose} className="p-2.5 bg-zinc-900 rounded-xl"><X className="w-5 h-5"/></button>
      </div>

      {/* Navegación de mes */}
      <div className="px-6 py-3 flex items-center justify-between border-b border-white/5">
        <button onClick={() => changeViewMonth(-1)}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-zinc-900 border border-white/8 active:scale-95 transition-all">
          <ChevronLeft className="w-4 h-4 text-zinc-400"/>
          <span className="text-xs font-semibold text-zinc-400">
            {MONTHS[new Date(viewDate.year, viewDate.month - 1, 1).getMonth()].slice(0,3)}
          </span>
        </button>
        <div className="text-center">
          <p className="text-sm font-black text-white">{MONTHS[viewDate.month]} {viewDate.year}</p>
          {!isCurrentMonth && (
            <button onClick={() => setViewDate({ year: currentDate.getFullYear(), month: currentDate.getMonth() })}
              className="text-[10px] text-violet-400 font-semibold mt-0.5">
              Volver a este mes
            </button>
          )}
        </div>
        <button onClick={() => changeViewMonth(+1)}
          disabled={viewDate.year === currentDate.getFullYear() && viewDate.month >= currentDate.getMonth()}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-zinc-900 border border-white/8 active:scale-95 transition-all disabled:opacity-30">
          <span className="text-xs font-semibold text-zinc-400">
            {MONTHS[new Date(viewDate.year, viewDate.month + 1, 1).getMonth()].slice(0,3)}
          </span>
          <ChevronRight className="w-4 h-4 text-zinc-400"/>
        </button>
      </div>

      <div className="flex-1 overflow-y-auto px-6 py-5 space-y-4">
        {/* Total del mes + promedio */}
        <div className="bg-zinc-900/40 rounded-2xl p-4 flex items-center justify-between">
          <div>
            <p className="text-[10px] text-zinc-600 font-semibold mb-0.5">{isCurrentMonth ? 'Este mes' : MONTHS[viewDate.month] + ' ' + viewDate.year}</p>
            <p className="text-2xl font-black text-white">${formatNumber(viewTotal)}</p>
            <p className="text-[10px] text-zinc-600 mt-0.5">{viewMonthTxs.length} movimiento{viewMonthTxs.length!==1?'s':''}</p>
          </div>
          {avg > 0 && (
            <div className="text-right">
              <p className="text-[10px] text-zinc-600 font-semibold mb-0.5">Promedio mensual</p>
              <p className={`text-lg font-black ${viewTotal > avg * 1.5 ? 'text-rose-400' : viewTotal > avg ? 'text-amber-400' : 'text-emerald-400'}`}>
                ${formatNumber(avg)}
              </p>
              <p className={`text-[9px] font-bold mt-0.5 ${viewTotal > avg ? 'text-rose-500' : 'text-emerald-500'}`}>
                {viewTotal > avg ? `+${formatNumber(viewTotal - avg)} vs prom.` : `−${formatNumber(avg - viewTotal)} vs prom.`}
              </p>
            </div>
          )}
        </div>
        {/* 6-month bars — tappable para navegar */}
        <div className="bg-zinc-900/40 rounded-2xl p-4">
          <p className="text-xs font-bold text-zinc-400 mb-3">Histórico mensual (últimos 6)</p>
          <div className="flex items-end gap-1.5 h-20">
            {sixMonths.map((m, i) => {
              const d = new Date(viewDate.year, viewDate.month - (5 - i), 1);
              const barH = m.amount > 0 ? Math.max(4, Math.round((m.amount / maxVal) * 64)) : 0;
              return (
                <button key={i} className="flex-1 flex flex-col items-center justify-end gap-1.5 active:opacity-60"
                  onClick={() => setViewDate({ year: d.getFullYear(), month: d.getMonth() })}>
                  {m.amount > 0 && !m.isCurrent && (
                    <span className="text-[8px] text-zinc-600">${formatNumber(m.amount)}</span>
                  )}
                  <div className={`w-full rounded-t-md transition-all duration-500 ${m.isCurrent ? 'bg-rose-400' : 'bg-rose-800/60'}`}
                    style={{height: barH > 0 ? `${barH}px` : '2px'}}/>
                  <span className={`text-[9px] ${m.isCurrent ? 'text-rose-400 font-bold' : 'text-zinc-600'}`}>{m.label}</span>
                </button>
              );
            })}
          </div>
          <p className="text-[9px] text-zinc-700 mt-2 text-center">Toca una barra para ver ese mes</p>
        </div>

        {/* Transacciones del mes seleccionado */}
        {viewMonthTxs.length > 0 ? (
          <div>
            <p className="text-xs font-bold text-zinc-400 mb-3">{viewMonthTxs.length} movimiento{viewMonthTxs.length!==1?'s':''}</p>
            <div className="space-y-2">
              {viewMonthTxs.map(t => (
                <div key={t.id} className="flex items-center gap-3 bg-zinc-900/40 rounded-xl px-4 py-3">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-1.5">
                      <p className="text-xs font-semibold text-zinc-300 truncate">{t.note || cat}</p>
                      {t.subcategory && <span className="text-[9px] bg-teal-500/15 text-teal-400 px-1.5 rounded-md">{t.subcategory}</span>}
                      {t.account && <span className="text-[9px] bg-violet-500/15 text-violet-400 px-1.5 rounded-md">{t.account}</span>}
                    </div>
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
          <p className="text-center text-sm text-zinc-600 py-6">Sin gastos en {MONTHS[viewDate.month]} {viewDate.year}</p>
        )}
      </div>
      <div className="px-6 pb-[calc(env(safe-area-inset-bottom)+16px)] pt-4 border-t border-white/8">
        <button onClick={onGoToHistory}
          className="w-full py-3.5 bg-violet-600 rounded-2xl text-sm font-bold active:scale-95 transition-transform">
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
        {[{ label:'Mes A', state: monthA, set: setMonthA, color:'text-violet-400' },
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
          <p className="text-xs font-black text-violet-400 text-right pr-2">{MONTHS[monthA.month].slice(0,3)} {monthA.year}</p>
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
          {[{s:sA,label:MONTHS[monthA.month].slice(0,3),col:'text-violet-400'},{s:sB,label:MONTHS[monthB.month].slice(0,3),col:'text-violet-400'}].map(({s,label,col})=>(
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
          <button onClick={()=>onToggle(rec)} className={`p-1 transition-colors ${rec.active?'text-violet-400':'text-zinc-700'}`} title={rec.active?'Pausar':'Activar'}>
            <RefreshCw className="w-3.5 h-3.5"/>
          </button>
          <button onClick={()=>onEdit(rec)} className="p-1 text-zinc-700 active:text-violet-400 transition-colors">
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
function RecurringForm({ rec, categories, accounts: accs, currSymbol, onSave, onClose }) {
  const [type,      setType]      = useState(rec?.type || 'GASTO');
  const [amount,    setAmount]    = useState(rec ? formatNumber(rec.amount) : '');
  const [category,  setCategory]  = useState(rec?.category || (categories?.GASTO?.[0] || ''));
  const [subcateg,  setSubcateg]  = useState(rec?.subcategory || '');
  const [acctVal,   setAcctVal]   = useState(rec?.account || '');
  const [frequency, setFrequency] = useState(rec?.frequency || 'monthly');
  const [startDate, setStartDate] = useState(rec?.start_date || new Date().toISOString().slice(0,10));
  const [endDate,   setEndDate]   = useState(rec?.end_date || '');
  const [note,      setNote]      = useState(rec?.note || '');
  const [saving,    setSaving]    = useState(false);

  const currentCats  = categories?.[type] || [];
  const accountList  = accs || [];
  const catSubcats   = (() => {
    try { return JSON.parse(localStorage.getItem('metacasa_categories') || 'null')?.subcategories?.[category] || []; } catch { return []; }
  })();

  const handleSave = async () => {
    if (!amount || !category) return;
    setSaving(true);
    await onSave({
      id: rec?.id,
      type,
      amount: parseFormattedNumber(amount),
      category,
      subcategory: subcateg || null,
      account:     acctVal  || null,
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
    <div className="fixed inset-0 z-[300] bg-black/80 backdrop-blur-2xl flex items-end justify-center">
      <div className="anim-slide-up w-full max-w-md bg-zinc-950 rounded-t-[2.5rem] border-t border-white/10 px-6 pt-6 space-y-5 pb-[calc(2rem+env(safe-area-inset-bottom))] max-h-[90dvh] overflow-y-auto no-scrollbar">
        <div className="flex justify-between items-center">
          <h3 className="text-lg font-black uppercase tracking-tight">{rec ? 'Editar' : 'Nuevo'} recurrente</h3>
          <button onClick={onClose} className="p-2 bg-zinc-900 rounded-full"><X className="w-5 h-5"/></button>
        </div>

        {/* Tipo */}
        <div className="flex mc-card-inset p-1.5 gap-1" style={{borderRadius:'1rem'}}>
          {['GASTO','INGRESO'].map(t=>(
            <button key={t} onClick={()=>{ setType(t); setCategory(categories?.[t]?.[0]||''); setSubcateg(''); }}
              className={`flex-1 py-2.5 text-sm font-bold rounded-xl transition-all duration-200 active:scale-[0.97]
                ${type===t?(t==='GASTO'?'bg-rose-600 text-white shadow-lg shadow-rose-900/40':'bg-emerald-600 text-white shadow-lg shadow-emerald-900/40'):'text-zinc-500'}`}>
              {t === 'GASTO' ? '↓ Gasto' : '↑ Ingreso'}
            </button>
          ))}
        </div>

        {/* Monto */}
        <input
          value={amount ? `${currSymbol || '$'} ${amount}` : ''}
          onChange={e => {
            const raw = e.target.value.replace(/[^0-9]/g, '');
            setAmount(raw ? raw.replace(/\B(?=(\d{3})+(?!\d))/g, '.') : '');
          }}
          placeholder={`${currSymbol || '$'} 0`}
          inputMode="numeric"
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-2xl font-black text-center focus:outline-none focus:border-violet-500/60"/>

        {/* Categoría */}
        <div className="space-y-2">
          <p className="text-label ml-1">Categoría</p>
          <div className="flex flex-wrap gap-2">
            {currentCats.map(c=>(
              <button key={c} onClick={()=>{ setCategory(c); setSubcateg(''); }}
                className={`px-3.5 py-2 rounded-xl text-xs font-bold transition-all active:scale-95
                  ${category===c?(type==='GASTO'?'bg-rose-600 text-white':'bg-emerald-600 text-white'):'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
                {c}
              </button>
            ))}
          </div>
        </div>

        {/* Subcategoría (solo si hay) */}
        {catSubcats.length > 0 && (
          <div className="space-y-2">
            <p className="text-label ml-1">Subcategoría</p>
            <div className="flex flex-wrap gap-2">
              <button onClick={()=>setSubcateg('')}
                className={`px-3.5 py-2 rounded-xl text-xs font-bold transition-all active:scale-95
                  ${!subcateg?'bg-zinc-700 text-white':'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
                General
              </button>
              {catSubcats.map(sc=>(
                <button key={sc} onClick={()=>setSubcateg(sc)}
                  className={`px-3.5 py-2 rounded-xl text-xs font-bold transition-all active:scale-95
                    ${subcateg===sc?'bg-teal-600 text-white':'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
                  {sc}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Cuenta */}
        {accountList.length > 0 && (
          <div className="space-y-2">
            <p className="text-label ml-1">Cuenta</p>
            <div className="flex flex-wrap gap-2">
              <button onClick={()=>setAcctVal('')}
                className={`px-3.5 py-2 rounded-xl text-xs font-bold transition-all active:scale-95
                  ${!acctVal?'bg-violet-600 text-white':'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
                Sin especificar
              </button>
              {accountList.map(a=>(
                <button key={a} onClick={()=>setAcctVal(a)}
                  className={`px-3.5 py-2 rounded-xl text-xs font-bold transition-all active:scale-95
                    ${acctVal===a?'bg-violet-600 text-white':'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
                  {a}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Frecuencia */}
        <div className="space-y-2">
          <p className="text-label ml-1">Frecuencia</p>
          <div className="grid grid-cols-4 gap-2">
            {FREQUENCIES.map(f=>(
              <button key={f.v} onClick={()=>setFrequency(f.v)}
                className={`py-3 rounded-xl text-xs font-bold transition-all flex flex-col items-center gap-1 active:scale-95
                  ${frequency===f.v?'bg-violet-600 text-white':'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
                <span className="text-base">{f.icon}</span>
                <span>{f.l}</span>
              </button>
            ))}
          </div>
        </div>

        {/* Fechas */}
        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1">
            <p className="text-label ml-1">Inicia</p>
            <input type="date" value={startDate} onChange={e=>setStartDate(e.target.value)}
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-violet-500/60"/>
          </div>
          <div className="space-y-1">
            <p className="text-label ml-1">Termina (opc.)</p>
            <input type="date" value={endDate} onChange={e=>setEndDate(e.target.value)}
              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-violet-500/60"/>
          </div>
        </div>

        {/* Nota */}
        <textarea value={note} onChange={e=>setNote(e.target.value)} placeholder="Nota (opcional)" rows={2}
          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm text-zinc-400 resize-none focus:outline-none focus:border-violet-500/60"/>

        <button onClick={handleSave} disabled={saving||!amount||!category}
          className="w-full py-5 bg-violet-600 rounded-2xl font-black text-sm uppercase tracking-widest active:scale-95 transition-all disabled:opacity-40">
          {saving ? 'Guardando…' : rec ? 'Guardar cambios' : 'Agregar recurrente'}
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// SORTABLE WIDGET ITEM (para Personalizar modal)
// ─────────────────────────────────────────────
function SortableWidgetItem({ widget, hidden, size, onToggle, onCycleSize }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: widget.id });
  const style = { transform: DndCSS.Transform.toString(transform), transition, opacity: isDragging ? 0.5 : 1 };
  const sizeLabel = size === 'S' ? 'S' : size === 'L' ? 'L' : 'M';
  return (
    <div ref={setNodeRef} style={style}
      className={`flex items-center gap-2 px-3 py-3 rounded-2xl border transition-all
        ${hidden ? 'bg-zinc-900/20 border-white/4 opacity-50' : 'bg-zinc-900/50 border-white/8'}`}>
      {/* Drag handle */}
      <button {...attributes} {...listeners}
        className="cursor-grab active:cursor-grabbing p-1 text-zinc-600 hover:text-zinc-400 touch-none flex-shrink-0"
        tabIndex={-1}>
        <GripVertical className="w-4 h-4"/>
      </button>
      {/* Icon + Label */}
      <span className="text-base leading-none flex-shrink-0">{widget.icon}</span>
      <span className={`text-sm font-semibold flex-1 min-w-0 truncate ${hidden ? 'text-zinc-600' : 'text-zinc-300'}`}>{widget.label}</span>
      {/* Size cycle button */}
      {!hidden && (
        <button onClick={() => onCycleSize(widget.id)}
          className={`text-[10px] font-black px-2 py-1 rounded-lg border flex-shrink-0 transition-all active:scale-90
            ${size === 'S' ? 'bg-zinc-800 border-zinc-700 text-zinc-400' :
              size === 'L' ? 'bg-violet-700/15 border-violet-500/30 text-violet-400' :
              'bg-zinc-900 border-white/8 text-zinc-500'}`}>
          {sizeLabel}
        </button>
      )}
      {/* Toggle switch */}
      <button onClick={() => onToggle(widget.id)}
        className={`w-10 h-5 rounded-full flex-shrink-0 flex items-center px-0.5 transition-all
          ${hidden ? 'bg-zinc-800 justify-start' : 'bg-violet-600 justify-end'}`}>
        <div className="w-4 h-4 rounded-full bg-white shadow-sm"/>
      </button>
    </div>
  );
}

// ─────────────────────────────────────────────
// UTILS: Distribución de presupuesto
// ─────────────────────────────────────────────

/** Calcula allocations a partir de inputs del drawer de distribución.
 *  @param {number} globalAmount - Monto total del presupuesto global
 *  @param {Array<{account,mode,value}>} inputs - mode: '$'|'%'
 *  @returns {{ allocations, remainder, valid }}
 */
function calcAllocations(globalAmount, inputs) {
  const allocations = inputs.map(inp => ({
    account: inp.account,
    amount: inp.mode === '%'
      ? Math.round(globalAmount * (Number(inp.value) || 0) / 100)
      : Number(inp.value) || 0,
  }));
  const total     = allocations.reduce((a, b) => a + b.amount, 0);
  const remainder = globalAmount - total;
  const valid     = Math.abs(remainder) <= 1; // tolerancia $1 por redondeo
  return { allocations, remainder, valid };
}

/** Componente: formulario de distribución por cuenta */
function DistInputs({ accounts, globalAmt, existingBudgets, cat, subcat, onSave, onCancel, formatNumber: fmt }) {
  const [mode, setMode] = useState('$');
  const [inputs, setInputs] = useState(() =>
    accounts.map(acc => ({
      account: acc,
      mode: '$',
      value: existingBudgets[`${acc}|${cat}|${subcat}`]?.amount || 0,
    }))
  );
  const [saving, setSaving] = useState(false);
  const { allocations, remainder, valid } = calcAllocations(globalAmt, inputs);

  const switchMode = (newMode) => {
    setMode(newMode);
    setInputs(prev => prev.map(inp => ({
      ...inp,
      mode: newMode,
      value: newMode === '%'
        ? (globalAmt > 0 ? Math.round((inp.value / globalAmt) * 100) : 0)
        : Math.round(globalAmt * (inp.value || 0) / 100),
    })));
  };

  const updateVal = (i, raw) => {
    const next = [...inputs];
    const v = Number(String(raw).replace(/[^0-9.]/g,'')) || 0;
    next[i] = { ...next[i], value: mode === '%' ? Math.min(100, v) : v };
    setInputs(next);
  };

  const handleSave = async () => {
    if (!valid || saving) return;
    setSaving(true);
    await onSave(allocations);
    setSaving(false);
  };

  const totalAssigned = allocations.reduce((a, b) => a + b.amount, 0);

  return (
    <div className="space-y-4">
      {/* Toggle $ / % */}
      <div className="flex gap-2">
        {['$', '%'].map(m => (
          <button key={m} onClick={() => switchMode(m)}
            className={`flex-1 py-2 rounded-xl text-sm font-bold transition-all active:scale-95 ${
              mode === m ? 'bg-violet-600 text-white' : 'bg-zinc-900 text-zinc-500 border border-white/8'
            }`}>
            {m === '$' ? 'Monto fijo ($)' : 'Porcentaje (%)'}
          </button>
        ))}
      </div>

      {/* Fila por cuenta */}
      <div className="space-y-2">
        {inputs.map((inp, i) => (
          <div key={inp.account} className="flex items-center gap-3 bg-zinc-900/60 rounded-2xl px-4 py-3 border border-white/5">
            <span className="text-sm font-bold text-zinc-300 w-16 flex-shrink-0 truncate">{inp.account}</span>
            <div className="flex-1 flex items-center gap-1 border-b border-white/10 pb-0.5">
              <span className="text-xs text-zinc-600">{mode}</span>
              <input
                type="number"
                value={inp.value || ''}
                onChange={e => updateVal(i, e.target.value)}
                className="flex-1 bg-transparent text-right text-sm font-black text-white focus:outline-none [appearance:textfield]"
                placeholder="0"
                inputMode="numeric"
              />
            </div>
            {/* Preview en la otra unidad */}
            <span className="text-[10px] text-zinc-600 w-16 text-right flex-shrink-0">
              {mode === '%'
                ? `$${fmt(Math.round(globalAmt * (inp.value||0) / 100))}`
                : `${globalAmt > 0 ? Math.round(((inp.value||0)/globalAmt)*100) : 0}%`}
            </span>
          </div>
        ))}
      </div>

      {/* Barra de validación */}
      <div className={`flex items-center justify-between px-3 py-2.5 rounded-xl text-xs font-bold transition-colors ${
        valid ? 'bg-emerald-500/10 text-emerald-400' : 'bg-rose-500/10 text-rose-400'
      }`}>
        <span>Total asignado</span>
        <span>
          ${fmt(totalAssigned)} / ${fmt(globalAmt)}
          {!valid && (
            <span className="ml-1">
              ({remainder > 0 ? `faltan $${fmt(remainder)}` : `excede $${fmt(-remainder)}`})
            </span>
          )}
        </span>
      </div>

      {/* Botones */}
      <div className="flex gap-3 pt-1">
        <button onClick={onCancel}
          className="flex-1 py-3 bg-zinc-900 rounded-2xl text-sm font-bold text-zinc-400 active:opacity-60 border border-white/8">
          Cancelar
        </button>
        <button onClick={handleSave} disabled={!valid || saving}
          className={`flex-1 py-3 rounded-2xl text-sm font-bold transition-all ${
            valid && !saving
              ? 'bg-violet-600 text-white active:scale-[0.97]'
              : 'bg-zinc-800 text-zinc-600 cursor-not-allowed'
          }`}>
          {saving ? 'Guardando…' : 'Guardar'}
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
  const [showPassword, setShowPassword] = useState(false);
  // Tema: 'dark' | 'light' | 'auto'
  const [appTheme, setAppTheme] = useState(() => localStorage.getItem(THEME_KEY) || 'dark');
  const saveTheme = (t) => { setAppTheme(t); localStorage.setItem(THEME_KEY, t); };

  // ONBOARDING
  const ONBOARDING_KEY = 'metacasa_onboarding_done';
  const [showOnboarding, setShowOnboarding] = useState(false);
  const [onboardingStep, setOnboardingStep] = useState(1); // 1=welcome, 2=accounts, 3=currency, 4=done
  const [onboardingAccounts, setOnboardingAccounts] = useState([]);
  const [onboardingNewName, setOnboardingNewName] = useState('');

  // DATA
  const [transactions, setTransactions] = useState([]);
  const [budgets,      setBudgets]      = useState({});
  const [budgetAccount, setBudgetAccount] = useState('');        // '' = Todas
  const [expandedBudgetCats, setExpandedBudgetCats] = useState(new Set()); // categorías con subcats expandidas
  const [homeAccount, setHomeAccount] = useState('');            // '' = Todas
  const [statsAccount, setStatsAccount] = useState('');          // '' = Todas (para tab estadísticas)
  const [distDrawer, setDistDrawer]   = useState(null);          // null | { cat, subcat }
  const [strategy,     setStrategy]     = useState({ savingsPercent: 0, investmentPercent: 0, useGlobal: true });
  // Waterfall: tipo de cuenta 'personal' | 'compartida'
  const [accountTypes, setAccountTypes] = useState(() => {
    try { return JSON.parse(localStorage.getItem(ACCOUNT_TYPES_KEY) || '{}'); } catch { return {}; }
  });
  const saveAccountTypes = (types) => { setAccountTypes(types); localStorage.setItem(ACCOUNT_TYPES_KEY, JSON.stringify(types)); };
  // Waterfall: distribución del saldo a personas
  const [allocations, setAllocations] = useState(() => {
    try { return JSON.parse(localStorage.getItem(ALLOCATIONS_KEY) || '{"mode":"equal","amounts":{}}'); } catch { return { mode: 'equal', amounts: {} }; }
  });
  const saveAllocations = (alloc) => { setAllocations(alloc); localStorage.setItem(ALLOCATIONS_KEY, JSON.stringify(alloc)); };
  // Waterfall: qué cuenta maneja ahorro e inversión ('' = hogar/compartida)
  const [savingsInvestAccount, setSavingsInvestAccount] = useState(() => {
    return localStorage.getItem(SAVINGS_ACCOUNT_KEY) || '';
  });
  const saveSavingsInvestAccount = (acc) => { setSavingsInvestAccount(acc); localStorage.setItem(SAVINGS_ACCOUNT_KEY, acc); };
  const [customCats,   setCustomCats]   = useState(null);
  const [catMeta,      setCatMeta]      = useState({}); // { NombreCat: { emoji, color } }
  const [needsCats, setNeedsCats]     = useState(loadNeedsCats);
  const saveNeedsCats = (cats) => { const s = new Set(cats); setNeedsCats(s); localStorage.setItem(NEEDS_CATS_KEY, JSON.stringify([...s])); };
  const [subcategories, setSubcategories] = useState(() => {
    try { return JSON.parse(localStorage.getItem('metacasa_subcats') || '{}'); } catch { return {}; }
  }); // { catName: ['Subcat1', 'Subcat2'] }
  // UI state for subcategory management in CatManager
  const [expandedCatSubcat, setExpandedCatSubcat] = useState(null);
  const [newSubcatInput, setNewSubcatInput] = useState('');
  const [loadingData,  setLoadingData]  = useState(true);
  const [bills,        setBills]        = useState([]);
  const [recurring,    setRecurring]    = useState([]);

  // ── BILLETERAS / PSP ──────────────────────────────────
  const [wallets,              setWallets]              = useState([]);
  const [walletMovements,      setWalletMovements]      = useState([]);
  const [showWalletConnect,    setShowWalletConnect]    = useState(false);
  const [walletConnectStep,    setWalletConnectStep]    = useState(1); // 1=provider, 2=creds, 3=naming
  const [walletConnectProv,    setWalletConnectProv]    = useState(null);
  const [walletConnectCreds,   setWalletConnectCreds]   = useState({});
  const [walletConnectName,    setWalletConnectName]    = useState('');
  const [walletConnectLoading, setWalletConnectLoading] = useState(false);
  const [selectedWallet,       setSelectedWallet]       = useState(null);
  const [syncingWalletId,      setSyncingWalletId]      = useState(null);
  const [editingWalletBalance, setEditingWalletBalance] = useState(null); // wallet being balance-edited
  const [editBalanceVal,       setEditBalanceVal]       = useState('');
  const [mpOAuthLoading,       setMpOAuthLoading]       = useState(false); // OAuth exchange in progress
  const [mpManualToken,        setMpManualToken]        = useState(false);  // show manual token input

  // PRESUPUESTO POR PERÍODO
  const [budgetPeriod, setBudgetPeriod] = useState(() => {
    const n = new Date(); return { year: n.getFullYear(), month: n.getMonth() };
  });
  const [showBudgetPeriodPicker, setShowBudgetPeriodPicker] = useState(false);
  const [paidItems,    setPaidItems]    = useState({});
  const [budgetModes,  setBudgetModes]  = useState(() => {
    try { return JSON.parse(localStorage.getItem(BUDGET_MODE_KEY)||'{}'); } catch { return {}; }
  });
  const [expandHistorico, setExpandHistorico] = useState(false);
  const [showBudgetResumen, setShowBudgetResumen] = useState(false);
  const [showDueDateCalendar, setShowDueDateCalendar] = useState(false);
  const [calendarSelectedDay, setCalendarSelectedDay] = useState(null);
  const [fixedTxs,     setFixedTxs]     = useState(() => {
    try { return JSON.parse(localStorage.getItem(FIXED_TX_KEY)||'[]'); } catch { return []; }
  });
  // Estado de "abonado" por período para vencimientos (bills) y cuotas
  const [paidBillsInPeriod,  setPaidBillsInPeriod]  = useState({});
  const [paidCuotasInPeriod, setPaidCuotasInPeriod] = useState({});

  // NAVIGATION
  const [activeTab, setActiveTab] = useState('home'); // home | add | history | settings | stats
  const [statsView, setStatsView] = useState('menu'); // menu | gastos | ingresos | tendencias | salud | presupuesto | ahorro

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
  const [editingFixedTx,     setEditingFixedTx]      = useState(null); // action sheet Gastos Fijos
  const [editingBudgetItem,  setEditingBudgetItem]   = useState(null); // action sheet Vencimientos/Cuotas
  const [detailCat,          setDetailCat]           = useState(null); // sheet detalle categoría
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
  // ── HELP CENTER ──
  const [showHelpCenter,     setShowHelpCenter]     = useState(false);
  const [helpTab,            setHelpTab]            = useState('topics');
  const [helpSearchQuery,    setHelpSearchQuery]    = useState('');
  const [helpSelectedTopic,  setHelpSelectedTopic]  = useState(null);
  const [helpChatMessages,   setHelpChatMessages]   = useState([]);
  const [helpChatInput,      setHelpChatInput]      = useState('');
  const [helpChatLoading,    setHelpChatLoading]    = useState(false);
  const helpChatRef = useRef(null);
  // ── AI Provider Config ──
  const [aiConfig, setAiConfig] = useState(() => {
    try { return JSON.parse(localStorage.getItem(AI_CONFIG_KEY) || 'null'); } catch { return null; }
  });
  const [showAIConfig, setShowAIConfig] = useState(false);
  const [aiTestStatus, setAiTestStatus] = useState(null);
  const [aiTestError, setAiTestError] = useState('');
  const saveAiConfig = (config) => {
    setAiConfig(config);
    if (config) localStorage.setItem(AI_CONFIG_KEY, JSON.stringify(config));
    else localStorage.removeItem(AI_CONFIG_KEY);
  };
  // Widgets visibles por defecto (curados) — el resto se oculta para nuevos usuarios
  const CURATED_WIDGETS = new Set([
    'planMes','dailyBudget','topTxs','recurringAlerts','semaforo',
    'rule503020','healthScore','todaySummary','gastosHoy','monthProjection',
    'goalsWidget','debtsWidget','savings','donutChart','prevMonthCompare',
    'recurringFixed','vencimientos',
  ]);
  const [hiddenWidgets,      setHiddenWidgets]      = useState(() => {
    try {
      const stored = localStorage.getItem(HIDDEN_WIDGETS_KEY);
      if (stored) return new Set(JSON.parse(stored));
      // First time: hide all except curated set
      const allIds = WIDGET_LIST.map(w => w.id);
      const defaultHidden = allIds.filter(id => !CURATED_WIDGETS.has(id));
      return new Set(defaultHidden);
    } catch { return new Set(); }
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
  // ── Widget Order (persisted) ──
  const [widgetOrder, setWidgetOrder] = useState(() => {
    try {
      const stored = JSON.parse(localStorage.getItem(WIDGET_ORDER_KEY) || 'null');
      const allIds = WIDGET_LIST.map(w => w.id);
      if (!stored) return allIds;
      const missing = allIds.filter(id => !stored.includes(id));
      return [...stored.filter(id => allIds.includes(id)), ...missing];
    } catch { return WIDGET_LIST.map(w => w.id); }
  });

  // ── Widget Sizes (persisted) ──
  const [widgetSizes, setWidgetSizes] = useState(() => {
    try { return JSON.parse(localStorage.getItem(WIDGET_SIZES_KEY) || '{}'); }
    catch { return {}; }
  });

  const getOrder = useCallback((id) => {
    const idx = widgetOrder.indexOf(id);
    return idx === -1 ? widgetOrder.length : idx;
  }, [widgetOrder]);

  const getWidgetSize = useCallback((id) => widgetSizes[id] ?? 'M', [widgetSizes]);

  const cycleWidgetSize = useCallback((id) => {
    setWidgetSizes(prev => {
      const cur = prev[id] ?? 'M';
      const next = cur === 'M' ? 'S' : cur === 'S' ? 'L' : 'M';
      const n = { ...prev, [id]: next };
      localStorage.setItem(WIDGET_SIZES_KEY, JSON.stringify(n));
      haptic(6);
      return n;
    });
  }, []);

  const reorderWidgets = useCallback((activeId, overId) => {
    setWidgetOrder(prev => {
      const oldIdx = prev.indexOf(activeId);
      const newIdx = prev.indexOf(overId);
      if (oldIdx === -1 || newIdx === -1) return prev;
      const next = arrayMove(prev, oldIdx, newIdx);
      localStorage.setItem(WIDGET_ORDER_KEY, JSON.stringify(next));
      return next;
    });
  }, []);

  // Sensores DnD — declarados como hooks en el top-level del componente
  const dndSensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 8 } }),
    useSensor(TouchSensor, { activationConstraint: { delay: 200, tolerance: 8 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates })
  );

  // ww() = widget wrapper: aplica isHidden, CSS order y size
  const ww = useCallback((id, content) => {
    if (isHidden(id)) return null;
    const size = getWidgetSize(id);
    return (
      <div key={id} style={{ order: getOrder(id) }} className={
        size === 'L' ? 'md:col-span-2' :
        size === 'S' ? 'max-h-[76px] overflow-hidden relative after:content-[""] after:absolute after:bottom-0 after:inset-x-0 after:h-5 after:bg-gradient-to-t after:from-black after:to-transparent pointer-events-none' : ''
      }>{content}</div>
    );
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [widgetOrder, widgetSizes, hiddenWidgets]);
  const [showScrollTop,      setShowScrollTop]       = useState(false);
  const [deferredInstall,    setDeferredInstall]     = useState(null);
  const [showInstallBanner,  setShowInstallBanner]   = useState(false);

  // BÚSQUEDA Y FILTROS (Historial)
  const [filterType,       setFilterType]       = useState('ALL');   // ALL | GASTO | INGRESO
  const [filterCategories, setFilterCategories] = useState(new Set()); // Set de categorías seleccionadas (vacío = todas)
  const [showHistoryMonthPicker, setShowHistoryMonthPicker] = useState(false);
  const [showCatFilter,    setShowCatFilter]    = useState(false);
  const [selectedHistoryMonth, setSelectedHistoryMonth] = useState(null); // null=mes actual | {year,month}
  const [sortBy,           setSortBy]           = useState('date_desc'); // date_desc | date_asc | amount_desc | amount_asc
  const [allMonths,        setAllMonths]        = useState(false);   // false = solo mes actual
  const [filterDate,       setFilterDate]       = useState('');      // '' | 'YYYY-MM-DD'
  const [filterMin,        setFilterMin]        = useState('');      // '' | number string
  const [filterMax,        setFilterMax]        = useState('');      // '' | number string
  const [filterWeek,       setFilterWeek]       = useState(false);   // true = esta semana
  const [filterDateFrom,   setFilterDateFrom]   = useState('');      // '' | 'YYYY-MM-DD'
  const [filterDateTo,     setFilterDateTo]     = useState('');      // '' | 'YYYY-MM-DD'
  const [showRangeFilter,  setShowRangeFilter]  = useState(false);
  const [historyDateMode,  setHistoryDateMode]  = useState('period'); // 'period' | 'real'
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
  const [isFixed,    setIsFixed]    = useState(false);
  // mesAsignado: mes en que se contabiliza el movimiento (independiente de txDate)
  const [mesAsignado, setMesAsignado] = useState(() => ({
    year: new Date().getFullYear(), month: new Date().getMonth(),
  }));
  // TIPOS DE CAMBIO por moneda — { USD: 1000, EUR: 1100 }  (debe estar antes del useEffect que lo usa)
  const [exchangeRates, setExchangeRates] = useState(() => {
    try {
      const stored = localStorage.getItem('metacasa_fx_rates');
      if (stored) return JSON.parse(stored);
    } catch {}
    // Migrar valor legacy de USD si existía
    const oldRate = parseFloat(localStorage.getItem('metacasa_usd_rate') || '0');
    return oldRate > 0 ? { USD: oldRate } : {};
  });

  // Moneda de la transacción siendo registrada (default = moneda base del usuario)
  const [txCurrency, setTxCurrency] = useState(() => localStorage.getItem(CURRENCY_KEY) || 'ARS');
  const [txFxRate,   setTxFxRate]   = useState(0);
  const [txFxLoading, setTxFxLoading] = useState(false);

  // Actualizar tipo de cambio cuando cambia la moneda de la transacción
  useEffect(() => {
    // Si la moneda de la TX coincide con la base → no se necesita conversión
    const baseCurr = localStorage.getItem(CURRENCY_KEY) || 'ARS';
    if (txCurrency === baseCurr) { setTxFxRate(1); return; }
    const manualRate = exchangeRates[txCurrency] || 0;
    setTxFxRate(manualRate > 0 ? manualRate : 0);
  }, [txCurrency, exchangeRates]);

  const autoReplicatedRef = useRef(new Set()); // meses ya auto-replicados en esta sesión

  // VOZ + REPORTE
  const [isListening,  setIsListening]  = useState(false);
  const [showReport,   setShowReport]   = useState(false);
  const recognitionRef = useRef(null);
  const voiceSupported = typeof window !== 'undefined' &&
    !!(window.SpeechRecognition || window.webkitSpeechRecognition);

  // DETALLE INGRESOS/GASTOS — Home
  const [homeDetailType, setHomeDetailType] = useState(null); // null | 'INGRESO' | 'GASTO' | 'DISPONIBLE'

  // VOZ DICTADO — Home FAB
  const [showVoiceDictado, setShowVoiceDictado] = useState(false);
  const [voiceTranscript,  setVoiceTranscript]  = useState('');
  const [voiceInterim,     setVoiceInterim]     = useState('');
  const [voiceDraft,       setVoiceDraft]       = useState({
    type: 'GASTO', amount: '', category: '', note: '',
    date: new Date().toISOString().slice(0, 10),
  });
  const [isDictandoHome,   setIsDictandoHome]   = useState(false);
  const [voiceDraftSaving, setVoiceDraftSaving] = useState(false);
  const homeRecRef = useRef(null);

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

  // ── IDIOMA (i18n) ─────────────────────────────────────────────────────────
  const [lang, setLang] = useState(() => localStorage.getItem(LANG_KEY) || 'es');
  const changeLang = (l) => { setLang(l); localStorage.setItem(LANG_KEY, l); };
  // Shorthand
  const tl = (key) => t(lang, key);

  // ── MONEDA BASE ──────────────────────────────────────────────────────────
  // `currency` ES la moneda base: todos los movimientos se guardan en esta moneda.
  const [currency, setCurrency] = useState(() => localStorage.getItem(CURRENCY_KEY) || 'ARS');
  const currSymbol = CURRENCIES[currency]?.symbol ?? '$';

  // Monedas activas (las que el usuario habilitó para usar en la app)
  const [activeCurrencies, setActiveCurrencies] = useState(() => {
    try {
      const stored = localStorage.getItem(ACTIVE_CURRENCIES_KEY);
      if (stored) return JSON.parse(stored);
    } catch {}
    return DEFAULT_ACTIVE_CURRENCIES;
  });
  const [showCurrencyPicker, setShowCurrencyPicker] = useState(false);
  const [currencySearch, setCurrencySearch] = useState('');

  const addActiveCurrency = (code) => {
    if (activeCurrencies.includes(code)) return;
    const updated = [...activeCurrencies, code];
    setActiveCurrencies(updated);
    localStorage.setItem(ACTIVE_CURRENCIES_KEY, JSON.stringify(updated));
  };
  const removeActiveCurrency = (code) => {
    if (code === currency) return; // no se puede quitar la base
    const updated = activeCurrencies.filter(c => c !== code);
    setActiveCurrencies(updated);
    localStorage.setItem(ACTIVE_CURRENCIES_KEY, JSON.stringify(updated));
  };

  // Cambiar moneda base → también resetear txCurrency al nuevo default
  const changeCurrency = (c) => {
    setCurrency(c);
    localStorage.setItem(CURRENCY_KEY, c);
    setTxCurrency(c);
  };
  // fmtMoney: los montos YA están en la moneda base → solo agregar símbolo
  const fmtMoney = (amt) => {
    const n = Math.abs(Number(amt));
    const sign = Number(amt) < 0 ? '-' : '';
    return `${sign}${currSymbol}${formatNumber(n)}`;
  };
  // exchangeRate: solo se usa para la sección de tipo de cambio en Ajustes (legacy compat)
  const exchangeRate = exchangeRates[currency] || 0;
  // needsConversion: true si hay alguna moneda no-base configurada (para mostrar sección TC)
  const needsConversion = Object.keys(CURRENCIES).some(c => c !== currency);

  // ── CUENTAS (quién pagó) ──────────────────────────────────────────────────
  const [accounts, setAccounts] = useState(() => {
    try { return JSON.parse(localStorage.getItem(ACCOUNTS_KEY) || '[]'); }
    catch { return []; }
  });
  const saveAccounts = (list) => {
    setAccounts(list);
    localStorage.setItem(ACCOUNTS_KEY, JSON.stringify(list));
  };
  // Cuenta activa del formulario de registro
  const [txAccount, setTxAccount] = useState('');
  // Filtro de historial por cuenta
  const [filterAccount, setFilterAccount] = useState('');

  // ── ESTADÍSTICAS: mes seleccionado ────────────────────────────────────────
  const [statsDate, setStatsDate] = useState(() => ({
    year: new Date().getFullYear(), month: new Date().getMonth(),
  }));
  const changeStatsMonth = (offset) => {
    setStatsDate(prev => {
      const d = new Date(prev.year, prev.month + offset, 1);
      return { year: d.getFullYear(), month: d.getMonth() };
    });
  };

  // ── SUBCATEGORÍAS (formulario registro) ──────────────────────────────────
  const [txSubcategory, setTxSubcategory] = useState('');

  // ── INPUT TEMPORAL PARA NUEVA CUENTA EN AJUSTES ──────────────────────────
  const [newAccountName, setNewAccountName] = useState('');

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
  const resetPassword = async () => {
    if (!authEmail.trim()) { toast('Ingresá tu email primero', 'error'); return; }
    const { error } = await supabase.auth.resetPasswordForEmail(authEmail.trim());
    if (error) toast(error.message, 'error');
    else toast('Te enviamos un email para restablecer tu contraseña', 'success');
  };

  // ── AI Provider: llamada directa al proveedor configurado ──
  const callAI = async (systemPrompt, messages) => {
    if (!aiConfig?.apiKey) throw new Error('No AI configured');
    const provider = aiConfig.provider;
    const provDef = AI_PROVIDERS[provider];
    const model = aiConfig.model?.trim() || provDef?.defaultModel || '';
    const apiKey = aiConfig.apiKey;

    if (provider === 'openai' || provider === 'custom') {
      const baseUrl = provider === 'custom'
        ? (aiConfig.baseUrl?.replace(/\/+$/, '') || '')
        : 'https://api.openai.com';
      const res = await fetch(`${baseUrl}/v1/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
        body: JSON.stringify({
          model, max_tokens: 1024, temperature: 0.4,
          messages: [{ role: 'system', content: systemPrompt }, ...messages.map(m => ({ role: m.role, content: m.content }))],
        }),
      });
      if (!res.ok) { const e = await res.json().catch(() => ({})); throw new Error(e.error?.message || `HTTP ${res.status}`); }
      const data = await res.json();
      return data.choices?.[0]?.message?.content || '';
    }
    if (provider === 'gemini') {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
      const contents = messages.map(m => ({ role: m.role === 'assistant' ? 'model' : 'user', parts: [{ text: m.content }] }));
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contents, systemInstruction: { parts: [{ text: systemPrompt }] }, generationConfig: { maxOutputTokens: 1024, temperature: 0.4 } }),
      });
      if (!res.ok) { const e = await res.json().catch(() => ({})); throw new Error(e.error?.message || `HTTP ${res.status}`); }
      const data = await res.json();
      return data.candidates?.[0]?.content?.parts?.[0]?.text || '';
    }
    if (provider === 'anthropic') {
      const res = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'anthropic-dangerous-direct-browser-access': 'true' },
        body: JSON.stringify({ model, max_tokens: 1024, system: systemPrompt, messages: messages.map(m => ({ role: m.role, content: m.content })) }),
      });
      if (!res.ok) { const e = await res.json().catch(() => ({})); throw new Error(e.error?.message || `HTTP ${res.status}`); }
      const data = await res.json();
      return data.content?.[0]?.text || '';
    }
    throw new Error('Unknown provider');
  };

  // ── Help Center: AI Chat ──
  const sendHelpChatMessage = async () => {
    const msg = helpChatInput.trim();
    if (!msg || helpChatLoading) return;
    const userMessage = { role: 'user', content: msg };
    const updated = [...helpChatMessages, userMessage];
    setHelpChatMessages(updated);
    setHelpChatInput('');
    setHelpChatLoading(true);
    setTimeout(() => helpChatRef.current?.scrollTo({ top: helpChatRef.current.scrollHeight, behavior: 'smooth' }), 50);

    const topics = HELP_CONTENT(lang);
    const contextStr = topics.map(tp =>
      `## ${tp.title}\n${tp.sections.map(s => `### ${s.heading}\n${s.body}`).join('\n')}`
    ).join('\n\n');

    // 1) IA del usuario (llamada directa al proveedor)
    if (aiConfig?.apiKey) {
      try {
        const systemPrompt = lang === 'es'
          ? `Sos el asistente de MetaCasa, una app de finanzas del hogar. Respondé SOLO sobre MetaCasa usando esta documentación. Sé conciso y amigable. Si la pregunta no se relaciona con MetaCasa, decí que solo podés ayudar con temas de la app.\n\nDocumentación:\n${contextStr}`
          : `You are the MetaCasa help assistant, a household finance app. Answer ONLY about MetaCasa using this documentation. Be concise and friendly. If unrelated, say you can only help with app topics.\n\nDocumentation:\n${contextStr}`;
        const reply = await callAI(systemPrompt, updated.slice(-10));
        setHelpChatMessages(prev => [...prev, { role: 'assistant', content: reply }]);
        setHelpChatLoading(false);
        setTimeout(() => helpChatRef.current?.scrollTo({ top: helpChatRef.current.scrollHeight, behavior: 'smooth' }), 100);
        return;
      } catch (err) {
        console.error('AI provider error:', err);
      }
    }

    // 2) Supabase Edge Function (futuro server-side)
    try {
      const { data, error } = await supabase.functions.invoke('help-chat', {
        body: { messages: updated.slice(-10), appContext: contextStr, lang },
      });
      if (error) throw error;
      setHelpChatMessages(prev => [...prev, { role: 'assistant', content: data.reply }]);
    } catch (err) {
      // 3) Fallback local: búsqueda por keywords
      const q = msg.toLowerCase();
      const match = topics.find(tp =>
        tp.keywords.some(k => q.includes(k)) ||
        tp.title.toLowerCase().includes(q) ||
        tp.sections.some(s => s.body.toLowerCase().includes(q))
      );
      const fallback = match
        ? `${match.icon} **${match.title}**\n\n${match.sections.map(s => `**${s.heading}:** ${s.body}`).join('\n\n')}${match.tip ? `\n\n💡 ${match.tip}` : ''}`
        : (lang === 'es'
          ? 'No pude conectar con el asistente IA. Probá buscando en la pestaña "Temas" o "Buscar" del centro de ayuda.'
          : 'Could not connect to the AI assistant. Try searching in the "Topics" or "Search" tab of the help center.');
      setHelpChatMessages(prev => [...prev, { role: 'assistant', content: fallback }]);
    } finally {
      setHelpChatLoading(false);
      setTimeout(() => helpChatRef.current?.scrollTo({ top: helpChatRef.current.scrollHeight, behavior: 'smooth' }), 100);
    }
  };

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
    const { data, error } = await supabase.from('budgets').select('account, category, subcategory, amount');
    if (error) { console.error(error); return; }
    const b = {};
    (data || []).forEach(row => {
      const key = `${row.account || ''}|${row.category}|${row.subcategory || ''}`;
      b[key] = { amount: Number(row.amount || 0) };
    });
    setBudgets(b);
  }, [userId]);

  const loadStrategy = useCallback(async () => {
    if (!userId) return;
    const { data, error } = await supabase.from('strategy')
      .select('savings_percent, investment_percent, use_global').maybeSingle();
    if (error && error.code !== 'PGRST116') { console.error(error); return; }
    setStrategy({
      savingsPercent:    Number(data?.savings_percent    || 0),
      investmentPercent: Number(data?.investment_percent || 0),
      useGlobal:         data?.use_global ?? true,
    });
  }, [userId]);

  const loadCategories = useCallback(async () => {
    if (!userId) return;
    const { data, error } = await supabase.from('categories').select('data').maybeSingle();
    if (error && error.code !== 'PGRST116') { console.error(error); return; }
    const raw = data?.data || null;
    if (raw) {
      const { meta, goals: cloudGoals, cuotas: cloudCuotas, debts: cloudDebts, subcategories: cloudSubcats,
              accounts: cloudAccounts, accountTypes: cloudAccountTypes, allocations: cloudAllocations, savingsInvestAccount: cloudSavingsAccount,
              ...cats } = raw;
      setCustomCats(cats);
      setCatMeta(meta || {});
      if (cloudSubcats) {
        setSubcategories(cloudSubcats);
        localStorage.setItem('metacasa_subcats', JSON.stringify(cloudSubcats));
        const catData = JSON.parse(localStorage.getItem('metacasa_categories') || '{}');
        catData.subcategories = cloudSubcats;
        localStorage.setItem('metacasa_categories', JSON.stringify(catData));
      }
      // Cloud wins over localStorage
      if (cloudGoals)  { setGoals(cloudGoals);   localStorage.setItem(GOALS_KEY,  JSON.stringify(cloudGoals));  }
      if (cloudCuotas) { setCuotas(cloudCuotas); localStorage.setItem(CUOTAS_KEY, JSON.stringify(cloudCuotas)); }
      if (cloudDebts)  { setDebts(cloudDebts); }
      // Sincronizar cuentas y configuración hogar desde la nube
      if (cloudAccounts && cloudAccounts.length > 0) {
        setAccounts(cloudAccounts); localStorage.setItem(ACCOUNTS_KEY, JSON.stringify(cloudAccounts));
      }
      if (cloudAccountTypes && Object.keys(cloudAccountTypes).length > 0) {
        setAccountTypes(cloudAccountTypes); localStorage.setItem(ACCOUNT_TYPES_KEY, JSON.stringify(cloudAccountTypes));
      }
      if (cloudAllocations && cloudAllocations.mode) {
        setAllocations(cloudAllocations); localStorage.setItem(ALLOCATIONS_KEY, JSON.stringify(cloudAllocations));
      }
      if (cloudSavingsAccount !== undefined) {
        setSavingsInvestAccount(cloudSavingsAccount); localStorage.setItem(SAVINGS_ACCOUNT_KEY, cloudSavingsAccount);
      }
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

  const loadWallets = useCallback(async () => {
    if (!userId) return;
    const { data } = await supabase
      .from('connected_wallets')
      .select('*')
      .eq('user_id', userId)
      .eq('is_active', true)
      .order('created_at', { ascending: true });
    if (data) setWallets(data);
  }, [userId]);

  const loadWalletMovements = useCallback(async (walletId) => {
    const { data } = await supabase
      .from('wallet_movements')
      .select('*')
      .eq('wallet_id', walletId)
      .order('date', { ascending: false })
      .limit(100);
    if (data) setWalletMovements(data);
  }, []);

  const connectWallet = async () => {
    if (!walletConnectProv) return;
    setWalletConnectLoading(true);
    const provDef = WALLET_PROVIDERS[walletConnectProv];
    const insertName = walletConnectName.trim() || provDef.name;
    const meta = { ...walletConnectCreds };
    const accessToken = walletConnectCreds.access_token || null;
    // Remove access_token from metadata to avoid double storage
    delete meta.access_token;
    const { data, error } = await supabase.from('connected_wallets').insert({
      user_id: userId,
      provider: walletConnectProv,
      name: insertName,
      access_token: accessToken,
      metadata: meta,
      currency: walletConnectCreds.currency || currency,
      balance: 0,
    }).select().single();
    setWalletConnectLoading(false);
    if (error) { toast(error.message, 'error'); return; }
    setWallets(prev => [...prev, data]);
    setShowWalletConnect(false);
    setWalletConnectStep(1);
    setWalletConnectCreds({});
    setWalletConnectProv(null);
    setWalletConnectName('');
    toast(`${insertName} conectado ✓`, 'success');
    haptic(20);
  };

  const syncWallet = async (wallet) => {
    setSyncingWalletId(wallet.id);
    try {
      const adapter = createWalletAdapter(wallet.provider, { wallet_id: wallet.id });
      if (!adapter) { toast('Proveedor no soportado aún', 'info'); setSyncingWalletId(null); return; }
      let newBalance = wallet.balance;
      try { const bal = await adapter.getBalance(); if (bal !== null) newBalance = bal.available ?? bal.total ?? 0; } catch {}
      let movements = [];
      try { movements = await adapter.getTransactions(50); } catch {}
      if (movements.length > 0) {
        const rows = movements.map(m => ({
          wallet_id: wallet.id, user_id: userId, external_id: m.external_id,
          amount: m.amount, type: m.type, description: m.description,
          date: m.date, currency: m.currency, status: m.status, metadata: m.raw ?? {},
        }));
        await supabase.from('wallet_movements').upsert(rows, { onConflict: 'wallet_id,external_id', ignoreDuplicates: false });
      }
      const { data: updated } = await supabase.from('connected_wallets')
        .update({ balance: newBalance, last_sync: new Date().toISOString() })
        .eq('id', wallet.id).select().single();
      if (updated) setWallets(prev => prev.map(w => w.id === wallet.id ? updated : w));
      if (selectedWallet?.id === wallet.id) loadWalletMovements(wallet.id);
      toast('Sincronizado ✓', 'success');
    } catch (e) {
      toast('Error al sincronizar: ' + e.message, 'error');
    }
    setSyncingWalletId(null);
  };

  const disconnectWallet = async (walletId) => {
    await supabase.from('connected_wallets').update({ is_active: false }).eq('id', walletId);
    setWallets(prev => prev.filter(w => w.id !== walletId));
    if (selectedWallet?.id === walletId) setSelectedWallet(null);
    toast('Billetera desconectada', 'info');
    haptic(10);
  };

  const saveWalletBalance = async (wallet) => {
    const n = parseFormattedNumber(editBalanceVal);
    const { data } = await supabase.from('connected_wallets')
      .update({ balance: n, last_sync: new Date().toISOString() })
      .eq('id', wallet.id).select().single();
    if (data) setWallets(prev => prev.map(w => w.id === wallet.id ? data : w));
    setEditingWalletBalance(null);
    setEditBalanceVal('');
    toast('Saldo actualizado', 'success');
  };

  const importWalletMovement = async (movement, walletId) => {
    const d = new Date(movement.date || new Date());
    const { data, error } = await supabase.from('transactions').insert({
      user_id: userId,
      amount: movement.amount,
      type: movement.type,
      category: movement.type === 'GASTO' ? (activeCategories.GASTO?.[0] || 'Otros') : (activeCategories.INGRESO?.[0] || 'Sueldo'),
      note: movement.description,
      date: d.toISOString(),
      period_year: d.getFullYear(),
      period_month: d.getMonth(),
      currency_original: movement.currency !== currency ? movement.currency : null,
      fx_rate_to_base: 1,
      fx_source: 'WALLET',
      fx_status: 'FINAL',
    }).select().single();
    if (error) { toast(error.message, 'error'); return; }
    await supabase.from('wallet_movements').update({ synced_tx_id: data.id, status: 'synced' })
      .eq('wallet_id', walletId).eq('external_id', movement.external_id);
    loadTransactions();
    loadWalletMovements(walletId);
    toast('Importado ✓', 'success');
    haptic(15);
  };

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
    // Check if onboarding needed (first time user)
    if (!localStorage.getItem(ONBOARDING_KEY)) {
      setShowOnboarding(true);
      setOnboardingStep(1);
    }
  }, [loadTransactions, loadBudgets, loadStrategy, loadCategories, loadBills, autoGenerateRecurring, userId]);

  useEffect(() => { if (userId) { loadAll(); loadWallets(); } }, [userId, loadAll, loadWallets]);

  // ── Aplicar tema al document ──
  useEffect(() => {
    const applyTheme = (mode) => {
      document.documentElement.classList.remove('light-theme', 'dark-theme');
      document.documentElement.classList.add(mode === 'light' ? 'light-theme' : 'dark-theme');
    };
    if (appTheme === 'auto') {
      const mq = window.matchMedia('(prefers-color-scheme: light)');
      applyTheme(mq.matches ? 'light' : 'dark');
      const handler = (e) => applyTheme(e.matches ? 'light' : 'dark');
      mq.addEventListener('change', handler);
      return () => mq.removeEventListener('change', handler);
    } else {
      applyTheme(appTheme);
    }
  }, [appTheme]);

  // Auto-seleccionar primera cuenta PERSONAL en Budget tab para que el usuario inicie en modo editable
  useEffect(() => {
    if (accounts.length > 0 && budgetAccount === '') {
      const firstPersonal = accounts.find(a => (accountTypes[a] || 'personal') === 'personal');
      if (firstPersonal) setBudgetAccount(firstPersonal);
    }
  }, [accounts, accountTypes]);

  // ── Sincronizar cuentas y configuración hogar a la nube ──
  const syncAccountsRef = useRef(false);
  useEffect(() => {
    if (!userId || !syncAccountsRef.current) { syncAccountsRef.current = true; return; }
    const cats = customCats || INITIAL_CATEGORIES;
    const payload = { ...cats, meta: catMeta, goals, cuotas, debts, subcategories,
      accounts, accountTypes, allocations, savingsInvestAccount };
    supabase.from('categories').upsert({ user_id: userId, data: payload }, { onConflict: 'user_id' });
  }, [accounts, accountTypes, allocations, savingsInvestAccount]);

  // ── Mercado Pago OAuth callback detector ──────────────────────────────────
  // Runs once on mount; if ?code= found in URL, stores it and triggers exchange
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const code  = params.get('code');
    const state = params.get('state');
    if (!code || !state) return;
    // Clean the URL immediately so the code isn't reused
    window.history.replaceState({}, document.title, window.location.pathname);
    const storedState = sessionStorage.getItem('mp_oauth_state');
    if (state !== storedState) return; // CSRF guard
    sessionStorage.removeItem('mp_oauth_state');
    sessionStorage.setItem('mp_oauth_pending_code', code);
  }, []);

  // ── Process pending OAuth once userId is available ────────────────────────
  useEffect(() => {
    if (!userId) return;
    const code = sessionStorage.getItem('mp_oauth_pending_code');
    if (!code) return;
    sessionStorage.removeItem('mp_oauth_pending_code');
    handleMPOAuthCallback(code);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId]);

  const handleMPOAuthCallback = async (code) => {
    setMpOAuthLoading(true);
    try {
      const res = await fetch(WALLET_PROXY, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'apikey': SUPABASE_ANON_KEY },
        body: JSON.stringify({
          action:       'oauth_exchange',
          provider:     'mercadopago',
          code,
          redirect_uri: MP_OAUTH_REDIRECT,
        }),
      });
      const tokenData = await res.json();
      if (!tokenData.access_token) throw new Error(tokenData.message || 'No se pudo obtener el token de Mercado Pago');

      const walletName = tokenData.display_name || 'Mercado Pago';
      const { data, error } = await supabase.from('connected_wallets').insert({
        user_id:      userId,
        provider:     'mercadopago',
        name:         walletName,
        access_token: tokenData.access_token,
        metadata: {
          refresh_token: tokenData.refresh_token || null,
          token_type:    tokenData.token_type    || 'bearer',
          mp_user_id:    tokenData.user_id       || null,
          scope:         tokenData.scope         || null,
          oauth:         true,
        },
        currency: currency,
        balance:  0,
      }).select().single();

      if (error) throw new Error(error.message);
      setWallets(prev => [...prev, data]);
      setActiveTab('wallets');
      toast(`${walletName} conectado con OAuth ✓`, 'success');
      haptic(20);
    } catch (e) {
      toast('Error al conectar Mercado Pago: ' + e.message, 'error');
    }
    setMpOAuthLoading(false);
  };

  const startMPOAuth = () => {
    if (!MP_OAUTH_CLIENT_ID || MP_OAUTH_CLIENT_ID === 'REEMPLAZAR_CON_TU_APP_ID') {
      toast('Configurá el App ID de Mercado Pago en el código', 'error');
      return;
    }
    const state = Math.random().toString(36).slice(2) + Date.now().toString(36);
    sessionStorage.setItem('mp_oauth_state', state);
    const oauthUrl = new URL('https://auth.mercadopago.com/authorization');
    oauthUrl.searchParams.set('client_id',     MP_OAUTH_CLIENT_ID);
    oauthUrl.searchParams.set('response_type', 'code');
    oauthUrl.searchParams.set('platform_id',   'mp');
    oauthUrl.searchParams.set('state',         state);
    oauthUrl.searchParams.set('redirect_uri',  MP_OAUTH_REDIRECT);
    window.location.href = oauthUrl.toString();
  };

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

  // ── Cargar estados "pagado/abonado" del localStorage al cambiar período ──
  useEffect(() => {
    const p = `${budgetPeriod.year}-${String(budgetPeriod.month+1).padStart(2,'0')}`;
    try { setPaidItems(JSON.parse(localStorage.getItem(`metacasa_paid_${p}`)||'{}')); }         catch { setPaidItems({}); }
    try { setPaidBillsInPeriod(JSON.parse(localStorage.getItem(`metacasa_billspaid_${p}`)||'{}')); }  catch { setPaidBillsInPeriod({}); }
    try { setPaidCuotasInPeriod(JSON.parse(localStorage.getItem(`metacasa_cuotaspaid_${p}`)||'{}')); } catch { setPaidCuotasInPeriod({}); }
  }, [budgetPeriod]);

  // ── Auto-replicación de gastos/ingresos fijos ──
  useEffect(() => {
    if (!userId || !transactions.length) return;
    const y = currentDate.getFullYear();
    const m = currentDate.getMonth();
    const sessionKey = `${y}-${m}`;
    if (autoReplicatedRef.current.has(sessionKey)) return;
    autoReplicatedRef.current.add(sessionKey);

    const templates = JSON.parse(localStorage.getItem(FIXED_TX_KEY) || '[]');
    if (!templates.length) return;

    const monthTxs = transactions.filter(t => {
      const p = txBudgetPeriod(t);
      return p.year === y && p.month === m;
    });

    const missing = templates.filter(tpl =>
      !monthTxs.some(t =>
        t.category === tpl.category &&
        t.type === tpl.type &&
        Number(t.amount) === tpl.amount
      )
    );
    if (!missing.length) return;

    (async () => {
      for (const tpl of missing) {
        const maxDay = new Date(y, m + 1, 0).getDate();
        const day = Math.min(tpl.dayOfMonth || 1, maxDay);
        await supabase.from('transactions').insert({
          user_id: userId,
          category: tpl.category,
          type: tpl.type,
          amount: tpl.amount,
          note: (tpl.note || tpl.category) + ' (fijo)',
          date: new Date(y, m, day, 12).toISOString(),
          account: tpl.account || null,
        });
      }
      await loadTransactions();
      toast(
        `📌 ${missing.length} ${missing.length === 1 ? 'movimiento fijo registrado' : 'movimientos fijos registrados'} automáticamente`,
        'info'
      );
    })();
  }, [userId, currentDate.getFullYear(), currentDate.getMonth(), transactions.length]);

  // ── STATS ──
  const stats = useMemo(() => {
    const m = currentDate.getMonth(), y = currentDate.getFullYear();
    const cur = transactions.filter(t => { const p = txBudgetPeriod(t); return p.month===m && p.year===y; });
    const income   = cur.filter(t => t.type==='INGRESO').reduce((a,c) => a+Number(c.amount),0);
    const expenses = cur.filter(t => t.type==='GASTO').reduce((a,c) => a+Number(c.amount),0);
    const expenseByCategory = {};
    cur.filter(t => t.type==='GASTO').forEach(t => { expenseByCategory[t.category]=(expenseByCategory[t.category]||0)+Number(t.amount); });
    const savingsAmount    = (income*(strategy.savingsPercent||0))/100;
    const investmentAmount = (income*(strategy.investmentPercent||0))/100;
    const totalHistoricalIncome    = transactions.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
    const historicalSavingsTotal   = (totalHistoricalIncome*(strategy.savingsPercent||0))/100;
    const historicalInvestmentTotal= (totalHistoricalIncome*(strategy.investmentPercent||0))/100;
    const totalBudgetsAssigned = Object.entries(budgets)
      .filter(([k]) => { const p = k.split('|'); return p[0] === '' && p[2] === ''; })
      .reduce((a, [, b]) => a + Number(b.amount || 0), 0);
    const available = income - savingsAmount - investmentAmount - expenses;
    const availableToAssign = income - savingsAmount - investmentAmount - totalBudgetsAssigned;
    return { income, expenses, available, expenseByCategory, savingsAmount, investmentAmount,
             totalBudgetsAssigned, availableToAssign, historicalSavingsTotal, historicalInvestmentTotal };
  }, [transactions, currentDate, strategy, budgets]);

  // ── HOME STATS (filtrado por cuenta seleccionada) ──
  const homeStats = useMemo(() => {
    if (!homeAccount) return stats;
    const m = currentDate.getMonth(), y = currentDate.getFullYear();
    const cur = transactions.filter(t => {
      const p = txBudgetPeriod(t);
      return p.month === m && p.year === y && t.account === homeAccount;
    });
    const income   = cur.filter(t => t.type === 'INGRESO').reduce((a, c) => a + Number(c.amount), 0);
    const expenses = cur.filter(t => t.type === 'GASTO').reduce((a, c) => a + Number(c.amount), 0);
    const expenseByCategory = {};
    cur.filter(t => t.type === 'GASTO').forEach(t => {
      expenseByCategory[t.category] = (expenseByCategory[t.category] || 0) + Number(t.amount);
    });
    const savingsAmount    = (income * (strategy.savingsPercent    || 0)) / 100;
    const investmentAmount = (income * (strategy.investmentPercent || 0)) / 100;
    const available        = income - savingsAmount - investmentAmount - expenses;
    return {
      ...stats,
      income, expenses, available, expenseByCategory, savingsAmount, investmentAmount,
      availableToAssign: income - savingsAmount - investmentAmount - stats.totalBudgetsAssigned,
    };
  }, [homeAccount, transactions, currentDate, strategy, stats]);

  // ── STATS DEL MES SELECCIONADO EN TAB ESTADÍSTICAS ──
  const statsData = useMemo(() => {
    const m = statsDate.month, y = statsDate.year;
    const all = transactions.filter(t => { const p = txBudgetPeriod(t); return p.month===m && p.year===y; });
    // Filtrar por cuenta seleccionada en Estadísticas (statsAccount)
    const cur = statsAccount ? all.filter(t => t.account === statsAccount) : all;
    const income   = cur.filter(t => t.type==='INGRESO').reduce((a,c) => a+Number(c.amount),0);
    const expenses = cur.filter(t => t.type==='GASTO').reduce((a,c) => a+Number(c.amount),0);
    const expenseByCategory = {};
    cur.filter(t => t.type==='GASTO').forEach(t => {
      expenseByCategory[t.category]=(expenseByCategory[t.category]||0)+Number(t.amount);
    });
    // Desglose por cuenta (siempre del total del mes, para el widget byAccount)
    const byAccount = {};
    all.forEach(t => {
      const acct = t.account || 'Sin cuenta';
      if (!byAccount[acct]) byAccount[acct] = { income: 0, expense: 0 };
      if (t.type === 'INGRESO') byAccount[acct].income += Number(t.amount);
      else byAccount[acct].expense += Number(t.amount);
    });
    // Desglose por subcategoría (por categoría)
    const bySubcategory = {};
    cur.filter(t => t.subcategory && t.type==='GASTO').forEach(t => {
      if (!bySubcategory[t.category]) bySubcategory[t.category] = {};
      bySubcategory[t.category][t.subcategory] = (bySubcategory[t.category][t.subcategory]||0) + Number(t.amount);
    });
    return { income, expenses, expenseByCategory, byAccount, bySubcategory, txs: cur };
  }, [transactions, statsDate, statsAccount]);

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
      const p = txBudgetPeriod(t);
      return p.month===prev.getMonth() && p.year===prev.getFullYear();
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
      .reduce((a, c) => {
        const cuotaCurr = c.currency || currency;
        const rate = cuotaCurr !== currency ? (exchangeRates[cuotaCurr] || 1) : 1;
        return a + (c.monthlyAmount * rate);
      }, 0);
  }, [cuotas, currency, exchangeRates]);

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
  // forCurrency: la moneda EXTRANJERA (no la base) para la que se configura el rate
  // rate: cuántas unidades de moneda base (currency) vale 1 unidad de forCurrency
  const updateExchangeRate = (forCurrency, val) => {
    const n = parseFloat(String(val).replace(/[^0-9.]/g, '')) || 0;
    const updated = { ...exchangeRates, [forCurrency]: n };
    setExchangeRates(updated);
    localStorage.setItem('metacasa_fx_rates', JSON.stringify(updated));
    // Compatibilidad con key legacy para USD
    if (forCurrency === 'USD') localStorage.setItem('metacasa_usd_rate', String(n));
  };

  // ── SYNC EXTRAS → SUPABASE (goals / cuotas / debts en el blob de categories) ──
  const syncExtrasToCloud = useCallback(async (newGoals, newCuotas, newDebts) => {
    if (!userId) return;
    const cats = customCats || INITIAL_CATEGORIES;
    const payload = { ...cats, meta: catMeta, goals: newGoals, cuotas: newCuotas, debts: newDebts, subcategories,
      accounts, accountTypes, allocations, savingsInvestAccount };
    const { error } = await supabase.from('categories').upsert(
      { user_id: userId, data: payload }, { onConflict: 'user_id' }
    );
    if (error) console.error('syncExtrasToCloud error:', error);
  }, [userId, customCats, catMeta, subcategories, accounts, accountTypes, allocations, savingsInvestAccount]);

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

  // ── VOZ DICTADO HELPERS (Home FAB) ──
  const parseVoiceType = (text) => {
    const lower = text.toLowerCase();
    return ['cobré','ingresé','recibí','gané','sueldo','salario','ingreso']
      .some(k => lower.includes(k)) ? 'INGRESO' : 'GASTO';
  };

  const parseVoiceCategory = useCallback((text, type) => {
    const lower = text.toLowerCase();
    for (const [cat, kws] of Object.entries(CATEGORY_KEYWORDS)) {
      if (kws.some(k => lower.includes(k))) return cat;
    }
    return activeCategories[type]?.[0] || '';
  }, [activeCategories]);

  const parseVoiceDate = (text) => {
    const today = new Date();
    const lower = text.toLowerCase();
    if (lower.includes('ayer')) {
      const d = new Date(today);
      d.setDate(d.getDate() - 1);
      return d.toISOString().slice(0, 10);
    }
    const days = ['domingo','lunes','martes','miércoles','jueves','viernes','sábado'];
    for (let i = 0; i < days.length; i++) {
      if (lower.includes(days[i])) {
        const d = new Date(today);
        const diff = (today.getDay() - i + 7) % 7 || 7;
        d.setDate(d.getDate() - diff);
        return d.toISOString().slice(0, 10);
      }
    }
    return today.toISOString().slice(0, 10);
  };

  const startHomeDictado = useCallback(() => {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SR) { toast('Tu dispositivo no soporta dictado', 'error'); return; }
    setVoiceTranscript('');
    setVoiceInterim('');
    const rec = new SR();
    homeRecRef.current = rec;
    rec.lang = 'es-AR';
    rec.continuous = true;
    rec.interimResults = true;
    rec.onstart = () => setIsDictandoHome(true);
    rec.onend   = () => setIsDictandoHome(false);
    rec.onerror = (e) => {
      setIsDictandoHome(false);
      if (e.error === 'not-allowed') {
        toast('Permiso de micrófono denegado. Habilitalo en Configuración > Safari/Chrome > Micrófono', 'error');
      } else if (e.error !== 'aborted') {
        toast('Error de voz: ' + e.error, 'error');
      }
    };
    rec.onresult = (e) => {
      let interim = '', finalText = '';
      for (let i = e.resultIndex; i < e.results.length; i++) {
        if (e.results[i].isFinal) finalText += e.results[i][0].transcript + ' ';
        else interim += e.results[i][0].transcript;
      }
      setVoiceInterim(interim);
      if (finalText) {
        setVoiceTranscript(prev => {
          const full = (prev + finalText).trim();
          const type = parseVoiceType(full);
          const amount = String(parseVoiceAmount(full) || '');
          const category = parseVoiceCategory(full, type);
          const date = parseVoiceDate(full);
          setVoiceDraft({ type, amount, category, note: full, date });
          return full;
        });
      }
    };
    rec.start();
  }, [toast, parseVoiceCategory]);

  const stopHomeDictado = useCallback(() => {
    homeRecRef.current?.stop();
    setIsDictandoHome(false);
  }, []);

  const saveVoiceDraft = useCallback(async () => {
    if (!userId || !voiceDraft.amount || !voiceDraft.category) return;
    setVoiceDraftSaving(true);
    const payload = {
      user_id: userId,
      amount: parseInt(voiceDraft.amount),
      category: voiceDraft.category,
      type: voiceDraft.type,
      note: voiceDraft.note,
      date: new Date(voiceDraft.date + 'T12:00:00').toISOString(),
    };
    const { error } = await supabase.from('transactions').insert(payload);
    setVoiceDraftSaving(false);
    if (error) { toast(error.message, 'error'); return; }
    setShowVoiceDictado(false);
    stopHomeDictado();
    setVoiceTranscript('');
    setVoiceDraft({
      type: 'GASTO', amount: '', category: '', note: '',
      date: new Date().toISOString().slice(0, 10),
    });
    await loadTransactions();
    haptic(20);
    toast(
      `Listo ✅ ${voiceDraft.type === 'GASTO' ? 'Gasto' : 'Ingreso'} de $${formatNumber(parseInt(voiceDraft.amount))} cargado`,
      'success'
    );
  }, [userId, voiceDraft, stopHomeDictado, loadTransactions, toast, haptic, formatNumber]);

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
  const payCuota = async (id) => {
    const cuota = cuotas.find(c => c.id === id);
    if (!cuota) return;
    // Update cuota progress
    persistCuotas(cuotas.map(c => c.id===id
      ? { ...c, paidCuotas: Math.min(c.paidCuotas+1, c.totalCuotas) }
      : c
    ));
    haptic(15);
    // Create real transaction in Supabase
    if (userId) {
      const cuotaCurr = cuota.currency || currency;
      const amt = Math.round(cuota.monthlyAmount * 100) / 100;
      let amountInBase = amt;
      let fxRateUsed = 1, fxSource = 'MANUAL', fxStatus = 'FINAL';
      if (cuotaCurr !== currency) {
        const manualRate = exchangeRates[cuotaCurr] || 0;
        const todayStr = new Date().toISOString().slice(0,10);
        const fx = await fxGetRate(cuotaCurr, todayStr, manualRate);
        fxRateUsed = fx.rate; fxSource = fx.source; fxStatus = fx.status;
        amountInBase = fxRateUsed > 0 ? Math.round(amt * fxRateUsed) : amt;
      }
      const paidNum = cuota.paidCuotas + 1;
      const payload = {
        user_id: userId,
        amount: Math.round(amountInBase),
        category: cuota.category || 'Cuotas',
        type: 'GASTO',
        note: `${cuota.emoji} ${cuota.name} (${paidNum}/${cuota.totalCuotas})`,
        date: new Date().toISOString(),
        account: cuota.account || null,
        subcategory: cuota.subcategory || null,
        amount_original: cuotaCurr !== currency ? amt : null,
        currency_original: cuotaCurr,
        fx_rate_to_base: fxRateUsed,
        fx_source: fxSource,
        fx_status: fxStatus,
      };
      const { error } = await supabase.from('transactions').insert(payload);
      if (!error) {
        await loadTransactions();
        toast(`Cuota ${paidNum}/${cuota.totalCuotas} de ${cuota.name} registrada`, 'success');
      }
    }
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

  // Helper: suma presupuestos de una categoría a través de todas las cuentas
  const getAggregatedBudget = (cat, subcat = '') => {
    return accounts.reduce((sum, acc) => {
      const key = `${acc}|${cat}|${subcat}`;
      return sum + (budgets[key]?.amount || 0);
    }, 0);
  };

  // Waterfall: cuentas personales vs compartidas
  const personalAccounts = accounts.filter(a => (accountTypes[a] || 'personal') === 'personal');
  const sharedAccounts   = accounts.filter(a => accountTypes[a] === 'compartida');

  // ── INSIGHTS DINÁMICOS ──
  const insights = useMemo(() => {
    if (stats.income === 0 && stats.expenses === 0) return [];
    const result = [];

    // 1. Tendencia de la categoría principal vs mes anterior
    const topCat = Object.entries(stats.expenseByCategory).sort((a,b)=>b[1]-a[1])[0];
    if (topCat && prevMonth.expense > 0) {
      const prev = new Date(currentDate.getFullYear(), currentDate.getMonth()-1, 1);
      const prevSpent = transactions
        .filter(t => { const p = txBudgetPeriod(t); return p.month===prev.getMonth() && p.year===prev.getFullYear() && t.category===topCat[0] && t.type==='GASTO'; })
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
      const limit = getAggregatedBudget(cat);
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
  const [dupWarning, setDupWarning] = useState(null); // { amount, category }
  const handleSaveTransaction = async (skipDupCheck = false) => {
    if (!userId || !amount || !category) return;
    setSavingTx(true);
    const numericAmount = parseFormattedNumber(amount);

    // Bloqueo de posible duplicado (mismo monto + categoría en las últimas 2 horas)
    const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString();
    const recentDup = transactions.find(t =>
      t.type === type &&
      Number(t.amount) === numericAmount &&
      t.category === category &&
      t.date > twoHoursAgo
    );
    if (recentDup && !skipDupCheck) {
      setSavingTx(false);
      setDupWarning({ amount: numericAmount, category });
      return;
    }
    setDupWarning(null);
    // Guardar la fecha real; si el período asignado difiere, almacenar en period_year/period_month
    const txDateObj = new Date(txDate + 'T12:00:00');
    const realDate = new Date(txDate + 'T12:00:00').toISOString();
    const periodDiffers = mesAsignado.year !== txDateObj.getFullYear() || mesAsignado.month !== txDateObj.getMonth();
    // Multi-currency: calcular amount_in_base (moneda base del usuario)
    let amountInBase = numericAmount;
    let fxRateUsed   = 1;
    let fxSource     = 'MANUAL';
    let fxStatus     = 'FINAL';
    if (txCurrency !== currency) {
      // La transacción está en una moneda distinta a la base → convertir
      const manualRate = exchangeRates[txCurrency] || 0;
      const fx = await fxGetRate(txCurrency, txDate, manualRate);
      fxRateUsed  = fx.rate;
      fxSource    = fx.source;
      fxStatus    = fx.status;
      amountInBase = fxRateUsed > 0 ? Math.round(numericAmount * fxRateUsed) : numericAmount;
    }

    const payload = {
      user_id: userId,
      amount: amountInBase,          // siempre en ARS (base)
      category, type, note: note.trim(),
      date: realDate,
      period_year:  periodDiffers ? mesAsignado.year  : null,
      period_month: periodDiffers ? mesAsignado.month : null,
      account:      txAccount    || null,
      subcategory:  txSubcategory || null,
      // Multi-currency fields
      amount_original:  txCurrency !== currency ? numericAmount : null,
      currency_original: txCurrency,
      fx_rate_to_base:  fxRateUsed,
      fx_source:        fxSource,
      fx_status:        fxStatus,
    };
    const { error } = await supabase.from('transactions').insert(payload);
    setSavingTx(false);
    if (error) { toast(error.message, 'error'); return; }

    // ── Alerta de presupuesto ──
    if (type === 'GASTO') {
      const budgetKey = `${txAccount || ''}|${category}|`;
      const limit = budgets[budgetKey]?.amount || getAggregatedBudget(category);
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

    // ── Gasto / Ingreso fijo: guardar template ──
    if (isFixed) {
      const templates = JSON.parse(localStorage.getItem(FIXED_TX_KEY) || '[]');
      const existIdx = templates.findIndex(t => t.category === category && t.type === type);
      const tpl = {
        id: existIdx >= 0 ? templates[existIdx].id : Date.now(),
        category, type,
        amount: numericAmount,
        note: note.trim(),
        dayOfMonth: new Date(txDate + 'T12:00:00').getDate(),
        account: txAccount || '',
      };
      if (existIdx >= 0) templates[existIdx] = tpl; else templates.push(tpl);
      localStorage.setItem(FIXED_TX_KEY, JSON.stringify(templates));
      setFixedTxs(templates);
      setIsFixed(false);
    }

    setAmount(''); setNote(''); setTxAccount(''); setTxSubcategory(''); setTxCurrency('ARS');
    setMesAsignado({ year: new Date().getFullYear(), month: new Date().getMonth() });
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
    const { error } = await supabase.from('strategy').upsert({
      user_id:           userId,
      savings_percent:   Number(ns.savingsPercent    || 0),
      investment_percent:Number(ns.investmentPercent || 0),
      use_global:        true,
    }, { onConflict: 'user_id' });
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

  const [undoableTx, setUndoableTx] = useState(null); // { id, tx, timer }
  const deleteTransaction = async (id) => {
    if (!userId) return;
    // Optimistic: remove from local state first, allow undo for 5 seconds
    const txToDelete = transactions.find(t => t.id === id);
    if (!txToDelete) return;
    setTransactions(prev => prev.filter(t => t.id !== id));
    if (editingTx) setEditingTx(null);
    // Clear any previous pending undo
    if (undoableTx?.timer) clearTimeout(undoableTx.timer);
    const timer = setTimeout(async () => {
      await supabase.from('transactions').delete().eq('id', id);
      setUndoableTx(null);
    }, 5000);
    setUndoableTx({ id, tx: txToDelete, timer });
    toast('Eliminado · Toca deshacer abajo', 'info');
  };
  const undoDeleteTransaction = () => {
    if (!undoableTx) return;
    clearTimeout(undoableTx.timer);
    setTransactions(prev => [...prev, undoableTx.tx].sort((a,b) => b.date?.localeCompare(a.date)));
    setUndoableTx(null);
    toast('Movimiento restaurado ✓', 'success');
  };

  // ── PRESUPUESTO: GASTOS FIJOS edit/delete ──
  const deleteFixedTx = (id) => {
    const updated = fixedTxs.filter(t => t.id !== id);
    localStorage.setItem(FIXED_TX_KEY, JSON.stringify(updated));
    setFixedTxs(updated);
    haptic(10);
    toast('Gasto fijo eliminado', 'info');
  };

  const openFixedTxEdit = (f) => {
    const now = new Date();
    const maxDay = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
    const day = Math.min(f.dayOfMonth || 1, maxDay);
    const d = new Date(now.getFullYear(), now.getMonth(), day);
    setType(f.type);
    setAmount(formatNumber(f.amount));
    setCategory(f.category);
    setNote(f.note || '');
    setIsFixed(true);
    setTxDate(d.toISOString().slice(0, 10));
    setTxAccount(f.account || '');
    setActiveTab('add');
    setEditingFixedTx(null);
    haptic(12);
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
    else if (action==='DELETE') {
      const txCount = transactions.filter(t => t.category === clean).length;
      if (txCount > 0 && !extra?.__confirmed) {
        const ok = window.confirm(`"${clean}" tiene ${txCount} movimiento(s). Si la eliminás, esos movimientos quedarán sin categoría válida.\n\n¿Eliminar de todas formas?`);
        if (!ok) return;
      }
      nc[type]=nc[type].filter(c=>c!==clean);
    }
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

  // ── SUBCATEGORÍAS CRUD ──
  const saveSubcategories = (updated) => {
    setSubcategories(updated);
    localStorage.setItem('metacasa_subcats', JSON.stringify(updated));
    // Mirror for Add form quick access
    const catData = JSON.parse(localStorage.getItem('metacasa_categories') || '{}');
    catData.subcategories = updated;
    localStorage.setItem('metacasa_categories', JSON.stringify(catData));
    // Sync to cloud — include all shared data to avoid overwriting
    if (userId) {
      const cats = customCats || INITIAL_CATEGORIES;
      const payload = { ...cats, meta: catMeta, goals, cuotas, debts, subcategories: updated,
        accounts, accountTypes, allocations, savingsInvestAccount };
      supabase.from('categories').upsert({ user_id: userId, data: payload }, { onConflict: 'user_id' });
    }
  };
  const addSubcategory = (catName, subcatName) => {
    const name = subcatName.trim();
    if (!name) return;
    const cur = subcategories[catName] || [];
    if (cur.includes(name)) { toast('Ya existe esa subcategoría', 'info'); return; }
    const updated = { ...subcategories, [catName]: [...cur, name] };
    saveSubcategories(updated);
    setNewSubcatInput('');
    toast('Subcategoría agregada ✓', 'success'); haptic(10);
  };
  const deleteSubcategory = (catName, subcatName) => {
    const updated = { ...subcategories, [catName]: (subcategories[catName] || []).filter(s => s !== subcatName) };
    if (updated[catName].length === 0) delete updated[catName];
    saveSubcategories(updated);
    toast('Subcategoría eliminada', 'info'); haptic(10);
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

  const updateBudget = async (account, cat, subcat, val) => {
    if (!userId) return;
    // Advertencia si excede disponible de la cuenta (waterfall)
    if (account && !subcat) {
      const isShared = accountTypes[account] === 'compartida';
      const base = isShared
        ? waterfallData.remainder
        : (waterfallData.effectiveAllocations[account] || 0);

      const otherBudgets = activeCategories.GASTO.filter(c => c !== cat).reduce((acc, c) => {
        const raw  = budgets[`${account}|${c}|`]?.amount || 0;
        return acc + raw;
      }, 0);
      const newDisponible = base - otherBudgets - Number(val || 0);
      if (newDisponible < 0 && base > 0) {
        toast(`⚠ Excede el ${isShared ? 'presupuesto compartido' : 'presupuesto de ' + account} en ${currSymbol}${formatNumber(-newDisponible)}`, 'info');
      }
    }
    const { error } = await supabase.from('budgets').upsert(
      { user_id: userId, account: account || '', category: cat, subcategory: subcat || '', amount: Number(val||0) },
      { onConflict: 'user_id,account,category,subcategory' }
    );
    if (error) { toast(error.message, 'error'); return; }
    await loadBudgets();
  };

  const suggestBudgets = async () => {
    if (!userId) return;
    if (!budgetAccount) { toast('Seleccioná una cuenta para sugerir presupuestos', 'info'); return; }
    const now = new Date();
    const rows = [];
    activeCategories.GASTO.forEach(cat => {
      const amounts = [];
      for (let i = 1; i <= 3; i++) {
        const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
        const y = d.getFullYear(), m = d.getMonth();
        const total = transactions
          .filter(t => {
            const p = txBudgetPeriod(t);
            const matchAcc = !budgetAccount || t.account === budgetAccount;
            return t.type === 'GASTO' && t.category === cat && p.year === y && p.month === m && matchAcc;
          })
          .reduce((a, c) => a + Number(c.amount), 0);
        if (total > 0) amounts.push(total);
      }
      if (amounts.length > 0) {
        const avg = amounts.reduce((a, b) => a + b, 0) / amounts.length;
        rows.push({
          user_id: userId,
          account: budgetAccount || '',
          category: cat,
          subcategory: '',
          amount: Math.round(avg * 1.05),
        });
      }
    });
    if (rows.length === 0) { toast('Sin historial para sugerir presupuestos', 'info'); return; }
    const { error } = await supabase.from('budgets').upsert(rows, { onConflict: 'user_id,account,category,subcategory' });
    if (error) { toast(error.message, 'error'); return; }
    await loadBudgets();
    const acctLabel = budgetAccount || 'todas las cuentas';
    toast(`✓ Sugerencias aplicadas para ${rows.length} categorías (${acctLabel}, +5% buffer)`, 'success');
    haptic(20);
  };

  // ── Marcar/desmarcar ítem fijo como "Pagado" para el período ──
  // Si no existe transacción real: la crea en Supabase. Si se desmarca: la elimina.
  // Clave localStorage para el ID de la tx auto-creada: metacasa_paid_txid_YYYY-MM_templateId
  const togglePaidItem = async (f) => {
    if (!userId) return;
    const periodStr  = `${budgetPeriod.year}-${String(budgetPeriod.month+1).padStart(2,'0')}`;
    const stateKey   = `metacasa_paid_${periodStr}`;
    const txIdKey    = `metacasa_paid_txid_${periodStr}_${f.id}`;
    const isPaid     = !!paidItems[f.id];

    if (!isPaid) {
      // Marcando como pagado: crear transacción si no existe ya (auto-replicación puede haberla creado)
      const alreadyHasTx = budgetPeriodTxs.some(t =>
        t.category === f.category &&
        t.type     === f.type     &&
        Math.abs(Number(t.amount) - f.amount) < 1
      );
      if (!alreadyHasTx) {
        const txDate = new Date(budgetPeriod.year, budgetPeriod.month, f.dayOfMonth || 1);
        const { data, error } = await supabase
          .from('transactions')
          .insert({
            user_id:  userId,
            category: f.category,
            type:     f.type,
            amount:   f.amount,
            note:     `[Fijo] ${f.note || f.category}`,
            date:     txDate.toISOString(),
            account:  f.account || null,
          })
          .select('id')
          .single();
        if (error) { toast(error.message, 'error'); return; }
        // Guardar el ID para poder eliminarlo si se desmarca
        localStorage.setItem(txIdKey, data.id);
        await loadTransactions();
      }
      toast(`✓ ${f.category} registrado como pagado`, 'success');
    } else {
      // Desmarcando: eliminar la transacción auto-creada (si la creamos nosotros)
      const autoTxId = localStorage.getItem(txIdKey);
      if (autoTxId) {
        const { error } = await supabase
          .from('transactions')
          .delete()
          .eq('id', autoTxId)
          .eq('user_id', userId);
        if (!error) {
          localStorage.removeItem(txIdKey);
          await loadTransactions();
        }
      }
    }

    // Actualizar estado de "Pagado" en localStorage (persistencia por período)
    setPaidItems(prev => {
      const next = { ...prev, [f.id]: !prev[f.id] };
      localStorage.setItem(stateKey, JSON.stringify(next));
      return next;
    });
    haptic(8);
  };

  // ── Marcar/desmarcar vencimiento o cuota como "Abonado" para el período ──
  // Al abonar: crea transacción en Supabase → reduce disponibleReal.
  // Al desabonar: elimina la tx auto-creada.
  const markPeriodItemPaid = async (item) => {
    if (!userId) return;
    const periodStr = `${budgetPeriod.year}-${String(budgetPeriod.month+1).padStart(2,'0')}`;

    if (item.type === 'bill') {
      const bill = bills.find(b => b.id === item.rawId);
      if (!bill) return;
      const txIdKey  = `metacasa_billtxid_${periodStr}_${item.rawId}`;
      const stateKey = `metacasa_billspaid_${periodStr}`;

      if (!item.isPaid) {
        // Verificar si ya existe una tx real que coincida (evitar duplicado)
        const alreadyHasTx = budgetPeriodTxs.some(t =>
          t.type === 'GASTO' && t.category === bill.category &&
          Math.abs(Number(t.amount) - bill.amount) < 1
        );
        if (!alreadyHasTx) {
          const txDay  = item.isRecurring ? item.dueDay : new Date(bill.due_date).getDate();
          const txDate = new Date(budgetPeriod.year, budgetPeriod.month, txDay || 1);
          const { data, error } = await supabase.from('transactions').insert({
            user_id:  userId,
            category: bill.category,
            type:     'GASTO',
            amount:   bill.amount,
            note:     `[Vencimiento] ${bill.title}`,
            date:     txDate.toISOString(),
          }).select('id').single();
          if (error) { toast(error.message, 'error'); return; }
          localStorage.setItem(txIdKey, data.id);
          await loadTransactions();
        }
        // Para bills one-time: actualizar status en Supabase también
        if (!item.isRecurring) {
          await supabase.from('bills').update({ status: 'paid' }).eq('id', item.rawId).eq('user_id', userId);
          await loadBills();
        } else {
          setPaidBillsInPeriod(prev => {
            const next = { ...prev, [item.rawId]: true };
            localStorage.setItem(stateKey, JSON.stringify(next));
            return next;
          });
        }
        toast(`✓ ${bill.title} marcado como abonado`, 'success');
      } else {
        // Desabonar: eliminar tx auto-creada
        const autoTxId = localStorage.getItem(txIdKey);
        if (autoTxId) {
          await supabase.from('transactions').delete().eq('id', autoTxId).eq('user_id', userId);
          localStorage.removeItem(txIdKey);
          await loadTransactions();
        }
        if (!item.isRecurring) {
          await supabase.from('bills').update({ status: 'pending' }).eq('id', item.rawId).eq('user_id', userId);
          await loadBills();
        } else {
          setPaidBillsInPeriod(prev => {
            const next = { ...prev, [item.rawId]: false };
            localStorage.setItem(stateKey, JSON.stringify(next));
            return next;
          });
        }
      }

    } else if (item.type === 'cuota') {
      const cuota = cuotas.find(c => c.id === item.rawId);
      if (!cuota) return;
      const txIdKey  = `metacasa_cuotatxid_${periodStr}_${item.rawId}`;
      const stateKey = `metacasa_cuotaspaid_${periodStr}`;

      if (!item.isPaid) {
        const alreadyHasTx = budgetPeriodTxs.some(t =>
          t.type === 'GASTO' && Math.abs(Number(t.amount) - cuota.monthlyAmount) < 1
        );
        if (!alreadyHasTx) {
          const txDate = new Date(budgetPeriod.year, budgetPeriod.month, 1);
          const { data, error } = await supabase.from('transactions').insert({
            user_id:  userId,
            category: activeCategories.GASTO[0] || 'Servicios',
            type:     'GASTO',
            amount:   cuota.monthlyAmount,
            note:     `[Cuota ${item.cuotaNum}/${cuota.totalCuotas}] ${cuota.name}`,
            date:     txDate.toISOString(),
          }).select('id').single();
          if (error) { toast(error.message, 'error'); return; }
          localStorage.setItem(txIdKey, data.id);
          await loadTransactions();
        }
        setPaidCuotasInPeriod(prev => {
          const next = { ...prev, [item.rawId]: true };
          localStorage.setItem(stateKey, JSON.stringify(next));
          return next;
        });
        toast(`✓ Cuota ${item.cuotaNum}/${cuota.totalCuotas} de ${cuota.name} abonada`, 'success');
      } else {
        const autoTxId = localStorage.getItem(txIdKey);
        if (autoTxId) {
          await supabase.from('transactions').delete().eq('id', autoTxId).eq('user_id', userId);
          localStorage.removeItem(txIdKey);
          await loadTransactions();
        }
        setPaidCuotasInPeriod(prev => {
          const next = { ...prev, [item.rawId]: false };
          localStorage.setItem(stateKey, JSON.stringify(next));
          return next;
        });
      }
    }
    haptic(8);
  };

  // ── Alternar modo de presupuesto: '$' ↔ '%' por categoría ──
  const cycleBudgetMode = (cat) => {
    setBudgetModes(prev => {
      const next = {...prev, [cat]: (prev[cat]||'$')==='$'?'%':'$'};
      localStorage.setItem(BUDGET_MODE_KEY, JSON.stringify(next));
      return next;
    });
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
  // RENDER: APP
  // ─────────────────────────────────────────────

  // Transacciones del mes actual (usando período asignado si corresponde)
  const monthTxs = transactions.filter(t => {
    const p = txBudgetPeriod(t);
    return p.month===currentDate.getMonth() && p.year===currentDate.getFullYear();
  });

  // ── Transacciones filtradas para Historial ──
  const filteredTxs = useMemo(() => {
    let base;
    if (allMonths) {
      base = transactions;
    } else if (selectedHistoryMonth) {
      if (historyDateMode === 'period') {
        base = transactions.filter(t => {
          const p = txBudgetPeriod(t);
          return p.year === selectedHistoryMonth.year && p.month === selectedHistoryMonth.month;
        });
      } else {
        base = transactions.filter(t => {
          const d = new Date(t.date);
          return d.getFullYear() === selectedHistoryMonth.year && d.getMonth() === selectedHistoryMonth.month;
        });
      }
    } else {
      // Mes actual: 'period' usa txBudgetPeriod (comportamiento original), 'real' usa fecha real
      if (historyDateMode === 'real') {
        base = transactions.filter(t => {
          const d = new Date(t.date);
          return d.getMonth() === currentDate.getMonth() && d.getFullYear() === currentDate.getFullYear();
        });
      } else {
        base = monthTxs;
      }
    }

    // Filtro por tipo
    if (filterType !== 'ALL') base = base.filter(t => t.type === filterType);

    // Filtro por categoría (Set multi-select)
    if (filterCategories.size > 0) base = base.filter(t => filterCategories.has(t.category));

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

    // Filtro por cuenta (quien pagó)
    if (filterAccount) base = base.filter(t => t.account === filterAccount);

    // Búsqueda por texto (categoría, nota, monto, cuenta)
    if (searchQuery.trim()) {
      const q = searchQuery.trim().toLowerCase();
      base = base.filter(t =>
        t.category.toLowerCase().includes(q) ||
        (t.note || '').toLowerCase().includes(q) ||
        String(t.amount).includes(q) ||
        (t.account || '').toLowerCase().includes(q) ||
        (t.subcategory || '').toLowerCase().includes(q)
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
  }, [transactions, monthTxs, allMonths, selectedHistoryMonth, historyDateMode, currentDate, filterType, filterCategories, filterDate, filterMin, filterMax, filterWeek, filterDateFrom, filterDateTo, searchQuery, sortBy, filterAccount]);

  // Categorías disponibles según el filtro de tipo actual
  const filterableCats = useMemo(() => {
    let base;
    if (allMonths) {
      base = transactions;
    } else if (selectedHistoryMonth) {
      if (historyDateMode === 'period') {
        base = transactions.filter(t => {
          const p = txBudgetPeriod(t);
          return p.year === selectedHistoryMonth.year && p.month === selectedHistoryMonth.month;
        });
      } else {
        base = transactions.filter(t => {
          const d = new Date(t.date);
          return d.getFullYear() === selectedHistoryMonth.year && d.getMonth() === selectedHistoryMonth.month;
        });
      }
    } else {
      base = historyDateMode === 'real'
        ? transactions.filter(t => { const d = new Date(t.date); return d.getMonth() === currentDate.getMonth() && d.getFullYear() === currentDate.getFullYear(); })
        : monthTxs;
    }
    const src = filterType === 'ALL' ? base : base.filter(t => t.type === filterType);
    return [...new Set(src.map(t => t.category))].sort();
  }, [transactions, monthTxs, allMonths, selectedHistoryMonth, historyDateMode, currentDate, filterType]);

  // Meses disponibles agrupados por año (para el picker)
  const availableYearMonths = useMemo(() => {
    const byYearMonth = {};
    transactions.forEach(t => {
      const d = new Date(t.date);
      const y = d.getFullYear(), m = d.getMonth();
      const key = `${y}-${String(m).padStart(2,'0')}`;
      if (!byYearMonth[key]) byYearMonth[key] = { year: y, month: m };
    });
    return Object.values(byYearMonth).sort((a,b) => b.year !== a.year ? b.year - a.year : b.month - a.month);
  }, [transactions]);

  const hasActiveFilters = searchQuery || filterType !== 'ALL' || filterCategories.size > 0 || filterDate || filterMin !== '' || filterMax !== '' || filterWeek || filterDateFrom || filterDateTo || sortBy !== 'date_desc' || allMonths || selectedHistoryMonth || filterAccount;

  const clearFilters = () => {
    setSearchQuery(''); setFilterType('ALL'); setFilterCategories(new Set());
    setFilterDate(''); setFilterMin(''); setFilterMax(''); setFilterWeek(false);
    setFilterDateFrom(''); setFilterDateTo(''); setShowRangeFilter(false);
    setSortBy('date_desc'); setAllMonths(false); setSelectedHistoryMonth(null);
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
      .filter(cat => getAggregatedBudget(cat) > 0);
    const budgetPts = budgetItems.length > 0 ? (() => {
      const greenCount = budgetItems.filter(cat => {
        const pct = (stats.expenseByCategory[cat] || 0) / getAggregatedBudget(cat);
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
    const color = score >= 80 ? 'text-emerald-400' : score >= 60 ? 'text-violet-400' : score >= 40 ? 'text-amber-400' : 'text-rose-400';
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

  // ── ESTADÍSTICAS DEL MES (merged into MICRO-ESTADÍSTICAS below) ──

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

  // Donut data (moved here — needed by catTrends below, must come before it)
  const chartData = activeCategories.GASTO
    .map((cat,i)=>({cat,spent:stats.expenseByCategory[cat]||0,color:CHART_COLORS[i%CHART_COLORS.length]}))
    .filter(d=>d.spent>0);
  const totalSpent = chartData.reduce((s,d)=>s+d.spent,0);
  const { slices } = DonutChart({ data: chartData, total: totalSpent });

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
    const now = new Date();
    const m = currentDate.getMonth(), y = currentDate.getFullYear();
    const daysInMonth = new Date(y, m + 1, 0).getDate();
    const daysPassed = (m === now.getMonth() && y === now.getFullYear()) ? now.getDate() : daysInMonth;
    const dayOfMonth = daysPassed;
    const daysLeft = daysInMonth - dayOfMonth;
    const dailyRate = dayOfMonth > 0 ? stats.expenses / dayOfMonth : 0;
    const projected = Math.round(dailyRate * daysInMonth);
    const totalBudget = Object.values(budgets).reduce((a, c) => a + (Number(c.amount) || 0), 0);
    const remaining = totalBudget > 0 ? Math.max(0, totalBudget - stats.expenses) : null;
    const safeDaily = (daysLeft > 0 && remaining !== null) ? Math.round(remaining / daysLeft) : null;
    const pct = totalBudget > 0 ? Math.round((projected / totalBudget) * 100) : null;
    // Historical comparison fields (merged from Phase 51 duplicate)
    let histTotal = 0, histDays = 0;
    for (let i = 1; i <= 3; i++) {
      const d = new Date(y, m - i, 1); const hm = d.getMonth(), hy = d.getFullYear();
      const hDays = new Date(hy, hm + 1, 0).getDate();
      const hSpent = transactions.filter(t => { const td = new Date(t.date); return t.type==='GASTO' && td.getMonth()===hm && td.getFullYear()===hy; }).reduce((a, c) => a + Number(c.amount), 0);
      if (hSpent > 0) { histTotal += hSpent; histDays += hDays; }
    }
    const histDailyRate = histDays > 0 ? histTotal / histDays : 0;
    const changeVsHist = histDailyRate > 0 ? Math.round(((dailyRate - histDailyRate) / histDailyRate) * 100) : null;
    return { dailyRate: Math.round(dailyRate), projected, totalBudget, daysLeft, safeDaily, pct, dayOfMonth, daysInMonth, daysPassed, totalSpent: Math.round(stats.expenses), histDailyRate: Math.round(histDailyRate), changeVsHist };
  }, [stats.expenses, budgets, transactions, currentDate]);

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
        const limit = getAggregatedBudget(cat);
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
    // Fields for "Este mes en números" widget (merged from first declaration)
    const expDays = Object.entries(byDay).sort(([, a], [, b]) => b - a);
    const activeDays = Object.keys(byDay).length;
    const noSpendDays = Math.max(0, daysInMonth - expDays.length);
    const maxExpDay = expDays[0] ? { date: expDays[0][0], amount: expDays[0][1] } : null;
    return { avgDaily, peakLabel, peakAmount: peakDay ? peakDay[1] : 0, daysNoExp, totalTxs: monthTxs.length, daysElapsed, daysInMonth, activeDays, noSpendDays, maxExpDay };
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
    const needsAmt   = activeCategories.GASTO.filter(c => needsCats.has(c)).reduce((a,c) => a + (stats.expenseByCategory[c]||0), 0);
    const wantsAmt   = activeCategories.GASTO.filter(c => !needsCats.has(c)).reduce((a,c) => a + (stats.expenseByCategory[c]||0), 0);
    const savingsAmt = Math.max(0, stats.income - stats.expenses);
    const base       = stats.income;
    const needsPct   = Math.round((needsAmt   / base) * 100);
    const wantsPct   = Math.round((wantsAmt   / base) * 100);
    const savingsPct = Math.round((savingsAmt / base) * 100);
    const getStatus  = (val, target) => Math.abs(val - target) <= 10 ? 'ok' : val > target ? 'over' : 'low';
    return {
      // Flat percent/status fields used by first 50/30/20 widget
      needsPct, wantsPct, savingsPct, base,
      needsStatus:   getStatus(needsPct,   50),
      wantsStatus:   getStatus(wantsPct,   30),
      savingsStatus: getStatus(savingsPct, 20),
      // Nested amount/actual/target fields used by second 50/30/20 widget (merged from Phase 51)
      income: stats.income,
      needs:   { amount: Math.round(needsAmt),   actual: needsPct,   target: 50 },
      wants:   { amount: Math.round(wantsAmt),   actual: wantsPct,   target: 30 },
      savings: { amount: Math.round(savingsAmt), actual: savingsPct, target: 20 },
    };
  }, [stats, activeCategories, needsCats]);

  // ── SPARKLINES POR CATEGORÍA (3 meses) ──
  const catSparklines = useMemo(() => {
    const now = new Date();
    const result = {};
    activeCategories.GASTO.forEach(cat => {
      const vals = [3, 2, 1].map(i => {
        const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
        const y = d.getFullYear(), m = d.getMonth();
        return transactions
          .filter(t => {
            const p = txBudgetPeriod(t);
            const matchAcc = !budgetAccount || t.account === budgetAccount;
            return t.type === 'GASTO' && t.category === cat && p.year === y && p.month === m && matchAcc;
          })
          .reduce((a, c) => a + Number(c.amount), 0);
      });
      const maxVal = Math.max(...vals, 1);
      result[cat] = { vals, maxVal };
    });
    return result;
  }, [transactions, activeCategories, budgetAccount]);

  // ── PRESUPUESTO: transacciones del período seleccionado ──
  const budgetPeriodTxs = useMemo(() =>
    transactions.filter(t => {
      const p = txBudgetPeriod(t);
      return p.year===budgetPeriod.year && p.month===budgetPeriod.month;
    }),
  [transactions, budgetPeriod]);

  // ── PRESUPUESTO: vencimientos (bills) y cuotas activas en el período ──
  // Cada ítem: { id, rawId, type:'bill'|'cuota', name, amount, dueDay, isPaid, emoji, ... }
  const periodBudgetItems = useMemo(() => {
    const pY = budgetPeriod.year;
    const pM = budgetPeriod.month; // 0-based
    const items = [];

    // ── Bills ──
    bills.forEach(b => {
      const due = new Date(b.due_date);
      let inPeriod = false;
      if      (b.recurrence_type === 'monthly') { inPeriod = true; }
      else if (b.recurrence_type === 'yearly')  { inPeriod = due.getMonth() === pM; }
      else { inPeriod = due.getFullYear() === pY && due.getMonth() === pM; }
      if (!inPeriod) return;

      // Estado de pago: recurrentes = por período; one-time = status global
      const isPaid = b.recurrence_type
        ? !!paidBillsInPeriod[b.id]
        : b.status === 'paid';

      items.push({
        id:          `bill_${b.id}`,
        rawId:       b.id,
        type:        'bill',
        name:        b.title,
        amount:      b.amount,
        dueDay:      due.getDate(),
        isPaid,
        emoji:       '📅',
        category:    b.category,
        isRecurring: !!b.recurrence_type,
      });
    });

    // ── Cuotas ──
    cuotas.forEach(c => {
      if (c.paidCuotas >= c.totalCuotas) return;
      const start     = new Date(c.startDate);
      const endDate   = new Date(c.startDate);
      endDate.setMonth(endDate.getMonth() + c.totalCuotas);
      const pStart    = new Date(pY, pM, 1);
      const pEnd      = new Date(pY, pM + 1, 0);
      if (start > pEnd || endDate <= pStart) return;

      const startMonthNum  = start.getFullYear() * 12 + start.getMonth();
      const periodMonthNum = pY * 12 + pM;
      const cuotaNum = Math.max(1, periodMonthNum - startMonthNum + 1);

      items.push({
        id:          `cuota_${c.id}`,
        rawId:       c.id,
        type:        'cuota',
        name:        c.name,
        amount:      c.monthlyAmount,
        dueDay:      null,
        isPaid:      !!paidCuotasInPeriod[c.id],
        emoji:       c.emoji || '💳',
        cuotaNum,
        totalCuotas: c.totalCuotas,
      });
    });

    // Ordenar por día de vencimiento (bills primero, luego cuotas)
    return items.sort((a, b) => {
      if (a.dueDay === null && b.dueDay === null) return 0;
      if (a.dueDay === null) return 1;
      if (b.dueDay === null) return -1;
      return a.dueDay - b.dueDay;
    });
  }, [bills, cuotas, budgetPeriod, paidBillsInPeriod, paidCuotasInPeriod]);

  // ── PRESUPUESTO: stats del período seleccionado ──
  const budgetPeriodStats = useMemo(() => {
    const income = budgetPeriodTxs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
    const expBycat = {};
    budgetPeriodTxs.filter(t=>t.type==='GASTO').forEach(t=>{
      expBycat[t.category]=(expBycat[t.category]||0)+Number(t.amount);
    });
    const incomeCats = {};
    budgetPeriodTxs.filter(t=>t.type==='INGRESO').forEach(t=>{
      incomeCats[t.category]=(incomeCats[t.category]||0)+Number(t.amount);
    });
    const fixedPaidTotal = fixedTxs
      .filter(f=>f.type==='GASTO' && paidItems[f.id])
      .reduce((a,c)=>a+c.amount,0);
    return { income, expBycat, incomeCats, fixedPaidTotal };
  }, [budgetPeriodTxs, fixedTxs, paidItems]);

  // ── PRESUPUESTO: stats filtrados por cuenta seleccionada ──
  const budgetFilteredStats = useMemo(() => {
    const filtered = budgetAccount
      ? budgetPeriodTxs.filter(t => t.account === budgetAccount)
      : budgetPeriodTxs;
    const income = filtered.filter(t => t.type === 'INGRESO').reduce((a, c) => a + Number(c.amount), 0);
    const expBycat = {};
    const expByCatSubcat = {}; // key: 'cat||subcat'
    filtered.filter(t => t.type === 'GASTO').forEach(t => {
      expBycat[t.category] = (expBycat[t.category] || 0) + Number(t.amount);
      const sk = `${t.category}||${t.subcategory || ''}`;
      expByCatSubcat[sk] = (expByCatSubcat[sk] || 0) + Number(t.amount);
    });
    return { income, expBycat, expByCatSubcat };
  }, [budgetPeriodTxs, budgetAccount]);

  // ── WATERFALL: Cálculo completo del presupuesto del hogar ──
  const waterfallData = useMemo(() => {
    // 1. Ingreso total del hogar (TODAS las cuentas)
    const totalIncome = budgetPeriodTxs
      .filter(t => t.type === 'INGRESO')
      .reduce((a, c) => a + Number(c.amount), 0);

    // Ingreso por cuenta (para modo proporcional)
    const incomeByAccount = {};
    budgetPeriodTxs.filter(t => t.type === 'INGRESO').forEach(t => {
      incomeByAccount[t.account] = (incomeByAccount[t.account] || 0) + Number(t.amount);
    });

    // 2. Obligaciones: gastos fijos pagados
    const fixedExpenses = budgetPeriodStats.fixedPaidTotal;

    // 3. Vencimientos y cuotas
    const billsAndCuotas = periodBudgetItems.reduce((a, i) => a + i.amount, 0);

    // 4. Presupuestos compartidos (categorías asignadas a cuentas "compartida")
    const sharedCategoryBudgets = sharedAccounts.reduce((total, acc) => {
      return total + activeCategories.GASTO.reduce((sum, cat) => {
        const raw = budgets[`${acc}|${cat}|`]?.amount || 0;
        return sum + raw;
      }, 0);
    }, 0);

    // 5. Ahorro e Inversión (% del ingreso total del hogar)
    const savingsAmt = Math.round(totalIncome * (strategy.savingsPercent || 0) / 100);
    const investAmt  = Math.round(totalIncome * (strategy.investmentPercent || 0) / 100);

    // 6. Saldo a distribuir
    const totalDeductions = fixedExpenses + billsAndCuotas + sharedCategoryBudgets + savingsAmt + investAmt;
    const remainder = Math.max(0, totalIncome - totalDeductions);

    // 7. Asignaciones efectivas según modo
    let effectiveAllocations = {};
    const mode = allocations.mode || 'equal';
    if (mode === 'equal' && personalAccounts.length > 0) {
      const share = Math.round(remainder / personalAccounts.length);
      personalAccounts.forEach(a => { effectiveAllocations[a] = share; });
    } else if (mode === 'proportional' && totalIncome > 0) {
      personalAccounts.forEach(a => {
        const accIncome = incomeByAccount[a] || 0;
        effectiveAllocations[a] = Math.round(remainder * (accIncome / totalIncome));
      });
    } else if (mode === 'custom') {
      effectiveAllocations = { ...(allocations.amounts || {}) };
    } else if (personalAccounts.length > 0) {
      const share = Math.round(remainder / personalAccounts.length);
      personalAccounts.forEach(a => { effectiveAllocations[a] = share; });
    }

    const totalAllocated = personalAccounts.reduce((a, acc) => a + (effectiveAllocations[acc] || 0), 0);
    const unallocated = remainder - totalAllocated;

    return {
      totalIncome, incomeByAccount,
      fixedExpenses, billsAndCuotas, sharedCategoryBudgets,
      savingsAmt, investAmt, totalDeductions,
      remainder, effectiveAllocations, totalAllocated, unallocated,
    };
  }, [budgetPeriodTxs, budgetPeriodStats, periodBudgetItems,
      sharedAccounts, personalAccounts, budgets,
      activeCategories, strategy, allocations]);

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
      const budget = getAggregatedBudget(cat);
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
    const budgeted = activeCategories.GASTO.filter(cat => getAggregatedBudget(cat) > 0);
    if (budgeted.length === 0) return null;
    const wins = budgeted
      .map(cat => {
        const budget = getAggregatedBudget(cat);
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
        const s = transactions.filter(t => { const p = txBudgetPeriod(t); return t.type==='GASTO' && t.category===cat && p.year===y && p.month===m; }).reduce((a,c)=>a+Number(c.amount),0);
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

  // rule503020 duplicate removed — merged into declaration above

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

  // burnRate duplicate removed — merged into declaration above

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
    const withBudget = activeCats.filter(cat => getAggregatedBudget(cat) > 0);
    const noBudget   = activeCats.filter(cat => getAggregatedBudget(cat) === 0);
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

  // monthlySavingsGoal — ahorro necesario/mes para alcanzar todas las metas activas en 12 meses
  const monthlySavingsGoal = useMemo(() => {
    const activeGoals = goals.filter(g => !g.completed && g.target > 0 && g.current < g.target);
    if (activeGoals.length === 0 || stats.income === 0) return null;
    const totalRemaining = activeGoals.reduce((a, g) => a + (g.target - Math.min(g.current, g.target)), 0);
    const requiredMonthly = Math.round(totalRemaining / 12);
    const monthly = Math.max(0, stats.income - stats.expenses);
    const pct = requiredMonthly > 0 ? Math.min(100, Math.round((monthly / requiredMonthly) * 100)) : 100;
    const isOnTrack = monthly >= requiredMonthly;
    return { monthly, requiredMonthly, totalRemaining, pct, isOnTrack, goalsCount: activeGoals.length };
  }, [goals, stats]);

  // quarterSummary — ingresos, gastos y ahorro acumulado del trimestre actual vs anterior
  const quarterSummary = useMemo(() => {
    const now = new Date();
    const cy = currentDate.getFullYear(), cm = currentDate.getMonth();
    const currentQ = Math.floor(cm / 3);
    const getQData = (year, q) => {
      const months = [q*3, q*3+1, q*3+2];
      let income=0, expense=0;
      months.forEach(m => {
        transactions.filter(t => { const d=new Date(t.date); return d.getMonth()===m&&d.getFullYear()===year; }).forEach(t => {
          if(t.type==='INGRESO') income+=Number(t.amount);
          else expense+=Number(t.amount);
        });
      });
      return{income:Math.round(income), expense:Math.round(expense), balance:Math.round(income-expense)};
    };
    const prevQ = currentQ === 0 ? 3 : currentQ - 1;
    const prevY = currentQ === 0 ? cy - 1 : cy;
    const curr = getQData(cy, currentQ);
    const prev = getQData(prevY, prevQ);
    if (curr.income === 0 && curr.expense === 0) return null;
    const pctChg = (c, p) => p !== 0 ? Math.round(((c-p)/Math.abs(p))*100) : null;
    const QNAMES = ['Q1 (Ene–Mar)','Q2 (Abr–Jun)','Q3 (Jul–Sep)','Q4 (Oct–Dic)'];
    return{curr:{...curr, label:QNAMES[currentQ]}, prev:{...prev, label:QNAMES[prevQ]}, incChange:pctChg(curr.income,prev.income), expChange:pctChg(curr.expense,prev.expense), balChange:pctChg(curr.balance,prev.balance)};
  }, [transactions, currentDate]);

  // healthCheckList — 5 checks de salud financiera rápidos
  const healthCheckList = useMemo(() => {
    const now = new Date(); now.setHours(0,0,0,0);
    const weekAgo = new Date(now.getTime() - 7*86400000);
    const hasRecentTx = transactions.some(t => new Date(t.date+'T12:00:00') >= weekAgo);
    const hasActiveGoals = goals.some(g => !g.completed);
    const allBudgetsCovered = budgetCoverage ? budgetCoverage.pct >= 80 : false;
    const positiveBalance = stats.income > 0 && stats.income > stats.expenses;
    const noPendingDebts = !debts.some(d => !d.settled);
    return [
      { label: 'Movimientos esta semana', ok: hasRecentTx },
      { label: 'Metas de ahorro activas', ok: hasActiveGoals },
      { label: 'Presupuestos cubiertos (≥80%)', ok: allBudgetsCovered },
      { label: 'Balance mensual positivo', ok: positiveBalance },
      { label: 'Sin deudas pendientes', ok: noPendingDebts },
    ];
  }, [transactions, goals, budgetCoverage, stats, debts]);

  // achievements — logros desbloqueados basados en datos reales
  const achievements = useMemo(() => {
    const all = [];
    if (stats.income > 0 && stats.income > stats.expenses)
      all.push({ emoji:'🥇', label:'Mes positivo',          desc:'Ingresos superan los gastos este mes' });
    if (noSpendStreak && noSpendStreak.record >= 7)
      all.push({ emoji:'🔥', label:`Racha ${noSpendStreak.record}d`,  desc:`Récord de ${noSpendStreak.record} días sin gastar` });
    const completedGoals = goals.filter(g => g.completed).length;
    if (completedGoals > 0)
      all.push({ emoji:'🎯', label:`${completedGoals} meta${completedGoals>1?'s':''} ✓`, desc:'Alcanzaste tu objetivo de ahorro' });
    const now2 = new Date(); let consec = 0;
    for (let i=1;i<=6;i++){
      const d=new Date(now2.getFullYear(),now2.getMonth()-i,1);
      const txs=transactions.filter(t=>{const td=new Date(t.date);return td.getMonth()===d.getMonth()&&td.getFullYear()===d.getFullYear();});
      const inc=txs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
      const exp=txs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0);
      if(inc>exp) consec++; else break;
    }
    if (consec >= 3)
      all.push({ emoji:'📈', label:`${consec} meses ↑`,   desc:`Ahorraste ${consec} meses consecutivos` });
    if (budgetCoverage && budgetCoverage.pct === 100)
      all.push({ emoji:'🧩', label:'Presupuesto 100%',     desc:'Todas las categorías tienen presupuesto' });
    if (liquidityRatio && liquidityRatio.ratio >= 3)
      all.push({ emoji:'💧', label:`Colchón ${liquidityRatio.ratio}×`, desc:`${liquidityRatio.ratio} meses de reserva` });
    if (debts.length > 0 && !debts.some(d => !d.settled))
      all.push({ emoji:'🏆', label:'¡Sin deudas!',         desc:'Todas las deudas están saldadas' });
    return all.length > 0 ? all : null;
  }, [stats, noSpendStreak, goals, transactions, budgetCoverage, liquidityRatio, debts]);

  // incomeByDow — ingreso promedio por día de la semana (últimas 8 semanas)
  const incomeByDow = useMemo(() => {
    const ingreso = transactions.filter(t => t.type === 'INGRESO');
    if (ingreso.length < 4) return null;
    const now=new Date(); now.setHours(0,0,0,0);
    const cutoff=new Date(now.getTime()-8*7*86400000);
    const recent=ingreso.filter(t=>{const d=new Date(t.date+'T12:00:00');return d>=cutoff&&d<=now;});
    if (recent.length < 2) return null;
    const dowTotals=Array(7).fill(0);
    recent.forEach(t=>{const d=new Date(t.date+'T12:00:00');dowTotals[d.getDay()]+=Number(t.amount);});
    const avgs=dowTotals.map(s=>Math.round(s/8));
    const maxAvg=Math.max(...avgs,1);
    const peakDow=avgs.indexOf(Math.max(...avgs));
    if(avgs[peakDow]===0) return null;
    const DOW_LABELS=['D','L','M','X','J','V','S'];
    return{avgs,maxAvg,peakDow,labels:DOW_LABELS};
  }, [transactions]);

  // stabilityIndex — score 0–100 de estabilidad financiera en 5 dimensiones
  const stabilityIndex = useMemo(() => {
    if (transactions.length < 10) return null;
    let score = 0;
    const breakdown = [];
    const add = (label, pts, max) => { score += pts; breakdown.push({ label, pts, max }); };
    if (liquidityRatio) {
      add('Liquidez', liquidityRatio.ratio>=6?20:liquidityRatio.ratio>=3?15:liquidityRatio.ratio>=1?8:2, 20);
    } else { add('Liquidez', 0, 20); }
    if (budgetCoverage) {
      add('Presupuesto', budgetCoverage.pct>=100?20:budgetCoverage.pct>=80?15:budgetCoverage.pct>=50?10:5, 20);
    } else { add('Presupuesto', 0, 20); }
    if (stats.income > 0) {
      const rate=(stats.income-stats.expenses)/stats.income;
      add('Ahorro', rate>=0.2?20:rate>=0.1?12:rate>=0?5:0, 20);
    } else { add('Ahorro', 0, 20); }
    if (balanceTrend) {
      add('Tendencia', balanceTrend.trend==='up'?20:balanceTrend.trend==='flat'?10:2, 20);
    } else { add('Tendencia', 0, 20); }
    const now3=new Date(); let greenM=0;
    for(let i=1;i<=6;i++){
      const d=new Date(now3.getFullYear(),now3.getMonth()-i,1);
      const txs=transactions.filter(t=>{const td=new Date(t.date);return td.getMonth()===d.getMonth()&&td.getFullYear()===d.getFullYear();});
      const inc=txs.filter(t=>t.type==='INGRESO').reduce((a,c)=>a+Number(c.amount),0);
      const exp=txs.filter(t=>t.type==='GASTO').reduce((a,c)=>a+Number(c.amount),0);
      if((inc>0||exp>0)&&inc>=exp) greenM++;
    }
    add('Historial', greenM>=6?20:greenM>=4?15:greenM>=2?8:greenM>=1?3:0, 20);
    const level=score>=80?'Excelente':score>=60?'Bueno':score>=40?'Regular':'Crítico';
    const color=score>=80?'#10b981':score>=60?'#6366f1':score>=40?'#f59e0b':'#ef4444';
    return{score,level,color,breakdown};
  }, [transactions, liquidityRatio, budgetCoverage, stats, balanceTrend]);

  // ─────────────────────────────────────────────
  // RENDER: CARGANDO AUTH (must be after all hooks)
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
  // RENDER: LOGIN (must be after all hooks)
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
              <p className="text-sm text-zinc-500 mt-1">{tl('homeFinance')}</p>
            </div>
          </div>

          <div className="bg-zinc-900/50 rounded-[2rem] p-7 border border-white/5 space-y-5">
            <div className="flex bg-black rounded-2xl p-1.5 border border-white/10">
              {[{key:"LOGIN",label:tl('loginTab')},{key:"SIGNUP",label:tl('signupTab')}].map(opt=>(
                <button key={opt.key} onClick={()=>setAuthMode(opt.key)}
                  className={`flex-1 py-3 text-sm font-bold rounded-xl transition-all ${authMode===opt.key?'bg-violet-600 text-white':'text-zinc-500'}`}>
                  {opt.label}
                </button>
              ))}
            </div>
            <input type="email" value={authEmail} onChange={e=>setAuthEmail(e.target.value)} placeholder="Email"
              className="w-full bg-black/60 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-violet-500/40 transition-colors" />
            <div className="relative">
              <input type={showPassword ? 'text' : 'password'} value={authPassword} onChange={e=>setAuthPassword(e.target.value)} placeholder={lang==='en'?'Password':'Contraseña'}
                className="w-full bg-black/60 rounded-2xl p-4 pr-12 border border-white/10 text-sm text-white focus:outline-none focus:border-violet-500/40 transition-colors" />
              <button type="button" onClick={()=>setShowPassword(p=>!p)}
                className="absolute right-3 top-1/2 -translate-y-1/2 p-1.5 text-zinc-500 active:text-zinc-300 transition-colors">
                {showPassword ? <EyeOff className="w-4 h-4"/> : <Eye className="w-4 h-4"/>}
              </button>
            </div>
            <button onClick={authMode==="LOGIN"?signIn:signUp}
              className="w-full py-5 rounded-2xl font-bold text-sm uppercase tracking-wider bg-violet-600 active:scale-95 transition-all shadow-lg">
              {authMode==="LOGIN"?tl('loginBtn'):tl('createAccountBtn')}
            </button>
            {authMode==="LOGIN" && (
              <button onClick={resetPassword} className="text-xs text-violet-400 text-center w-full py-2 active:text-violet-300">
                {tl('forgotPassword')}
              </button>
            )}
            {authMode==="SIGNUP"&&<p className="text-xs text-zinc-600 text-center">{tl('checkSpam')}</p>}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-black text-white font-sans overflow-x-hidden">
      <GlobalStyles />

      {/* ── TAB CONTENT ── */}
      <div className="max-w-md sm:max-w-xl md:max-w-3xl xl:max-w-5xl mx-auto pb-[calc(env(safe-area-inset-bottom)+8rem)] md:pb-10">

        {/* ════════════════════════════════
            TAB: INICIO (Dashboard)
        ════════════════════════════════ */}
        {activeTab==='home' && (
          <div className="px-5 pt-[calc(env(safe-area-inset-top)+16px)] pb-[calc(env(safe-area-inset-bottom)+90px)] flex flex-col gap-4 md:grid md:grid-cols-2 lg:grid-cols-3 md:gap-5 md:items-start">
            {/* Header */}
            <header style={{order: -2}} className="md:col-span-2 lg:col-span-3 flex justify-between items-center">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl overflow-hidden border border-white/10">
                  <img src={logoMetacasa} alt="MetaCasa" className="w-full h-full object-cover" />
                </div>
                <div>
                  <h1 className="text-lg font-black italic uppercase tracking-tight leading-none">MetaCasa</h1>
                  <button onClick={()=>setShowDatePicker(true)}
                    className="flex items-center gap-1 text-xs font-semibold text-violet-400 mt-0.5 active:opacity-60">
                    <Calendar className="w-3 h-3" />
                    {MONTHS[currentDate.getMonth()]} {currentDate.getFullYear()}
                  </button>
                </div>
              </div>
              <div className="flex gap-1.5">
                <button onClick={()=>{ haptic(8); setShowSearch(true); }}
                  className="p-2 bg-zinc-900 rounded-xl active:scale-90 transition-transform" title="Buscar transacciones">
                  <Search className="w-5 h-5 text-zinc-400"/>
                </button>
                <button onClick={()=>{ haptic(8); setActiveTab('settings'); }}
                  className="p-2 bg-zinc-900 rounded-xl active:scale-90 transition-transform" title="Ajustes">
                  <Settings className="w-5 h-5 text-zinc-400"/>
                </button>
                <button onClick={()=>{ haptic(8); setShowWidgetEditor(true); }}
                  className={`p-2 rounded-xl active:scale-90 transition-transform ${hiddenWidgets.size > 0 ? 'bg-violet-700/15' : 'bg-zinc-900'}`} title="Personalizar widgets">
                  <LayoutGrid className={`w-5 h-5 ${hiddenWidgets.size > 0 ? 'text-violet-400' : 'text-zinc-400'}`}/>
                </button>
                <button onClick={togglePrivacy} className={`p-2 rounded-xl active:scale-90 transition-transform ${privacyMode ? 'bg-amber-500/20' : 'bg-zinc-900'}`} title={privacyMode ? 'Mostrar montos' : 'Ocultar montos'}>
                  {privacyMode ? <EyeOff className="w-5 h-5 text-amber-400"/> : <Eye className="w-5 h-5 text-zinc-400"/>}
                </button>
                <button onClick={handleQuickShare} className="p-2 bg-zinc-900 rounded-xl active:scale-90 transition-transform" title="Compartir resumen">
                  <Share2 className="w-5 h-5 text-violet-400" />
                </button>
              </div>
            </header>

            {/* Balance Card */}
            {loadingData ? <LoadingSkeleton /> : (
              <>
                <div style={{order: -1, gridColumn: '1 / -1'}} className="space-y-3">
                  <div className="flex items-center justify-between px-1">
                    <button onClick={()=>changeMonth(-1)} className="p-2 bg-zinc-900/70 rounded-full text-zinc-500 active:scale-90 transition-transform">
                      <ChevronLeft className="w-5 h-5" />
                    </button>
                    <span className="text-xs font-semibold text-zinc-600 uppercase tracking-wider">{tl('periodBalance')}</span>
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
                              ${isSel ? 'bg-violet-600 text-white shadow-md' : 'bg-zinc-900/80 text-zinc-500 border border-white/8'}`}>
                            {MONTHS[d.getMonth()].slice(0,3)}{d.getFullYear()!==new Date().getFullYear()?` ${d.getFullYear()}`:''}
                          </button>
                        );
                      }).filter(Boolean)}
                    </div>
                  </div>

                  {/* Selector de cuenta — Home */}
                  {accounts.length > 0 && (
                    <div className="flex gap-2 overflow-x-auto no-scrollbar -mx-1 px-1">
                      {['', ...accounts].map(acc => (
                        <button key={acc || '__all__'}
                          onClick={() => { setHomeAccount(acc); haptic(6); }}
                          className={`flex-shrink-0 px-4 py-1.5 rounded-full text-xs font-bold transition-all active:scale-95 border
                            ${homeAccount === acc
                              ? 'bg-violet-600 text-white border-violet-500/50'
                              : 'bg-zinc-900 text-zinc-500 border-white/8'}`}>
                          {acc || 'Todas'}
                        </button>
                      ))}
                    </div>
                  )}

                  <div className="rounded-[2rem] p-7 shadow-2xl relative overflow-hidden border border-violet-500/10" style={{background:'linear-gradient(145deg, #2c1158 0%, #18093a 45%, #090511 100%)'}}>
                    <div className="relative z-10">
                      <button
                        onClick={()=>{ setHomeDetailType('DISPONIBLE'); haptic(8); }}
                        className="w-full text-left active:opacity-70 transition-opacity">
                        <p className="text-xs font-semibold text-violet-200/55 uppercase tracking-wider">{tl('availableBalance')}</p>
                        {privacyMode
                          ? <p className="text-5xl font-black text-white tracking-tight my-1">••••</p>
                          : <SharedSizeText value={homeStats.available} fontSizeClass="text-5xl" />
                        }
                        {/* Eliminado: conversión de balance — los montos ya están en la moneda base */}
                        <p className="text-[9px] text-white/20 font-semibold tracking-wide mt-1.5">{tl('seeDetailByCategory')}</p>
                      </button>
                      <div className="mt-6 pt-5 border-t border-white/10 grid grid-cols-2 gap-3">
                        <button onClick={()=>{ setHomeDetailType('INGRESO'); haptic(8); }}
                          className="bg-white/8 rounded-2xl p-4 text-left active:scale-[0.96] transition-transform">
                          <span className="flex items-center gap-1 text-xs font-semibold text-emerald-300 mb-1.5">
                            <ArrowUpRight className="w-3.5 h-3.5" /> {tl('incomesLabel')}
                          </span>
                          <p className="text-xl font-black tracking-tight">${priv(formatNumber(homeStats.income))}</p>
                          <p className="text-[9px] text-white/30 mt-1 font-semibold tracking-wide">{tl('seeDetail')}</p>
                        </button>
                        <button onClick={()=>{ setHomeDetailType('GASTO'); haptic(8); }}
                          className="bg-white/8 rounded-2xl p-4 text-left active:scale-[0.96] transition-transform">
                          <span className="flex items-center gap-1 text-xs font-semibold text-rose-300 mb-1.5">
                            <ArrowDownLeft className="w-3.5 h-3.5" /> {tl('expensesTitle')}
                          </span>
                          <p className="text-xl font-black tracking-tight">${priv(formatNumber(homeStats.expenses))}</p>
                          <p className="text-[9px] text-white/30 mt-1 font-semibold tracking-wide">{tl('seeDetail')}</p>
                        </button>
                        {cuotasMonthly > 0 && (
                          <div className="col-span-2 bg-amber-500/10 rounded-2xl p-3 flex justify-between items-center">
                            <span className="flex items-center gap-1.5 text-xs font-semibold text-amber-300">
                              <Wallet className="w-3.5 h-3.5"/> {tl('monthInstallments')}
                            </span>
                            <span className="text-sm font-black text-amber-300">{currSymbol}{priv(formatNumber(cuotasMonthly))}</span>
                          </div>
                        )}
                      </div>
                    </div>
                    <div className="absolute top-0 right-0 w-56 h-56 bg-violet-400/18 rounded-full blur-[90px] -mr-20 -mt-20" />
                  </div>
                </div>

                {/* ── Plan del mes ── */}
                {!isHidden('planMes') && ((planMes.targetIncome > 0 || planMes.targetExpense > 0 || showPlanEditor) ? (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5 space-y-3">
                    <div className="flex justify-between items-center">
                      <p className="text-sm font-bold text-zinc-300">Plan de {MONTHS[currentDate.getMonth()]}</p>
                      <button onClick={() => setShowPlanEditor(v=>!v)} className="text-[10px] font-bold text-violet-400 active:opacity-60">
                        {showPlanEditor ? 'Cerrar' : 'Editar →'}
                      </button>
                    </div>
                    {showPlanEditor ? (
                      <PlanEditor planMes={planMes} onSave={savePlanMes} onCancel={()=>setShowPlanEditor(false)}/>
                    ) : (
                      <>
                        <div className="space-y-2.5">
                          {planMes.targetIncome > 0 && (
                            <div>
                              <div className="flex justify-between text-xs mb-1">
                                <span className="text-zinc-500 font-semibold">Ingreso meta</span>
                                <span className="font-black text-emerald-400">${priv(formatNumber(homeStats.income))} / ${formatNumber(planMes.targetIncome)}</span>
                              </div>
                              <div className="h-2 bg-black/40 rounded-full overflow-hidden">
                                <div className="h-full rounded-full bg-emerald-500 transition-all duration-700"
                                  style={{width:`${Math.min(100,Math.round((homeStats.income/planMes.targetIncome)*100))}%`}}/>
                              </div>
                            </div>
                          )}
                          {planMes.targetExpense > 0 && (
                            <div>
                              <div className="flex justify-between text-xs mb-1">
                                <span className="text-zinc-500 font-semibold">Gasto límite</span>
                                <span className={`font-black ${homeStats.expenses > planMes.targetExpense ? 'text-rose-400' : 'text-violet-400'}`}>
                                  ${priv(formatNumber(homeStats.expenses))} / ${formatNumber(planMes.targetExpense)}
                                </span>
                              </div>
                              <div className="h-2 bg-black/40 rounded-full overflow-hidden">
                                <div className={`h-full rounded-full transition-all duration-700 ${homeStats.expenses > planMes.targetExpense ? 'bg-rose-500' : 'bg-violet-500'}`}
                                  style={{width:`${Math.min(100,Math.round((homeStats.expenses/planMes.targetExpense)*100))}%`}}/>
                              </div>
                            </div>
                          )}
                        </div>
                        {planMes.note && (
                          <p className="text-xs text-zinc-600 italic mt-2 px-1 border-t border-white/5 pt-2">
                            💬 {planMes.note}
                          </p>
                        )}
                      </>
                    )}
                  </div>
                ) : (
                  <button onClick={() => setShowPlanEditor(true)}
                    className="w-full py-3 bg-zinc-900/20 border border-dashed border-white/10 rounded-[1.5rem] text-xs font-bold text-zinc-600 active:text-zinc-400 active:border-white/20 transition-all flex items-center justify-center gap-2">
                    <span>📋</span> Establecer plan para {MONTHS[currentDate.getMonth()]}
                  </button>
                ))}

                {/* ── Gastos fijos comprometidos ── */}
                {!isHidden('recurringFixed') && recurringFixed && (
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
                      style={{background: dailyBudget.isOver ? 'rgba(244,63,94,0.12)' : 'rgba(109,40,217,0.12)'}}>
                      {dailyBudget.isOver ? '🚨' : dailyBudget.pct >= 85 ? '⚠️' : '💰'}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-xs font-bold text-zinc-400">
                        {dailyBudget.isOver ? 'Presupuesto excedido' : `Disponible por día — ${dailyBudget.daysLeft} días`}
                      </p>
                      <div className="w-full h-1 bg-black/40 rounded-full mt-1.5 overflow-hidden">
                        <div className={`h-full rounded-full transition-all duration-700 ${dailyBudget.isOver ? 'bg-rose-500' : dailyBudget.pct >= 85 ? 'bg-amber-400' : 'bg-violet-500'}`}
                          style={{width:`${dailyBudget.pct}%`}}/>
                      </div>
                    </div>
                    <div className="text-right flex-shrink-0">
                      <p className={`text-base font-black ${dailyBudget.isOver ? 'text-rose-400' : dailyBudget.pct >= 85 ? 'text-amber-400' : 'text-violet-300'}`}>
                        {dailyBudget.isOver ? `−${priv(formatNumber(Math.abs(dailyBudget.remaining)))}` : `$${priv(formatNumber(dailyBudget.daily))}`}
                      </p>
                      <p className="text-[9px] text-zinc-600 mt-0.5">{dailyBudget.pct}% del presupuesto</p>
                    </div>
                  </div>
                )}

                {/* ── Gasto de hoy ── */}
                {!isHidden('gastosHoy') && gastosHoy && (
                  <button onClick={() => { goToDate(new Date().toISOString().slice(0,10)); setActiveTab('history'); }}
                    className="w-full bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-4 flex items-center gap-4 active:bg-zinc-900/70 transition-colors">
                    <div className="w-10 h-10 bg-violet-700/12 rounded-xl flex items-center justify-center flex-shrink-0">
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
                          <p className="text-[10px] text-zinc-600 mb-1">{tl('estIncome')}</p>
                          <p className="text-xs font-black text-emerald-400">${priv(formatNumber(monthProjection.projectedIncome))}</p>
                        </div>
                      )}
                      <div className="bg-black/30 rounded-xl p-2.5 text-center">
                        <p className="text-[10px] text-zinc-600 mb-1">{tl('estExpenses')}</p>
                        <p className="text-xs font-black text-rose-300">${priv(formatNumber(monthProjection.projectedExpense))}</p>
                      </div>
                      <div className={`rounded-xl p-2.5 text-center ${monthProjection.projectedBalance >= 0 ? 'bg-emerald-500/8 border border-emerald-500/15' : 'bg-rose-500/8 border border-rose-500/15'}`}>
                        <p className="text-[10px] text-zinc-600 mb-1">{tl('balance')} est.</p>
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
                {!isHidden('monthStats') && monthStats && (
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
                    <p className="text-sm font-bold text-zinc-300 mb-3">{tl('topExpensesMonth')}</p>
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
                {ww('savings', (strategy.savingsPercent > 0 || strategy.investmentPercent > 0) && (
                  <div className="grid grid-cols-2 gap-3">
                    {strategy.savingsPercent>0 && (
                      <div className="mc-card p-4">
                        <p className="text-xs text-emerald-400 font-semibold flex items-center gap-1 mb-1"><PiggyBank className="w-3.5 h-3.5"/>{tl('savings')}</p>
                        <p className="text-lg font-black">${formatNumber(homeStats.savingsAmount)}</p>
                        <p className="text-xs text-zinc-600">{strategy.savingsPercent}{tl('ofIncome')}</p>
                      </div>
                    )}
                    {strategy.investmentPercent>0 && (
                      <div className="mc-card p-4">
                        <p className="text-xs text-violet-400 font-semibold flex items-center gap-1 mb-1"><TrendingUp className="w-3.5 h-3.5"/>{tl('investment')}</p>
                        <p className="text-lg font-black">${formatNumber(homeStats.investmentAmount)}</p>
                        <p className="text-xs text-zinc-600">{strategy.investmentPercent}{tl('ofIncome')}</p>
                      </div>
                    )}
                  </div>
                ))}

                {/* ── Desglose fuentes de ingreso ── */}
                {!isHidden('incomeSourceBreakdown') && incomeSourceBreakdown && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-3">{tl('incomeSources')}</p>
                    <div className="space-y-2.5">
                      {incomeSourceBreakdown.map(({ cat, amount }) => {
                        const pct = Math.round((amount / homeStats.income) * 100);
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
                {ww('donutChart', chartData.length > 0 && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-4">
                      <p className="text-sm font-bold text-zinc-300">{tl('expenseDistribution')}</p>
                      <button onClick={()=>{ setShowBudgetModal(true); setBudgetChartView(true); }}
                        className="text-xs text-violet-400 font-semibold">
                        {tl('seeDetail')}
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
                            <p className="text-[9px] text-zinc-600 mt-0.5">{tl('expensesLabel')}</p>
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
                ))}

                {/* Insights dinámicos */}
                {ww('insights', insights.length > 0 && (
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
                ))}

                {/* Calendario de gastos del mes */}
                {ww('spendingCal', monthTxs.filter(t=>t.type==='GASTO').length > 0 && (
                  <SpendingCalendar
                    transactions={transactions}
                    year={currentDate.getFullYear()}
                    month={currentDate.getMonth()}
                    onDayPress={goToDate}
                  />
                ))}

                {/* Sparkline — últimos 7 días de gasto */}
                {ww('sparkline7d', last7DaysData.some(d => d.expense > 0) && (() => {
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
                                  ${isToday ? 'bg-violet-500' : d.expense > 0 ? 'bg-rose-500/55' : 'bg-zinc-800/50'}`}
                                style={{ height: `${barH}px` }}
                              />
                              <span className={`text-[9px] font-bold leading-none
                                ${isToday ? 'text-violet-400' : d.expense > 0 ? 'text-zinc-500' : 'text-zinc-800'}`}>
                                {d.label}
                              </span>
                            </button>
                          );
                        })}
                      </div>
                    </div>
                  );
                })())}

                {/* Este mes en números */}
                {ww('esteMesGrid', monthStats && (
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
                ))}

                {/* Tasa de ahorro */}
                {ww('savingsRate', savingsRateData && (
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
                ))}

                {/* ── Semáforo de presupuestos ── */}
                {!isHidden('semaforo') && budgetSemaforo && (
                  <button onClick={() => setShowBudgetModal(true)} className="w-full text-left">
                    <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                      <div className="flex justify-between items-center mb-3">
                        <p className="text-sm font-bold text-zinc-300">Presupuestos por categoría</p>
                        <span className="text-[10px] text-zinc-600 font-semibold">{tl('seeDetail')}</span>
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
                {ww('globalBudget', homeStats.totalBudgetsAssigned > 0 && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    {(() => {
                      const spent = homeStats.expenses;
                      const total = homeStats.totalBudgetsAssigned;
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
                ))}

                {/* Tendencia de categorías */}
                {ww('catTrends3m', catTrends && catTrends.length > 0 && (
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
                ))}

                {/* Gasto por día de semana */}
                {ww('weekdayChart', weekdaySpending && (
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
                ))}

                {/* Promedio mensual histórico */}
                {ww('monthlyAvg', monthlyAvg && monthlyAvg.months >= 2 && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">Promedio mensual</p>
                      <span className="text-[10px] text-zinc-600 font-semibold">{monthlyAvg.months} meses de datos</span>
                    </div>
                    <div className="grid grid-cols-3 gap-2">
                      <div className="bg-black/30 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-600 font-semibold mb-1">{tl('incomesLabel')}</p>
                        <p className="text-sm font-black text-emerald-400">${formatNumber(monthlyAvg.avgIncome)}</p>
                      </div>
                      <div className="bg-black/30 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-600 font-semibold mb-1">{tl('expensesTitle')}</p>
                        <p className="text-sm font-black text-rose-400">${formatNumber(monthlyAvg.avgExpense)}</p>
                      </div>
                      <div className="bg-black/30 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-600 font-semibold mb-1">{tl('balance')}</p>
                        <p className={`text-sm font-black ${monthlyAvg.avgBalance >= 0 ? 'text-violet-300' : 'text-rose-400'}`}>
                          {monthlyAvg.avgBalance >= 0 ? '+' : ''}${formatNumber(Math.abs(monthlyAvg.avgBalance))}
                        </p>
                      </div>
                    </div>
                  </div>
                ))}

                {/* Resumen anual (YTD) */}
                {ww('ytdSummary', yearStats && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">{currentDate.getFullYear()} hasta hoy</p>
                      <button onClick={() => setShowAnnualModal(true)}
                        className="text-[10px] font-bold text-violet-400 active:opacity-60">
                        Ver completo →
                      </button>
                    </div>
                    <div className="grid grid-cols-3 gap-2 mb-3">
                      <div className="bg-black/30 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-600 font-semibold mb-1">{tl('incomesLabel')}</p>
                        <p className="text-sm font-black text-emerald-400">${formatNumber(yearStats.income)}</p>
                      </div>
                      <div className="bg-black/30 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-600 font-semibold mb-1">{tl('expensesTitle')}</p>
                        <p className="text-sm font-black text-rose-400">${formatNumber(yearStats.expense)}</p>
                      </div>
                      <div className="bg-black/30 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-600 font-semibold mb-1">{tl('balance')}</p>
                        <p className={`text-sm font-black ${yearStats.balance >= 0 ? 'text-violet-300' : 'text-rose-400'}`}>
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
                ))}

                {/* ── Comparativa año anterior ── */}
                {ww('yearAgoComp', yearAgoComparison && (
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
                ))}

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
                              <div className="h-full bg-violet-500 rounded-full" style={{width:`${(b.pts/b.max)*100}%`}}/>
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
                {!isHidden('yearHeatmap') && yearHeatmap && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">Gastos {currentDate.getFullYear()}</p>
                      <button onClick={() => setShowAnnualModal(true)}
                        className="text-[10px] font-bold text-violet-400 active:opacity-60">
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
                        <div className="h-full bg-violet-500 rounded-l-full transition-all duration-700"
                          style={{width:`${weekendAnalysis.wdPct}%`}}/>
                        <div className="h-full bg-violet-400 rounded-r-full transition-all duration-700"
                          style={{width:`${weekendAnalysis.wePct}%`}}/>
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <div className="bg-violet-500/8 border border-violet-500/15 rounded-xl p-3 text-center">
                        <p className="text-[10px] text-zinc-500 font-semibold mb-1">Lun–Vie</p>
                        <p className="text-sm font-black text-violet-300">${priv(formatNumber(weekendAnalysis.weekday))}</p>
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
                {!isHidden('dailyBars') && dailyBars && (
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
                {!isHidden('sixMonthBars') && sixMonthBars && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-4">{tl('incomeVsExpenses')}</p>
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
                        <span className="text-[10px] text-zinc-600 font-semibold">{tl('incomesLabel')}</span>
                      </div>
                      <div className="flex items-center gap-1.5">
                        <div className="w-2.5 h-2.5 rounded-sm bg-rose-500"/>
                        <span className="text-[10px] text-zinc-600 font-semibold">{tl('expensesTitle')}</span>
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
                        <p className="text-xs font-black text-violet-300">{yearProgress.savedMonths}/{yearProgress.months.length}</p>
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
                        <p className="text-[9px] text-zinc-600 mb-1">{tl('incomesLabel')}</p>
                        <p className="text-sm font-black text-emerald-400">+${priv(formatNumber(nextMonthForecast.income))}</p>
                      </div>
                      <div className="bg-rose-500/8 rounded-2xl p-3 text-center">
                        <p className="text-[9px] text-zinc-600 mb-1">{tl('expensesTitle')}</p>
                        <p className="text-sm font-black text-rose-400">−${priv(formatNumber(nextMonthForecast.expense))}</p>
                      </div>
                      <div className={`${nextMonthForecast.balance >= 0 ? 'bg-violet-500/8' : 'bg-rose-500/8'} rounded-2xl p-3 text-center`}>
                        <p className="text-[9px] text-zinc-600 mb-1">{tl('balance')}</p>
                        <p className={`text-sm font-black ${nextMonthForecast.balance >= 0 ? 'text-violet-300' : 'text-rose-400'}`}>
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
                          <span className="text-amber-400 font-black">·${formatNumber(homeStats.expenseByCategory[cat]||0)}</span>
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
                  <div className="bg-violet-500/6 rounded-[1.5rem] p-4 border border-violet-500/15">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-base leading-none">🎯</span>
                      <p className="text-xs font-bold text-violet-300">Sugerencia de ahorro</p>
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
                                <div className="h-full bg-violet-600/50 rounded-full" style={{width:`${pct}%`}}/>
                              </div>
                            </div>
                            <span className="text-xs font-black text-violet-300 flex-shrink-0">
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
                          <p className="text-xs font-black text-violet-300">{goalETA.etaLabel}</p>
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
                              <span className={`font-black ${data.balance >= 0 ? 'text-violet-300' : 'text-rose-400'}`}>
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

                {/* Widget legacy usdSavings removido (dead code) */}

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
                          ${i === monthlyPattern.peakMonth ? 'text-rose-400' : i === currentDate.getMonth() ? 'text-violet-400' : 'text-zinc-700'}`}>
                          {l}
                        </span>
                      ))}
                    </div>
                    <div className="flex items-center justify-center gap-4 mt-2 text-[9px] text-zinc-600">
                      <span><span className="text-rose-400">■</span> Pico histórico</span>
                      <span><span className="text-violet-400">■</span> Mes actual</span>
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
                        <div key={i} className={`rounded-xl p-3 border ${m.balance >= 0 ? 'bg-violet-500/6 border-violet-500/15' : 'bg-rose-500/6 border-rose-500/15'}`}>
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
                          <p className={`text-xs font-black text-center ${m.balance >= 0 ? 'text-violet-300' : 'text-rose-400'}`}>
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
                        <span><span className="text-violet-400">■</span> 70–85%</span>
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
                            ${i === 3 ? 'bg-violet-700/12 border-violet-500/25' : 'bg-zinc-900/60 border-white/5'}`}>
                          <p className="text-[10px] text-zinc-500 mb-1">{m.label}</p>
                          <div className="mx-auto mb-1.5 rounded-sm"
                            style={{
                              width: '100%',
                              height: `${Math.round((m.amount / savingsProjection.max) * 32) + 4}px`,
                              backgroundColor: `rgba(99,102,241,${0.2 + (i / 3) * 0.5})`,
                            }}/>
                          <p className={`text-[10px] font-black ${i === 3 ? 'text-violet-300' : 'text-zinc-300'}`}>
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
                      <p className="text-xs font-bold text-zinc-300">{tl('expectedIncome')}</p>
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
                                  <div className="h-full rounded-full bg-violet-500/60"
                                    style={{width:`${Math.round((item.amount/homeStats.expenses)*100)}%`}}/>
                                </div>
                              </div>
                              <span className="text-[10px] text-zinc-400 font-semibold w-8 text-right flex-shrink-0">
                                {Math.round((item.amount/homeStats.expenses)*100)}%
                              </span>
                              <span className="text-[10px] text-violet-300 font-bold w-8 text-right flex-shrink-0">
                                {item.cumPct}%
                              </span>
                            </div>
                            {isParetoLine && i < paretoExpenses.items.length - 1 && (
                              <div className="flex items-center gap-2 my-1">
                                <div className="flex-1 h-px bg-violet-500/30"/>
                                <span className="text-[9px] text-violet-400 font-bold">80% acumulado</span>
                                <div className="flex-1 h-px bg-violet-500/30"/>
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
                        <p className="text-[10px] text-violet-400 font-semibold uppercase tracking-wide mb-1.5">✅ Activas ({categoryLifecycle.activeCats.length})</p>
                        <div className="flex flex-wrap gap-1.5">
                          {categoryLifecycle.activeCats.slice(0,5).map(cat => (
                            <span key={cat} className="text-[11px] bg-violet-500/10 text-violet-400/80 border border-violet-500/15 px-2 py-0.5 rounded-full">{cat}</span>
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
                              <div className="h-1.5 bg-violet-500 rounded-full" style={{width:`${pct}%`}}/>
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
                            <div className="h-2 bg-violet-500/70 rounded-full"
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
                          <p className="text-[10px] text-emerald-400 mb-0.5">{tl('incomesLabel')}</p>
                          <p className="text-sm font-bold text-emerald-300">{priv(`$${formatNumber(todaySummary.income)}`)}</p>
                        </div>
                      )}
                      {todaySummary.expense > 0 && (
                        <div className="flex-1 bg-rose-500/10 rounded-xl p-3 border border-rose-500/15">
                          <p className="text-[10px] text-rose-400 mb-0.5">{tl('expensesTitle')}</p>
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
                      <div className="text-[10px] text-violet-400 font-semibold uppercase">{prevMonthCompare.curr.label}</div>
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
                            <div className={`w-full rounded-md ${isToday ? 'bg-violet-500' : 'bg-zinc-700'}`} style={{height:`${h}px`}}/>
                            <span className={`text-[9px] ${isToday ? 'text-violet-400' : 'text-zinc-600'}`}>{weekOverWeek.labels[i]}</span>
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

                {/* ── Meta de ahorro mensual ── */}
                {!isHidden('monthlySavingsGoal') && monthlySavingsGoal && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">💰 Meta de ahorro mensual</p>
                      <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${monthlySavingsGoal.isOnTrack ? 'bg-emerald-500/15 text-emerald-400' : 'bg-amber-500/15 text-amber-400'}`}>
                        {monthlySavingsGoal.isOnTrack ? '✓ En camino' : 'Por debajo'}
                      </span>
                    </div>
                    <div className="flex justify-between items-end mb-2">
                      <div>
                        <p className="text-[10px] text-zinc-500 mb-0.5">Ahorrando este mes</p>
                        <p className="text-xl font-black text-white">{priv(`$${formatNumber(monthlySavingsGoal.monthly)}`)}</p>
                      </div>
                      <div className="text-right">
                        <p className="text-[10px] text-zinc-500 mb-0.5">Necesario para metas</p>
                        <p className="text-xl font-black text-zinc-400">{priv(`$${formatNumber(monthlySavingsGoal.requiredMonthly)}`)}</p>
                      </div>
                    </div>
                    <div className="w-full bg-zinc-800 rounded-full h-2.5 overflow-hidden mb-2">
                      <div className="h-2.5 rounded-full transition-all"
                        style={{width:`${monthlySavingsGoal.pct}%`, background: monthlySavingsGoal.isOnTrack ? '#10b981' : '#f59e0b'}}/>
                    </div>
                    <p className="text-[10px] text-zinc-600 text-center">
                      {monthlySavingsGoal.pct}% del objetivo · {monthlySavingsGoal.goalsCount} meta{monthlySavingsGoal.goalsCount !== 1 ? 's' : ''} activa{monthlySavingsGoal.goalsCount !== 1 ? 's' : ''} · total pendiente {priv(`$${formatNumber(monthlySavingsGoal.totalRemaining)}`)}
                    </p>
                  </div>
                )}

                {/* ── Resumen trimestral ── */}
                {!isHidden('quarterSummary') && quarterSummary && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-4">🗃️ Resumen trimestral</p>
                    <div className="grid grid-cols-3 gap-1 text-center mb-2">
                      <div/>
                      <div className="text-[10px] text-zinc-500 font-semibold">{quarterSummary.prev.label}</div>
                      <div className="text-[10px] text-violet-400 font-semibold">{quarterSummary.curr.label}</div>
                    </div>
                    {[
                      { label: 'Ingresos', prevVal: quarterSummary.prev.income,  currVal: quarterSummary.curr.income,  chg: quarterSummary.incChange, goodIfUp: true  },
                      { label: 'Gastos',   prevVal: quarterSummary.prev.expense, currVal: quarterSummary.curr.expense, chg: quarterSummary.expChange, goodIfUp: false },
                      { label: 'Balance',  prevVal: quarterSummary.prev.balance, currVal: quarterSummary.curr.balance, chg: quarterSummary.balChange, goodIfUp: true  },
                    ].map(row => {
                      const isGood = row.chg !== null && (row.goodIfUp ? row.chg >= 0 : row.chg <= 0);
                      return (
                        <div key={row.label} className="grid grid-cols-3 gap-1 items-center py-2 border-b border-white/5 last:border-0">
                          <span className="text-[11px] text-zinc-500">{row.label}</span>
                          <span className="text-[11px] text-zinc-400 text-center">{priv(`$${formatNumber(row.prevVal)}`)}</span>
                          <div className="flex items-center justify-center gap-1">
                            <span className="text-[11px] font-semibold text-zinc-200">{priv(`$${formatNumber(row.currVal)}`)}</span>
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

                {/* ── Chequeo financiero ── */}
                {!isHidden('healthCheckList') && healthCheckList && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">📋 Chequeo financiero</p>
                      <span className="text-[10px] text-zinc-500">
                        {healthCheckList.filter(c => c.ok).length}/{healthCheckList.length} OK
                      </span>
                    </div>
                    <div className="space-y-2.5">
                      {healthCheckList.map((item, i) => (
                        <div key={i} className="flex items-center gap-3">
                          <div className={`w-5 h-5 rounded-full flex items-center justify-center shrink-0 text-[10px] font-black ${item.ok ? 'bg-emerald-500/20 text-emerald-400' : 'bg-zinc-800 text-zinc-600'}`}>
                            {item.ok ? '✓' : '×'}
                          </div>
                          <span className={`text-xs ${item.ok ? 'text-zinc-300' : 'text-zinc-600'}`}>{item.label}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* ── Logros desbloqueados ── */}
                {!isHidden('achievements') && achievements && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-3">
                      <p className="text-sm font-bold text-zinc-300">🏅 Logros desbloqueados</p>
                      <span className="text-[10px] text-amber-400 bg-amber-500/10 border border-amber-500/20 px-2 py-0.5 rounded-full">
                        {achievements.length} logro{achievements.length !== 1 ? 's' : ''}
                      </span>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      {achievements.map((a, i) => (
                        <div key={i} className="flex items-center gap-1.5 bg-zinc-800 border border-white/8 rounded-xl px-3 py-2">
                          <span className="text-base">{a.emoji}</span>
                          <div>
                            <p className="text-[11px] font-semibold text-zinc-200 leading-tight">{a.label}</p>
                            <p className="text-[9px] text-zinc-500 leading-tight">{a.desc}</p>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* ── Ingresos por día de semana ── */}
                {!isHidden('incomeByDow') && incomeByDow && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-4">
                      <p className="text-sm font-bold text-zinc-300">{tl('incomePerDay')}</p>
                      <span className="text-[10px] text-zinc-600 bg-zinc-800 px-2 py-0.5 rounded-full">últ. 8 semanas</span>
                    </div>
                    <div className="flex gap-2 items-end justify-between">
                      {incomeByDow.avgs.map((avg, i) => {
                        const intensity = Math.round((avg / incomeByDow.maxAvg) * 100);
                        const isPeak = i === incomeByDow.peakDow;
                        const bg = isPeak ? 'bg-emerald-500'
                          : intensity >= 70 ? 'bg-emerald-400/60'
                          : intensity >= 30 ? 'bg-emerald-400/30'
                          : avg > 0 ? 'bg-emerald-400/15' : 'bg-zinc-800';
                        const h = avg > 0 ? Math.max(8, Math.round((avg / incomeByDow.maxAvg) * 56)) : 6;
                        return (
                          <div key={i} className="flex flex-col items-center gap-1.5 flex-1">
                            <div className={`w-full rounded-lg ${bg}`} style={{height:`${h}px`}}/>
                            <span className={`text-[10px] font-semibold ${isPeak ? 'text-emerald-400' : 'text-zinc-500'}`}>
                              {incomeByDow.labels[i]}
                            </span>
                          </div>
                        );
                      })}
                    </div>
                    <p className="text-[10px] text-zinc-600 mt-3 text-center">
                      Día pico: <span className="text-emerald-400 font-semibold">{['Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado'][incomeByDow.peakDow]}</span>
                      {' · '}<span className="text-zinc-400">{priv(`$${formatNumber(incomeByDow.avgs[incomeByDow.peakDow])}`)}</span> prom.
                    </p>
                  </div>
                )}

                {/* ── Índice de estabilidad ── */}
                {!isHidden('stabilityIndex') && stabilityIndex && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-3">🧭 Índice de estabilidad</p>
                    <div className="flex items-center gap-4 mb-4">
                      <div className="relative w-16 h-16 shrink-0">
                        <svg viewBox="0 0 64 64" className="w-16 h-16 -rotate-90">
                          <circle cx="32" cy="32" r="26" fill="none" stroke="#27272a" strokeWidth="8"/>
                          <circle cx="32" cy="32" r="26" fill="none" strokeWidth="8"
                            stroke={stabilityIndex.color}
                            strokeDasharray={`${Math.round((stabilityIndex.score/100)*163.4)} 163.4`}
                            strokeLinecap="round"/>
                        </svg>
                        <span className="absolute inset-0 flex items-center justify-center text-sm font-black" style={{color:stabilityIndex.color}}>
                          {stabilityIndex.score}
                        </span>
                      </div>
                      <div>
                        <p className="text-lg font-black" style={{color:stabilityIndex.color}}>{stabilityIndex.level}</p>
                        <p className="text-xs text-zinc-500">sobre 100 puntos</p>
                      </div>
                    </div>
                    <div className="space-y-1.5">
                      {stabilityIndex.breakdown.map((d, i) => (
                        <div key={i} className="flex items-center gap-2">
                          <span className="text-[10px] text-zinc-500 w-20 shrink-0">{d.label}</span>
                          <div className="flex-1 bg-zinc-800 rounded-full h-1.5 overflow-hidden">
                            <div className="h-1.5 rounded-full" style={{width:`${Math.round((d.pts/d.max)*100)}%`, background:stabilityIndex.color}}/>
                          </div>
                          <span className="text-[10px] text-zinc-500 w-8 text-right">{d.pts}/{d.max}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* ── Patrimonio acumulado ── */}
                {!isHidden('patrimonioAcumulado') && patrimonioData && (
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
                {!isHidden('savingsStreak') && savingsStreak >= 1 && (
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
                      <span className={`text-4xl font-black tabular-nums ${savingsStreak >= 6 ? 'text-amber-400' : savingsStreak >= 3 ? 'text-violet-400' : 'text-zinc-400'}`}>
                        {savingsStreak}
                      </span>
                    </div>
                  </div>
                )}

                {/* ── Racha de registro ── */}
                {!isHidden('registroStreak') && registroStreak >= 2 && (
                  <div className={`rounded-[1.5rem] p-4 border flex items-center gap-3
                    ${registroStreak >= 14 ? 'bg-violet-500/8 border-violet-500/20' : registroStreak >= 7 ? 'bg-violet-500/8 border-violet-500/15' : 'bg-zinc-900/30 border-white/5'}`}>
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
                      ${registroStreak >= 14 ? 'text-violet-400' : registroStreak >= 7 ? 'text-violet-400' : 'text-zinc-400'}`}>
                      {registroStreak}
                    </span>
                    <span className="text-[9px] text-zinc-600 flex-shrink-0 self-end mb-1">días</span>
                  </div>
                )}

                {/* Metas de ahorro — preview en Home */}
                {ww('goalsWidget', goals.filter(g=>!g.completed).length > 0 && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <div className="flex justify-between items-center mb-4">
                      <p className="text-sm font-bold text-zinc-300 flex items-center gap-2">
                        <Target className="w-4 h-4 text-violet-400"/> Metas
                      </p>
                      <button onClick={()=>setShowGoalsModal(true)} className="text-xs text-violet-400 font-semibold">Ver todas →</button>
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
                              <span className="text-xs font-bold text-violet-400">{pct}%</span>
                            </div>
                            <div className="h-2 bg-black/60 rounded-full overflow-hidden">
                              <div className="h-full bg-violet-600 rounded-full" style={{width:`${pct}%`}}/>
                            </div>
                            <p className="text-xs text-zinc-700">${formatNumber(g.current)} / ${formatNumber(g.target)}</p>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                ))}

                {/* Cuotas activas — preview en Home */}
                {ww('cuotasWidget', activeCuotas.length > 0 && (
                  <button onClick={()=>setShowCuotasModal(true)} className="w-full text-left">
                    <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                      <div className="flex justify-between items-center mb-3">
                        <p className="text-sm font-bold text-zinc-300 flex items-center gap-2">
                          <Wallet className="w-4 h-4 text-amber-400"/> Cuotas
                        </p>
                        <div className="text-right">
                          <p className="text-xs text-zinc-600">{activeCuotas.length} en curso</p>
                          <p className="text-sm font-black text-amber-400">{currSymbol}{formatNumber(cuotasMonthly)}/mes</p>
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
                              <span className="text-xs text-zinc-600">{rem} cuota{rem!==1?'s':''} · {CURRENCIES[c.currency||currency]?.symbol||'$'}{formatNumberWithDecimals(c.monthlyAmount)}</span>
                            </div>
                          );
                        })}
                        {activeCuotas.length > 3 && <p className="text-xs text-zinc-700 text-center">+{activeCuotas.length-3} más →</p>}
                      </div>
                    </div>
                  </button>
                ))}

                {/* Deudas — preview en Home */}
                {ww('debtsWidget', pendingDebts.length > 0 && (
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
                ))}

                {/* Tendencias 6 meses */}
                {ww('trends6m', transactions.length > 0 && (
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
                        <span className={`font-bold ${homeStats.expenses > prevMonth.expense ? 'text-rose-400' : 'text-emerald-400'}`}>
                          {homeStats.expenses > prevMonth.expense ? '▲' : '▼'}
                          {prevMonth.expense > 0 ? Math.abs(((homeStats.expenses-prevMonth.expense)/prevMonth.expense)*100).toFixed(0) : 0}%
                        </span>
                      </div>
                    )}
                  </div>
                ))}

                {/* Comparador: este mes vs mes anterior */}
                {ww('vsLastMonth', (prevMonth.income > 0 || prevMonth.expense > 0) && (
                  <div className="bg-zinc-900/40 rounded-[1.5rem] p-5 border border-white/5">
                    <p className="text-sm font-bold text-zinc-300 mb-4">Este mes vs anterior</p>
                    {[
                      { label: 'Ingresos', cur: homeStats.income,    prev: prevMonth.income,   betterIfHigher: true  },
                      { label: 'Gastos',   cur: homeStats.expenses,  prev: prevMonth.expense,  betterIfHigher: false },
                      { label: 'Balance',  cur: homeStats.available, prev: prevMonth.income - prevMonth.expense, betterIfHigher: true },
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
                ))}

                {/* Velocímetro de gastos */}
                {ww('ritmoGastos', burnRate && (
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
                ))}

                {/* Proyección fin de mes */}
                {ww('projection2', projection && (
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
                ))}

                {/* Patrimonio Neto */}
                {ww('patrimonio', (patrimonioNeto.activos > 0 || patrimonioNeto.pasivos > 0) && (
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
                          <div className="h-full bg-gradient-to-r from-emerald-500 to-violet-500 rounded-full transition-all duration-700"
                            style={{width:`${Math.min(100, (patrimonioNeto.activos / (patrimonioNeto.activos + patrimonioNeto.pasivos)) * 100).toFixed(0)}%`}}/>
                        </div>
                      )}
                    </div>
                  </div>
                ))}

                {/* Vencimientos urgentes en Home */}
                {ww('vencimientos', (billsDue.overdue.length > 0 || billsDue.today.length > 0 || billsDue.soon.length > 0) && (
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
                ))}

                {/* Nota del mes */}
                {!isHidden('notaDelMes') && (
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
                )}

                {/* ── Empty state: all widgets hidden ── */}
                {WIDGET_LIST.every(w => isHidden(w.id)) && (
                  <div className="flex flex-col items-center justify-center py-20 text-center col-span-full">
                    <span className="text-5xl mb-4">📦</span>
                    <p className="text-zinc-300 font-black text-lg mb-1">Home vacío</p>
                    <p className="text-zinc-600 text-sm mb-6">Ocultaste todos los widgets</p>
                    <button
                      onClick={() => { setHiddenWidgets(new Set()); localStorage.removeItem(HIDDEN_WIDGETS_KEY); haptic(12); }}
                      className="px-6 py-3 bg-violet-600 hover:bg-violet-500 rounded-2xl text-sm font-bold text-white active:scale-95 transition-all">
                      ✨ Mostrar todos los widgets
                    </button>
                  </div>
                )}

                {/* Empty state */}
                {monthTxs.length===0 && (
                  <div className="text-center py-10 space-y-3">
                    <div className="w-16 h-16 bg-zinc-900 rounded-full flex items-center justify-center mx-auto">
                      <ArrowUpRight className="w-7 h-7 text-zinc-700" />
                    </div>
                    <p className="text-sm font-semibold text-zinc-600">Sin movimientos en {MONTHS[currentDate.getMonth()]}</p>
                    <button onClick={()=>setActiveTab('add')} className="text-sm font-bold text-violet-400 active:opacity-60">
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
          <div className="px-4 md:px-6 pt-[calc(env(safe-area-inset-top)+16px)] space-y-4 pb-[calc(env(safe-area-inset-bottom)+100px)] max-w-lg mx-auto">
            <div className="flex items-center justify-between">
              <h2 className="text-h1 uppercase">{tl('add')}</h2>
            </div>

            {/* ── Atajos rápidos ── */}
            {templates.length > 0 && (
              <div className="space-y-2">
                <p className="text-[10px] font-bold text-zinc-600 uppercase tracking-wider ml-1">{tl('quickShortcuts')}</p>
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

            <div className="mc-card p-6 space-y-5" style={{borderRadius:'2rem'}}>
              {/* Tipo GASTO/INGRESO */}
              <div className="flex mc-card-inset p-1.5 gap-1" style={{borderRadius:'1rem'}}>
                {['GASTO','INGRESO'].map(t=>(
                  <button key={t} onClick={()=>setType(t)}
                    className={`flex-1 py-3 text-sm font-bold rounded-xl transition-all duration-200 active:scale-[0.97]
                      ${type===t
                        ?(t==='GASTO'
                          ?'bg-rose-600 text-white shadow-lg shadow-rose-900/40'
                          :'bg-emerald-600 text-white shadow-lg shadow-emerald-900/40')
                        :'text-zinc-500 hover:text-zinc-400'}`}>
                    {t === 'GASTO' ? '↓ Gasto' : '↑ Ingreso'}
                  </button>
                ))}
              </div>

              {/* Gasto en cuotas */}
              {type === 'GASTO' && (
                <button onClick={() => { setEditingCuota(null); setShowCuotaForm(true); }}
                  className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl border border-dashed border-violet-500/30 bg-violet-500/5 text-violet-400 text-xs font-bold active:scale-[0.97] transition-all">
                  <Wallet className="w-3.5 h-3.5"/> Registrar gasto en cuotas
                </button>
              )}

              {/* Monto + Moneda */}
              <div className="space-y-3">
                {/* Selector de moneda (solo muestra las monedas activas) */}
                {activeCurrencies.length > 1 && (
                  <div className="flex gap-1.5 justify-center flex-wrap">
                    {activeCurrencies.map(code => {
                      const cfg = CURRENCIES[code];
                      if (!cfg) return null;
                      return (
                        <button key={code}
                          onClick={() => { setTxCurrency(code); haptic(6); }}
                          className={`flex items-center gap-1 px-3 py-1.5 rounded-xl text-xs font-bold transition-all active:scale-95 border
                            ${txCurrency === code
                              ? 'bg-violet-600 text-white border-violet-500/40'
                              : 'bg-zinc-900/80 text-zinc-500 border-white/8'}`}>
                          <span>{cfg.flag}</span>
                          <span>{code}</span>
                        </button>
                      );
                    })}
                  </div>
                )}

                <input type="text"
                  value={amount ? (CURRENCIES[txCurrency]?.symbol || '$') + ' ' + formatNumber(amount) : ""}
                  onChange={e=>setAmount(e.target.value.replace(/\D/g,''))}
                  placeholder={`${CURRENCIES[txCurrency]?.symbol || '$'} 0`}
                  className={`w-full bg-transparent text-6xl font-black text-center focus:outline-none transition-colors
                    ${amount
                      ? type==='GASTO' ? 'text-rose-400' : 'text-emerald-400'
                      : 'placeholder:text-zinc-800'}`}
                  inputMode="numeric"
                  onKeyDown={e => { if (e.key==='Enter' && amount && category && !savingTx) { e.target.blur(); handleSaveTransaction(); } }}
 />

                {/* Preview FX cuando la moneda de la TX ≠ moneda base */}
                {txCurrency !== currency && amount && (
                  <div className="flex items-center justify-center gap-2 text-sm">
                    {txFxRate > 0 ? (
                      <span className="text-zinc-400">
                        ≈ <strong className="text-white">{currSymbol}{formatNumber(Math.round(parseFormattedNumber(amount) * txFxRate))}</strong>{' '}
                        <span className="text-zinc-600">{currency}</span>
                      </span>
                    ) : (
                      <span className="text-amber-400 text-xs">⚠️ Configurá el tipo de cambio en Ajustes</span>
                    )}
                  </div>
                )}
                {txCurrency !== currency && !amount && txFxRate <= 0 && (
                  <div className="flex items-center justify-center">
                    <span className="text-amber-400 text-xs">⚠️ Sin tipo de cambio para {txCurrency} → configurá en Ajustes</span>
                  </div>
                )}

                {/* Dictado por voz */}
                {voiceSupported && (
                  <div className="flex justify-center">
                    <button onClick={isListening ? stopListening : startListening}
                      className={`flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-bold transition-all active:scale-95
                        ${isListening
                          ? 'bg-rose-600 text-white'
                          : 'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
                      {isListening
                        ? <><MicOff className="w-3.5 h-3.5"/><span className="animate-pulse">{tl('listening')}</span></>
                        : <><Mic className="w-3.5 h-3.5"/>{tl('dictate')}</>}
                    </button>
                  </div>
                )}
              </div>

              {/* Categoría */}
              <div className="space-y-3">
                <div className="space-y-1.5">
                  <p className="text-xs font-semibold text-zinc-600 ml-1">{tl('category')}</p>
                  <div className="flex flex-wrap gap-2">
                    {activeCategories[type]?.map(c=>(
                      <button key={c} onClick={()=>setCategory(c)}
                        className={`flex items-center gap-1.5 px-3.5 py-2.5 rounded-xl text-sm font-semibold transition-all active:scale-90
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
                          className="flex-1 bg-zinc-900/80 border border-white/10 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-violet-500/40 transition-colors placeholder:text-zinc-700"
                        />
                        <button
                          onClick={() => {
                            if (inlineCatName.trim()) {
                              manageCategory('ADD', inlineCatName.trim());
                              setCategory(inlineCatName.trim());
                            }
                            setInlineCatName(''); setShowInlineCat(false);
                          }}
                          className="px-3 py-2 bg-violet-600 rounded-xl text-sm font-bold active:scale-95 transition-all">
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
                        <Plus className="w-3.5 h-3.5"/><span>{tl('newCategory')}</span>
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

              {/* Cuenta (quién pagó) */}
              {accounts.length > 0 && (
                <div className="space-y-2">
                  <p className="text-xs font-semibold text-zinc-600 ml-1">{tl('account')}</p>
                  <div className="flex flex-wrap gap-2">
                    <button
                      onClick={() => setTxAccount('')}
                      className={`px-3.5 py-2 rounded-xl text-sm font-semibold transition-all active:scale-95
                        ${!txAccount ? 'bg-violet-600 text-white shadow-md shadow-violet-950/40' : 'bg-zinc-900/80 text-zinc-400 border border-white/8'}`}>
                      {tl('noAccountSpecified')}
                    </button>
                    {accounts.map(acc => (
                      <button key={acc}
                        onClick={() => setTxAccount(acc)}
                        className={`px-3.5 py-2 rounded-xl text-sm font-semibold transition-all active:scale-95
                          ${txAccount === acc ? 'bg-violet-600 text-white shadow-md shadow-violet-900/40' : 'bg-zinc-900/80 text-zinc-400 border border-white/8'}`}>
                        {acc}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* Subcategoría */}
              {category && (() => {
                const catData = JSON.parse(localStorage.getItem('metacasa_categories') || 'null');
                const subcats = catData?.subcategories?.[category] || [];
                if (subcats.length === 0) return null;
                return (
                  <div className="space-y-2">
                    <p className="text-xs font-semibold text-zinc-600 ml-1">{tl('subcategory')}</p>
                    <div className="flex flex-wrap gap-2">
                      <button onClick={() => setTxSubcategory('')}
                        className={`px-3.5 py-2 rounded-xl text-sm font-semibold transition-all active:scale-95
                          ${!txSubcategory ? 'bg-zinc-700 text-white' : 'bg-zinc-900/80 text-zinc-400 border border-white/8'}`}>
                        {tl('general')}
                      </button>
                      {subcats.map(sc => (
                        <button key={sc} onClick={() => setTxSubcategory(sc)}
                          className={`px-3.5 py-2 rounded-xl text-sm font-semibold transition-all active:scale-95
                            ${txSubcategory === sc ? 'bg-teal-600 text-white' : 'bg-zinc-900/80 text-zinc-400 border border-white/8'}`}>
                          {sc}
                        </button>
                      ))}
                    </div>
                  </div>
                );
              })()}

              {/* Fecha */}
              <div className="space-y-2">
                <div className="flex items-center justify-between ml-1">
                  <p className="text-xs font-semibold text-zinc-600">{tl('transactionDate')}</p>
                  <div className="flex gap-1.5">
                    {[tl('today'), tl('yesterday')].map((label, i) => {
                      const d = new Date();
                      d.setDate(d.getDate() - i);
                      const dStr = d.toISOString().slice(0, 10);
                      return (
                        <button key={label} onClick={() => setTxDate(dStr)}
                          className={`px-2.5 py-1 rounded-lg text-xs font-bold transition-all active:scale-95
                            ${txDate === dStr
                              ? 'bg-violet-600 text-white'
                              : 'bg-zinc-900/80 text-zinc-500 border border-white/8'}`}>
                          {label}
                        </button>
                      );
                    })}
                  </div>
                </div>

                {/* Date picker */}
                <div className="relative cursor-pointer"
                  onClick={() => {
                    const inp = document.getElementById('tx-date-input');
                    if (inp) { inp.showPicker ? inp.showPicker() : inp.focus(); }
                  }}>
                  <input
                    id="tx-date-input"
                    type="date"
                    value={txDate}
                    onChange={e => setTxDate(e.target.value)}
                    className="absolute inset-0 w-full h-full opacity-[0.01] cursor-pointer"
                    style={{ zIndex: 20, minHeight: '60px' }}
                  />
                  <div className="w-full bg-black/60 rounded-2xl px-5 py-4 border border-white/10 flex items-center justify-between pointer-events-none select-none">
                    <div>
                      <p className="text-white font-bold text-base capitalize">
                        {new Date(txDate + 'T12:00:00').toLocaleDateString('es-AR', {
                          weekday: 'long', day: 'numeric', month: 'long',
                        })}
                      </p>
                      <p className="text-zinc-500 text-xs mt-0.5">
                        {new Date(txDate + 'T12:00:00').getFullYear()}
                      </p>
                    </div>
                    <Calendar className="w-5 h-5 text-violet-400"/>
                  </div>
                </div>
              </div>

              {/* Período del mes — INDEPENDIENTE de la fecha */}
              <div className="space-y-2">
                <div className="flex items-center justify-between ml-1">
                  <p className="text-xs font-semibold text-zinc-600">{tl('registerIn')}</p>
                  {(mesAsignado.year !== new Date(txDate + 'T12:00:00').getFullYear() ||
                    mesAsignado.month !== new Date(txDate + 'T12:00:00').getMonth()) && (
                    <span className="text-[10px] text-amber-400 font-bold">
                      {tl('diffFromReal')}
                    </span>
                  )}
                </div>
                <div className="flex gap-2">
                  {[-1, 0, 1].map(offset => {
                    const now = new Date();
                    const rawM = now.getMonth() + offset;
                    const y = now.getFullYear() + (rawM < 0 ? -1 : rawM > 11 ? 1 : 0);
                    const m = ((rawM % 12) + 12) % 12;
                    const isSelected = mesAsignado.year === y && mesAsignado.month === m;
                    return (
                      <button
                        key={offset}
                        onClick={() => { setMesAsignado({ year: y, month: m }); haptic(6); }}
                        className={`flex-1 py-3 rounded-xl text-xs font-bold transition-all active:scale-95 text-center
                          ${isSelected
                            ? 'bg-violet-600 text-white shadow-md ring-2 ring-violet-400/30'
                            : 'bg-zinc-900/80 text-zinc-500 border border-white/8'}`}>
                        <span className="block text-sm">{MONTHS[m].slice(0, 3)}</span>
                        <span className={`block text-[9px] mt-0.5 ${isSelected ? 'text-violet-200' : 'text-zinc-700'}`}>
                          {offset < 0 ? tl('previous') : offset > 0 ? tl('next') : tl('current')}
                        </span>
                      </button>
                    );
                  })}
                </div>
                {(mesAsignado.year !== new Date(txDate + 'T12:00:00').getFullYear() ||
                  mesAsignado.month !== new Date(txDate + 'T12:00:00').getMonth()) && (
                  <div className="flex items-center gap-2 bg-amber-500/8 rounded-xl px-3 py-2 border border-amber-500/20">
                    <span className="text-sm">⚠️</span>
                    <p className="text-[11px] text-amber-300 leading-tight">
                      La fecha es <strong>{new Date(txDate + 'T12:00:00').toLocaleDateString('es-AR', { day: 'numeric', month: 'short' })}</strong> pero
                      se registrará en <strong>{MONTHS[mesAsignado.month]} {mesAsignado.year}</strong>
                    </p>
                  </div>
                )}
              </div>

              {/* Nota */}
              <textarea value={note} onChange={e=>setNote(e.target.value)} placeholder={tl('optionalNote')}
                className="w-full bg-black/40 rounded-2xl p-4 border border-white/10 text-sm text-zinc-400 min-h-[80px] resize-none focus:outline-none focus:border-violet-500/40 transition-colors" />

              {/* Auto-sugerencia de categoría */}
              {catSuggestion && (
                <button onClick={()=>setCategory(catSuggestion)}
                  className="w-full flex items-center gap-2 px-4 py-3 rounded-2xl bg-violet-600/10 border border-violet-500/25 text-left active:scale-[0.98] transition-all">
                  <Sparkles className="w-4 h-4 text-violet-400 flex-shrink-0"/>
                  <span className="text-xs font-semibold text-violet-300 flex-1">
                    {tl('suggestedCat')}: <strong className="text-white">{catSuggestion}</strong>?
                  </span>
                  <span className="text-xs text-violet-500 font-bold flex-shrink-0">{tl('apply')} →</span>
                </button>
              )}

              {/* Toggle: Gasto / Ingreso fijo mensual */}
              <button
                onClick={() => { setIsFixed(v => !v); haptic(6); }}
                className={`w-full flex items-center gap-3 px-4 py-3.5 rounded-2xl border transition-all active:scale-[0.98]
                  ${isFixed
                    ? 'bg-amber-500/10 border-amber-500/30'
                    : 'bg-zinc-900/40 border-white/8'}`}>
                <span className="text-lg leading-none">📌</span>
                <div className="flex-1 text-left">
                  <p className={`text-sm font-bold ${isFixed ? 'text-amber-300' : 'text-zinc-400'}`}>
                    {type === 'GASTO' ? tl('monthlyFixed') : tl('monthlyFixedIncome')}
                  </p>
                  <p className="text-[10px] text-zinc-600 mt-0.5">
                    {isFixed ? tl('autoRegisterEachMonth') : tl('activateToReplicate')}
                  </p>
                </div>
                <div className={`w-10 h-5 rounded-full flex items-center px-0.5 transition-all flex-shrink-0 ${isFixed ? 'bg-amber-500 justify-end' : 'bg-zinc-700 justify-start'}`}>
                  <div className="w-4 h-4 rounded-full bg-white shadow-sm"/>
                </div>
              </button>

              {/* Alerta de duplicado bloqueante */}
              {dupWarning && (
                <div className="w-full p-4 rounded-2xl bg-amber-900/30 border border-amber-500/30 space-y-3">
                  <p className="text-sm text-amber-200 font-bold">⚠️ Posible duplicado</p>
                  <p className="text-xs text-amber-200/70">Ya registraste ${formatNumber(dupWarning.amount)} en {dupWarning.category} en las últimas 2 horas.</p>
                  <div className="flex gap-2">
                    <button onClick={() => { setDupWarning(null); handleSaveTransaction(true); }}
                      className="flex-1 py-2.5 rounded-xl bg-amber-600 text-white text-xs font-bold active:scale-95 transition-transform">
                      Guardar igual
                    </button>
                    <button onClick={() => setDupWarning(null)}
                      className="flex-1 py-2.5 rounded-xl bg-zinc-800 text-zinc-400 text-xs font-bold active:scale-95 transition-transform border border-white/10">
                      Cancelar
                    </button>
                  </div>
                </div>
              )}

              {/* Botón guardar */}
              <button onClick={() => handleSaveTransaction()} disabled={!amount||!category||savingTx}
                className={`w-full py-5 rounded-2xl font-bold text-sm uppercase tracking-wider active:scale-95 transition-all shadow-xl
                  ${savedOk?'bg-emerald-600':(!amount||!category)?'bg-zinc-800/50 text-zinc-600':(type==='GASTO'?'bg-rose-600':'bg-emerald-600')}
                  ${savingTx?'opacity-60':''}`}>
                {savingTx ? tl('saving') : savedOk ? tl('done') : tl('confirmRegister')}
              </button>

              {/* Guardar como atajo */}
              {amount && category && (
                <button
                  onClick={() => saveTemplate({ type, category, amount: parseInt(amount)||0, note })}
                  className="w-full py-2.5 rounded-xl bg-zinc-900/60 border border-white/8 text-xs font-bold text-zinc-500 active:text-zinc-300 active:scale-95 transition-all flex items-center justify-center gap-1.5">
                  ⚡ {tl('saveAsShortcut')}
                </button>
              )}
            </div>
          </div>
        )}

        {/* ════════════════════════════════
            TAB: HISTORIAL
        ════════════════════════════════ */}
        {activeTab==='history' && (
          <div className="pt-[calc(env(safe-area-inset-top)+16px)] space-y-3 pb-[calc(env(safe-area-inset-bottom)+90px)]">
            {/* Header */}
            <div className="px-5 flex justify-between items-center">
              <div className="flex items-center gap-2">
                <h2 className="text-h1 uppercase">{tl('history')}</h2>
                {(allMonths || selectedHistoryMonth) && !filterDate && (
                  <button onClick={() => { setAllMonths(false); setSelectedHistoryMonth(null); haptic(10); }}
                    className="text-xs font-bold text-violet-400 active:opacity-60">
                    {tl('goToToday')}
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
                  className={`p-2.5 rounded-xl active:scale-90 transition-transform ${compactView ? 'bg-violet-600 text-white' : 'bg-zinc-900 text-zinc-500 border border-white/8'}`}
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
                  placeholder={tl('search')}
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
                    className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold whitespace-nowrap bg-violet-600 text-white">
                    <Calendar className="w-3.5 h-3.5"/>
                    {(() => { const p = filterDate.split('-'); return `${p[2]}/${p[1]}/${p[0]}`; })()}
                    <X className="w-3 h-3 opacity-70"/>
                  </button>
                )}

                {/* Esta semana */}
                <button
                  onClick={() => { setFilterWeek(v => !v); if (!filterWeek) setAllMonths(true); haptic(8); }}
                  className={`flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition-all
                    ${filterWeek ? 'bg-violet-600 text-white' : 'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                  <Clock className="w-3.5 h-3.5"/>
                  {tl('thisWeek')}
                </button>

                {/* Rango de fechas */}
                <button
                  onClick={() => { setShowRangeFilter(v=>!v); haptic(8); }}
                  className={`flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition-all
                    ${(filterDateFrom || filterDateTo) ? 'bg-violet-600 text-white' : showRangeFilter ? 'bg-zinc-800 text-zinc-300 border border-white/20' : 'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                  <Calendar className="w-3.5 h-3.5"/>
                  {(filterDateFrom || filterDateTo) ? tl('activeRange') : tl('range')}
                </button>

                {/* Toggle: Fecha de registro vs Fecha real */}
                {!allMonths && (
                  <div className="flex items-center bg-zinc-900 border border-white/8 rounded-xl overflow-hidden p-0.5 gap-0.5 flex-shrink-0">
                    <button
                      onClick={()=>{ setHistoryDateMode('period'); haptic(6); }}
                      className={`px-2.5 py-1.5 rounded-[0.4rem] text-[10px] font-bold whitespace-nowrap transition-all
                        ${historyDateMode==='period' ? 'bg-violet-600 text-white' : 'text-zinc-500 hover:text-zinc-300'}`}>
                      📋 Registro
                    </button>
                    <button
                      onClick={()=>{ setHistoryDateMode('real'); haptic(6); }}
                      className={`px-2.5 py-1.5 rounded-[0.4rem] text-[10px] font-bold whitespace-nowrap transition-all
                        ${historyDateMode==='real' ? 'bg-violet-600 text-white' : 'text-zinc-500 hover:text-zinc-300'}`}>
                      📅 Real
                    </button>
                  </div>
                )}

                {/* Selector de mes */}
                {!filterDate && !filterWeek && !(filterDateFrom || filterDateTo) && (
                <button
                  onClick={()=>{ setShowHistoryMonthPicker(true); haptic(8); }}
                  className={`flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition-all
                    ${(allMonths || selectedHistoryMonth) ? 'bg-violet-600 text-white' : 'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                  <Calendar className="w-3.5 h-3.5"/>
                  {allMonths ? tl('allMonths')
                    : selectedHistoryMonth ? `${MONTHS[selectedHistoryMonth.month].slice(0,3)} ${selectedHistoryMonth.year}`
                    : `${MONTHS[currentDate.getMonth()].slice(0,3)} ${currentDate.getFullYear()}`}
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
                    : tl('amount')}
                </button>

                {/* Separador */}
                <div className="w-px bg-white/10 self-stretch my-1"/>

                {/* Tipo */}
                {['ALL','GASTO','INGRESO'].map(t=>(
                  <button key={t}
                    onClick={()=>{ setFilterType(t); setFilterCategories(new Set()); }}
                    className={`px-3.5 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition-all
                      ${filterType===t
                        ? t==='GASTO' ? 'bg-rose-600 text-white'
                          : t==='INGRESO' ? 'bg-emerald-600 text-white'
                          : 'bg-violet-600 text-white'
                        : 'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                    {t==='ALL'?tl('all'):t}
                  </button>
                ))}

                {/* Separador + botón Categorías */}
                {filterableCats.length > 0 && (
                  <>
                    <div className="w-px bg-white/10 self-stretch my-1"/>
                    <button
                      onClick={() => { setShowCatFilter(true); haptic(8); }}
                      className={`flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition-all
                        ${filterCategories.size > 0 ? 'bg-white text-black' : 'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                      <span>🏷️</span>
                      {filterCategories.size > 0 ? `${filterCategories.size} cat.` : tl('categories')}
                    </button>
                  </>
                )}

                {/* Filtro por cuenta */}
                {accounts.length > 0 && (
                  <>
                    <div className="w-px bg-white/10 self-stretch my-1"/>
                    {['', ...accounts].map(acc => (
                      <button key={acc || '__all'}
                        onClick={() => { setFilterAccount(acc); haptic(8); }}
                        className={`px-3.5 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition-all
                          ${filterAccount === acc
                            ? acc ? 'bg-violet-600 text-white' : 'bg-violet-600 text-white'
                            : 'bg-zinc-900 text-zinc-400 border border-white/8'}`}>
                        {acc || '👥 Todos'}
                      </button>
                    ))}
                  </>
                )}
              </div>
            </div>

            {/* Filtro por rango de fechas */}
            {showRangeFilter && (
              <div className="px-5">
                <div className="bg-violet-600/8 border border-violet-500/20 rounded-2xl px-4 py-3 space-y-2.5">
                  <p className="text-[10px] font-bold text-violet-400 uppercase tracking-wider">{tl('customRange')}</p>
                  <div className="flex items-center gap-2">
                    <div className="flex-1">
                      <p className="text-[10px] text-zinc-600 font-semibold mb-1">{tl('from')}</p>
                      <input type="date" value={filterDateFrom}
                        onChange={e => { setFilterDateFrom(e.target.value); setAllMonths(true); }}
                        className="w-full bg-zinc-900/60 border border-white/10 rounded-xl px-3 py-2 text-xs font-bold text-zinc-200 focus:outline-none focus:border-violet-500/40"/>
                    </div>
                    <span className="text-zinc-600 text-sm mt-4">→</span>
                    <div className="flex-1">
                      <p className="text-[10px] text-zinc-600 font-semibold mb-1">{tl('to')}</p>
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
                  <span className="text-xs text-zinc-500 font-semibold whitespace-nowrap">{tl('amount')}</span>
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
                  ? <span className="text-xs text-zinc-600">{tl('loading')}</span>
                  : <span className="text-xs text-zinc-500">{filteredTxs.length} movimiento{filteredTxs.length!==1?'s':''}</span>
                }
                {hasActiveFilters && (
                  <button onClick={clearFilters} className="text-xs text-violet-400 font-semibold ml-2 active:opacity-60">
                    {tl('clear')}
                  </button>
                )}
              </div>
              <div className="relative">
                <select
                  value={sortBy}
                  onChange={e=>setSortBy(e.target.value)}
                  className="appearance-none bg-zinc-900/60 border border-white/8 rounded-xl pl-3 pr-7 py-2 text-xs font-semibold text-zinc-400 focus:outline-none">
                  <option value="date_desc">{tl('mostRecent')}</option>
                  <option value="date_asc">{tl('oldest')}</option>
                  <option value="amount_desc">{tl('highestAmount')}</option>
                  <option value="amount_asc">{tl('lowestAmount')}</option>
                </select>
                <ArrowUpDown className="w-3 h-3 text-zinc-600 absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none"/>
              </div>
            </div>

            {/* Stats de categoría filtrada (solo cuando hay exactamente 1 seleccionada) */}
            {filterCategories.size === 1 && filteredTxs.length > 0 && !loadingData && (() => {
              const singleCat = [...filterCategories][0];
              const catColor = chartData.find(d=>d.cat===singleCat)?.color || '#6366f1';
              const total = filteredTxs.reduce((a,c)=>a+Number(c.amount),0);
              const avg = filteredTxs.length > 0 ? Math.round(total/filteredTxs.length) : 0;
              const budget = budgets[singleCat]?.amount || 0;
              return (
                <div className="px-5">
                  <div className="rounded-2xl p-4 border"
                    style={{backgroundColor:`${catColor}12`, borderColor:`${catColor}30`}}>
                    <div className="flex items-center gap-2 mb-3">
                      <div className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{backgroundColor:catColor}}/>
                      <span className="text-sm font-bold text-zinc-200">{singleCat}</span>
                      {budget > 0 && (
                        <span className="ml-auto text-xs font-semibold text-zinc-500">
                          {Math.round((total/budget)*100)}% del límite
                        </span>
                      )}
                    </div>
                    <div className="grid grid-cols-3 gap-3">
                      <div>
                        <p className="text-[10px] text-zinc-600 mb-0.5">{tl('total')}</p>
                        <p className="text-sm font-black text-white">${formatNumber(total)}</p>
                      </div>
                      <div>
                        <p className="text-[10px] text-zinc-600 mb-0.5">{tl('movements')}</p>
                        <p className="text-sm font-black text-white">{filteredTxs.length}</p>
                      </div>
                      <div>
                        <p className="text-[10px] text-zinc-600 mb-0.5">{tl('average')}</p>
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
                  <p className="text-[9px] text-zinc-500 font-semibold tracking-wider uppercase">{tl('incomes')}</p>
                  <p className="text-sm font-black text-emerald-400 mt-0.5">${formatNumber(filteredIncome)}</p>
                </div>
                <div className="bg-rose-500/10 rounded-xl p-2.5 text-center">
                  <p className="text-[9px] text-zinc-500 font-semibold tracking-wider uppercase">{tl('expenses')}</p>
                  <p className="text-sm font-black text-rose-400 mt-0.5">${formatNumber(filteredExpense)}</p>
                </div>
                <div className={`rounded-xl p-2.5 text-center ${filteredBalance >= 0 ? 'bg-violet-500/10' : 'bg-zinc-900/60'}`}>
                  <p className="text-[9px] text-zinc-500 font-semibold tracking-wider uppercase">{tl('balance')}</p>
                  <p className={`text-sm font-black mt-0.5 ${filteredBalance >= 0 ? 'text-violet-300' : 'text-rose-400'}`}>
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
                              ${isSelected ? 'ring-2 ring-violet-400' : ''}
                              ${isToday    ? 'ring-1 ring-white/30'   : ''}`}
                            style={{ backgroundColor: hasExpense ? `rgba(239,68,68,${0.08+intensity*0.52})` : hasIncome ? 'rgba(52,211,153,0.15)' : 'transparent' }}>
                            <span className={`text-[11px] font-bold leading-none
                              ${isSelected ? 'text-white' : isToday ? 'text-violet-300' : data ? 'text-zinc-200' : 'text-zinc-600'}`}>
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
                          className="font-bold text-violet-400 active:opacity-60">
                          {tl('clearDay')}
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
                    {searchQuery || hasActiveFilters ? tl('noResults') : tl('noMovementsMonth')}
                  </p>
                  {hasActiveFilters
                    ? <button onClick={clearFilters} className="text-sm font-bold text-violet-400">{tl('clear')}</button>
                    : <button onClick={()=>setActiveTab('add')} className="text-sm font-bold text-violet-400">{tl('registerOne')}</button>
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
                  if (key===today) return tl('today');
                  if (key===yesterday) return tl('yesterday');
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
                            <span className="text-label capitalize" style={{color:'#71717a'}}>{dayLabel(day)}</span>
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
                                  {t.type==='GASTO'?'−':'+'}
                                  {t.currency_original && t.currency_original !== 'ARS'
                                    ? `${CURRENCIES[t.currency_original]?.symbol||t.currency_original}${formatNumber(t.amount_original)}`
                                    : `$${formatNumber(t.amount)}`}
                                </span>
                              </button>
                            ) : (
                              /* ── Vista normal ── */
                              <div key={t.id} className="mc-card-sm border-white/[0.06]">
                                <div className="flex items-center gap-3.5 p-4">
                                  <div className={`w-11 h-11 rounded-xl flex items-center justify-center text-xl flex-shrink-0
                                    ${t.type==='INGRESO'?'bg-emerald-500/15':'bg-rose-500/15'}`}>
                                    {getEmoji(t.category)}
                                  </div>
                                  <div className="flex-1 min-w-0">
                                    <div className="flex items-center gap-1.5 flex-wrap">
                                      <p className="text-sm font-bold text-white truncate">{t.category}</p>
                                      {t.subcategory && <span className="text-[10px] bg-teal-500/15 text-teal-400 px-1.5 py-0.5 rounded-md font-semibold flex-shrink-0">{t.subcategory}</span>}
                                      {t.account && <span className="text-[10px] bg-violet-500/15 text-violet-400 px-1.5 py-0.5 rounded-md font-semibold flex-shrink-0">{t.account}</span>}
                                    </div>
                                    {t.note && <p className="text-xs text-zinc-500 italic truncate mt-0.5">"{t.note}"</p>}
                                  </div>
                                  <div className="flex items-center gap-2 flex-shrink-0">
                                    <div className="text-right">
                                      <p className={`text-lg font-black ${t.type==='INGRESO'?'amount-ingreso':'amount-gasto'}`}>
                                        {t.type==='GASTO'?'-':'+'} {t.currency_original && t.currency_original !== 'ARS'
                                          ? `${CURRENCIES[t.currency_original]?.symbol || t.currency_original} ${formatNumber(t.amount_original)}`
                                          : `$${formatNumber(t.amount)}`}
                                      </p>
                                      {t.currency_original && t.currency_original !== 'ARS' && t.amount && (
                                        <p className="text-[10px] text-zinc-500 mt-0.5">≈ ${formatNumber(t.amount)} ARS</p>
                                      )}
                                    </div>
                                    <div className="flex flex-col gap-1">
                                      <button onClick={()=>prefillFromTransaction(t)} className="p-1.5 text-zinc-700 active:text-violet-400 transition-colors" title="Copiar como nuevo">
                                        <Copy className="w-3.5 h-3.5"/>
                                      </button>
                                      <button onClick={()=>setEditingTx(t)} className="p-1.5 text-zinc-700 active:text-violet-400 transition-colors" title="Editar">
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
            TAB: ESTADÍSTICAS
        ════════════════════════════════ */}
        {activeTab==='stats' && (
          <div className="px-5 pt-[calc(env(safe-area-inset-top)+20px)] pb-10">
            {statsView==='menu' ? (
              <div className="space-y-5">
                <div className="flex items-center justify-between">
                  <div>
                    <h2 className="text-h1 uppercase">{tl('stats')}</h2>
                    <p className="text-xs text-zinc-500 mt-0.5">{MONTHS[statsDate.month]} {statsDate.year}</p>
                  </div>
                  {/* Selector de mes para estadísticas */}
                  <div className="flex items-center gap-1 mc-card-sm p-1">
                    <button onClick={() => changeStatsMonth(-1)}
                      className="w-8 h-8 flex items-center justify-center rounded-lg text-zinc-400 active:bg-zinc-700 transition-colors">
                      <ChevronLeft className="w-4 h-4"/>
                    </button>
                    <span className="text-xs font-bold text-white px-1 min-w-[60px] text-center">
                      {MONTHS[statsDate.month].slice(0,3)} {statsDate.year}
                    </span>
                    <button onClick={() => changeStatsMonth(+1)}
                      className="w-8 h-8 flex items-center justify-center rounded-lg text-zinc-400 active:bg-zinc-700 transition-colors">
                      <ChevronRight className="w-4 h-4"/>
                    </button>
                  </div>
                </div>
                <button onClick={()=>setShowReport(true)}
                  className="w-full bg-violet-700/12 border border-violet-500/30 rounded-[1.5rem] p-5 flex items-center gap-4 active:bg-violet-600/25 transition-colors">
                  <div className="w-12 h-12 bg-violet-600/30 rounded-2xl flex items-center justify-center flex-shrink-0">
                    <span className="text-2xl">📊</span>
                  </div>
                  <div className="flex-1 text-left">
                    <p className="text-sm font-black text-white">{tl('monthlyReport')}</p>
                    <p className="text-xs text-violet-300/70 mt-0.5">{tl('fullSummary')} · {MONTHS[currentDate.getMonth()]} {currentDate.getFullYear()}</p>
                  </div>
                  <ChevronRight className="w-5 h-5 text-violet-400 flex-shrink-0"/>
                </button>
                {/* Selector de cuenta — Estadísticas */}
                {accounts.length > 0 && (
                  <div className="flex gap-2 overflow-x-auto no-scrollbar -mx-1 px-1">
                    {['', ...accounts].map(acc => (
                      <button key={acc || '__all__'}
                        onClick={() => { setStatsAccount(acc); haptic(6); }}
                        className={`flex-shrink-0 px-4 py-1.5 rounded-full text-xs font-bold transition-all active:scale-95 border
                          ${statsAccount === acc
                            ? 'bg-violet-600 text-white border-violet-500/50'
                            : 'bg-zinc-900 text-zinc-500 border-white/8'}`}>
                        {acc || 'Todas'}
                      </button>
                    ))}
                  </div>
                )}
                <div className="grid grid-cols-2 gap-3">
                  <div className="glass-success p-4">
                    <p className="text-[10px] text-zinc-500 font-semibold mb-1">{tl('incomes')}</p>
                    <p className="text-lg font-black text-emerald-400">${priv(formatNumber(statsData.income))}</p>
                    <p className="text-[10px] text-zinc-600 mt-0.5">{statsData.txs.filter(t=>t.type==='INGRESO').length} movimientos</p>
                  </div>
                  <div className="glass-danger p-4">
                    <p className="text-[10px] text-zinc-500 font-semibold mb-1">{tl('expenses')}</p>
                    <p className="text-lg font-black text-rose-400">${priv(formatNumber(statsData.expenses))}</p>
                    <p className="text-[10px] text-zinc-600 mt-0.5">{statsData.txs.filter(t=>t.type==='GASTO').length} movimientos</p>
                  </div>
                </div>

                {/* Desglose por cuenta */}
                {Object.keys(statsData.byAccount).length > 1 && (
                  <div className="bg-zinc-900/40 rounded-2xl border border-white/5 p-4 space-y-3">
                    <p className="text-[10px] font-bold text-zinc-500 uppercase tracking-wider">👥 {tl('byAccount')}</p>
                    {Object.entries(statsData.byAccount).map(([acct, vals]) => (
                      <div key={acct} className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <div className="w-2 h-2 rounded-full bg-violet-500 flex-shrink-0"/>
                          <span className="text-sm font-semibold text-zinc-300">{acct}</span>
                        </div>
                        <div className="text-right">
                          {vals.expense > 0 && <p className="text-xs font-black text-rose-400">-${formatNumber(vals.expense)}</p>}
                          {vals.income > 0 && <p className="text-xs font-bold text-emerald-400">+${formatNumber(vals.income)}</p>}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
                <div>
                  <p className="text-[10px] font-semibold text-zinc-600 uppercase tracking-wider ml-1 mb-3">{tl('reports')}</p>
                  <div className="grid grid-cols-2 gap-3">
                    {[
                      { id:'gastos',      label:tl('expenses'),         icon:'🛒', color:'bg-rose-500/10 border-rose-500/20',       badge: statsData.expenses > 0 ? '$'+formatNumber(statsData.expenses) : null },
                      { id:'ingresos',    label:tl('incomes'),          icon:'💰', color:'bg-emerald-500/10 border-emerald-500/20', badge: statsData.income > 0 ? '$'+formatNumber(statsData.income) : null },
                      { id:'tendencias',  label:tl('trends'),           icon:'📈', color:'bg-violet-500/10 border-violet-500/20',   badge: null },
                      { id:'salud',       label:tl('financialHealth'),  icon:'🏥', color:'bg-violet-500/10 border-violet-500/20',   badge: healthScore ? healthScore.grade : null },
                      { id:'presupuesto', label:tl('budget'),           icon:'📋', color:'bg-amber-500/10 border-amber-500/20',     badge: budgetCoverage ? budgetCoverage.pct+'%' : null },
                      { id:'ahorro',      label:'Ahorro y metas',       icon:'🚀', color:'bg-cyan-500/10 border-cyan-500/20',       badge: null },
                    ].map(cat=>(
                      <button key={cat.id} onClick={()=>setStatsView(cat.id)}
                        className={`${cat.color} border rounded-2xl p-4 text-left active:scale-95 transition-all`}>
                        <div className="flex items-start justify-between mb-2">
                          <span className="text-2xl leading-none">{cat.icon}</span>
                          {cat.badge && <span className="text-[10px] font-black text-zinc-400">{cat.badge}</span>}
                        </div>
                        <p className="text-sm font-bold text-white">{cat.label}</p>
                        <p className="text-[10px] text-zinc-500 mt-0.5 flex items-center gap-0.5">{tl('seeDetail')} <ChevronRight className="w-3 h-3 inline"/></p>
                      </button>
                    ))}
                  </div>
                </div>
                {healthScore && (
                  <button onClick={()=>setStatsView('salud')}
                    className="w-full bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-4 flex items-center gap-4 active:bg-zinc-900/70 transition-colors">
                    <div className="w-12 h-12 rounded-2xl flex items-center justify-center flex-shrink-0" style={{background:healthScore.color+'20',border:'1px solid '+healthScore.color+'40'}}>
                      <span className="text-xl font-black" style={{color:healthScore.color}}>{healthScore.grade}</span>
                    </div>
                    <div className="flex-1 text-left">
                      <p className="text-sm font-bold text-zinc-300">{tl('financialHealth')}</p>
                      <p className="text-xs mt-0.5 font-semibold" style={{color:healthScore.color}}>{healthScore.label} · {healthScore.score}/100 pts</p>
                    </div>
                    <ChevronRight className="w-4 h-4 text-zinc-600 flex-shrink-0"/>
                  </button>
                )}
              </div>
            ) : (
              <div className="space-y-5">
                <button onClick={()=>setStatsView('menu')} className="flex items-center gap-2 text-violet-400 active:opacity-60 py-1">
                  <ChevronLeft className="w-4 h-4"/>
                  <span className="text-sm font-semibold">{tl('stats')}</span>
                </button>
                {statsView==='gastos' && (<>
                  <h3 className="text-xl font-black uppercase tracking-tight">🛒 {tl('expenses')}</h3>
                  {burnRate && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-1">{tl('spendingSpeed')}</p>
                    <p className="text-3xl font-black">${priv(formatNumber(burnRate.dailyRate))}<span className="text-sm text-zinc-500 font-semibold">/día</span></p>
                    <div className="flex gap-4 mt-3 text-xs"><span className="text-zinc-500">Proyectado: <b className="text-white">${priv(formatNumber(burnRate.projected))}</b></span>{burnRate.pct&&<span className="text-amber-400 font-bold">{burnRate.pct}% del presupuesto</span>}</div>
                    <div className="mt-3 h-1.5 bg-zinc-800 rounded-full"><div className="h-full bg-rose-500 rounded-full" style={{width:`${Math.min(100,Math.round((burnRate.daysPassed/burnRate.daysInMonth)*100))}%`}}/></div>
                    <p className="text-[10px] text-zinc-600 mt-1">Día {burnRate.daysPassed} de {burnRate.daysInMonth}</p>
                  </div>)}
                  {topTxs && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-3">{tl('topExpenses')}</p>
                    {topTxs.slice(0,5).map((t,i)=>(<div key={t.id||i} className="flex items-center gap-3 py-2 border-b border-white/5 last:border-0">
                      <span className="text-base leading-none">{getEmoji(t.category)}</span>
                      <div className="flex-1 min-w-0"><p className="text-sm font-semibold text-zinc-300 truncate">{t.note||t.category}</p><p className="text-[10px] text-zinc-600">{t.category}</p></div>
                      <p className="text-sm font-black text-rose-300">-${priv(formatNumber(t.amount))}</p>
                    </div>))}
                  </div>)}
                  {worstWeek && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-4 flex items-center gap-3">
                    <span className="text-2xl">📉</span>
                    <div><p className="text-xs text-zinc-500">{tl('worstWeek')}</p><p className="text-sm font-black text-white">${priv(formatNumber(worstWeek.total))}</p><p className="text-[10px] text-zinc-600">{worstWeek.label}</p></div>
                  </div>)}
                  {paretoExpenses && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-3">Pareto de gastos</p>
                    {paretoExpenses.items.slice(0,5).map((p,i)=>(<div key={p.cat} className="mb-2"><div className="flex justify-between mb-0.5"><span className="text-xs text-zinc-300">{i+1}. {p.cat}</span><span className="text-xs font-bold text-rose-400">{p.cumPct}%</span></div><div className="h-1 bg-zinc-800 rounded-full"><div className="h-full bg-rose-500 rounded-full" style={{width:`${Math.min(p.cumPct,100)}%`}}/></div></div>))}
                  </div>)}
                  {microSpends && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-4 flex items-center gap-3">
                    <span className="text-2xl">🐜</span>
                    <div className="flex-1"><p className="text-xs text-zinc-500">Gastos hormiga</p><p className="text-sm font-black text-white">${priv(formatNumber(microSpends.total))}</p><p className="text-[10px] text-zinc-600">{microSpends.count} transacciones &lt;${microSpends.threshold}</p></div>
                  </div>)}
                </>)}
                {statsView==='ingresos' && (<>
                  <h3 className="text-xl font-black uppercase tracking-tight">💰 {tl('incomes')}</h3>
                  <div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5 grid grid-cols-2 gap-4">
                    <div><p className="text-xs text-zinc-500">Este mes</p><p className="text-2xl font-black text-emerald-400">${priv(formatNumber(stats.income))}</p></div>
                    {prevMonth&&<div><p className="text-xs text-zinc-500">Mes anterior</p><p className="text-2xl font-black text-zinc-300">${priv(formatNumber(prevMonth.income))}</p></div>}
                  </div>
                  {incomeDiversity && incomeDiversity.length > 0 && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-3">Fuentes de ingreso</p>
                    {incomeDiversity.map(s=>(<div key={s.cat} className="mb-3"><div className="flex justify-between mb-1"><span className="text-sm text-zinc-300">{s.cat}</span><span className="text-xs font-bold text-emerald-400">{s.pct}%</span></div><div className="h-1.5 bg-zinc-800 rounded-full"><div className="h-full bg-emerald-500 rounded-full" style={{width:`${s.pct}%`}}/></div></div>))}
                  </div>)}
                  {topIncomeMonths && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-3">Mejores meses de ingreso</p>
                    {topIncomeMonths.map((m,i)=>(<div key={i} className="flex items-center gap-3 py-2 border-b border-white/5 last:border-0"><span className="text-xs text-zinc-600 w-4">{i+1}</span><p className="text-sm flex-1 text-zinc-300">{m.label}</p><p className="text-sm font-black text-emerald-400">${priv(formatNumber(m.total))}</p></div>))}
                  </div>)}
                  {savingsMomentum && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-4 flex items-center gap-3">
                    <span className="text-2xl">📈</span>
                    <div><p className="text-xs text-zinc-500">{tl('savingsMomentum')}</p><p className={`text-sm font-black ${savingsMomentum.trend==='up'?'text-emerald-400':savingsMomentum.trend==='down'?'text-rose-400':'text-zinc-300'}`}>{savingsMomentum.trend==='up'?'▲ Tendencia positiva':savingsMomentum.trend==='down'?'▼ Tendencia negativa':'→ Estable'}</p></div>
                  </div>)}
                  {incomeByDow && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-3">{tl('incomePerDay')}</p>
                    <div className="flex gap-1 items-end h-16">{incomeByDow.avgs.map((v,i)=>{const max=Math.max(...incomeByDow.avgs,1);return(<div key={i} className="flex-1 flex flex-col items-center gap-1"><div className="w-full rounded-t" style={{height:`${Math.round((v/max)*48)+4}px`,background:incomeByDow.peakDow===i?'#10b981':'#27272a'}}/><span className="text-[9px] text-zinc-600">{incomeByDow.labels[i]}</span></div>);})}
                    </div>
                  </div>)}
                </>)}
                {statsView==='tendencias' && (<>
                  <h3 className="text-xl font-black uppercase tracking-tight">📈 {tl('trends')}</h3>
                  {balanceTrend && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-1">{tl('balanceTrend')}</p>
                    <p className={`text-lg font-black ${balanceTrend.trend==='up'?'text-emerald-400':balanceTrend.trend==='down'?'text-rose-400':'text-zinc-300'}`}>{balanceTrend.trend==='up'?'▲ Balance en crecimiento':balanceTrend.trend==='down'?'▼ Balance en descenso':'→ Balance estable'}</p>
                    {balanceTrend.last3&&balanceTrend.last3.length>0&&<div className="flex gap-2 mt-3">{balanceTrend.last3.map((v,i)=>(<div key={i} className="flex-1 text-center bg-zinc-800/50 rounded-xl py-2"><p className="text-[9px] text-zinc-600 mb-1">M-{2-i}</p><p className={`text-xs font-bold ${v>=0?'text-emerald-400':'text-rose-400'}`}>{v>=0?'+':''}{formatNumber(v)}</p></div>))}</div>}
                  </div>)}
                  {weekOverWeek && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-3">{tl('weekVsWeek')}</p>
                    <div className="grid grid-cols-2 gap-4">
                      <div><p className="text-[10px] text-zinc-600">{tl('thisWeekLabel')}</p><p className="text-xl font-black text-white">${priv(formatNumber(weekOverWeek.cur))}</p></div>
                      <div><p className="text-[10px] text-zinc-600">{tl('prevWeek')}</p><p className="text-xl font-black text-zinc-400">${priv(formatNumber(weekOverWeek.prev))}</p></div>
                    </div>
                    {weekOverWeek.pct!==null&&<p className={`text-xs mt-2 font-bold ${weekOverWeek.diff>0?'text-rose-400':'text-emerald-400'}`}>{weekOverWeek.diff>0?'▲':'▼'} {Math.abs(weekOverWeek.pct)}% vs semana anterior</p>}
                  </div>)}
                  {prevMonthCompare && prevMonthCompare.items && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-3">{tl('vsLastMonth')}</p>
                    {prevMonthCompare.items.slice(0,6).map(it=>(<div key={it.cat} className="flex items-center gap-2 py-1.5 border-b border-white/5 last:border-0"><span className="text-base leading-none flex-shrink-0">{getEmoji(it.cat)}</span><p className="text-sm flex-1 text-zinc-300">{it.cat}</p><p className={`text-xs font-bold ${it.diff>0?'text-rose-400':'text-emerald-400'}`}>{it.diff>0?'+':''}{formatNumber(it.diff)}</p></div>))}
                  </div>)}
                  {weeklyHeatmap && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-3">{tl('weeklyHeatmap')}</p>
                    <div className="flex gap-1 items-end h-16">{weeklyHeatmap.avgs.map((v,i)=>{const pct=weeklyHeatmap.maxAvg>0?v/weeklyHeatmap.maxAvg:0;return(<div key={i} className="flex-1 flex flex-col items-center gap-1"><div className="w-full rounded-t" style={{height:`${Math.round(pct*48)+4}px`,background:weeklyHeatmap.peakDow===i?'#f97316':`rgba(249,115,22,${0.15+pct*0.5})`}}/><span className="text-[9px] text-zinc-500">{weeklyHeatmap.labels[i]}</span></div>);})}
                    </div>
                    <p className="text-[10px] text-zinc-600 mt-2">Pico: {weeklyHeatmap.labels[weeklyHeatmap.peakDow]} · ${priv(formatNumber(weeklyHeatmap.avgs[weeklyHeatmap.peakDow]))}/sem</p>
                  </div>)}
                  {categoryLifecycle && categoryLifecycle.length>0 && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-3">{tl('categoryCycle')}</p>
                    {categoryLifecycle.slice(0,5).map(c=>(<div key={c.cat} className="flex items-center gap-2 py-1.5 border-b border-white/5 last:border-0"><span className="text-base leading-none">{getEmoji(c.cat)}</span><p className="text-sm flex-1 text-zinc-300">{c.cat}</p><span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${c.trend==='growing'?'bg-rose-500/20 text-rose-400':c.trend==='shrinking'?'bg-emerald-500/20 text-emerald-400':'bg-zinc-800 text-zinc-400'}`}>{c.trend==='growing'?'↑ Creciendo':c.trend==='shrinking'?'↓ Bajando':'→ Estable'}</span></div>))}
                  </div>)}
                </>)}
                {statsView==='salud' && (<>
                  <h3 className="text-xl font-black uppercase tracking-tight">🏥 {tl('financialHealth')}</h3>
                  {healthScore && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-6">
                    <div className="flex items-center gap-4 mb-5">
                      <div className="w-16 h-16 rounded-2xl flex items-center justify-center" style={{background:healthScore.color+'20'}}>
                        <span className="text-3xl font-black" style={{color:healthScore.color}}>{healthScore.grade}</span>
                      </div>
                      <div>
                        <p className="text-3xl font-black text-white">{healthScore.score}<span className="text-sm text-zinc-500">/100</span></p>
                        <p className="text-sm font-bold mt-0.5" style={{color:healthScore.color}}>{healthScore.label}</p>
                      </div>
                    </div>
                    {healthScore.breakdown.map(b=>(<div key={b.label} className="flex items-center gap-3 py-2"><p className="text-xs text-zinc-400 flex-1">{b.label}</p><div className="w-20 h-1.5 bg-zinc-800 rounded-full"><div className="h-full bg-violet-500 rounded-full" style={{width:`${(b.pts/b.max)*100}%`}}/></div><p className="text-xs font-bold text-zinc-300 w-10 text-right">{b.pts}/{b.max}</p></div>))}
                  </div>)}
                  {stabilityIndex && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-2">Índice de estabilidad</p>
                    <p className="text-2xl font-black" style={{color:stabilityIndex.color}}>{stabilityIndex.score}<span className="text-sm text-zinc-500 ml-1">/100 · {stabilityIndex.level}</span></p>
                  </div>)}
                  {achievements && achievements.length>0 && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-3">{tl('achievementsUnlocked')}</p>
                    {achievements.slice(0,5).map(a=>(<div key={a.id} className="flex items-center gap-3 py-2.5 border-b border-white/5 last:border-0"><span className="text-2xl leading-none">{a.icon}</span><div><p className="text-sm font-bold text-zinc-300">{a.label}</p><p className="text-[10px] text-zinc-600">{a.desc}</p></div></div>))}
                  </div>)}
                  {noSpendStreak > 0 && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-4 flex items-center gap-3"><span className="text-2xl">🔥</span><div><p className="text-xs text-zinc-500">Racha sin gastos</p><p className="text-lg font-black text-amber-400">{noSpendStreak} mes{noSpendStreak!==1?'es':''} consecutivo{noSpendStreak!==1?'s':''}</p></div></div>)}
                  {healthCheckList && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-3">Chequeo financiero</p>
                    {healthCheckList.map(item=>(<div key={item.id} className="flex items-start gap-3 py-2 border-b border-white/5 last:border-0"><span className={`text-base leading-none mt-0.5 ${item.ok?'text-emerald-400':'text-zinc-600'}`}>{item.ok?'✅':'⭕'}</span><div><p className={`text-xs font-semibold ${item.ok?'text-zinc-300':'text-zinc-500'}`}>{item.label}</p>{item.note&&<p className="text-[10px] text-zinc-600 mt-0.5">{item.note}</p>}</div></div>))}
                  </div>)}
                </>)}
                {statsView==='presupuesto' && (<>
                  <h3 className="text-xl font-black uppercase tracking-tight">📋 {tl('budget')}</h3>
                  {budgetCoverage && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-2">Cobertura de presupuesto</p>
                    <p className={`text-3xl font-black ${budgetCoverage.pct>=100?'text-emerald-400':budgetCoverage.pct>=75?'text-amber-400':'text-rose-400'}`}>{budgetCoverage.pct}%</p>
                    <div className="mt-2 h-2 bg-zinc-800 rounded-full"><div className={`h-full rounded-full ${budgetCoverage.pct>=100?'bg-emerald-500':budgetCoverage.pct>=75?'bg-amber-500':'bg-rose-500'}`} style={{width:`${Math.min(100,budgetCoverage.pct)}%`}}/></div>
                    <p className="text-xs text-zinc-600 mt-1">${priv(formatNumber(budgetCoverage.assigned))} asignado de ${priv(formatNumber(budgetCoverage.income))}</p>
                  </div>)}
                  {rule503020 && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-3">Regla 50/30/20</p>
                    {[{label:'Necesidades (50%)',val:rule503020.needs,pct:rule503020.needsPct,color:'bg-violet-500'},{label:'Deseos (30%)',val:rule503020.wants,pct:rule503020.wantsPct,color:'bg-violet-500'},{label:'Ahorro (20%)',val:rule503020.savings,pct:rule503020.savingsPct,color:'bg-emerald-500'}].map(r=>(<div key={r.label} className="mb-3"><div className="flex justify-between text-xs mb-1"><span className="text-zinc-400">{r.label}</span><span className="font-bold text-white">${priv(formatNumber(r.val))}</span></div><div className="h-2 bg-zinc-800 rounded-full"><div className={`h-full ${r.color} rounded-full`} style={{width:`${Math.min(100,r.pct||0)}%`}}/></div></div>))}
                  </div>)}
                  {monthProjection && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-1">Proyección fin de mes</p>
                    <p className="text-2xl font-black text-white">${priv(formatNumber(monthProjection.projected))}</p>
                    <p className="text-xs text-zinc-500 mt-1">{monthProjection.daysLeft} días restantes</p>
                  </div>)}
                  {surplusAllocation && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-1">Superávit para distribuir</p>
                    <p className="text-2xl font-black text-emerald-400">${priv(formatNumber(surplusAllocation.surplus))}</p>
                    {surplusAllocation.suggestions && <div className="flex gap-2 mt-3">{surplusAllocation.suggestions.map(s=>(<div key={s.label} className="flex-1 bg-zinc-800/60 rounded-xl p-2 text-center"><p className="text-[10px] text-zinc-500">{s.label}</p><p className="text-xs font-black text-white">${formatNumber(s.amount)}</p></div>))}</div>}
                  </div>)}
                </>)}
                {statsView==='ahorro' && (<>
                  <h3 className="text-xl font-black uppercase tracking-tight">🚀 Ahorro y metas</h3>
                  {monthlySavingsGoal && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-2">Meta de ahorro mensual</p>
                    <div className="flex items-end gap-2"><p className="text-3xl font-black text-emerald-400">${priv(formatNumber(monthlySavingsGoal.actual))}</p><p className="text-sm text-zinc-500 mb-1">de ${priv(formatNumber(monthlySavingsGoal.target))}</p></div>
                    <div className="mt-2 h-2 bg-zinc-800 rounded-full"><div className={`h-full rounded-full ${monthlySavingsGoal.met?'bg-emerald-500':'bg-amber-500'}`} style={{width:`${Math.min(100,monthlySavingsGoal.pct||0)}%`}}/></div>
                    <p className={`text-xs mt-1 font-bold ${monthlySavingsGoal.met?'text-emerald-400':'text-amber-400'}`}>{monthlySavingsGoal.pct||0}% {monthlySavingsGoal.met?'✓ Meta alcanzada':'de la meta'}</p>
                  </div>)}
                  {quarterSummary && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-3">Resumen trimestral Q{quarterSummary.q} {quarterSummary.year}</p>
                    <div className="grid grid-cols-3 gap-3">
                      <div><p className="text-[10px] text-zinc-600">{tl('incomes')}</p><p className="text-base font-black text-emerald-400">${priv(formatNumber(quarterSummary.income))}</p></div>
                      <div><p className="text-[10px] text-zinc-600">{tl('expenses')}</p><p className="text-base font-black text-rose-400">${priv(formatNumber(quarterSummary.expenses))}</p></div>
                      <div><p className="text-[10px] text-zinc-600">{tl('balance')}</p><p className={`text-base font-black ${quarterSummary.balance>=0?'text-emerald-400':'text-rose-400'}`}>{quarterSummary.balance>=0?'+':''}{priv(formatNumber(quarterSummary.balance))}</p></div>
                    </div>
                  </div>)}
                  {liquidityRatio && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-4 flex items-center gap-3"><span className="text-2xl">💧</span><div><p className="text-xs text-zinc-500">Ratio de liquidez</p><p className="text-lg font-black text-white">{liquidityRatio.ratio} mes{liquidityRatio.ratio!==1?'es':''}<span className="text-xs text-zinc-500 font-normal"> cobertura</span></p></div></div>)}
                  {savingsProjection && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-2">Proyección de ahorro anual</p>
                    <p className="text-2xl font-black text-emerald-400">${priv(formatNumber(savingsProjection.projected))}</p>
                    <p className="text-xs text-zinc-600 mt-1">Manteniendo el ritmo actual</p>
                  </div>)}
                  {netPosition && (<div className="bg-zinc-900/40 rounded-[1.5rem] border border-white/5 p-5">
                    <p className="text-xs font-bold text-zinc-500 mb-1">Posición neta</p>
                    <p className={`text-2xl font-black ${netPosition.net>=0?'text-emerald-400':'text-rose-400'}`}>{netPosition.net>=0?'+':''}{priv(formatNumber(netPosition.net))}</p>
                    <div className="flex gap-4 mt-2 text-xs text-zinc-600"><span>Activos: ${priv(formatNumber(netPosition.assets))}</span><span>Deudas: ${priv(formatNumber(netPosition.liabilities))}</span></div>
                  </div>)}
                </>)}
              </div>
            )}
          </div>
        )}

        {/* ════════════════════════════════
            TAB: PRESUPUESTO
        ════════════════════════════════ */}
        {activeTab==='budget' && (
          <div className="px-4 md:px-6 lg:px-8 pt-[calc(env(safe-area-inset-top)+16px)] space-y-4 md:space-y-5 pb-[calc(env(safe-area-inset-bottom)+90px)] max-w-2xl lg:max-w-3xl mx-auto">

            {/* ── Header con selector de período ── */}
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-h1 uppercase">{tl('budget')}</h2>
                <p className="text-xs text-zinc-500 mt-0.5">Control de Gastos</p>
              </div>
              <div className="flex items-center gap-2">
                <button onClick={()=>{ setShowBudgetResumen(true); haptic(6); }}
                  className="flex items-center gap-1.5 px-3 py-1.5 bg-violet-600/15 rounded-xl border border-violet-500/25 text-sm font-bold text-violet-400 active:scale-90 transition-transform">
                  <FileText className="w-3.5 h-3.5"/>
                  Resumen
                </button>
                <button onClick={()=>setShowBudgetPeriodPicker(true)}
                  className="flex items-center gap-1.5 px-3 py-1.5 bg-zinc-900 rounded-xl border border-white/8 text-sm font-bold text-zinc-300 active:scale-90 transition-transform">
                  <Calendar className="w-3.5 h-3.5 text-zinc-500"/>
                  {MONTHS[budgetPeriod.month].slice(0,3)} {budgetPeriod.year}
                  <ChevronDown className="w-3 h-3 text-zinc-500"/>
                </button>
              </div>
            </div>

            {/* ── Selector de cuenta ── */}
            {accounts.length > 0 && (
              <div className="flex gap-2 overflow-x-auto pb-1 -mx-4 px-4">
                {['', ...personalAccounts].map(acc => (
                  <button key={acc || '__hogar__'}
                    onClick={() => { setBudgetAccount(acc); haptic(6); }}
                    className={`flex-shrink-0 px-4 py-1.5 rounded-full text-xs font-bold transition-all active:scale-95 border
                      ${budgetAccount === acc
                        ? 'bg-violet-600 text-white border-violet-500/50'
                        : 'bg-zinc-900 text-zinc-500 border-white/8'}`}>
                    {acc || '🏠 Hogar'}
                  </button>
                ))}
              </div>
            )}

            {/* ── Sección 1: Resumen del período ── */}
            {!budgetAccount ? (
              /* ══════ VISTA HOGAR: Waterfall + Distribución + Compartidos ══════ */
              <div className="space-y-4">
                {/* ── A: Waterfall Card — Ingresos del hogar ── */}
                <div className="glass-success px-5 py-5">
                  <p className="text-label mb-2">💰 Ingresos del hogar</p>
                  {accounts.map(acc => {
                    const accIncome = waterfallData.incomeByAccount[acc] || 0;
                    return accIncome > 0 ? (
                      <div key={acc} className="flex justify-between items-center py-0.5">
                        <span className="text-xs text-emerald-300/70 font-semibold">{acc}</span>
                        <span className="text-sm font-bold text-emerald-400">{currSymbol}{formatNumber(accIncome)}</span>
                      </div>
                    ) : null;
                  })}
                  <div className="flex justify-between items-center pt-2 mt-2 border-t border-emerald-500/20">
                    <span className="text-xs font-black text-emerald-200">TOTAL</span>
                    <span className="text-display text-emerald-400">{currSymbol}{formatNumber(waterfallData.totalIncome)}</span>
                  </div>
                </div>

                {/* ── Deducciones ── */}
                <div className="mc-card px-5 py-5 space-y-2">
                  <p className="text-label mb-2">📋 Deducciones</p>
                  {waterfallData.fixedExpenses > 0 && (
                    <div className="flex justify-between items-center">
                      <span className="text-xs text-zinc-500 font-semibold">Gastos fijos pagados</span>
                      <span className="text-sm font-bold text-rose-400">−{currSymbol}{formatNumber(waterfallData.fixedExpenses)}</span>
                    </div>
                  )}
                  {waterfallData.billsAndCuotas > 0 && (
                    <div className="flex justify-between items-center">
                      <span className="text-xs text-zinc-500 font-semibold">Vencimientos y cuotas</span>
                      <span className="text-sm font-bold text-rose-400">−{currSymbol}{formatNumber(waterfallData.billsAndCuotas)}</span>
                    </div>
                  )}
                  {waterfallData.savingsAmt > 0 && (
                    <div className="flex justify-between items-center">
                      <span className="text-xs text-zinc-500 font-semibold">Ahorro ({strategy.savingsPercent}%)</span>
                      <span className="text-sm font-bold text-emerald-400">−{currSymbol}{formatNumber(waterfallData.savingsAmt)}</span>
                    </div>
                  )}
                  {waterfallData.investAmt > 0 && (
                    <div className="flex justify-between items-center">
                      <span className="text-xs text-zinc-500 font-semibold">Inversión ({strategy.investmentPercent}%)</span>
                      <span className="text-sm font-bold text-violet-400">−{currSymbol}{formatNumber(waterfallData.investAmt)}</span>
                    </div>
                  )}
                  {waterfallData.sharedCategoryBudgets > 0 && (
                    <div className="flex justify-between items-center">
                      <span className="text-xs text-zinc-500 font-semibold">Presup. compartidos</span>
                      <span className="text-sm font-bold text-teal-400">−{currSymbol}{formatNumber(waterfallData.sharedCategoryBudgets)}</span>
                    </div>
                  )}
                  <div className="flex justify-between items-center pt-3 mt-2 border-t border-white/10">
                    <span className="text-xs font-black text-white">💵 SALDO A DISTRIBUIR</span>
                    <span className="text-xl font-black text-white">{currSymbol}{formatNumber(waterfallData.remainder)}</span>
                  </div>
                </div>

                {/* ── B: Distribución (editable) ── */}
                <div className="mc-card px-5 py-5 space-y-3">
                  <p className="text-label mb-1">Distribución</p>
                  {/* Mode chips */}
                  <div className="flex gap-2">
                    {[
                      { key: 'equal', label: 'Igual' },
                      { key: 'proportional', label: 'Proporcional' },
                      { key: 'custom', label: 'Manual' },
                    ].map(m => (
                      <button key={m.key}
                        onClick={() => saveAllocations({ ...allocations, mode: m.key })}
                        className={`px-3 py-1.5 rounded-full text-[11px] font-bold transition-all active:scale-95 border
                          ${(allocations.mode || 'equal') === m.key
                            ? 'bg-violet-600 text-white border-violet-500/50'
                            : 'bg-zinc-900 text-zinc-500 border-white/8'}`}>
                        {m.label}
                      </button>
                    ))}
                  </div>
                  {/* Per-person allocation */}
                  {personalAccounts.length > 0 && (
                    <div className="space-y-2">
                      {personalAccounts.map(acc => {
                        const amount = waterfallData.effectiveAllocations[acc] || 0;
                        const pct = waterfallData.remainder > 0
                          ? Math.round((amount / waterfallData.remainder) * 100)
                          : 0;
                        const isCustom = (allocations.mode || 'equal') === 'custom';
                        return (
                          <div key={acc} className="flex items-center gap-3">
                            <span className="text-xs text-zinc-400 font-semibold w-16 truncate">{acc}</span>
                            <div className="flex-1">
                              <div className="h-2 bg-zinc-800 rounded-full overflow-hidden">
                                <div className="h-full bg-violet-600 rounded-full transition-all duration-300"
                                  style={{width: `${Math.min(100, pct)}%`}}/>
                              </div>
                            </div>
                            {isCustom ? (
                              <input
                                type="text"
                                value={formatNumber(allocations.amounts?.[acc] || 0)}
                                onChange={e => {
                                  const v = parseFormattedNumber(e.target.value);
                                  saveAllocations({
                                    ...allocations,
                                    amounts: { ...(allocations.amounts || {}), [acc]: v }
                                  });
                                }}
                                className="bg-zinc-900 border border-white/8 rounded-lg text-right font-bold text-sm w-24 px-2 py-1 focus:outline-none focus:border-violet-500/60 text-white"
                                inputMode="numeric"
                              />
                            ) : (
                              <span className="text-sm font-bold text-white w-24 text-right">
                                {currSymbol}{formatNumber(amount)}
                              </span>
                            )}
                            <span className="text-[10px] text-zinc-600 font-semibold w-8 text-right">{pct}%</span>
                          </div>
                        );
                      })}
                      {/* Unallocated warning */}
                      {waterfallData.unallocated !== 0 && (
                        <div className={`flex justify-between items-center px-2 py-1.5 rounded-lg text-xs font-bold ${
                          waterfallData.unallocated < 0
                            ? 'bg-rose-500/10 text-rose-400'
                            : 'bg-amber-500/10 text-amber-400'
                        }`}>
                          <span>Sin asignar</span>
                          <span>{currSymbol}{formatNumber(waterfallData.unallocated)}</span>
                        </div>
                      )}
                    </div>
                  )}
                  {personalAccounts.length === 0 && (
                    <p className="text-xs text-zinc-600 text-center py-3">
                      No hay cuentas personales. Marcá al menos una cuenta como personal en Ajustes.
                    </p>
                  )}
                </div>

                {/* ── C: Presupuestos Compartidos (editables) ── */}
                {sharedAccounts.length > 0 && (
                  <div className="mc-card px-5 py-5 space-y-3">
                    <p className="text-label mb-1">🤝 Presupuestos compartidos</p>
                    {sharedAccounts.map(sharedAcc => (
                      <div key={sharedAcc} className="space-y-2">
                        {sharedAccounts.length > 1 && (
                          <p className="text-[10px] text-zinc-600 font-bold uppercase tracking-wider">{sharedAcc}</p>
                        )}
                        {activeCategories.GASTO.map(cat => {
                          const budKey  = `${sharedAcc}|${cat}|`;
                          const rawVal  = budgets[budKey]?.amount || 0;
                          const spent   = budgetPeriodTxs
                            .filter(t => t.account === sharedAcc && t.type === 'GASTO' && t.category === cat)
                            .reduce((a, c) => a + Number(c.amount), 0);
                          const remaining = rawVal > 0 ? rawVal - spent : null;
                          const pct     = rawVal > 0 ? Math.min(100, Math.round((spent / rawVal) * 100)) : 0;
                          const isOver  = remaining !== null && remaining < 0;
                          const barColor = isOver ? '#f43f5e' : pct > 80 ? '#f59e0b' : '#14b8a6';
                          if (rawVal === 0 && spent === 0) return null;
                          return (
                            <div key={cat}>
                              <div className="flex items-center gap-2">
                                <span className="text-sm leading-none flex-shrink-0">{getEmoji(cat)}</span>
                                <span className="text-xs text-zinc-400 flex-1 truncate">{cat}</span>
                                <span className="text-[10px] text-zinc-600 mr-1">{currSymbol}{formatNumber(spent)}</span>
                                <span className="text-zinc-700 text-[10px]">/</span>
                                <input
                                  type="text"
                                  value={formatNumber(rawVal)}
                                  onChange={async e => {
                                    const v = parseFormattedNumber(e.target.value);
                                    await updateBudget(sharedAcc, cat, '', v);
                                  }}
                                  className="bg-transparent text-right font-bold text-xs w-16 focus:outline-none focus:text-teal-400 text-zinc-500 transition-colors"
                                  inputMode="numeric" placeholder="0"
                                />
                              </div>
                              {rawVal > 0 && (
                                <div className="ml-6 mt-1">
                                  <div className="h-1 bg-zinc-800 rounded-full overflow-hidden">
                                    <div className="h-full rounded-full transition-all duration-300"
                                      style={{width:`${pct}%`, backgroundColor: barColor}}/>
                                  </div>
                                  <div className="flex justify-between text-[9px] font-semibold mt-0.5">
                                    <span className="text-zinc-600">{pct}%</span>
                                    <span className={isOver ? 'text-rose-400' : 'text-zinc-600'}>
                                      {isOver ? `⚠ −${currSymbol}${formatNumber(-remaining)}` : `${currSymbol}${formatNumber(remaining)}`}
                                    </span>
                                  </div>
                                </div>
                              )}
                              {/* Subcategorías compartidas expandibles */}
                              {(subcategories[cat] || []).length > 0 && rawVal > 0 && (
                                <>
                                  <button
                                    onClick={() => setExpandedBudgetCats(prev => {
                                      const next = new Set(prev);
                                      const key = `shared_${sharedAcc}_${cat}`;
                                      next.has(key) ? next.delete(key) : next.add(key);
                                      return next;
                                    })}
                                    className="mt-1 ml-6 flex items-center gap-1 text-[9px] text-zinc-600 active:text-zinc-400 transition-colors">
                                    <ChevronRight className={`w-2.5 h-2.5 transition-transform ${expandedBudgetCats.has(`shared_${sharedAcc}_${cat}`) ? 'rotate-90' : ''}`}/>
                                    {(subcategories[cat]||[]).length} sub
                                  </button>
                                  {expandedBudgetCats.has(`shared_${sharedAcc}_${cat}`) && (subcategories[cat] || []).map(subcat => {
                                    const subKey = `${sharedAcc}|${cat}|${subcat}`;
                                    const subRawVal = budgets[subKey]?.amount || 0;
                                    const subSpent = budgetPeriodTxs
                                      .filter(t => t.account === sharedAcc && t.type === 'GASTO' && t.category === cat && t.subcategory === subcat)
                                      .reduce((a, c) => a + Number(c.amount), 0);
                                    return (
                                      <div key={subcat} className="ml-6 mt-1 flex items-center gap-1.5">
                                        <span className="text-[10px] text-zinc-500 flex-1 truncate">{subcat}</span>
                                        <span className="text-[10px] text-zinc-600 w-12 text-right">{subSpent > 0 ? `${currSymbol}${formatNumber(subSpent)}` : '-'}</span>
                                        <span className="text-zinc-700 text-[9px]">/</span>
                                        <input type="text" value={formatNumber(subRawVal)}
                                          onChange={async e => { const v = parseFormattedNumber(e.target.value); await updateBudget(sharedAcc, cat, subcat, v); }}
                                          className="bg-transparent text-right font-bold text-[10px] w-12 focus:outline-none focus:text-teal-400 text-zinc-600 transition-colors"
                                          inputMode="numeric" placeholder="0" />
                                      </div>
                                    );
                                  })}
                                </>
                              )}
                            </div>
                          );
                        })}
                        {/* Add budget for unbudgeted shared categories */}
                        {activeCategories.GASTO.filter(cat => {
                          const rawVal = budgets[`${sharedAcc}|${cat}|`]?.amount || 0;
                          const spent = budgetPeriodTxs
                            .filter(t => t.account === sharedAcc && t.type === 'GASTO' && t.category === cat)
                            .reduce((a, c) => a + Number(c.amount), 0);
                          return rawVal === 0 && spent === 0;
                        }).length > 0 && (
                          <details className="mt-2">
                            <summary className="text-[10px] text-zinc-700 cursor-pointer hover:text-zinc-500 transition-colors">
                              + Agregar categoría compartida
                            </summary>
                            <div className="mt-1 space-y-1">
                              {activeCategories.GASTO.filter(cat => {
                                const rawVal = budgets[`${sharedAcc}|${cat}|`]?.amount || 0;
                                const spent = budgetPeriodTxs
                                  .filter(t => t.account === sharedAcc && t.type === 'GASTO' && t.category === cat)
                                  .reduce((a, c) => a + Number(c.amount), 0);
                                return rawVal === 0 && spent === 0;
                              }).map(cat => (
                                <div key={cat} className="flex items-center gap-2">
                                  <span className="text-sm leading-none">{getEmoji(cat)}</span>
                                  <span className="text-xs text-zinc-500 flex-1">{cat}</span>
                                  <input type="text" placeholder="0"
                                    onBlur={async e => {
                                      const v = parseFormattedNumber(e.target.value);
                                      if (v > 0) await updateBudget(sharedAcc, cat, '', v);
                                    }}
                                    className="bg-transparent text-right font-bold text-xs w-16 focus:outline-none focus:text-teal-400 text-zinc-600 transition-colors"
                                    inputMode="numeric" />
                                </div>
                              ))}
                            </div>
                          </details>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            ) : (
              /* ══════ VISTA CUENTA PERSONAL ══════ */
              (() => {
                const allocation = waterfallData.effectiveAllocations[budgetAccount] || 0;
                const totalBudgets = activeCategories.GASTO.reduce((acc, cat) => {
                  const mode = budgetModes[cat] || '$';
                  const raw  = budgets[`${budgetAccount}|${cat}|`]?.amount || 0;
                  return acc + (mode === '%' ? Math.round(allocation * raw / 100) : raw);
                }, 0);
                const totalExp = Object.values(budgetFilteredStats.expBycat).reduce((a,b)=>a+b, 0);
                const dispPresupuestado = allocation - totalBudgets;
                const dispReal = allocation - totalExp;
                return (
                  <div className="space-y-3">
                    {/* Card: Asignación del hogar */}
                    <div className="glass-success px-5 py-5 flex items-center justify-between">
                      <div>
                        <p className="text-label mb-1">Tu presupuesto</p>
                        <p className="text-display text-emerald-400">{currSymbol}{formatNumber(allocation)}</p>
                        <p className="text-[10px] text-zinc-600 mt-1">Asignación del hogar</p>
                      </div>
                      <ArrowUpRight className="w-8 h-8 text-emerald-600/30 flex-shrink-0"/>
                    </div>
                    {/* Cards: Disponible presupuestado + Disponible real */}
                    <div className="grid grid-cols-2 gap-3">
                      <div className={`flex flex-col gap-1 px-4 py-4
                        ${dispPresupuestado >= 0 ? 'glass-card' : 'glass-danger'}`} style={{borderRadius:'1.75rem'}}>
                        <p className="text-label">{tl('budgetedAvailable')}</p>
                        <p className={`text-amount mt-1 ${dispPresupuestado >= 0 ? 'text-white' : 'text-rose-400'}`}>
                          {currSymbol}{formatNumber(dispPresupuestado)}
                        </p>
                        <p className="text-[9px] text-zinc-700 font-semibold">{tl('accordingToPlan')}</p>
                      </div>
                      <div className={`flex flex-col gap-1 px-4 py-4
                        ${dispReal >= 0 ? 'mc-card' : 'glass-danger'}`} style={{borderRadius:'1.75rem'}}>
                        <p className="text-label">{tl('realAvailable')}</p>
                        <p className={`text-amount mt-1 ${dispReal >= 0 ? 'text-white' : 'text-rose-400'}`}>
                          {currSymbol}{formatNumber(dispReal)}
                        </p>
                        <p className="text-[9px] text-zinc-700 font-semibold">{tl('accordingToExpenses')}</p>
                      </div>
                    </div>
                  </div>
                );
              })()
            )}

            {/* ── Sección 2 y 2b: Gastos Fijos + Vencimientos ── */}
            {(() => {
              const acctFixedTxs = fixedTxs.filter(f => {
                if (f.type !== 'GASTO') return false;
                if (!budgetAccount) return true; // Hogar: mostrar todos
                return (f.account || '') === budgetAccount;
              });
              const acctFixedPaidTotal = acctFixedTxs
                .filter(f => paidItems[f.id])
                .reduce((a, c) => a + c.amount, 0);
              return (
            <>
            <div className="space-y-3">
              <div className="section-header"><p className="text-label">{tl('fixedExpenses')}</p></div>
              {acctFixedTxs.length === 0 ? (
                <div className="bg-zinc-900/40 rounded-[1.75rem] border border-white/5 px-5 py-8 text-center">
                  <p className="text-zinc-600 text-sm mb-1">{tl('noFixedExpenses')}</p>
                  <p className="text-zinc-700 text-xs">{tl('markFixedToAdd')}</p>
                </div>
              ) : (
                <>
                  <div className="mc-card overflow-hidden">
                    {acctFixedTxs.map((f,i,arr)=>{
                      const isPaid = !!paidItems[f.id];
                      return (
                        <div key={f.id} className={`flex items-center px-5 py-4 transition-all ${i<arr.length-1?'border-b border-white/[0.04]':''} ${isPaid?'opacity-40':''}`}>
                          <div className="flex items-center gap-3 flex-1 min-w-0 cursor-pointer active:opacity-60 transition-opacity"
                            onClick={() => setEditingFixedTx(f)}>
                            <span className="text-lg flex-shrink-0">{getEmoji(f.category)}</span>
                            <div className="flex-1 min-w-0">
                              <p className="text-sm font-semibold text-zinc-300 truncate">{f.category}</p>
                              <p className="text-xs text-zinc-600">
                                Día {f.dayOfMonth}{f.note ? ` · ${f.note}` : ''}
                                {!budgetAccount && f.account ? ` · ${f.account}` : ''}
                              </p>
                            </div>
                            <span className={`text-sm font-bold flex-shrink-0 mr-2 ${isPaid?'text-emerald-400 line-through decoration-emerald-600':'text-zinc-200'}`}>
                              ${formatNumber(f.amount)}
                            </span>
                          </div>
                          <button onClick={e=>{ e.stopPropagation(); togglePaidItem(f); }}
                            className={`w-6 h-6 rounded-full border-2 flex-shrink-0 flex items-center justify-center transition-all active:scale-90 ${isPaid?'bg-emerald-600 border-emerald-500':'bg-transparent border-zinc-600 active:border-zinc-400'}`}>
                            {isPaid && <Check className="w-3 h-3 text-white"/>}
                          </button>
                        </div>
                      );
                    })}
                  </div>
                  {acctFixedPaidTotal > 0 && (
                    <div className="flex justify-between items-center px-1">
                      <span className="text-xs text-zinc-600 font-semibold">{tl('paidFixed')}</span>
                      <span className="text-xs font-bold text-rose-400">${formatNumber(acctFixedPaidTotal)}</span>
                    </div>
                  )}
                </>
              )}
            </div>

            <div className="space-y-3">
              <div className="section-header">
                <div className="flex items-center gap-2">
                  <p className="text-label">{tl('billsAndInstallments')}</p>
                  {periodBudgetItems.length > 0 && (
                    <button onClick={() => setShowDueDateCalendar(true)}
                      className="p-1 rounded-lg bg-zinc-800 border border-white/8 active:scale-90 transition-transform">
                      <Calendar className="w-3.5 h-3.5 text-violet-400"/>
                    </button>
                  )}
                </div>
                {periodBudgetItems.length > 0 && (
                  <span className="text-[10px] font-bold text-rose-400 bg-rose-500/10 px-2 py-0.5 rounded-full">
                    ${formatNumber(periodBudgetItems.reduce((a,i)=>a+i.amount,0))}
                  </span>
                )}
              </div>
              {periodBudgetItems.length === 0 ? (
                <div className="bg-zinc-900/40 rounded-[1.75rem] border border-white/5 px-5 py-6 text-center">
                  <p className="text-zinc-600 text-sm">{tl('noBills')}</p>
                  <p className="text-zinc-700 text-xs mt-1">{tl('manageBillsInSettings')}</p>
                </div>
              ) : (
                <div className="mc-card overflow-hidden">
                  {periodBudgetItems.map((item, i) => {
                    const dueDate = item.dueDay
                      ? new Date(budgetPeriod.year, budgetPeriod.month, item.dueDay)
                      : null;
                    const today = new Date();
                    const isOverdue = dueDate && !item.isPaid &&
                      dueDate < new Date(today.getFullYear(), today.getMonth(), today.getDate());
                    const isDueSoon = dueDate && !item.isPaid && !isOverdue &&
                      (dueDate - new Date(today.getFullYear(), today.getMonth(), today.getDate())) <= 3 * 86400000;
                    return (
                    <div key={item.id}
                      className={`flex items-center px-5 py-4 transition-all
                        ${i < periodBudgetItems.length-1 ? 'border-b border-white/[0.04]' : ''}
                        ${item.isPaid ? 'opacity-40' : ''}`}>
                      <div className="flex items-center gap-3 flex-1 min-w-0 cursor-pointer active:opacity-60 transition-opacity"
                        onClick={() => setEditingBudgetItem(item)}>
                        <span className="text-lg flex-shrink-0">{item.emoji}</span>
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-semibold text-zinc-300 truncate">{item.name}</p>
                          <p className={`text-xs ${isOverdue ? 'text-rose-400' : isDueSoon ? 'text-amber-400' : 'text-zinc-600'}`}>
                            {item.type === 'bill'
                              ? `${item.dueDay}/${budgetPeriod.month+1}${item.isRecurring ? ' · Mensual' : ''}${isOverdue ? ' · ⚠ Vencido' : isDueSoon ? ' · Próximo' : ''}`
                              : `Cuota ${item.cuotaNum}/${item.totalCuotas}`}
                          </p>
                        </div>
                        <span className={`text-sm font-bold flex-shrink-0 mr-2
                          ${item.isPaid ? 'text-emerald-400 line-through decoration-emerald-600' : 'text-zinc-200'}`}>
                          ${formatNumber(item.amount)}
                        </span>
                      </div>
                      <button
                        onClick={e=>{ e.stopPropagation(); markPeriodItemPaid(item); }}
                        className={`w-6 h-6 rounded-full border-2 flex-shrink-0 flex items-center justify-center
                          transition-all active:scale-90
                          ${item.isPaid
                            ? 'bg-emerald-600 border-emerald-500'
                            : 'bg-transparent border-zinc-600 active:border-zinc-400'}`}>
                        {item.isPaid && <Check className="w-3 h-3 text-white"/>}
                      </button>
                    </div>
                    );
                  })}
                </div>
              )}
            </div>
            </>
              );
            })()}

            {/* ── Sección 3: Estrategia — solo visible en la cuenta asignada ── */}
            {/* savingsInvestAccount='' → visible en Hogar, savingsInvestAccount='Ariel' → visible solo en Ariel */}
            {budgetAccount === savingsInvestAccount && (
            <div className="space-y-3">
              <div className="section-header"><p className="text-label">{tl('strategy')}</p></div>
              <div className="mc-card p-5 space-y-4">
                {/* Montos de este período — siempre visible */}
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-0.5">
                    <p className="text-xs text-emerald-400 font-semibold">{tl('savingsThisPeriod')}</p>
                    <p className="text-xl font-black">{currSymbol}{formatNumber(waterfallData.savingsAmt)}</p>
                    <p className="text-[10px] text-zinc-600">{strategy.savingsPercent||0}% del ingreso hogar</p>
                  </div>
                  <div className="space-y-0.5">
                    <p className="text-xs text-violet-400 font-semibold">{tl('investmentThisPeriod')}</p>
                    <p className="text-xl font-black">{currSymbol}{formatNumber(waterfallData.investAmt)}</p>
                    <p className="text-[10px] text-zinc-600">{strategy.investmentPercent||0}% del ingreso hogar</p>
                  </div>
                </div>
                {/* Botón colapsable patrimonio histórico */}
                <button onClick={()=>setExpandHistorico(e=>!e)}
                  className="flex items-center gap-2 text-xs text-zinc-500 font-semibold w-full pt-1 border-t border-white/5 active:opacity-60 transition-opacity">
                  <TrendingUp className="w-3.5 h-3.5"/>
                  <span>Patrimonio histórico acumulado</span>
                  <ChevronDown className={`w-3 h-3 ml-auto transition-transform duration-200 ${expandHistorico?'rotate-180':''}`}/>
                </button>
                {expandHistorico && (
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-0.5">
                      <p className="text-xs text-emerald-400 font-semibold">Ahorro total</p>
                      <p className="text-lg font-black">{currSymbol}{formatNumber(stats.historicalSavingsTotal)}</p>
                    </div>
                    <div className="space-y-0.5">
                      <p className="text-xs text-violet-400 font-semibold">Inversión total</p>
                      <p className="text-lg font-black">{currSymbol}{formatNumber(stats.historicalInvestmentTotal)}</p>
                    </div>
                  </div>
                )}
              </div>
              <PrecisionSelector label="Ahorro mensual" subtext={`Este período: ${currSymbol}${formatNumber(waterfallData.savingsAmt)}`}
                value={strategy.savingsPercent||0} onChange={v=>updateStrategy('savingsPercent',v)} color="emerald" icon={PiggyBank}/>
              <PrecisionSelector label="Inversión mensual" subtext={`Este período: ${currSymbol}${formatNumber(waterfallData.investAmt)}`}
                value={strategy.investmentPercent||0} onChange={v=>updateStrategy('investmentPercent',v)} color="violet" icon={TrendingUp}/>
            </div>
            )}

            {/* ── Sección 4: Límites por categoría (solo para cuentas personales) ── */}
            {budgetAccount && (
            <div className="space-y-3">
              {(() => {
                const allocation = waterfallData.effectiveAllocations[budgetAccount] || 0;
                const totalBudgetsForAccount = activeCategories.GASTO.reduce((acc, cat) => {
                  const mode = budgetModes[cat] || '$';
                  const raw  = budgets[`${budgetAccount}|${cat}|`]?.amount || 0;
                  return acc + (mode === '%' ? Math.round(allocation * raw / 100) : raw);
                }, 0);
                const disponible = allocation - totalBudgetsForAccount;
                return (
                  <div className="section-header">
                    <p className="text-label">{tl('categoryLimits')}</p>
                    <span className={`text-xs font-bold px-2.5 py-1 rounded-full ${disponible<0?'bg-rose-500/10 text-rose-400':'bg-emerald-500/10 text-emerald-400'}`}>
                      Disponible: {currSymbol}{formatNumber(disponible)}
                    </span>
                  </div>
                );
              })()}
              {(() => {
                const filteredGastoCats = budgetAccount
                  ? activeCategories.GASTO.filter(cat => {
                      const hasExpenses = (budgetFilteredStats.expBycat[cat] || 0) > 0;
                      const hasBudget = (budgets[`${budgetAccount}|${cat}|`]?.amount || 0) > 0;
                      return hasExpenses || hasBudget;
                    })
                  : activeCategories.GASTO;
                const unlistedCats = budgetAccount
                  ? activeCategories.GASTO.filter(cat => {
                      const hasExpenses = (budgetFilteredStats.expBycat[cat] || 0) > 0;
                      const hasBudget = (budgets[`${budgetAccount}|${cat}|`]?.amount || 0) > 0;
                      return !hasExpenses && !hasBudget;
                    })
                  : [];
                return (
                  <>
              <div className="mc-card overflow-hidden">
                {filteredGastoCats.length === 0 ? (
                  <div className="px-5 py-8 text-center">
                    <p className="text-sm text-zinc-600">Sin categorías con gastos</p>
                    <p className="text-xs text-zinc-700 mt-1">Registra gastos en esta cuenta para ver categorías</p>
                  </div>
                ) : filteredGastoCats.map((cat,i)=>{
                  const spark     = catSparklines[cat];
                  const spent     = budgetFilteredStats.expBycat[cat] || 0;
                  const allocation = waterfallData.effectiveAllocations[budgetAccount] || 0;
                  const mode      = budgetModes[cat] || '$';
                  const budKey    = `${budgetAccount}|${cat}|`;
                  const rawVal    = budgets[budKey]?.amount || 0;
                  const budgetLimit = mode === '%'
                    ? Math.round(allocation * rawVal / 100)
                    : rawVal;
                  const remaining = budgetLimit > 0 ? budgetLimit - spent : null;
                  const pct       = budgetLimit > 0 ? Math.min(100, Math.round((spent/budgetLimit)*100)) : 0;
                  const isOver    = remaining !== null && remaining < 0;
                  const barColor  = isOver ? '#f43f5e' : pct > 80 ? '#f59e0b' : '#7c3aed';
                  return (
                    <div key={cat} className={`px-5 py-3.5 ${i<filteredGastoCats.length-1?'border-b border-white/5':''}`}>
                      <div className="flex items-center gap-3">
                        <div className="flex items-center gap-2 flex-1 min-w-0 cursor-pointer active:opacity-60 transition-opacity"
                          onClick={() => setDetailCat(cat)}>
                          <span className="text-lg leading-none flex-shrink-0">{getEmoji(cat)}</span>
                          <div className="min-w-0 flex-1">
                            <span className="text-sm font-semibold text-zinc-300 block truncate">{cat}</span>
                            {spark && spark.vals.some(v=>v>0) && (
                              <svg width="36" height="14" className="mt-0.5">
                                {spark.vals.map((v,idx)=>{
                                  const barH = Math.max(2, Math.round((v/spark.maxVal)*12));
                                  return <rect key={idx} x={idx*13} y={14-barH} width={10} height={barH}
                                    rx="2" fill={idx===2?'#7c3aed':'#3f3f46'}/>;
                                })}
                              </svg>
                            )}
                          </div>
                          <ChevronRight className="w-3.5 h-3.5 text-zinc-700 flex-shrink-0"/>
                        </div>
                        {/* Modo $ / % + input */}
                        <div className="flex items-center gap-1 flex-shrink-0">
                          <button onClick={()=>cycleBudgetMode(cat)}
                            className="text-[10px] font-black px-1.5 py-0.5 rounded bg-zinc-800 text-zinc-400 border border-white/5 active:scale-90 transition-transform">
                            {mode}
                          </button>
                          <input
                            type="text"
                            value={mode==='%' ? rawVal : formatNumber(rawVal)}
                            onChange={async e=>{
                              const v = mode==='%'
                                ? Math.min(100, Math.max(0, parseFloat(e.target.value)||0))
                                : parseFormattedNumber(e.target.value);
                              await updateBudget(budgetAccount, cat, '', v);
                            }}
                            className="bg-transparent text-right font-bold text-sm w-20 focus:outline-none focus:text-violet-400 transition-colors"
                            inputMode="numeric"
                          />
                          {mode==='%' && <span className="text-xs text-zinc-600">%</span>}
                        </div>
                      </div>
                      {/* Barra de progreso + resumen */}
                      {budgetLimit > 0 && (
                        <div className="space-y-1 mt-2 ml-9">
                          <div className="h-1.5 bg-zinc-800 rounded-full overflow-hidden">
                            <div className="h-full rounded-full transition-all duration-300"
                              style={{width:`${pct}%`, backgroundColor: barColor}}/>
                          </div>
                          <div className="flex justify-between text-[10px] font-semibold">
                            <span className="text-zinc-600">
                              Gastado {currSymbol}{formatNumber(spent)}
                              {mode==='%' && <span className="text-zinc-700"> (límite {currSymbol}{formatNumber(budgetLimit)})</span>}
                            </span>
                            <span className={isOver?'text-rose-400':'text-zinc-500'}>
                              {isOver ? `⚠ Excedido ${currSymbol}${formatNumber(-remaining)}` : `Sobra ${currSymbol}${formatNumber(remaining)}`}
                            </span>
                          </div>
                        </div>
                      )}
                      {/* Botón expandir subcats — filtrado por cuenta */}
                      {(() => {
                        const allSubs = subcategories[cat] || [];
                        const filteredSubs = budgetAccount
                          ? allSubs.filter(sub => {
                              const hasExp = (budgetFilteredStats.expByCatSubcat[`${cat}||${sub}`] || 0) > 0;
                              const hasBud = (budgets[`${budgetAccount}|${cat}|${sub}`]?.amount || 0) > 0;
                              return hasExp || hasBud;
                            })
                          : allSubs;
                        if (filteredSubs.length === 0) return null;
                        return (
                          <>
                        <button
                          onClick={() => setExpandedBudgetCats(prev => {
                            const next = new Set(prev);
                            next.has(cat) ? next.delete(cat) : next.add(cat);
                            return next;
                          })}
                          className="mt-2 ml-9 flex items-center gap-1 text-[10px] text-zinc-600 active:text-zinc-400 transition-colors">
                          <ChevronRight className={`w-3 h-3 transition-transform ${expandedBudgetCats.has(cat) ? 'rotate-90' : ''}`}/>
                          {expandedBudgetCats.has(cat) ? 'Ocultar subcategorías' : `${filteredSubs.length} subcategoría${filteredSubs.length !== 1 ? 's' : ''}`}
                        </button>
                          </>
                        );
                      })()}
                      {/* Filas de subcategorías expandidas */}
                      {expandedBudgetCats.has(cat) && (() => {
                        const allSubs = subcategories[cat] || [];
                        const filteredSubs = budgetAccount
                          ? allSubs.filter(sub => {
                              const hasExp = (budgetFilteredStats.expByCatSubcat[`${cat}||${sub}`] || 0) > 0;
                              const hasBud = (budgets[`${budgetAccount}|${cat}|${sub}`]?.amount || 0) > 0;
                              return hasExp || hasBud;
                            })
                          : allSubs;
                        return filteredSubs;
                      })().map(subcat => {
                        const subKey    = `${budgetAccount}|${cat}|${subcat}`;
                        const subRawVal = budgets[subKey]?.amount || 0;
                        const subSpent  = budgetFilteredStats.expByCatSubcat[`${cat}||${subcat}`] || 0;
                        const subLimit  = subRawVal;
                        const subPct    = subLimit > 0 ? Math.min(100, Math.round((subSpent / subLimit) * 100)) : 0;
                        const subOver   = subLimit > 0 && subSpent > subLimit;
                        return (
                          <div key={subcat} className="ml-9 mt-2 pb-2 border-b border-white/5 last:border-0">
                            <div className="flex items-center gap-2">
                              <span className="text-xs text-zinc-400 flex-1 truncate">{subcat}</span>
                              <span className="text-xs text-zinc-600 mr-1">{currSymbol}{formatNumber(subSpent)}</span>
                              <input
                                type="text"
                                value={subRawVal ? formatNumber(subRawVal) : ''}
                                onChange={async e => {
                                  const v = parseFormattedNumber(e.target.value);
                                  await updateBudget(budgetAccount, cat, subcat, v);
                                }}
                                placeholder="—"
                                className="bg-transparent text-right font-bold text-xs w-16 focus:outline-none focus:text-violet-400 transition-colors text-zinc-500 placeholder-zinc-700"
                                inputMode="numeric"
                              />
                            </div>
                            {subLimit > 0 && (
                              <div className="h-1 bg-zinc-800 rounded-full overflow-hidden mt-1">
                                <div className="h-full rounded-full transition-all duration-300"
                                  style={{width:`${subPct}%`, backgroundColor: subOver ? '#f43f5e' : '#7c3aed'}}/>
                              </div>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  );
                })}
              </div>
              {/* Categorías sin gastos — agregar manualmente */}
              {unlistedCats.length > 0 && (
                <details className="mt-2">
                  <summary className="text-[11px] text-zinc-600 font-semibold cursor-pointer active:text-zinc-400 transition-colors px-1">
                    + {unlistedCats.length} categoría{unlistedCats.length !== 1 ? 's' : ''} sin gastos
                  </summary>
                  <div className="mc-card overflow-hidden mt-1.5">
                    {unlistedCats.map((cat, i) => (
                      <div key={cat} className={`flex items-center px-5 py-3 gap-3 ${i < unlistedCats.length - 1 ? 'border-b border-white/5' : ''}`}>
                        <span className="text-lg leading-none flex-shrink-0">{getEmoji(cat)}</span>
                        <span className="text-sm text-zinc-500 flex-1 truncate">{cat}</span>
                        <input
                          type="text"
                          value=""
                          onChange={async e => {
                            const v = parseFormattedNumber(e.target.value);
                            await updateBudget(budgetAccount, cat, '', v);
                          }}
                          placeholder="—"
                          className="bg-transparent text-right font-bold text-sm w-20 focus:outline-none focus:text-violet-400 transition-colors text-zinc-500 placeholder-zinc-700"
                          inputMode="numeric"
                        />
                      </div>
                    ))}
                  </div>
                </details>
              )}
                  </>
                );
              })()}
              {/* Botón Sugerir */}
              <button onClick={suggestBudgets}
                className="w-full py-3.5 bg-violet-700/12 border border-violet-500/25 rounded-2xl text-sm font-semibold text-violet-400 active:bg-violet-600/25 transition-colors flex items-center justify-center gap-2">
                <span className="text-base leading-none">🪄</span>
                {tl('suggestFromHistory')}
              </button>
            </div>
            )}
          </div>
        )}

        {/* ══════════════════════════════════════════════════════════════
            TAB: BILLETERAS
        ══════════════════════════════════════════════════════════════ */}
        {activeTab==='billeteras' && (
          <div className="flex-1 overflow-y-auto pb-32 px-5 pt-[calc(env(safe-area-inset-top)+20px)]">
            {/* Header */}
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-h1 uppercase">Billeteras</h2>
                <p className="text-xs text-zinc-500 mt-0.5">Conectá tus cuentas y PSPs</p>
              </div>
              <button onClick={() => { setShowWalletConnect(true); setWalletConnectStep(1); }}
                className="w-10 h-10 bg-violet-600 rounded-2xl flex items-center justify-center active:scale-95 transition-transform shadow-lg shadow-violet-950/40">
                <Plus className="w-5 h-5 text-white"/>
              </button>
            </div>

            {/* Total balance card */}
            {wallets.length > 0 && (() => {
              const total = wallets.reduce((s, w) => s + Number(w.balance || 0), 0);
              return (
                <div className="mx-5 mb-4 glass-card p-5" style={{borderRadius:'1.75rem'}}>
                  <p className="text-xs text-violet-300 uppercase tracking-wider font-semibold mb-1">Saldo total en billeteras</p>
                  <p className="text-3xl font-black text-white">{fmtMoney(total)}</p>
                  <p className="text-xs text-zinc-500 mt-1">{wallets.length} billetera{wallets.length !== 1 ? 's' : ''} conectada{wallets.length !== 1 ? 's' : ''}</p>
                </div>
              );
            })()}

            {/* Wallet cards */}
            <div className="px-5 space-y-3">
              {wallets.map(wallet => {
                const provDef = WALLET_PROVIDERS[wallet.provider] || WALLET_PROVIDERS.manual;
                const isSyncing = syncingWalletId === wallet.id;
                const isEditing = editingWalletBalance?.id === wallet.id;
                return (
                  <div key={wallet.id} className={`rounded-3xl border ${provDef.borderClass} ${provDef.bgClass} overflow-hidden`}>
                    {/* Card header */}
                    <div className="px-5 py-4 flex items-center gap-3">
                      <div className="w-11 h-11 flex-shrink-0">
                        <WalletLogo provider={wallet.provider} size={44} className="rounded-2xl"/>
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="font-black text-sm truncate">{wallet.name}</p>
                        <p className={`text-xs ${provDef.textClass} font-semibold`}>{provDef.name}</p>
                        {wallet.last_sync && (
                          <p className="text-[10px] text-zinc-600 mt-0.5">
                            Actualizado {new Date(wallet.last_sync).toLocaleDateString('es-AR',{day:'numeric',month:'short',hour:'2-digit',minute:'2-digit'})}
                          </p>
                        )}
                      </div>
                      <div className="text-right flex-shrink-0">
                        {isEditing ? (
                          <div className="flex items-center gap-2">
                            <input
                              type="text" inputMode="numeric"
                              value={editBalanceVal}
                              onChange={e => { const r=e.target.value.replace(/\D/g,''); setEditBalanceVal(r?r.replace(/\B(?=(\d{3})+(?!\d))/g,'.'):''); }}
                              className="w-24 bg-zinc-900 border border-white/10 rounded-xl px-2 py-1 text-sm font-black text-right focus:outline-none focus:border-violet-500/60"
                              autoFocus
                              onBlur={() => { setEditingWalletBalance(null); setEditBalanceVal(''); }}
                            />
                            <button
                              onMouseDown={e => { e.preventDefault(); saveWalletBalance(wallet); }}
                              className="w-7 h-7 bg-violet-600 rounded-xl flex items-center justify-center active:scale-95">
                              <Check className="w-4 h-4 text-white"/>
                            </button>
                          </div>
                        ) : (
                          <button onClick={() => { setEditingWalletBalance(wallet); setEditBalanceVal(formatNumber(wallet.balance||0)); }}
                            className="text-right active:opacity-70">
                            <p className="text-base font-black text-white">{fmtMoney(wallet.balance || 0)}</p>
                            <p className="text-[10px] text-zinc-600">toca para editar</p>
                          </button>
                        )}
                      </div>
                    </div>
                    {/* Actions */}
                    <div className="flex border-t border-white/5">
                      <button onClick={() => { setSelectedWallet(wallet); loadWalletMovements(wallet.id); }}
                        className="flex-1 flex items-center justify-center gap-1.5 py-3 text-xs font-semibold text-zinc-400 active:bg-white/5 transition-colors">
                        <History className="w-3.5 h-3.5"/>Movimientos
                      </button>
                      <div className="w-px bg-white/5"/>
                      {!provDef.comingSoon && (
                        <>
                          <button onClick={() => syncWallet(wallet)} disabled={isSyncing}
                            className="flex-1 flex items-center justify-center gap-1.5 py-3 text-xs font-semibold text-zinc-400 active:bg-white/5 transition-colors disabled:opacity-50">
                            <RefreshCw className={`w-3.5 h-3.5 ${isSyncing ? 'animate-spin' : ''}`}/>
                            {isSyncing ? 'Sincronizando...' : 'Sincronizar'}
                          </button>
                          <div className="w-px bg-white/5"/>
                        </>
                      )}
                      <button onClick={() => disconnectWallet(wallet.id)}
                        className="flex-1 flex items-center justify-center gap-1.5 py-3 text-xs font-semibold text-red-500/70 active:bg-red-500/5 transition-colors">
                        <X className="w-3.5 h-3.5"/>Quitar
                      </button>
                    </div>
                  </div>
                );
              })}

              {/* Empty state */}
              {wallets.length === 0 && (
                <div className="text-center py-16 px-6">
                  <div className="w-16 h-16 mc-card rounded-3xl flex items-center justify-center mx-auto mb-4">
                    <Wallet className="w-8 h-8 text-zinc-700"/>
                  </div>
                  <p className="text-zinc-400 font-bold mb-1">Sin billeteras conectadas</p>
                  <p className="text-zinc-600 text-sm mb-6">Conectá Mercado Pago, PayPal o creá una cuenta manual para trackear tu saldo</p>
                  <button onClick={() => { setShowWalletConnect(true); setWalletConnectStep(1); }}
                    className="px-6 py-3 bg-violet-600 rounded-2xl font-black text-sm active:scale-95 transition-transform">
                    + Conectar billetera
                  </button>
                </div>
              )}
            </div>
          </div>
        )}

        {/* ════════════════════════════════
            TAB: AJUSTES
        ════════════════════════════════ */}
        {activeTab==='settings' && (
          <div className="px-5 pt-[calc(env(safe-area-inset-top)+20px)] space-y-6 pb-[calc(env(safe-area-inset-bottom)+100px)]">
            {/* Header con botón volver */}
            <div className="flex items-center gap-3">
              <button onClick={()=>setActiveTab('home')} className="p-2 bg-zinc-900 rounded-xl active:scale-90 transition-transform">
                <ChevronLeft className="w-5 h-5 text-zinc-400"/>
              </button>
              <h2 className="text-h1 uppercase">{tl('settings')}</h2>
            </div>

            {/* ═══ SECCIÓN: GESTIÓN FINANCIERA ═══ */}
            <div className="space-y-2">
              <p className="text-[10px] font-black uppercase tracking-widest text-violet-400 ml-1">Gestión financiera</p>
              <div className="mc-card overflow-hidden divide-y divide-white/5">
                <button onClick={()=>setShowCuotasModal(true)} className="flex items-center gap-3 px-4 py-3.5 w-full active:bg-zinc-900/60 transition-colors">
                  <Wallet className="w-4 h-4 text-amber-400 flex-shrink-0"/>
                  <span className="text-sm font-semibold text-zinc-300 flex-1 text-left">{tl('manageInstallments')}</span>
                  {activeCuotas.length>0 && <span className="bg-amber-500 text-black text-[10px] font-black px-2 py-0.5 rounded-full">{activeCuotas.length}</span>}
                  <ChevronRight className="w-4 h-4 text-zinc-700"/>
                </button>
                <button onClick={()=>setShowGoalsModal(true)} className="flex items-center gap-3 px-4 py-3.5 w-full active:bg-zinc-900/60 transition-colors">
                  <Target className="w-4 h-4 text-violet-400 flex-shrink-0"/>
                  <span className="text-sm font-semibold text-zinc-300 flex-1 text-left">{tl('manageSavingsGoals')}</span>
                  {goals.length>0 && <span className="bg-violet-600 text-white text-[10px] font-black px-2 py-0.5 rounded-full">{goals.length}</span>}
                  <ChevronRight className="w-4 h-4 text-zinc-700"/>
                </button>
                <button onClick={()=>setShowDebtsModal(true)} className="flex items-center gap-3 px-4 py-3.5 w-full active:bg-zinc-900/60 transition-colors">
                  <span className="text-base leading-none flex-shrink-0">🤝</span>
                  <span className="text-sm font-semibold text-zinc-300 flex-1 text-left">{tl('manageDebts')}</span>
                  {pendingDebts.length>0 && <span className="bg-emerald-600 text-white text-[10px] font-black px-2 py-0.5 rounded-full">{pendingDebts.length}</span>}
                  <ChevronRight className="w-4 h-4 text-zinc-700"/>
                </button>
                <button onClick={()=>setShowRecurringModal(true)} className="flex items-center gap-3 px-4 py-3.5 w-full active:bg-zinc-900/60 transition-colors">
                  <RefreshCw className="w-4 h-4 text-violet-400 flex-shrink-0"/>
                  <span className="text-sm font-semibold text-zinc-300 flex-1 text-left">{tl('recurringMovements')}</span>
                  {recurring.length > 0 && <span className="bg-violet-600 text-white text-[10px] font-black px-2 py-0.5 rounded-full">{recurring.length}</span>}
                  <ChevronRight className="w-4 h-4 text-zinc-700"/>
                </button>
                <button onClick={()=>setShowBillsModal(true)} className="flex items-center gap-3 px-4 py-3.5 w-full active:bg-zinc-900/60 transition-colors">
                  <Bell className="w-4 h-4 text-zinc-400 flex-shrink-0"/>
                  <span className="text-sm font-semibold text-zinc-300 flex-1 text-left">{tl('billsAndAlerts')}</span>
                  {urgentCount > 0 && <span className="bg-rose-500 text-white text-[10px] font-black px-2 py-0.5 rounded-full">{urgentCount}</span>}
                  <ChevronRight className="w-4 h-4 text-zinc-700"/>
                </button>
              </div>
            </div>

            {/* ═══ SECCIÓN: CATEGORÍAS Y REPORTES ═══ */}
            <div className="space-y-2">
              <p className="text-[10px] font-black uppercase tracking-widest text-violet-400 ml-1">Categorías y reportes</p>
              <div className="mc-card overflow-hidden divide-y divide-white/5">
                <button onClick={()=>setShowCatManager(true)} className="flex items-center gap-3 px-4 py-3.5 w-full active:bg-zinc-900/60 transition-colors">
                  <span className="text-base leading-none flex-shrink-0">🏷️</span>
                  <span className="text-sm font-semibold text-zinc-300 flex-1 text-left">{tl('editCategories')}</span>
                  <ChevronRight className="w-4 h-4 text-zinc-700"/>
                </button>
                <button onClick={()=>setShowBudgetModal(true)} className="flex items-center gap-3 px-4 py-3.5 w-full active:bg-zinc-900/60 transition-colors">
                  <span className="text-base leading-none flex-shrink-0">🥧</span>
                  <span className="text-sm font-semibold text-zinc-300 flex-1 text-left">{tl('viewExpenseChart')}</span>
                  <ChevronRight className="w-4 h-4 text-zinc-700"/>
                </button>
                <button onClick={()=>setShowReport(true)} className="flex items-center gap-3 px-4 py-3.5 w-full active:bg-zinc-900/60 transition-colors">
                  <FileText className="w-4 h-4 text-violet-400 flex-shrink-0"/>
                  <span className="text-sm font-semibold text-zinc-300 flex-1 text-left">Reporte de {MONTHS[currentDate.getMonth()]}</span>
                  <ChevronRight className="w-4 h-4 text-zinc-700"/>
                </button>
                <button onClick={()=>setShowAnnualModal(true)} className="flex items-center gap-3 px-4 py-3.5 w-full active:bg-zinc-900/60 transition-colors">
                  <BarChart3 className="w-4 h-4 text-violet-400 flex-shrink-0"/>
                  <span className="text-sm font-semibold text-zinc-300 flex-1 text-left">Vista anual {currentDate.getFullYear()}</span>
                  <ChevronRight className="w-4 h-4 text-zinc-700"/>
                </button>
                <button onClick={()=>{ haptic(10); setShowCompareModal(true); }} className="flex items-center gap-3 px-4 py-3.5 w-full active:bg-zinc-900/60 transition-colors">
                  <span className="text-base leading-none flex-shrink-0">⚖️</span>
                  <span className="text-sm font-semibold text-zinc-300 flex-1 text-left">Comparar dos meses</span>
                  <ChevronRight className="w-4 h-4 text-zinc-700"/>
                </button>
              </div>
            </div>

            {/* ═══ SECCIÓN: PREFERENCIAS ═══ */}
            <div className="space-y-2">
              <p className="text-[10px] font-black uppercase tracking-widest text-violet-400 ml-1">Preferencias</p>
            </div>
            {/* ── IDIOMA ── */}
            <div className="space-y-3">
              <p className="text-label ml-1">🌐 Idioma / Language</p>
              <div className="mc-card p-4">
                <div className="flex gap-2">
                  {[{code:'es',label:'🇦🇷 Español'},{code:'en',label:'🇺🇸 English'}].map(l => (
                    <button key={l.code} onClick={() => changeLang(l.code)}
                      className={`flex-1 py-3 rounded-xl text-sm font-bold transition-all active:scale-95
                        ${lang === l.code ? 'bg-violet-600 text-white shadow-md' : 'bg-zinc-800 text-zinc-400 border border-white/8'}`}>
                      {l.label}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            {/* ── APARIENCIA ── */}
            <div className="space-y-3">
              <p className="text-label ml-1">🎨 Apariencia</p>
              <div className="mc-card p-4">
                <div className="flex gap-2">
                  {[
                    { key: 'dark',  label: '🌙 Oscuro' },
                    { key: 'light', label: '☀️ Claro' },
                    { key: 'auto',  label: '⚙️ Auto' },
                  ].map(t => (
                    <button key={t.key} onClick={() => saveTheme(t.key)}
                      className={`flex-1 py-3 rounded-xl text-sm font-bold transition-all active:scale-95
                        ${appTheme === t.key ? 'bg-violet-600 text-white shadow-md' : 'bg-zinc-800 text-zinc-400 border border-white/8'}`}>
                      {t.label}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            {/* ── MONEDA BASE ── */}
            <div className="space-y-3">
              <p className="text-label ml-1">💰 Moneda base</p>
              <div className="mc-card p-4 space-y-4">
                <p className="text-[11px] text-zinc-500 leading-relaxed">
                  Tu moneda principal. Todos los movimientos se guardan en esta moneda. Si registrás un pago en otra moneda, se convierte automáticamente.
                </p>

                {/* Grilla de monedas activas */}
                <div className="flex flex-wrap gap-2">
                  {activeCurrencies.map(code => {
                    const cfg = CURRENCIES[code];
                    if (!cfg) return null;
                    const isBase = currency === code;
                    return (
                      <div key={code} className="relative">
                        <button onClick={() => changeCurrency(code)}
                          className={`flex flex-col items-center px-3 py-2.5 rounded-xl text-sm font-bold transition-all active:scale-95 min-w-[72px]
                            ${isBase
                              ? 'bg-emerald-600 text-white shadow-md ring-2 ring-emerald-400/30'
                              : 'bg-zinc-800 text-zinc-400 border border-white/8'}`}>
                          <span className="text-base leading-none">{cfg.flag}</span>
                          <span className="text-xs font-black mt-1">{cfg.symbol}</span>
                          <span className={`text-[9px] mt-0.5 font-semibold ${isBase ? 'text-emerald-200' : 'text-zinc-600'}`}>{code}</span>
                        </button>
                        {/* Botón quitar (solo si no es la base) */}
                        {!isBase && (
                          <button onClick={() => removeActiveCurrency(code)}
                            className="absolute -top-1.5 -right-1.5 w-4 h-4 bg-zinc-700 border border-zinc-600 rounded-full flex items-center justify-center active:bg-rose-700 transition-colors z-10">
                            <X className="w-2.5 h-2.5 text-zinc-300"/>
                          </button>
                        )}
                        {isBase && (
                          <span className="absolute -top-1.5 -right-1.5 text-[8px] bg-emerald-500 text-white rounded-full px-1 font-black leading-4">✓</span>
                        )}
                      </div>
                    );
                  })}

                  {/* Botón agregar moneda */}
                  <button onClick={() => { setShowCurrencyPicker(true); setCurrencySearch(''); }}
                    className="flex flex-col items-center justify-center px-3 py-2.5 rounded-xl min-w-[72px] bg-zinc-900/60 border border-dashed border-white/15 text-zinc-600 active:scale-95 transition-all gap-1">
                    <Plus className="w-4 h-4"/>
                    <span className="text-[9px] font-bold">Agregar</span>
                  </button>
                </div>

                <p className="text-[10px] text-zinc-700">Tocá una moneda para usarla como base · × para quitarla</p>
              </div>
            </div>

            {/* ── TIPOS DE CAMBIO (para monedas activas ≠ base) ── */}
            {activeCurrencies.filter(c => c !== currency).length > 0 && (
              <div className="space-y-3">
                <p className="text-label ml-1">🔄 {tl('exchangeRate')}</p>
                <div className="mc-card p-4 space-y-4">
                  <p className="text-[11px] text-zinc-500 leading-relaxed">
                    ¿Cuántos <strong className="text-zinc-300">{getCurrencyShortName(currency)} ({currency})</strong> vale 1 unidad de cada moneda? Necesario para convertir al registrar.
                  </p>
                  {activeCurrencies
                    .filter(code => code !== currency)
                    .map(code => {
                      const cfg = CURRENCIES[code];
                      if (!cfg) return null;
                      const rate = exchangeRates[code] || 0;
                      return (
                        <div key={code} className="space-y-1.5">
                          <div className="flex items-center gap-2">
                            <div className="flex items-center gap-2 flex-shrink-0">
                              <span className="text-base">{cfg.flag}</span>
                              <div className="flex items-center gap-1 text-xs font-bold">
                                <span className="text-zinc-500">1</span>
                                <span className="bg-zinc-800 border border-white/10 rounded-lg px-2 py-1 text-violet-300 font-black tracking-wide">
                                  {cfg.symbol} {code}
                                </span>
                                <span className="text-zinc-600">=</span>
                              </div>
                            </div>
                            <div className="flex items-center gap-2 flex-1 justify-end">
                              <input
                                type="text"
                                value={rate || ''}
                                onChange={e => updateExchangeRate(code, e.target.value)}
                                placeholder="0"
                                inputMode="decimal"
                                className="bg-black/60 rounded-xl px-3 py-2 w-28 text-right font-black text-sm text-white focus:outline-none border border-white/10 focus:border-violet-500/60 transition-colors"
                              />
                              <span className="text-sm font-bold text-zinc-400 flex-shrink-0">{currSymbol} {currency}</span>
                            </div>
                          </div>
                          {rate > 0 ? (
                            <div className="flex items-center justify-between text-[10px] text-zinc-600 px-1">
                              <span>1 {code} = {currSymbol}{formatNumber(rate)}</span>
                              <span>100 {code} = {currSymbol}{formatNumber(Math.round(rate * 100))}</span>
                            </div>
                          ) : (
                            <p className="text-[10px] text-amber-500/70 px-1">⚠️ Sin tasa — las transacciones en {code} no se convertirán</p>
                          )}
                        </div>
                      );
                    })
                  }
                </div>
              </div>
            )}

            {/* ── SISTEMA WATERFALL ── */}
            <div className="space-y-3">
              <p className="text-label ml-1">🏠 Sistema Hogar</p>
              <div className="mc-card p-4 space-y-4">
                <p className="text-xs text-zinc-500">
                  La vista "🏠 Hogar" muestra el flujo waterfall: ingresos totales → deducciones → saldo a distribuir entre cuentas personales. Las cuentas compartidas tienen presupuestos editables desde Hogar.
                </p>
              </div>
            </div>

            {/* ── CUENTAS (quién pagó) ── */}
            <div className="space-y-3">
              <p className="text-label ml-1">👥 {tl('accounts')}</p>
              <div className="mc-card p-4 space-y-3">
                <p className="text-xs text-zinc-500">Nombres para identificar quién registró cada movimiento. Usá el toggle para marcar cuentas como compartidas.</p>
                <div className="flex flex-col gap-2">
                  {accounts.map((acc, i) => (
                    <div key={i} className="flex items-center gap-2">
                      <div className="flex-1 bg-zinc-800 rounded-xl px-4 py-2.5 flex items-center gap-2">
                        <span className="text-sm font-semibold text-white">{acc}</span>
                        <span className="text-[10px] text-zinc-500">
                          {(accountTypes[acc] || 'personal') === 'compartida' ? '🤝 Compartida' : '👤 Personal'}
                        </span>
                      </div>
                      <button onClick={() => {
                        const current = accountTypes[acc] || 'personal';
                        const next = current === 'personal' ? 'compartida' : 'personal';
                        saveAccountTypes({ ...accountTypes, [acc]: next });
                      }}
                        className={`px-3 py-1.5 rounded-lg text-[10px] font-bold border transition-all active:scale-90 ${
                          (accountTypes[acc] || 'personal') === 'compartida'
                            ? 'bg-teal-600/15 text-teal-400 border-teal-500/30'
                            : 'bg-zinc-800 text-zinc-500 border-white/8'
                        }`}>
                        {(accountTypes[acc] || 'personal') === 'compartida' ? '🤝' : '👤'}
                      </button>
                      <button onClick={() => {
                        const updated = accounts.filter((_, idx) => idx !== i);
                        saveAccounts(updated);
                      }} className="w-9 h-9 bg-zinc-900 rounded-xl flex items-center justify-center border border-white/8 active:bg-rose-500/20">
                        <X className="w-4 h-4 text-zinc-500"/>
                      </button>
                    </div>
                  ))}
                </div>
                <div className="flex gap-2">
                  <input
                    value={newAccountName}
                    onChange={e => setNewAccountName(e.target.value)}
                    placeholder={tl('newName')}
                    className="flex-1 bg-zinc-800 rounded-xl px-4 py-2.5 text-sm text-white border border-white/8 focus:outline-none focus:border-violet-500/60"
                  />
                  <button
                    onClick={() => {
                      const name = newAccountName.trim();
                      if (!name || accounts.includes(name)) return;
                      saveAccounts([...accounts, name]);
                      setNewAccountName('');
                    }}
                    className="px-4 py-2.5 bg-violet-600 rounded-xl text-sm font-bold active:scale-95 transition-all">
                    <Plus className="w-4 h-4"/>
                  </button>
                </div>
              </div>
            </div>

            {/* ── AHORRO E INVERSIÓN: qué cuenta lo gestiona ── */}
            {accounts.length > 0 && (
            <div className="space-y-3">
              <p className="text-label ml-1">💰 Ahorro e Inversión</p>
              <div className="mc-card p-4 space-y-3">
                <p className="text-xs text-zinc-500">Elegí qué cuenta gestiona el ahorro e inversión. Solo esa cuenta mostrará la sección de estrategia.</p>
                <div className="flex flex-wrap gap-2">
                  {[{ key: '', label: '🏠 Hogar' }, ...accounts.map(a => ({ key: a, label: a }))].map(opt => (
                    <button key={opt.key || '__hogar__'}
                      onClick={() => saveSavingsInvestAccount(opt.key)}
                      className={`px-4 py-2 rounded-xl text-xs font-bold transition-all active:scale-95 border
                        ${savingsInvestAccount === opt.key
                          ? 'bg-emerald-600/20 text-emerald-400 border-emerald-500/30'
                          : 'bg-zinc-900 text-zinc-500 border-white/8'}`}>
                      {opt.label}
                    </button>
                  ))}
                </div>
                <p className="text-[10px] text-zinc-600">
                  {savingsInvestAccount
                    ? `📌 ${savingsInvestAccount} gestiona el ahorro e inversión`
                    : '📌 Se deduce del ingreso total del hogar (vista Hogar)'}
                </p>
              </div>
            </div>
            )}

            {/* ═══ SECCIÓN: CUENTA Y DATOS ═══ */}
            <div className="space-y-2">
              <p className="text-[10px] font-black uppercase tracking-widest text-violet-400 ml-1">Cuenta y datos</p>
            </div>
            <div className="space-y-3">
              <p className="text-label ml-1">{tl('account')}</p>
              <div className="mc-card overflow-hidden">
                <div className="flex items-center justify-between px-5 py-4 border-b border-white/5">
                  <span className="text-sm font-semibold text-zinc-300">Email</span>
                  <span className="text-xs text-zinc-600 truncate max-w-[140px]">{session?.user?.email}</span>
                </div>
                <button onClick={() => exportExcel(transactions)} className="flex items-center gap-3 px-5 py-4 w-full border-b border-white/5 active:bg-zinc-900/60 transition-colors">
                  <FileSpreadsheet className="w-4 h-4 text-emerald-400"/>
                  <span className="text-sm font-semibold text-zinc-300">{tl('exportCsv')}</span>
                </button>
                <button onClick={exportAllJSON} className="flex items-center gap-3 px-5 py-4 w-full border-b border-white/5 active:bg-zinc-900/60 transition-colors">
                  <span className="text-base leading-none w-4 text-center">📦</span>
                  <span className="text-sm font-semibold text-zinc-300">{tl('backupJson')}</span>
                </button>
                <button onClick={()=>importFileRef.current?.click()} className="flex items-center gap-3 px-5 py-4 w-full border-b border-white/5 active:bg-zinc-900/60 transition-colors">
                  <span className="text-base leading-none w-4 text-center">📥</span>
                  <span className="text-sm font-semibold text-zinc-300">{tl('restoreJson')}</span>
                </button>
                <button onClick={() => setShowPlazoFijo(true)} className="flex items-center gap-3 px-5 py-4 w-full border-b border-white/5 active:bg-zinc-900/60 transition-colors">
                  <span className="text-base leading-none w-4 text-center">🏦</span>
                  <span className="text-sm font-semibold text-zinc-300">{tl('fixedTermCalc')}</span>
                </button>
                <button onClick={() => { setShowAIConfig(true); haptic(8); }} className="flex items-center gap-3 px-5 py-4 w-full border-b border-white/5 active:bg-zinc-900/60 transition-colors">
                  <Sparkles className="w-4 h-4 text-violet-400"/>
                  <span className="text-sm font-semibold text-zinc-300">{tl('aiConfigTitle')}</span>
                  {aiConfig?.apiKey && <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400 ml-auto mr-1"/>}
                  <ChevronRight className="w-4 h-4 text-zinc-700 ml-auto"/>
                </button>
                <button onClick={() => { setShowHelpCenter(true); haptic(8); }} className="flex items-center gap-3 px-5 py-4 w-full border-b border-white/5 active:bg-zinc-900/60 transition-colors">
                  <BookOpen className="w-4 h-4 text-violet-400"/>
                  <span className="text-sm font-semibold text-zinc-300">{tl('helpCenter')}</span>
                  <ChevronRight className="w-4 h-4 text-zinc-700 ml-auto"/>
                </button>
                <button onClick={signOut} className="flex items-center gap-3 px-5 py-4 w-full active:bg-zinc-900/60 transition-colors">
                  <LogOut className="w-4 h-4 text-rose-400"/>
                  <span className="text-sm font-semibold text-rose-400">{tl('signOut')}</span>
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* ════════════════════════════════
          FAB — Registrar rápido
      ════════════════════════════════ */}
      {/* ════════════════════════════════
          FABs — contenedor centrado con el contenido
          Evita que queden pegados al borde del viewport en desktop
      ════════════════════════════════ */}
      <div className="fixed bottom-0 left-0 right-0 z-[85] pointer-events-none">
        <div className="relative max-w-lg md:max-w-2xl lg:max-w-3xl mx-auto h-0">

          {/* Plus FAB — Home + Historial */}
          {(activeTab === 'home' || activeTab === 'history') && (
            <button
              onClick={() => { setActiveTab('add'); haptic(12); }}
              className="pointer-events-auto absolute right-5 w-14 h-14 bg-violet-600 rounded-full shadow-2xl shadow-violet-950/50 flex items-center justify-center active:scale-90 transition-transform border-2 border-violet-400/30"
              style={{ bottom: 'calc(env(safe-area-inset-bottom) + 84px)' }}>
              <Plus className="w-7 h-7 text-white"/>
            </button>
          )}

          {/* Mic FAB — solo Home */}
          {activeTab === 'home' && voiceSupported && (
            <button
              onClick={() => { setShowVoiceDictado(true); setTimeout(startHomeDictado, 300); haptic(10); }}
              className="pointer-events-auto absolute w-14 h-14 bg-violet-700 rounded-full shadow-2xl shadow-violet-900/50 flex items-center justify-center active:scale-90 transition-transform border-2 border-violet-400/30"
              style={{ right: 'calc(1.25rem + 3.5rem + 0.75rem)', bottom: 'calc(env(safe-area-inset-bottom) + 84px)' }}>
              <Mic className="w-6 h-6 text-white"/>
            </button>
          )}

          {/* AI Chat FAB — Home, solo si hay IA configurada */}
          {activeTab === 'home' && aiConfig?.apiKey && (
            <button
              onClick={() => { setShowHelpCenter(true); setHelpTab('chat'); haptic(10); }}
              className="pointer-events-auto absolute left-5 w-14 h-14 rounded-full shadow-2xl flex items-center justify-center active:scale-90 transition-transform border-2 overflow-hidden"
              style={{
                bottom: 'calc(env(safe-area-inset-bottom) + 84px)',
                background: aiConfig.provider === 'openai' ? 'linear-gradient(135deg, #10a37f 0%, #1a7f64 100%)'
                  : aiConfig.provider === 'gemini' ? 'linear-gradient(135deg, #4285F4 0%, #9B72CB 50%, #D96570 100%)'
                  : aiConfig.provider === 'anthropic' ? 'linear-gradient(135deg, #D97757 0%, #c4613f 100%)'
                  : 'linear-gradient(135deg, #7c3aed 0%, #5b21b6 100%)',
                borderColor: aiConfig.provider === 'openai' ? 'rgba(16,163,127,0.4)'
                  : aiConfig.provider === 'gemini' ? 'rgba(66,133,244,0.4)'
                  : aiConfig.provider === 'anthropic' ? 'rgba(217,119,87,0.4)'
                  : 'rgba(124,58,237,0.4)',
              }}>
              {(() => { const FabIcon = AI_PROVIDERS[aiConfig.provider]?.Icon; return FabIcon ? <span className="text-white"><FabIcon size={26}/></span> : <MessageCircle className="w-6 h-6 text-white"/>; })()}
            </button>
          )}

          {/* Scroll-to-top — Historial */}
          {activeTab === 'history' && showScrollTop && (
            <button
              onClick={() => { window.scrollTo({ top: 0, behavior: 'smooth' }); haptic(8); }}
              className="pointer-events-auto absolute left-5 w-11 h-11 bg-zinc-800/90 backdrop-blur-sm rounded-full shadow-xl flex items-center justify-center active:scale-90 transition-all border border-white/10"
              style={{ bottom: 'calc(env(safe-area-inset-bottom) + 72px)' }}>
              <ChevronLeft className="w-4 h-4 text-zinc-300 -rotate-90"/>
            </button>
          )}

        </div>
      </div>

      {/* PWA install banner */}
      {showInstallBanner && (
        <div className="fixed bottom-[calc(env(safe-area-inset-bottom)+60px)] left-4 right-4 z-[95] bg-zinc-900 border border-violet-500/30 rounded-2xl p-4 shadow-2xl flex items-center gap-3 max-w-md mx-auto">
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
            className="px-3.5 py-2 bg-violet-600 rounded-xl text-xs font-black active:scale-95 transition-transform">
            Instalar
          </button>
          <button onClick={() => setShowInstallBanner(false)} className="p-1.5 active:opacity-60">
            <X className="w-4 h-4 text-zinc-600"/>
          </button>
        </div>
      )}

      {/* ═══ ONBOARDING WIZARD ═══ */}
      {showOnboarding && (
        <div className="fixed inset-0 z-[1000] bg-black/95 flex items-center justify-center p-6">
          <div className="w-full max-w-sm space-y-6">
            {/* Progress dots */}
            <div className="flex justify-center gap-2">
              {[1,2,3].map(s => (
                <div key={s} className={`w-2 h-2 rounded-full transition-all ${onboardingStep >= s ? 'bg-violet-500 scale-110' : 'bg-zinc-700'}`}/>
              ))}
            </div>

            {onboardingStep === 1 && (
              <div className="text-center space-y-4">
                <div className="text-5xl">👋</div>
                <h2 className="text-2xl font-black text-white">¡Bienvenido a MetaCasa!</h2>
                <p className="text-sm text-zinc-400 leading-relaxed">
                  Vamos a configurar tu app en 2 pasos rápidos para que puedas empezar a controlar tus finanzas.
                </p>
                <button onClick={() => setOnboardingStep(2)}
                  className="w-full py-4 bg-violet-600 rounded-2xl font-bold text-sm uppercase tracking-wider active:scale-95 transition-transform shadow-xl shadow-violet-950/50">
                  Comenzar
                </button>
                <button onClick={() => { setShowOnboarding(false); localStorage.setItem(ONBOARDING_KEY, '1'); }}
                  className="text-xs text-zinc-600 active:text-zinc-400">
                  Omitir configuración
                </button>
              </div>
            )}

            {onboardingStep === 2 && (
              <div className="space-y-4">
                <div className="text-center space-y-2">
                  <div className="text-4xl">👥</div>
                  <h2 className="text-xl font-black text-white">¿Quiénes usan la app?</h2>
                  <p className="text-xs text-zinc-500">Agregá los nombres de las personas del hogar para saber quién registra cada gasto.</p>
                </div>
                <div className="space-y-2">
                  {onboardingAccounts.map((acc, i) => (
                    <div key={i} className="flex items-center gap-2">
                      <div className="flex-1 bg-zinc-800 rounded-xl px-4 py-2.5">
                        <span className="text-sm font-semibold text-white">{acc}</span>
                      </div>
                      <button onClick={() => setOnboardingAccounts(prev => prev.filter((_, idx) => idx !== i))}
                        className="w-9 h-9 bg-zinc-900 rounded-xl flex items-center justify-center border border-white/8 active:bg-rose-500/20">
                        <X className="w-4 h-4 text-zinc-500"/>
                      </button>
                    </div>
                  ))}
                </div>
                <div className="flex gap-2">
                  <input
                    value={onboardingNewName}
                    onChange={e => setOnboardingNewName(e.target.value)}
                    onKeyDown={e => {
                      if (e.key === 'Enter' && onboardingNewName.trim()) {
                        setOnboardingAccounts(prev => [...prev, onboardingNewName.trim()]);
                        setOnboardingNewName('');
                      }
                    }}
                    placeholder="Nombre..."
                    className="flex-1 bg-zinc-800 rounded-xl px-4 py-2.5 text-sm text-white border border-white/8 focus:outline-none focus:border-violet-500/60"
                  />
                  <button
                    onClick={() => {
                      if (!onboardingNewName.trim()) return;
                      setOnboardingAccounts(prev => [...prev, onboardingNewName.trim()]);
                      setOnboardingNewName('');
                    }}
                    className="px-4 py-2.5 bg-violet-600 rounded-xl text-sm font-bold active:scale-95 transition-all">
                    <Plus className="w-4 h-4"/>
                  </button>
                </div>
                <button onClick={() => {
                  if (onboardingAccounts.length > 0) saveAccounts(onboardingAccounts);
                  setOnboardingStep(3);
                }}
                  className="w-full py-4 bg-violet-600 rounded-2xl font-bold text-sm uppercase tracking-wider active:scale-95 transition-transform shadow-xl shadow-violet-950/50">
                  {onboardingAccounts.length > 0 ? 'Siguiente' : 'Omitir'}
                </button>
              </div>
            )}

            {onboardingStep === 3 && (
              <div className="space-y-4">
                <div className="text-center space-y-2">
                  <div className="text-4xl">💰</div>
                  <h2 className="text-xl font-black text-white">Tu moneda</h2>
                  <p className="text-xs text-zinc-500">Elegí la moneda principal. Podés agregar más después en Ajustes.</p>
                </div>
                <div className="grid grid-cols-3 gap-2">
                  {['ARS','USD','EUR','BRL','CLP','UYU','MXN','COP','PEN'].map(code => {
                    const cfg = CURRENCIES[code];
                    if (!cfg) return null;
                    return (
                      <button key={code} onClick={() => changeCurrency(code)}
                        className={`flex flex-col items-center px-2 py-3.5 rounded-xl text-sm font-bold transition-all active:scale-95 gap-0.5
                          ${currency === code ? 'bg-violet-600 text-white shadow-md ring-2 ring-violet-400/30' : 'bg-zinc-800 text-zinc-400 border border-white/8'}`}>
                        <span className="text-2xl leading-none">{cfg.flag}</span>
                        <span className="text-[11px] font-black mt-1">{code}</span>
                        <span className={`text-[9px] font-semibold ${currency === code ? 'text-violet-200' : 'text-zinc-600'}`}>{cfg.symbol}</span>
                      </button>
                    );
                  })}
                </div>
                <button onClick={() => {
                  setShowOnboarding(false);
                  localStorage.setItem(ONBOARDING_KEY, '1');
                  toast('¡Todo listo! Registrá tu primer movimiento con el botón +', 'success');
                }}
                  className="w-full py-4 bg-emerald-600 rounded-2xl font-bold text-sm uppercase tracking-wider active:scale-95 transition-transform shadow-xl shadow-emerald-950/50">
                  ¡Empezar!
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ── UNDO DELETE BANNER ── */}
      {undoableTx && (
        <div className="fixed bottom-24 left-1/2 -translate-x-1/2 z-[998] animate-in fade-in slide-in-from-bottom-4">
          <button onClick={undoDeleteTransaction}
            className="flex items-center gap-2 px-5 py-3 bg-zinc-800 border border-white/10 rounded-2xl shadow-2xl shadow-black/60 active:scale-95 transition-transform">
            <span className="text-sm font-bold text-white">Deshacer eliminación</span>
            <span className="text-xs text-violet-400 font-mono">5s</span>
          </button>
        </div>
      )}

      {/* ════════════════════════════════
          BOTTOM TAB BAR (iOS-style)
      ════════════════════════════════ */}
      <div className="bottom-nav">
        <div className="max-w-lg md:max-w-2xl lg:max-w-3xl mx-auto flex items-end px-1">
          {[
            { id:'home',       icon: Home,      label: tl('home')    },
            { id:'add',        icon: Plus,      label: tl('add')     },
            { id:'history',    icon: History,   label: tl('history') },
            { id:'stats',      icon: BarChart3, label: tl('stats')   },
            { id:'budget',     icon: PiggyBank, label: tl('budget')  },
            { id:'billeteras', icon: Wallet,    label: 'Billeteras'  },
          ].map(tab=>{
            const Icon = tab.icon;
            const active = activeTab===tab.id;
            const isAdd = tab.id==='add';
            return (
              <button key={tab.id} onClick={()=>{ setActiveTab(tab.id); haptic && haptic(5); }}
                className="flex-1 flex flex-col items-center gap-0.5 py-2 transition-all duration-200 active:scale-90 relative min-w-0">
                {/* Active pill indicator */}
                {active && !isAdd && (
                  <span className="absolute top-1.5 left-1/2 -translate-x-1/2 w-8 h-8 bg-violet-600/12 rounded-2xl -z-0"/>
                )}
                <div className="relative z-10">
                  {isAdd ? (
                    <div className={`w-11 h-11 rounded-2xl flex items-center justify-center shadow-lg transition-all duration-200 -mb-1
                      ${active
                        ? 'bg-violet-600 shadow-violet-950/60'
                        : 'bg-zinc-900 border border-white/10 shadow-black/40'}`}>
                      <Icon className={`w-5 h-5 transition-colors ${active?'text-white':'text-zinc-500'}`}/>
                    </div>
                  ) : (
                    <Icon className={`w-[22px] h-[22px] transition-all duration-200 ${active?'text-violet-400':'text-zinc-600'}`}/>
                  )}
                  {tab.id==='home' && urgentCount > 0 && (
                    <span className="pulse-dot absolute -top-1 -right-2 w-4 h-4 bg-rose-500 rounded-full flex items-center justify-center text-[8px] font-black text-white leading-none border border-black">
                      {urgentCount > 9 ? '9+' : urgentCount}
                    </span>
                  )}
                </div>
                <span className={`text-[9px] font-bold leading-tight transition-all duration-200 truncate max-w-[52px] text-center
                  ${active?'text-violet-400':'text-zinc-600'}
                  ${isAdd&&!active?'opacity-0 h-0 overflow-hidden':''}`}>
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
            <button onClick={()=>setShowDatePicker(false)} className="w-full py-4 bg-violet-600 rounded-2xl font-bold text-sm active:scale-95 transition-all">
              Aplicar
            </button>
          </div>
        </div>
      )}

      {/* ════════════════════════════════
          MODAL: Selector de período de presupuesto
      ════════════════════════════════ */}
      {showBudgetPeriodPicker && (
        <div className="fixed inset-0 z-[100] flex items-end justify-center">
          <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={()=>setShowBudgetPeriodPicker(false)}/>
          <div className="anim-slide-up relative w-full max-w-md bg-zinc-950 rounded-t-[2rem] border border-white/8 px-5 pt-5 pb-[calc(env(safe-area-inset-bottom)+20px)]">
            <div className="flex items-center justify-between mb-5">
              <p className="text-base font-black">Seleccioná período</p>
              <button onClick={()=>setShowBudgetPeriodPicker(false)} className="p-2 bg-zinc-900 rounded-xl active:scale-90 transition-transform">
                <X className="w-4 h-4"/>
              </button>
            </div>
            <div className="overflow-y-auto max-h-[55vh] space-y-4 pb-2">
              {availableYearMonths.length === 0 ? (
                <p className="text-center text-zinc-600 text-sm py-6">Sin movimientos registrados aún</p>
              ) : (
                Object.entries(
                  availableYearMonths.reduce((g,{year,month})=>{ (g[year]=g[year]||[]).push(month); return g; },{})
                ).sort(([a],[b])=>Number(b)-Number(a)).map(([year, months]) => (
                  <div key={year}>
                    <p className="text-xs font-bold text-zinc-600 uppercase tracking-wider mb-2">{year}</p>
                    <div className="grid grid-cols-4 gap-2">
                      {months.map(m => {
                        const isSelected = budgetPeriod.year===Number(year) && budgetPeriod.month===m;
                        return (
                          <button key={m}
                            onClick={()=>{ setBudgetPeriod({year:Number(year),month:m}); setShowBudgetPeriodPicker(false); haptic(8); }}
                            className={`py-2.5 rounded-xl text-xs font-bold transition-all active:scale-95
                              ${isSelected?'bg-violet-600 text-white shadow-lg shadow-violet-500/30':'bg-zinc-900 text-zinc-400 active:bg-zinc-800'}`}>
                            {MONTHS[m].slice(0,3)}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                ))
              )}
            </div>
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
                className={`p-2.5 rounded-xl transition-all ${budgetChartView?'bg-violet-600 text-white':'bg-zinc-900 text-zinc-400'}`}>
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
                const limit=getAggregatedBudget(cat), spent=stats.expenseByCategory[cat]||0;
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
              className="flex-1 bg-zinc-900/60 rounded-2xl p-4 border border-white/10 text-sm text-white focus:outline-none focus:border-violet-500/40" />
            <button onClick={()=>manageCategory('ADD',newCatName)} className="bg-violet-600 px-5 rounded-2xl active:scale-95 transition-all">
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
                        className="flex-1 bg-zinc-900 rounded-xl px-3 py-2 text-sm text-white focus:outline-none border border-violet-500/40"
                      />
                      <button onClick={() => { if (renameValue.trim()) manageCategory('RENAME', c, renameValue.trim()); else setRenamingCat(null); }}
                        className="px-3 py-2 bg-violet-600 rounded-xl text-sm font-bold active:scale-95 transition-transform">OK</button>
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
                          className="p-2 text-zinc-700 active:text-violet-400 transition-colors" title="Renombrar">
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
                            ${getEmoji(c)===emoji ? 'bg-violet-600' : 'active:bg-white/10'}`}>
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

                {/* ── Subcategorías ── */}
                <div className="border-t border-white/5 pt-1">
                  <button
                    onClick={() => {
                      setExpandedCatSubcat(expandedCatSubcat === c ? null : c);
                      setNewSubcatInput('');
                    }}
                    className="w-full flex items-center justify-between px-2 py-2 rounded-xl active:bg-white/5 transition-colors">
                    <div className="flex items-center gap-2">
                      <span className="text-sm">⊞</span>
                      <span className="text-xs font-semibold text-zinc-500">Subcategorías</span>
                      {subcategories[c]?.length > 0 && (
                        <span className="text-[10px] font-bold bg-teal-500/20 text-teal-400 px-1.5 py-0.5 rounded-full leading-none">
                          {subcategories[c].length}
                        </span>
                      )}
                    </div>
                    <ChevronRight className={`w-3.5 h-3.5 text-zinc-600 transition-transform duration-200 ${expandedCatSubcat === c ? 'rotate-90' : ''}`}/>
                  </button>

                  {expandedCatSubcat === c && (
                    <div className="mt-1.5 bg-black/30 rounded-2xl p-3 border border-teal-500/20 space-y-3">
                      {/* Chips existentes */}
                      {(subcategories[c] || []).length > 0 ? (
                        <div className="flex flex-wrap gap-2">
                          {(subcategories[c] || []).map(sc => (
                            <div key={sc} className="flex items-center gap-1 bg-teal-500/15 border border-teal-500/25 rounded-xl px-2.5 py-1.5">
                              <span className="text-xs font-semibold text-teal-300">{sc}</span>
                              <button
                                onClick={() => deleteSubcategory(c, sc)}
                                className="ml-0.5 text-teal-700 active:text-rose-400 transition-colors">
                                <X className="w-3 h-3"/>
                              </button>
                            </div>
                          ))}
                        </div>
                      ) : (
                        <p className="text-[11px] text-zinc-600 text-center py-0.5">Sin subcategorías aún — agregá una abajo</p>
                      )}

                      {/* Input para agregar */}
                      <div className="flex gap-2">
                        <input
                          value={newSubcatInput}
                          onChange={e => setNewSubcatInput(e.target.value)}
                          onKeyDown={e => { if (e.key === 'Enter') { addSubcategory(c, newSubcatInput); } }}
                          placeholder="Nueva subcategoría…"
                          className="flex-1 bg-zinc-900 rounded-xl px-3 py-2.5 text-sm text-white border border-white/10 focus:outline-none focus:border-teal-500/60 placeholder:text-zinc-700"
                        />
                        <button
                          onClick={() => addSubcategory(c, newSubcatInput)}
                          className="px-4 py-2.5 bg-teal-600 rounded-xl active:scale-95 transition-all font-bold flex items-center gap-1">
                          <Plus className="w-4 h-4"/>
                        </button>
                      </div>
                    </div>
                  )}
                </div>
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
                className="p-2.5 bg-violet-600 rounded-xl active:scale-90 transition-transform">
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
                <button onClick={()=>{setEditingBill(null);setShowBillForm(true);}} className="text-sm font-bold text-violet-400">
                  + Agregar el primero
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ── CURRENCY PICKER MODAL ── */}
      {showCurrencyPicker && (
        <div className="fixed inset-0 z-[110] flex items-end justify-center">
          <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={() => setShowCurrencyPicker(false)}/>
          <div className="anim-slide-up relative w-full max-w-md bg-zinc-950 rounded-t-[2rem] border border-white/8 px-5 pt-4 pb-[calc(env(safe-area-inset-bottom)+24px)] max-h-[80vh] flex flex-col">
            <div className="w-8 h-1 bg-zinc-700 rounded-full mx-auto mb-4"/>
            <div className="flex items-center justify-between mb-4">
              <p className="font-black text-base">Agregar moneda</p>
              <button onClick={() => setShowCurrencyPicker(false)}
                className="p-2 bg-zinc-900 rounded-xl active:bg-zinc-800">
                <X className="w-4 h-4 text-zinc-400"/>
              </button>
            </div>

            {/* Búsqueda */}
            <div className="relative mb-3">
              <input
                type="text"
                value={currencySearch}
                onChange={e => setCurrencySearch(e.target.value)}
                placeholder="Buscar por nombre o código..."
                autoFocus
                className="w-full bg-zinc-900 rounded-2xl px-4 py-3 text-sm text-white border border-white/10 focus:outline-none focus:border-violet-500/40 pl-9"
              />
              <span className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-500 text-sm">🔍</span>
            </div>

            {/* Lista scrolleable */}
            <div className="overflow-y-auto flex-1 space-y-1 pr-1">
              {Object.entries(CURRENCIES)
                .filter(([code, cfg]) => {
                  if (activeCurrencies.includes(code)) return false; // ya agregada
                  if (!currencySearch) return true;
                  const q = currencySearch.toLowerCase();
                  return code.toLowerCase().includes(q) || cfg.name.toLowerCase().includes(q) || cfg.shortName.toLowerCase().includes(q);
                })
                .map(([code, cfg]) => (
                  <button key={code}
                    onClick={() => { addActiveCurrency(code); setShowCurrencyPicker(false); haptic(10); }}
                    className="w-full flex items-center gap-3 px-4 py-3 bg-zinc-900/60 rounded-2xl active:bg-zinc-800 transition-colors text-left border border-white/4">
                    <span className="text-2xl leading-none flex-shrink-0">{cfg.flag}</span>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-bold text-white">{cfg.name}</p>
                      <p className="text-xs text-zinc-500">{code} · {cfg.symbol}</p>
                    </div>
                    <Plus className="w-4 h-4 text-zinc-500 flex-shrink-0"/>
                  </button>
                ))
              }
              {Object.entries(CURRENCIES).filter(([code, cfg]) => {
                if (activeCurrencies.includes(code)) return false;
                if (!currencySearch) return true;
                const q = currencySearch.toLowerCase();
                return code.toLowerCase().includes(q) || cfg.name.toLowerCase().includes(q);
              }).length === 0 && (
                <p className="text-center text-zinc-600 text-sm py-8">
                  {currencySearch ? `No se encontró "${currencySearch}"` : 'Todas las monedas ya están agregadas'}
                </p>
              )}
            </div>
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
                <RefreshCw className="w-5 h-5 text-violet-400"/> Recurrentes
              </h3>
              <p className="text-xs text-zinc-600 mt-0.5">{recurring.length} activo{recurring.length!==1?'s':''}</p>
            </div>
            <div className="flex gap-2">
              <button onClick={()=>{ setEditingRecurring(null); setShowRecurringForm(true); }}
                className="p-2.5 bg-violet-600 rounded-xl active:scale-90 transition-transform">
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
                  className="text-sm font-bold text-violet-400">
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
          accounts={accounts}
          currSymbol={currSymbol}
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
          accounts={accounts}
          onSave={loadTransactions}
          onClose={()=>setEditingTx(null)}
          onFixedTxsChange={setFixedTxs}
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

      {/* ── Modal: Gasto Fijo action sheet ── */}
      {editingFixedTx && (
        <div className="fixed inset-0 z-[100] flex items-end justify-center">
          <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={()=>setEditingFixedTx(null)}/>
          <div className="anim-slide-up relative w-full max-w-md bg-zinc-950 rounded-t-[2rem] border border-white/8 px-5 pt-4 pb-[calc(env(safe-area-inset-bottom)+20px)]">
            <div className="w-8 h-1 bg-zinc-700 rounded-full mx-auto mb-4"/>
            <div className="flex items-center gap-3 mb-5">
              <span className="text-2xl">{getEmoji(editingFixedTx.category)}</span>
              <div>
                <p className="font-black">{editingFixedTx.category}</p>
                <p className="text-sm text-zinc-500">Día {editingFixedTx.dayOfMonth} · ${formatNumber(editingFixedTx.amount)}{editingFixedTx.account ? ` · ${editingFixedTx.account}` : ''}{editingFixedTx.note ? ` · ${editingFixedTx.note}` : ''}</p>
              </div>
            </div>
            <div className="space-y-2">
              <button onClick={()=>openFixedTxEdit(editingFixedTx)}
                className="w-full py-3.5 bg-zinc-900 rounded-2xl font-bold text-sm flex items-center justify-center gap-2 active:scale-95 transition-transform">
                <Edit3 className="w-4 h-4"/> Editar
              </button>
              <button onClick={()=>{ deleteFixedTx(editingFixedTx.id); setEditingFixedTx(null); }}
                className="w-full py-3.5 bg-red-500/10 rounded-2xl font-bold text-sm text-red-400 flex items-center justify-center gap-2 active:scale-95 transition-transform">
                <Trash2 className="w-4 h-4"/> Eliminar
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Modal: Vencimiento/Cuota action sheet ── */}
      {editingBudgetItem && (
        <div className="fixed inset-0 z-[100] flex items-end justify-center">
          <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={()=>setEditingBudgetItem(null)}/>
          <div className="anim-slide-up relative w-full max-w-md bg-zinc-950 rounded-t-[2rem] border border-white/8 px-5 pt-4 pb-[calc(env(safe-area-inset-bottom)+20px)]">
            <div className="w-8 h-1 bg-zinc-700 rounded-full mx-auto mb-4"/>
            <div className="flex items-center gap-3 mb-5">
              <span className="text-2xl">{editingBudgetItem.emoji}</span>
              <div>
                <p className="font-black">{editingBudgetItem.name}</p>
                <p className="text-sm text-zinc-500">
                  {editingBudgetItem.type === 'bill'
                    ? `Vence día ${editingBudgetItem.dueDay}${editingBudgetItem.isRecurring ? ' · Mensual' : ''}`
                    : `Cuota ${editingBudgetItem.cuotaNum}/${editingBudgetItem.totalCuotas}`}
                  {' · '}${formatNumber(editingBudgetItem.amount)}
                </p>
              </div>
            </div>
            <div className="space-y-2">
              {editingBudgetItem.type === 'bill' && (
                <button onClick={()=>{
                  const b = bills.find(x => x.id === editingBudgetItem.rawId);
                  if (b) { setEditingBill(b); setShowBillForm(true); }
                  setEditingBudgetItem(null);
                }} className="w-full py-3.5 bg-zinc-900 rounded-2xl font-bold text-sm flex items-center justify-center gap-2 active:scale-95 transition-transform">
                  <Edit3 className="w-4 h-4"/> Editar vencimiento
                </button>
              )}
              <button onClick={()=>{
                if (editingBudgetItem.type === 'bill') deleteBill(editingBudgetItem.rawId);
                else deleteCuota(editingBudgetItem.rawId);
                setEditingBudgetItem(null);
              }} className="w-full py-3.5 bg-red-500/10 rounded-2xl font-bold text-sm text-red-400 flex items-center justify-center gap-2 active:scale-95 transition-transform">
                <Trash2 className="w-4 h-4"/> Eliminar
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Modal: Detalle de categoría ── */}
      {detailCat && (()=>{
        const catTxs = budgetPeriodTxs
          .filter(t => t.type === 'GASTO' && t.category === detailCat)
          .sort((a,b) => new Date(b.date) - new Date(a.date));
        const total = catTxs.reduce((s,t) => s + Number(t.amount), 0);
        return (
          <div className="fixed inset-0 z-[100] flex items-end justify-center">
            <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={()=>setDetailCat(null)}/>
            <div className="anim-slide-up relative w-full max-w-md bg-zinc-950 rounded-t-[2rem] border border-white/8 px-5 pt-4 pb-[calc(env(safe-area-inset-bottom)+20px)] max-h-[85vh] flex flex-col">
              {/* Header */}
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <span className="text-xl">{getEmoji(detailCat)}</span>
                  <div>
                    <p className="font-black">{detailCat}</p>
                    <p className="text-xs text-zinc-500">{MONTHS[budgetPeriod.month].slice(0,3)} {budgetPeriod.year} · {catTxs.length} movimiento{catTxs.length !== 1 ? 's' : ''}</p>
                  </div>
                </div>
                <button onClick={()=>setDetailCat(null)} className="p-2 bg-zinc-900 rounded-xl"><X className="w-4 h-4"/></button>
              </div>
              {/* Total */}
              <div className="mb-3 px-4 py-3 bg-zinc-900/60 rounded-2xl flex items-center justify-between">
                <p className="text-xs text-zinc-500 uppercase tracking-wide font-semibold">Total gastado</p>
                <p className="text-lg font-black text-red-400">${formatNumber(total)}</p>
              </div>
              {/* Lista de transacciones */}
              <div className="overflow-y-auto flex-1 space-y-1.5">
                {catTxs.map(t => (
                  <button key={t.id}
                    onClick={()=>{ setEditingTx(t); setDetailCat(null); }}
                    className="w-full flex items-center gap-3 px-4 py-3 bg-zinc-900 rounded-2xl active:bg-zinc-800 transition-colors text-left">
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold truncate">{t.note || t.category}</p>
                      <p className="text-xs text-zinc-500">{new Date(t.date+'T12:00:00').toLocaleDateString('es-AR',{day:'numeric',month:'short'})}</p>
                    </div>
                    <p className="text-sm font-black text-red-400 flex-shrink-0">${formatNumber(t.amount)}</p>
                    <ChevronRight className="w-3.5 h-3.5 text-zinc-600 flex-shrink-0"/>
                  </button>
                ))}
                {catTxs.length === 0 && (
                  <p className="text-center text-zinc-600 text-sm py-10">Sin movimientos en este período</p>
                )}
              </div>
            </div>
          </div>
        );
      })()}

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
                {activeCuotas.length} activa{activeCuotas.length!==1?'s':''} · {currSymbol}{formatNumber(cuotasMonthly)}/mes
              </p>
            </div>
            <div className="flex gap-2">
              <button onClick={()=>{ setEditingCuota(null); setShowCuotaForm(true); }}
                className="p-2.5 bg-violet-600 rounded-xl active:scale-90 transition-transform">
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
                  className="text-sm font-bold text-violet-400">+ Agregar la primera</button>
              </div>
            ) : (
              <>
                {/* Resumen */}
                {cuotasMonthly > 0 && (
                  <div className="bg-amber-500/8 border border-amber-500/20 rounded-2xl p-4 flex justify-between items-center">
                    <div>
                      <p className="text-xs text-zinc-500 font-semibold">Compromiso mensual</p>
                      <p className="text-xl font-black text-amber-400">{currSymbol}{formatNumber(cuotasMonthly)}/mes</p>
                    </div>
                    <div className="text-right">
                      <p className="text-xs text-zinc-500 font-semibold">Total restante</p>
                      <p className="text-lg font-black">{currSymbol}{formatNumber(cuotas.reduce((a,c)=>{const r=c.currency&&c.currency!==currency?(exchangeRates[c.currency]||1):1;return a+(c.totalCuotas-c.paidCuotas)*c.monthlyAmount*r;},0))}</p>
                    </div>
                  </div>
                )}
                {/* Activas */}
                {activeCuotas.length > 0 && (
                  <div className="space-y-3">
                    <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider ml-1">En curso ({activeCuotas.length})</p>
                    {activeCuotas.map(c=>(
                      <CuotaCard key={c.id} cuota={c} baseCurrency={currency}
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
                      <CuotaCard key={c.id} cuota={c} baseCurrency={currency}
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
          baseCurrency={currency}
          activeCurrencies={activeCurrencies}
          categories={activeCategories}
          accounts={accounts}
          getEmoji={getEmoji}
          onSave={(data)=>{ saveCuota(data); setShowCuotaForm(false); }}
          onClose={()=>setShowCuotaForm(false)}
        />
      )}

      {/* ════════════════════════════════
          MODAL: Resumen Presupuesto
      ════════════════════════════════ */}
      {showBudgetResumen && (() => {
        const periodItemsTotal = periodBudgetItems.reduce((a, i) => a + i.amount, 0);
        return (
          <div className="fixed inset-0 z-[110] flex items-end justify-center">
            <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={() => setShowBudgetResumen(false)} />
            <div className="anim-slide-up relative w-full max-w-md bg-zinc-950 rounded-t-[2rem] border border-white/8 px-5 pt-4 pb-[calc(env(safe-area-inset-bottom)+20px)] max-h-[90vh] flex flex-col">
              <div className="w-8 h-1 bg-zinc-700 rounded-full mx-auto mb-4" />
              <div className="flex items-center justify-between mb-4">
                <div>
                  <p className="font-black text-base">Resumen financiero</p>
                  <p className="text-xs text-zinc-500">{MONTHS[budgetPeriod.month]} {budgetPeriod.year} · {accounts.length} cuenta{accounts.length !== 1 ? 's' : ''}</p>
                </div>
                <button onClick={() => setShowBudgetResumen(false)} className="p-2 bg-zinc-900 rounded-xl active:scale-90 transition-transform">
                  <X className="w-4 h-4" />
                </button>
              </div>

              <div className="overflow-y-auto flex-1 space-y-4 no-scrollbar">
                {/* Waterfall resumen global */}
                <div className="glass-success px-4 py-4 space-y-2">
                  <p className="text-label mb-1">🏠 Ingresos del hogar</p>
                  <p className="text-display text-emerald-400">{currSymbol}{formatNumber(waterfallData.totalIncome)}</p>
                  <div className="flex justify-between items-center pt-1">
                    <span className="text-xs text-zinc-500 font-semibold">Deducciones</span>
                    <span className="text-sm font-black text-rose-400">−{currSymbol}{formatNumber(waterfallData.totalDeductions)}</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-xs text-zinc-500 font-semibold">Saldo distribuido</span>
                    <span className="text-sm font-black text-white">{currSymbol}{formatNumber(waterfallData.remainder)}</span>
                  </div>
                </div>

                {/* Per personal account */}
                {personalAccounts.map(acc => {
                  const allocation = waterfallData.effectiveAllocations[acc] || 0;
                  const accTxs = budgetPeriodTxs.filter(t => t.account === acc);
                  const expBycat = {};
                  accTxs.filter(t => t.type === 'GASTO').forEach(t => {
                    expBycat[t.category] = (expBycat[t.category] || 0) + Number(t.amount);
                  });
                  const totalExp = Object.values(expBycat).reduce((a, b) => a + b, 0);
                  const totalBudgets = activeCategories.GASTO.reduce((catAcc, cat) => {
                    return catAcc + (budgets[`${acc}|${cat}|`]?.amount || 0);
                  }, 0);
                  const dispPresupuestado = allocation - totalBudgets;
                  const dispReal = allocation - totalExp;
                  return (
                    <div key={acc} className="mc-card p-4 space-y-3">
                      <div className="flex items-center gap-2 pb-2 border-b border-white/5">
                        <Wallet className="w-4 h-4 text-violet-400" />
                        <p className="font-black text-sm">{acc}</p>
                        <span className="text-[9px] text-zinc-600 px-1.5 py-0.5 rounded-full bg-zinc-800">👤 Personal</span>
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-xs text-zinc-500 font-semibold">Asignación</span>
                        <span className="text-sm font-black text-emerald-400">{currSymbol}{formatNumber(allocation)}</span>
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-xs text-zinc-500 font-semibold">Disp. presupuestado</span>
                        <span className={`text-sm font-black ${dispPresupuestado >= 0 ? 'text-white' : 'text-rose-400'}`}>{currSymbol}{formatNumber(dispPresupuestado)}</span>
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-xs text-zinc-500 font-semibold">Disp. real</span>
                        <span className={`text-sm font-black ${dispReal >= 0 ? 'text-white' : 'text-rose-400'}`}>{currSymbol}{formatNumber(dispReal)}</span>
                      </div>
                      {/* Category limits - editable */}
                      <div className="space-y-1 pt-2 border-t border-white/5">
                        <div className="flex items-center justify-between mb-1">
                          <p className="text-[10px] text-zinc-600 font-bold uppercase tracking-wider">Límites por categoría</p>
                          <p className="text-[10px] text-zinc-700 font-semibold">gastado / límite</p>
                        </div>
                        {activeCategories.GASTO.map(cat => {
                          const budKey = `${acc}|${cat}|`;
                          const rawVal = budgets[budKey]?.amount || 0;
                          const spent = expBycat[cat] || 0;
                          const pct = rawVal > 0 ? Math.min(100, Math.round((spent / rawVal) * 100)) : 0;
                          const isOver = rawVal > 0 && spent > rawVal;
                          return (
                            <div key={cat}>
                              <div className="flex items-center gap-1.5 py-1">
                                <span className="text-sm leading-none flex-shrink-0">{getEmoji(cat)}</span>
                                <span className="text-xs text-zinc-400 truncate flex-1 min-w-0">{cat}</span>
                                <span className={`text-[11px] font-bold w-[4.5rem] text-right flex-shrink-0 ${isOver ? 'text-rose-400' : spent > 0 ? 'text-zinc-300' : 'text-zinc-700'}`}>
                                  {spent > 0 ? `${currSymbol}${formatNumber(spent)}` : '-'}
                                </span>
                                <span className="text-zinc-700 text-[10px] mx-0.5">/</span>
                                <input type="text" value={formatNumber(rawVal)}
                                  onChange={async e => { const v = parseFormattedNumber(e.target.value); await updateBudget(acc, cat, '', v); }}
                                  className="bg-transparent text-right font-bold text-[11px] w-[4.5rem] flex-shrink-0 focus:outline-none focus:text-violet-400 text-zinc-500 transition-colors"
                                  inputMode="numeric" placeholder="0" />
                              </div>
                              {rawVal > 0 && (
                                <div className="h-1 bg-black/40 rounded-full overflow-hidden ml-6 mb-0.5">
                                  <div className={`h-full rounded-full transition-all ${isOver ? 'bg-rose-500' : pct > 80 ? 'bg-amber-500' : 'bg-violet-600'}`}
                                    style={{width:`${pct}%`}}/>
                                </div>
                              )}
                              {(subcategories[cat] || []).length > 0 && (
                                <div className="ml-6 space-y-0.5 border-l border-white/5 pl-3 mt-1">
                                  {(subcategories[cat] || []).map(subcat => {
                                    const subKey = `${acc}|${cat}|${subcat}`;
                                    const subRawVal = budgets[subKey]?.amount || 0;
                                    const subSpent = budgetPeriodTxs
                                      .filter(t => t.account === acc && t.type === 'GASTO' && t.category === cat && t.subcategory === subcat)
                                      .reduce((a, c) => a + Number(c.amount), 0);
                                    return (
                                      <div key={subcat} className="flex items-center gap-1.5 py-0.5">
                                        <span className="text-[10px] text-zinc-500 truncate flex-1 min-w-0">{subcat}</span>
                                        <span className="text-[10px] text-zinc-600 w-14 text-right flex-shrink-0">{subSpent > 0 ? `${currSymbol}${formatNumber(subSpent)}` : '-'}</span>
                                        <span className="text-zinc-700 text-[9px]">/</span>
                                        <input type="text" value={formatNumber(subRawVal)}
                                          onChange={async e => { const v = parseFormattedNumber(e.target.value); await updateBudget(acc, cat, subcat, v); }}
                                          className="bg-transparent text-right font-bold text-[10px] w-14 flex-shrink-0 focus:outline-none focus:text-violet-400 text-zinc-600 transition-colors"
                                          inputMode="numeric" placeholder="0" />
                                      </div>
                                    );
                                  })}
                                </div>
                              )}
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  );
                })}

                {/* Shared accounts */}
                {sharedAccounts.map(acc => {
                  const accTxs = budgetPeriodTxs.filter(t => t.account === acc);
                  const expBycat = {};
                  accTxs.filter(t => t.type === 'GASTO').forEach(t => {
                    expBycat[t.category] = (expBycat[t.category] || 0) + Number(t.amount);
                  });
                  const totalBudgets = activeCategories.GASTO.reduce((catAcc, cat) => {
                    return catAcc + (budgets[`${acc}|${cat}|`]?.amount || 0);
                  }, 0);
                  const totalExp = Object.values(expBycat).reduce((a, b) => a + b, 0);
                  return (
                    <div key={acc} className="mc-card p-4 space-y-3">
                      <div className="flex items-center gap-2 pb-2 border-b border-white/5">
                        <Wallet className="w-4 h-4 text-teal-400" />
                        <p className="font-black text-sm">{acc}</p>
                        <span className="text-[9px] text-teal-500 px-1.5 py-0.5 rounded-full bg-teal-500/10">🤝 Compartida</span>
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-xs text-zinc-500 font-semibold">Presupuesto compartido</span>
                        <span className="text-sm font-black text-teal-400">{currSymbol}{formatNumber(totalBudgets)}</span>
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-xs text-zinc-500 font-semibold">Gastado</span>
                        <span className="text-sm font-black text-rose-400">{currSymbol}{formatNumber(totalExp)}</span>
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-xs text-zinc-500 font-semibold">Disponible</span>
                        <span className={`text-sm font-black ${totalBudgets - totalExp >= 0 ? 'text-white' : 'text-rose-400'}`}>{currSymbol}{formatNumber(totalBudgets - totalExp)}</span>
                      </div>
                    </div>
                  );
                })}

                {/* Global commitments */}
                <div className="mc-card p-4 space-y-2">
                  <p className="text-[10px] text-zinc-600 font-bold uppercase tracking-wider mb-1">Compromisos del periodo</p>
                  <div className="flex justify-between items-center">
                    <span className="text-xs text-zinc-500 font-semibold">Gastos fijos pagados</span>
                    <span className="text-sm font-black text-rose-400">{currSymbol}{formatNumber(budgetPeriodStats.fixedPaidTotal)}</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-xs text-zinc-500 font-semibold">Vencimientos y cuotas</span>
                    <span className="text-sm font-black text-rose-400">{currSymbol}{formatNumber(periodItemsTotal)}</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-xs text-zinc-500 font-semibold">Ahorro ({strategy.savingsPercent||0}%)</span>
                    <span className="text-sm font-black text-emerald-400">{currSymbol}{formatNumber(waterfallData.savingsAmt)}</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-xs text-zinc-500 font-semibold">Inversión ({strategy.investmentPercent||0}%)</span>
                    <span className="text-sm font-black text-violet-400">{currSymbol}{formatNumber(waterfallData.investAmt)}</span>
                  </div>
                </div>

                {accounts.length === 0 && (
                  <div className="text-center py-10">
                    <p className="text-sm text-zinc-600">Sin cuentas configuradas</p>
                    <p className="text-xs text-zinc-700 mt-1">Agrega cuentas en Ajustes para ver el desglose</p>
                  </div>
                )}
              </div>
            </div>
          </div>
        );
      })()}

      {/* ════════════════════════════════
          MODAL: Centro de Ayuda / Help Center
      ════════════════════════════════ */}
      {showHelpCenter && (() => {
        const topics = HELP_CONTENT(lang);
        const selectedTopicData = helpSelectedTopic ? topics.find(tp => tp.id === helpSelectedTopic) : null;
        const sq = helpSearchQuery.trim().toLowerCase();
        const filteredTopics = sq
          ? topics.filter(tp =>
              tp.title.toLowerCase().includes(sq) ||
              tp.subtitle.toLowerCase().includes(sq) ||
              tp.keywords.some(k => k.includes(sq)) ||
              tp.sections.some(s => s.heading.toLowerCase().includes(sq) || s.body.toLowerCase().includes(sq))
            )
          : topics;

        return (
          <div className="fixed inset-0 z-[170] bg-black flex flex-col">
            {/* Header */}
            <div className="px-6 pt-[calc(env(safe-area-inset-top)+16px)] pb-4 border-b border-white/8">
              <div className="flex justify-between items-center mb-4">
                <h3 className="text-xl font-black uppercase tracking-tight flex items-center gap-2">
                  <BookOpen className="w-5 h-5 text-violet-400"/> {tl('helpCenter')}
                </h3>
                <button onClick={() => { setShowHelpCenter(false); setHelpSelectedTopic(null); setHelpSearchQuery(''); setHelpTab('topics'); }}
                  className="p-2.5 bg-zinc-900 rounded-xl active:scale-90 transition-transform">
                  <X className="w-5 h-5"/>
                </button>
              </div>
              {/* Tab bar */}
              <div className="flex bg-zinc-900/80 rounded-2xl p-1.5 border border-white/8">
                {[
                  { id:'topics', label: tl('helpTopics'),  icon: BookOpen },
                  { id:'search', label: tl('helpSearch'),  icon: Search },
                  { id:'chat',   label: tl('helpChat'),    icon: MessageCircle },
                ].map(tab => {
                  const TabIcon = tab.icon;
                  return (
                    <button key={tab.id}
                      onClick={() => { setHelpTab(tab.id); if (tab.id !== 'topics') setHelpSelectedTopic(null); }}
                      className={`flex-1 flex items-center justify-center gap-1.5 py-2.5 text-xs font-bold rounded-xl transition-all
                        ${helpTab === tab.id ? 'bg-violet-600 text-white' : 'text-zinc-500'}`}>
                      <TabIcon className="w-3.5 h-3.5"/>
                      {tab.label}
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Content */}
            <div className="flex-1 overflow-y-auto no-scrollbar">

              {/* ═══ TAB: TEMAS ═══ */}
              {helpTab === 'topics' && !selectedTopicData && (
                <div className="px-6 py-5 space-y-3">
                  {topics.map((topic, idx) => (
                    <button key={topic.id}
                      onClick={() => setHelpSelectedTopic(topic.id)}
                      className="anim-fade-up w-full flex items-center gap-4 mc-card px-5 py-4 active:scale-[0.98] transition-transform"
                      style={{ animationDelay: `${idx * 0.03}s` }}>
                      <div className="w-11 h-11 rounded-2xl bg-violet-600/10 border border-violet-500/20 flex items-center justify-center text-xl flex-shrink-0">
                        {topic.icon}
                      </div>
                      <div className="flex-1 text-left min-w-0">
                        <p className="text-sm font-bold text-zinc-200">{topic.title}</p>
                        <p className="text-xs text-zinc-600 truncate">{topic.subtitle}</p>
                      </div>
                      <ChevronRight className="w-4 h-4 text-zinc-700 flex-shrink-0"/>
                    </button>
                  ))}
                </div>
              )}

              {/* ═══ DETALLE DE TEMA ═══ */}
              {helpTab === 'topics' && selectedTopicData && (
                <div className="px-6 py-5 space-y-5 pb-12">
                  <button onClick={() => setHelpSelectedTopic(null)}
                    className="flex items-center gap-2 text-sm text-violet-400 font-bold active:opacity-70">
                    <ChevronLeft className="w-4 h-4"/> {tl('helpBackToTopics')}
                  </button>
                  <div className="flex items-center gap-4">
                    <div className="w-14 h-14 rounded-2xl bg-violet-600/10 border border-violet-500/20 flex items-center justify-center text-2xl">
                      {selectedTopicData.icon}
                    </div>
                    <div>
                      <h4 className="text-lg font-black text-white">{selectedTopicData.title}</h4>
                      <p className="text-xs text-zinc-500">{selectedTopicData.subtitle}</p>
                    </div>
                  </div>
                  {selectedTopicData.sections.map((section, si) => (
                    <div key={si} className="mc-card p-5 space-y-2">
                      <h5 className="text-sm font-black text-violet-300 uppercase tracking-wide">{section.heading}</h5>
                      <p className="text-sm text-zinc-400 leading-relaxed">{section.body}</p>
                    </div>
                  ))}
                  {selectedTopicData.tip && (
                    <div className="glass-card p-4 flex gap-3 items-start">
                      <Lightbulb className="w-5 h-5 text-amber-400 flex-shrink-0 mt-0.5"/>
                      <p className="text-xs text-zinc-400 leading-relaxed">
                        <span className="font-bold text-amber-400">{tl('helpTipPrefix')}</span> {selectedTopicData.tip}
                      </p>
                    </div>
                  )}
                </div>
              )}

              {/* ═══ TAB: BUSCAR ═══ */}
              {helpTab === 'search' && (
                <div className="px-6 py-5 space-y-4">
                  <div className="flex items-center gap-3 bg-zinc-900/60 border border-white/10 rounded-2xl px-4 py-3">
                    <Search className="w-5 h-5 text-zinc-500 flex-shrink-0"/>
                    <input autoFocus type="text" value={helpSearchQuery}
                      onChange={e => setHelpSearchQuery(e.target.value)}
                      placeholder={tl('helpSearchPlaceholder')}
                      className="flex-1 bg-transparent text-sm text-white placeholder:text-zinc-600 focus:outline-none"/>
                    {helpSearchQuery && (
                      <button onClick={() => setHelpSearchQuery('')} className="p-1 text-zinc-600 active:text-zinc-300">
                        <X className="w-4 h-4"/>
                      </button>
                    )}
                  </div>
                  {sq && filteredTopics.length === 0 && (
                    <div className="text-center py-12 space-y-3">
                      <Search className="w-10 h-10 text-zinc-800 mx-auto"/>
                      <p className="text-sm text-zinc-600">{tl('helpNoResults')}</p>
                    </div>
                  )}
                  <div className="space-y-3">
                    {filteredTopics.map(topic => (
                      <button key={topic.id}
                        onClick={() => { setHelpSelectedTopic(topic.id); setHelpTab('topics'); }}
                        className="w-full flex items-center gap-4 mc-card px-5 py-4 active:scale-[0.98] transition-transform">
                        <div className="w-10 h-10 rounded-xl bg-zinc-900 flex items-center justify-center text-lg flex-shrink-0">
                          {topic.icon}
                        </div>
                        <div className="flex-1 text-left min-w-0">
                          <p className="text-sm font-bold text-zinc-200">{topic.title}</p>
                          <p className="text-xs text-zinc-600 truncate">{topic.subtitle}</p>
                        </div>
                        <ChevronRight className="w-4 h-4 text-zinc-700 flex-shrink-0"/>
                      </button>
                    ))}
                  </div>
                  {!sq && (
                    <p className="text-center text-xs text-zinc-700 pt-4">
                      {lang === 'es' ? 'Escribí para buscar en todos los temas de ayuda' : 'Type to search across all help topics'}
                    </p>
                  )}
                </div>
              )}

              {/* ═══ TAB: CHAT IA ═══ */}
              {helpTab === 'chat' && (
                <div className="flex flex-col" style={{ height: 'calc(100dvh - 170px)' }}>
                  {/* Banner de estado IA */}
                  {!aiConfig?.apiKey ? (
                    <div className="mx-5 mt-4 mb-1 p-4 rounded-2xl bg-violet-600/8 border border-violet-500/15 space-y-3">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-xl bg-violet-600/20 border border-violet-500/30 flex items-center justify-center">
                          <Sparkles className="w-5 h-5 text-violet-400"/>
                        </div>
                        <div className="flex-1">
                          <p className="text-sm font-bold text-violet-300">{tl('aiNotConfigured')}</p>
                          <p className="text-xs text-zinc-500 mt-0.5">{tl('aiSetupPrompt')}</p>
                        </div>
                      </div>
                      <button onClick={() => { setShowAIConfig(true); haptic(8); }}
                        className="w-full py-3 bg-violet-600 rounded-xl text-xs font-black uppercase tracking-wider active:scale-95 transition-transform">
                        {tl('aiSetupButton')}
                      </button>
                    </div>
                  ) : (
                    <div className="mx-5 mt-4 mb-1 flex items-center gap-2 px-3 py-2 rounded-xl bg-emerald-500/8 border border-emerald-500/15">
                      <div className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"/>
                      {(() => { const BIcon = AI_PROVIDERS[aiConfig.provider]?.Icon; return BIcon ? <span className={`inline-flex ${AI_PROVIDERS[aiConfig.provider]?.iconColor || ''}`}><BIcon size={14}/></span> : null; })()}
                      <span className="text-[11px] font-bold text-emerald-400">
                        {AI_PROVIDERS[aiConfig.provider]?.name} {tl('aiConfigured').toLowerCase()}
                      </span>
                    </div>
                  )}
                  <div ref={helpChatRef} className="flex-1 overflow-y-auto px-5 py-5 space-y-4 no-scrollbar">
                    {helpChatMessages.length === 0 && (
                      <div className="space-y-4">
                        <div className="flex gap-3">
                          <div className="w-9 h-9 rounded-xl bg-violet-600/20 border border-violet-500/30 flex items-center justify-center flex-shrink-0">
                            <Sparkles className="w-4 h-4 text-violet-400"/>
                          </div>
                          <div className="mc-card p-4 max-w-[85%]">
                            <p className="text-sm text-zinc-300 leading-relaxed">{tl('helpChatWelcome')}</p>
                          </div>
                        </div>
                        <div className="space-y-2 pl-12">
                          {(lang === 'es' ? [
                            '¿Cómo configuro el presupuesto cascada?',
                            '¿Cómo registro un gasto en otra moneda?',
                            '¿Para qué sirven las cuentas compartidas?',
                            '¿Cómo funcionan los gastos fijos?',
                          ] : [
                            'How do I set up the waterfall budget?',
                            'How do I record an expense in another currency?',
                            'What are shared accounts for?',
                            'How do fixed expenses work?',
                          ]).map((q, qi) => (
                            <button key={qi}
                              onClick={() => setHelpChatInput(q)}
                              className="block w-full text-left text-xs text-violet-400 bg-violet-600/8 border border-violet-500/15 rounded-xl px-3 py-2.5 active:scale-[0.98] transition-transform">
                              {q}
                            </button>
                          ))}
                        </div>
                      </div>
                    )}
                    {helpChatMessages.map((msg, mi) => (
                      <div key={mi} className={`flex gap-3 ${msg.role === 'user' ? 'justify-end' : ''}`}>
                        {msg.role === 'assistant' && (
                          <div className="w-8 h-8 rounded-xl bg-violet-600/20 border border-violet-500/30 flex items-center justify-center flex-shrink-0">
                            <Sparkles className="w-3.5 h-3.5 text-violet-400"/>
                          </div>
                        )}
                        <div className={`max-w-[80%] rounded-2xl px-4 py-3 ${
                          msg.role === 'user' ? 'bg-violet-600 text-white' : 'mc-card'}`}>
                          <p className={`text-sm leading-relaxed whitespace-pre-wrap ${
                            msg.role === 'user' ? 'text-white' : 'text-zinc-300'}`}>{msg.content}</p>
                        </div>
                      </div>
                    ))}
                    {helpChatLoading && (
                      <div className="flex gap-3">
                        <div className="w-8 h-8 rounded-xl bg-violet-600/20 border border-violet-500/30 flex items-center justify-center flex-shrink-0">
                          <Sparkles className="w-3.5 h-3.5 text-violet-400"/>
                        </div>
                        <div className="mc-card px-4 py-3">
                          <div className="flex gap-1.5">
                            {[0,1,2].map(di => (
                              <div key={di} className="w-2 h-2 rounded-full bg-violet-400 animate-bounce" style={{ animationDelay: `${di * 0.15}s` }}/>
                            ))}
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                  <div className="px-5 pb-[calc(env(safe-area-inset-bottom)+12px)] pt-3 border-t border-white/8 bg-black">
                    <div className="flex items-center gap-3">
                      <input type="text" value={helpChatInput}
                        onChange={e => setHelpChatInput(e.target.value)}
                        onKeyDown={e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendHelpChatMessage(); } }}
                        placeholder={tl('helpChatPlaceholder')}
                        className="flex-1 bg-zinc-900/60 rounded-2xl px-4 py-3 border border-white/10 text-sm text-white placeholder:text-zinc-600 focus:outline-none focus:border-violet-500/40"/>
                      <button onClick={sendHelpChatMessage}
                        disabled={!helpChatInput.trim() || helpChatLoading}
                        className="p-3 bg-violet-600 rounded-xl active:scale-90 transition-transform disabled:opacity-40">
                        <Send className="w-4 h-4 text-white"/>
                      </button>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        );
      })()}

      {/* ════════════════════════════════
          MODAL: Configurar IA
      ════════════════════════════════ */}
      {showAIConfig && (
        <div className="fixed inset-0 z-[180] bg-black/95 backdrop-blur-xl flex items-end justify-center">
          <div className="absolute inset-0" onClick={() => setShowAIConfig(false)}/>
          <div className="anim-slide-up relative w-full max-w-md bg-zinc-950 rounded-t-[2.5rem] border-t border-white/10 pb-[calc(1rem+env(safe-area-inset-bottom))] max-h-[90vh] overflow-y-auto no-scrollbar">
            {/* Header */}
            <div className="sticky top-0 z-10 bg-zinc-950 px-6 pt-6 pb-4 flex justify-between items-center border-b border-white/5">
              <h3 className="text-lg font-black uppercase tracking-tight flex items-center gap-2">
                <Sparkles className="w-5 h-5 text-violet-400"/> {tl('aiConfigTitle')}
              </h3>
              <button onClick={() => setShowAIConfig(false)} className="p-2 bg-zinc-900 rounded-full active:scale-90 transition-transform">
                <X className="w-4 h-4"/>
              </button>
            </div>

            <div className="px-6 py-5 space-y-5">
              {/* Estado actual */}
              {aiConfig?.apiKey && (() => {
                const CurIcon = AI_PROVIDERS[aiConfig.provider]?.Icon;
                return (
                <div className="flex items-center gap-3 p-4 rounded-2xl bg-emerald-500/8 border border-emerald-500/20">
                  <div className={`w-8 h-8 flex items-center justify-center ${AI_PROVIDERS[aiConfig.provider]?.iconColor || ''}`}>{CurIcon && <CurIcon size={28}/>}</div>
                  <div className="flex-1">
                    <p className="font-black text-sm">{AI_PROVIDERS[aiConfig.provider]?.name}</p>
                    <p className="text-xs text-zinc-500">{aiConfig.model || AI_PROVIDERS[aiConfig.provider]?.defaultModel}</p>
                  </div>
                  <CheckCircle2 className="w-5 h-5 text-emerald-400"/>
                </div>
                );
              })()}

              {/* Grilla de proveedores */}
              <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500">{tl('aiSelectProvider')}</p>
              <div className="grid grid-cols-2 gap-3">
                {Object.values(AI_PROVIDERS).map(prov => {
                  const ProvIcon = prov.Icon;
                  return (
                  <button key={prov.id}
                    onClick={() => { saveAiConfig({ provider: prov.id, apiKey: aiConfig?.provider === prov.id ? (aiConfig?.apiKey || '') : '', model: '', baseUrl: '' }); setAiTestStatus(null); }}
                    className={`flex flex-col items-center gap-2 p-4 rounded-3xl border transition-all active:scale-95
                      ${aiConfig?.provider === prov.id ? 'ring-2 ring-violet-500 bg-violet-600/10 border-violet-500/30' : 'bg-zinc-900/60 border-white/5'}`}>
                    <div className={`w-10 h-10 flex items-center justify-center ${prov.iconColor}`}><ProvIcon size={32}/></div>
                    <span className="text-xs font-black text-center leading-tight">{prov.name}</span>
                  </button>
                  );
                })}
              </div>

              {/* Campos de configuración */}
              {aiConfig?.provider && (() => {
                const prov = AI_PROVIDERS[aiConfig.provider];
                return (
                  <div className="space-y-4">
                    {/* API Key */}
                    <div className="space-y-1.5">
                      <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wide">API Key</p>
                      <input type="password" placeholder={prov.placeholder}
                        value={aiConfig.apiKey || ''}
                        onChange={e => saveAiConfig({ ...aiConfig, apiKey: e.target.value })}
                        className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm font-mono focus:outline-none focus:border-violet-500/60 text-zinc-200"/>
                    </div>

                    {/* Modelo */}
                    <div className="space-y-1.5">
                      <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wide">
                        {tl('aiModel')} <span className="text-zinc-700 normal-case">({tl('aiOptional')})</span>
                      </p>
                      <input type="text" placeholder={prov.defaultModel || 'model-name'}
                        value={aiConfig.model || ''}
                        onChange={e => saveAiConfig({ ...aiConfig, model: e.target.value })}
                        className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm font-mono focus:outline-none focus:border-violet-500/60 text-zinc-200"/>
                    </div>

                    {/* Base URL (solo Custom) */}
                    {aiConfig.provider === 'custom' && (
                      <div className="space-y-1.5">
                        <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wide">Base URL</p>
                        <input type="url" placeholder="https://your-api.com"
                          value={aiConfig.baseUrl || ''}
                          onChange={e => saveAiConfig({ ...aiConfig, baseUrl: e.target.value })}
                          className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm font-mono focus:outline-none focus:border-violet-500/60 text-zinc-200"/>
                      </div>
                    )}

                    {/* Link de ayuda */}
                    {prov.helpUrl && (
                      <a href={prov.helpUrl} target="_blank" rel="noopener noreferrer"
                        className="flex items-center gap-2 text-xs text-violet-400 underline">
                        {prov.helpText?.[lang] || prov.helpText?.es} →
                      </a>
                    )}

                    {/* Probar conexión */}
                    <button
                      onClick={async () => {
                        if (!aiConfig.apiKey?.trim()) { toast(lang === 'es' ? 'Ingresá tu API key' : 'Enter your API key', 'error'); return; }
                        setAiTestStatus('testing'); setAiTestError('');
                        try {
                          await callAI('Reply with exactly: OK', [{ role: 'user', content: 'Test' }]);
                          setAiTestStatus('success');
                          toast(lang === 'es' ? 'Conexión exitosa ✓' : 'Connection successful ✓', 'success');
                          haptic(12);
                        } catch (e) { setAiTestStatus('error'); setAiTestError(e.message); toast(e.message, 'error'); }
                      }}
                      disabled={!aiConfig.apiKey?.trim() || aiTestStatus === 'testing'}
                      className="w-full py-3.5 bg-violet-600 rounded-2xl font-black text-sm uppercase tracking-widest active:scale-95 transition-all disabled:opacity-40 flex items-center justify-center gap-2">
                      {aiTestStatus === 'testing'
                        ? <><RefreshCw className="w-4 h-4 animate-spin"/> {tl('aiTesting')}</>
                        : tl('aiTestConnection')}
                    </button>

                    {/* Resultado del test */}
                    {aiTestStatus === 'success' && (
                      <div className="flex items-center gap-2 p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20">
                        <CheckCircle2 className="w-4 h-4 text-emerald-400"/>
                        <span className="text-xs font-bold text-emerald-400">{tl('aiConnectionOk')}</span>
                      </div>
                    )}
                    {aiTestStatus === 'error' && (
                      <div className="flex items-start gap-2 p-3 rounded-xl bg-rose-500/10 border border-rose-500/20">
                        <AlertCircle className="w-4 h-4 text-rose-400 mt-0.5 flex-shrink-0"/>
                        <span className="text-xs font-bold text-rose-400">{aiTestError}</span>
                      </div>
                    )}

                    {/* Desconectar */}
                    {aiConfig.apiKey && (
                      <button onClick={() => { saveAiConfig(null); setAiTestStatus(null); toast(lang === 'es' ? 'IA desconectada' : 'AI disconnected', 'info'); }}
                        className="w-full py-3 bg-zinc-900 rounded-2xl text-sm font-bold text-rose-400 border border-rose-500/20 active:scale-95 transition-all">
                        {tl('aiDisconnect')}
                      </button>
                    )}
                  </div>
                );
              })()}
            </div>
          </div>
        </div>
      )}

      {/* ════════════════════════════════
          MODAL: Calendario de Vencimientos
      ════════════════════════════════ */}
      {showDueDateCalendar && (() => {
        const year = budgetPeriod.year;
        const month = budgetPeriod.month; // 0-based
        const firstDay = new Date(year, month, 1).getDay(); // 0=Sun
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const today = new Date();
        const isCurrentMonth = today.getFullYear() === year && today.getMonth() === month;
        const todayDate = today.getDate();

        // Build map: day → items
        const dayItems = {};
        // Bills from periodBudgetItems
        periodBudgetItems.filter(it => it.dueDay).forEach(it => {
          if (!dayItems[it.dueDay]) dayItems[it.dueDay] = [];
          dayItems[it.dueDay].push({ ...it, source: 'bill' });
        });
        // Fixed expenses
        fixedTxs.filter(f => f.type === 'GASTO').forEach(f => {
          const day = f.dayOfMonth;
          if (day >= 1 && day <= daysInMonth) {
            if (!dayItems[day]) dayItems[day] = [];
            dayItems[day].push({
              id: f.id, name: f.category, amount: f.amount, emoji: getEmoji(f.category),
              isPaid: !!paidItems[f.id], source: 'fixed', note: f.note || ''
            });
          }
        });

        const monthNames = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
        const dayNames = ['Do','Lu','Ma','Mi','Ju','Vi','Sá'];
        const cells = [];
        for (let i = 0; i < firstDay; i++) cells.push(null);
        for (let d = 1; d <= daysInMonth; d++) cells.push(d);

        const selectedItems = calendarSelectedDay ? (dayItems[calendarSelectedDay] || []) : [];

        // Count totals
        const totalDueAmount = Object.values(dayItems).flat().reduce((a, it) => a + it.amount, 0);
        const totalPaidAmount = Object.values(dayItems).flat().filter(it => it.isPaid).reduce((a, it) => a + it.amount, 0);
        const totalPendingAmount = totalDueAmount - totalPaidAmount;

        return (
          <div className="fixed inset-0 z-[110] bg-black flex flex-col">
            <div className="px-6 pt-[calc(env(safe-area-inset-top)+16px)] pb-4 flex justify-between items-center border-b border-white/8">
              <div>
                <h3 className="text-xl font-black uppercase tracking-tight flex items-center gap-2">
                  <Calendar className="w-5 h-5 text-violet-400"/> Calendario
                </h3>
                <p className="text-xs text-zinc-600 mt-0.5">{monthNames[month]} {year}</p>
              </div>
              <button onClick={() => { setShowDueDateCalendar(false); setCalendarSelectedDay(null); }}
                className="p-2.5 bg-zinc-900 rounded-xl active:scale-90 transition-transform">
                <X className="w-5 h-5"/>
              </button>
            </div>

            <div className="flex-1 overflow-y-auto px-5 py-4 space-y-4 no-scrollbar pb-12">
              {/* Resumen */}
              <div className="grid grid-cols-3 gap-2">
                <div className="bg-zinc-900/60 rounded-2xl border border-white/5 p-3 text-center">
                  <p className="text-[10px] text-zinc-600 font-bold uppercase">Total</p>
                  <p className="text-sm font-black text-zinc-200">{currSymbol}{formatNumber(totalDueAmount)}</p>
                </div>
                <div className="bg-emerald-600/8 rounded-2xl border border-emerald-500/15 p-3 text-center">
                  <p className="text-[10px] text-emerald-500 font-bold uppercase">Pagado</p>
                  <p className="text-sm font-black text-emerald-400">{currSymbol}{formatNumber(totalPaidAmount)}</p>
                </div>
                <div className="bg-rose-600/8 rounded-2xl border border-rose-500/15 p-3 text-center">
                  <p className="text-[10px] text-rose-500 font-bold uppercase">Pendiente</p>
                  <p className="text-sm font-black text-rose-400">{currSymbol}{formatNumber(totalPendingAmount)}</p>
                </div>
              </div>

              {/* Calendar Grid */}
              <div className="mc-card p-4">
                {/* Day headers */}
                <div className="grid grid-cols-7 gap-1 mb-2">
                  {dayNames.map(d => (
                    <div key={d} className="text-center text-[10px] font-bold text-zinc-600 uppercase">{d}</div>
                  ))}
                </div>
                {/* Day cells */}
                <div className="grid grid-cols-7 gap-1">
                  {cells.map((day, idx) => {
                    if (day === null) return <div key={`empty-${idx}`} />;
                    const hasItems = !!dayItems[day];
                    const isToday = isCurrentMonth && day === todayDate;
                    const isSelected = calendarSelectedDay === day;
                    const allPaid = hasItems && dayItems[day].every(it => it.isPaid);
                    const someOverdue = hasItems && dayItems[day].some(it => {
                      if (it.isPaid) return false;
                      const dueDate = new Date(year, month, day);
                      return dueDate < new Date(today.getFullYear(), today.getMonth(), today.getDate());
                    });

                    return (
                      <button key={day}
                        onClick={() => setCalendarSelectedDay(isSelected ? null : day)}
                        className={`relative aspect-square rounded-xl flex flex-col items-center justify-center transition-all active:scale-90
                          ${isSelected ? 'bg-violet-600 ring-2 ring-violet-400' :
                            hasItems ? (someOverdue ? 'bg-rose-600/15 border border-rose-500/30' : allPaid ? 'bg-emerald-600/15 border border-emerald-500/30' : 'bg-amber-600/10 border border-amber-500/25') :
                            'bg-zinc-900/40'}`}>
                        <span className={`text-xs font-bold ${isSelected ? 'text-white' : isToday ? 'text-violet-400' : hasItems ? 'text-zinc-200' : 'text-zinc-600'}`}>
                          {day}
                        </span>
                        {hasItems && (
                          <div className="flex gap-0.5 mt-0.5">
                            {dayItems[day].slice(0, 3).map((it, i) => (
                              <div key={i} className={`w-1 h-1 rounded-full ${it.isPaid ? 'bg-emerald-400' : someOverdue ? 'bg-rose-400' : 'bg-amber-400'}`}/>
                            ))}
                          </div>
                        )}
                        {isToday && !isSelected && (
                          <div className="absolute -top-0.5 -right-0.5 w-2 h-2 bg-violet-500 rounded-full"/>
                        )}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Selected day details */}
              {calendarSelectedDay && (
                <div className="space-y-2">
                  <p className="text-xs font-bold text-zinc-500 uppercase tracking-wider px-1">
                    {calendarSelectedDay} de {monthNames[month]}
                    {selectedItems.length > 0 && ` · ${selectedItems.length} item${selectedItems.length !== 1 ? 's' : ''}`}
                  </p>
                  {selectedItems.length === 0 ? (
                    <div className="mc-card p-5 text-center">
                      <p className="text-sm text-zinc-600">Sin vencimientos este día</p>
                    </div>
                  ) : (
                    <div className="mc-card overflow-hidden">
                      {selectedItems.map((item, i) => (
                        <div key={item.id}
                          className={`flex items-center px-4 py-3.5 ${i < selectedItems.length - 1 ? 'border-b border-white/[0.04]' : ''} ${item.isPaid ? 'opacity-40' : ''}`}>
                          <span className="text-lg mr-3 flex-shrink-0">{item.emoji}</span>
                          <div className="flex-1 min-w-0">
                            <p className="text-sm font-semibold text-zinc-300 truncate">{item.name}</p>
                            <p className="text-[11px] text-zinc-600">
                              {item.source === 'fixed' ? 'Gasto fijo' :
                               item.source === 'bill' && item.type === 'cuota' ? `Cuota ${item.cuotaNum}/${item.totalCuotas}` :
                               item.isRecurring ? 'Mensual' : 'Único'}
                              {item.note ? ` · ${item.note}` : ''}
                            </p>
                          </div>
                          <div className="text-right flex-shrink-0 ml-2">
                            <p className={`text-sm font-bold ${item.isPaid ? 'text-emerald-400 line-through decoration-emerald-600' : 'text-zinc-200'}`}>
                              {currSymbol}{formatNumber(item.amount)}
                            </p>
                            <p className={`text-[10px] font-semibold ${item.isPaid ? 'text-emerald-500' : 'text-amber-500'}`}>
                              {item.isPaid ? '✓ Pagado' : '⏳ Pendiente'}
                            </p>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}

              {/* Legend */}
              <div className="flex flex-wrap gap-3 px-1">
                <div className="flex items-center gap-1.5">
                  <div className="w-2.5 h-2.5 rounded-full bg-emerald-400"/>
                  <span className="text-[10px] text-zinc-600 font-semibold">Pagado</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <div className="w-2.5 h-2.5 rounded-full bg-amber-400"/>
                  <span className="text-[10px] text-zinc-600 font-semibold">Pendiente</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <div className="w-2.5 h-2.5 rounded-full bg-rose-400"/>
                  <span className="text-[10px] text-zinc-600 font-semibold">Vencido</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <div className="w-2.5 h-2.5 rounded-full bg-violet-500"/>
                  <span className="text-[10px] text-zinc-600 font-semibold">Hoy</span>
                </div>
              </div>
            </div>
          </div>
        );
      })()}

      {/* ════════════════════════════════
          MODAL: Metas de Ahorro
      ════════════════════════════════ */}
      {showGoalsModal && (
        <div className="fixed inset-0 z-[110] bg-black flex flex-col">
          <div className="px-6 pt-[calc(env(safe-area-inset-top)+16px)] pb-5 flex justify-between items-center border-b border-white/8">
            <div>
              <h3 className="text-xl font-black uppercase tracking-tight flex items-center gap-2">
                <Target className="w-5 h-5 text-violet-400"/> Metas de ahorro
              </h3>
              <p className="text-xs text-zinc-600 mt-0.5">{goals.length} meta{goals.length!==1?'s':''}</p>
            </div>
            <div className="flex gap-2">
              <button onClick={()=>{ setEditingGoal(null); setShowGoalForm(true); }}
                className="p-2.5 bg-violet-600 rounded-xl active:scale-90 transition-transform">
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
                  className="text-sm font-bold text-violet-400">+ Crear la primera</button>
              </div>
            ) : (
              <>
                {/* Resumen total */}
                <div className="bg-violet-600/10 border border-violet-500/20 rounded-2xl p-4 flex justify-between items-center">
                  <div>
                    <p className="text-xs text-zinc-500 font-semibold">Total guardado</p>
                    <p className="text-xl font-black text-violet-300">${formatNumber(goals.reduce((a,g)=>a+g.current,0))}</p>
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
                className="p-2.5 bg-violet-600 rounded-xl active:scale-90 transition-transform">
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
                  className="text-sm font-bold text-violet-400">+ Agregar la primera</button>
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
        <div className="fixed inset-0 z-[130] flex items-end md:items-center justify-center" onClick={()=>setShowWidgetEditor(false)}>
          <div className="w-full max-w-md md:max-w-lg mx-auto bg-zinc-950 rounded-t-[2rem] md:rounded-[2rem] border-t md:border border-white/8 pb-[calc(env(safe-area-inset-bottom)+16px)] md:pb-0"
            onClick={e=>e.stopPropagation()}>
            <div className="flex items-center justify-between px-6 pt-5 pb-4 border-b border-white/8">
              <div>
                <h3 className="text-lg font-black uppercase tracking-tight flex items-center gap-2">
                  <LayoutGrid className="w-5 h-5 text-violet-400"/> Personalizar Home
                </h3>
                <p className="text-xs text-zinc-600 mt-0.5">Arrastrá ⠿ para reordenar · S/M/L para tamaño</p>
              </div>
              <button onClick={()=>setShowWidgetEditor(false)} className="p-2 bg-zinc-900 rounded-xl">
                <X className="w-4 h-4"/>
              </button>
            </div>

            {/* Drag-sortable list */}
            <DndContext
              sensors={dndSensors}
              collisionDetection={closestCenter}
              onDragEnd={({ active, over }) => {
                if (over && active.id !== over.id) reorderWidgets(String(active.id), String(over.id));
              }}
            >
              <SortableContext items={widgetOrder} strategy={verticalListSortingStrategy}>
                <div className="overflow-y-auto max-h-[60vh] px-4 py-3 space-y-1.5">
                  {widgetOrder.map(id => {
                    const widget = WIDGET_LIST.find(w => w.id === id);
                    if (!widget) return null;
                    return (
                      <SortableWidgetItem
                        key={id}
                        widget={widget}
                        hidden={isHidden(id)}
                        size={getWidgetSize(id)}
                        onToggle={toggleWidget}
                        onCycleSize={cycleWidgetSize}
                      />
                    );
                  })}
                </div>
              </SortableContext>
            </DndContext>

            <div className="px-6 py-3 border-t border-white/8 flex gap-2">
              <button onClick={() => { setHiddenWidgets(new Set()); localStorage.removeItem(HIDDEN_WIDGETS_KEY); haptic(12); }}
                className="flex-1 py-2.5 text-xs font-bold text-violet-400 bg-violet-600/10 rounded-xl active:opacity-60">
                Mostrar todos
              </button>
              <button onClick={() => {
                const all = new Set(WIDGET_LIST.map(w => w.id));
                setHiddenWidgets(all);
                localStorage.setItem(HIDDEN_WIDGETS_KEY, JSON.stringify([...all]));
                haptic(12);
              }} className="flex-1 py-2.5 text-xs font-bold text-rose-400 bg-rose-500/10 rounded-xl active:opacity-60">
                Ocultar todos
              </button>
              <button onClick={() => {
                setWidgetOrder(WIDGET_LIST.map(w => w.id));
                localStorage.removeItem(WIDGET_ORDER_KEY);
                haptic(8);
              }} className="flex-1 py-2.5 text-xs font-bold text-zinc-500 bg-zinc-900/60 rounded-xl active:opacity-60">
                Orden original
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ════════════════════════════════
          MODAL: Dictado por voz (Home)
      ════════════════════════════════ */}
      {showVoiceDictado && (
        <div className="fixed inset-0 z-[200] flex items-end justify-center md:items-center">
          <div
            className="absolute inset-0 bg-black/70 backdrop-blur-sm"
            onClick={() => { setShowVoiceDictado(false); stopHomeDictado(); }}
          />
          <div className="relative w-full max-w-md bg-zinc-950 rounded-t-[2rem] md:rounded-[2rem] border border-white/8 p-6 pb-[calc(env(safe-area-inset-bottom)+24px)] md:pb-6 mx-auto">

            {/* Header */}
            <div className="flex items-center justify-between mb-5">
              <div className="flex items-center gap-3">
                <div className={`p-2 rounded-xl transition-all ${isDictandoHome ? 'bg-rose-600 animate-pulse' : 'bg-violet-600/30'}`}>
                  {isDictandoHome
                    ? <Mic className="w-5 h-5 text-white"/>
                    : <MicOff className="w-5 h-5 text-violet-400"/>
                  }
                </div>
                <div>
                  <p className="font-black text-white text-base">{isDictandoHome ? 'Escuchando…' : 'Dictado'}</p>
                  <p className="text-xs text-zinc-500">{isDictandoHome ? 'Hablá ahora' : 'Tocá para dictar'}</p>
                </div>
              </div>
              <button
                onClick={() => { setShowVoiceDictado(false); stopHomeDictado(); }}
                className="p-2 bg-zinc-900 rounded-xl active:opacity-60">
                <X className="w-4 h-4"/>
              </button>
            </div>

            {/* Live transcript */}
            <div className="min-h-[60px] bg-black/40 rounded-2xl p-4 mb-4 border border-white/5">
              {voiceTranscript || voiceInterim ? (
                <p className="text-sm text-zinc-200 leading-relaxed">
                  {voiceTranscript}
                  <span className="text-zinc-500 italic">{voiceInterim}</span>
                </p>
              ) : (
                <p className="text-sm text-zinc-600 italic">
                  Dictá el movimiento, ej: "Gasté dos mil pesos en supermercado ayer"
                </p>
              )}
            </div>

            {/* Start / Stop */}
            <button
              onClick={isDictandoHome ? stopHomeDictado : startHomeDictado}
              className={`w-full py-3 rounded-2xl text-sm font-bold mb-4 transition-all active:scale-[0.97]
                ${isDictandoHome
                  ? 'bg-rose-600 text-white'
                  : 'bg-zinc-800 text-zinc-300 border border-white/8'}`}>
              {isDictandoHome ? '⏹ Detener' : '🎤 Dictar'}
            </button>

            {/* Auto-parsed form — editable */}
            <div className="space-y-3 mb-5">
              {/* Type toggle */}
              <div className="flex gap-2">
                {['GASTO', 'INGRESO'].map(t => (
                  <button
                    key={t}
                    onClick={() => setVoiceDraft(d => ({
                      ...d, type: t,
                      category: activeCategories[t]?.[0] || '',
                    }))}
                    className={`flex-1 py-2.5 rounded-xl text-xs font-bold transition-all active:scale-95
                      ${voiceDraft.type === t
                        ? (t === 'GASTO' ? 'bg-rose-600 text-white' : 'bg-emerald-600 text-white')
                        : 'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
                    {t === 'GASTO' ? '↗ Gasto' : '↙ Ingreso'}
                  </button>
                ))}
              </div>

              {/* Amount */}
              <div className="flex items-center gap-3 bg-zinc-900/60 rounded-2xl px-4 py-3 border border-white/8">
                <span className="text-zinc-500 text-sm font-bold">$</span>
                <input
                  type="number"
                  value={voiceDraft.amount}
                  onChange={e => setVoiceDraft(d => ({ ...d, amount: e.target.value }))}
                  placeholder="Monto"
                  className="flex-1 bg-transparent text-white text-lg font-black placeholder-zinc-600 outline-none min-w-0"
                />
              </div>

              {/* Category */}
              <select
                value={voiceDraft.category}
                onChange={e => setVoiceDraft(d => ({ ...d, category: e.target.value }))}
                className="w-full bg-zinc-900/60 text-zinc-200 text-sm font-semibold rounded-2xl px-4 py-3 border border-white/8 outline-none">
                {(activeCategories[voiceDraft.type] || []).map(c => (
                  <option key={c} value={c}>{c}</option>
                ))}
              </select>

              {/* Date */}
              <input
                type="date"
                value={voiceDraft.date}
                onChange={e => setVoiceDraft(d => ({ ...d, date: e.target.value }))}
                className="w-full bg-zinc-900/60 text-zinc-200 text-sm rounded-2xl px-4 py-3 border border-white/8 outline-none"
              />

              {/* Note */}
              <input
                value={voiceDraft.note}
                onChange={e => setVoiceDraft(d => ({ ...d, note: e.target.value }))}
                placeholder="Nota (auto-completada)"
                className="w-full bg-zinc-900/60 text-zinc-200 text-sm rounded-2xl px-4 py-3 border border-white/8 outline-none placeholder-zinc-600"
              />
            </div>

            {/* Save */}
            <button
              onClick={saveVoiceDraft}
              disabled={voiceDraftSaving || !voiceDraft.amount || !voiceDraft.category}
              className="w-full py-4 bg-violet-600 rounded-2xl text-base font-black text-white active:scale-[0.97] disabled:opacity-40 disabled:cursor-not-allowed transition-all">
              {voiceDraftSaving ? 'Guardando…' : 'Guardar movimiento ✅'}
            </button>
          </div>
        </div>
      )}

      {/* ════════════════════════════════
          MODAL: Detalle Ingresos / Gastos (Home)
      ════════════════════════════════ */}
      {/* ════════════════════════════════
          (Drawer de distribución eliminado — ahora se edita directamente por cuenta)
      ════════════════════════════════ */}

      {/* ════════════════════════════════
          MODAL: Detalle Disponible por categoría (desde Home)
      ════════════════════════════════ */}
      {homeDetailType === 'DISPONIBLE' && (() => {
        const savingsAmt  = Math.round(homeStats.income * (strategy.savingsPercent||0) / 100);
        const investAmt   = Math.round(homeStats.income * (strategy.investmentPercent||0) / 100);
        // Categorías con presupuesto asignado
        const catsWithBudget = activeCategories.GASTO.filter(cat => getAggregatedBudget(cat) > 0);
        // Calcular disponible presupuestado (según plan)
        const totalBudgetsAmt = activeCategories.GASTO.reduce((acc, cat) => {
          return acc + getAggregatedBudget(cat);
        }, 0);
        const dispPresupuestado = homeStats.income - savingsAmt - investAmt - totalBudgetsAmt;
        return (
          <div className="fixed inset-0 z-[200] flex flex-col bg-black">
            {/* Header */}
            <div className="px-6 pt-[calc(env(safe-area-inset-top)+20px)] pb-5 border-b border-white/8 flex items-center justify-between">
              <div>
                <p className="text-[10px] font-bold uppercase tracking-wider text-zinc-500">
                  {MONTHS[currentDate.getMonth()]} {currentDate.getFullYear()}
                </p>
                <h3 className="text-2xl font-black text-violet-400 flex items-center gap-2">
                  <Wallet className="w-6 h-6"/> Disponible
                </h3>
                <p className="text-3xl font-black text-white mt-0.5">${formatNumber(homeStats.available)}</p>
                <p className="text-xs text-zinc-600 mt-0.5">Ingresos − Gastos − Ahorro − Inversión</p>
              </div>
              <button onClick={()=>setHomeDetailType(null)} className="p-2.5 bg-zinc-900 rounded-2xl">
                <X className="w-5 h-5"/>
              </button>
            </div>

            <div className="flex-1 overflow-y-auto no-scrollbar pb-[calc(env(safe-area-inset-bottom)+24px)]">
              <div className="px-5 pt-5 space-y-5">

                {/* Resumen de cómo se compone */}
                <div className="bg-zinc-900/60 rounded-2xl border border-white/5 overflow-hidden">
                  {[
                    { label: 'Ingresos del mes',  value: homeStats.income,           color: 'text-emerald-400', sign: '+' },
                    { label: `Ahorro (${strategy.savingsPercent||0}%)`,    value: savingsAmt,   color: 'text-zinc-400',   sign: '−' },
                    { label: `Inversión (${strategy.investmentPercent||0}%)`, value: investAmt,  color: 'text-zinc-400',   sign: '−' },
                    { label: 'Gastos del mes',     value: homeStats.expenses,         color: 'text-rose-400',    sign: '−' },
                  ].map(({ label, value, color, sign }, i, arr) => (
                    <div key={label} className={`flex items-center justify-between px-4 py-3 ${i < arr.length-1 ? 'border-b border-white/5' : ''}`}>
                      <span className="text-sm text-zinc-400">{label}</span>
                      <span className={`text-sm font-bold ${color}`}>{sign} ${formatNumber(value)}</span>
                    </div>
                  ))}
                  <div className="flex items-center justify-between px-4 py-3 bg-violet-600/10 border-t border-violet-500/20">
                    <span className="text-sm font-bold text-zinc-200">= Saldo disponible</span>
                    <span className={`text-base font-black ${homeStats.available >= 0 ? 'text-white' : 'text-rose-400'}`}>${formatNumber(homeStats.available)}</span>
                  </div>
                </div>

                {/* Disponible por categoría según presupuesto */}
                <div>
                  <div className="flex items-center justify-between mb-3">
                    <p className="text-[10px] font-bold uppercase tracking-wider text-zinc-600">Por categoría (presupuesto)</p>
                    {dispPresupuestado !== 0 && (
                      <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${dispPresupuestado >= 0 ? 'bg-emerald-500/10 text-emerald-400' : 'bg-rose-500/10 text-rose-400'}`}>
                        {dispPresupuestado >= 0 ? 'Sin asignar' : 'Excedido'}: ${formatNumber(Math.abs(dispPresupuestado))}
                      </span>
                    )}
                  </div>
                  {catsWithBudget.length === 0 ? (
                    <div className="bg-zinc-900/40 rounded-2xl border border-white/5 px-5 py-8 text-center">
                      <p className="text-zinc-600 text-sm mb-1">Sin presupuestos asignados</p>
                      <p className="text-zinc-700 text-xs">Configurá límites en el tab Presupuesto</p>
                      <button onClick={()=>{ setHomeDetailType(null); setActiveTab('budget'); haptic(8); }}
                        className="mt-4 px-4 py-2 bg-violet-700/15 border border-violet-500/30 rounded-xl text-xs font-bold text-violet-400 active:opacity-60">
                        Ir a Presupuesto →
                      </button>
                    </div>
                  ) : (
                    <div className="space-y-2">
                      {catsWithBudget.map(cat => {
                        const mode = budgetModes[cat] || '$';
                        const raw  = getAggregatedBudget(cat);
                        const limit = raw;
                        const spent = homeStats.expenseByCategory[cat] || 0;
                        const remaining = limit - spent;
                        const pct = limit > 0 ? Math.min(100, Math.round((spent/limit)*100)) : 0;
                        const isOver = remaining < 0;
                        const barColor = isOver ? '#f43f5e' : pct > 80 ? '#f59e0b' : '#7c3aed';
                        return (
                          <div key={cat} className="bg-zinc-900/60 rounded-2xl px-4 py-3.5 border border-white/5">
                            <div className="flex items-center justify-between mb-2">
                              <div className="flex items-center gap-2">
                                <span className="text-base">{getEmoji(cat)}</span>
                                <span className="text-sm font-semibold text-zinc-200">{cat}</span>
                                {mode === '%' && <span className="text-[9px] text-zinc-600 bg-zinc-800 rounded-full px-1.5">{raw}%</span>}
                              </div>
                              <div className="text-right">
                                <p className={`text-sm font-black ${isOver ? 'text-rose-400' : 'text-white'}`}>
                                  {isOver ? '−' : ''}${formatNumber(Math.abs(remaining))}
                                </p>
                                <p className="text-[9px] text-zinc-600">{isOver ? 'excedido' : 'restante'}</p>
                              </div>
                            </div>
                            <div className="h-1.5 bg-zinc-800 rounded-full overflow-hidden mb-1.5">
                              <div className="h-full rounded-full transition-all"
                                style={{ width:`${pct}%`, backgroundColor: barColor }}/>
                            </div>
                            <div className="flex justify-between text-[10px] text-zinc-600 font-semibold">
                              <span>Gastado ${formatNumber(spent)}</span>
                              <span>Límite ${formatNumber(limit)}</span>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        );
      })()}

      {homeDetailType && homeDetailType !== 'DISPONIBLE' && (() => {
        const isIngreso = homeDetailType === 'INGRESO';
        const homeMonthTxs = homeAccount ? monthTxs.filter(t => t.account === homeAccount) : monthTxs;
        const txs = homeMonthTxs.filter(t => t.type === homeDetailType).sort((a,b) => new Date(b.date) - new Date(a.date));
        const total = txs.reduce((s,t) => s + Number(t.amount), 0);
        // Agrupar por categoría
        const byCat = {};
        txs.forEach(t => {
          if (!byCat[t.category]) byCat[t.category] = { total: 0, txs: [] };
          byCat[t.category].total += Number(t.amount);
          byCat[t.category].txs.push(t);
        });
        const catList = Object.entries(byCat).sort((a,b) => b[1].total - a[1].total);
        const accentColor = isIngreso ? 'emerald' : 'rose';
        return (
          <div className="fixed inset-0 z-[200] flex flex-col bg-black">
            {/* Header */}
            <div className="px-6 pt-[calc(env(safe-area-inset-top)+20px)] pb-5 border-b border-white/8 flex items-center justify-between">
              <div>
                <p className="text-[10px] font-bold uppercase tracking-wider text-zinc-500">
                  {MONTHS[currentDate.getMonth()]} {currentDate.getFullYear()}
                </p>
                <h3 className={`text-2xl font-black ${isIngreso ? 'text-emerald-400' : 'text-rose-400'} flex items-center gap-2`}>
                  {isIngreso ? <ArrowUpRight className="w-6 h-6"/> : <ArrowDownLeft className="w-6 h-6"/>}
                  {isIngreso ? tl('incomesLabel') : tl('expensesTitle')}
                </h3>
                <p className="text-3xl font-black text-white mt-0.5">${formatNumber(total)}</p>
              </div>
              <button onClick={()=>setHomeDetailType(null)} className="p-2.5 bg-zinc-900 rounded-2xl">
                <X className="w-5 h-5"/>
              </button>
            </div>

            <div className="flex-1 overflow-y-auto no-scrollbar pb-[calc(env(safe-area-inset-bottom)+24px)]">
              {txs.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-24 space-y-3">
                  <p className="text-4xl">{isIngreso ? '💰' : '🧾'}</p>
                  <p className="text-sm font-semibold text-zinc-600">Sin {isIngreso ? 'ingresos' : 'gastos'} este mes</p>
                </div>
              ) : (
                <div className="px-5 pt-5 space-y-5">
                  {/* Resumen por categoría */}
                  <div>
                    <p className="text-[10px] font-bold uppercase tracking-wider text-zinc-600 mb-3">Por categoría</p>
                    <div className="space-y-2">
                      {catList.map(([cat, data]) => {
                        const pct = total > 0 ? Math.round((data.total / total) * 100) : 0;
                        const catColor = chartData.find(d=>d.cat===cat)?.color || (isIngreso ? '#10b981' : '#f43f5e');
                        return (
                          <div key={cat} className="bg-zinc-900/60 rounded-2xl px-4 py-3 border border-white/5">
                            <div className="flex items-center justify-between mb-1.5">
                              <div className="flex items-center gap-2">
                                <span className="text-base">{getEmoji(cat)}</span>
                                <span className="text-sm font-semibold text-zinc-200">{cat}</span>
                                <span className="text-[10px] font-semibold text-zinc-600 bg-zinc-800 rounded-full px-1.5 py-0.5">{data.txs.length}</span>
                              </div>
                              <div className="text-right">
                                <p className="text-sm font-black text-white">${formatNumber(data.total)}</p>
                                <p className="text-[10px] text-zinc-600 font-semibold">{pct}%</p>
                              </div>
                            </div>
                            {/* Barra de proporción */}
                            <div className="h-1 bg-zinc-800 rounded-full overflow-hidden">
                              <div className="h-full rounded-full" style={{width:`${pct}%`, backgroundColor: catColor}}/>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>

                  {/* Lista de transacciones */}
                  <div>
                    <p className="text-[10px] font-bold uppercase tracking-wider text-zinc-600 mb-3">Movimientos ({txs.length})</p>
                    <div className="space-y-2">
                      {txs.map(t => {
                        const d = new Date(t.date);
                        const catColor = chartData.find(c=>c.cat===t.category)?.color || (isIngreso ? '#10b981' : '#f43f5e');
                        return (
                          <div key={t.id} className="flex items-center gap-3 bg-zinc-900/50 rounded-2xl px-4 py-3 border border-white/5">
                            <div className="w-10 h-10 rounded-xl flex items-center justify-center text-lg flex-shrink-0"
                              style={{backgroundColor:`${catColor}18`}}>
                              {getEmoji(t.category)}
                            </div>
                            <div className="flex-1 min-w-0">
                              <p className="text-sm font-bold text-zinc-200 truncate">{t.category}</p>
                              {t.note && t.note.trim() && (
                                <p className="text-[11px] text-zinc-600 truncate mt-0.5">{t.note}</p>
                              )}
                              <p className="text-[10px] text-zinc-700 mt-0.5 font-medium">
                                {d.toLocaleDateString('es-AR', { weekday: 'short', day: 'numeric', month: 'short' })}
                              </p>
                            </div>
                            <p className={`text-sm font-black flex-shrink-0 ${isIngreso ? 'text-emerald-400' : 'text-rose-400'}`}>
                              ${formatNumber(Number(t.amount))}
                            </p>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        );
      })()}

      {/* ════════════════════════════════
          MODAL: Picker de mes (Historial)
      ════════════════════════════════ */}
      {showHistoryMonthPicker && (
        <div className="fixed inset-0 z-[200] flex items-end justify-center md:items-center">
          <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={()=>setShowHistoryMonthPicker(false)}/>
          <div className="relative w-full max-w-md bg-zinc-950 rounded-t-[2rem] md:rounded-[2rem] border border-white/8 p-6 pb-[calc(env(safe-area-inset-bottom)+24px)] md:pb-6">
            {/* Header */}
            <div className="flex items-center justify-between mb-5">
              <h3 className="font-black text-white text-lg">Elegir mes</h3>
              <button onClick={()=>setShowHistoryMonthPicker(false)} className="p-2 bg-zinc-900 rounded-xl">
                <X className="w-4 h-4"/>
              </button>
            </div>

            {/* Opción Todos los meses */}
            <button
              onClick={() => { setAllMonths(true); setSelectedHistoryMonth(null); setShowHistoryMonthPicker(false); haptic(8); }}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-2xl border mb-4 transition-all
                ${allMonths ? 'bg-violet-600 border-violet-500/40 text-white' : 'bg-zinc-900/60 border-white/8 text-zinc-400'}`}>
              <Calendar className="w-4 h-4 flex-shrink-0"/>
              <span className="font-bold text-sm flex-1 text-left">Todos los meses</span>
              {allMonths && <Check className="w-4 h-4"/>}
            </button>

            {/* Grilla de meses por año */}
            <div className="overflow-y-auto max-h-[50vh] space-y-4 no-scrollbar">
              {Object.entries(
                availableYearMonths.reduce((acc, ym) => {
                  if (!acc[ym.year]) acc[ym.year] = [];
                  acc[ym.year].push(ym);
                  return acc;
                }, {})
              ).sort(([a],[b]) => Number(b) - Number(a)).map(([year, months]) => (
                <div key={year}>
                  <p className="text-[10px] font-bold text-zinc-600 uppercase tracking-wider mb-2">{year}</p>
                  <div className="grid grid-cols-4 gap-2">
                    {months.map(ym => {
                      const isCurrent = currentDate.getFullYear()===ym.year && currentDate.getMonth()===ym.month;
                      const isSelected = !allMonths && (
                        selectedHistoryMonth
                          ? selectedHistoryMonth.year===ym.year && selectedHistoryMonth.month===ym.month
                          : isCurrent
                      );
                      return (
                        <button key={`${ym.year}-${ym.month}`}
                          onClick={() => {
                            if (isCurrent) {
                              setAllMonths(false); setSelectedHistoryMonth(null);
                            } else {
                              setAllMonths(false); setSelectedHistoryMonth({ year: ym.year, month: ym.month });
                            }
                            setShowHistoryMonthPicker(false); haptic(8);
                          }}
                          className={`py-2.5 rounded-xl text-xs font-bold transition-all
                            ${isSelected ? 'bg-violet-600 text-white shadow-lg shadow-violet-500/20' : 'bg-zinc-900/60 border border-white/8 text-zinc-400 active:bg-zinc-800'}`}>
                          {MONTHS[ym.month].slice(0,3)}
                          {isCurrent && !isSelected && <span className="block text-[8px] text-violet-400 mt-0.5">hoy</span>}
                        </button>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* ════════════════════════════════
          MODAL: Filtro de categorías (Historial)
      ════════════════════════════════ */}
      {showCatFilter && (
        <div className="fixed inset-0 z-[200] flex items-end justify-center md:items-center">
          <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={()=>setShowCatFilter(false)}/>
          <div className="relative w-full max-w-md bg-zinc-950 rounded-t-[2rem] md:rounded-[2rem] border border-white/8 p-6 pb-[calc(env(safe-area-inset-bottom)+24px)] md:pb-6">
            {/* Header */}
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-black text-white text-lg">Categorías</h3>
              <div className="flex items-center gap-2">
                {filterCategories.size > 0 && (
                  <button onClick={() => { setFilterCategories(new Set()); haptic(6); }}
                    className="text-xs font-bold text-zinc-500 px-3 py-1.5 bg-zinc-900 rounded-lg active:opacity-60">
                    Limpiar
                  </button>
                )}
                <button onClick={()=>setShowCatFilter(false)} className="p-2 bg-zinc-900 rounded-xl">
                  <X className="w-4 h-4"/>
                </button>
              </div>
            </div>

            {/* Seleccionar todas */}
            <button
              onClick={() => {
                if (filterCategories.size === filterableCats.length && filterableCats.length > 0) {
                  setFilterCategories(new Set());
                } else {
                  setFilterCategories(new Set(filterableCats));
                }
                haptic(8);
              }}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-2xl border mb-3 transition-all
                ${filterCategories.size === filterableCats.length && filterableCats.length > 0
                  ? 'bg-violet-600 border-violet-500/40 text-white'
                  : 'bg-zinc-900/60 border-white/8 text-zinc-400'}`}>
              <div className={`w-5 h-5 rounded-md border-2 flex items-center justify-center flex-shrink-0 transition-all
                ${filterCategories.size === filterableCats.length && filterableCats.length > 0 ? 'bg-white border-white' : filterCategories.size > 0 ? 'border-violet-500' : 'border-zinc-600'}`}>
                {filterCategories.size === filterableCats.length && filterableCats.length > 0
                  ? <Check className="w-3 h-3 text-violet-600"/>
                  : filterCategories.size > 0
                  ? <div className="w-2 h-0.5 bg-violet-400 rounded"/>
                  : null}
              </div>
              <span className="font-bold text-sm flex-1 text-left">Todas las categorías</span>
              <span className="text-xs text-zinc-500">{filterableCats.length}</span>
            </button>

            {/* Lista de categorías */}
            <div className="overflow-y-auto max-h-[50vh] space-y-1.5 no-scrollbar">
              {filterableCats.map(cat => {
                const isChecked = filterCategories.has(cat);
                const catColor = chartData.find(d=>d.cat===cat)?.color || '#6366f1';
                const baseForCount = allMonths ? transactions : selectedHistoryMonth
                  ? transactions.filter(t => { const d=new Date(t.date); return d.getFullYear()===selectedHistoryMonth.year && d.getMonth()===selectedHistoryMonth.month; })
                  : monthTxs;
                const catTxCount = baseForCount.filter(t => (filterType==='ALL' || t.type===filterType) && t.category===cat).length;
                return (
                  <button key={cat}
                    onClick={() => {
                      setFilterCategories(prev => {
                        const next = new Set(prev);
                        if (next.has(cat)) next.delete(cat); else next.add(cat);
                        return next;
                      });
                      haptic(6);
                    }}
                    className={`w-full flex items-center gap-3 px-4 py-3 rounded-2xl border transition-all
                      ${isChecked ? 'bg-zinc-800 border-white/12' : 'bg-zinc-900/40 border-white/5 active:bg-zinc-800/60'}`}>
                    <div
                      className={`w-5 h-5 rounded-md border-2 flex items-center justify-center flex-shrink-0 transition-all
                        ${isChecked ? 'border-transparent' : 'border-zinc-600'}`}
                      style={isChecked ? {backgroundColor: catColor} : {}}>
                      {isChecked && <Check className="w-3 h-3 text-white"/>}
                    </div>
                    <span className="text-sm">{getEmoji(cat)}</span>
                    <span className={`text-sm font-semibold flex-1 text-left ${isChecked ? 'text-white' : 'text-zinc-400'}`}>{cat}</span>
                    <span className="text-xs text-zinc-600 font-medium">{catTxCount}</span>
                  </button>
                );
              })}
            </div>

            {/* Botón aplicar */}
            <button
              onClick={() => { setShowCatFilter(false); haptic(10); }}
              className="w-full mt-4 py-3.5 bg-violet-600 rounded-2xl text-sm font-black text-white active:scale-[0.97] transition-all">
              {filterCategories.size === 0
                ? 'Mostrar todas'
                : `Ver ${filterCategories.size} categoría${filterCategories.size !== 1 ? 's' : ''}`}
            </button>
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

      {/* ── MP OAUTH LOADING OVERLAY ─────────────────────── */}
      {mpOAuthLoading && (
        <div className="fixed inset-0 z-[500] bg-black/90 backdrop-blur-2xl flex flex-col items-center justify-center gap-6">
          <WalletLogo provider="mercadopago" size={72} className="rounded-2xl shadow-2xl shadow-sky-500/30"/>
          <div className="text-center space-y-2">
            <p className="text-lg font-black">Conectando Mercado Pago</p>
            <p className="text-sm text-zinc-400">Intercambiando credenciales OAuth…</p>
          </div>
          <div className="flex gap-1.5">
            {[0,1,2].map(i => (
              <div key={i} className="w-2 h-2 rounded-full bg-sky-400 animate-bounce" style={{ animationDelay: `${i*0.15}s` }}/>
            ))}
          </div>
        </div>
      )}

      {/* ── CONNECT WALLET MODAL ─────────────────────────── */}
      {showWalletConnect && (
        <div className="fixed inset-0 z-[300] bg-black/80 backdrop-blur-xl flex items-end justify-center">
          <div className="w-full max-w-md bg-zinc-950 rounded-t-[2.5rem] border-t border-white/10 px-6 pt-6 pb-[calc(1.5rem+env(safe-area-inset-bottom))] space-y-5 max-h-[90vh] overflow-y-auto">
            {/* Header */}
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                {walletConnectStep > 1 && (
                  <button onClick={() => setWalletConnectStep(s => s-1)} className="p-1.5 bg-zinc-900 rounded-xl">
                    <ChevronLeft className="w-4 h-4"/>
                  </button>
                )}
                <h3 className="text-base font-black">
                  {walletConnectStep === 1 ? 'Elegí una billetera' : walletConnectStep === 2 ? 'Configurar' : 'Confirmar'}
                </h3>
              </div>
              <button onClick={() => { setShowWalletConnect(false); setWalletConnectStep(1); setWalletConnectProv(null); setWalletConnectCreds({}); setWalletConnectName(''); }}
                className="p-2 bg-zinc-900 rounded-full"><X className="w-4 h-4"/></button>
            </div>

            {/* Step 1: Choose provider */}
            {walletConnectStep === 1 && (
              <div className="grid grid-cols-2 gap-3">
                {Object.values(WALLET_PROVIDERS).map(prov => (
                  <button key={prov.id}
                    onClick={() => { if (!prov.comingSoon) { setWalletConnectProv(prov.id); setWalletConnectStep(2); } }}
                    className={`relative flex flex-col items-center gap-2 p-4 rounded-3xl border transition-all
                      ${prov.comingSoon ? 'opacity-40 cursor-not-allowed ' + prov.bgClass + ' ' + prov.borderClass
                        : 'active:scale-95 ' + prov.bgClass + ' ' + prov.borderClass}`}>
                    <WalletLogo provider={prov.id} size={44} className="rounded-xl"/>
                    <span className="text-xs font-black text-center leading-tight">{prov.name}</span>
                    {prov.comingSoon && (
                      <span className="absolute top-2 right-2 text-[9px] bg-zinc-700 text-zinc-400 rounded-full px-1.5 py-0.5 font-bold">Próx.</span>
                    )}
                  </button>
                ))}
              </div>
            )}

            {/* Step 2: Enter credentials */}
            {walletConnectStep === 2 && walletConnectProv && (() => {
              const prov = WALLET_PROVIDERS[walletConnectProv];
              const isMP = prov.id === 'mercadopago';
              return (
                <div className="space-y-4">
                  {/* Provider header */}
                  <div className={`flex items-center gap-3 p-4 rounded-2xl ${prov.bgClass} border ${prov.borderClass}`}>
                    <WalletLogo provider={prov.id} size={40} className="rounded-xl flex-shrink-0"/>
                    <div>
                      <p className="font-black text-sm">{prov.name}</p>
                      {prov.helpText && <p className="text-xs text-zinc-400 mt-0.5">{prov.helpText}</p>}
                    </div>
                  </div>

                  {/* ── Mercado Pago: OAuth button (primary) + manual (secondary) ── */}
                  {isMP && (
                    <>
                      {/* OAuth — recommended */}
                      <button onClick={startMPOAuth}
                        className="w-full py-4 rounded-2xl font-black text-sm flex items-center justify-center gap-3 active:scale-95 transition-all"
                        style={{ background: '#009EE3', color: 'white' }}>
                        <WalletLogo provider="mercadopago" size={24} className="rounded-md"/>
                        Conectar con Mercado Pago
                      </button>

                      {/* Divider */}
                      <div className="flex items-center gap-3">
                        <div className="flex-1 h-px bg-white/10"/>
                        <span className="text-xs text-zinc-600 font-semibold">o</span>
                        <div className="flex-1 h-px bg-white/10"/>
                      </div>

                      {/* Manual toggle */}
                      <button onClick={() => setMpManualToken(v => !v)}
                        className="w-full py-3 rounded-2xl border border-white/10 text-xs text-zinc-500 font-semibold flex items-center justify-center gap-2 active:scale-95 transition-all">
                        <span>{mpManualToken ? '▲' : '▼'}</span>
                        Usar Access Token manualmente
                      </button>

                      {/* Manual token input (collapsed by default) */}
                      {mpManualToken && (
                        <div className="space-y-3">
                          <div className="space-y-1.5">
                            <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wide">Access Token</p>
                            <input
                              type="text"
                              placeholder="APP_USR-..."
                              value={walletConnectCreds.access_token || ''}
                              onChange={e => setWalletConnectCreds(p => ({ ...p, access_token: e.target.value }))}
                              className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm font-mono focus:outline-none focus:border-violet-500/60 text-zinc-200"
                            />
                          </div>
                          <a href={prov.helpUrl} target="_blank" rel="noopener noreferrer"
                            className="flex items-center gap-2 text-xs text-sky-400 underline">
                            Cómo obtener mi Access Token →
                          </a>
                          <button onClick={() => setWalletConnectStep(3)}
                            disabled={!walletConnectCreds.access_token?.trim()}
                            className="w-full py-4 bg-violet-600 rounded-2xl font-black text-sm uppercase tracking-widest active:scale-95 transition-all disabled:opacity-40">
                            Continuar con token manual
                          </button>
                        </div>
                      )}
                    </>
                  )}

                  {/* ── Otros providers: flujo estándar con campos ── */}
                  {!isMP && (
                    <>
                      {prov.fields.map(field => (
                        <div key={field.key} className="space-y-1.5">
                          <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wide">{field.label}</p>
                          <input
                            type={field.type === 'password' ? 'text' : field.type}
                            placeholder={field.placeholder}
                            value={walletConnectCreds[field.key] || ''}
                            onChange={e => setWalletConnectCreds(p => ({ ...p, [field.key]: e.target.value }))}
                            className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm font-mono focus:outline-none focus:border-violet-500/60 text-zinc-200"
                          />
                        </div>
                      ))}
                      {prov.helpUrl && (
                        <a href={prov.helpUrl} target="_blank" rel="noopener noreferrer"
                          className={`flex items-center gap-2 text-xs ${prov.textClass} underline`}>
                          Cómo obtener mis credenciales →
                        </a>
                      )}
                      <button onClick={() => setWalletConnectStep(3)}
                        disabled={prov.fields.some(f => !walletConnectCreds[f.key]?.trim())}
                        className="w-full py-4 bg-violet-600 rounded-2xl font-black text-sm uppercase tracking-widest active:scale-95 transition-all disabled:opacity-40">
                        Continuar
                      </button>
                    </>
                  )}
                </div>
              );
            })()}

            {/* Step 3: Name + confirm */}
            {walletConnectStep === 3 && walletConnectProv && (() => {
              const prov = WALLET_PROVIDERS[walletConnectProv];
              return (
                <div className="space-y-4">
                  <div className="space-y-1.5">
                    <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wide">Nombre de la billetera</p>
                    <input
                      type="text"
                      placeholder={prov.name}
                      value={walletConnectName}
                      onChange={e => setWalletConnectName(e.target.value)}
                      className="w-full bg-zinc-900 rounded-2xl p-4 border border-white/10 text-sm font-bold focus:outline-none focus:border-violet-500/60 text-zinc-200"
                    />
                  </div>
                  <div className={`p-4 rounded-2xl ${prov.bgClass} border ${prov.borderClass} space-y-1`}>
                    <p className="text-xs font-semibold text-zinc-400">Resumen</p>
                    <p className="font-black">{walletConnectName.trim() || prov.name}</p>
                    <p className={`text-xs ${prov.textClass}`}>{prov.name}</p>
                    {prov.fields.length > 0 && (
                      <p className="text-xs text-zinc-600 font-mono truncate">
                        {prov.fields[0].key}: {walletConnectCreds[prov.fields[0].key]?.slice(0,12)}...
                      </p>
                    )}
                  </div>
                  <button onClick={connectWallet} disabled={walletConnectLoading}
                    className="w-full py-4 bg-violet-600 rounded-2xl font-black text-sm uppercase tracking-widest active:scale-95 transition-all disabled:opacity-50">
                    {walletConnectLoading ? 'Conectando...' : 'Conectar billetera'}
                  </button>
                </div>
              );
            })()}
          </div>
        </div>
      )}

      {/* ── WALLET MOVEMENTS DETAIL ──────────────────────── */}
      {selectedWallet && (
        <div className="fixed inset-0 z-[300] bg-black/80 backdrop-blur-xl flex items-end justify-center">
          <div className="w-full max-w-md bg-zinc-950 rounded-t-[2.5rem] border-t border-white/10 pb-[calc(1rem+env(safe-area-inset-bottom))] max-h-[90vh] flex flex-col">
            {/* Header */}
            {(() => {
              const prov = WALLET_PROVIDERS[selectedWallet.provider] || WALLET_PROVIDERS.manual;
              const isSyncing = syncingWalletId === selectedWallet.id;
              return (
                <div className="px-6 pt-6 pb-4 flex items-center gap-3 border-b border-white/5 flex-shrink-0">
                  <WalletLogo provider={selectedWallet.provider} size={40} className="rounded-xl flex-shrink-0"/>
                  <div className="flex-1 min-w-0">
                    <p className="font-black truncate">{selectedWallet.name}</p>
                    <p className="text-sm font-black text-white">{fmtMoney(selectedWallet.balance || 0)}</p>
                  </div>
                  <button onClick={() => syncWallet(selectedWallet)} disabled={isSyncing}
                    className={`p-2.5 rounded-2xl ${prov.bgClass} border ${prov.borderClass} active:scale-95 transition-all disabled:opacity-50`}>
                    <RefreshCw className={`w-4 h-4 ${prov.textClass} ${isSyncing?'animate-spin':''}`}/>
                  </button>
                  <button onClick={() => { setSelectedWallet(null); setWalletMovements([]); }}
                    className="p-2.5 bg-zinc-900 rounded-2xl active:scale-95 transition-all ml-1">
                    <X className="w-4 h-4"/>
                  </button>
                </div>
              );
            })()}
            {/* Movements list */}
            <div className="overflow-y-auto flex-1 px-5 py-3 space-y-2">
              {walletMovements.length === 0 ? (
                <div className="text-center py-12">
                  <p className="text-zinc-600 text-sm">Sin movimientos guardados</p>
                  <p className="text-zinc-700 text-xs mt-1">Sincronizá para importar tus movimientos</p>
                </div>
              ) : walletMovements.map(m => (
                <div key={m.id} className="flex items-center gap-3 bg-zinc-900/60 rounded-2xl px-4 py-3">
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold truncate">{m.description || 'Sin descripción'}</p>
                    <p className="text-xs text-zinc-600">{new Date(m.date).toLocaleDateString('es-AR',{day:'numeric',month:'short',year:'2-digit'})}</p>
                    {m.status === 'synced' && <p className="text-[10px] text-emerald-500 font-bold">✓ importado</p>}
                  </div>
                  <div className="text-right flex-shrink-0">
                    <p className={`text-sm font-black ${m.type === 'GASTO' ? 'text-red-400' : 'text-emerald-400'}`}>
                      {m.type === 'GASTO' ? '-' : '+'}{fmtMoney(m.amount)}
                    </p>
                    {m.status !== 'synced' && (
                      <button onClick={() => importWalletMovement(m, selectedWallet.id)}
                        className="text-[10px] text-violet-400 font-bold mt-0.5 active:opacity-70">
                        Importar →
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
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
            className="w-full bg-zinc-900/60 border border-white/10 rounded-2xl px-4 py-4 text-xl font-black text-white focus:outline-none focus:border-violet-500/40 placeholder:text-zinc-700"/>
        </div>

        {/* TNA + Días */}
        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <label className="text-xs font-bold text-zinc-400 ml-1">TNA (%)</label>
            <input
              type="text" inputMode="decimal" value={tna}
              onChange={e => setTna(e.target.value)}
              placeholder="100"
              className="w-full bg-zinc-900/60 border border-white/10 rounded-2xl px-4 py-4 text-lg font-black text-white focus:outline-none focus:border-violet-500/40 placeholder:text-zinc-700"/>
          </div>
          <div className="space-y-1.5">
            <label className="text-xs font-bold text-zinc-400 ml-1">Plazo</label>
            <div className="flex gap-1.5">
              {['30','60','90'].map(d => (
                <button key={d} onClick={() => setDias(d)}
                  className={`flex-1 py-4 rounded-2xl text-xs font-black transition-all active:scale-90
                    ${dias === d ? 'bg-violet-600 text-white shadow-lg' : 'bg-zinc-900 text-zinc-500 border border-white/8'}`}>
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
            <div className="bg-violet-500/10 border border-violet-500/20 rounded-2xl p-4">
              <div className="flex items-center justify-between mb-1.5">
                <span className="text-xs font-bold text-zinc-400 uppercase tracking-wider">Total a cobrar</span>
                <span className="text-2xl font-black text-white">${fmt(result.totalNeto)}</span>
              </div>
              <div className="flex items-center justify-between text-xs text-zinc-600">
                <span>TNA efectiva neta</span>
                <span className="text-violet-300 font-bold">{result.tnaEfNeta.toFixed(2)}%</span>
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
                        ${d === dias ? 'bg-violet-700/15 border-violet-500/30' : 'bg-zinc-900/40 border-white/5'}`}>
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

      /* ── Light Theme ── */
      .light-theme {
        filter: invert(1) hue-rotate(180deg);
      }
      .light-theme img,
      .light-theme video,
      .light-theme svg rect,
      .light-theme [class*="glass-"],
      .light-theme .emoji-native {
        filter: invert(1) hue-rotate(180deg);
      }
      .light-theme span[style*="font-size"] {
        filter: invert(1) hue-rotate(180deg);
      }
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
