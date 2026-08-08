/**
 * Llevar plata de una fecha a otra.
 *
 * ─── POR QUÉ EXISTE DOS VECES ────────────────────────────────────────────────
 * Esta es la contraparte de `Reexpresion.swift` en iOS. Normalmente duplicar una
 * regla es exactamente cómo una de las dos copias queda mal — pero acá son dos
 * plataformas y no hay forma de compartir el código. Lo que sí se comparte es la
 * **verificación**: los tests de los dos lados usan los MISMOS valores reales
 * del CER y esperan los MISMOS resultados, hasta el centavo. Si las dos
 * implementaciones se separan, un test se pone rojo.
 *
 * Un número distinto en el teléfono y en la computadora es peor que no tener la
 * feature: rompe la confianza en toda la app, no en una pantalla.
 *
 * Regla de oro: se guarda SIEMPRE el importe nominal y la fecha. La reexpresión
 * se calcula al vuelo. Guardar el valor ajustado lo pudre — mañana el índice
 * cambia y el número guardado miente para siempre.
 */

/** Devuelve el valor del índice para un día, o `null` si no hay dato. */
export type Indice = (fecha: Date) => number | null;

/** Redondeo a centavos, igual que en iOS. */
function aCentavos(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/**
 * Lleva `monto`, que es de `desde`, a la moneda de `hasta`.
 *
 * `null` cuando falta el índice de alguna de las dos fechas: **un número
 * inventado en una app de plata es peor que no mostrar nada.**
 */
export function llevar(
  monto: number,
  desde: Date,
  hasta: Date,
  indice: Indice,
): number | null {
  const origen = indice(desde);
  const destino = indice(hasta);
  if (origen === null || destino === null || origen <= 0) return null;
  return aCentavos((monto * destino) / origen);
}

/**
 * Cuánto compra hoy un peso de aquella fecha. `0.7492` = "un peso de agosto
 * pasado compra 75 centavos de hoy".
 *
 * Es la frase que más rápido le explica la inflación a alguien.
 */
export function poderDeCompra(
  fecha: Date,
  hoy: Date,
  indice: Indice,
): number | null {
  const origen = indice(fecha);
  const destino = indice(hoy);
  if (origen === null || destino === null || destino <= 0) return null;
  return Math.round((origen / destino) * 10000) / 10000;
}

/**
 * Variación real: cuánto cambió algo **descontando la inflación**.
 *
 * "Tu sueldo subió 25%, la inflación fue 33,5% → perdiste 6,35% real". Sin
 * esto, un aumento nominal parece una mejora cuando puede ser una pérdida.
 */
export function variacionReal(
  anterior: number,
  fechaAnterior: Date,
  actual: number,
  fechaActual: Date,
  indice: Indice,
): number | null {
  if (anterior <= 0) return null;
  const enMonedaDeHoy = llevar(anterior, fechaAnterior, fechaActual, indice);
  if (enMonedaDeHoy === null || enMonedaDeHoy <= 0) return null;
  return Math.round(((actual - enMonedaDeHoy) / enMonedaDeHoy) * 10000) / 10000;
}
