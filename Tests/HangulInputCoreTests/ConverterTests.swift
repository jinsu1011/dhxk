import HangulInputCore

func runConverterTests(_ suite: TestSuite) {
    suite.expect(DubeolsikConverter.englishKeysToHangul("ghdrlfehd") == "홍길동", "ghdrlfehd → 홍길동")
    suite.expect(DubeolsikConverter.englishKeysToHangul("dkssudgktpdy") == "안녕하세요", "dkssudgktpdy → 안녕하세요")
    suite.expect(DubeolsikConverter.englishKeysToHangul("gksrmf") == "한글", "gksrmf → 한글")
    suite.expect(DubeolsikConverter.englishKeysToHangul("EMldjTMrlsk") == "띄어쓰기나", "일반 대문자 혼합: EMldjTMrlsk → 띄어쓰기나")
    suite.expect(DubeolsikConverter.englishKeysToHangul("TMaus") == "쓰면", "일반 대문자 혼합: TMaus → 쓰면")
    suite.expect(DubeolsikConverter.englishKeysToHangul("DKSSUDGKTPDY") == "안녕하세요", "Caps Lock 전체 대문자 → 안녕하세요")
    suite.expect(DubeolsikConverter.englishKeysToHangul("hello") == "ㅗ디ㅣㅐ", "hello 물리 키 → ㅗ디ㅣㅐ")
    suite.expect(DubeolsikConverter.hangulToEnglishKeys("ㅗ디ㅣㅐ") == "hello", "ㅗ디ㅣㅐ → hello")

    for keys in ["rlawlstn", "dkssudgktpdy", "gksrmf", "RkR", "rhk", "rhks", "rkqt"] {
        suite.expect(DubeolsikConverter.hangulToEnglishKeys(DubeolsikConverter.englishKeysToHangul(keys)) == keys, "round trip: \(keys)")
    }
    suite.expect(DubeolsikConverter.englishKeysToHangul("rhk") == "과", "복합 모음 ㅘ")
    suite.expect(DubeolsikConverter.englishKeysToHangul("rkqt") == "값", "겹받침 ㅄ")
    suite.expect(DubeolsikConverter.englishKeysToHangul("rkrk") == "가가", "받침 이동")
    suite.expect(DubeolsikConverter.isConvertibleEnglish("EMldjTMrlsk"), "일반 대문자 혼합 변환 가능")
}
