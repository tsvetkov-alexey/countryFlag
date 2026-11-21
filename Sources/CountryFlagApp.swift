import AppKit
import Network

@main
enum CountryFlagApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = MenuBarController()

        application.setActivationPolicy(.accessory)
        application.delegate = delegate

        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

@MainActor
private final class MenuBarController: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: 32)
    private let countryItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let addressItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let globe = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)

    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "CountryFlag.network")

    private var timer: Timer?
    private var lookupTask: Task<Void, Never>?
    private var hasConnection: Bool?
    private var location: IPLocation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenu()
        showStatus("Определяем страну…")

        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status != .unsatisfied

            DispatchQueue.main.async {
                self?.networkChanged(isConnected: isConnected)
            }
        }

        networkMonitor.start(queue: networkQueue)

        let timer = Timer(
            timeInterval: 30,
            target: self,
            selector: #selector(periodicRefresh),
            userInfo: nil,
            repeats: true
        )

        timer.tolerance = 3
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        lookupTask?.cancel()
        networkMonitor.cancel()
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        countryItem.isEnabled = false
        menu.addItem(countryItem)

        addressItem.action = #selector(copyAddress)
        addressItem.target = self
        menu.addItem(addressItem)

        menu.addItem(.separator())

        let refreshItem = NSMenuItem(title: "Обновить", action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let quitItem = NSMenuItem(
            title: "Выйти из Country Flag",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)

        statusItem.button?.font = .systemFont(ofSize: 16)
        statusItem.menu = menu
    }

    private func networkChanged(isConnected: Bool) {
        hasConnection = isConnected
        lookupTask?.cancel()
        lookupTask = nil

        guard isConnected else {
            showStatus("Нет подключения к сети")

            return
        }

        showStatus("Определяем страну…")
        refresh()
    }

    @objc private func periodicRefresh() {
        refresh()
    }

    @objc private func refreshNow() {
        guard hasConnection != false else {
            return
        }

        lookupTask?.cancel()
        lookupTask = nil

        if location == nil {
            showStatus("Определяем страну…")
        }

        refresh()
    }

    private func refresh() {
        guard hasConnection != false, lookupTask == nil else {
            return
        }

        lookupTask = Task { [weak self] in
            let result = try? await IPLookup.current()

            guard let self, !Task.isCancelled else {
                return
            }

            self.lookupTask = nil

            if let result {
                self.showLocation(result)
            } else {
                self.showStatus("Не удалось определить страну")
            }
        }
    }

    private func showStatus(_ message: String) {
        location = nil
        countryItem.title = message
        addressItem.isHidden = true

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.title = ""
            button.image = globe
            button.toolTip = message
            button.setAccessibilityLabel(message)
        }
    }

    private func showLocation(_ location: IPLocation) {
        self.location = location
        countryItem.title = location.countryName
        addressItem.title = "Скопировать IP · \(location.address)"
        addressItem.isHidden = false

        if let button = statusItem.button {
            button.imagePosition = .noImage
            button.image = nil
            button.title = location.flag
            button.toolTip = "\(location.countryName) · \(location.address)"
            button.setAccessibilityLabel("Страна IP · \(location.countryName)")
        }
    }

    @objc private func copyAddress() {
        guard let location else {
            return
        }

        let pasteboard = NSPasteboard.general

        pasteboard.clearContents()
        pasteboard.setString(location.address, forType: .string)
    }
}
