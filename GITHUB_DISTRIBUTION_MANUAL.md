# dhxk 처음부터 배포하기

기준일: 2026-07-30
대상: 처음으로 macOS 앱을 외부 사용자에게 배포하는 개발자
권장 방식: Developer ID 서명 + Apple 공증 + Universal 2 ZIP + GitHub Releases

## 1. 전체 흐름

```text
Apple Developer 가입
→ 고정 Bundle ID 결정
→ Developer ID Application 인증서 발급
→ 공증 자격 증명 저장
→ 테스트
→ Universal 2 빌드
→ Hardened Runtime 서명
→ Apple 공증
→ ticket staple
→ 깨끗한 Mac 설치 시험
→ GitHub Release 게시
```

GitHub는 다운로드 파일과 소스·이슈를 제공하는 장소다. macOS가 앱 개발자를 신뢰하게 만드는 것은 GitHub가 아니라 Apple의 Developer ID 서명과 공증이다.

## 2. 최초 한 번: Apple Developer 준비

1. [Apple Developer](https://developer.apple.com/)에 Apple ID로 로그인한다.
2. Apple Developer Program에 가입하고 연회비를 결제한다.
3. 계약·세금·결제 관련 동의가 표시되면 Account Holder 계정으로 완료한다.
4. Xcode → Settings → Accounts에서 같은 Apple ID를 추가한다.
5. Xcode의 계정 화면에서 Team이 정상 표시되는지 확인한다.

현재 개발 Mac에는 Xcode 26.6과 `notarytool`이 있지만 Developer ID 인증서는 아직 없다. 다음 명령이 `0 valid identities found`가 아니어야 실제 공개 서명을 진행할 수 있다.

```bash
security find-identity -v -p codesigning
```

## 3. 제품 식별자 확정

공개 전에 다음 값을 한 번 정하고 이후 버전에서도 유지한다.

- 앱 이름: `dhxk`
- production Bundle ID: 실제 소유 도메인의 역순 값, 예: `com.example.dhxk`
- 최소 macOS: 13.0
- 버전: 사용자에게 보이는 `0.2.0` 같은 값
- 빌드 번호: 매 배포마다 증가하는 정수
- 지원 이메일 또는 이슈 URL
- 개인정보 처리방침 URL

`local.hangul-input-fixer`는 개발용 Bundle ID다. 첫 공개 배포 전에 production Bundle ID로 바꾼다. Bundle ID를 바꾼 최초 1회에는 개발 설치본의 손쉬운 사용·입력 모니터링 권한을 다시 허용해야 한다.

## 4. Developer ID Application 인증서 만들기

가장 간단한 방법:

1. Xcode → Settings → Accounts
2. Apple ID와 Team 선택
3. Manage Certificates 클릭
4. `+` → Developer ID Application 선택
5. 생성 후 아래 명령으로 이름 확인

```bash
security find-identity -v -p codesigning
```

출력 예:

```text
1) ABCD... "Developer ID Application: 이름 (TEAMID)"
```

괄호까지 포함한 전체 인증서 이름을 이후 `SIGNING_IDENTITY`에 사용한다. 개인키나 인증서 암호를 Git에 올리지 않는다.

## 5. 공증 자격 증명 저장

앱 전용 암호 방식을 사용하는 예:

1. [Apple Account](https://account.apple.com/)에서 앱 전용 암호를 생성한다.
2. Team ID를 Apple Developer 계정 화면에서 확인한다.
3. 다음 명령을 한 번 실행한다.

```bash
xcrun notarytool store-credentials "dhxk-notary" \
  --apple-id "APPLE_ID_EMAIL" \
  --team-id "TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"
```

성공하면 암호 자체가 프로젝트 파일에 저장되는 것이 아니라 Keychain의 `dhxk-notary` profile에 저장된다.

## 6. GitHub 저장소 준비

1. GitHub에서 새 저장소를 만든다.
2. 공개 소스 제품이면 Public, 소스 비공개 배포면 Private을 선택한다.
3. 인증서, 암호, API key, `.build`, `release` 결과물은 커밋하지 않는다.
4. `README.md`, `USER_MANUAL.md`, `PRIVACY.md`를 검토한다.
5. 이 프로젝트는 아직 전체 파일이 Git에서 추적되지 않은 상태이므로 첫 공개 전에 의도한 파일만 검토해 커밋한다.

GitHub 저장소 공개 여부와 Release 파일 다운로드 가능 여부는 별도로 설계할 수 있다. 일반 소비자용 배포는 공개 저장소의 Releases가 가장 이해하기 쉽다.

## 7. 릴리스 전 테스트

프로젝트 루트에서 실행한다.

```bash
make test
git diff --check
```

수동으로 최소한 다음을 확인한다.

- `ghdrlfehd → 홍길동`
- `dkssudgktpdy → 안녕하세요`
- `EMldjTMrlsk → 띄어쓰기나`
- `TMaus → 쓰면`
- `ㅗ디ㅣㅐ → hello`
- TextEdit, Chrome, Safari, ChatGPT, 카카오톡, Pages/Word
- 자동수정과 `⌘⌥Z` 되돌리기
- 재시작 후 자동 감지·동작 모드 유지
- 비밀번호·로그인 ID·이메일·OTP 필드 미동작
- Terminal·IDE·원격 데스크톱 미동작
- URL·이메일·경로·코드 문자열 미동작

## 8. Developer ID로 Universal 2 앱 빌드

실제 값을 넣어 실행한다.

```bash
SIGNING_IDENTITY="Developer ID Application: 이름 (TEAMID)" \
BUNDLE_ID="com.example.dhxk" \
VERSION="0.3.0" \
BUILD_NUMBER="3" \
SKALA_REGISTRATION_REQUIRED=true \
REGISTRATION_ENDPOINT="https://script.google.com/macros/s/DEPLOYMENT_ID/exec" \
make universal
```

SKALA 파일럿판은 먼저 [`SKALA_REGISTRATION_SETUP.md`](SKALA_REGISTRATION_SETUP.md)에 따라 기관 승인 Sheet와 Apps Script `/exec` URL을 만들어야 한다. 시험용 또는 비어 있는 URL로 만든 앱은 배포하지 않는다.

이 명령은 다음을 자동 수행한다.

1. arm64 빌드
2. x86_64 빌드
3. `lipo`로 Universal 2 실행 파일 생성
4. `release/dhxk.app` 조립
5. 앱 아이콘 포함
6. Bundle ID·버전·빌드 번호 적용
7. Hardened Runtime과 timestamp를 포함한 Developer ID 서명
8. plist·architecture·서명 검증

로컬 구조 시험만 할 때는 인증서 없이 `make universal`을 실행할 수 있지만 결과는 ad-hoc 서명이므로 절대 공개 배포하지 않는다.

수동 검증:

```bash
lipo -info release/dhxk.app/Contents/MacOS/HangulInputFixer
codesign --verify --deep --strict --verbose=2 release/dhxk.app
codesign -dv --verbose=4 release/dhxk.app
```

다음을 확인한다.

- `x86_64 arm64`
- `Authority=Developer ID Application: ...`
- `TeamIdentifier=...`
- 서명 flags에 `runtime`
- `Signature=adhoc`가 아님

## 9. Apple 공증과 staple

```bash
NOTARY_PROFILE="dhxk-notary" Scripts/notarize-release.sh
```

스크립트는 Developer ID와 Hardened Runtime이 없으면 제출 전에 중단한다. 정상일 때는 다음을 수행한다.

1. 공증 제출 ZIP 생성
2. `notarytool submit --wait`
3. 앱에 ticket staple
4. staple 검증
5. Gatekeeper 평가
6. 최종 ZIP과 SHA-256 생성

결과:

```text
release/dhxk-0.2.0-universal.zip
release/dhxk-0.2.0-universal.zip.sha256
```

공증이 실패하면 출력된 submission ID로 로그를 확인한다.

```bash
xcrun notarytool log SUBMISSION_ID \
  --keychain-profile "dhxk-notary" \
  release/notary-log.json
```

## 10. 깨끗한 Mac에서 설치 시험

가능하면 이 앱을 설치한 적 없는 Apple Silicon Mac과 Intel Mac에서 각각 시험한다.

1. 최종 ZIP을 웹이나 AirDrop이 아닌 실제 다운로드 방식으로 받는다.
2. 압축을 풀고 `dhxk.app`을 `/Applications`로 옮긴다.
3. Gatekeeper의 개발자 이름이 올바른지 확인한다.
4. 손쉬운 사용과 입력 모니터링을 허용한다.
5. 앱을 재시작한다.
6. 메뉴에서 세 권한이 모두 `✓`인지 확인한다.
7. 양방향 변환과 되돌리기를 시험한다.
8. Mac을 재부팅하고 설정 유지와 로그인 실행을 확인한다.

배포자의 개발 Mac에서만 시험하면 기존 TCC 권한과 캐시 때문에 신규 사용자 문제를 놓칠 수 있다.

## 11. GitHub Release 게시

### 웹에서 게시

1. GitHub 저장소 → Releases
2. Draft a new release
3. 새 태그 `v0.2.0`
4. 제목 `dhxk 0.2.0`
5. 변경사항·지원 macOS·권한·알려진 제한 작성
6. 다음 두 파일 첨부
   - `dhxk-0.2.0-universal.zip`
   - `dhxk-0.2.0-universal.zip.sha256`
7. 먼저 Pre-release로 내부 시험
8. 문제가 없으면 정식 Release로 변경

### GitHub CLI로 게시

```bash
gh auth login

gh release create v0.2.0 \
  release/dhxk-0.2.0-universal.zip \
  release/dhxk-0.2.0-universal.zip.sha256 \
  --title "dhxk 0.2.0" \
  --notes-file RELEASE_NOTES.md \
  --prerelease
```

내부 시험이 끝나면 GitHub 웹에서 Pre-release 표시를 해제한다.

## 12. 사용자에게 안내할 설치 순서

1. GitHub Releases에서 최신 ZIP 다운로드
2. 압축 해제
3. `dhxk.app`을 `/Applications`에 복사
4. 앱 실행
5. 손쉬운 사용 허용
6. 입력 모니터링 허용
7. 앱 재시작
8. 메뉴에서 `자동 감지 켜기`
9. 처음에는 제안 모드로 시험 후 자동수정 모드 선택

상세 내용은 `USER_MANUAL.md`를 Release 설명에 링크한다.

## 13. 업데이트 원칙

- Bundle ID를 바꾸지 않는다.
- Developer ID 인증서와 Team을 유지한다.
- 버전과 빌드 번호를 매번 증가시킨다.
- 같은 `/Applications/dhxk.app` 경로에 덮어쓴다.
- 모든 릴리스를 다시 서명·공증·staple한다.
- 권한이 유지되는지 깨끗한 Mac과 기존 사용자 Mac에서 모두 시험한다.
- 문제가 있는 Release는 삭제만 하지 말고 Deprecated 안내와 수정 버전을 게시한다.

## 14. 현재 남은 외부 준비

- [ ] Apple Developer Program 가입 완료
- [ ] production Bundle ID 결정
- [ ] Developer ID Application 인증서 발급
- [ ] `dhxk-notary` Keychain profile 생성
- [ ] 지원 이메일/URL과 공개 개인정보 처리방침 URL 결정
- [ ] GitHub 저장소 생성 및 첫 커밋
- [ ] 공증된 최초 Pre-release 게시
- [ ] 깨끗한 Apple Silicon/Intel Mac 시험

## 공식 자료

- [Apple: Developer ID certificate](https://developer.apple.com/help/glossary/developer-id-certificate/)
- [Apple: Distribute outside the Mac App Store](https://help.apple.com/xcode/mac/current/en.lproj/dev033e997ca.html)
- [Apple: Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple: Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [Apple: Enable hardened runtime](https://help.apple.com/xcode/mac/current/en.lproj/devf87a2ac8f.html)
- [GitHub: About releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
