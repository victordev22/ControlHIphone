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

    var body: some View {
        Color.clear
            .onAppear { authVM.logout() }
    }
}
