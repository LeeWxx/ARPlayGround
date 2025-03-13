import UIKit
import AVFoundation
import React

@objc(CameraView)
class CameraView: UIView {
    private var overlayImageView: UIImageView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCameraView()
        setupOverlayView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCameraView()
        setupOverlayView()
    }
    
    /// 카메라 미리보기 설정
    private func setupCameraView() {
        CameraManager.shared.setupCamera(in: self)
    }
    
    /// 오버레이 이미지 뷰 설정
    private func setupOverlayView() {
        overlayImageView = UIImageView(frame: bounds)
        overlayImageView?.contentMode = .scaleAspectFill
        overlayImageView?.alpha = 0.6 // 투명도 설정
        if let overlayImageView = overlayImageView {
            addSubview(overlayImageView)
        }
    }
    
    /// 세그멘테이션 결과 이미지 표시
    func showSegmentationResult(_ image: UIImage) {
        DispatchQueue.main.async { [weak self] in
            self?.overlayImageView?.image = image
            
            // 페이드 인 애니메이션
            UIView.animate(withDuration: 0.3) {
                self?.overlayImageView?.alpha = 0.6
            }
        }
    }
    
    /// 오버레이 이미지 제거
    func clearOverlay() {
        DispatchQueue.main.async { [weak self] in
            UIView.animate(withDuration: 0.3) {
                self?.overlayImageView?.alpha = 0
            } completion: { _ in
                self?.overlayImageView?.image = nil
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // 뷰 크기에 맞게 미리보기 레이어 프레임을 업데이트
        if let previewLayer = CameraManager.shared.getPreviewLayer() {
            previewLayer.frame = self.bounds
        }
        overlayImageView?.frame = bounds
    }
    
    deinit {
        CameraManager.shared.stopCamera()
    }
} 