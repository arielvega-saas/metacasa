import SwiftUI

/// Placeholder. CRUD de metas se construye en la próxima sesión de Fase 3.
struct GoalsView: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ContentUnavailableView(
                "Metas de ahorro",
                systemImage: "target",
                description: Text("Muy pronto vas a poder crear metas compartidas con tu hogar (viaje, auto, vacaciones...) y ver el progreso de cada una.")
            )
        }
        .navigationTitle("Metas")
    }
}
