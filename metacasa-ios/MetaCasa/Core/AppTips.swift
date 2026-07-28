import Foundation
import TipKit

/// Tips de descubribilidad (TipKit, iOS 17+).
///
/// Hasta ahora las features menos obvias del Home —el ojito de privacidad y el
/// editor del dashboard— sólo estaban documentadas en el Centro de ayuda, que
/// casi nadie abre. TipKit las muestra en contexto, una sola vez, y recuerda
/// que ya fueron vistas (persistencia propia del framework).
///
/// Reglas de uso: un tip por pantalla como máximo y siempre anclado al control
/// del que habla. Nada de tips en pantallas de dinero en movimiento.
enum AppTips {
    /// Se llama una vez en el arranque de la app.
    static func configure() {
        try? Tips.configure([
            // Un tip por día como mucho: la app se usa a diario y no queremos
            // que se sienta un tutorial.
            .displayFrequency(.daily),
            .datastoreLocation(.applicationDefault)
        ])
    }

    #if DEBUG
    /// Resetea el estado de los tips para poder verlos de nuevo en QA.
    static func resetForTesting() {
        try? Tips.resetDatastore()
    }
    #endif
}

/// Tip del modo privacidad (el "ojito" del balance). Aparece después de que el
/// usuario abrió el Home unas cuantas veces, no en el primer arranque —
/// primero que entienda la app, después los extras.
struct PrivacyModeTip: Tip {
    /// Cantidad de veces que se mostró el Home.
    static let homeOpened = Event(id: "home_opened")

    var title: Text { Text("tip.privacy.title") }
    var message: Text? { Text("tip.privacy.message") }
    var image: Image? { Image(systemName: "eye.slash.fill") }

    var rules: [Rule] {
        #Rule(Self.homeOpened) { $0.donations.count >= 3 }
    }
}

/// Tip del editor del dashboard: que el usuario sepa que puede reordenar y
/// ocultar widgets (es de las features más fuertes y estaba escondida).
struct DashboardEditorTip: Tip {
    static let homeOpened = PrivacyModeTip.homeOpened

    var title: Text { Text("tip.dashboard.title") }
    var message: Text? { Text("tip.dashboard.message") }
    var image: Image? { Image(systemName: "slider.horizontal.3") }

    var rules: [Rule] {
        // Más tarde que el de privacidad para que no aparezcan juntos.
        #Rule(Self.homeOpened) { $0.donations.count >= 6 }
    }
}
