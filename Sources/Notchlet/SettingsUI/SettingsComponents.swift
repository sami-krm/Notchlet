import SwiftUI

/// Couleur d'accent de l'app, propre à Notchlet.
enum NotchletStyle {
    static let accent = Color(red: 0.98, green: 0.65, blue: 0.20)
}

/// Icône colorée d'une rubrique : un symbole blanc sur un carré arrondi.
struct SettingsIcon: View {
    let symbol: String
    let colors: [Color]
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28)
                    .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            )
    }
}

/// Carte qui regroupe des lignes de réglages.
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07)))
    }
}

struct SettingsSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
            .padding(.top, 8)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
    }
}

struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(NotchletStyle.accent)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
    }
}

/// Curseur avec sa valeur affichée dans une pastille.
struct SettingsSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            Slider(value: $value, in: range, step: step)
                .tint(NotchletStyle.accent)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// Choix illustré : une tuile par option, entourée quand elle est sélectionnée.
struct SettingsTilePicker<Option: Identifiable & Hashable, Preview: View>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String
    @ViewBuilder let preview: (Option) -> Preview

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(options) { option in
                let isSelected = option == selection
                Button {
                    selection = option
                } label: {
                    VStack(spacing: 6) {
                        preview(option)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 9).fill(Color.black.opacity(0.55)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(isSelected ? NotchletStyle.accent : Color.white.opacity(0.1),
                                            lineWidth: isSelected ? 2 : 1)
                            )
                        Text(label(option))
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// Aperçu d'une barre dans une tuile.
struct BarPreview: View {
    let colors: [Color]
    var glow = false

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.18)).frame(width: 56)
            Capsule()
                .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                .frame(width: 36)
                .shadow(color: glow ? .white : .clear, radius: 4)
        }
        .frame(height: 5)
    }
}
