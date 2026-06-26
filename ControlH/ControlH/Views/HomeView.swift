import SwiftUI

struct HomeView: View {
    @Environment(AuthViewModel.self)    var authVM
    @Environment(HomeViewModel.self)    var homeVM
    @Environment(ControlViewModel.self) var controlVM

    var body: some View {
        Group {
            if authVM.isLoading || authVM.currentUser == nil {
                ProgressView("Cargando perfil...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let user = authVM.currentUser {
                if user.isAdmin {
                    AdminHomeView()
                } else {
                    UserHomeView()
                }
            }
        }
        .navigationTitle(authVM.currentUser?.nickname ?? "ControlH")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let user = authVM.currentUser else { return }
            homeVM.fetchHoras(user.nickname)
        }
        .onChange(of: homeVM.currentUserHours) { _, entry in
            if case .success = homeVM.horasUiState, let entry {
                controlVM.syncPowerState(entry.isOn)
            }
        }
    }
}

// MARK: - Admin home content

struct AdminHomeView: View {
    @Environment(HomeViewModel.self)    var homeVM
    @Environment(ControlViewModel.self) var controlVM
    @Environment(AuthViewModel.self)    var authVM

    var body: some View {
        let horasData    = homeVM.horasUiState.horas
        let weeklyLeast  = homeVM.adminWeeklyLeast(from: horasData)
        let monthlyLeast = homeVM.adminMonthlyLeast(from: horasData)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Panel de Administrador")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .center)

                if let err = homeVM.horasUiState.errorMessage {
                    Text("Error: \(err)").foregroundColor(.red)
                }

                SectionHeader("Menos horas esta semana")
                if weeklyLeast.isEmpty {
                    Text("Sin datos esta semana.").foregroundColor(.secondary)
                } else {
                    ForEach(weeklyLeast) { s in
                        UsageCard(summary: s, maxMillis: weeklyLeast.map(\.totalMillis).max() ?? 1)
                    }
                }

                SectionHeader("Menos horas este mes")
                if monthlyLeast.isEmpty {
                    Text("Sin datos este mes.").foregroundColor(.secondary)
                } else {
                    ForEach(monthlyLeast) { s in
                        UsageCard(summary: s, maxMillis: monthlyLeast.map(\.totalMillis).max() ?? 1)
                    }
                }

                HStack {
                    Spacer()
                    PowerButton()
                    Spacer()
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .refreshable { homeVM.fetchHoras(authVM.currentUser?.nickname ?? "") }
    }
}

// MARK: - User home content

struct UserHomeView: View {
    @Environment(HomeViewModel.self)    var homeVM
    @Environment(ControlViewModel.self) var controlVM
    @Environment(AuthViewModel.self)    var authVM

    var body: some View {
        let userId    = authVM.currentUser?.nickname ?? ""
        let horasData = homeVM.horasUiState.horas.filter { $0.user == userId }

        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Control de PC Personal")
                    .font(.title3.bold())
                let suffix  = userId.suffix(2).uppercased()
                let display = homeVM.currentUserHours?.durationFormatted ?? "00:00:00"
                Text("PC\(suffix)  |  Hoy: \(display)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()

            if horasData.isEmpty {
                Spacer()
                Text("No hay registros de sesiones.")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(horasData) { hora in
                    NavigationLink(value: hora) {
                        HoraRow(hora: hora)
                    }
                }
                .listStyle(.insetGrouped)
                .navigationDestination(for: Horas.self) { hora in
                    DetailView(hora: hora)
                }
            }

            HStack {
                Spacer()
                PowerButton()
                Spacer()
            }
            .padding(.bottom, 24)
        }
        .refreshable { homeVM.fetchHoras(userId) }
    }
}

// MARK: - Helper views

struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.top, 4)
    }
}

struct UsageCard: View {
    let summary: UserUsageSummary
    let maxMillis: TimeInterval

    var body: some View {
        let hours    = Int(summary.totalMillis) / 3600
        let minutes  = (Int(summary.totalMillis) % 3600) / 60
        let progress = maxMillis > 0 ? Float(summary.totalMillis / maxMillis) : 0

        VStack(alignment: .leading, spacing: 6) {
            Text(summary.user)
                .font(.headline)
                .foregroundColor(.accentColor)
            Text("\(hours)h \(minutes)m")
                .font(.subheadline)
            ProgressView(value: progress)
                .tint(.accentColor)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
