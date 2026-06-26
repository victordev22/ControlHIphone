import SwiftUI

enum HorasFilter: String, CaseIterable, Identifiable {
    case all       = "Ver todos"
    case poweredOn = "PCs Encendidas"
    case byUser    = "Por usuario"

    var id: String { rawValue }
}

struct ListHorasView: View {
    @State private var horasList:    [Horas] = []
    @State private var isLoading     = true
    @State private var errorMessage: String?
    @State private var filter:       HorasFilter = .all
    @State private var selectedUser: String?
    @State private var uniqueUsers:  [String] = []
    @State private var showFilter    = false
    @State private var statsTarget:  UserStatsItem?

    private let service = ControlService.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Cargando…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMessage {
                VStack(spacing: 12) {
                    Text("Error: \(err)").foregroundColor(.red)
                    Button("Reintentar") { Task { await loadData() } }
                        .buttonStyle(.bordered)
                }
            } else if filtered.isEmpty {
                Text("No hay registros.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filtered) { hora in
                    Button { statsTarget = UserStatsItem(nickname: hora.user) } label: {
                        HoraRow(hora: hora)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Listado de Horas")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Ver todos")         { filter = .all;       selectedUser = nil }
                    Button("PCs Encendidas")    { filter = .poweredOn; selectedUser = nil }
                    Divider()
                    ForEach(uniqueUsers, id: \.self) { user in
                        Button {
                            filter = .byUser
                            selectedUser = user
                        } label: {
                            Label(user, systemImage: selectedUser == user ? "checkmark" : "person")
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        // ✅ Después — directo, sin transformación
        .sheet(item: $statsTarget) { item in
            UserStatsSheet(userNickname: item.nickname, allHoras: horasList)
        }        .task { await loadData() }
        .refreshable { await loadData() }
    }

    // MARK: Filtered list

    private var filtered: [Horas] {
        let base = selectedUser.map { u in horasList.filter { $0.user == u } } ?? horasList
        switch filter {
        case .all, .byUser: return base
        case .poweredOn:    return base.filter { $0.isOn }
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            let list = try await service.getHoras()
            horasList   = list
            uniqueUsers = Array(Set(list.map { $0.user })).sorted()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}

// Thin wrapper to make an optional String Identifiable for .sheet(item:)
private struct UserStatsItem: Identifiable {
    let nickname: String
    var id: String { nickname }
}


