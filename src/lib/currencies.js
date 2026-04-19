// MetaCasa — catálogo de monedas y helpers.
// Extraído de App.jsx en Fase 2.

export const ACTIVE_CURRENCIES_KEY = 'metacasa_active_currencies';
export const DEFAULT_ACTIVE_CURRENCIES = ['ARS', 'USD', 'EUR'];

export const CURRENCIES = {
  // América Latina
  ARS: { symbol: '$',    name: 'Peso Argentino',    shortName: 'Peso ARS',  article: 'el', flag: '🇦🇷' },
  BRL: { symbol: 'R$',   name: 'Real Brasileño',    shortName: 'Real',      article: 'el', flag: '🇧🇷' },
  CLP: { symbol: 'CL$',  name: 'Peso Chileno',      shortName: 'Peso CLP',  article: 'el', flag: '🇨🇱' },
  COP: { symbol: 'CO$',  name: 'Peso Colombiano',   shortName: 'Peso COP',  article: 'el', flag: '🇨🇴' },
  MXN: { symbol: 'MX$',  name: 'Peso Mexicano',     shortName: 'Peso MXN',  article: 'el', flag: '🇲🇽' },
  PEN: { symbol: 'S/.',  name: 'Sol Peruano',       shortName: 'Sol',       article: 'el', flag: '🇵🇪' },
  UYU: { symbol: '$U',   name: 'Peso Uruguayo',     shortName: 'Peso UYU',  article: 'el', flag: '🇺🇾' },
  PYG: { symbol: '₲',    name: 'Guaraní',           shortName: 'Guaraní',   article: 'el', flag: '🇵🇾' },
  BOB: { symbol: 'Bs.',  name: 'Boliviano',         shortName: 'Boliviano', article: 'el', flag: '🇧🇴' },
  VES: { symbol: 'Bs.S', name: 'Bolívar Venezolano',shortName: 'Bolívar',   article: 'el', flag: '🇻🇪' },
  // Norte América
  USD: { symbol: 'U$S',  name: 'Dólar Estadounidense', shortName: 'Dólar',  article: 'el', flag: '🇺🇸' },
  CAD: { symbol: 'CA$',  name: 'Dólar Canadiense',     shortName: 'Dólar CA',article: 'el', flag: '🇨🇦' },
  // Europa
  EUR: { symbol: '€',    name: 'Euro',              shortName: 'Euro',      article: 'el', flag: '🇪🇺' },
  GBP: { symbol: '£',    name: 'Libra Esterlina',   shortName: 'Libra',     article: 'la', flag: '🇬🇧' },
  CHF: { symbol: 'Fr.',  name: 'Franco Suizo',      shortName: 'Franco',    article: 'el', flag: '🇨🇭' },
  SEK: { symbol: 'kr',   name: 'Corona Sueca',      shortName: 'Corona SE', article: 'la', flag: '🇸🇪' },
  NOK: { symbol: 'kr',   name: 'Corona Noruega',    shortName: 'Corona NO', article: 'la', flag: '🇳🇴' },
  DKK: { symbol: 'kr',   name: 'Corona Danesa',     shortName: 'Corona DK', article: 'la', flag: '🇩🇰' },
  PLN: { symbol: 'zł',   name: 'Złoty Polaco',      shortName: 'Złoty',     article: 'el', flag: '🇵🇱' },
  // Asia / Pacífico
  JPY: { symbol: '¥',    name: 'Yen Japonés',       shortName: 'Yen',       article: 'el', flag: '🇯🇵' },
  CNY: { symbol: 'CN¥',  name: 'Yuan Chino',        shortName: 'Yuan',      article: 'el', flag: '🇨🇳' },
  KRW: { symbol: '₩',    name: 'Won Surcoreano',    shortName: 'Won',       article: 'el', flag: '🇰🇷' },
  INR: { symbol: '₹',    name: 'Rupia India',       shortName: 'Rupia',     article: 'la', flag: '🇮🇳' },
  AUD: { symbol: 'A$',   name: 'Dólar Australiano', shortName: 'Dólar AU',  article: 'el', flag: '🇦🇺' },
  NZD: { symbol: 'NZ$',  name: 'Dólar Neozelandés', shortName: 'Dólar NZ',  article: 'el', flag: '🇳🇿' },
  SGD: { symbol: 'S$',   name: 'Dólar Singapurense',shortName: 'Dólar SG',  article: 'el', flag: '🇸🇬' },
  HKD: { symbol: 'HK$',  name: 'Dólar de Hong Kong',shortName: 'Dólar HK',  article: 'el', flag: '🇭🇰' },
  // Medio Oriente / África
  AED: { symbol: 'د.إ',  name: 'Dírham Emiratí',    shortName: 'Dírham',    article: 'el', flag: '🇦🇪' },
  ILS: { symbol: '₪',    name: 'Séquel Israelí',    shortName: 'Séquel',    article: 'el', flag: '🇮🇱' },
  ZAR: { symbol: 'R',    name: 'Rand Sudafricano',  shortName: 'Rand',      article: 'el', flag: '🇿🇦' },
};

export const getCurrencyShortName = (code) => CURRENCIES[code]?.shortName ?? code;
export const getCurrencyArticle   = (code) => CURRENCIES[code]?.article   ?? 'el';
