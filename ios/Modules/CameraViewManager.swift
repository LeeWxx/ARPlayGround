import Foundation
import React

@objc(CameraViewManager)
class CameraViewManager: RCTViewManager {
    
    private var cameraService: CameraCapturable {
        return CameraService.shared
    }
    
    private var imageSegmenter: ImageSegmenting {
        return ImageSegmenter.shared
    }
    
    override func view() -> UIView! {
        return CameraView()
    }
    
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    @objc func capturePhoto(_ node: NSNumber, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            guard let view = self.bridge.uiManager.view(forReactTag: node) as? CameraView else {
                rejecter("ERROR", "Invalid view reference", nil)
                return
            }
            
            // 이미지 캡처 요청 (카메라가 실행 중인 상태에서)
            self.cameraService.capturePhoto { image in
                // 이미지 캡처 완료 후 카메라 세션 중지
                view.stopCameraSession()
                
                guard let image = image else {
                    rejecter("ERROR", "Failed to capture image", nil)
                    return
                }
                
                // 세그멘테이션 처리
                self.imageSegmenter.processImage(image) { resultImage, error in
                    if let error = error {
                        rejecter("ERROR", error.localizedDescription, error)
                        return
                    }
                    
                    guard let resultImage = resultImage else {
                        rejecter("ERROR", "Failed to process image", nil)
                        return
                    }
                    
                    // 결과 이미지를 오버레이로 표시
                    view.showSegmentationResult(resultImage)
                    resolver(true)
                }
            }
        }
    }
    
    @objc func clearOverlay(_ node: NSNumber) {
        DispatchQueue.main.async {
            guard let view = self.bridge.uiManager.view(forReactTag: node) as? CameraView else { return }
            view.clearOverlay()
            
            // 카메라 세션 재시작
            view.startCameraSession()
        }
    }
} 