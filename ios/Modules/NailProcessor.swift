import UIKit
import Vision

/// 세그멘테이션 및 손 포즈 감지 결과를 기반으로 네일 오버레이 처리를 제공하는 클래스
@objcMembers class NailProcessor: NSObject, NailProcessing {
    /// 싱글톤 인스턴스
    static let shared = NailProcessor()
    
    /// 핸드 포즈 감지 서비스
    private let handPoseDetector: HandPoseDetecting
    
    /// 이미지 세그멘테이션 서비스
    private let imageSegmenter: ImageSegmenting
    
    /// 마지막 처리 시간 (밀리초)
    private(set) var lastProcessingTime: Double = 0
    
    private override init() {
        self.handPoseDetector = HandPoseDetector.shared
        self.imageSegmenter = ImageSegmenter.shared
        super.init()
    }
    
    // MARK: - NailProcessing 프로토콜 구현
    
    /// 이미지에 네일 오버레이 처리를 수행합니다.
    ///
    /// - Parameters:
    ///   - image: 처리할 원본 이미지
    ///   - completion: 처리된 이미지와 에러를 전달하는 콜백
    func processNailOverlay(for image: UIImage, completion: @escaping (UIImage?, Error?) -> Void) {
        // TODO: 실제 네일 오버레이 처리 구현
        // 현재는 프로세싱 후 시각화만 진행
        let startTime = CACurrentMediaTime()
        
        // 이미지 프로세싱 후 결과 시각화
        processImage(image) { segmentedImage, observations, error in
            if let error = error {
                print("[NailProcessor] 처리 에러: \(error)")
                completion(nil, error)
                return
            }
            
            guard let segmentedImage = segmentedImage else {
                let error = NSError(domain: "NailProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "세그멘테이션 결과가 없습니다"])
                completion(nil, error)
                return
            }
            
            // 시각화 수행
            self.visualizeResults(image: segmentedImage, observations: observations) { resultImage, error in
                // 처리 시간 계산
                self.lastProcessingTime = (CACurrentMediaTime() - startTime) * 1000
                print("[NailProcessor] 총 처리 시간: \(self.lastProcessingTime) ms")
                
                completion(resultImage, error)
            }
        }
    }
    
    /// 이미지에서 세그멘테이션과 손 포즈 감지를 수행합니다.
    ///
    /// - Parameters:
    ///   - image: 처리할 원본 이미지
    ///   - completion: 세그멘테이션 결과, 손 포즈 감지 결과, 에러를 전달하는 콜백
    func processImage(_ image: UIImage, completion: @escaping (UIImage?, [VNHumanHandPoseObservation]?, Error?) -> Void) {
        print("[NailProcessor] 이미지 프로세싱 시작")
        
        // 콜백이 이미 호출되었는지 추적
        var isCompleted = false
        
        // 세그멘테이션 및 손 포즈 감지를 병렬로 수행
        // 세그멘테이션 처리
        var segmentationResult: UIImage?
        var segmentationError: Error?
        let segmentationGroup = DispatchGroup()
        
        segmentationGroup.enter()
        imageSegmenter.processImage(image) { result, error in
            segmentationResult = result
            segmentationError = error
            segmentationGroup.leave()
        }
        
        // 손 포즈 감지
        var handPoseObservations: [VNHumanHandPoseObservation]?
        var handPoseError: Error?
        let handPoseGroup = DispatchGroup()
        
        handPoseGroup.enter()
        handPoseDetector.detectHandPose(on: image) { observations, error in
            handPoseObservations = observations
            handPoseError = error
            handPoseGroup.leave()
        }
        
        // 두 작업 완료 시 실행되는 처리
        let processingQueue = DispatchQueue.global(qos: .userInitiated)
        
        // 타임아웃 타이머 설정
        let timeoutTimer = DispatchSource.makeTimerSource(queue: processingQueue)
        timeoutTimer.setEventHandler {
            if !isCompleted {
                isCompleted = true
                print("[NailProcessor] 처리 타임아웃")
                completion(nil, nil, NSError(domain: "NailProcessor", code: -3, userInfo: [NSLocalizedDescriptionKey: "처리 시간이 초과되었습니다"]))
            }
            timeoutTimer.cancel()
        }
        
        // 10초 후 타임아웃
        timeoutTimer.schedule(deadline: .now() + 10.0)
        timeoutTimer.resume()
        
        // 비동기로 두 작업 완료 대기
        processingQueue.async {
            // 두 그룹을 모두 대기
            segmentationGroup.wait()
            handPoseGroup.wait()
            
            // 타이머 취소
            timeoutTimer.cancel()
            
            // 이미 완료된 경우 추가 처리 방지
            if isCompleted {
                return
            }
            
            isCompleted = true
            
            // 에러 확인
            if let error = segmentationError {
                print("[NailProcessor] 세그멘테이션 에러: \(error)")
                completion(nil, nil, error)
                return
            }
            
            if let error = handPoseError {
                print("[NailProcessor] 손 포즈 감지 에러: \(error)")
                completion(nil, nil, error)
                return
            }
            
            // 결과 반환
            print("[NailProcessor] 세그멘테이션 및 손 포즈 감지 완료")
            completion(segmentationResult, handPoseObservations, nil)
        }
    }
    
    /// 세그멘테이션과 손 포즈 감지 결과를 시각화합니다.
    ///
    /// - Parameters:
    ///   - image: 원본 이미지 또는 세그멘테이션 결과 이미지
    ///   - observations: 손 포즈 감지 결과
    ///   - completion: 시각화된 이미지와 에러를 전달하는 콜백
    func visualizeResults(image: UIImage, observations: [VNHumanHandPoseObservation]?, completion: @escaping (UIImage?, Error?) -> Void) {
        print("[NailProcessor] 결과 시각화 시작")
        
        // 손 포즈 감지 결과가 있는 경우, 이를 시각화
        if let observations = observations, !observations.isEmpty {
            handPoseDetector.visualizeHandPose(on: image, observations: observations) { resultImage, error in
                if let error = error {
                    print("[NailProcessor] 손 포즈 시각화 에러: \(error)")
                    completion(nil, error)
                    return
                }
                
                guard let finalImage = resultImage else {
                    print("[NailProcessor] 최종 이미지 생성 실패")
                    completion(nil, NSError(domain: "NailProcessor", code: -2, userInfo: [NSLocalizedDescriptionKey: "최종 이미지 생성 실패"]))
                    return
                }
                
                print("[NailProcessor] 손 포즈 시각화 완료")
                completion(finalImage, nil)
            }
        } else {
            // 손 포즈 관측 결과가 없는 경우 - 원본 이미지만 반환
            print("[NailProcessor] 손 포즈 관측 결과가 없습니다. 원본 이미지만 반환합니다.")
            completion(image, nil)
        }
    }
} 