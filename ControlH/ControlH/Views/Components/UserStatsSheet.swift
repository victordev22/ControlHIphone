import SwiftUI

// Shows usage statistics for a given user — replaces UserStatsDialog
struct UserStatsSheet: View {
    let userNickname: String
    let allHoras: [Horas]

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    private var userSessions: [Horas] {
        allHoras
            .filter { $0.user == userNickname }
            .sorted { ($0.hora_encendido ?? .distantPast) > ($1.hora_encendido ?? .distantPast) }
    }

    private var totalSeconds: TimeInterval {
        userSessions.reduce(0) { $0 + $1.durationSeconds }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Resumen de \(userNickname)") {
                    LabeledRow("Sesiones registradas", "\(userSessions.count)")
                    LabeledRow("Tiempo total", format(seconds: totalSeconds))
                }

                Section("Historial") {
                    ForEach(userSessions) { h in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(h.hora_encendido.map { Self.dateFmt.string(from: $0) } ?? "—")
                                    .font(.subheadline)
                                Spacer()
                                Text(h.durationFormatted)
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            Text(h.isOn ? "🟢 Sigue ON" : "🔴 Apagado")
                                .font(.caption2)
                                .foregroundColor(h.isOn ? .green : .secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Estadísticas")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func format(seconds s: TimeInterval) -> String {
        let h = Int(s) / 3600
        let m = (Int(s) % 3600) / 60
        return "\(h)h \(m)m"
    }
}
