import SwiftUI
import WebKit

// MARK: - SwiftUI wrapper

struct GameWebView: UIViewControllerRepresentable {
    let game: Game
    let controllerManager: GameControllerManager

    func makeUIViewController(context: Context) -> GameWebViewController {
        GameWebViewController(game: game, controllerManager: controllerManager)
    }

    func updateUIViewController(_ vc: GameWebViewController, context: Context) {}
}

// MARK: - UIViewController

final class GameWebViewController: UIViewController {

    // MARK: Dependencies
    private let game: Game
    private let controllerManager: GameControllerManager

    // MARK: UI
    private var webView: WKWebView!
    private var loadingView: UIView!
    private var loadingLabel: UILabel!

    init(game: Game, controllerManager: GameControllerManager) {
        self.game = game
        self.controllerManager = controllerManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupWebView()
        setupLoadingOverlay()
        loadGame()
        wireControllerCallbacks()
    }

    // MARK: - WebView Setup

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isTextInteractionEnabled = false

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .black
        view.addSubview(webView)
    }

    private func setupLoadingOverlay() {
        loadingView = UIView(frame: view.bounds)
        loadingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        loadingView.backgroundColor = UIColor(hex: game.accentColorHex) ?? .black

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false

        loadingLabel = UILabel()
        loadingLabel.text = game.title
        loadingLabel.textColor = .white
        loadingLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [spinner, loadingLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        loadingView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor)
        ])
        view.addSubview(loadingView)
    }

    private func loadGame() {
        guard let url = URL(string: game.url) else { return }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        webView.load(request)
    }

    // MARK: - Controller → Bridge

    private func wireControllerCallbacks() {
        controllerManager.onKeyDown = { [weak self] keyCode in
            self?.injectKeyEvent(keyCode: keyCode, type: "keydown")
        }
        controllerManager.onKeyUp = { [weak self] keyCode in
            self?.injectKeyEvent(keyCode: keyCode, type: "keyup")
        }
        controllerManager.onGamepadButton = { [weak self] buttonIndex, pressed in
            self?.setVirtualGamepadButton(buttonIndex, pressed: pressed)
        }
        controllerManager.onGamepadAxis = { [weak self] axisIndex, value in
            self?.setVirtualGamepadAxis(axisIndex, value: value)
        }
    }

    // MARK: - Keyboard injection (left / right / jump)

    private func injectKeyEvent(keyCode: Int, type: String) {
        let js = """
        (function() {
            var opts = {
                key: '\(keyCodeToKey(keyCode))',
                keyCode: \(keyCode),
                which: \(keyCode),
                code: '\(keyCodeToCode(keyCode))',
                bubbles: true,
                cancelable: true
            };
            document.dispatchEvent(new KeyboardEvent('\(type)', opts));
            window.dispatchEvent(new KeyboardEvent('\(type)', opts));
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - Virtual Gamepad injection (fire / attack)

    /// Injects a virtual gamepad into navigator.getGamepads() so the game's
    /// native Construct Gamepad plugin picks it up on its next tick poll.
    private func injectVirtualGamepad() {
        let js = """
        (function() {
            if (window.__virtualGamepadInstalled) return;
            window.__virtualGamepadInstalled = true;

            const NUM_BUTTONS = 17;
            const NUM_AXES = 4;

            // Mutable state arrays
            window.__vgpButtons = Array.from({length: NUM_BUTTONS}, () => ({
                pressed: false, touched: false, value: 0.0
            }));
            window.__vgpAxes = new Array(NUM_AXES).fill(0.0);

            const virtualGamepad = {
                id: "Virtual Controller",
                index: 0,
                connected: true,
                timestamp: performance.now(),
                mapping: "standard",
                get buttons() { return window.__vgpButtons; },
                get axes() { return window.__vgpAxes; }
            };

            // Override getGamepads - return virtual as index 0 if no real pad present
            const _origGetGamepads = navigator.getGamepads.bind(navigator);
            Object.defineProperty(navigator, 'getGamepads', {
                configurable: true,
                value: function() {
                    const real = _origGetGamepads();
                    const realConnected = Array.from(real).filter(g => g && g.connected);
                    if (realConnected.length > 0) return real;
                    return [virtualGamepad];
                }
            });

            // Tell the game a gamepad connected
            setTimeout(function() {
                window.dispatchEvent(new GamepadEvent('gamepadconnected', { gamepad: virtualGamepad }));
            }, 300);

            // API for Swift to update state
            window.__setVGPButton = function(index, pressed) {
                if (index < 0 || index >= NUM_BUTTONS) return;
                window.__vgpButtons[index] = { pressed: pressed, touched: pressed, value: pressed ? 1.0 : 0.0 };
                virtualGamepad.timestamp = performance.now();
            };

            window.__setVGPAxis = function(index, value) {
                if (index < 0 || index >= NUM_AXES) return;
                window.__vgpAxes[index] = value;
                virtualGamepad.timestamp = performance.now();
            };

            console.log('[MathGames] Virtual gamepad installed');
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func setVirtualGamepadButton(_ index: Int, pressed: Bool) {
        let js = "if(window.__setVGPButton) window.__setVGPButton(\(index), \(pressed ? "true" : "false"));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func setVirtualGamepadAxis(_ index: Int, value: Float) {
        let js = "if(window.__setVGPAxis) window.__setVGPAxis(\(index), \(value));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - Key name helpers

    private func keyCodeToKey(_ keyCode: Int) -> String {
        switch keyCode {
        case 37: return "ArrowLeft"
        case 38: return "ArrowUp"
        case 39: return "ArrowRight"
        case 40: return "ArrowDown"
        case 32: return " "
        default: return ""
        }
    }

    private func keyCodeToCode(_ keyCode: Int) -> String {
        switch keyCode {
        case 37: return "ArrowLeft"
        case 38: return "ArrowUp"
        case 39: return "ArrowRight"
        case 40: return "ArrowDown"
        case 32: return "Space"
        default: return ""
        }
    }
}

// MARK: - WKNavigationDelegate

extension GameWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Install virtual gamepad after page loads
        injectVirtualGamepad()

        UIView.animate(withDuration: 0.4, delay: 0.8) {
            self.loadingView.alpha = 0
        } completion: { _ in
            self.loadingView.isHidden = true
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadingLabel.text = "Failed to load game"
    }
}

// MARK: - UIColor hex helper

private extension UIColor {
    convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        guard hexString.count == 6,
              let value = UInt64(hexString, radix: 16) else { return nil }
        self.init(
            red:   CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8)  & 0xFF) / 255,
            blue:  CGFloat( value        & 0xFF) / 255,
            alpha: 1
        )
    }
}
