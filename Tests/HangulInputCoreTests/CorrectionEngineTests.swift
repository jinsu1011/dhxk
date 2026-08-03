import HangulInputCore

func runCorrectionEngineTests(_ suite: TestSuite) {
    let engine = CorrectionEngine()
    suite.expect(engine.evaluate("ghdrlfehd", direction: .englishToKorean)?.replacement == "홍길동", "판정 결과 홍길동")
    suite.expect(engine.evaluate("dkssudgktpdy", direction: .englishToKorean)?.shouldAutoCorrect == true, "안녕하세요 고신뢰")
    suite.expect(engine.evaluate("gksrmf", direction: .englishToKorean)?.shouldAutoCorrect == true, "한글 고신뢰")
    suite.expect(engine.evaluate("EMldjTMrlsk", direction: .englishToKorean)?.replacement == "띄어쓰기나", "대문자 혼합 판정")
    suite.expect(engine.evaluate("TMaus", direction: .englishToKorean)?.replacement == "쓰면", "대문자 일반키 판정")

    suite.expect(
        ReplacementTokenValidator.exactDisplayedToken(
            rawKeys: "dkssudgktpdy", displayedToken: "dkssudgktpdy", direction: .englishToKorean
        ) == "dkssudgktpdy",
        "영문→한글 표시 토큰 완전 일치 허용"
    )
    suite.expect(
        ReplacementTokenValidator.exactDisplayedToken(
            rawKeys: "dkssudgktpdy", displayedToken: "kssudgktpdy", direction: .englishToKorean
        ) == nil,
        "Chrome 한 글자 지연 표시 토큰 부분 교체 차단"
    )
    suite.expect(
        ReplacementTokenValidator.exactDisplayedToken(
            rawKeys: "hello", displayedToken: "ㅗ디ㅣㅐ", direction: .koreanToEnglish
        ) == "ㅗ디ㅣㅐ",
        "한글→영문 표시 토큰 완전 일치 허용"
    )
    suite.expect(
        ReplacementTokenValidator.exactDisplayedToken(
            rawKeys: "hello", displayedToken: "디ㅣㅐ", direction: .koreanToEnglish
        ) == nil,
        "한글 IME 부분 표시 토큰 교체 차단"
    )

    for token in ["test", "hello", "https://openai.com", "me@example.com", "/tmp/file", "foo.swift", "123456", "some_var"] {
        let decision = engine.evaluate(token, direction: .englishToKorean)
        suite.expect(decision?.shouldAutoCorrect != true, "제외/보수 판정: \(token)")
    }

    let mistyped = DubeolsikConverter.englishKeysToHangul("hello")
    let decision = engine.evaluate(mistyped, direction: .koreanToEnglish)
    suite.expect(decision?.replacement == "hello", "한글 입력 상태에서 hello 복원")
    suite.expect(decision?.shouldAutoCorrect == true, "hello 복원 고신뢰")

    let expandedWord = engine.evaluate(
        "tjddls",
        direction: .englishToKorean,
        lexicalEvidence: LexicalEvidence(replacementKnown: true)
    )
    suite.expect(expandedWord?.replacement == "성인", "시스템 사전 기반 신규 한국어 후보")
    suite.expect(expandedWord?.shouldAutoCorrect == true, "시스템 사전 후보 신뢰도 상승")

    let protectedEnglish = engine.evaluate(
        "message",
        direction: .englishToKorean,
        lexicalEvidence: LexicalEvidence(originalKnown: true)
    )
    suite.expect(protectedEnglish?.shouldAutoCorrect != true, "시스템 사전 영어 원문 보호")

    let unlearned = engine.evaluate("kdk", direction: .englishToKorean)
    let learned = engine.evaluate(
        "kdk",
        direction: .englishToKorean,
        lexicalEvidence: LexicalEvidence(learnedInSession: true)
    )
    suite.expect(unlearned?.shouldAutoCorrect != true, "미학습 저신뢰 후보 보존")
    suite.expect(learned?.shouldAutoCorrect == true, "세션 수락 변환 학습")

    for (keys, expected) in [
        ("wlstn", "진수"),
        ("alswl", "민지"),
        ("rkdgh", "강호"),
        ("qkralswns", "박민준"),
        ("chldbsdk", "최윤아"),
    ] {
        let nameDecision = engine.evaluate(keys, direction: .englishToKorean)
        suite.expect(nameDecision?.replacement == expected, "일반 이름 변환: \(expected)")
        suite.expect(nameDecision?.shouldAutoCorrect == true, "일반 이름 자동판정: \(expected)")
    }

    for keys in ["tkfka", "akdma", "tkscor", "rPghlr"] {
        let koreanShaped = engine.evaluate(keys, direction: .englishToKorean)
        suite.expect(koreanShaped?.replacement != nil, "완성형 한글 후보 생성: \(keys)")
        suite.expect(koreanShaped?.shouldAutoCorrect == true, "완성형 한글 형태 자동판정: \(keys)")
    }

    for english in ["github", "notion", "slack", "openai"] {
        let protected = engine.evaluate(
            english,
            direction: .englishToKorean,
            lexicalEvidence: LexicalEvidence(originalKnown: true)
        )
        suite.expect(protected?.shouldAutoCorrect != true, "정상 영어/브랜드 보호: \(english)")
    }

    for metadata in [
        ["아이디"], ["이메일 주소"], ["Username"], ["user_id_field"],
        ["Log in"], ["Account"], ["OTP"], ["PIN"], ["인증번호"], ["password-field"],
    ] {
        suite.expect(SensitiveFieldClassifier.metadataSuggestsAuthentication(metadata), "민감 필드 분류: \(metadata[0])")
    }
    for metadata in [["메시지를 입력하세요"], ["문서 본문"], ["Search results description"]] {
        suite.expect(!SensitiveFieldClassifier.metadataSuggestsAuthentication(metadata), "일반 편집 필드 허용: \(metadata[0])")
    }

    for bundleID in [
        "com.google.Chrome", "com.openai.codex", "com.openai.chat",
        "com.anthropic.claudefordesktop", "com.google.antigravity",
        "com.kakao.KakaoTalkMac", "notion.id",
        "com.apple.Pages", "com.apple.iWork.Pages",
    ] {
        suite.expect(CompatibilityAppClassifier.supportsFallback(bundleIdentifier: bundleID), "호환 앱 분류: \(bundleID)")
    }
    for bundleID in ["com.anthropic.claudefordesktop", "com.google.antigravity"] {
        suite.expect(
            CompatibilityAppClassifier.requiresManualAccessibility(bundleIdentifier: bundleID),
            "Chromium 접근성 활성화 분류: \(bundleID)"
        )
        suite.expect(
            CompatibilityAppClassifier.prefersPasteReplacement(bundleIdentifier: bundleID),
            "Electron 붙여넣기 치환 우선: \(bundleID)"
        )
    }
    suite.expect(
        CompatibilityAppClassifier.requiresEnhancedAccessibility(bundleIdentifier: "com.google.Chrome"),
        "Chrome AXEnhancedUserInterface 활성화 분류"
    )
    suite.expect(
        CompatibilityAppClassifier.prefersSyntheticReplacement(bundleIdentifier: "com.google.Chrome"),
        "Chrome 합성키 치환 우선"
    )
    for bundleID in ["com.anthropic.claudefordesktop", "com.google.antigravity"] {
        suite.expect(
            !CompatibilityAppClassifier.prefersSyntheticReplacement(bundleIdentifier: bundleID),
            "Electron AX 치환 우선: \(bundleID)"
        )
    }
    suite.expect(
        !CompatibilityAppClassifier.prefersSyntheticReplacement(bundleIdentifier: "com.apple.TextEdit"),
        "네이티브 앱 AX 치환 유지"
    )
    suite.expect(
        !CompatibilityAppClassifier.prefersPasteReplacement(bundleIdentifier: "com.apple.TextEdit"),
        "네이티브 앱 붙여넣기 치환 제외"
    )
    suite.expect(
        !CompatibilityAppClassifier.requiresManualAccessibility(bundleIdentifier: "com.apple.TextEdit"),
        "네이티브 앱 Chromium 접근성 활성화 제외"
    )
    suite.expect(
        AccessibilityTextRoleClassifier.isEligible(
            role: "AXGroup", valueAvailable: true,
            selectedRangeSettable: true, selectedTextSettable: true
        ),
        "Chrome contenteditable AXGroup 허용"
    )
    suite.expect(
        !AccessibilityTextRoleClassifier.isEligible(
            role: "AXGroup", valueAvailable: true,
            selectedRangeSettable: false, selectedTextSettable: false
        ),
        "일반 AXGroup 차단"
    )
    for bundleID in ["com.apple.Terminal", "com.microsoft.VSCode", "unknown.app"] {
        suite.expect(!CompatibilityAppClassifier.supportsFallback(bundleIdentifier: bundleID), "위험/미확인 앱 대체 경로 차단: \(bundleID)")
    }

    for (keys, expected) in [
        ("rjaxh", "검토"), ("dycjd", "요청"), ("rhddb", "공유"),
        ("qhrhtj", "보고서"), ("gusghkd", "현황"), ("rPghlr", "계획"),
        ("qnstjr", "분석"), ("ruffhs", "결론"), ("dydir", "요약"),
    ] {
        let documentWord = engine.evaluate(keys, direction: .englishToKorean)
        suite.expect(documentWord?.replacement == expected, "문서 어휘 변환: \(expected)")
        suite.expect(documentWord?.shouldAutoCorrect == true, "문서 어휘 자동판정: \(expected)")
    }

    let commonEnglishWords = [
        "world", "computer", "keyboard", "document", "project", "meeting", "schedule",
        "report", "review", "request", "response", "summary", "analysis", "design",
        "implementation", "improvement", "requirement", "progress", "deadline", "quality",
        "performance", "reference", "conclusion", "feedback", "business", "customer",
        "education", "experience", "information", "organization", "technology", "security",
        "privacy", "database", "developer", "production", "communication", "recommendation",
        "download", "upload", "website", "application", "support", "available", "important",
    ]
    for english in commonEnglishWords {
        let koreanMistype = DubeolsikConverter.englishKeysToHangul(english)
        let restored = engine.evaluate(koreanMistype, direction: .koreanToEnglish)
        suite.expect(restored?.replacement == english, "일반 영어 복원: \(english)")
        suite.expect(restored?.shouldAutoCorrect == true, "일반 영어 자동판정: \(english)")
    }

    for english in ["reports", "requested", "reviewing", "quickly", "projects"] {
        let koreanMistype = DubeolsikConverter.englishKeysToHangul(english)
        let restored = engine.evaluate(koreanMistype, direction: .koreanToEnglish)
        suite.expect(restored?.replacement == english, "영어 굴절형 복원: \(english)")
        suite.expect(restored?.shouldAutoCorrect == true, "영어 굴절형 자동판정: \(english)")
    }

    let scorer = LanguageScorer()
    for korean in [
        "띄어쓰기", "대문자", "맞춤법", "배포", "업데이트", "접근성", "개인정보",
        "데이터베이스", "복구", "동기화", "소스코드", "호환성", "사용법", "매뉴얼",
        "확인바랍니다", "전달해주세요", "수정해주세요", "완료해주세요",
    ] {
        suite.expect(scorer.koreanScore(korean) >= 6.0, "확장 한국어 어휘 점수: \(korean)")
        let keys = DubeolsikConverter.hangulToEnglishKeys(korean)
        suite.expect(engine.evaluate(keys, direction: .englishToKorean)?.shouldAutoCorrect == true, "확장 한국어 자동판정: \(korean)")
    }

    for english in [
        "uppercase", "lowercase", "spelling", "grammar", "translation", "browser",
        "repository", "permission", "monitoring", "deployment", "distribution", "notarization",
        "architecture", "dependency", "workflow", "scenario", "published", "verified",
    ] {
        suite.expect(scorer.englishScore(english) >= 6.0, "확장 영어 어휘 점수: \(english)")
        let mistype = DubeolsikConverter.englishKeysToHangul(english)
        suite.expect(engine.evaluate(mistype, direction: .koreanToEnglish)?.shouldAutoCorrect == true, "확장 영어 자동판정: \(english)")
    }

    for inflected in ["running", "bigger", "biggest"] {
        let mistype = DubeolsikConverter.englishKeysToHangul(inflected)
        suite.expect(engine.evaluate(mistype, direction: .koreanToEnglish)?.shouldAutoCorrect == true, "겹자음 영어 굴절형: \(inflected)")
    }
}
