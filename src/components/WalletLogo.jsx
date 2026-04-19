// MetaCasa — logo de wallet provider (imágenes bundleadas + SVG fallback para cuenta manual).
// Extraído de App.jsx en Fase 2.

import logoMP    from '../assets/logos/mercadopago.jpg';
import logoPP    from '../assets/logos/paypal.jpg';
import logoUala  from '../assets/logos/uala.jpg';
import logoBru   from '../assets/logos/brubank.jpg';
import logoNX    from '../assets/logos/naranjax.jpg';

const LOGO_MAP = {
  mercadopago: logoMP,
  paypal:      logoPP,
  uala:        logoUala,
  brubank:     logoBru,
  naranja_x:   logoNX,
};

export function WalletLogo({ provider, size = 40, className = '' }) {
  const r = Math.round(size * 0.22);

  if (LOGO_MAP[provider]) {
    return (
      <img
        src={LOGO_MAP[provider]}
        alt={provider}
        width={size}
        height={size}
        className={className}
        style={{ width: size, height: size, objectFit: 'cover', borderRadius: r, flexShrink: 0, display: 'block' }}
      />
    );
  }

  return (
    <svg width={size} height={size} viewBox="0 0 200 200" fill="none" xmlns="http://www.w3.org/2000/svg"
      className={className} style={{ borderRadius: r, flexShrink: 0 }}>
      <defs>
        <linearGradient id="manGrad2" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#10B981"/>
          <stop offset="100%" stopColor="#059669"/>
        </linearGradient>
      </defs>
      <rect width="200" height="200" rx="44" fill="url(#manGrad2)"/>
      <rect x="32" y="74" width="136" height="90" rx="16" fill="white" fillOpacity="0.95"/>
      <rect x="32" y="88" width="136" height="20" fill="#059669" fillOpacity="0.25"/>
      <rect x="122" y="99" width="46" height="40" rx="10" fill="#10B981"/>
      <circle cx="145" cy="119" r="9" fill="white" fillOpacity="0.9"/>
      <rect x="48" y="62" width="90" height="22" rx="11" fill="white" fillOpacity="0.65"/>
    </svg>
  );
}
