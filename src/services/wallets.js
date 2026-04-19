// MetaCasa — configuración de wallets, provider registry y adapter.
// Extraído de App.jsx en Fase 2. El proxy usa wallet_id (server descifra tokens).

import { supabase } from '../supabaseClient';

export const WALLET_PROXY = 'https://rgslvrxdppphzvqgcwbx.functions.supabase.co/wallet-proxy';
// Nota: el anon key también está disponible en import.meta.env.VITE_SUPABASE_ANON_KEY.
// Este duplicado se mantiene por compatibilidad hasta eliminar el hardcoding en Fase 3.
export const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJnc2x2cnhkcHBwaHp2cWdjd2J4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3NjU0NTIsImV4cCI6MjA4NzM0MTQ1Mn0.P8GFzmmj4sAIpWjyjJFSWhhlM5LqP2BBFflOGfUmfhk';

// Mercado Pago OAuth: client_id público, client_secret vive en la Edge Function
export const MP_OAUTH_CLIENT_ID = '2693470312497962';
export const MP_OAUTH_REDIRECT  = typeof window !== 'undefined' ? window.location.origin : 'https://metacasa-app-cf592.web.app';

export const WALLET_PROVIDERS = {
  mercadopago: {
    id: 'mercadopago',
    name: 'Mercado Pago',
    emoji: '🔵',
    bgClass: 'bg-sky-500/10',
    borderClass: 'border-sky-500/30',
    textClass: 'text-sky-400',
    fields: [{ key: 'access_token', label: 'Access Token', type: 'password', placeholder: 'APP_USR-...' }],
    helpUrl: 'https://www.mercadopago.com.ar/developers/panel/app',
    helpText: 'Obtené tu Access Token en el panel de desarrolladores de Mercado Pago → Credenciales de producción',
  },
  paypal: {
    id: 'paypal',
    name: 'PayPal',
    emoji: '💙',
    bgClass: 'bg-blue-500/10',
    borderClass: 'border-blue-500/30',
    textClass: 'text-blue-400',
    fields: [
      { key: 'client_id', label: 'Client ID', type: 'text', placeholder: 'AX...' },
      { key: 'client_secret', label: 'Client Secret', type: 'password', placeholder: 'EC...' },
    ],
    helpUrl: 'https://developer.paypal.com/dashboard/',
    helpText: 'Obtené tus credenciales en el dashboard de PayPal Developers',
  },
  uala: {
    id: 'uala', name: 'Ualá', emoji: '💜',
    bgClass: 'bg-purple-500/10', borderClass: 'border-purple-500/30', textClass: 'text-purple-400',
    fields: [], comingSoon: true,
  },
  brubank: {
    id: 'brubank', name: 'Brubank', emoji: '🟠',
    bgClass: 'bg-orange-500/10', borderClass: 'border-orange-500/30', textClass: 'text-orange-400',
    fields: [], comingSoon: true,
  },
  naranja_x: {
    id: 'naranja_x', name: 'Naranja X', emoji: '🟡',
    bgClass: 'bg-amber-500/10', borderClass: 'border-amber-500/30', textClass: 'text-amber-400',
    fields: [], comingSoon: true,
  },
  manual: {
    id: 'manual',
    name: 'Cuenta manual',
    emoji: '💵',
    bgClass: 'bg-emerald-500/10',
    borderClass: 'border-emerald-500/30',
    textClass: 'text-emerald-400',
    fields: [
      { key: 'name_override', label: 'Nombre de la cuenta', type: 'text', placeholder: 'Ej: Efectivo, Ahorros...' },
    ],
    helpText: 'Registrá el saldo de cualquier cuenta o efectivo de forma manual',
  },
};

// El adapter retorna { testConnection, getBalance, getTransactions } según el provider.
// Para MP, el proxy recibe wallet_id y el server descifra el access_token (Fase 0).
export const createWalletAdapter = (provider, config) => {
  if (provider === 'mercadopago') {
    const walletId = config.wallet_id;
    const proxyFetch = async (path) => {
      const { data: { session } } = await supabase.auth.getSession();
      return fetch(`${WALLET_PROXY}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json',
          'Authorization': `Bearer ${session?.access_token || SUPABASE_ANON_KEY}`,
          'apikey': SUPABASE_ANON_KEY },
        body: JSON.stringify({ provider: 'mercadopago', path, wallet_id: walletId }),
      });
    };
    return {
      async testConnection() {
        try { const r = await proxyFetch('/users/me'); return r.ok; } catch { return false; }
      },
      async getBalance() {
        // La API pública de MP no expone el saldo de billetera personal.
        return null;
      },
      async getTransactions(limit = 50) {
        let mpUserId = null;
        try {
          const meR = await proxyFetch('/users/me');
          if (meR.ok) { const me = await meR.json(); mpUserId = String(me.id); }
        } catch {}

        const r = await proxyFetch(`/v1/payments/search?sort=date_created&criteria=desc&limit=${limit}`);
        if (!r.ok) return [];
        const d = await r.json();

        const userCache = {};
        const getMPUserName = async (uid) => {
          if (!uid || String(uid) === mpUserId) return null;
          if (userCache[uid]) return userCache[uid];
          try {
            const ur = await proxyFetch(`/users/${uid}`);
            if (ur.ok) {
              const u = await ur.json();
              const name = [u.first_name, u.last_name].filter(Boolean).join(' ') || u.nickname || null;
              userCache[uid] = name;
              return name;
            }
          } catch {}
          return null;
        };

        const results = await Promise.all((d.results ?? []).map(async t => {
          const collectorId = String(t.collector?.id || t.collector_id || '');
          const payerId     = String(t.payer?.id || '');
          const isIngreso   = mpUserId && collectorId === mpUserId;

          let desc = t.description || t.statement_descriptor || '';

          if ((!desc || desc === 'Varios') && isIngreso && payerId && payerId !== mpUserId) {
            const name = await getMPUserName(payerId);
            if (name) desc = `Transferencia de ${name}`;
            else desc = 'Transferencia recibida';
          } else if ((!desc || desc === 'Varios') && !isIngreso && collectorId && collectorId !== mpUserId) {
            const name = await getMPUserName(collectorId);
            if (name) desc = `Transferencia a ${name}`;
            else desc = 'Transferencia enviada';
          }

          if (!desc || desc === 'null') {
            const opNames = {
              account_fund: isIngreso ? 'Depósito bancario' : 'Fondeo de cuenta',
              investment:   isIngreso ? 'Rendimiento MP'    : 'Inversión MP',
              money_transfer: isIngreso ? 'Transferencia recibida' : 'Transferencia enviada',
            };
            desc = opNames[t.operation_type] || t.operation_type || 'Movimiento MP';
          }

          return {
            external_id: String(t.id),
            date:        t.date_created,
            amount:      Math.abs(t.transaction_amount ?? 0),
            type:        isIngreso ? 'INGRESO' : 'GASTO',
            description: desc,
            currency:    t.currency_id ?? 'ARS',
            status:      t.status ?? 'approved',
            raw:         t,
          };
        }));

        return results;
      },
    };
  }
  if (provider === 'manual') {
    return {
      async testConnection() { return true; },
      async getBalance() { return { available: 0, total: 0, currency: 'ARS' }; },
      async getTransactions() { return []; },
    };
  }
  return null;
};
