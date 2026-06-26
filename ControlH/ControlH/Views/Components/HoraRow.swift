import SwiftUI

struct HoraRow: View {
    let hora: Horas

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(hora.user)
                    .font(.headline)
                    .foregroundColor(.accentColor)
                Spacer()
                Circle()
                    .fill(hora.isOn ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
            }
            Group {
                let encendido = hora.hora_encendido.map { Self.fmt.string(from: $0) } ?? "—"
                let apagado   = hora.hora_apagado.map   { Self.fmt.string(from: $0) } ?? "Sigue ON"
                Text("Encendido: \(encendido)  |  Apagado: \(apagado)")
                Text("Inactividad: \(hora.minutosInactivo ?? 0) min")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
