import Foundation

/// A web game that can be loaded in the GameWebView.
struct Game: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let url: String
    let thumbnailURL: String?
    let accentColorHex: String
    let controlMap: ControlMap

    /// Maps physical controller buttons to keyboard keyCodes injected into the WebView.
    struct ControlMap: Hashable {
        let left: Int        // keyCode
        let right: Int
        let jump: Int
        let fire: Int?       // nil = fire not used / touch-only fallback

        static let arrowKeys = ControlMap(
            left: 37,   // ArrowLeft
            right: 39,  // ArrowRight
            jump: 38,   // ArrowUp
            fire: 32    // Space
        )
    }
}

// MARK: - Game Library

extension Game {
    static let all: [Game] = [
        multiplicationMage
    ]

    static let multiplicationMage = Game(
        id: "multiplication-mage",
        title: "Multiplication Mage",
        subtitle: "Master the times tables with magic & adventure",
        url: "https://www.tafeldiploma.nl/gf/mage/dist/0.27d/?l=1",
        thumbnailURL: "https://cdn-t-3.bvkstatic.com/sv/static/images/games/mage-thumb.png",
        accentColorHex: "#4A2C8F",
        controlMap: .arrowKeys
    )
}
