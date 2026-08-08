import "server-only";

/**
 * La serie del CER — el índice con el que se reexpresa la plata.
 *
 * ─── POR QUÉ SE PIDE EN EL SERVIDOR ──────────────────────────────────────────
 * En iOS cada dispositivo pega al BCRA y cachea en disco: es un cliente por
 * persona. Acá una sola instancia sirve a todos los navegadores, así que pegar
 * desde el browser multiplicaría los pedidos por cada pestaña abierta y además
 * expondría la app a que el BCRA esté caído del lado del usuario.
 *
 * Con `revalidate` de una hora, Next sirve la serie desde su caché y sólo
 * refresca una vez por hora para toda la app. El CER se mueve ~0,06% por día:
 * una hora de desfasaje no cambia ninguna decisión.
 *
 * Ver `lib/reexpresion.ts` para el cálculo y por qué el CER y no el IPC.
 */

/** Día calendario. El índice es por DÍA: en UTC un gasto de las 22 h se corre. */
export function claveDeDia(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${dd}`;
}

export type SerieCER = Record<string, number>;

type RespuestaBCRA = {
  results?: Array<{ detalle?: Array<{ fecha: string; valor: number }> }>;
};

/**
 * Trae los últimos 24 meses de CER. Devuelve `{}` si el BCRA no responde —
 * quien llama decide qué hacer, y lo correcto es **ocultar la reexpresión**, no
 * mostrar números sin respaldo.
 */
export async function obtenerSerieCER(): Promise<SerieCER> {
  const hoy = new Date();
  const desde = new Date(hoy);
  desde.setMonth(desde.getMonth() - 24);

  const url =
    "https://api.bcra.gob.ar/estadisticas/v4.0/monetarias/30" +
    `?desde=${claveDeDia(desde)}&hasta=${claveDeDia(hoy)}&limit=1000`;

  try {
    const resp = await fetch(url, {
      headers: { Accept: "application/json" },
      // Una vez por hora para toda la app, no una vez por visita.
      next: { revalidate: 3600 },
      signal: AbortSignal.timeout(8000),
    });
    if (!resp.ok) return {};
    const json = (await resp.json()) as RespuestaBCRA;

    const serie: SerieCER = {};
    for (const variable of json.results ?? []) {
      for (const punto of variable.detalle ?? []) {
        if (typeof punto.valor === "number" && Number.isFinite(punto.valor)) {
          serie[punto.fecha] = punto.valor;
        }
      }
    }
    return serie;
  } catch {
    // Sin índice la app sigue funcionando: lo que se apaga es la reexpresión.
    // Una feature ausente se entiende; un número mal calculado, no.
    return {};
  }
}

/**
 * Convierte la serie en un lector de índice.
 *
 * Para un día sin dato —sábado, domingo, feriado— devuelve **el último
 * anterior**: el CER de un domingo es el del viernes, no un valor interpolado
 * que nadie publicó. Idéntico a `CERService.Snapshot.valor` en iOS.
 */
export function lectorDeIndice(serie: SerieCER) {
  const dias = Object.keys(serie).sort();
  return (fecha: Date): number | null => {
    const clave = claveDeDia(fecha);
    const exacto = serie[clave];
    if (exacto !== undefined) return exacto;
    // Binaria sobre los días ordenados: el último <= clave.
    let lo = 0;
    let hi = dias.length - 1;
    let encontrado = -1;
    while (lo <= hi) {
      const mid = (lo + hi) >> 1;
      if (dias[mid] <= clave) {
        encontrado = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return encontrado >= 0 ? serie[dias[encontrado]] : null;
  };
}
