// MetaCasa — constants puras (sin dependencias de React ni DOM).
// Extraido de App.jsx en Fase 2.

export const INITIAL_CATEGORIES = {
  GASTO: ["Vivienda", "Transporte", "Salud", "Ocio", "Alimentación", "Servicios"],
  INGRESO: ["Sueldo", "Inversiones", "Ventas"],
};

export const MONTHS = ["ENERO","FEBRERO","MARZO","ABRIL","MAYO","JUNIO","JULIO","AGOSTO","SEPTIEMBRE","OCTUBRE","NOVIEMBRE","DICIEMBRE"];

export const CHART_COLORS = ['#6366f1','#f43f5e','#10b981','#f59e0b','#3b82f6','#8b5cf6','#ec4899','#14b8a6','#f97316','#84cc16'];

export const DEFAULT_EMOJIS = {
  Vivienda:'🏠', Transporte:'🚗', Salud:'🏥', Ocio:'🎮', Alimentación:'🍽️', Servicios:'⚡',
  Sueldo:'💼', Inversiones:'📈', Ventas:'🛍️',
};

export const EMOJI_PALETTE = [
  '🏠','🚗','🏥','🎮','🍽️','⚡','💼','📈','🛍️','🎓','✈️','🏋️',
  '🐶','🐱','🌿','🎵','📱','💊','🛒','🎁','🏦','💳','🍕','☕',
  '🚌','⛽','🎬','📚','👕','🏡','🔧','🧹','🌙','☀️','🍺','🎯',
  '💰','💸','🤝','📊','🔑','🏊','🎨','💡','🧘','🌊','🚀','🍎',
];

export const FREQUENCIES = [
  { v:'daily',   l:'Diario',   icon:'📅' },
  { v:'weekly',  l:'Semanal',  icon:'📆' },
  { v:'monthly', l:'Mensual',  icon:'🗓️' },
  { v:'yearly',  l:'Anual',    icon:'📌' },
];

export const CATEGORY_KEYWORDS = {
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

export const GOAL_EMOJIS = ['🎯','✈️','🏠','🚗','💻','📱','🎓','💍','🏖️','🎪','🎸','🐕','🌍','🏋️','🎮','👶','🏥','🛋️','🌿','⛵'];

export const DEFAULT_NEEDS_CATS = ['Vivienda','Transporte','Salud','Servicios','Alimentación','Alquiler','Supermercado','Educacion'];

// localStorage keys
export const GOALS_KEY          = 'metacasa_goals';
export const CUOTAS_KEY         = 'metacasa_cuotas';
export const MEMO_KEY           = 'metacasa_memos';
export const TEMPLATES_KEY      = 'metacasa_templates';
export const HIDDEN_WIDGETS_KEY = 'metacasa_hidden_widgets';
export const WIDGET_ORDER_KEY   = 'metacasa_widget_order';
export const WIDGET_SIZES_KEY   = 'metacasa_widget_sizes';
export const FIXED_TX_KEY       = 'metacasa_fixed_txs';
export const BUDGET_MODE_KEY    = 'metacasa_budget_modes';
export const ACCOUNTS_KEY       = 'metacasa_accounts';
export const ACCOUNT_TYPES_KEY  = 'metacasa_account_types';
export const ALLOCATIONS_KEY    = 'metacasa_allocations';
export const SAVINGS_ACCOUNT_KEY = 'metacasa_savings_account';
export const CURRENCY_KEY       = 'metacasa_currency';
export const LANG_KEY           = 'metacasa_lang';
export const NEEDS_CATS_KEY     = 'metacasa_needs_cats';
export const THEME_KEY          = 'metacasa_theme';
export const AI_CONFIG_KEY      = 'metacasa_ai_config';

export const loadNeedsCats = () => {
  try { return new Set(JSON.parse(localStorage.getItem(NEEDS_CATS_KEY)) || DEFAULT_NEEDS_CATS); }
  catch { return new Set(DEFAULT_NEEDS_CATS); }
};
