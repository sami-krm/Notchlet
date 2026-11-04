import AppKit

/// Luminosité de l'écran intégré.
///
/// API PRIVÉE : DisplayServices n'est pas documenté et une mise à jour de macOS peut le casser
/// ou le retirer. On le charge à l'exécution avec `dlopen` : s'il manque, toutes les fonctions
/// renvoient `nil` et les touches de luminosité restent gérées par macOS.
enum DisplayBrightness {
    private typealias GetFunction = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFunction = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let library = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY
    )
    private static let getFunction: GetFunction? = dlsym(library, "DisplayServicesGetBrightness")
        .map { unsafeBitCast($0, to: GetFunction.self) }
    private static let setFunction: SetFunction? = dlsym(library, "DisplayServicesSetBrightness")
        .map { unsafeBitCast($0, to: SetFunction.self) }

    private static var builtInDisplay: CGDirectDisplayID? {
        NSScreen.screens
            .map { CGDirectDisplayID($0.displayID) }
            .first { CGDisplayIsBuiltin($0) != 0 }
    }

    /// Luminosité de 0 à 1, ou `nil` si elle n'est pas accessible (API absente, écran fermé).
    static var level: Float? {
        guard setFunction != nil, let getFunction, let display = builtInDisplay else { return nil }
        var value: Float = 0
        return getFunction(display, &value) == 0 ? value : nil
    }

    static func setLevel(_ value: Float) {
        guard let setFunction, let display = builtInDisplay else { return }
        _ = setFunction(display, value)
    }
}
