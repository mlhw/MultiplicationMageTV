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

    // MARK: Init

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

    // MARK: - Controller → JS Bridge

    private func wireControllerCallbacks() {
        controllerManager.onKeyDown = { [weak self] keyCode in
            self?.injectKeyEvent(keyCode: keyCode, type: "keydown")
        }
        controllerManager.onKeyUp = { [weak self] keyCode in
            self?.injectKeyEvent(keyCode: keyCode, type: "keyup")
        }
    }

    private func injectKeyEvent(keyCode: Int, type: String) {
        let keyString = keyCodeToKey(keyCode)
        let js = """
        (function() {
            var opts = {
                key: '\(keyString)',
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

    /// Maps common game keyCodes to their `key` string.
    private func keyCodeToKey(_ keyCode: Int) -> String {
        switch keyCode {
        case 37: return "ArrowLeft"
        case 38: return "ArrowUp"
        case 39: return "ArrowRight"
        case 40: return "ArrowDown"
        case 32: return " "
        case 90: return "z"
        case 88: return "x"
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
        case 90: return "KeyZ"
        case 88: return "KeyX"
        default: return ""
        }
    }
}

// MARK: - WKNavigationDelegate

extension GameWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        UIView.animate(withDuration: 0.4, delay: 0.5) {
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
