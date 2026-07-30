# dhxk 출시·배포 통합 가이드

기준일: 2026-07-30
대상 제품: macOS 메뉴 막대 앱 `dhxk`
현재 버전: 0.2.0 개발 후보

## 1. 먼저 결론

### 가장 현실적인 첫 출시

**전체 기능판을 Developer ID로 서명·공증해 GitHub Releases에서 무료 다운로드로 배포**하는 것이 가장 적합하다.

이유:

- GitHub Release 파일 배포 비용은 0 USD다.
- 현재 핵심 기능인 전역 입력 감지와 다른 앱의 텍스트 자동 교체를 유지할 수 있다.
- Apple 공증을 받으면 Gatekeeper 경고를 최소화할 수 있다.
- App Store 심사를 기다리지 않고 베타 사용자를 받을 수 있다.

다만 GitHub가 무료여도 **안정적인 macOS 공개 배포에는 Apple Developer Program 연 99 USD가 사실상 필요**하다. GitHub 비용과 Apple 코드 서명 비용은 서로 다른 항목이다.

### Mac App Store판

현재 전체 기능판을 그대로 제출하는 것은 권장하지 않는다. Mac App Store 앱은 App Sandbox가 필수이며, Apple 문서는 sandbox에서 assistive app의 Accessibility API 사용을 금지 활동으로 명시한다. 현재 앱은 AXUIElement로 다른 앱의 텍스트 범위를 읽고 바꾸므로 핵심 자동 교체가 충돌한다.

현실적인 제품 전략:

1. `dhxk Full`: GitHub/제품 웹사이트에서 Developer ID 직접 배포
2. `dhxk Lite`: App Store용 sandbox 버전
   - 전역 키 감지는 Input Monitoring + CGEventTap 사용 가능
   - AX 기반 다른 앱 텍스트 직접 교체 제거
   - 변환 후보 알림, 클립보드 복사, 앱 내부 변환창 중심
   - 실제 자동 교체 수준은 낮아짐

## 2. 비용

| 항목 | GitHub 직접 배포 | Mac App Store |
|---|---:|---:|
| GitHub Free 저장소·Releases | 0 USD/월 | 선택 사항 |
| Xcode | 무료 | 무료 |
| Apple Developer Program | 연 99 USD | 연 99 USD |
| Developer ID 서명·Apple 공증 | 별도 건별 비용 없음 | 사용하지 않음 |
| App Store 앱 등록 | 별도 앱별 등록비 없음 | 멤버십에 포함 |
| Apple 판매 수수료 | 없음 | 일반 30%, Small Business 등 해당 시 15%, 일부 구독 15% |
| GitHub Release 다운로드 대역폭 | 공식 문서상 제한 없음 | 해당 없음 |
| 도메인 | 선택, 없어도 됨 | 개인정보 처리방침·지원 페이지용으로 권장 |
| 결제 시스템 | 유료 판매 시 별도 구축 | 유료 앱·구독은 App Store 결제 사용 |

Apple 멤버십은 지역에 따라 현지 통화와 세금이 적용될 수 있다. 비영리·공인 교육기관·정부기관은 조건에 따라 fee waiver를 신청할 수 있다.

### 최소 현금 비용 시나리오

- 무료 GitHub 베타, 서명 없음: 0 USD — Gatekeeper·권한 불안정 때문에 일반 사용자 배포에는 부적합
- 권장 GitHub 정식 베타: Apple Developer 연 99 USD, GitHub 0 USD
- Mac App Store 출시: Apple Developer 연 99 USD + 판매 수수료
- 커스텀 도메인·유료 서버·외부 분석 도구: 현재 구조에는 필수 아님

## 3. GitHub로 무료 배포할 수 있는가?

가능하다. GitHub Free는 월 0 USD이며 공개·비공개 저장소를 제공한다. GitHub Releases에는 설치 ZIP을 올릴 수 있다. 공식 제한은 릴리스 자산 하나당 2 GiB 미만, 릴리스당 최대 1,000개 자산이며 릴리스 전체 용량과 대역폭에는 제한이 없다.

### 권장 공개 형태

```text
GitHub 공개 저장소
├── README.md
├── PRIVACY.md
├── USER_MANUAL.md
├── 소스 코드
└── Releases
    ├── dhxk-0.2.0-universal.zip
    └── dhxk-0.2.0-universal.zip.sha256
```

소스를 공개하고 싶지 않다면 private 저장소로 개발하면서 별도 공개 다운로드 저장소나 제품 웹사이트를 운영할 수 있다. 다만 사용자 신뢰와 이슈 접수를 위해 초기에는 공개 저장소가 단순하다.

## 4. GitHub 무료 배포 절차

### 4.1 계정과 저장소

1. GitHub 무료 계정을 만든다.
2. 이메일을 인증하고 2단계 인증을 켠다.
3. 새 Public 저장소 `dhxk`를 만든다.
4. 인증서, Apple 암호, API key는 절대 저장소에 넣지 않는다.
5. `.gitignore`에 `.build`, `dist`, `release`가 제외됐는지 확인한다.

### 4.2 Apple Developer 준비

1. Apple Developer Program에 가입한다.
2. Xcode → Settings → Accounts에 Apple ID를 등록한다.
3. Manage Certificates → `Developer ID Application` 인증서를 만든다.
4. production Bundle ID를 정한다. 예: `com.소유도메인.dhxk`.
5. `notarytool` Keychain profile을 만든다.

자세한 명령은 `GITHUB_DISTRIBUTION_MANUAL.md`에 있다.

### 4.3 테스트

```bash
make test
git diff --check
```

필수 수동 시험:

- `ghdrlfehd → 홍길동`
- `EMldjTMrlsk → 띄어쓰기나`
- `TMaus → 쓰면`
- `ㅗ디ㅣㅐ → hello`
- Chrome, Safari, ChatGPT, 카카오톡, 문서 앱
- 비밀번호·ID·OTP 미동작
- 되돌리기와 재시작 설정 유지

### 4.4 공개용 앱 빌드

```bash
SIGNING_IDENTITY="Developer ID Application: 이름 (TEAMID)" \
BUNDLE_ID="com.example.dhxk" \
VERSION="0.2.0" \
BUILD_NUMBER="2" \
make universal
```

### 4.5 공증

```bash
NOTARY_PROFILE="dhxk-notary" Scripts/notarize-release.sh
```

결과 파일:

```text
release/dhxk-0.2.0-universal.zip
release/dhxk-0.2.0-universal.zip.sha256
```

### 4.6 깨끗한 Mac 시험

1. ZIP을 실제 브라우저로 다운로드한다.
2. `/Applications`에 설치한다.
3. Gatekeeper 화면의 개발자 이름을 확인한다.
4. 손쉬운 사용·입력 모니터링을 켠다.
5. 재시작 후 변환과 되돌리기를 확인한다.
6. Apple Silicon과 Intel Mac에서 각각 시험한다.

### 4.7 GitHub Release

1. 저장소 → Releases → Draft a new release
2. 태그 `v0.2.0`
3. 제목 `dhxk 0.2.0`
4. `RELEASE_NOTES.md` 내용을 붙여넣는다.
5. ZIP과 SHA-256 파일을 첨부한다.
6. 먼저 Pre-release로 게시한다.
7. 내부 사용자 시험 후 정식 Release로 바꾼다.

## 5. Mac App Store까지 남은 단계

### 5.1 가입과 사업 정보

1. Apple Developer Program 가입
2. App Store Connect 계약 확인
3. 유료 앱·구독이면 Paid Apps Agreement 동의
4. 은행·세금 정보 입력
5. 개인 계정 또는 조직 계정의 판매자 이름 확인

### 5.2 App Store용 제품 재설계

현재 코드에 App Sandbox만 켜는 것으로는 충분하지 않다.

반드시 분리할 항목:

- 제거: AXUIElement를 통한 다른 앱 텍스트 읽기·선택·교체
- 제거 또는 심사 검토: 합성 키 이벤트 기반 자동 입력
- 유지 가능성 높음: CGEventTap을 통한 전역 키 감지와 Input Monitoring 요청
- 대체 UX: 메뉴 후보, 알림, 클립보드 복사, 앱 내부 변환창
- App Store판용 별도 target·Bundle ID·entitlements
- App Sandbox 활성화

이 단계는 기능 축소가 아니라 별도 제품 설계 작업이다. Full과 Lite의 기능 차이를 App Store 설명에 명확히 적어야 한다.

### 5.3 Xcode 프로젝트 전환

현재 Swift Package/Makefile 앱을 정식 Xcode macOS App target으로 옮긴다.

- Signing & Capabilities 설정
- App Sandbox 활성화
- Team과 Mac App Distribution 서명 설정
- App Store provisioning profile
- Release scheme과 Archive
- 메뉴 막대 앱의 카테고리·권한 문구·아이콘 확인
- sandbox 환경에서 모든 기능 재시험

### 5.4 App Store Connect 앱 레코드

빌드를 올리기 전에 App Store Connect에서 앱을 만든다.

필수 정보:

- 플랫폼: macOS
- 앱 이름: dhxk
- 기본 언어
- Bundle ID
- SKU
- 카테고리
- 설명, 키워드, 지원 URL, 개인정보 처리방침 URL
- 앱 아이콘과 스크린샷
- 연령 등급
- 앱 개인정보 설문
- 가격과 판매 지역

### 5.5 Archive·업로드·시험

1. Xcode에서 Generic Mac 또는 Any Mac 대상으로 Archive
2. Organizer → Distribute App
3. App Store Connect 선택
4. 검증 오류 해결 후 업로드
5. App Store Connect에서 빌드 처리 완료 확인
6. 내부·외부 시험 배포 경로 확인
7. 깨끗한 Mac에서 App Store/TestFlight 빌드 기능 확인

### 5.6 심사 제출

1. 앱 버전에 처리된 build 선택
2. 심사 메모에 Input Monitoring이 필요한 이유와 테스트 절차 작성
3. 권한 요청 화면과 실제 기능을 설명
4. Add for Review
5. Submit for Review
6. 거절 시 Resolution Center에서 답변하고 수정 build 제출

### 5.7 출시 후

- 리뷰와 충돌 보고 확인
- 판매·다운로드 지표 확인
- App Store판 업데이트는 App Store만 사용
- Bundle ID와 서명 Team 유지
- Full과 Lite의 기능 차이 문서 유지

## 6. 출시형 사용자 가이드

### 설치 전

- macOS 13 이상
- 두벌식 한글 입력 소스
- 손쉬운 사용과 입력 모니터링 권한 필요
- 입력은 서버로 전송되지 않음

### 3분 빠른 시작

1. 공식 GitHub Release에서 `dhxk-버전-universal.zip`을 받는다.
2. 압축을 풀고 `dhxk.app`을 `/Applications`로 옮긴다.
3. Applications에서 dhxk를 실행한다.
4. 메뉴 막대의 `한↔영`을 클릭한다.
5. 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 dhxk를 켠다.
6. 입력 모니터링에서도 dhxk를 켠다.
7. 앱을 완전히 종료하고 다시 실행한다.
8. 메뉴에서 세 권한이 모두 `✓`인지 확인한다.
9. 처음에는 제안 모드로 시험한다.
10. TextEdit에서 `rlawlstn` 뒤에 공백을 입력한다.

### 메뉴 해석

- `자동 감지 켜기`: 현재 꺼져 있으므로 클릭하면 켜짐
- `자동 감지 끄기`: 현재 켜져 있음
- 제안 모드: 후보만 표시
- 자동수정 모드: 고신뢰 후보 즉시 교체
- 최근 변환 되돌리기: 마지막 변환 복구
- `⌘⌥Z`: 전역 즉시 되돌리기

### 개인정보와 보안

- 현재 단어만 메모리에 보관
- 서버/API 전송 없음
- 입력 내용 파일 저장 없음
- 비밀번호·인증·계정 필드에서 중단
- Terminal·IDE·원격 데스크톱 기본 제외
- 수락/되돌림 학습은 앱 종료 시 삭제
- 감지/모드 설정만 UserDefaults에 저장

### 문제 해결

권한을 켰는데 동작하지 않으면:

1. 메뉴에서 어느 항목이 `✗`인지 확인한다.
2. 입력 모니터링을 바꿨다면 앱을 재시작한다.
3. 이전 개발판 항목을 `–`로 제거한다.
4. `+`로 정확히 `/Applications/dhxk.app`을 추가한다.
5. 자동 감지가 켜져 있는지 확인한다.

상세 사용자 설명은 `USER_MANUAL.md`, 개인정보는 `PRIVACY.md`를 참조한다.

## 7. 출시 판단 체크포인트

### GitHub Pre-release 가능 조건

- [x] Universal 2 자동 빌드
- [x] 275개 자동 테스트
- [x] 앱 아이콘·사용자·배포·개인정보 문서
- [ ] Developer ID 인증서
- [ ] production Bundle ID
- [ ] Apple 공증과 staple
- [ ] 깨끗한 Intel/Apple Silicon Mac 시험
- [ ] 공개 지원 URL·이메일
- [ ] GitHub 저장소와 최초 tag

### Mac App Store 제출 가능 조건

- [ ] sandbox용 Lite 기능 명세 확정
- [ ] AX 자동 교체 제거 또는 Apple이 허용하는 대체 구조 확정
- [ ] Xcode App target과 App Sandbox
- [ ] Mac App Distribution 서명
- [ ] App Store Connect metadata·privacy·screenshots
- [ ] sandbox 빌드 전 앱 회귀 시험
- [ ] App Review 제출

## 공식 근거

- [Apple Developer Program 비용](https://developer.apple.com/programs/whats-included/)
- [Apple App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
- [Apple Sandbox 금지 활동](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple App Store Connect workflow](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow)
- [Apple 앱 레코드 생성](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)
- [Apple 빌드 업로드](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [Apple 심사 제출](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/)
- [GitHub Free 가격](https://github.com/pricing)
- [GitHub Releases 용량과 대역폭](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
