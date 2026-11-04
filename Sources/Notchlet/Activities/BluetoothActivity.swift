import SwiftUI

/// Activité brève : un appareil Bluetooth vient de se connecter.
struct BluetoothActivity: Activity {
    let deviceName: String
    let battery: BluetoothBattery
    let minorType: String?

    var id: String { "bluetooth.\(deviceName)" }
    var displayDuration: TimeInterval { 4 }
    var closedWing: CGFloat { 50 }

    var closedView: AnyView {
        AnyView(
            HStack {
                BouncingSymbol(name: Self.symbol(name: deviceName, minorType: minorType))
                Spacer()
                if let level = battery.displayed {
                    Text("\(level)%")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(level <= 20 ? Color.red : Color.green)
                }
            }
        )
    }

    var closedFooter: AnyView? {
        AnyView(
            Text(deviceName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .padding(.horizontal, 16)
        )
    }

    /// shortcut: le modèle est déduit du nom ; des AirPods renommés sans « AirPods » auront
    /// l'icône générique du casque. À remplacer par les identifiants de produit au besoin.
    static func symbol(name: String, minorType: String?) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("airpods") {
            if lowercased.contains("max") { return "airpodsmax" }
            return lowercased.contains("pro") ? "airpodspro" : "airpods"
        }
        switch minorType {
        case "Headphones", "Headset": return "headphones"
        case "Speaker": return "hifispeaker.fill"
        case "Keyboard": return "keyboard.fill"
        case "Mouse": return "computermouse.fill"
        default: return "dot.radiowaves.left.and.right"
        }
    }
}

/// Icône qui apparaît avec un petit rebond : un ressort animé, plutôt que des vidéos
/// propres à chaque modèle.
private struct BouncingSymbol: View {
    let name: String
    @State private var isVisible = false

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .scaleEffect(isVisible ? 1 : 0.3)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { isVisible = true }
            }
    }
}
