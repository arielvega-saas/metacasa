// MetaCasa — helpers de formato de números, parseo de voz y feedback háptico.
// Extraído de App.jsx en Fase 2.

export const formatNumber = (num) => {
  if (num === undefined || num === null || isNaN(num)) return "0";
  const absNum = Math.abs(Math.floor(Number(num)));
  const formatted = absNum.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  return Number(num) < 0 ? `-${formatted}` : formatted;
};

export const formatNumberWithDecimals = (num) => {
  if (num === undefined || num === null || isNaN(num)) return "0";
  const n = Number(num);
  const abs = Math.abs(n);
  const intPart = Math.floor(abs).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  const dec = abs % 1;
  const decPart = dec ? (',' + abs.toFixed(2).split('.')[1]) : '';
  const formatted = intPart + decPart;
  return n < 0 ? `-${formatted}` : formatted;
};

export const parseFormattedNumber = (val) => {
  if (typeof val === 'number') return val;
  if (typeof val === 'string') return parseFloat(val.replace(/\./g, '')) || 0;
  return 0;
};

export const parseVoiceAmount = (text) => {
  const digitMatch = text.match(/\b(\d[\d.,]*)\b/);
  if (digitMatch) return parseInt(digitMatch[1].replace(/[.,]/g,''));
  const words = {
    'cien':100,'ciento':100,'doscientos':200,'trescientos':300,'cuatrocientos':400,'quinientos':500,
    'mil':1000,'dos mil':2000,'tres mil':3000,'cuatro mil':4000,'cinco mil':5000,
    'seis mil':6000,'siete mil':7000,'ocho mil':8000,'nueve mil':9000,'diez mil':10000,
    'quince mil':15000,'veinte mil':20000,'treinta mil':30000,'cincuenta mil':50000,'cien mil':100000,
  };
  const lower = text.toLowerCase();
  for (const [phrase, val] of Object.entries(words)) { if (lower.includes(phrase)) return val; }
  return 0;
};

export const haptic = (ms = 10) => {
  try { navigator.vibrate?.(ms); } catch {}
};
