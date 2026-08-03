# SKALA 등록 시트 연결 매뉴얼

## 수집 범위

SKALA 내부 파일럿 빌드는 최초 실행 때 동의를 받은 뒤 `캠퍼스`, `반`, `이름`, 앱 버전, 동의문 버전과 서버 수신 시각을 한 번 전송한다. 키 입력, 작성 문서, 전화번호, 이메일, 기기 식별자는 전송하지 않는다. 앱은 Mac에 개인정보를 보관하지 않고 등록 완료 여부만 `UserDefaults`에 저장한다.

운영 전 SKALA 담당자에게 Google Workspace/Google Sheets 사용과 보유기간 승인을 받아야 한다. 개인 Google 계정보다는 기관이 관리하는 계정을 사용한다.

## 1. Google Sheet와 Web App 만들기

1. 운영용 Google 계정에서 새 스프레드시트를 만들고 이름을 `dhxk SKALA 등록`으로 지정한다.
2. **확장 프로그램 → Apps Script**를 연다.
3. 기본 `Code.gs` 내용을 프로젝트의 `Backend/GoogleAppsScript/Code.gs`로 교체한다.
4. **프로젝트 설정 → 매니페스트 파일 표시**를 켜고 `appsscript.json`도 프로젝트 파일과 동일하게 맞춘다.
5. **배포 → 새 배포 → 유형 선택 → 웹 앱**을 선택한다.
6. 실행 사용자는 **나**, 액세스 사용자는 파일럿 참가자가 로그인 없이 호출할 수 있는 범위로 설정한다. 개인 계정 UI에서는 `모든 사용자`로 보일 수 있다. 기관 정책이 이를 막으면 SKALA 승인 백엔드를 사용해야 한다.
7. 배포하고 Google 권한 화면을 승인한 뒤 `/exec`로 끝나는 웹 앱 URL을 복사한다.

코드 변경 뒤에는 **배포 관리 → 수정 → 새 버전 → 배포**가 필요하다. 편집기 저장만으로 기존 `/exec` 배포가 갱신되지는 않는다.

## 2. 연결 전 단독 시험

아래에서 URL만 실제 `/exec` 주소로 바꾼다.

```bash
curl -L 'https://script.google.com/macros/s/DEPLOYMENT_ID/exec' \
  -H 'Content-Type: application/json' \
  --data '{"campus":"판교캠퍼스","classNumber":1,"name":"테스트","appVersion":"0.3.1","consentVersion":"2026-07-30-v1"}'
```

응답이 `{"ok":true}`이고 시트의 `등록` 탭에 한 행이 추가되어야 한다. 시험 행은 확인 후 직접 삭제한다.

`-X POST`를 강제로 넣으면 Google의 302 결과 주소에도 POST가 유지되어 오류 페이지가 나올 수 있다. `--data`가 최초 요청을 POST로 만들고 `-L`이 결과 주소를 GET으로 따라가게 둔다.

## 3. SKALA용 앱 빌드

```bash
SKALA_REGISTRATION_REQUIRED=true \
REGISTRATION_ENDPOINT='https://script.google.com/macros/s/DEPLOYMENT_ID/exec' \
VERSION=0.3.1 BUILD_NUMBER=5 \
make universal
```

`release/dhxk.app`의 설정을 확인한다.

```bash
defaults read "$PWD/release/dhxk.app/Contents/Info" SKALARegistrationRequired
defaults read "$PWD/release/dhxk.app/Contents/Info" SKALARegistrationEndpoint
```

실제 배포에서는 위 명령에 Developer ID `SIGNING_IDENTITY`와 production `BUNDLE_ID`를 함께 지정하고 공증한다. URL은 앱 번들에서 확인할 수 있으므로 비밀 키가 아니다. 백엔드는 항상 값 검증과 최소 권한을 유지해야 한다.

## 4. 운영과 삭제

- 동일 캠퍼스·반·이름은 중복 행을 만들지 않고 성공으로 처리한다.
- 서버는 하루 최대 500개의 새 등록만 허용한다. 이 제한은 오염 완화 수단이며 사용자 인증을 대체하지 않는다.
- Sheet 공유 대상을 최소 운영자로 제한하고 공개 링크 공유를 금지한다.
- 보유기간 종료 시 전체 파일을 휴지통으로 이동하는 것만으로 끝내지 말고 휴지통에서도 삭제한 뒤 삭제 일자를 운영 기록에 남긴다.
- 교육 종료일이 정해지면 사용자 고지의 `종료 후 30일`과 실제 삭제 일정을 일치시킨다.
- 참여자가 정정·삭제를 요청할 연락처를 배포 전에 `PRIVACY.md`와 앱 안내에 넣는다.
- 공개 URL 스팸, 중복 등록, 인원 증가가 예상되면 Apps Script 대신 인증된 SKALA 관리 서버로 이전한다.
