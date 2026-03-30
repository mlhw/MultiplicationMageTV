import GameController
import Combine

/// Observes connected game controllers and emits game input events.
final class GameControllerManager: ObservableObject {

    // MARK: - Published state
    @Published private(set) var isControllerConnected: Bool = false
    @Published private(set) var connectedControllerName: String? = nil

    // MARK: - Input callbacks (set by the active GameWebViewController)
    var onKeyDown: ((_ keyCode: Int) -> Void)?
    var onKeyUp: ((_ keyCode: Int) -> Void)?

    // MARK: - Private
    private var controller: GCController?
    private var cancellables = Set<AnyCancellable>()

    /// Keys currently held down (to avoid repeat events on analog stick drift).
    private var heldKeys: Set<Int> = []

    // Analog stick dead zone
    private let deadZone: Float = 0.4

    init() {
        observeControllerNotifications()
        // Pick up already-connected controllers
        if let existing = GCController.controllers().first {
            connect(existing)
        }
    }

    // MARK: - Notifications

    private func observeControllerNotifications() {
        NotificationCenter.default
            .publisher(for: .GCControllerDidConnect)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                if let c = note.object as? GCController {
                    self?.connect(c)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .GCControllerDidDisconnect)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.disconnect()
            }
            .store(in: &cancellables)

        GCController.startWirelessControllerDiscovery()
    }

    // MARK: - Connect / Disconnect

    private func connect(_ c: GCController) {
        controller = c
        connectedControllerName = c.vendorName
        isControllerConnected = true
        bindInputs(c)
    }

    private func disconnect() {
        controller = nil
        connectedControllerName = nil
        isControllerConnected = false
        heldKeys.removeAll()
    }

    // MARK: - Input binding

    private func bindInputs(_ c: GCController) {
        guard let pad = c.extendedGamepad ?? c.microGamepad.map({ _ in c.extendedGamepad })
                         ?? { c.extendedGamepad }()
        else { return }

        // ── D-pad ──────────────────────────────────────────────────────────────
        pad.dpad.left.valueChangedHandler  = { [weak self] _, _, pressed in self?.handle(keyCode: 37, pressed: pressed) }
        pad.dpad.right.valueChangedHandler = { [weak self] _, _, pressed in self?.handle(keyCode: 39, pressed: pressed) }
        pad.dpad.up.valueChangedHandler    = { [weak self] _, _, pressed in self?.handle(keyCode: 38, pressed: pressed) }
        pad.dpad.down.valueChangedHandler  = { [weak self] _, _, pressed in self?.handle(keyCode: 40, pressed: pressed) }

        // ── Left thumbstick ────────────────────────────────────────────────────
        pad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            guard let self else { return }
            self.handle(keyCode: 37, pressed: xValue < -self.deadZone)
            self.handle(keyCode: 39, pressed: xValue >  self.deadZone)
            self.handle(keyCode: 38, pressed: yValue >  self.deadZone)
            self.handle(keyCode: 40, pressed: yValue < -self.deadZone)
        }

        // ── Face buttons ───────────────────────────────────────────────────────
        // A / Cross  → Jump (ArrowUp / Space)
        pad.buttonA.valueChangedHandler = { [weak self] _, _, pressed in self?.handle(keyCode: 38, pressed: pressed) }
        // B / Circle → Fire (Space)
        pad.buttonB.valueChangedHandler = { [weak self] _, _, pressed in self?.handle(keyCode: 32, pressed: pressed) }
        // X / Square → also Fire (fallback)
        pad.buttonX.valueChangedHandler = { [weak self] _, _, pressed in self?.handle(keyCode: 32, pressed: pressed) }
        // Y / Triangle → unused for now
    }

    // MARK: - Key state machine

    private func handle(keyCode: Int, pressed: Bool) {
        if pressed {
            guard !heldKeys.contains(keyCode) else { return }
            heldKeys.insert(keyCode)
            DispatchQueue.main.async { self.onKeyDown?(keyCode) }
        } else {
            guard heldKeys.contains(keyCode) else { return }
            heldKeys.remove(keyCode)
            DispatchQueue.main.async { self.onKeyUp?(keyCode) }
        }
    }
}
