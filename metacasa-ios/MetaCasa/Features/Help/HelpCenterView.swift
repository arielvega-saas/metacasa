import SwiftUI

/// Help Center embebido — port de los ~22 topics del `HELP_CONTENT` de la PWA
/// (App.jsx:375+). Lista buscable con tópicos por categoría. Cada detail es
/// markdown plano renderizado con `Text`.
struct HelpCenterView: View {
    @State private var query = ""

    var body: some View {
        List {
            ForEach(filteredSections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.topics) { topic in
                        NavigationLink {
                            HelpTopicView(topic: topic)
                        } label: {
                            HStack(spacing: 12) {
                                Text(topic.emoji).font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(topic.title).font(.body.weight(.semibold))
                                    Text(topic.summary)
                                        .font(.caption).foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Buscar ayuda…")
        .navigationTitle(Text("Ayuda"))
    }

    private var filteredSections: [HelpSection] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return HelpContent.sections
        }
        let q = query.lowercased()
        return HelpContent.sections.compactMap { section in
            let matched = section.topics.filter { topic in
                topic.title.lowercased().contains(q) ||
                topic.summary.lowercased().contains(q) ||
                topic.content.lowercased().contains(q)
            }
            guard !matched.isEmpty else { return nil }
            return HelpSection(title: section.title, topics: matched)
        }
    }
}

struct HelpTopicView: View {
    let topic: HelpTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text(topic.emoji).font(.system(size: 40))
                    Text(topic.title).font(.mcH1).foregroundStyle(Color.textPrimary)
                }
                Text(topic.summary)
                    .font(.mcBody)
                    .foregroundStyle(Color.textMuted)
                Divider()
                Text(topic.content)
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)
                    .textSelection(.enabled)
            }
            .padding(20)
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Content

struct HelpSection: Sendable {
    let title: String
    let topics: [HelpTopic]
}

struct HelpTopic: Identifiable, Sendable {
    let id: String
    let emoji: String
    let title: String
    let summary: String
    let content: String
}

enum HelpContent {
    static let sections: [HelpSection] = [
        HelpSection(
            title: "Empezar",
            topics: [
                HelpTopic(id: "first-tx", emoji: "💸", title: "Cómo agregar tu primera transacción",
                    summary: "Registrá un gasto o ingreso en segundos",
                    content: """
                    Para agregar una transacción:

                    1. Tocá el tab central "+" en el tab bar.
                    2. Elegí el tipo: Gasto o Ingreso.
                    3. Ingresá el monto en el teclado numérico.
                    4. Elegí la categoría deslizando horizontalmente entre opciones.
                    5. Opcional: agregá una nota, subcategoría, o cambiá la fecha.
                    6. Tocá "Guardar".

                    Tip: si cargás transacciones frecuentes, podés guardarlas como "atajo" tocando el bookmark después de cargar. Así la próxima vez tocás el chip y carga todo el form pre-llenado.
                    """),
                HelpTopic(id: "create-household", emoji: "🏠", title: "Crear o unirse a un hogar",
                    summary: "Compartí tus finanzas con tu familia o pareja",
                    content: """
                    Un hogar es el espacio donde vos (y opcionalmente otras personas) gestionan las finanzas juntos.

                    Crear: después de registrarte, ingresá nombre del hogar y moneda base. Listo.

                    Invitar a alguien más:
                    1. Andá a Más > Miembros del hogar.
                    2. Tocá "Invitar".
                    3. Ingresá el email de la persona.
                    4. Se le envía una invitación con token. Tiene 7 días para aceptar.

                    Quien acepta pasa a ver las mismas transacciones, cuentas, metas y presupuestos que vos.
                    """),
                HelpTopic(id: "currency", emoji: "💱", title: "Cambiar la moneda base del hogar",
                    summary: "ARS, USD, EUR, BRL, MXN y 22 más",
                    content: """
                    La moneda base es en la que se calcula el balance del hogar.

                    Cambiarla: Más > Ajustes del hogar > Moneda. Elegí entre 27 opciones regionales (Latam, USA, Europa, Asia).

                    Las transacciones en otra moneda se convierten automáticamente usando las tasas FX configuradas. Podés ver y ajustar las tasas en Más > Ajustes > Tasas de cambio.
                    """)
            ]
        ),
        HelpSection(
            title: "Cuentas y deudas",
            topics: [
                HelpTopic(id: "account-types", emoji: "🏦", title: "Tipos de cuenta y cuándo usar cada uno",
                    summary: "Checking, savings, cash, credit card, investment, loan",
                    content: """
                    La app soporta 7 tipos de cuenta. Elegí el que corresponda al momento de crearla (Más → Cuentas → +):

                    • checking (corriente): cuenta operativa del día a día. Ahí suele entrar el sueldo.
                    • savings (ahorro): plata parada que devenga interés. Baja liquidez.
                    • cash (efectivo): billetera, alcancía, lo que tenés físico.
                    • credit_card (tarjeta): deuda con fecha de vencimiento + pago mínimo + interés. La app calcula el interés proyectado.
                    • investment: inversiones (acciones, bonos, fondo, plazo fijo).
                    • loan: préstamo a pagar (cuota mensual).
                    • other: cualquier cosa que no encaja arriba (billetera virtual, paypal, etc.).

                    Ownership (pertenencia):
                    • personal: asignada a una persona del hogar. El Plan Editor la usa para distribuir el remanente.
                    • shared: del hogar, compartida. Se usa para gastos comunes.
                    • external: informativa. No afecta el Plan Editor.

                    Tip: después de crear la cuenta, cada transacción puede asignarse a esa cuenta. Si la dejás vacía, queda "del hogar" (shared).
                    """),
                HelpTopic(id: "credit-card-detail", emoji: "💳", title: "Usar el detalle de tarjeta de crédito",
                    summary: "Vencimiento, mínimo, interés proyectado",
                    content: """
                    Si tu cuenta es tipo "tarjeta de crédito", al tocarla en Más → Cuentas vas a un detalle especial con:

                    • Límite de crédito.
                    • Día de cierre (statement day): cuándo cierra el mes de la tarjeta.
                    • Día de vencimiento (due day): cuándo tenés que pagar.
                    • Tasa de interés mensual.
                    • % mínimo exigido.
                    • Último resumen cargado (opcional): monto + fecha.

                    Con esos datos la app proyecta:
                    • Intereses estimados si pagás solo el mínimo.
                    • Fecha del próximo vencimiento.

                    Tip: cargá el último resumen cada vez que llegue para que la proyección sea precisa.
                    """),
                HelpTopic(id: "debt-plan", emoji: "💰", title: "Gestionar deudas con plan de pago",
                    summary: "Snowball vs avalanche, payoff estimado",
                    content: """
                    Más → Deudas → +. Cargás cada deuda (nombre, monto original, saldo actual, tasa, cuota mensual).

                    La app te muestra:
                    • Lista de deudas activas con % pagado.
                    • Detalle: balance actual, cronograma de pago.

                    Estrategias clásicas:
                    • Snowball: pagar primero las deudas más chicas. Ganás momentum psicológico.
                    • Avalanche: pagar primero las de mayor tasa de interés. Óptimo matemático — ahorra más plata.

                    Tip: si tenés múltiples deudas, preguntale al asistente IA "¿qué deuda debería priorizar?" y te da una recomendación basada en tus datos.
                    """)
            ]
        ),
        HelpSection(
            title: "Presupuesto y metas",
            topics: [
                HelpTopic(id: "envelope-budget", emoji: "📦", title: "Qué es un presupuesto envelope",
                    summary: "Asigná cada peso de tu ingreso antes de gastarlo",
                    content: """
                    El método envelope (zero-based budgeting) consiste en "asignar" cada peso de tus ingresos a una categoría antes de gastar. No dejás plata "flotando".

                    En la app:
                    1. Tab Presupuesto.
                    2. Cada categoría es un sobre. Tocá una para asignarle un monto del mes.
                    3. A medida que cargás gastos, el sobre se vacía.
                    4. Semáforo visual: verde (tenés margen), amarillo (cerca del límite), rojo (sobrepasaste).

                    La app siempre muestra cuánto te queda sin asignar en el card "Por asignar".
                    """),
                HelpTopic(id: "goal", emoji: "🎯", title: "Crear una meta de ahorro",
                    summary: "Apuntá a un objetivo con progreso visual",
                    content: """
                    Una meta es un monto objetivo con o sin fecha. Podés ir contribuyendo de a poco.

                    Crear: Más > Metas > "+". Ingresá nombre, monto objetivo, fecha (opcional), ícono y prioridad.

                    Contribuir: dentro del detalle de la meta tocás "+ Contribuir". Ingresás monto. Se registra como contribución y actualiza el progreso.

                    Cuando llegás al 100%, la meta se marca como completada automáticamente 🎉.
                    """),
                HelpTopic(id: "bill", emoji: "📅", title: "Registrar un vencimiento",
                    summary: "Facturas con fecha de pago",
                    content: """
                    Un vencimiento es un pago que tenés que hacer en una fecha específica (luz, internet, alquiler, etc.).

                    Crear: Más > Vencimientos > "+". Cargá título, monto, fecha.

                    Aparecen en el dashboard 14 días antes de vencer. Si activás notificaciones, te llega un recordatorio el día anterior a las 9am.

                    Marcar como pagado cuando corresponda para que no se acumule en "próximos".
                    """),
                HelpTopic(id: "recurring", emoji: "🔁", title: "Gastos e ingresos recurrentes",
                    summary: "Sueldo, alquiler, suscripciones",
                    content: """
                    Un recurrente es un movimiento que se repite en una frecuencia fija: diario, semanal, mensual, anual.

                    Crear: Más > Recurrentes > "+". Elegís tipo, monto, categoría, frecuencia y fecha de inicio.

                    El backend se encarga de la lógica de ejecución. Si tenés notificaciones activas, te recordamos el día del next_date a las 9am.
                    """)
            ]
        ),
        HelpSection(
            title: "Análisis y reportes",
            topics: [
                HelpTopic(id: "dashboard", emoji: "📊", title: "Entender el dashboard",
                    summary: "Qué muestra cada widget",
                    content: """
                    El tab Inicio es tu dashboard. Widgets principales:

                    • Balance del mes: ingresos - gastos del mes actual. Verde = positivo, rojo = negativo.
                    • Vs mes anterior: comparación y atajos a "Comparar meses" y "Vista anual".
                    • Por asignar: cuánto te queda sin allocar en tu presupuesto envelope.
                    • Vencimientos próximos: facturas a pagar en los próximos 14 días.
                    • Tus metas: progreso visual de las metas activas.
                    • Top categorías del mes: dónde se va más tu plata.
                    • Atajos rápidos: transacciones frecuentes listas para 1-tap.
                    """),
                HelpTopic(id: "reports", emoji: "📈", title: "Ver reportes avanzados",
                    summary: "Health Score, Pareto, 6 meses",
                    content: """
                    Más > Reportes incluye:

                    • Health Score (0-100): puntaje de salud financiera basado en ratio ahorro, adherencia al presupuesto y consistencia.
                    • Evolución 6 meses: barras comparativas de ingresos vs gastos.
                    • Pareto 80/20: te muestra las pocas categorías que concentran el 80% de tus gastos.
                    • Desglose por categorías.

                    Más > Comparar meses: elegís 2 meses y la app muestra totales lado a lado + chart por categoría.

                    Más > Vista anual: los 12 meses del año en grid + chart de evolución + totales anuales.
                    """),
                HelpTopic(id: "compare", emoji: "⚖️", title: "Comparar dos meses",
                    summary: "Identificar cambios en tus gastos",
                    content: """
                    Abrí Más > Comparar meses. Elegí dos meses cualesquiera en los pickers.

                    La app muestra:
                    • Totales: ingresos, gastos y balance de cada mes con delta.
                    • Chart horizontal por categoría: barras paralelas para ver qué categorías subieron o bajaron.

                    El delta está codificado: en gastos, subir es rojo y bajar es verde. En ingresos y balance, al revés.
                    """)
            ]
        ),
        HelpSection(
            title: "Herramientas avanzadas",
            topics: [
                HelpTopic(id: "plan-editor", emoji: "🌊", title: "Plan Editor — Cascada visual de tu plata",
                    summary: "Sankey con sliders para distribuir ingresos",
                    content: """
                    El Plan Editor es una herramienta visual para ver cómo se distribuyen tus ingresos entre ahorro, inversión, bills, installments, deudas y gasto libre.

                    Acceder: Home → widget "Ahorro e Inversión" → "Configurar" (botón). O Más → Plan Editor.

                    Cómo funciona:
                    1. Arriba: card de ingresos mensuales con gradient verde.
                    2. Abajo: cascada vertical de bloques proporcionales. Cada bloque es una deducción (ahorro %, inversión %, bills, etc.).
                    3. Sliders interactivos: movés % de ahorro y % de inversión. La cascada se actualiza en vivo.
                    4. Toggles: podés incluir o excluir bills/installments/debts del cálculo.
                    5. Remainder badge: muestra cuánto queda de "gasto libre" después de todas las deducciones. Verde si positivo, rojo + ⚠️ si negativo.

                    Tip: si el remainder es rojo, bajá el % de ahorro o de inversión hasta que quede verde. Es la plata que te queda para comidas, transporte, etc.
                    """),
                HelpTopic(id: "fixed-term", emoji: "🧮", title: "Calculadora de Plazo Fijo",
                    summary: "Interés, total, TEA, equivalente mensual",
                    content: """
                    Más → Calculadora Plazo Fijo. Ingresás:
                    • Capital inicial.
                    • Tasa anual (TNA o TEA según elijas).
                    • Plazo en días o meses.

                    La app calcula y muestra:
                    • Interés generado.
                    • Total al vencimiento (capital + interés).
                    • TEA (Tasa Efectiva Anual) si ingresaste TNA, o viceversa.
                    • Equivalente mensual (interés prorrateado por mes).
                    • Equivalente diario.

                    Tip: compará TNA vs TEA entre bancos antes de decidir. La TEA te dice el rendimiento REAL anual considerando la capitalización.
                    """),
                HelpTopic(id: "app-intents", emoji: "🎙️", title: "Siri / Atajos de iOS",
                    summary: "Cargar gastos o ver balance sin abrir la app",
                    content: """
                    La app expone 2 App Intents a Siri, Spotlight y la app Atajos:

                    1. "Agregar gasto": Siri te pide monto + categoría y lo registra en tu hogar activo sin que abras la app.
                       • "Oye Siri, cargar gasto en MetaCasa" → voz te pide monto y categoría.

                    2. "Ver balance del mes": Siri te lee el balance, ingresos y gastos del mes actual.
                       • "Oye Siri, cuánto balance tengo en MetaCasa".

                    Configurar:
                    • Ajustes de iOS → Siri → Atajos → buscá MetaCasa.
                    • O abrí la app Atajos y creá automatizaciones (ej: al salir del super, cargar gasto automático).

                    Requiere estar logueado en la app — si la sesión expiró, Siri te pide abrir la app para re-loguearte.
                    """)
            ]
        ),
        HelpSection(
            title: "Asistente IA",
            topics: [
                HelpTopic(id: "assistant", emoji: "✨", title: "Cómo usar el asistente IA",
                    summary: "Tu coach financiero con 3 modos: chat, voz y vision",
                    content: """
                    Tocá el botón circular sage con sparkles abajo-derecha (visible desde cualquier pantalla una vez que iniciaste sesión). Se abre el chat.

                    El asistente tiene **3 modos** de interacción:

                    1) **Chat texto** — escribí cualquier pregunta o pedido.
                    2) **Voz** — tap del waveform arriba del chat → modo voz tipo ChatGPT con voz nativa argentina (Malena, rioplatense). Auto-VAD: te escucha hasta que dejás de hablar.
                    3) **Vision** — tocá el paperclip 📎 → "Sacar foto", "Foto" o "Escanear recibo". Te lee el monto, comercio, categoría y te propone crear la transacción.

                    Y combina DOS roles:

                    **A) Coach financiero** — analiza tus datos reales:
                    • "¿Cómo voy este mes?" → resumen ingresos/gastos/balance/savings rate.
                    • "¿Dónde gasto más?" → top categorías con % del total.
                    • "Comparame marzo con febrero" → side-by-side con deltas.
                    • "¿Cuánto me va a quedar a fin de mes?" → proyección.
                    • "¿Cómo voy con mis metas?" → progreso + ETA.
                    • "¿Qué deuda debería priorizar?" → snowball vs avalanche.
                    • "¿Mi Health Score es bueno?" → puntaje 0-100 desglosado.
                    • "Detectá anomalías" → cargos inusuales, duplicados.
                    • "Cómo me afecta la inflación" → análisis precio-cantidad (LATAM).

                    **B) Acciones directas** (22 acciones agentic):
                    • "Cargá un gasto de $X en Y" → te confirma + lo crea.
                    • "Transferí $X de Checking a Savings" → 2 transacciones linkeadas.
                    • "Marcá la factura de luz como pagada" → busca + confirma + marca.
                    • "Asigná $50.000 a Alimentación en el presupuesto" → upsert envelope.
                    • "Categorizá este gasto: Edenor" → "Servicios, confianza 94%".
                    • "Validá este CFDI" (México) o "verificá este CAE" (Argentina) → parseo formal + URL de verificación oficial SAT/ARCA.

                    **C) Guía experta de la app** — te explica cómo hacer cualquier cosa:
                    • "¿Cómo agrego una transacción?"
                    • "¿Cómo funciona el envelope budget?"
                    • "¿Cómo invito a alguien al hogar?"
                    • "¿Cómo hago backup?"

                    **Memoria entre sesiones**: el asistente recuerda lo que charlaron antes. Al cerrar el chat, genera un resumen y la próxima vez retoma el contexto. Podés decir "como te dije ayer, mi meta de viaje..." y entiende.

                    Privacidad: voz (Apple Speech) y OCR de recibos (Apple Vision) corren **siempre on-device** — no salen del iPhone. Las preguntas complejas se procesan con Claude (Anthropic) **solo con tu consentimiento explícito**. Podés activar "Solo on-device" en Ajustes → Privacidad del Asistente IA.
                    """),
                HelpTopic(id: "assistant-privacy", emoji: "🔒", title: "Privacidad y consentimiento del asistente",
                    summary: "Cómo controlar qué procesa el asistente y dónde",
                    content: """
                    El asistente tiene **tres capas de privacidad** bajo tu control directo:

                    **1) Consent explícito al primer uso**
                    La primera vez que abrís el chat, te aparece un sheet con 3 puntos:
                    • Qué se procesa en tu iPhone (voz, OCR, persistencia).
                    • Qué se envía a Claude (Anthropic) — y qué NO (emails, tarjetas, contraseñas).
                    • Política de Anthropic: no entrenan modelos con tus consultas.

                    Tenés 2 opciones: "Aceptar y continuar" (modo completo) o "Usar solo on-device" (más lento pero todo on-device).

                    **2) Toggles en Ajustes → Avanzado → Privacidad del Asistente IA**
                    • Toggle "Procesamiento en la nube" — alterna el consentimiento global. Si está OFF, el asistente solo usa modos on-device + fallback estadístico.
                    • Toggle "Forzar solo on-device" — incluso con consent ON, fuerza usar solo Apple Intelligence on-device. Más lento, garantizado privado.

                    **3) Revocar y borrar**
                    Botón rojo "Revocar consentimiento y borrar historial":
                    • Revoca el consent global.
                    • Borra todos los chat sessions persistidos (incluyendo los resúmenes para memoria).
                    • La próxima vez que abras el chat, te pedimos consent de nuevo desde cero.

                    **Detalles técnicos**: el historial de chat se guarda en `Documents/chat-sessions/{householdId}/` con `completeFileProtection` (encriptado a nivel sistema cuando el iPhone está bloqueado). Los resúmenes los genera Claude Haiku al cerrar cada sesión.

                    Más detalle público (link en Settings → footer): https://metacasa-app-cf592.web.app/assistant-ai.html
                    """),
                HelpTopic(id: "assistant-siri", emoji: "🎙️", title: "Atajos de Siri",
                    summary: "Hablale a Siri sin abrir la app",
                    content: """
                    MetaCasa expone **7 atajos** a Siri / Spotlight / Shortcuts. Decí "Hey Siri" + cualquiera:

                    • "Ver balance en MetaCasa" → balance del mes con voz.
                    • "Cargar gasto en MetaCasa" → pide monto + categoría, lo carga.
                    • "Registrar ingreso en MetaCasa" → mismo flow para ingreso.
                    • "Dónde gasto más en MetaCasa" → top 3 categorías del mes.
                    • "Mi salud financiera en MetaCasa" → Health Score 0-100.
                    • "Próximos vencimientos en MetaCasa" → bills pendientes 7 días.
                    • "Hablar con el asistente de MetaCasa" → abre el chat.

                    Los atajos también aparecen en:
                    • **Spotlight** (deslizá abajo en home screen → buscar "MetaCasa").
                    • **Lock Screen** — Siri sugiere atajos según patrones de uso.
                    • **App Shortcuts** (iOS) — podés crear shortcuts personalizados, agruparlos con otros atajos, automatizarlos.

                    Privacidad: las donaciones de App Intents viven solo en el dispositivo. No se sincronizan vía iCloud ni se envían a nuestros servidores.
                    """),
                HelpTopic(id: "assistant-limits", emoji: "⚠️", title: "Qué NO puede hacer el asistente",
                    summary: "Guardrails y alcance",
                    content: """
                    El asistente está diseñado con guardrails para no darte info errónea ni consejos peligrosos.

                    No hace:
                    • **Consejo de inversión específico** — no te dice "comprá acción X" o "vendé cripto Y". Sí habla de diversificación genérica, fondo de emergencia, proporciones de asset allocation.
                    • **Inventar números** — si no tiene un dato, te dice "no tengo eso cargado" en vez de imaginarlo.
                    • **Proyecciones infalibles** — cuando estima, aclara la asunción ("asumiendo que mantenés el gasto actual...").
                    • **Reemplazar un contador o asesor real** — para decisiones importantes (tomar deuda grande, comprar propiedad), avisa que es orientativo.
                    • **Salir del scope** — si preguntás de política, chismes, programación, salud, redirige amablemente.
                    • **Transferir plata real fuera de la app** — la acción "transferir entre cuentas" es contable (anotación entre tus cuentas internas), NO inicia una transferencia bancaria en el banco.
                    • **Ejecutar acciones sensibles sin confirmación** — siempre te pide "¿confirmás?" antes de crear/borrar/transferir.

                    Si notás una respuesta rara o inventada, reportalo a soporte — ayuda a mejorar el modelo.
                    """)
            ]
        ),
        HelpSection(
            title: "Datos y privacidad",
            topics: [
                HelpTopic(id: "backup", emoji: "💾", title: "Hacer backup y restaurar",
                    summary: "Export/import JSON completo",
                    content: """
                    Exportar: Ajustes > Datos > Backup > "Generar backup JSON". Se crea un archivo con TODOS los datos del hogar: transacciones, cuentas, categorías, presupuestos, metas, recurrentes. Lo podés compartir con el botón Share (AirDrop, Mail, WhatsApp, Files, iCloud).

                    Restaurar: Ajustes > Datos > Backup > "Elegir archivo JSON". Seleccioná el archivo de backup. La app te pide confirmación y después restaura los datos al hogar activo. **Los datos se AGREGAN, no reemplazan los existentes.**

                    Duplicados: el restore detecta y saltea transacciones idénticas (misma fecha + monto + categoría + nota).
                    """),
                HelpTopic(id: "export", emoji: "📄", title: "Exportar a CSV o PDF",
                    summary: "Archivos listos para Excel o impresión",
                    content: """
                    Desde el tab Transacciones, tocá el ícono de share arriba-derecha y elegí "Exportar".

                    Opciones:
                    • CSV (RFC 4180, UTF-8): abrible en Excel, Numbers, Google Sheets. 23 columnas con todos los campos.
                    • PDF (A4/Letter multi-página): listado formateado con resumen arriba.

                    Filtros de rango: mes actual, mes pasado, últimos 30/90 días, año actual, todo, o personalizado.

                    Después de generar el archivo, usá el botón Share para enviarlo a donde quieras.
                    """),
                HelpTopic(id: "privacy", emoji: "🔒", title: "Cómo se protegen tus datos",
                    summary: "Cifrado, biometría, RLS",
                    content: """
                    • Autenticación: email + contraseña con hash en Supabase.
                    • Sesión: token guardado en Keychain (cifrado por iOS con tu passcode / biometría).
                    • Datos en tránsito: HTTPS + TLS 1.3.
                    • Datos at-rest: Postgres cifrado en Supabase.
                    • Row Level Security (RLS): solo vos y miembros de tu hogar ven tus datos. Otros users NO pueden acceder aunque sepan tu ID.
                    • Biometría: si la activás, la app pide Face ID / Touch ID al abrirla.
                    • IA: on-device (Apple Intelligence). Tus datos NO salen del iPhone.
                    """),
                HelpTopic(id: "delete-account", emoji: "🗑️", title: "Eliminar tu cuenta",
                    summary: "Borrado completo dentro de 30 días",
                    content: """
                    Si querés eliminar tu cuenta y todos tus datos, enviá un email a soporte@homefinance.app desde la cuenta registrada con el pedido explícito.

                    Borramos todo dentro de los 30 días siguientes:
                    • Usuario en Supabase Auth
                    • Hogares donde sos único miembro
                    • Transacciones, cuentas, categorías, metas, presupuestos, recurrentes, vencimientos
                    • Suscripciones en RevenueCat (el entitlement se cancela)
                    • Logs y backups

                    Si compartís un hogar con otras personas, se te quita como miembro pero el hogar sigue existiendo para los demás.
                    """)
            ]
        ),
        HelpSection(
            title: "Suscripción",
            topics: [
                HelpTopic(id: "premium", emoji: "👑", title: "Qué incluye Premium",
                    summary: "Hogares ilimitados, IA, reportes avanzados",
                    content: """
                    El plan gratuito te deja usar las funciones core: transacciones, 1 hogar, presupuesto básico, hasta 3 metas.

                    Premium desbloquea:
                    • Hogares ilimitados
                    • Miembros ilimitados por hogar
                    • Categorías personalizadas sin límite
                    • Multi-moneda con tasas automáticas
                    • Reportes avanzados y exportación PDF
                    • Metas de ahorro ilimitadas
                    • Asistente IA on-device con contexto completo
                    • Widgets y Live Activities

                    Precios: USD 4,99/mes o USD 39,99/año (ahorro 30% vs mensual). Trial de 7 días gratis.

                    Gestionar suscripción: Ajustes > Apple ID > Suscripciones.
                    """),
                HelpTopic(id: "restore-purchase", emoji: "🔄", title: "Restaurar compras",
                    summary: "Si cambiaste de iPhone o reinstalaste",
                    content: """
                    Si ya compraste Premium y lo perdiste (cambio de iPhone, reinstalación, etc.):

                    1. Entrá a Más > Premium.
                    2. Tocá "Restaurar compras" al pie del paywall.
                    3. Apple valida contra tu Apple ID.
                    4. Si encuentra una compra activa, tu Premium vuelve automáticamente.

                    Importante: la restauración usa la Apple ID con la que compraste originalmente.
                    """)
            ]
        )
    ]
}
