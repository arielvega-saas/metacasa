// MetaCasa — Toast provider + useToast hook.
// Extraído de App.jsx en Fase 2.

import React, { createContext, useCallback, useContext, useState } from 'react';
import { CheckCircle2, AlertCircle, Info } from 'lucide-react';

const ToastContext = createContext(null);

export function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([]);

  const addToast = useCallback((msg, type = 'success') => {
    const id = Date.now();
    setToasts(t => [...t, { id, msg, type }]);
    setTimeout(() => setToasts(t => t.filter(x => x.id !== id)), 3200);
  }, []);

  const iconMap = {
    success: <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />,
    error:   <AlertCircle className="w-5 h-5 text-rose-400 flex-shrink-0" />,
    info:    <Info className="w-5 h-5 text-violet-400 flex-shrink-0" />,
  };

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

export const useToast = () => useContext(ToastContext);
