import SwiftUI

struct DetailView: View {
    let hora: Horas

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        List {
            Section("Sesión #\(hora.id)") {
                LabeledRow("Usuario",      hora.user)
                LabeledRow("Encendido",    hora.hora_encendido.map { Self.dateFmt.string(from: $0) } ?? "—")
                LabeledRow("Apagado",      hora.hora_apagado.map { Self.dateFmt.string(from: $0) } ?? "Sigue ON")
                LabeledRow("Duración",     hora.durationFormatted)
                LabeledRow("Inactividad",  "\(hora.minutosInactivo ?? 0) min")
            }

            if let apps = hora.listaApps, !apps.isEmpty {
                Section("Aplicaciones usadas") {
                    Text(apps)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Section("Estado") {
                HStack {
                    Circle()
                        .fill(hora.isOn ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    Text(hora.isOn ? "PC encendida" : "PC apagada")
                }
            }
        }
        .navigationTitle("Detalle")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LabeledRow: View {
    let label: String
    let value: String
    init(_ label: String, _ value: String) {
        self.label = label; self.value = value
    }
    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}
