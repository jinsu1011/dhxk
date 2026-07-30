import AppKit
import HangulInputCore

final class RegistrationWindowController: NSWindowController, NSTextFieldDelegate {
    private let service: RegistrationService
    private let onFinished: (Bool) -> Void
    private let campusPopup = NSPopUpButton()
    private let classPopup = NSPopUpButton()
    private let nameField = NSTextField()
    private let consentCheckbox = NSButton(checkboxWithTitle: "개인정보 수집·이용 안내를 확인했으며 동의합니다.", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let submitButton = NSButton(title: "동의하고 시작하기", target: nil, action: nil)
    private let progress = NSProgressIndicator()

    init(service: RegistrationService, onFinished: @escaping (Bool) -> Void) {
        self.service = service
        self.onFinished = onFinished
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 510),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "dhxk SKALA 파일럿 등록"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) { nil }

    func present() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let title = NSTextField(labelWithString: "SKALA 사용자 등록")
        title.font = .systemFont(ofSize: 24, weight: .bold)
        let subtitle = NSTextField(wrappingLabelWithString: "dhxk 파일럿 운영과 사용자 지원을 위해 최초 실행 시 한 번만 등록합니다. 키 입력과 작성 문서는 수집하지 않습니다.")
        subtitle.textColor = .secondaryLabelColor

        campusPopup.addItems(withTitles: PilotRegistrationValidator.campuses)
        classPopup.addItems(withTitles: PilotRegistrationValidator.classNumbers.map { "\($0)반" })
        nameField.placeholderString = "이름"
        nameField.delegate = self

        let notice = NSTextField(wrappingLabelWithString: "수집 목적: SKALA 내부 파일럿 참여 확인 및 지원\n수집 항목: 캠퍼스, 반, 이름\n보유 기간: SKALA 교육 운영 종료 후 30일 이내 삭제\n동의 거부 권리: 동의를 거부할 수 있으나 파일럿 앱은 사용할 수 없습니다.\n처리 방식: 등록 정보만 운영자가 설정한 Google Sheet로 전송됩니다.")
        notice.font = .systemFont(ofSize: 12)
        notice.textColor = .secondaryLabelColor

        consentCheckbox.target = self
        consentCheckbox.action = #selector(inputChanged)
        statusLabel.textColor = .systemRed
        statusLabel.maximumNumberOfLines = 2
        submitButton.bezelStyle = .rounded
        submitButton.keyEquivalent = "\r"
        submitButton.target = self
        submitButton.action = #selector(submit)
        progress.style = .spinning
        progress.controlSize = .small

        let campusRow = labeledRow("캠퍼스", campusPopup)
        let classRow = labeledRow("반", classPopup)
        let nameRow = labeledRow("이름", nameField)
        let actionRow = NSStackView(views: [progress, NSView(), submitButton])
        actionRow.orientation = .horizontal
        actionRow.alignment = .centerY
        actionRow.spacing = 10

        let stack = NSStackView(views: [title, subtitle, campusRow, classRow, nameRow, notice, consentCheckbox, statusLabel, actionRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 26),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24),
            subtitle.widthAnchor.constraint(equalTo: stack.widthAnchor),
            notice.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            actionRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            nameField.widthAnchor.constraint(equalToConstant: 330)
        ])
        updateSubmitState()
    }

    private func labeledRow(_ label: String, _ control: NSView) -> NSStackView {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = .systemFont(ofSize: 13, weight: .medium)
        labelView.widthAnchor.constraint(equalToConstant: 70).isActive = true
        let row = NSStackView(views: [labelView, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    func controlTextDidChange(_ obj: Notification) { updateSubmitState() }
    @objc private func inputChanged() { updateSubmitState() }

    private func updateSubmitState() {
        let campus = campusPopup.titleOfSelectedItem ?? ""
        let classNumber = classPopup.indexOfSelectedItem + 1
        submitButton.isEnabled = consentCheckbox.state == .on &&
            PilotRegistrationValidator.validationMessage(campus: campus, classNumber: classNumber, name: nameField.stringValue) == nil
    }

    @objc private func submit() {
        let campus = campusPopup.titleOfSelectedItem ?? ""
        let classNumber = classPopup.indexOfSelectedItem + 1
        if let message = PilotRegistrationValidator.validationMessage(campus: campus, classNumber: classNumber, name: nameField.stringValue) {
            statusLabel.stringValue = message; return
        }
        guard consentCheckbox.state == .on else { statusLabel.stringValue = "개인정보 수집·이용 동의가 필요합니다."; return }
        setBusy(true)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let registration = PilotRegistration(campus: campus, classNumber: classNumber,
                                             name: PilotRegistrationValidator.normalizedName(nameField.stringValue),
                                             appVersion: version, consentVersion: PilotRegistrationValidator.consentVersion)
        service.submit(registration) { [weak self] result in
            guard let self else { return }
            self.setBusy(false)
            switch result {
            case .success:
                self.window?.orderOut(nil)
                self.onFinished(true)
            case .failure(let error): self.statusLabel.stringValue = error.localizedDescription
            }
        }
    }

    private func setBusy(_ busy: Bool) {
        [campusPopup, classPopup, nameField, consentCheckbox].forEach { $0.isEnabled = !busy }
        submitButton.isEnabled = !busy
        busy ? progress.startAnimation(nil) : progress.stopAnimation(nil)
        if !busy { updateSubmitState() }
    }
}

extension RegistrationWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let alert = NSAlert()
        alert.messageText = "등록을 종료할까요?"
        alert.informativeText = "등록에 동의하지 않으면 SKALA 파일럿 버전을 사용할 수 없습니다. 입력한 정보는 아직 전송되지 않았습니다."
        alert.addButton(withTitle: "계속 등록")
        alert.addButton(withTitle: "앱 종료")
        if alert.runModal() == .alertSecondButtonReturn { onFinished(false); return true }
        return false
    }
}
