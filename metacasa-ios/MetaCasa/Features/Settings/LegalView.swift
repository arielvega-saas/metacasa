import SwiftUI

/// Privacy Policy + Terms of Service in-app. Versiones template que el usuario
/// debe revisar con asesor legal antes de producción. Accesibles desde
/// `SettingsView` y desde el flujo de signup como checkbox obligatorio.
///
/// **Importante**: el texto acá es un punto de partida razonable para una app
/// de finanzas personales con backend Supabase + RevenueCat + FoundationModels
/// on-device. NO es asesoramiento legal. Revisá con abogado antes del launch.
struct LegalView: View {
    let kind: Kind

    enum Kind: Sendable {
        case privacy
        case terms

        var title: String {
            switch self {
            case .privacy: "Política de privacidad"
            case .terms:   "Términos de servicio"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(content)
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)
                    .textSelection(.enabled)
            }
            .padding(20)
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var content: String {
        switch kind {
        case .privacy: Self.privacyText
        case .terms:   Self.termsText
        }
    }

    // MARK: - Privacy

    static var privacyText: String {
        let app = String(localized: "app.name")
        return """
    Última actualización: 2026-05-01

    \(app) (en adelante, "la app") es una herramienta de gestión de \
    finanzas personales del hogar. Este documento describe qué datos \
    recolectamos, cómo los usamos y los derechos que tenés sobre ellos.

    1. QUÉ DATOS RECOLECTAMOS

    • Datos de cuenta: email y contraseña (hasheada con bcrypt) para autenticarte.
    • Datos financieros cargados por vos: transacciones, cuentas, categorías, \
    presupuestos, metas, deudas, vencimientos y configuraciones.
    • Datos del hogar: nombre, miembros invitados (por email), moneda base, \
    zona horaria.
    • Datos de suscripción (si usás Premium): identificador anónimo de \
    RevenueCat + estado del entitlement (activo/expirado/trial).
    • Datos técnicos mínimos: identificador de dispositivo para sesión + \
    logs de error agregados (sin datos personales ni financieros específicos).
    • Voz (solo si usás el asistente por voz): el audio se transcribe \
    on-device con Apple Speech, NO se sube. El texto resultante se envía a \
    un proxy server que lo reenvía a Anthropic (LLM) y ElevenLabs (síntesis \
    de voz). Ver sección 6.

    NO recolectamos: tu ubicación, contactos, fotos, historial de navegación, \
    sensores del dispositivo, ni ningún otro dato que no sea esencial para la app.

    2. DÓNDE SE GUARDAN

    • Tus datos financieros se guardan en Supabase (Postgres cifrado at-rest \
    con AES-256, región us-east-1, EE.UU.). Las RLS policies garantizan que \
    solo vos y los miembros de tu hogar pueden leerlos.
    • Tokens OAuth de wallets (si conectás MercadoPago/Uala/etc.) se cifran \
    server-side con pgp_sym_encrypt antes de guardarse — nunca quedan en \
    texto plano.
    • Los tokens de sesión (JWT + refresh token) se guardan localmente en tu \
    iPhone vía Keychain, cifrado por iOS con tu passcode/biometría.

    3. QUIÉN VE TUS DATOS

    • Solamente vos, y los miembros de tu hogar que hayas invitado \
    explícitamente por email.
    • El desarrollador no tiene acceso al contenido de tus transacciones. \
    Puede ver métricas agregadas anonimizadas (ej. cantidad de usuarios \
    activos) y logs de error sin datos personales.
    • RevenueCat recibe solo un identificador hasheado de usuario y el \
    estado de tu suscripción. NUNCA recibe datos financieros tuyos.

    4. TUS DERECHOS (GDPR / CCPA / LFPDPPP)

    • Acceso: ver todos tus datos en la app, en cualquier momento.
    • Portabilidad / Export: Más → Ajustes → Datos → Backup. Genera un JSON \
    completo descargable.
    • Rectificación: editar transacciones, cuentas, categorías y otros datos \
    directamente en la app.
    • Eliminación: Más → Ajustes → Hogar → Eliminar hogar (irreversible, \
    borra todo en cascada). Para eliminar la cuenta completa de auth, enviá \
    un email a soporte; eliminamos todo dentro de 30 días.
    • Restringir procesamiento: podés desactivar el asistente IA en \
    Ajustes para que ningún dato se envíe a Anthropic/ElevenLabs.
    • Retirar consentimiento: podés cerrar tu cuenta en cualquier momento.
    • Presentar quejas: ante la autoridad de protección de datos de tu país.

    5. SEGURIDAD

    • Cifrado en tránsito: HTTPS + TLS 1.3 obligatorio para toda comunicación.
    • Cifrado at-rest: AES-256 en Postgres (Supabase) + Keychain en iOS.
    • Tokens OAuth de wallets cifrados con pgp_sym_encrypt + Vault.
    • Row Level Security (RLS) en backend — tus datos no son accesibles por \
    otros users aunque conozcan tu identificador.
    • Biometría opcional (Face ID / Touch ID) para abrir la app.
    • Auditorías periódicas de seguridad vía Supabase Advisors.

    6. TERCEROS

    Compartimos lo mínimo necesario con:
    • Supabase (Postgres + Edge Functions): backend principal. Política: \
    https://supabase.com/privacy
    • RevenueCat (suscripciones): solo identificador hasheado + estado. \
    Política: https://www.revenuecat.com/privacy
    • Anthropic (LLM Claude Haiku 4.5): solo si usás el asistente. Recibe \
    el contenido de tus mensajes + un resumen de tu situación financiera \
    para responderte. Anthropic no entrena modelos con tu data según su \
    política. Detalle: https://www.anthropic.com/privacy
    • ElevenLabs (síntesis de voz): solo si usás voice mode. Recibe el \
    texto de la respuesta del asistente para convertirlo a audio. Política: \
    https://elevenlabs.io/privacy
    • Apple (App Store, StoreKit, Speech, Push Notifications): según \
    políticas de Apple Inc.

    El audio del asistente NO se almacena en nuestros servidores. Las \
    respuestas del LLM tampoco se persisten — solo el texto del intercambio \
    queda guardado localmente en tu iPhone.

    7. MENORES

    La app no está dirigida a menores de 13 años (COPPA) ni a menores de \
    16 años en jurisdicciones GDPR. No recolectamos conscientemente datos \
    de menores. Si nos enterás que un menor cargó datos, los borramos.

    8. RETENCIÓN DE DATOS

    Mantenemos tus datos mientras tu cuenta esté activa. Después de eliminar \
    la cuenta: backups de seguridad pueden retener datos hasta 90 días por \
    razones técnicas, después se eliminan permanentemente.

    9. TRANSFERENCIAS INTERNACIONALES

    Tus datos se procesan en EE.UU. (Supabase region us-east-1). Si vivís \
    en Unión Europea / Reino Unido, esto constituye una transferencia \
    internacional. Confiamos en las cláusulas contractuales tipo (Standard \
    Contractual Clauses) de Supabase para legitimarla.

    10. CAMBIOS

    Podemos actualizar esta política. Los cambios se notificarán dentro de \
    la app y a la versión publicada en la URL pública. El uso continuado \
    implica aceptación.

    11. CONTACTO

    Dudas o pedidos sobre privacidad: privacy@metacasa.app

    ---
    ⚠️ ESTE TEXTO ES UN PUNTO DE PARTIDA RAZONABLE PERO NO REEMPLAZA \
    REVISIÓN LEGAL. Antes de lanzar a producción consultá con asesor legal \
    en tu jurisdicción para adaptarlo a GDPR (UE/UK), CCPA/CPRA (California), \
    LFPDPPP (México), LGPD (Brasil), Ley 25.326 (Argentina), u otros marcos \
    aplicables a tu mercado objetivo.
    """
    }

    // MARK: - Terms

    static var termsText: String {
        let app = String(localized: "app.name")
        return """
    Última actualización: 2026-05-01

    Bienvenido/a a \(app). Al usar la app, aceptás los siguientes \
    términos. Leelos con atención.

    1. SERVICIO

    \(app) es una app de gestión de finanzas personales. Te ayuda a \
    registrar transacciones, presupuestar, seguir metas de ahorro y analizar \
    tus gastos. NO es un servicio bancario, de inversión ni de asesoramiento \
    financiero profesional.

    2. USO ACEPTABLE

    Te comprometés a:
    • Usar la app solo con fines legales y personales (o familiares).
    • No intentar acceder a datos de otros usuarios.
    • No revender el servicio ni integrarlo con terceros sin autorización.
    • Mantener tu contraseña segura y no compartirla.

    3. SUSCRIPCIONES (si aplica)

    • \(app) ofrece un plan gratuito con funcionalidades limitadas y un \
    plan Premium con todas las funciones.
    • Los precios se muestran en la app en tu moneda local (vía App Store / \
    RevenueCat).
    • Las suscripciones se renuevan automáticamente al final de cada período. \
    Podés cancelar en cualquier momento desde Ajustes > Apple ID > Suscripciones.
    • Se puede ofrecer un período de prueba gratis; si no cancelás antes del \
    fin, se convierte en suscripción paga automáticamente.
    • Los reembolsos se gestionan a través de Apple / Google según sus políticas.

    4. DISCLAIMERS

    • Los análisis, proyecciones y sugerencias del asistente IA son \
    informativos. NO son consejo financiero profesional.
    • No nos responsabilizamos por decisiones financieras que tomes en base a \
    la app. Siempre consultá con profesionales para decisiones importantes.
    • El servicio se provee "AS IS" — hacemos nuestro mejor esfuerzo para que \
    funcione pero no garantizamos disponibilidad ininterrumpida.

    5. LIMITACIÓN DE RESPONSABILIDAD

    En la medida permitida por la ley, \(app) no es responsable por \
    daños indirectos, consecuentes o incidentales derivados del uso de la \
    app. La responsabilidad máxima se limita a lo que hayas pagado por la \
    suscripción en los últimos 12 meses.

    6. PROPIEDAD INTELECTUAL

    El código, diseño e identidad visual de \(app) son propiedad del \
    desarrollador. El contenido que cargás (transacciones, notas, etc.) es \
    tuyo. Nos concedés licencia limitada para almacenarlo y procesarlo con \
    el fin de proveer el servicio.

    7. CAMBIOS EN TÉRMINOS

    Podemos actualizar estos términos. Los cambios se notifican dentro de la \
    app. Si no estás de acuerdo, podés dejar de usar la app y cerrar tu cuenta.

    8. LEY APLICABLE

    Estos términos se rigen por las leyes [de tu jurisdicción — completar \
    antes de lanzar]. Cualquier disputa se resolverá en los tribunales de \
    [jurisdicción — completar].

    9. CONTACTO

    Dudas sobre los términos: soporte@homefinance.app

    ---
    ⚠️ Este texto es un template inicial. Antes de lanzar, revisalo con \
    asesor legal en tu país (especialmente secciones de ley aplicable, \
    limitación de responsabilidad, y términos de suscripción).
    """
    }
}
