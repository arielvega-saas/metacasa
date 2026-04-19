import SwiftUI
import Observation

@MainActor
@Observable
final class ManageCategoriesViewModel {
    var data: CategoriesData = CategoriesData()
    var isLoading = false
    var errorMessage: String?

    func load(householdId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if let blob = try await CategoryService.shared.fetch(householdId: householdId) {
                self.data = blob.data
            } else {
                // Seed con los defaults para que el usuario vea algo editable
                self.data = CategoriesData(
                    gastos: CategoryCatalog.defaultGastos.map {
                        CategoryItem(name: $0, emoji: CategoryCatalog.emoji(for: $0))
                    },
                    ingresos: CategoryCatalog.defaultIngresos.map {
                        CategoryItem(name: $0, emoji: CategoryCatalog.emoji(for: $0))
                    }
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(householdId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await CategoryService.shared.save(householdId: householdId, data: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ManageCategoriesView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ManageCategoriesViewModel()
    @State private var selectedType: TxType = .gasto
    @State private var showAdd = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                Picker("Tipo", selection: $selectedType) {
                    Text("Gastos").tag(TxType.gasto)
                    Text("Ingresos").tag(TxType.ingreso)
                }
                .pickerStyle(.segmented)
                .padding()

                List {
                    ForEach(items, id: \.name) { item in
                        NavigationLink(destination: EditCategoryView(
                            item: item,
                            type: selectedType,
                            onSave: { updated in
                                await updateItem(updated)
                            },
                            onDelete: {
                                await removeItem(item)
                            }
                        )) {
                            HStack {
                                Text(item.emoji ?? "📌").font(.title2)
                                VStack(alignment: .leading) {
                                    Text(item.name).font(.mcBody.weight(.bold)).foregroundStyle(Color.textPrimary)
                                    if let subs = item.subcategories, !subs.isEmpty {
                                        Text("\(subs.count) subcategoría\(subs.count == 1 ? "" : "s")")
                                            .font(.mcCaption).foregroundStyle(Color.textMuted)
                                    }
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
        }
        .navigationTitle("Categorías")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            EditCategoryView(
                item: nil,
                type: selectedType,
                onSave: { created in
                    await addItem(created)
                },
                onDelete: nil
            )
        }
        .task {
            if let hid = appState.currentHouseholdId {
                await viewModel.load(householdId: hid)
            }
        }
    }

    private var items: [CategoryItem] {
        selectedType == .gasto ? viewModel.data.gastos : viewModel.data.ingresos
    }

    @MainActor
    private func addItem(_ item: CategoryItem) async {
        if selectedType == .gasto {
            viewModel.data.gastos.append(item)
        } else {
            viewModel.data.ingresos.append(item)
        }
        await persist()
    }

    @MainActor
    private func updateItem(_ item: CategoryItem) async {
        if selectedType == .gasto {
            if let idx = viewModel.data.gastos.firstIndex(where: { $0.name == item.name }) {
                viewModel.data.gastos[idx] = item
            }
        } else {
            if let idx = viewModel.data.ingresos.firstIndex(where: { $0.name == item.name }) {
                viewModel.data.ingresos[idx] = item
            }
        }
        await persist()
    }

    @MainActor
    private func removeItem(_ item: CategoryItem) async {
        if selectedType == .gasto {
            viewModel.data.gastos.removeAll { $0.name == item.name }
        } else {
            viewModel.data.ingresos.removeAll { $0.name == item.name }
        }
        await persist()
    }

    @MainActor
    private func persist() async {
        if let hid = appState.currentHouseholdId {
            await viewModel.save(householdId: hid)
        }
    }
}

/// Editor de categoría: name + emoji + subcategorías.
struct EditCategoryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var emoji: String
    @State private var subcategories: [String]
    @State private var newSub: String = ""

    let originalName: String?
    let type: TxType
    let onSave: (CategoryItem) async -> Void
    let onDelete: (() async -> Void)?

    init(
        item: CategoryItem?,
        type: TxType,
        onSave: @escaping (CategoryItem) async -> Void,
        onDelete: (() async -> Void)?
    ) {
        self._name = State(initialValue: item?.name ?? "")
        self._emoji = State(initialValue: item?.emoji ?? "📌")
        self._subcategories = State(initialValue: item?.subcategories ?? [])
        self.originalName = item?.name
        self.type = type
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Ej: Supermercado", text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section("Emoji") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 8), spacing: 8) {
                        ForEach(CategoryCatalog.emojiPalette, id: \.self) { e in
                            Button { emoji = e } label: {
                                Text(e).font(.title2)
                                    .frame(width: 36, height: 36)
                                    .background(emoji == e ? Color.brandPrimary.opacity(0.2) : Color.clear)
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
                Section("Subcategorías") {
                    ForEach(subcategories, id: \.self) { s in
                        Text(s)
                    }
                    .onDelete { idx in subcategories.remove(atOffsets: idx) }

                    HStack {
                        TextField("Nueva subcategoría", text: $newSub)
                        Button("Agregar") {
                            let trimmed = newSub.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty, !subcategories.contains(trimmed) {
                                subcategories.append(trimmed)
                                newSub = ""
                            }
                        }
                        .disabled(newSub.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                if let onDelete {
                    Section {
                        Button("Eliminar categoría", role: .destructive) {
                            Task {
                                await onDelete()
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle(originalName == nil ? "Nueva categoría" : originalName!)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            await onSave(CategoryItem(
                                name: name,
                                emoji: emoji,
                                subcategories: subcategories.isEmpty ? nil : subcategories
                            ))
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
