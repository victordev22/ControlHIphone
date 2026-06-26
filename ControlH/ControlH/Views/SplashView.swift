import SwiftUI

struct SplashView: View {
    @Environment(AuthViewModel.self) var authVM
    @State private var isActive = false

    var body: some View {
        if isActive {
            if authVM.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        } else {
            ZStack {
                Color.accentColor.opacity(0.1).ignoresSafeArea()
                VStack(spacing: 24) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(radius: 8)

                    Text("ControlH")
                        .font(.largeTitle.bold())
                        .foregroundColor(.accentColor)

                    ProgressView()
                }
            }
            .task {
                if authVM.isAuthenticated {
                    await authVM.fetchCurrentUser()
                }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                withAnimation { isActive = true }
            }
        }
    }
}
