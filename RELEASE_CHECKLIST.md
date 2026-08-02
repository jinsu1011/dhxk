# dhxk Release Checklist

## 제품

- [x] production Bundle ID 확정 — `com.jinsu1011.dhxk`
- [x] 버전과 빌드 번호 증가 — 파일럿 `0.3.0 (4)`
- [ ] 지원 URL·개인정보 처리방침 URL 확인
- [x] Release notes 작성 — 무료 ad-hoc Pre-release와 Gatekeeper 수동 절차 명시
- [ ] SKALA 개인정보 처리 책임자·문의 채널·교육 종료일 확정
- [x] 기관 관리 Google Workspace/Sheet 사용 승인

## 품질

- [x] `make test` 통과 — Core 303/303 + backend 10/10
- [ ] 대문자·Caps Lock 회귀 예시 통과
- [ ] 영문→한글·한글→영어 수동 시험
- [ ] Chrome·Safari·ChatGPT·카카오톡·문서 앱 시험
- [ ] 비밀번호·ID·OTP·Secure Input 미동작 확인
- [ ] 되돌리기와 재귀 방지 확인
- [ ] 재시작 후 설정 유지 확인
- [ ] 최초 등록의 캠퍼스 3종·1~10반·이름 검증 확인
- [ ] 등록 성공 뒤 재실행 시 미표시, 실패 시 미완료 확인
- [ ] 키 입력·작성 문서가 등록 요청/시트에 포함되지 않음을 확인

## 빌드와 보안

- [x] Universal 2 확인 — ad-hoc ZIP 압축 해제본 `arm64` + `x86_64`
- [ ] Developer ID Application 서명 확인 — 유료 정식 배포로 연기
- [ ] Hardened Runtime 확인 — 유료 정식 배포로 연기
- [ ] Apple 공증 Accepted — 유료 정식 배포로 연기
- [ ] ticket staple 확인 — 유료 정식 배포로 연기
- [ ] Gatekeeper accepted 확인 — 무료 파일럿은 사용자 `그래도 열기` 필요
- [x] SHA-256 생성 — `0.3.0 (4)` SKALA ad-hoc Pre-release ZIP
- [x] production Apps Script `/exec` URL 삽입 및 시험 행 수신 확인

## 배포

- [ ] 깨끗한 Apple Silicon Mac 시험
- [ ] 깨끗한 Intel Mac 시험
- [ ] GitHub Pre-release 업로드
- [ ] 설치·권한·업데이트 문서 링크 확인
- [ ] 내부 시험 후 정식 Release 전환
- [ ] Sheet 공유 권한 최소화와 보유기간 삭제 일정 등록
