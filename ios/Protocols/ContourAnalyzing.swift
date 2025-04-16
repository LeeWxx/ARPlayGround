import UIKit
import Vision

protocol ContourAnalyzing {
    /// Segmentation 마스크 이미지로부터 유효한 컨투어(경로와 중심점)를 추출합니다.
    func extractContours(from segmentationMask: UIImage) -> [(path: UIBezierPath, center: CGPoint)]
    
    /// 손가락 관절 점들과 컨투어 정보를 매핑하여 컨텍스트에 색상 및 표시를 적용합니다.
    func mapFingerTipsToContours(
        in context: CGContext,
        observation: VNHumanHandPoseObservation,
        contours: [(path: UIBezierPath, center: CGPoint)],
        colors: [UIColor],
        displaySize: CGSize
    )
    
    /// 손가락 방향(화살표, 십자선, 각도 텍스트)을 시각화하여 그립니다.
    func visualizeFingerDirections(
        in context: CGContext,
        observation: VNHumanHandPoseObservation,
        contours: [(path: UIBezierPath, center: CGPoint)],
        displaySize: CGSize
    )
}
