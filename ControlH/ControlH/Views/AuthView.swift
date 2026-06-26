import SwiftUI

struct AuthView: View {
    @Environment(AuthViewModel.self) var authVM

    var body: some View {
        @Bindable var vm = authVM
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(radius: 6)
                        .padding(.top, 48)

                    Text(vm.isLoginScreen ? "Iniciar Sesión" : "Registrarse")
                        .font(.title.bold())

                    VStack(spacing: 14) {
                        if !vm.isLoginScreen {
                            FormField(title: "Nombre de usuario", text: $vm.nickname)
                        }
                        FormField(title: "Email", text: $vm.email, contentType: .emailAddress, keyboard: .emailAddress)
                        FormField(title: "Contraseña", text: $vm.password, isSecure: true)
                    }
                    .padding(.horizontal)

                    if let err = vm.errorMessage {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    if let ok = vm.successMessage {
                        Text(ok)
                            .foregroundColor(.green)
                            .font(.footnote)
                            .padding(.horizontal)
                    }

                    Button {
                        if vm.isLoginScreen { vm.signIn() } else { vm.signUp() }
                    } label: {
                        if vm.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text(vm.isLoginScreen ? "Entrar" : "Crear cuenta")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isLoading)
                    .padding(.horizontal)

                    if vm.isLoginScreen {
                        HStack {
                            VStack { Divider() }
                            Text("o").font(.subheadline).foregroundColor(.secondary)
                            VStack { Divider() }
                        }
                        .padding(.horizontal)

                        Button {
                            vm.signInWithKeycloak()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.badge.key.fill")
                                Text("Entrar con Keycloak")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .buttonStyle(.bordered)
                        .disabled(vm.isLoading)
                        .padding(.horizontal)
                    }

                    Button(vm.isLoginScreen
                           ? "¿No tienes cuenta? Regístrate"
                           : "¿Ya tienes cuenta? Inicia sesión") {
                        vm.toggleAuthScreen()
                    }
                    .font(.subheadline)

                    Spacer(minLength: 40)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Reusable form field

struct FormField: View {
    let title: String
    @Binding var text: String
    var contentType: UITextContentType? = nil
    var keyboard: UIKeyboardType = .default
    var isSecure = false

    var body: some View {
        Group {
            if isSecure {
                SecureField(title, text: $text)
            } else {
                TextField(title, text: $text)
                    .keyboardType(keyboard)
            }
        }
        .textContentType(contentType)
        .autocorrectionDisabled()
        .autocapitalization(.none)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}
