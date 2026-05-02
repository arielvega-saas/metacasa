import Foundation

/// Base de conocimiento estructurada sobre la app que se inyecta como
/// contexto al modelo (FoundationModels o fallback estadístico).
///
/// Propósito: que el asistente pueda responder preguntas de **uso de la app**
/// ("¿cómo agrego un vencimiento?", "¿qué es un envelope?") con pasos
/// concretos, no solo preguntas de datos financieros.
///
/// Organización:
/// - `featuresOverview`: mapa de navegación condensado.
/// - `howTo`: procedimientos comunes ("cómo hacer X").
/// - `glossary`: términos de finanzas personales con definiciones cortas.
/// - `principles`: principios de asesoría financiera para dar consejos pro.
///
/// Las strings están en español (es-AR) porque el system prompt instruye al
/// modelo a responder en ese idioma. Si el usuario usa otro idioma, el modelo
/// traduce en vuelo.
///
/// Tamaño total: ~2.5k tokens estimado. FoundationModels acepta contexto
/// amplio por sesión, así que cabe holgado junto al contexto financiero.
enum AppKnowledgeBase {

    /// Mapa de navegación + lista de features. Densidad alta, pocos párrafos.
    static let featuresOverview: String = """
    === MAPA DE NAVEGACIÓN ===

    Tab bar inferior (4 tabs + FAB central):
    • Inicio (Home) — Dashboard con widgets reordenables.
    • Movimientos (Transactions) — Lista filtrable de todas las transacciones.
    • [+] FAB central sage — Agregar transacción rápida (gasto o ingreso).
    • Presupuesto (Budget) — Envelope budget del mes.
    • Más (More) — Todo lo demás (cuentas, metas, reportes, ajustes).

    === TAB INICIO (HOME) ===
    Widgets disponibles (el user puede ocultarlos desde "Personalizar dashboard" en el menú "⋯"):
    • HeroBalanceCard: balance del mes en serif grande + delta vs mes anterior.
    • StatsRow: ingresos + gastos con sparklines.
    • InsightCard: tip del asistente ("gastaste X% más que el mes anterior").
    • HealthScoreCard: Score 0-100 + streak 🔥 de días consecutivos.
    • SavingsInvestmentCard: muestra la estrategia (sin configurar → ir al Plan Editor).
    • ReadyToAssignCard: cuánto falta asignar en el envelope.
    • UpcomingBillsStrip: próximos vencimientos.
    • GoalsRingsRow: progreso anular de cada meta.
    • CategoryDonutCard: donut de gastos por categoría.
    • QuickShortcutsCarousel: atajos rápidos de transacciones frecuentes.
    • DebtsAndPlansTiles: deudas activas + plan de cuotas.
    • SetupChecklistCard: para usuarios nuevos, checklist de primeros pasos.
    Menú "⋯": compartir resumen (texto o PDF del mes), personalizar dashboard.

    === TAB MOVIMIENTOS ===
    Lista filtrable. Filtros: tipo, fecha (preset/mes específico/día/rango), monto rango, categoría, subcategoría, cuenta, texto libre, modo fecha (real/registro). Sort (fecha/monto, asc/desc). Modo lista o calendar (vista heatmap).
    Acciones: tap en fila → editar. Swipe → duplicar/eliminar. Toolbar → export CSV/PDF, import CSV/XLSX.

    === TAB PRESUPUESTO ===
    Envelope del mes actual. Cada categoría es un sobre. Tap → asignar monto. La app calcula "Por asignar" (ingresos - asignaciones). Semáforo visual: verde (hay margen), amarillo (80%), rojo (>100%).
    Integra Plan Editor (cascada Sankey) para asignaciones de alto nivel: ahorro/inversión/bills/installments/debts.

    === TAB MÁS ===
    Items:
    • Cuentas (checking/savings/cash/credit_card/investment/loan/other).
    • Detalle de tarjeta de crédito (vencimiento, mínimo, interés proyectado).
    • Metas de ahorro (con contribuciones + ETA calculada).
    • Vencimientos (bills con fecha + recordatorio).
    • Recurrentes (sueldo, alquiler, suscripciones, con frecuencia configurable).
    • Deudas (préstamos con plan de pago sugerido).
    • Planes de cuotas (installments).
    • Miembros del hogar (invitar por email, revoke token, roles).
    • Categorías personalizadas (emoji + subcategorías).
    • Ajustes del hogar (nombre, moneda base, eliminar).
    • Tasas de cambio FX (ajustar manualmente si hace falta).
    • Reportes: Health Score, Pareto 80/20, 6-month bars, category breakdown.
    • Comparar meses (dos meses lado a lado con chart).
    • Vista anual (12 meses en grid + chart de evolución).
    • Plan Editor (visual Sankey con sliders de estrategia).
    • Calculadora Plazo Fijo (interés + total + TEA + equivalente mensual).
    • Help Center (16 tópicos con búsqueda).
    • Asistente IA flotante (sparkles abajo-derecha, on-device con FoundationModels).
    • Preferencias: apariencia (light/dark/auto), idioma (es-AR/en/pt-BR), notificaciones, biometría.
    • Backup JSON full (export + restore con detección de duplicados).
    • Paywall Premium (RevenueCat).
    • Legal (privacy policy + terms of service).
    """

    /// Procedimientos comunes. Cada entrada: "pregunta del user" → "respuesta paso-a-paso".
    static let howTo: String = """
    === CÓMO HACER COSAS COMUNES ===

    Agregar una transacción:
    1) Tocá el botón [+] central del tab bar.
    2) Elegí tipo: Gasto o Ingreso.
    3) Ingresá monto con el teclado numérico.
    4) Deslizá horizontalmente para elegir categoría.
    5) Opcional: nota, subcategoría, fecha, cuenta, moneda distinta.
    6) "Guardar". Podés marcar el bookmark para guardar el movimiento como atajo.

    Crear el presupuesto del mes:
    1) Tab Presupuesto.
    2) Por cada categoría tocá y asignale un monto del mes.
    3) "Por asignar" arriba muestra cuánto falta (ingresos - asignaciones).
    4) A medida que cargás gastos, el sobre se va vaciando.
    5) Si sobrepasás, queda rojo. Podés re-asignar desde otra categoría con margen.

    Configurar estrategia de ahorro / inversión (Plan Editor):
    1) Home → widget "Ahorro e Inversión" → "Configurar".
    2) Se abre el Plan Editor con cascada visual de tus ingresos.
    3) Mové los sliders de % ahorro y % inversión. Toggleá si querés incluir bills/installments/debts en la cascada.
    4) El remainder badge muestra cuánto queda "libre" después de la estrategia. Si es rojo, tenés que bajar alguna %.
    5) "Guardar".

    Crear una meta con fecha:
    1) Más → Metas → "+".
    2) Nombre, monto objetivo, moneda, fecha target (opcional), ícono, prioridad.
    3) Contribuí desde el detalle de la meta tocando "+ Contribuir" con el monto.
    4) Si configurás targetDate, la app calcula el ETA: ¿vas en camino a llegar?

    Agregar un vencimiento (bill):
    1) Más → Vencimientos → "+".
    2) Título, monto, fecha de vencimiento, recurrencia opcional.
    3) Aparece en el Home 14 días antes.
    4) Si notificaciones están activas, te llega recordatorio N días antes a las 9am (configurable en Ajustes).
    5) Marcar como pagado cuando corresponda.

    Registrar un recurrente (sueldo, alquiler, etc.):
    1) Más → Recurrentes → "+".
    2) Tipo, monto, categoría, frecuencia (diario/semanal/mensual/anual), fecha de inicio.
    3) La app te recuerda el día del next_date a las 9am.

    Invitar a alguien al hogar:
    1) Más → Miembros del hogar → Invitar.
    2) Ingresá email.
    3) Se genera un token con validez 7 días. La persona acepta desde su app.
    4) Podés revoke el token si querés antes del plazo.

    Comparar dos meses:
    1) Más → Comparar meses.
    2) Elegí dos meses en los pickers.
    3) Ves totales lado a lado con delta + chart horizontal por categoría.
    4) En gastos: subir es rojo, bajar es verde. En ingresos/balance: al revés.

    Ver reportes avanzados:
    1) Más → Reportes.
    2) Health Score con breakdown (savings rate + ratio + consistencia).
    3) Evolución 6 meses (barras).
    4) Pareto 80/20 (top categorías que concentran el 80% del gasto).
    5) Desglose por categoría con % del total.

    Exportar datos para compartir:
    • Resumen mensual en texto: Home → menú "⋯" → Compartir resumen del mes.
    • PDF del mes: Home → menú "⋯" → Descargar resumen PDF → Share (AirDrop/Mail/WhatsApp/Files).
    • CSV/PDF con rango custom: Movimientos → Share → Exportar.
    • Backup JSON completo: Ajustes → Datos → Backup.

    Importar transacciones:
    1) Movimientos → toolbar → Importar CSV/XLSX.
    2) La app autodetecta el mapping de columnas. Podés ajustarlo.
    3) Preview muestra válidas/duplicadas/errores.
    4) Duplicados detectados se saltean por default — podés forzar su import con toggle individual.

    Activar notificaciones:
    1) Más → Ajustes → Notificaciones.
    2) Tocá "Permitir" para ver el prompt del sistema.
    3) Toggleá por tipo: bills, goals, recurrentes. Podés ajustar el timing.

    Cambiar la moneda del hogar (USD → ARS, etc.):
    1) Más → Ajustes → Hogar → "Editar hogar".
    2) Tocá el botón de moneda al lado del nombre — abre un picker con todas las monedas (ARS, USD, EUR, BRL, CLP, MXN, etc.).
    3) Elegí la moneda y "Guardar".
    4) Toda la app se actualiza al símbolo y formato de la nueva moneda. Las transacciones cargadas mantienen su monto numérico (no se reconvierten automáticamente).

    Editar el nombre del hogar:
    1) Más → Ajustes → Hogar → "Editar hogar".
    2) Cambiá el nombre y "Guardar".

    Cambiar idioma de la app:
    1) Más → Ajustes → Idioma.
    2) Elegí es (MetaCasa), en (MetaHome), pt-BR (MetaCasa).
    3) El nombre en el home screen del iPhone cambia automáticamente.

    Cambiar tema (light/dark):
    1) Más → Ajustes → Apariencia.
    2) System / Light / Dark.

    Restaurar compra Premium:
    1) Más → Premium.
    2) Al pie: "Restaurar compras".
    3) Apple valida contra tu Apple ID. Si hay compra activa, vuelve.

    Empezar de cero / restablecer toda la información:
    1) Más → Ajustes → Hogar → "Editar hogar".
    2) Al pie tocá "Eliminar hogar" (botón rojo, solo visible si sos owner del hogar).
    3) Confirmá "Eliminar todo" en el diálogo.
    4) Se borran transacciones, cuentas, presupuestos, metas, miembros y categorías. Acción irreversible.
    5) Después podés crear un hogar nuevo desde la pantalla de bienvenida con datos en blanco.
    """

    /// Glosario finanzas. Términos con definición corta. Para que la IA pueda
    /// responder "¿qué es Pareto?" con precisión.
    static let glossary: String = """
    === GLOSARIO DE FINANZAS PERSONALES ===

    Envelope budget: método donde asignás cada peso de tu ingreso a una categoría (sobre) antes de gastarlo. Si un sobre se vacía, no gastás más ahí — reasignás de otro sobre con margen.

    Zero-based budgeting (YNAB): variante del envelope donde Ingresos - Asignaciones = 0. Cada peso tiene un "trabajo".

    Regla 50/30/20 (Elizabeth Warren): 50% necesidades, 30% deseos, 20% ahorro/deuda. Marco inicial fácil.

    Savings rate (tasa de ahorro): (ingresos - gastos) / ingresos. Ideal ≥20% mensual. En iOS el Health Score premia ≥20%.

    Pareto 80/20: en finanzas personales, ~20% de las categorías suelen concentrar 80% de los gastos. Identificá esas primero.

    Fondo de emergencia: 3-6 meses de gastos esenciales en cuenta de alta liquidez (savings). Primer objetivo antes de invertir.

    Deuda snowball (Dave Ramsey): pagás primero las deudas más chicas independiente de la tasa. Ganás momentum psicológico.

    Deuda avalanche: pagás primero las de mayor tasa. Óptimo matemático. Ahorra más intereses.

    TEA (Tasa Efectiva Anual): rendimiento real de una inversión en un año considerando capitalización. La calculadora Plazo Fijo la calcula.

    TNA (Tasa Nominal Anual): tasa declarada anual sin capitalización. Siempre menor que la TEA.

    Plazo fijo: depósito a tasa fija por un plazo definido. Capital intacto + interés al vencimiento.

    Interés compuesto: ganás interés sobre el interés previamente acumulado. Clave del crecimiento a largo plazo.

    Diversificación: repartir inversiones entre distintos activos/regiones/monedas para reducir riesgo. No es garantía.

    Inflación: pérdida de poder adquisitivo de la moneda en el tiempo. En LatAm especialmente relevante.

    Multi-moneda: la app soporta 27 monedas. Las transacciones en moneda distinta se convierten a la moneda base del hogar vía tasas FX configurables.

    Categoría vs subcategoría: "Alimentación" es categoría, "Supermercado" / "Delivery" son subcategorías. Podés filtrar por ambas.

    Account types:
    • checking: cuenta corriente (operativa).
    • savings: cuenta de ahorro (baja liquidez, devenga interés).
    • cash: efectivo en mano.
    • credit_card: tarjeta de crédito (deuda con fecha de vencimiento + pago mínimo).
    • investment: inversión (acciones, bonos, fondo).
    • loan: préstamo a pagar.
    • other: cualquier otra cosa.

    Ownership:
    • personal: asignada a una persona (waterfall la considera para distribuir remanente).
    • shared: del hogar, gastos compartidos.
    • external: informativa, no afecta waterfall.

    Health Score (0-100):
    • 75-100: Excelente.
    • 55-74: Bueno.
    • 35-54: Regular.
    • 0-34: A mejorar.
    Ponderación: savings rate (50 pts) + ratio gastos/ingresos (30 pts) + consistencia (20 pts).

    Streak: días consecutivos con al menos una transacción cargada. Medido hacia atrás desde hoy. Mide disciplina de registro.

    ETA de meta: tiempo estimado para llegar al target basado en el promedio mensual de contribuciones.
    """

    /// Principios de asesoría profesional que la IA debe seguir al dar consejos.
    /// Esto eleva la calidad de las respuestas (de "cual es tu balance" a
    /// "acá va el análisis + la recomendación accionable").
    static let principles: String = """
    === PRINCIPIOS DE ASESORÍA FINANCIERA (SEGUIR EN LAS RESPUESTAS) ===

    1. Contexto primero, consejo después. Antes de sugerir algo, reformulá la situación del usuario con sus propios datos ("Este mes ingresaste $X y gastaste $Y, con un savings rate de Z%"). Así demostrás que entendiste.

    2. Accionable > genérico. En vez de "ahorrá más", decí "reducí el gasto en [categoría específica con top share] en un 15% y reasignás esos $W a tu meta [nombre]".

    3. Priorizar por impacto. Si el user tiene deudas de alta tasa + inversión sin emergency fund, recomendar el orden: (a) emergency fund 1 mes mínimo → (b) pagar deuda alta tasa → (c) fondo 3-6 meses → (d) invertir.

    4. No especular con mercados. No decir "comprá/vendé X activo". Sí podés hablar de proporciones de asset allocation genéricas.

    5. Señalar red flags. Si el savings rate es negativo, si una categoría tiene >50% del gasto, si hay deuda >40% del ingreso, avisalo claramente.

    6. Aprovechar features de la app. Cuando recomiendes algo, mencioná la feature específica: "podés crear una meta en 'Más → Metas' con target $X para dic/2026".

    7. Celebrar avances. Si el Health Score subió vs mes anterior o una meta avanzó, reconocé el progreso antes de pedir más esfuerzo.

    8. Claridad en proyecciones. Si estimás algo a futuro, explicitá la asunción: "asumiendo que mantenés el gasto actual de $X/mes...".

    9. Humildad. Ante datos ambiguos, preguntá. "¿Pensás que este gasto es recurrente o único?". Mejor eso que inventar.

    10. Empatía sin condescendencia. El user gestiona su plata — no es un nene. Tratalo como adulto, directo pero amable.
    """

    /// Wrapper compacto para inyectar todo el knowledge base en el system
    /// prompt del LLM. Se puede cortar en secciones si el prompt es muy largo.
    static var full: String {
        return """
        \(featuresOverview)

        \(howTo)

        \(glossary)

        \(principles)
        """
    }

    /// Versión ultra-corta (solo overview) para cuando el prompt ya es largo.
    static var compact: String {
        return """
        \(featuresOverview)

        \(principles)
        """
    }
}
