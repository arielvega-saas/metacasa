# Qué tiene que ser la web de Home Finance

> Research + recomendación, 2026-08-04. Pregunta del Owner: *"¿cuál sería la app web? Tipo la
> función de home banking o app de escritorio, para trabajar en la compu. No sé si tendría que
> tener el mismo formato de la app u otro estilo."*

## La respuesta corta

**Misma identidad, distinta densidad y distintos verbos.** Ni la app estirada, ni un producto
aparte.

La web no es "Home Finance en pantalla grande": es **el lugar donde se hace el trabajo pesado**.
El teléfono es donde cargás un gasto en la fila del súper; la compu es donde te sentás una vez por
mes a ordenar el desastre.

## Qué hace la competencia

**Monarch Money** es el caso más cercano a Home Finance y su reparto es explícito: la web es
superior para *"fine-tuning categories, rules, and reports"* y para patrimonio/inversiones, y la
app móvil sirve para el *"quick daily check-in"*. Su propia recomendación a usuarios es literal:
**móvil para la revisión diaria, web para el análisis mensual**.

El dato más importante: **los dashboards se personalizan por separado en web y en móvil.** No
espejan. Monarch asume que lo que querés ver sentado no es lo que querés ver parado.

**YNAB** define la web por lo que **sólo se puede hacer con teclado y mouse**:

- Atajos de teclado (colapsar/expandir todas las categorías, tipear `split` para dividir).
- **Edición masiva**: seleccionar N movimientos y categorizarlos de una, moverlos de cuenta de
  una, editar memos en lote.

Ninguna de esas dos cosas tiene sentido en un teléfono. Y ninguna es "la misma pantalla más
grande": son **verbos que el móvil no tiene**.

**Lo que NO hace ninguna:** cambiar de identidad visual entre plataformas. El color, la
tipografía, el ícono y el tono son los mismos. Lo que cambia es cuánta información entra por
pantalla y qué se puede hacer con ella.

## La recomendación para Home Finance

### 1. La identidad no se toca

Midnight Sage, el número héroe serif, el ícono. Ya está bien resuelto y es el activo de marca.
(De hecho el 2026-08-04 se corrigió justo lo contrario: la web tenía el **logo viejo** en el
encabezado, el favicon, el ícono del PWA y los mails. La coherencia va en ese sentido.)

### 2. La web gana en densidad, no en tamaño

El error típico es tomar las tarjetas del móvil y hacerlas más grandes. En una pantalla de 1440px
eso deja 60% de aire y obliga a scrollear igual. Lo correcto es **más filas visibles y más
columnas por fila**: una tabla de movimientos con fecha, categoría, subcategoría, cuenta, nota y
monto — todo de un vistazo, ordenable por cualquier columna.

### 3. Los verbos exclusivos de la web (ordenados por valor)

1. **Selección múltiple + acciones en lote.** Recategorizar 40 movimientos del súper de una vez.
   Hoy hay que entrar a cada uno. Es lo que más duele al importar un resumen.
2. **Importar/conciliar.** El preview del import ya pregunta cuenta y moneda; en la compu se puede
   mostrar la tabla entera con los errores resaltados, en vez de una lista de 10 con "+130 más".
3. **Reportes anchos.** Comparar meses lado a lado, la vista anual completa, el heatmap sin
   scroll. Ya existen las tres pantallas; en la compu entran de verdad.
4. **Teclado.** `N` para nuevo movimiento, `/` para buscar, flechas para navegar filas, `Enter`
   para editar. Baratísimo de implementar y es lo que separa "una web que anda" de "una
   herramienta".
5. **Exportar.** Excel/CSV con lo que estés viendo filtrado. En el teléfono un .xlsx no sirve
   para nada; en la compu es el puente al contador.

### 4. Lo que debe quedarse en el teléfono

Cámara para recibos, voz, widgets, Face ID, notificaciones, y el alta rápida de un toque. No hay
que portarlos a la web: se usan parado, no sentado.

### 5. Lo que tiene que ser idéntico, sin excepción

**Los números.** Este es el punto donde el proyecto ya se quemó tres veces: "listo para asignar"
llegó a tener cinco definiciones distintas, el patrimonio neto sumaba monedas sin convertir, y la
racha de días seguidos daba 1 en iOS y bien en la web. La regla que quedó:

> Si un número aparece en las dos plataformas, se calcula **una sola vez, en el servidor**, y las
> dos lo consumen.

Eso ya está hecho para totales (`transaction_totals`), presupuesto (`budget_period_summary`) y
sobres (`envelope_balance`). Cualquier número nuevo sigue el mismo camino.

## Qué NO hacer

- **No hacer una PWA "instalable" como sustituto de la app.** La app nativa tiene cámara, Face ID,
  widgets y notificaciones; la PWA es un atajo, no un reemplazo. Ya hay una PWA vieja en `app/src`
  que se está retirando — no revivirla.
- **No duplicar la navegación del móvil.** El tab bar de 5 ítems es una restricción del teléfono.
  En la compu va sidebar con todo visible, que es lo que ya tiene.
- **No inventar un tema claro distinto "porque es web".** El tema claro ya existe y comparte
  tokens; que siga compartiéndolos.

## Backlog concreto, ordenado por valor/esfuerzo

| # | Qué | Por qué primero |
|---|---|---|
| 1 | Selección múltiple + recategorizar en lote en `/transactions` | Es el dolor más grande y hoy no tiene ninguna salida |
| 2 | Atajos de teclado (`N`, `/`, flechas, `Enter`) | Horas de trabajo, cambia la sensación del producto |
| 3 | Tabla densa con columnas ordenables (reemplaza las tarjetas en ≥1024px) | Es *la* diferencia de la compu |
| 4 | Preview del import a pantalla completa con errores resaltados | El import es el momento de mayor fricción |
| 5 | Exportar lo filtrado a Excel/CSV | Puente al contador; ya existe el generador |
| 6 | Dashboard de la web configurable aparte del móvil | Lo que hace Monarch; requiere 1-5 antes |

## Fuentes

- [Monarch Money Review 2026 — Marriage Kids and Money](https://marriagekidsandmoney.com/monarch-money-review/)
- [Monarch Money Review — Rob Berger](https://robberger.com/monarch-money-review/)
- [Monarch Money Review 2026 — The College Investor](https://thecollegeinvestor.com/35342/monarch-review/)
- [6 YNAB Web App Features You Didn't Know Existed — YNAB](https://www.youneedabudget.com/6-ynab-web-app-features-you-didnt-know-existed/)
- [Keyboard Shortcuts in YNAB — soporte YNAB](https://support.ynab.com/en_us/keyboard-shortcuts-Skw9Xp9A9)
- [Best Budget Apps 2026 — NerdWallet](https://www.nerdwallet.com/finance/learn/best-budget-apps)
