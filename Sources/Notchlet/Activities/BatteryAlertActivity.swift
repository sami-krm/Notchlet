import SwiftUI

/// Activité brève : le Mac vient d'être branché, ou sa batterie est faible.
struct BatteryAlertActivity: Activity {
    let alert: BatteryAlert
    var duration: TimeInterval = 3
    var showsPercentage = true

    var displayDuration: TimeInterval { duration }

    var id: String {
        switch alert {
        case .charging: return "battery.charging"
        case .low: return "battery.low"
        }
    }

    // "100%" est plus large qu'une pochette.
    var closedWing: CGFloat { 50 }

    var closedView: AnyView {
        switch alert {
        case .charging(let level):
            return content(symbol: "battery.100.bolt", color: .green, level: level)
        case .low(let level):
            return content(symbol: "battery.25", color: .red, level: level)
        }
    }

    private func content(symbol: String, color: Color, level: Int) -> AnyView {
        AnyView(
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 15))
                    // Ce symbole a ses propres couleurs : on impose une teinte unique.
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(color)
                Spacer()
                if showsPercentage {
                    Text("\(level)%")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(color)
                }
            }
        )
    }
}
