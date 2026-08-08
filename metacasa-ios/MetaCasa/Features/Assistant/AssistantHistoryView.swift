import SwiftUI

/// Historial de conversaciones con el asistente.
///
/// Las charlas ya se archivaban y se resumían —el resumen alimenta la memoria
/// del asistente entre sesiones—, pero no había forma de verlas. Desde que el
/// chat arranca limpio pasada la media hora, sin esta pantalla una conversación
/// vieja era irrecuperable: existía en disco y el usuario no podía llegar a
/// ella. Es el mismo par que tienen los asistentes de las fintech: el lápiz
/// empieza una nueva, el reloj abre las anteriores.
@MainActor
struct AssistantHistoryView: View {
    let householdId: UUID
    let userId: UUID
    /// Se llama al retomar una conversación: el chat se recarga con ella.
    let onRetomar: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var conversaciones: [ChatPersistenceService.ConversacionArchivada] = []
    @State private var cargando = true
    @State private var abierta: ChatSessionRecord?

    var body: some View {
        NavigationStack {
            Group {
                if cargando {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if conversaciones.isEmpty {
                    vacio
                } else {
                    lista
                }
            }
            .background(Color.appBackground)
            .navigationTitle(Text("assistant.history.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                }
            }
            .task {
                conversaciones = await ChatPersistenceService.shared
                    .conversacionesArchivadas(householdId: householdId)
                cargando = false
            }
            .sheet(item: $abierta) { sesion in
                ConversacionArchivadaView(sesion: sesion) {
                    Task { await retomar(sesion.id) }
                }
            }
        }
    }

    private var vacio: some View {
        ContentUnavailableView {
            Label {
                Text("assistant.history.empty.title")
            } icon: {
                Image(systemName: "clock.arrow.circlepath")
            }
        } description: {
            Text("assistant.history.empty.body")
        }
    }

    private var lista: some View {
        List {
            ForEach(conversaciones) { c in
                Button {
                    Haptics.play(.selection)
                    Task {
                        abierta = await ChatPersistenceService.shared
                            .cargarArchivada(householdId: householdId, sessionId: c.id)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(c.titulo)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(2)
                        if let r = c.resumen {
                            Text(r)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        HStack(spacing: 6) {
                            Text(c.fecha, format: .dateTime.day().month().hour().minute())
                            Text("·")
                            Text("\(c.mensajes)")
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 9))
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.appSurface)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func retomar(_ sessionId: UUID) async {
        guard await ChatPersistenceService.shared.retomar(
            householdId: householdId, userId: userId, sessionId: sessionId
        ) != nil else { return }
        abierta = nil
        onRetomar()
        dismiss()
    }
}

/// Lectura de una conversación archivada.
///
/// Sólo lectura a propósito: acá no se ejecutan acciones. Si el usuario quiere
/// seguir hablando de eso, la retoma y vuelve al chat de verdad.
@MainActor
private struct ConversacionArchivadaView: View {
    let sesion: ChatSessionRecord
    let onRetomar: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(sesion.messages.filter { !$0.content.isEmpty && $0.role != .system }) { m in
                    HStack {
                        if m.role == .user { Spacer(minLength: 40) }
                        Text(m.content)
                            .font(.callout)
                            .padding(12)
                            .background(m.role == .user ? Color.brandPrimary.opacity(0.18) : Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        if m.role != .user { Spacer(minLength: 40) }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 5, leading: 14, bottom: 5, trailing: 14))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(Text(sesion.createdAt, format: .dateTime.day().month().year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Haptics.play(.impactLight)
                        onRetomar()
                    } label: {
                        Label {
                            Text("assistant.history.resume")
                        } icon: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                    }
                }
            }
        }
    }
}
