import CoreGraphics

/// Reconnaît un balayage à deux doigts. Un seul balayage est signalé par geste, même si
/// les doigts continuent de bouger.
struct SwipeDetector {
    enum Swipe { case up, down, left, right }

    /// Distance à parcourir, en points, pour éviter les déclenchements accidentels.
    private let threshold: CGFloat = 30
    private var x: CGFloat = 0
    private var y: CGFloat = 0
    private var hasFired = false

    /// `fingerX` est positif vers la droite, `fingerY` vers le bas.
    mutating func update(fingerX: CGFloat, fingerY: CGFloat) -> Swipe? {
        guard !hasFired else { return nil }
        x += fingerX
        y += fingerY
        guard max(abs(x), abs(y)) >= threshold else { return nil }
        hasFired = true
        if abs(x) > abs(y) { return x > 0 ? .right : .left }
        return y > 0 ? .down : .up
    }
}
