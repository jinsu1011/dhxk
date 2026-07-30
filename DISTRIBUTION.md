# dhxk 배포 가이드

실제 GitHub Release를 만드는 단계별 운영 절차는 [`GITHUB_DISTRIBUTION_MANUAL.md`](GITHUB_DISTRIBUTION_MANUAL.md), 설치 대상 사용자의 안내서는 [`USER_MANUAL.md`](USER_MANUAL.md)를 함께 확인한다.

기준일: 2026-07-30

## 결론

첫 공개 버전은 **Developer ID로 서명하고 Apple 공증을 받은 Universal 2 앱을 ZIP 또는 DMG로 만들어 GitHub Releases에서 직접 다운로드**하게 하는 방식을 권장한다.

GitHub와 앱 다운로드는 서로 다른 선택지가 아니다. GitHub Releases가 다운로드 페이지이고, 사용자가 받는 파일은 `dhxk.app`을 담은 ZIP 또는 DMG다.

Mac App Store는 App Sandbox와 App Review를 거쳐야 한다. 이 앱은 전역 입력 모니터링뿐 아니라 AXUIElement로 다른 앱의 선택 영역을 교체하므로 App Store 심사·sandbox 호환성 위험이 크다. 먼저 Developer ID 직접 배포로 제품과 권한 흐름을 검증하고, App Store 버전은 AX 교체 구조를 별도로 재설계한 뒤 판단한다.

## 현재 배포 준비 상태

| 항목 | 현재 상태 | 공개 배포에 필요한 상태 |
|---|---|---|
| 앱 번들 | `.app` 생성 성공 | 유지 |
| CPU | Universal 2 자동 빌드 검증 (`arm64` + `x86_64`) | Intel 실기기 시험 필요 |
| 최소 OS | macOS 13 | 유지 가능 |
| 서명 | ad-hoc | Developer ID Application |
| Hardened Runtime | 미적용 | 필수 |
| Apple 공증 | 없음 | 필수 |
| 공증 ticket staple | 없음 | 권장/사실상 필수 |
| Bundle ID | `local.hangul-input-fixer` | 소유 도메인 기반 ID로 고정 |
| 앱 아이콘 | `AppIcon.icns` 적용 | 유지 |
| 개인정보 처리방침 | README 설명만 있음 | 별도 공개 페이지 권장 |
| 업데이트 | 수동 | GitHub Releases 수동 업데이트부터 시작 |
| 설치 파일 | 개발용 `.app` | ZIP 또는 DMG |

현재 `dist/dhxk.app`과 인증서 없이 만든 `release/dhxk.app`은 로컬 테스트용이다. Universal 2 구조는 검증됐지만 Developer ID가 없으므로 그대로 배포하면 안 된다. 공개본은 `Scripts/build-universal.sh`와 `Scripts/notarize-release.sh`로 서명·공증해야 한다.

## 필요한 계정과 도구

1. Apple Developer Program 가입
   - 공식 연회비: 미화 99달러 또는 현지 통화.
   - Developer ID 인증서와 공증 서비스를 사용하려면 필요하다.
2. 전체 Xcode 설치
   - 현재 CLT만으로 앱 개발은 가능하지만 Archive, 최신 `notarytool`, 배포 관리에는 전체 Xcode를 권장한다.
3. Developer ID Application 인증서 생성
   - Keychain Access에서 CSR 생성.
   - Apple Developer의 Certificates에서 Developer ID Application 발급.
4. 고정 Bundle ID 결정
   - 예: `com.example.HangulInputFixer`.
   - 실제 소유자/조직의 reverse-DNS 값을 사용한다.

## 권장 릴리스 절차

### 1. 최종 빌드

Apple Silicon과 Intel Mac을 모두 지원하려면 Universal 2 바이너리를 만든다. 전체 Xcode 프로젝트로 전환해 Archive하는 방식을 가장 권장한다. Swift Package 방식을 유지한다면 두 architecture를 빌드하고 결과가 universal인지 `lipo -info`로 검증한다.

```bash
swift build -c release --product HangulInputFixer --arch arm64 --arch x86_64
lipo -info dist/dhxk.app/Contents/MacOS/HangulInputFixer
```

### 2. Developer ID 서명과 Hardened Runtime

```bash
codesign --force --deep \
  --options runtime \
  --timestamp \
  --sign "Developer ID Application: 이름 (TEAMID)" \
  dist/dhxk.app

codesign --verify --deep --strict --verbose=2 dist/dhxk.app
```

인증서 이름과 Team ID는 실제 개발자 계정 값으로 교체한다. 비밀키나 Apple 비밀번호를 Git에 저장하지 않는다.

### 3. 공증용 ZIP 생성

Apple이 권장하는 `ditto`로 앱 번들의 메타데이터를 보존한다.

```bash
ditto -c -k --keepParent \
  dist/dhxk.app \
  dist/dhxk-0.2.0-universal.zip
```

### 4. Apple 공증

앱 전용 암호 또는 App Store Connect API key를 Keychain profile에 한 번 저장한다.

```bash
xcrun notarytool store-credentials "dhxk-notary" \
  --apple-id "APPLE_ID" \
  --team-id "TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"

xcrun notarytool submit \
  dist/dhxk-0.2.0-universal.zip \
  --keychain-profile "dhxk-notary" \
  --wait
```

### 5. Ticket staple과 최종 검증

```bash
xcrun stapler staple dist/dhxk.app
xcrun stapler validate dist/dhxk.app
spctl --assess --type execute --verbose=4 dist/dhxk.app
```

ticket이 포함된 앱으로 ZIP을 다시 만든다.

```bash
ditto -c -k --keepParent \
  dist/dhxk.app \
  dist/dhxk-0.2.0-universal.zip
```

### 6. GitHub Releases에 게시

1. 버전 태그 생성: `v0.2.0`.
2. GitHub Release 생성.
3. `dhxk-0.2.0-universal.zip`을 Release asset으로 첨부.
4. SHA-256, 지원 macOS 버전, 권한 설정법, 개인정보 처리방침 링크를 release notes에 기록.
5. 소스 저장소 공개 여부와 관계없이 배포 파일은 Release asset으로 제공할 수 있다. 공개 프로젝트라면 코드와 이슈 추적을 함께 제공하는 편이 신뢰에 유리하다.

## ZIP, DMG, PKG 선택

- ZIP: MVP에 가장 간단하다. 사용자가 압축 해제 후 `/Applications`로 이동한다.
- DMG: 앱과 Applications 바로가기를 함께 보여줄 수 있어 공개 배포 UX가 좋다. 단일 앱 배포에 적합하다.
- PKG: 여러 구성요소나 지정 경로 설치가 필요할 때 사용한다. 현재 단일 메뉴 막대 앱에는 불필요하다.

첫 공개 버전은 ZIP, 사용자가 늘면 서명된 DMG로 전환하는 것이 합리적이다.

## 사용자 설치 흐름

1. GitHub Releases 또는 제품 웹사이트에서 ZIP/DMG 다운로드.
2. 앱을 `/Applications`로 복사.
3. 앱 실행.
4. 앱 안내에 따라 손쉬운 사용과 입력 모니터링 허용.
5. 권한 변경 뒤 앱 재시작.
6. 메뉴에서 자동 감지와 동작 모드 선택.

앱 경로와 코드 서명이 바뀌면 TCC 권한이 다시 필요할 수 있으므로, 사용자가 앱을 항상 `/Applications`에서 실행하게 안내한다.

## App Store를 당장 권장하지 않는 이유

- Mac App Store 앱은 sandbox 및 App Review 요구사항을 만족해야 한다.
- CGEventTap 기반 감지는 Input Monitoring 권한으로 가능한 사례가 있지만, 현재 앱은 AXUIElement로 다른 앱의 텍스트 선택 범위를 읽고 수정한다.
- Apple 지침은 사용자 입력을 기록·모니터링할 때 명시적 동의와 명확한 표시를 요구한다.
- 따라서 App Store 제출 전에는 sandbox 빌드에서 AX 교체 기능의 허용 범위와 App Review 정책을 별도로 검증해야 한다.

현재 기능을 유지하면서 빠르게 배포하려면 Developer ID 직접 배포가 예측 가능하다.

## 배포 전 추가 체크리스트

- [ ] 전체 Xcode 설치 및 SDK 라이선스 승인
- [ ] Apple Developer Program 가입
- [ ] production Bundle ID 결정
- [ ] Developer ID Application 인증서 발급
- [ ] 앱 아이콘과 버전 정보 추가
- [ ] Universal 2 빌드 및 Intel/Apple Silicon 실기기 테스트
- [ ] Hardened Runtime 서명
- [ ] Apple notarization 및 ticket staple
- [ ] Gatekeeper `spctl` 검증
- [ ] 개인정보 처리방침 공개
- [ ] 권한 onboarding 화면 추가
- [ ] TextEdit/메모/브라우저/Office 앱별 교체 회귀 테스트
- [ ] 로그인 ID/비밀번호/OTP 필드 미동작 수동 테스트
- [ ] GitHub Release notes와 SHA-256 게시

## 공식 참고자료

- Apple Developer ID: https://developer.apple.com/support/developer-id/
- Developer ID 인증서: https://developer.apple.com/help/account/certificates/create-developer-id-certificates
- Apple 공증: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Hardened Runtime: https://developer.apple.com/documentation/security/hardened-runtime
- Mac 패키징: https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution
- 앱 배포 방식: https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases
- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- GitHub Releases: https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases
