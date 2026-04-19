// MetaCasa — íconos SVG de AI providers + registry AI_PROVIDERS.
// Extraído de App.jsx en Fase 2.

export const AiIconOpenAI = ({ size = 28 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path d="M22.282 9.821a5.985 5.985 0 0 0-.516-4.91 6.046 6.046 0 0 0-6.51-2.9A6.065 6.065 0 0 0 4.981 4.18a5.998 5.998 0 0 0-3.998 2.9 6.042 6.042 0 0 0 .743 7.097 5.98 5.98 0 0 0 .51 4.911 6.051 6.051 0 0 0 6.515 2.9A5.985 5.985 0 0 0 13.26 24a6.056 6.056 0 0 0 5.772-4.206 5.99 5.99 0 0 0 3.997-2.9 6.056 6.056 0 0 0-.747-7.073zM13.26 22.43a4.476 4.476 0 0 1-2.876-1.04l.141-.081 4.779-2.758a.795.795 0 0 0 .392-.681v-6.737l2.02 1.168a.071.071 0 0 1 .038.052v5.583a4.504 4.504 0 0 1-4.494 4.494zM3.6 18.304a4.47 4.47 0 0 1-.535-3.014l.142.085 4.783 2.759a.771.771 0 0 0 .78 0l5.843-3.369v2.332a.08.08 0 0 1-.033.062L9.74 19.95a4.5 4.5 0 0 1-6.14-1.646zM2.34 7.896a4.485 4.485 0 0 1 2.366-1.973V11.6a.766.766 0 0 0 .388.676l5.815 3.355-2.02 1.168a.076.076 0 0 1-.071 0l-4.83-2.786A4.504 4.504 0 0 1 2.34 7.872zm16.597 3.855l-5.833-3.387L15.119 7.2a.076.076 0 0 1 .071 0l4.83 2.791a4.494 4.494 0 0 1-.676 8.105v-5.678a.79.79 0 0 0-.407-.667zm2.01-3.023l-.141-.085-4.774-2.782a.776.776 0 0 0-.785 0L9.409 9.23V6.897a.066.066 0 0 1 .028-.061l4.83-2.787a4.5 4.5 0 0 1 6.68 4.66zm-12.64 4.135l-2.02-1.164a.08.08 0 0 1-.038-.057V6.075a4.5 4.5 0 0 1 7.375-3.453l-.142.08L8.704 5.46a.795.795 0 0 0-.393.681zm1.097-2.365l2.602-1.5 2.607 1.5v2.999l-2.597 1.5-2.607-1.5z" fill="currentColor"/>
  </svg>
);

export const AiIconGemini = ({ size = 28 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path d="M12 24C12 24 12 12 0 12C12 12 12 0 12 0C12 0 12 12 24 12C12 12 12 24 12 24Z" fill="url(#gemini_grad)"/>
    <defs><linearGradient id="gemini_grad" x1="0" y1="0" x2="24" y2="24" gradientUnits="userSpaceOnUse">
      <stop stopColor="#4285F4"/><stop offset="0.5" stopColor="#9B72CB"/><stop offset="1" stopColor="#D96570"/>
    </linearGradient></defs>
  </svg>
);

export const AiIconClaude = ({ size = 28 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path d="M16.009 8.754L11.998 21 7.972 8.754h8.037z" fill="#D97757"/>
    <path d="M7.972 8.754L12 3l4.009 5.754H7.972z" fill="#D97757"/>
    <path d="M3 15.163L7.972 8.754h0L12 21l-9-5.837z" fill="#D97757"/>
    <path d="M3 15.163L7.241 3l.731 5.754L3 15.163z" fill="#D97757"/>
    <path d="M21 15.163L16.009 8.754h0L12 21l9-5.837z" fill="#D97757"/>
    <path d="M21 15.163L16.759 3l-.75 5.754L21 15.163z" fill="#D97757"/>
  </svg>
);

export const AiIconCustom = ({ size = 28 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <path d="M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z"/>
    <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>
  </svg>
);

export const AI_PROVIDERS = {
  openai: {
    id: 'openai', name: 'OpenAI', Icon: AiIconOpenAI,
    iconColor: 'text-white',
    defaultModel: 'gpt-4o-mini', placeholder: 'sk-...',
    helpUrl: 'https://platform.openai.com/api-keys',
    helpText: { es: 'Obtené tu API key en platform.openai.com', en: 'Get your API key at platform.openai.com' },
  },
  gemini: {
    id: 'gemini', name: 'Google Gemini', Icon: AiIconGemini,
    iconColor: '',
    defaultModel: 'gemini-2.0-flash', placeholder: 'AIza...',
    helpUrl: 'https://aistudio.google.com/apikey',
    helpText: { es: 'Obtené tu API key en Google AI Studio', en: 'Get your API key at Google AI Studio' },
  },
  anthropic: {
    id: 'anthropic', name: 'Anthropic Claude', Icon: AiIconClaude,
    iconColor: '',
    defaultModel: 'claude-sonnet-4-20250514', placeholder: 'sk-ant-...',
    helpUrl: 'https://console.anthropic.com/settings/keys',
    helpText: { es: 'Obtené tu API key en console.anthropic.com', en: 'Get your API key at console.anthropic.com' },
  },
  custom: {
    id: 'custom', name: 'Custom', Icon: AiIconCustom,
    iconColor: 'text-zinc-400',
    defaultModel: '', placeholder: 'your-api-key',
    helpUrl: '',
    helpText: { es: 'Endpoint compatible con la API de OpenAI', en: 'OpenAI-compatible API endpoint' },
  },
};
