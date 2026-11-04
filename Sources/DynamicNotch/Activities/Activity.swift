import SwiftUI

/// Ce que l'île peut afficher quand elle est fermée (musique, HUD, alerte…).
/// Ajouter une fonctionnalité revient à créer un nouveau type conforme à ce protocole.
@MainActor
protocol Activity {
    /// Identifie le genre d'activité : un changement d'`id` déclenche l'animation de l'île.
    var id: String { get }
    /// Temps d'affichage quand l'activité passe par la file des activités brèves.
    var displayDuration: TimeInterval { get }
    /// Largeur ajoutée de chaque côté de l'encoche quand l'activité est affichée.
    var closedWing: CGFloat { get }
    /// `AnyView` efface le type exact de la vue : chaque activité peut ainsi renvoyer
    /// une vue différente tout en respectant le même protocole.
    var closedView: AnyView { get }
}

extension Activity {
    var displayDuration: TimeInterval { 3 }
    var closedWing: CGFloat { 34 }
}
