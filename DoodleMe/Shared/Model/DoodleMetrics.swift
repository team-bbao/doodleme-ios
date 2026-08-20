//
//  DoodleMetrics.swift
//  DoodleMe
//

import CoreGraphics

nonisolated enum DoodleMetrics {
    /// 그림을 그리고 보여주는 기준 캔버스 크기.
    /// 저장된 좌표는 모두 이 크기를 기준으로 하므로, 축소해 보여줄 때는 이 값으로 나눠 배율을 구한다.
    static let canvasSize = CGSize(width: 350, height: 390)

    /// 버튼 하나가 차지하는 최소 한 변. 손끝으로 정확히 누를 수 있는 크기다.
    ///
    /// 그리기 탭에도 같은 값이 있지만 그쪽을 참조하지 않는다.
    /// 탭마다 담당자가 달라, 다른 탭의 파일에 기대면 그쪽이 바뀔 때 여기가 깨진다.
    static let buttonSide: CGFloat = 44

    /// 메모지와 캔버스가 공유하는 모서리 반경.
    /// 두 값이 어긋나면 모서리 바깥에도 획이 그려진다.
    static let canvasCornerRadius: CGFloat = 50
}
