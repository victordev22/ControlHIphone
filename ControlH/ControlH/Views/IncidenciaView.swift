import SwiftUI

private let estados = ["ABIERTA", "EN_PROCESO", "CERRADA"]

struct IncidenciaView: View {
    @Environment(AuthViewModel.self) var authVM
    @State private var incidencias:   [Incidencia] = []
    @State private var isLoading      = true
    @State private var errorMessage:  String?
    @State private var searchQuery    = ""
    @State private var showForm       = false
    @State private var editTarget:    Incidencia?
    @State private var deleteTarget:  Incidencia?

    private let service = IncidenciaService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Buscar incidencia…", text: $searchQuery)
                    .autocorrectionDisabled()
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMessage {
                    VStack(spacing: 12) {
                        Text(err).foregroundColor(.red)
                        Button("Reintentar") { Task { await loadData() } }.buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    Text("No hay incidencias").foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filtered) { inc in
                        IncidenciaCard(
                            incidencia: inc,
                            onEdit:   { editTarget = inc; showForm = true },
                            onDelete: { deleteTarget = inc }
                        )
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle("Incidencias")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { editTarget = nil; showForm = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await loadData() }
        .refreshable { await loadData() }

        // Form sheet
        .sheet(isPresented: $showForm) {
            IncidenciaFormSheet(incidencia: editTarget) { pcId, gestor, desc, estado in
                Task { await save(pcId: pcId, gestor: gestor, desc: desc, estado: estado) }
            }
        }

        // Delete confirmation
        .alert("¿Eliminar incidencia?",
               isPresented: Binding(get: { deleteTarget != nil },
                                    set: { if !$0 { deleteTarget = nil } })) {
            Button("Eliminar", role: .destructive) {
                if let t = deleteTarget { Task { await delete(id: t.id) } }
            }
            Button("Cancelar", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("¿Seguro que deseas eliminar la incidencia #\(deleteTarget?.id ?? 0)?")
        }
    }

    // MARK: Filtered

    private var filtered: [Incidencia] {
        guard !searchQuery.isEmpty else { return incidencias }
        let q = searchQuery.lowercased()
        return incidencias.filter {
            $0.incidencia.lowercased().contains(q) ||
            $0.gestor_incidencia.lowercased().contains(q) ||
            ($0.pc.nickname?.lowercased().contains(q) == true) ||
            "\($0.pc.id)".contains(q) ||
            ($0.estado?.lowercased().contains(q) == true)
        }
    }

    // MARK: - Network

    private func loadData() async {
        isLoading = true; errorMessage = nil
        do {
            incidencias = try await service.getIncidencias()
        } catch APIError.unauthorized {
            authVM.clearLocalSession()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    private func save(pcId: Int, gestor: String, desc: String, estado: String?) async {
        do {
            if let target = editTarget {
                _ = try await service.updateIncidencia(
                    id: target.id,
                    req: UpdateIncidenciaRequest(gestor_incidencia: gestor,
                                                incidencia: desc,
                                                estado: estado)
                )
            } else {
                _ = try await service.createIncidencia(
                    CreateIncidenciaRequest(pc: PcRef(id: pcId),
                                           gestor_incidencia: gestor,
                                           incidencia: desc)
                )
            }
            showForm = false
            editTarget = nil
            await loadData()
        } catch {}
    }

    private func delete(id: Int) async {
        do {
            try await service.deleteIncidencia(id: id)
            deleteTarget = nil
            await loadData()
        } catch {}
    }
}

// MARK: - Card

private struct IncidenciaCard: View {
    let incidencia: Incidencia
    let onEdit:   () -> Void
    let onDelete: () -> Void

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short; f.timeStyle = .short
        return f
    }()

    private var estadoColor: Color {
        switch incidencia.estado {
        case "CERRADA":    return .green
        case "EN_PROCESO": return .blue
        default:           return .red
        }
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("#\(incidencia.id)").font(.caption).foregroundColor(.secondary)
                    if let e = incidencia.estado {
                        Text(e)
                            .font(.caption.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(estadoColor.opacity(0.15))
                            .foregroundColor(estadoColor)
                            .cornerRadius(4)
                    }
                }
                Text("PC: \(incidencia.pc.nickname ?? "ID \(incidencia.pc.id)")")
                    .font(.headline).foregroundColor(.accentColor)
                Text("Gestor: \(incidencia.gestor_incidencia)")
                    .font(.caption).foregroundColor(.secondary)
                Text(incidencia.incidencia).font(.subheadline)
                if let f = incidencia.fecha {
                    Text(Self.fmt.string(from: f)).font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack {
                Button { onEdit() }   label: { Image(systemName: "pencil").padding(6) }
                    .foregroundColor(.accentColor)
                Button { onDelete() } label: { Image(systemName: "trash").padding(6) }
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Form sheet

private struct IncidenciaFormSheet: View {
    @Environment(\.dismiss) var dismiss
    let incidencia: Incidencia?
    let onSave: (Int, String, String, String?) -> Void

    @State private var pcId       = ""
    @State private var gestor     = ""
    @State private var descripcion = ""
    @State private var estado     = estados[0]
    @State private var pcError    = false

    init(incidencia: Incidencia?, onSave: @escaping (Int, String, String, String?) -> Void) {
        self.incidencia = incidencia
        self.onSave = onSave
        _pcId        = State(initialValue: incidencia?.pc.id.description ?? "")
        _gestor      = State(initialValue: incidencia?.gestor_incidencia ?? "")
        _descripcion = State(initialValue: incidencia?.incidencia ?? "")
        _estado      = State(initialValue: incidencia?.estado ?? estados[0])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ID de PC", text: $pcId)
                        .keyboardType(.numberPad)
                        .disabled(incidencia != nil)
                    if pcError {
                        Text("Ingresa un ID de PC válido").font(.caption).foregroundColor(.red)
                    }
                }
                Section {
                    TextField("Gestor", text: $gestor)
                    TextField("Descripción", text: $descripcion, axis: .vertical)
                        .lineLimit(3...6)
                }
                if incidencia != nil {
                    Section("Estado") {
                        Picker("Estado", selection: $estado) {
                            ForEach(estados, id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle(incidencia == nil ? "Nueva Incidencia" : "Editar Incidencia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        guard let id = Int(pcId) else { pcError = true; return }
                        onSave(id, gestor.trimmingCharacters(in: .whitespaces),
                               descripcion.trimmingCharacters(in: .whitespaces),
                               incidencia != nil ? estado : nil)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}
