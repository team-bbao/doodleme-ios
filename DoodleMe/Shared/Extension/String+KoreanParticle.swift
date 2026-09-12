//
//  String+KoreanParticle.swift
//  DoodleMe
//

/// 이름 뒤에 붙는 조사를 받침에 맞춰 고른다.
///
/// 내보내기 카드 제목이 「**에리카**가 그린」·「**케빈**이 그린」 처럼 이름을 앞세우는데,
/// 조사를 하나로 못박으면 이름에 따라 「케빈가 그린」 같은 말이 나온다.
/// Figma 의 예시 이름(에리카·제이)이 모두 받침이 없어 드러나지 않았을 뿐이다.
extension String {

    /// 주격 조사. 받침이 있으면 「이」, 없으면 「가」.
    var subjectParticle: String {
        hasFinalConsonant ? "이" : "가"
    }

    /// 마지막 글자에 받침이 있는지.
    ///
    /// 한글은 글자 코드로 바로 안다 — 완성형 한 글자는 초성·중성·종성이 28 주기로 배열돼 있어
    /// `(코드 - 가) % 28` 이 0 이 아니면 종성이 있다.
    ///
    /// 로마자 이름은 코드로 알 수 없어 **소리 나는 대로** 본다.
    /// 「Kevin」 은 ㄴ 으로 끝나 「Kevin이」, 「Mina」 는 모음으로 끝나 「Mina가」 가 자연스럽다.
    /// 숫자나 기호로 끝나면 읽는 법이 사람마다 달라 받침 없는 쪽으로 둔다 — 「가」 가 덜 어색하다.
    private var hasFinalConsonant: Bool {
        guard let last = unicodeScalars.last else { return false }

        if (0xAC00 ... 0xD7A3).contains(last.value) {
            return (last.value - 0xAC00) % 28 != 0
        }

        let letter = Character(last).lowercased()
        guard let ascii = letter.first, ascii.isLetter else { return false }
        return !"aeiouy".contains(ascii)
    }
}
