import AppKit
import ServiceManagement
import HangulInputCore

final class AppDelegate: NSObject, NSApplicationDelegate, MenuBarControllerDelegate, KeyboardEventMonitorDelegate {
    private let permissions = PermissionManager()
    private let inputSource = InputSourceMonitor()
    private let history = CorrectionHistory()
    private lazy var replacement = TextReplacementService(history: history)
    private let compatibilityReplacement = CompatibilityReplacementService()
    private let monitor = KeyboardEventMonitor()
    private let engine = CorrectionEngine()
    private let lexicon = SystemLexicon()
    private let menu = MenuBarController()
    private let registrationService = RegistrationService()
    private var registrationWindow: RegistrationWindowController?
    private var pendingSuggestion: (CorrectionDecision, String)?
    private let debug = ProcessInfo.processInfo.environment["HIF_DEBUG"] == "1"

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu.delegate = self; monitor.delegate = self
        updatePermissionStatus()
        guard RegistrationConfiguration.isRequired, !registrationService.isCompleted else {
            startMonitoringIfEnabled(); return
        }
        registrationWindow = RegistrationWindowController(service: registrationService) { [weak self] accepted in
            guard let self else { return }
            self.registrationWindow = nil
            if accepted { self.startMonitoringIfEnabled() }
            else { NSApp.terminate(nil) }
        }
        registrationWindow?.present()
    }

    private func startMonitoringIfEnabled() {
        if menu.enabled {
            let status = permissions.currentStatus()
            if !status.canOperate || !monitor.start() {
                menu.setEnabled(false)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) { monitor.stop() }

    func menuDidToggle(enabled: Bool) {
        guard enabled else { monitor.stop(); return }
        guard !RegistrationConfiguration.isRequired || registrationService.isCompleted else {
            menu.setEnabled(false)
            registrationWindow?.present()
            return
        }
        let status = permissions.currentStatus()
        guard status.canOperate, monitor.start() else {
            menu.setEnabled(false)
            showPermissionAlert(status)
            return
        }
    }
    func menuDidChangeMode(_ mode: CorrectionMode) { pendingSuggestion = nil; menu.suggestion = nil }
    func menuDidRequestUndo() { _ = replacement.undoLast() || compatibilityReplacement.undoLast() }
    func menuDidRequestPermissions() {
        let status = permissions.currentStatus(promptAccessibility: true)
        if !status.inputMonitoring { permissions.requestInputMonitoringOnce() }
        showPermissionAlert(status)
        updatePermissionStatus()
    }
    func menuDidToggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch { showAlert(title: "로그인 항목을 변경하지 못했습니다", message: "서명되지 않은 개발 빌드에서는 지원되지 않을 수 있습니다. 시스템 설정 → 일반 → 로그인 항목에서 직접 추가할 수 있습니다.\n\n\(error.localizedDescription)") }
    }
    func menuDidApplySuggestion() {
        guard let (decision, delimiter) = pendingSuggestion,
              replacement.replaceCurrentToken(original: decision.original, with: decision.replacement, delimiter: delimiter) else { return }
        pendingSuggestion = nil; menu.suggestion = nil; menu.refresh()
    }

    func keyboardMonitorDidReachBoundary(rawKeys: String, delimiter: String) -> Bool {
        if debug { NSLog("[dhxk] boundary context: %@", SecurityGuard.diagnosticDescription()) }
        guard menu.enabled, permissions.currentStatus().canOperate,
              !SecurityGuard.isSecureInputEnabled, !SecurityGuard.isExcludedFrontmostApp else { return false }
        let direction: InputDirection = inputSource.isKorean ? .koreanToEnglish : .englishToKorean
        let displayedToken = replacement.currentToken()
        // AX가 없는 앱에서도 물리 키로 두벌식 화면 문자열을 재구성할 수 있다.
        // 실제 삭제는 CompatibilityReplacementService가 IME 확정 후 화면 문자 수로 수행한다.
        let inferredDisplayedToken = DubeolsikConverter.englishKeysToHangul(rawKeys)
        let evaluationToken = direction == .koreanToEnglish
            ? (displayedToken ?? inferredDisplayedToken)
            : rawKeys
        guard !history.wasRejected(evaluationToken) else { return false }
        guard let candidate = engine.candidate(for: evaluationToken, direction: direction) else { return false }
        let evidence = lexicon.evidence(
            original: evaluationToken,
            replacement: candidate,
            direction: direction,
            learnedInSession: history.wasAccepted(evaluationToken)
        )
        guard let decision = engine.evaluate(evaluationToken, direction: direction, lexicalEvidence: evidence) else { return false }
        if debug { NSLog("[dhxk] confidence=%.2f auto=%@ reasons=%@", decision.confidence, String(decision.shouldAutoCorrect), decision.reasons.joined(separator: "; ")) }
        if menu.mode == .automatic && decision.shouldAutoCorrect {
            if let displayedToken,
               replacement.replaceCurrentToken(original: displayedToken, with: decision.replacement, delimiter: delimiter) {
                return true
            }
            if direction == .englishToKorean,
               compatibilityReplacement.replaceEnglishKeys(rawKeys, with: decision.replacement, delimiter: delimiter) {
                history.accept(evaluationToken)
                return true
            }
            if direction == .koreanToEnglish,
               compatibilityReplacement.replaceKoreanKeys(
                    rawKeys,
                    displayedOriginal: inferredDisplayedToken,
                    with: decision.replacement,
                    delimiter: delimiter
               ) {
                history.accept(evaluationToken)
                return true
            }
            return false
        }
        guard let displayedToken else { return false }
        pendingSuggestion = (CorrectionDecision(original: displayedToken, replacement: decision.replacement, confidence: decision.confidence, reasons: decision.reasons, shouldAutoCorrect: decision.shouldAutoCorrect), delimiter)
        menu.suggestion = pendingSuggestion?.0; menu.refresh()
        return false
    }
    func keyboardMonitorDidRequestUndo() { _ = replacement.undoLast() || compatibilityReplacement.undoLast() }
    func keyboardMonitorDidResetBuffer() {
        pendingSuggestion = nil
        menu.suggestion = nil
        menu.refresh()
    }

    private func updatePermissionStatus() {
        let status = permissions.currentStatus()
        menu.permissionText = "손쉬운 사용 \(status.accessibility ? "✓" : "✗") / 입력 모니터링 \(status.inputMonitoring ? "✓" : "✗") / 이벤트 \(status.eventSourceAvailable ? "✓" : "✗")"
        menu.refresh()
    }
    private func showPermissionAlert(_ status: PermissionStatus) {
        showAlert(title: "입력 감지 권한이 필요합니다", message: "이 앱은 키 입력을 서버나 파일로 저장하지 않으며 현재 단어만 메모리에 보관합니다.\n\n시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용, 입력 모니터링에서 dhxk를 허용하세요. 입력 모니터링 변경 뒤에는 앱 재시작이 필요할 수 있습니다.\n\n현재: 손쉬운 사용 \(status.accessibility ? "허용" : "미허용"), 입력 모니터링 \(status.inputMonitoring ? "허용" : "미허용")")
    }
    private func showAlert(title: String, message: String) { let alert = NSAlert(); alert.messageText = title; alert.informativeText = message; alert.runModal() }
}
