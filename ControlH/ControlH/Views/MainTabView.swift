import SwiftUI

struct MainTabView: View {
    @Environment(AuthViewModel.self) var authVM
    @State private var homeVM    = HomeViewModel()
    @State private var controlVM = ControlViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .environment(homeVM)
            .environment(controlVM)
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                ListHorasView()
            }
            .tabItem {
                Label("Horas", systemImage: "list.bullet")
            }

            if authVM.currentUser?.isAdmin == true {
                NavigationStack {
                    ListUserView()
                }
                .tabItem {
                    Label("Usuarios", systemImage: "person.2.fill")
                }

                NavigationStack {
                    IncidenciaView()
                }
                .tabItem {
                    Label("Incidencias", systemImage: "ant.fill")
                }
            }

            LogoutTab()
                .tabItem {
                    Label("Salir", systemImage: "rectangle.portrait.and.arrow.right")
                }
        }
    }
}

private struct LogoutTab: View {
    @Environment(AuthViewModel.self) var authVM
    @State private var confirmLogout = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 52))
                .foregroundColor(.secondary)
            Text("¿Cerrar sesión?")
                .font(.title2.bold())
            Button("Salir", role: .destructive) {
                authVM.logout()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
