# dhxk

macOS에서 한·영 입력 소스를 착각해 입력한 단어를 로컬에서 감지하고 두벌식 기준으로 복원하는 메뉴 막대 MVP입니다. 입력 문자열은 현재 단어만 메모리에 유지하며 파일이나 서버로 전송하지 않습니다. SKALA 내부 파일럿 빌드는 명시적 동의 후 캠퍼스·반·이름만 최초 1회 별도 등록할 수 있습니다.

`dhxk`는 Swift로 작성한 **네이티브 macOS 메뉴 막대 앱**입니다. 실행 파일·Info.plist·아이콘 리소스를 macOS 설치 형식으로 묶은 결과물이 `dhxk.app`이며, 활성화된 동안 백그라운드에서 동작합니다.

## 현재 기능

- 영문 물리 키 시퀀스 → 두벌식 한글 조합 (`ghdrlfehd` → `홍길동`)
- Shift가 의미 있는 쌍자음·복합 모음과 일반 대문자를 구분 (`EMldjTMrlsk` → `띄어쓰기나`, `TMaus` → `쓰면`)
- 토큰 전체 대문자를 Caps Lock 오입력으로 정규화
- 완성형/호환 자모 한글 → 영문 물리 키 시퀀스 복원
- 복합 모음, 겹받침, Shift 쌍자음 처리
- 제안 모드(기본값)와 고신뢰 자동수정 모드
- 메뉴 막대에서 감지 켜기/끄기, 권한 확인, 모드 변경, 제안 적용, 되돌리기, 로그인 항목 안내, 종료
- 전역 `⌘⌥Z` 즉시 되돌리기
- Accessibility 선택 범위 기반 교체로 실제 UTF-16 텍스트 범위를 사용
- 마우스, 포커스/방향키, 단축키에서 버퍼 초기화
- Secure Input, 암호/보호 필드, 로그인 ID·이메일·계정·OTP 필드, 제외 앱에서 입력을 버퍼링하지 않음
- 숫자·URL·이메일·경로·코드 형태 제외
- Chrome·Safari·ChatGPT·카카오톡·Notion·Pages·Word 등 일반 텍스트 입력 역할 지원
- AX 텍스트 범위가 없는 검증된 문서·채팅 앱도 합성 이벤트 표식이 붙은 양방향 대체 교체 사용
- `HIF_DEBUG=1`에서 실제 입력 문자열 없이 점수·판정 이유만 시스템 로그에 기록
- macOS 내장 한국어·영어 맞춤법 사전으로 변환 전후 어휘 판정
- 사용자가 적용한 변환은 현재 실행 중에 학습하고, 되돌린 변환은 다시 자동수정하지 않음
- 자동 감지와 제안/자동수정 모드는 재시작 후에도 유지하며 실제 입력과 세션 학습은 저장하지 않음
- 사전에 없는 2~4글자 한국 이름과 완성형 한글 음절 후보를 형태 기반으로 자동판정
- 보고서·회의·업무·연구·요청/회신 등 문서 작성 고빈도 어휘와 문장 종결형 판정
- 일상·문서·업무·교육·기술 분야 고빈도 영어 약 280개와 `-s/-ed/-ing/-ly` 등 일반 굴절형 복원
- 한글 두 음절로 짧게 조합된 긴 영어 물리 키도 복원 (`재깅` 형태의 입력 → `world`)

## 요구 환경

- macOS 13 이상
- Apple Swift 6 호환 Command Line Tools 또는 전체 Xcode
- Apple Silicon과 Intel 모두 Swift Package 설정상 지원(현재 개발 환경은 arm64)

### 이 환경에서 발견된 툴체인 문제

초기 환경의 Command Line Tools 26.5는 `swiftc` 내부 빌드가 `swiftlang-6.3.2.1.108`, SDK가 요구하는 빌드가 `swiftlang-6.3.2.1.2`여서 Swift 모듈을 만들 수 없었습니다. `softwareupdate --list`에서 Apple의 `Command Line Tools for Xcode 26.6` 업데이트가 확인되었습니다. 권장 복구는 다음 중 하나입니다.

1. 시스템 설정 → 일반 → 소프트웨어 업데이트에서 **Command Line Tools for Xcode 26.6**만 설치합니다.
2. 또는 터미널에서 `softwareupdate --install 'Command Line Tools for Xcode 26.6-26.6'`를 실행합니다.
3. 전체 Xcode를 설치했다면 `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` 후 `xcodebuild -version`과 `swift --version`을 확인합니다.

CLT를 수동 재설치할 때 `/Library/Developer/CommandLineTools` 삭제가 필요할 수 있지만, 이는 파괴적 시스템 변경이므로 먼저 위 업데이트 방식을 사용하십시오.

## 빌드와 테스트

```bash
make test
make app
make universal
```

SKALA 등록판의 Google Sheet 연결과 빌드는 [`SKALA_REGISTRATION_SETUP.md`](SKALA_REGISTRATION_SETUP.md)를 따릅니다. `SKALARegistrationRequired=false`인 기본 개발 빌드는 등록 화면이나 네트워크 전송 없이 동작합니다.

`make test`는 CLT만 설치된 환경에서도 동작하도록 외부 테스트 프레임워크 없이 assertion과 종료 코드를 집계하는 Swift `CoreTests` 실행 타깃을 사용합니다. `Makefile`은 중첩 샌드박스 충돌을 피하도록 SwiftPM의 자체 sandbox를 끄고, 모듈 캐시를 프로젝트의 `.build/cache` 아래에 둡니다. 이는 Codex 같은 제한 실행 환경을 위한 설정이며 앱 런타임 보안 설정을 끄는 것이 아닙니다.

완성된 앱은 `dist/dhxk.app`입니다. `make app`은 내부 SwiftPM 실행 파일을 번들에 넣고 `AppIcon.icns`를 포함한 뒤 로컬 실행용 ad-hoc 서명을 적용합니다. Developer ID 배포 서명은 하지 않습니다. 개발용 로컬 실행은 다음과 같습니다.

```bash
open dist/dhxk.app
```

또는 `make run`을 사용할 수 있습니다. 배포용으로 다른 Mac에서 안정적으로 권한을 유지하려면 Developer ID 서명과 notarization이 필요하지만, 로컬 MVP 빌드에는 필수가 아닙니다.

`make universal`은 arm64와 x86_64를 합친 `release/dhxk.app`을 만듭니다. 인증서 없이 실행하면 구조 검증용 ad-hoc 서명이고, 공개 배포 시에는 `SIGNING_IDENTITY`, production `BUNDLE_ID`, `VERSION`, `BUILD_NUMBER`를 지정해야 합니다. 전체 절차는 [`GITHUB_DISTRIBUTION_MANUAL.md`](GITHUB_DISTRIBUTION_MANUAL.md), 릴리스 점검은 [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md), 개인정보 처리는 [`PRIVACY.md`](PRIVACY.md)를 확인하십시오.

GitHub 무료 배포와 Mac App Store의 차이, 예상 비용, 출시 순서, 출시형 사용자 온보딩은 [`LAUNCH_AND_DISTRIBUTION_GUIDE.md`](LAUNCH_AND_DISTRIBUTION_GUIDE.md)에 통합했습니다. 다음 AI 작업에서 이어갈 때는 [`AI_HANDOFF_PROMPT.md`](AI_HANDOFF_PROMPT.md)를 그대로 전달하십시오.

## 권한 설정

처음 실행한 뒤 메뉴의 `권한` 항목을 누릅니다.

1. 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 `dhxk` 허용
2. 시스템 설정 → 개인정보 보호 및 보안 → 입력 모니터링에서 `dhxk` 허용
3. 입력 모니터링 변경 후 앱을 종료하고 다시 실행
4. 메뉴에서 `자동 감지 켜기` 선택

앱은 권한 요청을 시작 시마다 반복하지 않습니다. 권한이 없거나 이벤트 탭 생성이 실패하면 감지를 다시 끄고 안내하며 충돌하지 않습니다.

## 사용법

기본은 **제안 모드**입니다. 단어 뒤에 공백·Enter·Tab·문장부호를 입력했을 때 고신뢰 후보가 있으면 메뉴에 `제안 적용`이 나타납니다. 자동수정 모드에서는 고신뢰 임계값과 점수 차이를 모두 통과한 후보만 즉시 교체합니다.

자동 교체 직후 `⌘⌥Z` 또는 메뉴의 `최근 변환 되돌리기`를 사용할 수 있습니다. 되돌린 원문은 앱을 종료하기 전까지 다시 자동수정하지 않습니다.

로그인 시 실행은 메뉴에서 설정할 수 있습니다. 서명되지 않은 직접 조립 앱에서 ServiceManagement 등록이 거부되면 시스템 설정 → 일반 → 로그인 항목에서 앱을 직접 추가하십시오.

## 설계

```text
CGEventTap → KeyboardEventMonitor ─┬→ SecurityGuard
                                  ├→ InputSourceMonitor
                                  └→ CorrectionEngine ─┬→ TextReplacementService → AX focused element
                                           │           └→ CompatibilityReplacementService
                                  LanguageScorer                    │
                                                          synthetic marker / history

HangulInputCore: DubeolsikConverter → HangulComposer (macOS API 비의존)
```

`KeyboardEventMonitor`는 문자 자체 대신 US ANSI 물리 키 코드를 단어 단위로 모읍니다. 경계 키가 눌리기 직전에 현재 입력 소스와 Accessibility의 실제 입력 필드 텍스트를 확인합니다. AX가 정상인 앱은 실제 caret 앞 원문과 정확히 일치할 때만 교체합니다. AX 범위를 제공하지 않는 허용 앱에서 영문→한글은 물리 키 수만큼 삭제합니다. 한글→영어는 물리 키로 화면의 두벌식 문자열을 재구성하고 구분 키로 IME 조합을 먼저 확정한 뒤 실제 조합 문자 수만큼 삭제합니다. 앱이 만든 모든 이벤트에는 marker를 넣어 재귀 감지를 막습니다.

## 보안과 제외 조건

- Secure Input 활성화 시 감지/버퍼링 중단
- `AXSecure` 또는 `AXProtectedContent` 필드와 role이 불확실한 요소 제외
- `AXTextField`·`AXTextArea`·`AXComboBox` 모두 label/description/identifier/placeholder/DOM metadata에 아이디·로그인·계정·이메일·비밀번호·OTP·PIN·인증 코드가 있으면 제외
- AX 포커스 정보를 제공하지 않는 앱의 대체 교체는 명시된 문서·채팅 앱 번들 ID에서만 허용하고 Terminal·IDE·원격 앱에는 사용하지 않음
- Terminal, iTerm2, Xcode, VS Code, JetBrains IDE, Microsoft Remote Desktop, TeamViewer 기본 제외
- Command/Control/Option 조합, 숫자·`@`·`_`·경로 구분자가 포함된 토큰 제외
- 실제 입력 문자열은 로그에 남기지 않음

추가 제외 앱은 bundle ID를 사용해 다음처럼 설정할 수 있습니다. 앱을 다시 켜면 적용됩니다.

```bash
defaults write local.hangul-input-fixer ExcludedBundleIDs -array com.example.Editor com.example.RemoteDesktop
```

기본 제외 목록은 `Sources/HangulInputApp/SecurityGuard.swift`에 있습니다.

## 알려진 제한사항

- 앱마다 접근성 구현이 달라 문자 교체 성공 여부도 다릅니다. Chrome·Safari는 AX 경로를 우선 사용하고, 알려진 문서·채팅 앱만 제한적 대체 경로를 사용합니다. 임의의 모든 앱을 무조건 허용하지는 않습니다.
- AX 정보를 전혀 제공하지 않는 앱의 대체 경로에서는 일반 ID 필드와 본문을 공개 API로 완벽히 구분할 수 없습니다. Secure Input은 항상 차단하지만, 로그인 화면에서는 자동 감지를 꺼 두는 것이 가장 안전합니다.
- 한글 IME 조합 중 Accessibility 값 갱신 시점은 앱마다 다릅니다. 현재 MVP는 경계 키를 누르기 직전 AX 값과 실제 caret 범위를 확인합니다.
- 판정은 단어 경계 단위입니다. 문서 고빈도 단어와 종결형은 확장했지만 여러 단어로 된 문장 전체의 문맥 모델은 아직 포함하지 않습니다.
- 키 코드 표는 US ANSI 기반 두벌식 문자 키를 대상으로 합니다. Dvorak/사용자 정의 물리 배열은 후속 지원이 필요합니다.
- 로컬 ad-hoc/미서명 앱은 업데이트 때 macOS 권한 항목이 다시 필요할 수 있습니다.

## 배포

현재 ad-hoc arm64 앱은 로컬 개발용입니다. 공개 배포에는 Developer ID 서명, Hardened Runtime, Apple 공증, Universal 2 빌드가 필요합니다. 권장 배포 경로와 명령은 [`DISTRIBUTION.md`](DISTRIBUTION.md)에 정리되어 있습니다.

권장 사용자 흐름은 `GitHub Releases 또는 제품 웹사이트 → 공증된 ZIP/DMG 다운로드 → Applications에 복사 → 권한 허용`입니다. GitHub와 앱 다운로드는 양자택일이 아닙니다. GitHub Releases에 다운로드할 앱 ZIP/DMG를 올리는 방식입니다.

- 배포 담당자: [`GITHUB_DISTRIBUTION_MANUAL.md`](GITHUB_DISTRIBUTION_MANUAL.md)
- 일반 사용자: [`USER_MANUAL.md`](USER_MANUAL.md)
- SKALA 등록 운영: [`SKALA_REGISTRATION_SETUP.md`](SKALA_REGISTRATION_SETUP.md)
- SKALA 발표/기술 소개: [`SKALA_TECHNICAL_OVERVIEW.md`](SKALA_TECHNICAL_OVERVIEW.md)
- 배포 개요: [`DISTRIBUTION.md`](DISTRIBUTION.md)

## 프로젝트 구조

```text
Sources/HangulInputCore/
  DubeolsikConverter.swift
  HangulComposer.swift
  CorrectionEngine.swift       # LanguageScorer 포함
  SensitiveFieldClassifier.swift
  CompatibilityAppClassifier.swift
Sources/HangulInputApp/
  AppDelegate.swift
  MenuBarController.swift
  PermissionManager.swift
  InputSourceMonitor.swift
  KeyboardEventMonitor.swift
  SecurityGuard.swift
  TextReplacementService.swift
  CompatibilityReplacementService.swift
  CorrectionHistory.swift
Tests/HangulInputCoreTests/
Resources/Info.plist
Makefile
```
