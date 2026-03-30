import SwiftUI

struct GameSelectionView: View {
    @StateObject private var controllerManager = GameControllerManager()
    @State private var selectedGame: Game? = nil
    @State private var showingGame = false

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 24)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(hex: "#1a0a3e"), Color(hex: "#0d1b3e")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerView
                        .padding(.top, 32)
                        .padding(.horizontal, 32)

                    // Controller status badge
                    controllerBadge
                        .padding(.top, 12)
                        .padding(.horizontal, 32)

                    // Game grid
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(Game.all) { game in
                                GameCard(game: game)
                                    .onTapGesture {
                                        selectedGame = game
                                        showingGame = true
                                    }
                            }
                            // "More coming soon" placeholder
                            ComingSoonCard()
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 32)
                    }
                }
            }
            .navigationDestination(isPresented: $showingGame) {
                if let game = selectedGame {
                    GamePlayerView(game: game, controllerManager: controllerManager)
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Math Games")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Pick a game and play with your controller")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
    }

    private var controllerBadge: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: controllerManager.isControllerConnected
                      ? "gamecontroller.fill" : "gamecontroller")
                    .foregroundStyle(controllerManager.isControllerConnected
                                     ? Color(hex: "#5CFF7A") : .white.opacity(0.4))

                Text(controllerManager.isControllerConnected
                     ? (controllerManager.connectedControllerName ?? "Controller connected")
                     : "No controller connected")
                    .font(.caption)
                    .foregroundStyle(controllerManager.isControllerConnected
                                     ? Color(hex: "#5CFF7A") : .white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.white.opacity(0.08), in: Capsule())
            Spacer()
        }
    }
}

// MARK: - Game Card

private struct GameCard: View {
    let game: Game
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            ZStack {
                Color(hex: game.accentColorHex)
                    .opacity(0.6)

                if let thumbURL = game.thumbnailURL, let url = URL(string: thumbURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(16)
                    } placeholder: {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .frame(height: 180)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16,
                                              topTrailingRadius: 16))

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(game.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(game.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)

                // Controller layout hint
                HStack(spacing: 6) {
                    ControlHintBadge(symbol: "arrow.left.arrow.right", label: "Move")
                    ControlHintBadge(symbol: "arrowshape.up.fill", label: "Jump")
                    ControlHintBadge(symbol: "bolt.fill", label: "Fire")
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(Color(hex: "#1e1340").opacity(0.95))
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 16,
                                              bottomTrailingRadius: 16))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: game.accentColorHex).opacity(isHovered ? 0.9 : 0.3),
                        lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color(hex: game.accentColorHex).opacity(0.3), radius: 12, y: 6)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Control Hint Badge

private struct ControlHintBadge: View {
    let symbol: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
            Text(label)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.5))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.white.opacity(0.08), in: Capsule())
    }
}

// MARK: - Coming Soon Card

private struct ComingSoonCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.2))

            Text("More games coming")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .foregroundStyle(.white.opacity(0.1))
        )
    }
}

// MARK: - Color init from hex

extension Color {
    init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        guard hexString.count == 6, let value = UInt64(hexString, radix: 16) else {
            self = .clear; return
        }
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8)  & 0xFF) / 255,
            blue:  Double( value        & 0xFF) / 255
        )
    }
}

#Preview {
    GameSelectionView()
}
