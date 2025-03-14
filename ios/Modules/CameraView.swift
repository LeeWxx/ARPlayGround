import UIKit
import AVFoundation
import React

@objc(CameraView)
class CameraView: UIView {
    private var overlayImageView: UIImageView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        print("CameraView 초기화: \(frame)")
        setupCameraView()
        setupOverlayView()
        setupRealTimeProcessing()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        print("CameraView coder 초기화")
        setupCameraView()
        setupOverlayView()
        setupRealTimeProcessing()
    }
    
    /// 카메라 미리보기 설정
    private func setupCameraView() {
        print("카메라 뷰 설정 시작")
        CameraManager.shared.setupCamera(in: self)
    }
    
    /// 오버레이 이미지 뷰 설정
    private func setupOverlayView() {
        print("오버레이 뷰 설정 시작")
        overlayImageView = UIImageView(frame: bounds)
        overlayImageView?.contentMode = .scaleAspectFill
        overlayImageView?.alpha = 0.6 // 투명도 설정
        
        // 디버깅을 위해 배경색 설정
        overlayImageView?.backgroundColor = UIColor.red.withAlphaComponent(0.1)
        
        if let overlayImageView = overlayImageView {
            addSubview(overlayImageView)
            print("오버레이 이미지 뷰 추가됨, 크기: \(overlayImageView.frame)")
        } else {
            print("오버레이 이미지 뷰 생성 실패")
        }
    }
    
    /// 실시간 처리 설정
    private func setupRealTimeProcessing() {
        print("실시간 처리 설정 시작")
        CameraManager.shared.realTimeFrameCallback = { [weak self] resultImage in
            print("실시간 프레임 콜백 받음")
            self?.updateOverlay(with: resultImage)
        }
        CameraManager.shared.setRealTimeProcessing(enabled: true)
    }
    
    /// 오버레이 이미지 업데이트
    private func updateOverlay(with image: UIImage) {
        print("오버레이 업데이트, 이미지 크기: \(image.size)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("self가 nil임")
                return
            }
            
            if self.overlayImageView == nil {
                print("overlayImageView가 nil임, 다시 생성")
                self.setupOverlayView()
            }
            
            self.overlayImageView?.image = image
            print("오버레이 이미지 설정됨")
            
            // 페이드 인 애니메이션 (이미 표시되어 있지 않은 경우)
            if self.overlayImageView?.alpha != 0.6 {
                print("오버레이 페이드 인 애니메이션 시작")
                UIView.animate(withDuration: 0.3) {
                    self.overlayImageView?.alpha = 0.6
                }
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
        print("layoutSubviews 호출됨, 크기: \(bounds)")
        // 뷰 크기에 맞게 미리보기 레이어 프레임을 업데이트
        if let previewLayer = CameraManager.shared.getPreviewLayer() {
            previewLayer.frame = self.bounds
            print("프리뷰 레이어 크기 업데이트: \(self.bounds)")
        }
        
        overlayImageView?.frame = bounds
        print("오버레이 이미지 뷰 크기 업데이트: \(bounds)")
    }
    
    deinit {
        print("CameraView deinit")
        CameraManager.shared.stopCamera()
        CameraManager.shared.setRealTimeProcessing(enabled: false)
    }
} 