import AppKit
import ServiceManagement
import HangulInputCore

protocol MenuBarControllerDelegate: AnyObject {
    func menuDidToggle(enabled: Bool)
    func menuDidChangeMode(_ mode: CorrectionMode)
    func menuDidRequestUndo()
    func menuDidRequestPermissions()
    func menuDidToggleLaunchAtLogin()
    func menuDidApplySuggestion()
}

final class MenuBarController: NSObject, NSMenuDelegate {
    private enum DefaultsKey {
        static let detectionEnabled = "detectionEnabled"
        static let correctionMode = "correctionMode"
    }

    weak var delegate: MenuBarControllerDelegate?
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private(set) var enabled = UserDefaults.standard.bool(forKey: DefaultsKey.detectionEnabled)
    private(set) var mode = CorrectionMode(
        rawValue: UserDefaults.standard.string(forKey: DefaultsKey.correctionMode) ?? ""
    ) ?? .suggestion
    var permissionText = "권한 확인 중"
    var suggestion: CorrectionDecision?

    override init() {
        super.init()
        item.button?.title = "한↔영"
        let menu = NSMenu(); menu.delegate = self; item.menu = menu
        rebuild(menu)
    }

    func refresh() { if let menu = item.menu { rebuild(menu) } }
    func menuWillOpen(_ menu: NSMenu) { rebuild(menu) }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()
        add(menu, enabled ? "자동 감지 끄기" : "자동 감지 켜기", #selector(toggleEnabled))
        let modeItem = NSMenuItem(title: "동작 모드", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let suggestionItem = NSMenuItem(title: "제안 모드", action: #selector(selectSuggestion), keyEquivalent: "")
        suggestionItem.target = self; suggestionItem.state = mode == .suggestion ? .on : .off
        let automaticItem = NSMenuItem(title: "자동수정 모드", action: #selector(selectAutomatic), keyEquivalent: "")
        automaticItem.target = self; automaticItem.state = mode == .automatic ? .on : .off
        submenu.addItem(suggestionItem); submenu.addItem(automaticItem); modeItem.submenu = submenu; menu.addItem(modeItem)
        menu.addItem(.separator())
        let permission = NSMenuItem(title: "권한: \(permissionText)", action: #selector(requestPermissions), keyEquivalent: "")
        permission.target = self; menu.addItem(permission)
        if let suggestion {
            add(menu, "제안 적용: \(suggestion.replacement)", #selector(applySuggestion))
        }
        add(menu, "최근 변환 되돌리기 (⌘⌥Z)", #selector(undo))
        add(menu, "로그인 시 실행 설정", #selector(toggleLaunchAtLogin))
        menu.addItem(.separator())
        add(menu, "종료", #selector(quit), key: "q")
    }

    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "") {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key); menuItem.target = self; menu.addItem(menuItem)
    }

    func setEnabled(_ value: Bool, persist: Bool = true) {
        enabled = value
        if persist { UserDefaults.standard.set(value, forKey: DefaultsKey.detectionEnabled) }
        refresh()
    }

    @objc private func toggleEnabled() {
        setEnabled(!enabled)
        delegate?.menuDidToggle(enabled: enabled)
    }
    @objc private func selectSuggestion() {
        mode = .suggestion
        UserDefaults.standard.set(mode.rawValue, forKey: DefaultsKey.correctionMode)
        delegate?.menuDidChangeMode(mode)
        refresh()
    }
    @objc private func selectAutomatic() {
        mode = .automatic
        UserDefaults.standard.set(mode.rawValue, forKey: DefaultsKey.correctionMode)
        delegate?.menuDidChangeMode(mode)
        refresh()
    }
    @objc private func requestPermissions() { delegate?.menuDidRequestPermissions() }
    @objc private func undo() { delegate?.menuDidRequestUndo() }
    @objc private func toggleLaunchAtLogin() { delegate?.menuDidToggleLaunchAtLogin() }
    @objc private func applySuggestion() { delegate?.menuDidApplySuggestion() }
    @objc private func quit() { NSApp.terminate(nil) }
}
