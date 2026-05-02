import SwiftUI

/// Sheet para que el usuario elija qué widgets ver en el Dashboard.
/// Toggles on/off por widget. Persist en `DashboardPreferences`.
/// El reorder (drag-drop) viene post-launch.
struct DashboardEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DashboardPreferences.self) private var prefs

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(prefs.order, id: \.self) { widget in
                        HStack(spacing: 12) {
                            Image(systemName: widget.icon)
                                .font(.body)
                                .foregroundStyle(Color.brandPrimary)
                                .frame(width: 32, height: 32)
                                .background(Color.brandPrimary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(widget.labelKey).font(.body.weight(.semibold))
                                Text(widget.descriptionKey).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { prefs.isVisible(widget) },
                                set: { _ in
                                    Haptics.play(.selection)
                                    prefs.toggle(widget)
                                }
                            ))
                            .labelsHidden()
                            .tint(.brandPrimary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove { source, dest in
                        Haptics.play(.selection)
                        prefs.move(from: source, to: dest)
                    }
                } header: {
                    Text("dashboard.editor.widgets")
                } footer: {
                    Text("dashboard.editor.reorderHint")
                }

                Section {
                    Button(role: .destructive) {
                        Haptics.play(.warning)
                        prefs.resetToDefaults()
                    } label: {
                        Label("dashboard.editor.reset", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .environment(\.editMode, .constant(.active))   // Habilita drag handles siempre
            .navigationTitle(Text("dashboard.editor.title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.close") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
