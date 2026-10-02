import Foundation

/// Step-specific, prepared scenes. Playback timing never changes cooking timing.
nonisolated enum AuthoredPastaScene: String, CaseIterable, Sendable {
    case water = "heat-water"
    case zest = "zest-lemon"
    case boiling = "boil-pasta"
    case sauce = "lemon-sauce"
    case tossing = "toss-pasta"
    case serving = "serve-pasta"

    var movieName: String {
        switch self {
        case .water: "pasta-water"
        case .zest: "pasta-zest"
        case .boiling: "pasta-boil"
        case .sauce: "pasta-sauce"
        case .tossing: "pasta-toss"
        case .serving: "pasta-serve"
        }
    }

    var duration: Double {
        switch self {
        case .water, .boiling, .serving: 6
        case .zest, .sauce, .tossing: 8
        }
    }
}
