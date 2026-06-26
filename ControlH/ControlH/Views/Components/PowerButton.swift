import SwiftUI

struct PowerButton: View {
    @Environment(ControlViewModel.self) var controlVM

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(controlVM.uiState.isPoweredOn ? Color(hex: "43A047") : Color(hex: "E53935"))
                    .frame(width: 120, height: 120)
                    .shadow(radius: 8)

                if controlVM.uiState.isConnecting {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.4)
                } else {
                    Image(systemName: "power")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .foregroundColor(.white)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: controlVM.uiState.isPoweredOn)
            .onTapGesture {
                guard !controlVM.uiState.isConnecting else { return }
                controlVM.togglePower()
            }

            Text("Status: \(controlVM.uiState.isPoweredOn ? "On" : "Off")")
                .font(.title3.bold())

            if let err = controlVM.uiState.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Hex color helper

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8)  & 0xFF) / 255
        let b = Double( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
