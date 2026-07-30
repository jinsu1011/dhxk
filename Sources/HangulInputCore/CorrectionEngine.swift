import Foundation

public enum InputDirection: Sendable { case englishToKorean, koreanToEnglish }
public enum CorrectionMode: String, Sendable { case suggestion, automatic }

public struct CorrectionDecision: Equatable, Sendable {
    public let original: String
    public let replacement: String
    public let confidence: Double
    public let reasons: [String]
    public let shouldAutoCorrect: Bool

    public init(original: String, replacement: String, confidence: Double, reasons: [String], shouldAutoCorrect: Bool) {
        self.original = original
        self.replacement = replacement
        self.confidence = confidence
        self.reasons = reasons
        self.shouldAutoCorrect = shouldAutoCorrect
    }
}

public struct LexicalEvidence: Equatable, Sendable {
    public let originalKnown: Bool
    public let replacementKnown: Bool
    public let learnedInSession: Bool

    public init(originalKnown: Bool = false, replacementKnown: Bool = false, learnedInSession: Bool = false) {
        self.originalKnown = originalKnown
        self.replacementKnown = replacementKnown
        self.learnedInSession = learnedInSession
    }
}

public struct LanguageScorer: Sendable {
    private let commonSurnames = Set("김이박최정강조윤장임한오서신권황안송전홍유고문양손배백허남심노하곽성차주우구민진지엄채원천방공현함변염여추도소석선설마길연위표명기반왕금옥육인맹제모탁국어은편용예경봉사부가복태목두")
    private let commonKoreanEndings = [
        "하다", "한다", "했다", "됩니다", "입니다", "있다", "없다", "같다",
        "아요", "어요", "네요", "까요", "세요", "습니다", "했다", "한다",
        "에서", "에게", "으로", "부터", "까지", "처럼", "보다", "하고",
        "합니다", "했습니다", "하였습니다", "되었습니다", "드립니다", "바랍니다",
        "예정입니다", "필요합니다", "가능합니다", "부탁드립니다", "확인해주세요",
        "검토해주세요", "공유드립니다", "전달드립니다", "첨부합니다", "완료했습니다",
    ]
    private let koreanWords: Set<String> = [
        "안녕", "안녕하세요", "감사", "감사합니다", "고마워", "죄송합니다", "괜찮아요",
        "한글", "한국", "한국어", "영어", "사람", "친구", "가족", "사랑", "마음",
        "오늘", "내일", "어제", "지금", "시간", "아침", "점심", "저녁", "주말",
        "학교", "학생", "선생님", "회사", "회의", "업무", "일정", "계획", "프로젝트",
        "문서", "파일", "폴더", "사진", "영상", "음악", "메시지", "메일", "전화",
        "컴퓨터", "노트북", "키보드", "화면", "인터넷", "프로그램", "앱", "코드",
        "입력", "변환", "수정", "확인", "설정", "실행", "종료", "저장", "삭제",
        "시작", "완료", "성공", "실패", "문제", "방법", "결과", "내용", "정보",
        "좋아요", "맞아요", "아니요", "네", "가능", "필요", "중요", "안전",
        "서울", "부산", "대한민국", "홍길동",
        "검토", "요청", "전달", "공유", "첨부", "회신", "답변", "의견", "문의",
        "진행", "현황", "목표", "목적", "배경", "개요", "분석", "설계", "구현",
        "평가", "개선", "제안", "기준", "범위", "항목", "담당", "마감", "승인",
        "결재", "협의", "자료", "보고서", "발표", "회의록", "과제", "연구", "실험",
        "데이터", "표", "그림", "참고", "결론", "요약", "기대효과", "문제점",
        "해결방안", "추후", "향후", "예정", "제출", "작성", "반영", "수정사항",
        "요구사항", "세부사항", "주요내용", "진행상황", "업무보고", "검토결과",
        "프로세스", "시스템", "기능", "품질", "성능", "효율", "비용", "예산",
        "기간", "단계", "담당자", "참석자", "관련자", "사용자", "고객", "기관",
        "교육", "행사", "신청", "접수", "지원", "운영", "관리", "정책", "절차",
        "확인했습니다", "검토했습니다", "완료했습니다", "진행하겠습니다", "공유드립니다",
        "전달드립니다", "첨부합니다", "요청드립니다", "부탁드립니다", "감사드립니다",
        "확인해주세요", "검토해주세요", "참고해주세요", "회신부탁드립니다",
        "띄어쓰기", "대문자", "소문자", "문장", "단어", "표현", "맞춤법", "번역",
        "작성자", "수신자", "발신자", "제목", "본문", "목차", "서론", "본론",
        "일시", "장소", "안건", "공지", "알림", "질문", "응답", "설명", "예시",
        "원인", "해결", "조치", "점검", "확정", "취소", "변경", "추가", "제외",
        "등록", "접속", "로그인", "다운로드", "업로드", "설치", "배포", "업데이트",
        "버전", "권한", "보안", "개인정보", "접근성", "모니터링", "네트워크", "서버",
        "서비스", "웹사이트", "브라우저", "데이터베이스", "백업", "복구", "동기화",
        "개발", "테스트", "릴리스", "운영환경", "개발환경", "소스코드", "저장소",
        "오류", "버그", "장애", "로그", "디버그", "검증", "최적화", "호환성",
        "매출", "수익", "가격", "결제", "구매", "판매", "주문", "배송", "환불",
        "계약", "견적", "세금", "회계", "재무", "마케팅", "홍보", "성과", "지표",
        "채용", "면접", "직원", "부서", "팀원", "대표", "관리자", "책임자", "연락처",
        "수업", "강의", "시험", "학습", "공부", "교재", "교육과정", "수료", "출석",
        "건강", "병원", "예약", "상담", "여행", "교통", "출발", "도착", "주소",
        "날씨", "음식", "카페", "생활", "문화", "뉴스", "경제", "사회", "과학",
        "추천", "선택", "비교", "검색", "발견", "사용법", "가이드", "매뉴얼", "도움말",
        "작성합니다", "확인합니다", "진행합니다", "수정합니다", "반영합니다", "검토드립니다",
        "확인바랍니다", "참고바랍니다", "회신바랍니다", "전달해주세요", "공유해주세요",
        "수정해주세요", "추가해주세요", "삭제해주세요", "진행해주세요", "완료해주세요",
    ]
    private let englishWords: Set<String> = [
        "hello", "world", "thanks", "thank", "sorry", "please", "yes", "no", "okay",
        "apple", "swift", "keyboard", "input", "english", "korean", "hangul", "mac",
        "computer", "laptop", "screen", "message", "email", "phone", "internet", "program",
        "application", "project", "document", "file", "folder", "photo", "video", "music",
        "start", "finish", "complete", "success", "failure", "problem", "result", "information",
        "today", "tomorrow", "yesterday", "morning", "afternoon", "evening", "weekend",
        "school", "student", "teacher", "company", "meeting", "schedule", "plan", "work",
        "create", "update", "delete", "save", "open", "close", "run", "build", "test",
        "good", "great", "important", "safe", "possible", "required", "help", "check",
        "review", "request", "reply", "response", "share", "attach", "attachment", "submit",
        "report", "summary", "overview", "background", "purpose", "objective", "analysis",
        "design", "implementation", "evaluation", "improvement", "proposal", "requirement",
        "status", "progress", "deadline", "approval", "budget", "quality", "performance",
        "reference", "conclusion", "issue", "solution", "feedback", "agenda", "minutes",
        "about", "after", "again", "against", "almost", "along", "already", "also",
        "always", "another", "answer", "around", "because", "before", "between", "both",
        "business", "change", "chapter", "common", "community", "contact", "continue",
        "control", "course", "customer", "daily", "department", "detail", "different",
        "during", "each", "early", "education", "example", "experience", "first", "following",
        "future", "general", "group", "health", "history", "however", "include", "increase",
        "individual", "industry", "language", "large", "later", "level", "local", "market",
        "member", "month", "necessary", "number", "office", "order", "other", "people",
        "point", "policy", "process", "provide", "question", "reason", "research", "service",
        "several", "should", "simple", "small", "something", "special", "specific", "support",
        "system", "together", "under", "understand", "until", "value", "version", "without",
        "action", "activity", "address", "available", "benefit", "category", "condition",
        "decision", "description", "development", "effect", "environment", "feature", "function",
        "goal", "guide", "method", "option", "organization", "priority", "resource", "risk",
        "section", "standard", "strategy", "task", "team", "technology", "topic", "training",
        "account", "calendar", "call", "chat", "comment", "communication", "confirm", "copy",
        "download", "edit", "event", "form", "link", "login", "name", "note", "notification",
        "page", "password", "profile", "search", "send", "sign", "upload", "website", "window",
        "accept", "add", "allow", "apply", "choose", "compare", "connect", "correct", "define",
        "deliver", "discuss", "display", "enable", "explain", "find", "follow", "generate",
        "improve", "install", "manage", "move", "prepare", "publish", "receive", "remove",
        "replace", "select", "show", "verify", "write", "read", "learn", "study", "practice",
        "data", "database", "server", "client", "network", "security", "privacy", "access",
        "source", "target", "model", "interface", "user", "product", "release", "branch",
        "commit", "deploy", "package", "library", "framework", "developer", "production",
        "manager", "director", "employee", "partner", "contract", "payment", "price", "cost",
        "sales", "finance", "legal", "operation", "marketing", "table", "figure", "appendix",
        "introduction", "discussion", "recommendation", "schedule", "participant", "owner",
        "high", "low", "big", "long", "short", "new", "old", "right", "wrong", "current", "final",
        "main", "next", "previous", "real", "public", "private", "ready", "recent", "clear",
        "quick", "easy", "hard", "better", "best", "available", "successful", "useful",
        "word", "sentence", "paragraph", "title", "body", "author", "recipient", "sender",
        "spelling", "grammar", "translation", "uppercase", "lowercase", "capital", "typing",
        "documenting", "writing", "draft", "template", "format", "content", "context", "example",
        "cause", "resolution", "fix", "change", "addition", "exclusion", "registration", "connection",
        "browser", "repository", "backup", "restore", "synchronize", "permission", "monitoring",
        "error", "bug", "incident", "debug", "validation", "optimization", "compatibility",
        "revenue", "profit", "purchase", "sale", "shipping", "refund", "invoice", "tax",
        "accounting", "financial", "campaign", "promotion", "metric", "achievement", "recruitment",
        "interview", "staff", "department", "leader", "administrator", "responsibility", "location",
        "lesson", "lecture", "exam", "learning", "textbook", "curriculum", "attendance", "certificate",
        "hospital", "appointment", "consultation", "travel", "transportation", "departure", "arrival",
        "weather", "restaurant", "culture", "news", "economy", "science", "discovery", "manual",
        "documentation", "configuration", "deployment", "distribution", "notarization", "signature",
        "automation", "integration", "migration", "maintenance", "availability", "reliability",
        "architecture", "component", "module", "dependency", "protocol", "platform", "device",
        "desktop", "mobile", "storage", "memory", "processor", "application", "workspace",
        "planning", "reporting", "reviewer", "assignee", "milestone", "workflow", "scenario",
        "expected", "actual", "resolved", "pending", "approved", "rejected", "enabled", "disabled",
        "working", "running", "installed", "published", "verified", "completed", "failed",
    ]

    public init() {}

    public func koreanScore(_ text: String) -> Double {
        guard !text.isEmpty else { return 0 }
        let syllables = text.filter { $0.unicodeScalars.allSatisfy { (0xAC00...0xD7A3).contains(Int($0.value)) } }.count
        let ratio = Double(syllables) / Double(text.count)
        let incomplete = text.filter { $0.unicodeScalars.allSatisfy { (0x3130...0x318F).contains(Int($0.value)) } }.count
        var score = ratio * 3.0 - Double(incomplete) * 0.7
        let isCompleteHangul = syllables == text.count && incomplete == 0
        if isCompleteHangul && (2...16).contains(text.count) { score += 0.7 }
        if isCompleteHangul && (2...4).contains(text.count), let first = text.first, commonSurnames.contains(first) {
            score += 2.0
        }
        if isCompleteHangul && commonKoreanEndings.contains(where: { text.hasSuffix($0) }) { score += 0.8 }
        if koreanWords.contains(text) { score += 3.0 }
        return score
    }

    public func englishScore(_ text: String) -> Double {
        let lower = text.lowercased()
        guard lower.allSatisfy({ $0.isASCII && $0.isLetter }), !lower.isEmpty else { return -2 }
        var vowelCount = 0
        var vowelRun = 0
        var consonantRun = 0
        var longestVowelRun = 0
        var longestConsonantRun = 0
        for character in lower {
            if "aeiou".contains(character) {
                vowelCount += 1
                vowelRun += 1
                consonantRun = 0
                longestVowelRun = max(longestVowelRun, vowelRun)
            } else {
                consonantRun += 1
                vowelRun = 0
                longestConsonantRun = max(longestConsonantRun, consonantRun)
            }
        }
        var score = vowelCount > 0 ? 1.0 : -1.0
        if englishWords.contains(lower) { score += 5.2 }
        else if derivedEnglishBase(for: lower) != nil { score += 4.6 }
        if longestConsonantRun >= 5 { score -= 1.5 }
        if longestVowelRun >= 4 { score -= 1.0 }
        return score
    }

    private func derivedEnglishBase(for word: String) -> String? {
        var candidates: [String] = []
        if word.hasSuffix("ies"), word.count > 4 { candidates.append(String(word.dropLast(3)) + "y") }
        if word.hasSuffix("es"), word.count > 4 { candidates.append(String(word.dropLast(2))) }
        if word.hasSuffix("s"), word.count > 3 { candidates.append(String(word.dropLast())) }
        if word.hasSuffix("ed"), word.count > 4 {
            candidates.append(String(word.dropLast(2)))
            candidates.append(String(word.dropLast()))
        }
        if word.hasSuffix("ing"), word.count > 5 {
            let stem = String(word.dropLast(3))
            candidates.append(stem)
            candidates.append(stem + "e")
            if let last = stem.last, stem.dropLast().last == last { candidates.append(String(stem.dropLast())) }
        }
        if word.hasSuffix("ly"), word.count > 4 { candidates.append(String(word.dropLast(2))) }
        if word.hasSuffix("er"), word.count > 4 { candidates.append(String(word.dropLast(2))) }
        if word.hasSuffix("er"), word.count > 4 {
            let stem = String(word.dropLast(2))
            if let last = stem.last, stem.dropLast().last == last { candidates.append(String(stem.dropLast())) }
        }
        if word.hasSuffix("est"), word.count > 5 {
            let stem = String(word.dropLast(3))
            candidates.append(stem)
            if let last = stem.last, stem.dropLast().last == last { candidates.append(String(stem.dropLast())) }
        }
        return candidates.first(where: englishWords.contains)
    }
}

public struct CorrectionEngine: Sendable {
    public var minimumLength = 3
    public var automaticThreshold = 3.2
    public var minimumMargin = 2.2
    private let scorer = LanguageScorer()

    public init() {}

    public func candidate(for token: String, direction: InputDirection) -> String? {
        guard !Self.isExcludedToken(token) else { return nil }
        switch direction {
        case .englishToKorean:
            guard token.count >= minimumLength,
                  DubeolsikConverter.isConvertibleEnglish(token) else { return nil }
            return DubeolsikConverter.englishKeysToHangul(token)
        case .koreanToEnglish:
            let replacement = DubeolsikConverter.hangulToEnglishKeys(token)
            return replacement.count >= minimumLength ? replacement : nil
        }
    }

    public func evaluate(
        _ token: String,
        direction: InputDirection,
        lexicalEvidence: LexicalEvidence = LexicalEvidence()
    ) -> CorrectionDecision? {
        guard !Self.isExcludedToken(token) else { return nil }
        let replacement: String
        var before: Double
        var after: Double
        switch direction {
        case .englishToKorean:
            guard token.count >= minimumLength,
                  DubeolsikConverter.isConvertibleEnglish(token) else { return nil }
            replacement = DubeolsikConverter.englishKeysToHangul(token)
            before = scorer.englishScore(token)
            after = scorer.koreanScore(replacement)
        case .koreanToEnglish:
            replacement = DubeolsikConverter.hangulToEnglishKeys(token)
            guard replacement.count >= minimumLength else { return nil }
            before = scorer.koreanScore(token)
            after = scorer.englishScore(replacement)
        }
        guard replacement != token else { return nil }
        if lexicalEvidence.originalKnown { before += 2.0 }
        if lexicalEvidence.replacementKnown { after += 2.2 }
        if lexicalEvidence.learnedInSession { after += 3.0 }
        let margin = after - before
        let confidence = min(1, max(0, (margin + 1) / 6))
        var reasons = ["변환 후 자연스러움 점수 차이 \(String(format: "%.2f", margin))"]
        if lexicalEvidence.originalKnown { reasons.append("원문이 시스템 사전에 존재") }
        if lexicalEvidence.replacementKnown { reasons.append("변환 결과가 시스템 사전에 존재") }
        if lexicalEvidence.learnedInSession { reasons.append("현재 실행에서 사용자가 수락한 변환") }
        if after >= automaticThreshold { reasons.append("변환 결과가 고신뢰 임계값 통과") }
        return CorrectionDecision(
            original: token, replacement: replacement, confidence: confidence,
            reasons: reasons, shouldAutoCorrect: after >= automaticThreshold && margin >= minimumMargin
        )
    }

    public static func isExcludedToken(_ token: String) -> Bool {
        if token.contains("://") || token.contains("@") || token.contains("/") || token.contains("\\") { return true }
        if token.contains(".") && token.range(of: #"^[A-Za-z0-9._-]+\.[A-Za-z0-9]{1,8}$"#, options: .regularExpression) != nil { return true }
        if token.allSatisfy({ $0.isNumber || "-+().".contains($0) }) { return true }
        if token.range(of: #"[_{}\[\]();=<>]"#, options: .regularExpression) != nil { return true }
        return false
    }
}
