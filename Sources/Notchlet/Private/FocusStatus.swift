import Foundation

struct FocusMode: Equatable {
    let identifier: String
    let name: String
    let symbol: String
}

/// Lecture du mode de concentration actif.
///
/// NON DOCUMENTÉ : ces fichiers internes de macOS peuvent changer sans préavis. Un format
/// inconnu donne simplement « aucun mode ». Une concentration programmée peut ne pas y figurer.
/// Lire ce dossier demande l'Accès complet au disque.
enum FocusStatus {
    enum ReadResult: Equatable {
        case denied
        case mode(FocusMode?)
    }

    static func read() -> ReadResult {
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/DoNotDisturb/DB")
        do {
            let assertions = try Data(contentsOf: folder.appendingPathComponent("Assertions.json"))
            let configurations = try? Data(contentsOf: folder.appendingPathComponent("ModeConfigurations.json"))
            return .mode(parse(assertions: assertions, configurations: configurations))
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return .mode(nil)
        } catch {
            return .denied
        }
    }

    /// Seuls l'identifiant, le nom et le symbole du mode sont extraits.
    static func parse(assertions: Data, configurations: Data?) -> FocusMode? {
        guard let root = try? JSONSerialization.jsonObject(with: assertions) as? [String: Any],
              let blocks = root["data"] as? [[String: Any]],
              let records = blocks.first?["storeAssertionRecords"] as? [[String: Any]],
              let details = records.last?["assertionDetails"] as? [String: Any],
              let identifier = details["assertionDetailsModeIdentifier"] as? String
        else { return nil }

        var name: String?
        var symbol: String?
        if let configurations,
           let root = try? JSONSerialization.jsonObject(with: configurations) as? [String: Any],
           let blocks = root["data"] as? [[String: Any]],
           let modes = blocks.first?["modeConfigurations"] as? [String: Any],
           let entry = modes[identifier] as? [String: Any],
           let mode = entry["mode"] as? [String: Any] {
            name = mode["name"] as? String
            symbol = mode["symbolImageName"] as? String
        }
        return FocusMode(identifier: identifier, name: name ?? "Concentration", symbol: symbol ?? "moon.fill")
    }
}
