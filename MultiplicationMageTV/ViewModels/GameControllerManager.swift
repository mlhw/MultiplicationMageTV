import GameController
import Combine

/// Observes connected game controllers and emits game input events.
final class GameControllerManager: ObservableObject {

    // MARK: - Published state
    @Published private(set) var isControllerConnected: Bool = false
    @Published private(set) var connectedControllerName: String? = nil

    // MARK: - Callbacks (wired by the active GameWebViewController)
    /// Keyboard injection: left (37) / right (39) / up (38)
    var onKeyDown: ((_ keyCode: Int) -> Void)?
    var onKeyUp: ((_ keyCode: Int) -> Void)?

    /// Virtual gamepad injection: standard button index + pressed state
    var onGamepadButton: ((_ buttonIndex: Int, _ pressed: Bool) -> Void)?
    /// Virtual gamepad axis: axisIndex (0=leftX, 1=leftY), value (-1…1)
    var onGamepadAxis: ((_ axisIndex: Int, _ value: Float) -> Void)?

    // MARK: - Standard Gamepad button layout
    // https://w3c.github.io/gamepad/#remapping
    // 0=A/Cross  1=B/Circle  2=X/Square  3=Y/Triangle
    // 12=DpadUp  13=DpadDown  14=DpadLeft  15=DpadRight

    /// Which gamepad button index triggers fire/attack.
    /// The game's Construct event sheet most likely uses button 1 (B/Circle),
    /// but try 0 if 1 doesn't work — change here only.
    private let fireButtonIndex = 1

    // MARK: - Private
    private var controller: GCController?
    private var cancellables = Set<AnyCancellable>()
    private var heldKeys: Set<Int> = []
    private let deadZone: Float = 0.4

    init() {
        observeControllerNotifications()
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
                if let c = note.object as? GCController { self?.connect(c) }
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .GCControllerDidDisconnect)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.disconnect() }
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
        guard let pad = c.extendedGamepad else { return }

        // ── D-pad → keyboard ArrowLeft / ArrowRight / ArrowUp ─────────────────
        pad.dpad.left.valueChangedHandler  = { [weak self] _, _, pressed in
            self?.handleKey(keyCode: 37, pressed: pressed)
            self?.onGamepadButton?(14, pressed) // also update virtual pad axis
        }
        pad.dpad.right.valueChangedHandler = { [weak self] _, _, pressed in
            self?.handleKey(keyCode: 39, pressed: pressed)
            self?.onGamepadButton?(15, pressed)
        }
        pad.dpad.up.valueChangedHandler    = { [weak self] _, _, pressed in
            self?.handleKey(keyCode: 38, pressed: pressed)
            self?.onGamepadButton?(12, pressed)
        }
        pad.dpad.down.valueChangedHandler  = { [weak self] _, _, pressed in
            self?.handleKey(keyCode: 40, pressed: pressed)
            self?.onGamepadButton?(13, pressed)
        }

        // ── Left thumbstick → keyboard + virtual gamepad axes ─────────────────
        pad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            guard let self else { return }

            self.handleKey(keyCode: 37, pressed: xValue < -self.deadZone)
            self.handleKey(keyCode: 39, pressed: xValue >  self.deadZone)
            self.handleKey(keyCode: 38, pressed: yValue >  self.deadZone)

            // Push axis values to virtual gamepad (normalized -1…1)
            DispatchQueue.main.async {
                self.onGamepadAxis?(0, xValue)
                self.onGamepadAxis?(1, -yValue) // invert Y so up = negative
            }
        }

        // ── A / Cross → Jump (keyboard ArrowUp + gamepad button 0) ───────────
        pad.buttonA.valueChangedHandler = { [weak self] _, _, pressed in
            self?.handleKey(keyCode: 38, pressed: pressed)
            self?.onGamepadButton?(0, pressed)
        }

        // ── B / Circle → Fire (virtual gamepad only — no keyboard binding) ────
        pad.buttonB.valueChangedHandler = { [weak self] _, _, pressed in
            guard let self else { return }
            DispatchQueue.main.async {
                self.onGamepadButton?(self.fireButtonIndex, pressed)
            }
        }

        // ── X / Square → also Fire (fallback) ────────────────────────────────
        pad.buttonX.valueChangedHandler = { [weak self] _, _, pressed in
            guard let self else { return }
            DispatchQueue.main.async {
                self.onGamepadButton?(self.fireButtonIndex, pressed)
            }
        }

        // ── Y / Triangle → button 3 (secondary action if any) ────────────────
        pad.buttonY.valueChangedHandler = { [weak self] _, _, pressed in
            self?.onGamepadButton?(3, pressed)
        }
    }

    // MARK: - Key state machine

    private func handleKey(keyCode: Int, pressed: Bool) {
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
