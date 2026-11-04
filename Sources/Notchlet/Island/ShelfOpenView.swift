import SwiftUI
import UniformTypeIdentifiers

/// Île ouverte : l'étagère. On y dépose des fichiers, puis on les ouvre ou les fait glisser ailleurs.
struct ShelfOpenView: View {
    @ObservedObject var shelf: ShelfManager
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    @State private var isTargeted = false

    var body: some View {
        Group {
            if shelf.files.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Dépose des fichiers ici")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(shelf.files, id: \.self) { url in
                            ShelfItem(shelf: shelf, url: url)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isTargeted ? 0.12 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isTargeted ? NotchletStyle.accent : Color.white.opacity(0.12), lineWidth: isTargeted ? 2 : 1)
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in shelf.add(url) }
                }
            }
            return !providers.isEmpty
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, 16)
    }
}

private struct ShelfItem: View {
    @ObservedObject var shelf: ShelfManager
    let url: URL
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 3) {
            Image(nsImage: shelf.icon(for: url))
                .resizable()
                .frame(width: 44, height: 44)
            Text(url.lastPathComponent)
                .font(.system(size: 10))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 64)
        }
        .padding(6)
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button {
                    shelf.remove(url)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white, .black.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retirer \(url.lastPathComponent) de l'étagère")
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) { shelf.open(url) }
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
    }
}
