import Foundation

/// Décide quand ouvrir l'île : la souris doit rester dans la zone pendant tout le délai.
struct HoverTimer {
    private var enteredAt: Date?

    /// Renvoie `true` quand le délai est écoulé. Sortir de la zone remet le compteur à zéro.
    mutating func update(isInside: Bool, now: Date, delay: TimeInterval) -> Bool {
        guard isInside else {
            enteredAt = nil
            return false
        }
        let start = enteredAt ?? now
        guard now.timeIntervalSince(start) >= delay else {
            enteredAt = start
            return false
        }
        enteredAt = nil
        return true
    }
}
