import type { TxType } from "@/lib/constants";

/**
 * Contratos entre la page (server) y los componentes client de Wallets.
 * Las fechas llegan YA formateadas desde el server: así el markup no depende de
 * la zona horaria del navegador y no hay mismatch de hidratación.
 */

/** Un movimiento de wallet todavía sin convertir en transacción. */
export interface PendingMovement {
  id: string;
  /** Fecha ya localizada (ej. "12 mar"). */
  dateLabel: string;
  description: string;
  /** Magnitud positiva; el signo lo da `type`. */
  amount: number;
  currency: string;
  type: TxType;
  /** Categoría sugerida por `suggest_category`, o null si no hay regla. */
  suggestedCategory: string | null;
  /** Confianza 0-100 de la sugerencia. */
  confidence: number | null;
}

/** Una wallet conectada con su bandeja de movimientos pendientes. */
export interface WalletBlockData {
  id: string;
  name: string;
  provider: string;
  currency: string;
  /**
   * Saldo informado por el provider, o `null` si no lo expone. La API pública de
   * Mercado Pago NO devuelve el saldo de la billetera personal: en ese caso no
   * mostramos nada, en vez de un "$0" que sería mentira.
   */
  balance: number | null;
  /** Último sync ya localizado, o null si nunca sincronizó. */
  lastSyncLabel: string | null;
  /** `true` si el token es de sandbox (metadata.live_mode === false). */
  sandbox: boolean;
  pending: PendingMovement[];
}
