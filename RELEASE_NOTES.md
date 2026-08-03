# dhxk 0.3.1 SKALA 파일럿

이 버전은 SKALA 참여자 전용 **무료 ad-hoc Pre-release**다. Apple Developer ID 서명과 공증을 받지 않았으므로 macOS가 개발자를 확인할 수 없으며, 사용자가 최초 실행을 직접 승인해야 한다. SKALA 파일럿 참여자가 아니라면 설치하거나 등록 정보를 제출하지 않는다.

## 주요 기능

- 영문 키 위치 오입력을 두벌식 한글로 복원
- 한글 상태에서 입력한 영문 키 위치를 영어로 복원
- 혼합 대문자와 Caps Lock 입력 지원
- 제안 모드와 자동수정 모드
- `⌘⌥Z` 즉시 되돌리기
- Apple Silicon과 Intel을 지원하는 Universal 2 앱
- SKALA 파일럿 최초 실행 시 캠퍼스·반·이름 등록
- 실제 입력 단어와 작성 문서는 서버로 전송하지 않고 Mac 안에서 처리
- 포커스된 일반 텍스트 요소를 확인할 수 없으면 자동 감지를 차단
- Accessibility 전체 문서 대신 caret 앞 최대 256 UTF-16 범위만 확인
- 등록 중복 방지, 허용 필드 고정, 일일 500건 상한 적용

## 설치

1. Release 자산의 `dhxk-0.3.1-skala-universal-adhoc.zip`과 `.sha256` 파일을 받는다.
2. SHA-256이 `.sha256` 파일의 값과 같은지 확인한다.
3. ZIP을 풀고 `dhxk.app`을 `/Applications`로 옮긴다.
4. 앱을 한 번 실행해 macOS 차단 메시지를 확인한다.
5. 시스템 설정 → 개인정보 보호 및 보안에서 `그래도 열기`를 누르고 다시 실행한다.
6. 손쉬운 사용과 입력 모니터링 권한을 허용한 뒤 앱을 재시작한다.

상세 절차는 [사용자 매뉴얼](https://github.com/jinsu1011/dhxk/blob/v0.3.1/USER_MANUAL.md)을 따른다. 최초 등록 전에 [개인정보 처리 안내](https://github.com/jinsu1011/dhxk/blob/v0.3.1/PRIVACY.md)를 확인한다.

## 보안과 제한

- 이 앱은 Apple이 공증한 배포본이 아니며 Gatekeeper에서 자동 승인되지 않는다.
- GitHub의 공식 `jinsu1011/dhxk` Release와 SHA-256을 확인한 경우에만 수동으로 허용한다.
- 업데이트하면 손쉬운 사용과 입력 모니터링 권한을 다시 요구할 수 있다.
- 로그인·결제·인증 화면에서는 자동 감지를 끄는 것을 권장하며, AX 포커스 요소를 확인할 수 없으면 앱이 자동으로 차단한다.
- Terminal, IDE, 원격 데스크톱은 기본 제외 대상이다.
- SKALA 파일럿 등록 정보는 캠퍼스·반·이름이며 입력 내용은 등록 요청에 포함되지 않는다.

## 빌드 정보

- 버전: `0.3.1 (5)`
- Bundle ID: `com.jinsu1011.dhxk`
- 최소 macOS: 13.0
- 아키텍처: `arm64`, `x86_64`
- 서명: ad-hoc, 미공증
- SHA-256: `df3ebc550ada03469a9683d4ecedc641bae5f8673877fa825ca23bc6339ecdee`
