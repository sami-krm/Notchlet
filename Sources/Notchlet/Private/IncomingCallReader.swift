import AppKit
import ApplicationServices

struct IncomingCall: Equatable {
    let caller: String
}

/// Reconnaît une bannière d'appel d'après ses textes et ses boutons.
enum IncomingCallDetector {
    private static let acceptTitles: Set<String> = ["accepter", "répondre", "accept", "answer"]
    private static let declineTitles: Set<String> = ["refuser", "decline"]

    static func isAccept(_ title: String) -> Bool { acceptTitles.contains(title.lowercased()) }
    static func isDecline(_ title: String) -> Bool { declineTitles.contains(title.lowercased()) }

    /// Une notification ordinaire n'a pas ces deux boutons à la fois : on ignore tout le reste.
    static func detect(texts: [String], buttons: [String]) -> IncomingCall? {
        guard buttons.contains(where: isAccept), buttons.contains(where: isDecline) else { return nil }
        return IncomingCall(caller: texts.first { !$0.isEmpty } ?? "Appel entrant")
    }
}

/// Lit les bannières de notification à l'écran.
///
/// NON DOCUMENTÉ : s'appuie sur la structure d'accessibilité du Centre de notifications, qui peut
/// changer sans préavis. Permission : Accessibilité. Seule une bannière avec des boutons
/// d'appel est retenue, et rien n'est enregistré.
@MainActor
final class IncomingCallReader {
    private var acceptButton: AXUIElement?
    private var declineButton: AXUIElement?

    func read() -> IncomingCall? {
        acceptButton = nil
        declineButton = nil
        guard let process = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first
        else { return nil }

        let app = AXUIElementCreateApplication(process.processIdentifier)
        for window in Self.children(of: app, attribute: kAXWindowsAttribute) {
            var texts: [String] = []
            var buttons: [(title: String, element: AXUIElement)] = []
            Self.collect(window, depth: 0, texts: &texts, buttons: &buttons)
            if let call = IncomingCallDetector.detect(texts: texts, buttons: buttons.map(\.title)) {
                acceptButton = buttons.first { IncomingCallDetector.isAccept($0.title) }?.element
                declineButton = buttons.first { IncomingCallDetector.isDecline($0.title) }?.element
                return call
            }
        }
        return nil
    }

    func accept() { press(acceptButton) }
    func decline() { press(declineButton) }

    private func press(_ element: AXUIElement?) {
        guard let element else { return }
        AXUIElementPerformAction(element, kAXPressAction as CFString)
    }

    /// La profondeur est limitée : ces arbres restent petits, sauf format inattendu.
    private static func collect(_ element: AXUIElement, depth: Int, texts: inout [String],
                                buttons: inout [(title: String, element: AXUIElement)]) {
        guard depth < 12 else { return }
        let role = string(of: element, attribute: kAXRoleAttribute)
        if role == kAXButtonRole {
            let title = string(of: element, attribute: kAXTitleAttribute)
                ?? string(of: element, attribute: kAXDescriptionAttribute)
            if let title { buttons.append((title, element)) }
        } else if role == kAXStaticTextRole, let value = string(of: element, attribute: kAXValueAttribute) {
            texts.append(value)
        }
        for child in children(of: element, attribute: kAXChildrenAttribute) {
            collect(child, depth: depth + 1, texts: &texts, buttons: &buttons)
        }
    }

    private static func string(of element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func children(of element: AXUIElement, attribute: String) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }
}
