import SwiftUI

/// Activité de fond : un appel est en cours ou arrive.
struct CallActivity: Activity {
    let calls: CallManager

    let id = "call"
    var closedWing: CGFloat { 56 }
    var closedView: AnyView { AnyView(CallClosedView(calls: calls)) }
}

private struct CallClosedView: View {
    @ObservedObject var calls: CallManager

    var body: some View {
        HStack {
            Image(systemName: calls.incoming != nil ? "phone.fill" : (calls.isMicMuted ? "mic.slash.fill" : "mic.fill"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(calls.isMicMuted && calls.incoming == nil ? Color.red : Color.green)
            Spacer()
            if let start = calls.callStart, calls.incoming == nil {
                Text(timerInterval: start...Date.distantFuture, countsDown: false)
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .fixedSize()
            }
        }
    }
}

/// Île ouverte pendant un appel.
struct CallOpenView: View {
    @ObservedObject var calls: CallManager
    let horizontalPadding: CGFloat
    let topPadding: CGFloat

    var body: some View {
        VStack(spacing: 14) {
            if let incoming = calls.incoming {
                Text(incoming.caller)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text("Appel entrant")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 28) {
                    roundButton("phone.down.fill", color: .red, label: "Refuser") { calls.declineIncoming() }
                    roundButton("phone.fill", color: .green, label: "Accepter") { calls.acceptIncoming() }
                }
            } else if let start = calls.callStart {
                Text("Appel en cours")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Text(timerInterval: start...Date.distantFuture, countsDown: false)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if calls.canMuteMic {
                    roundButton(calls.isMicMuted ? "mic.slash.fill" : "mic.fill",
                                color: calls.isMicMuted ? .red : Color.white.opacity(0.2),
                                label: calls.isMicMuted ? "Réactiver le micro" : "Couper le micro") {
                        calls.toggleMicMute()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
    }

    private func roundButton(_ symbol: String, color: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(color))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
