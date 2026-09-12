//
//  Array+Chunked.swift
//  DoodleMe
//

extension Array {
    /// 앞에서부터 `size` 개씩 끊어 나눈다. 마지막 묶음은 모자랄 수 있다.
    ///
    /// 내보내기 카드가 한 장에 담을 수 있는 만큼씩 잘라 여러 페이지로 만드는 데 쓴다.
    func chunked(by size: Int) -> [[Element]] {
        guard size > 0 else { return isEmpty ? [] : [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
