import SwiftUI

struct ListUserView: View {
    @Environment(AuthViewModel.self) var authVM
    @State private var users:         [UserFull] = []
    @State private var isLoading      = true
    @State private var errorMessage:  String?
    @State private var editTarget:    UserFull?
    @State private var settingsTarget: UserFull?
    @State private var deleteTarget:  UserFull?

    private let authService = AuthService.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Cargando usuarios…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMessage {
                VStack(spacing: 12) {
                    Text("Error: \(err)").foregroundColor(.red)
                    Button("Reintentar") { Task { await loadData() } }.buttonStyle(.bordered)
                }
            } else {
                List(users) { user in
                    UserCard(
                        user: user,
                        onEdit:     { editTarget     = user },
                        onSettings: { settingsTarget = user },
                        onDelete:   { deleteTarget   = user }
                    )
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Gestión de Usuarios")
        .task { await loadData() }
        .refreshable { await loadData() }

        // Edit basic info
        .sheet(item: $editTarget) { user in
            EditUserSheet(user: user) { updated, newRole in
                Task { await saveUser(updated, newRole: newRole) }
            }
        }

        // Edit PC settings
        .sheet(item: $settingsTarget) { user in
            EditUserSettingsSheet(user: user) { updated in
                Task { await saveUserSettings(updated) }
            }
        }

        // Delete confirmation
        .alert("¿Eliminar usuario?",
               isPresented: Binding(get: { deleteTarget != nil },
                                    set: { if !$0 { deleteTarget = nil } })) {
            Button("Eliminar", role: .destructive) {
                if let u = deleteTarget { Task { await deleteUser(u) } }
            }
            Button("Cancelar", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("¿Seguro que deseas eliminar a \(deleteTarget?.nickname ?? "este usuario")? Esta acción no se puede deshacer.")
        }
    }

    // MARK: - Network

    private func loadData() async {
        isLoading = true; errorMessage = nil
        do {
            users = try await authService.getAllUsers()
        } catch APIError.unauthorized {
            authVM.clearLocalSession()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    private func saveUser(_ user: UserFull, newRole: Int) async {
        guard let email = user.email else { return }
        let req = UpdateUserRequest(nickname: user.nickname,
                                    on_control: user.on_control,
                                    of_control: user.of_control)
        do {
            _ = try await authService.updateUserByEmail(email, request: req)
            let roleName = newRole == 2 ? "ROLE_ADMIN" : "ROLE_USER"
            _ = try await authService.assignRole(email: email, roleName: roleName)
            editTarget = nil
            await loadData()
        } catch {}
    }

    private func saveUserSettings(_ user: UserFull) async {
        guard let email = user.email else { return }
        let req = UpdateUserRequest(
            nickname: user.nickname, email: user.email,
            on_control: user.on_control, of_control: user.of_control,
            version_windows: user.version_windows, password_pc: user.password_pc,
            password_nas1: user.password_nas1, password_2: user.password_2,
            memoria_ram: user.memoria_ram, cpu: user.cpu,
            tarjeta_grafica: user.tarjeta_grafica,
            puerto_escritorio_remoto: user.puerto_escritorio_remoto,
            direccion_ip: user.direccion_ip, mac: user.mac,
            procesador: user.procesador, tipo_de_estacion: user.tipo_de_estacion,
            nombre_user: user.nombre_user, localizacion: user.localizacion,
            estado: user.estado
        )
        do {
            _ = try await authService.updateUserByEmail(email, request: req)
            settingsTarget = nil
            await loadData()
        } catch {}
    }

    private func deleteUser(_ user: UserFull) async {
        guard let email = user.email else { return }
        do {
            try await authService.deleteUserByEmail(email)
            deleteTarget = nil
            await loadData()
        } catch {}
    }
}

// MARK: - User card row

struct UserCard: View {
    let user: UserFull
    let onEdit:     () -> Void
    let onSettings: () -> Void
    let onDelete:   () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.nickname ?? "Sin nombre")
                        .font(.headline).foregroundColor(.accentColor)
                    Text(user.email ?? "Sin email").font(.subheadline)
                    Text("Rol: \(user.isAdmin ? "ADMIN" : "USER")").font(.caption).foregroundColor(.secondary)
                    Text("ON: \(user.on_control ?? "--") | OFF: \(user.of_control ?? "--")")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 0) {
                    Button { onEdit() }     label: { Image(systemName: "pencil").padding(8) }
                        .foregroundColor(.accentColor)
                    Button { onSettings() } label: { Image(systemName: "gearshape").padding(8) }
                        .foregroundColor(.blue)
                    Button { onDelete() }   label: { Image(systemName: "trash").padding(8) }
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Edit basic info sheet

private struct EditUserSheet: View {
    @Environment(\.dismiss) var dismiss
    @State var user: UserFull
    @State var selectedRole: Int  // 1 = ROLE_USER, 2 = ROLE_ADMIN
    let onSave: (UserFull, Int) -> Void

    init(user: UserFull, onSave: @escaping (UserFull, Int) -> Void) {
        _user = State(initialValue: user)
        _selectedRole = State(initialValue: user.isAdmin ? 2 : 1)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos") {
                    TextField("Nickname", text: Binding($user.nickname, ""))
                    TextField("ON control", text: Binding($user.on_control, ""))
                    TextField("OFF control", text: Binding($user.of_control, ""))
                }
                Section("Rol") {
                    Picker("Rol", selection: $selectedRole) {
                        Text("ROLE_USER").tag(1)
                        Text("ROLE_ADMIN").tag(2)
                    }.pickerStyle(.segmented)
                }
            }
            .navigationTitle("Editar usuario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { onSave(user, selectedRole); dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Edit PC settings sheet

private struct EditUserSettingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @State var user: UserFull
    let onSave: (UserFull) -> Void

    var body: some View {
        NavigationStack {
            Form {
                pcField("Windows version",  $user.version_windows)
                pcField("Password PC",      $user.password_pc)
                pcField("Password NAS1",    $user.password_nas1)
                pcField("Password 2",       $user.password_2)
                pcField("RAM",              $user.memoria_ram)
                pcField("CPU",              $user.cpu)
                pcField("Tarjeta gráfica",  $user.tarjeta_grafica)
                pcField("Puerto escritorio",$user.puerto_escritorio_remoto)
                pcField("Dirección IP",     $user.direccion_ip)
                pcField("MAC",              $user.mac)
                pcField("Procesador",       $user.procesador)
                pcField("Tipo estación",    $user.tipo_de_estacion)
                pcField("Nombre usuario",   $user.nombre_user)
                pcField("Localización",     $user.localizacion)
                pcField("Estado",           $user.estado)
            }
            .navigationTitle("Configuración PC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { onSave(user); dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func pcField(_ label: String, _ binding: Binding<String?>) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            TextField(label, text: Binding(binding, ""))
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Optional<String> Binding helper

//  Después — Value == String  →  produce Binding<String>, compatible con TextField
extension Binding where Value == String {
    init(_ source: Binding<String?>,_ defaultValue: String = "") {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { source.wrappedValue = $0.isEmpty ? nil : $0 }  // $0 es String → ok
        )
    }
}
