import SwiftUI

/// Full-screen game player with a floating HUD.
struct GamePlayerView: View {
    let game: Game
    @ObservedObject var controllerManager: GameControllerManager

    @Environment(\.dismiss) private var dismiss
    @State private var hudVisible = true
    @State private var hudTimer: Timer?

    var body: some View {
        ZStack(alignment: .top) {
            // Full-screen web game
            GameWebView(game: game, controllerManager: controllerManager)
                .ignoresSafeArea()
                .onTapGesture {
                    showHUD()
                }

            // Floating HUD (fades out after a few seconds)
            if hudVisible {
                HUDBar(
                    gameName: game.title,
                    isControllerConnected: controllerManager.isControllerConnected,
                    controllerName: controllerManager.connectedControllerName,
                    onDismiss: { dismiss() }
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onAppear { scheduleHUDHide() }
    }

    // MARK: - HUD visibility

    private func showHUD() {
        withAnimation(.spring(duration: 0.3)) { hudVisible = true }
        scheduleHUDHide()
    }

    private func scheduleHUDHide() {
        hudTimer?.invalidate()
        hudTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.5)) { hudVisible = false }
        }
    }
}

// MARK: - HUD Bar

private struct HUDBar: View {
    let gameName: String
    let isControllerConnected: Bool
    let controllerName: String?
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                    Text("Games")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            // Game title
            Text(gameName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            // Controller status
            HStack(spacing: 6) {
                Image(systemName: isControllerConnected ? "gamecontroller.fill" : "gamecontroller")
                    .font(.system(size: 12))
                Text(isControllerConnected
                     ? (controllerName ?? "Connected")
                     : "No controller")
                    .font(.system(size: 12))
            }
            .foregroundStyle(isControllerConnected ? Color(hex: "#5CFF7A") : .white.opacity(0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }
}
