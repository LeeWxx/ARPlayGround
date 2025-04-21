import UIKit
import Vision

@objcMembers
class NailProcessor: NSObject, NailProcessing {
    static let shared = NailProcessor()
    
    private let handPoseDetector: HandPoseDetecting
    private let imageSegmenter: ImageSegmenting
    
    // 추가: 컨투어 및 손톱 메트릭스 분석 객체 (필요시 싱글톤 또는 인스턴스 생성)
    private let contourAnalyzer: ContourAnalyzing = ContourAnalyzer()
    private let nailMetricsAnalyzer: NailMetricsAnalyzing = NailMetricsAnalyzer()
    
    private(set) var lastProcessingTime: Double = 0
    
    private override init() {
        self.handPoseDetector = HandPoseDetector.shared
        self.imageSegmenter = ImageSegmenter.shared
        super.init()
    }
    
    // MARK: - NailProcessing 프로토콜 구현
    
    /// 원본 이미지에 네일 오버레이를 적용하는 최종 작업을 수행합니다.
    func processNailOverlay(for image: UIImage, completion: @escaping (UIImage?, Error?) -> Void) {
        let startTime = CACurrentMediaTime()
        
        // processImage 내부에서 세그멘테이션, 손 포즈 감지, 컨투어 추출 및 메트릭스 분석을 모두 진행
        processImage(image) { [weak self] segmentedImage, observations, error in
            guard let self = self else { return }
            if let error = error {
                print("[NailProcessor] 처리 에러: \(error)")
                completion(nil, error)
                return
            }
            guard let segmentedImage = segmentedImage,
                  let handObservations = observations, !handObservations.isEmpty else {
                let error = NSError(domain: "NailProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "세그멘테이션 또는 손 포즈 감지 결과가 없습니다"])
                completion(nil, error)
                return
            }
            
            // 컨투어 추출
            let contours = self.contourAnalyzer.extractContours(from: segmentedImage)
            if contours.isEmpty {
                let error = NSError(domain: "NailProcessor", code: -2, userInfo: [NSLocalizedDescriptionKey: "유효한 컨투어가 없습니다"])
                completion(nil, error)
                return
            }
            
            // 컨투어, 손 포즈, 세그멘테이션 결과를 통합해 최종 오버레이 이미지 생성
            let finalImage = self.composeFinalImage(
                baseImage: segmentedImage,
                handObservations: handObservations,
                contours: contours
            )
            
            self.lastProcessingTime = (CACurrentMediaTime() - startTime) * 1000
            print("[NailProcessor] 총 처리 시간: \(self.lastProcessingTime) ms")
            completion(finalImage, nil)
        }
    }
    
    /// 이미지에서 세그멘테이션과 손 포즈 감지를 동시에 수행하고 결과를 반환합니다.
    func processImage(_ image: UIImage, completion: @escaping (UIImage?, [VNHumanHandPoseObservation]?, Error?) -> Void) {
        print("[NailProcessor] 이미지 프로세싱 시작")
        
        var isCompleted = false
        
        var segmentationResult: UIImage?
        var segmentationError: Error?
        let segmentationGroup = DispatchGroup()
        
        segmentationGroup.enter()
        imageSegmenter.processImage(image) { result, error in
            segmentationResult = result
            segmentationError = error
            segmentationGroup.leave()
        }
        
        var handPoseObservations: [VNHumanHandPoseObservation]?
        var handPoseError: Error?
        let handPoseGroup = DispatchGroup()
        
        handPoseGroup.enter()
        handPoseDetector.detectHandPose(on: image) { observations, error in
            handPoseObservations = observations
            handPoseError = error
            handPoseGroup.leave()
        }
        
        let processingQueue = DispatchQueue.global(qos: .userInitiated)
        
        let timeoutTimer = DispatchSource.makeTimerSource(queue: processingQueue)
        timeoutTimer.setEventHandler {
            if !isCompleted {
                isCompleted = true
                print("[NailProcessor] 처리 타임아웃")
                completion(nil, nil, NSError(domain: "NailProcessor", code: -3, userInfo: [NSLocalizedDescriptionKey: "처리 시간이 초과되었습니다"]))
            }
            timeoutTimer.cancel()
        }
        timeoutTimer.schedule(deadline: .now() + 10.0)
        timeoutTimer.resume()
        
        processingQueue.async {
            segmentationGroup.wait()
            handPoseGroup.wait()
            timeoutTimer.cancel()
            if isCompleted { return }
            isCompleted = true
            
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
            print("[NailProcessor] 세그멘테이션 및 손 포즈 감지 완료")
            completion(segmentationResult, handPoseObservations, nil)
        }
    }
    
    /// 세그멘테이션, 손 포즈 감지, 컨투어와 메트릭스 분석 결과를 통합하여 최종 오버레이 이미지를 생성합니다.
    private func composeFinalImage(baseImage: UIImage,
                                   handObservations: [VNHumanHandPoseObservation],
                                   contours: [(path: UIBezierPath, center: CGPoint)]) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: baseImage.size)
        let finalImage = renderer.image { context in
            // 원본 이미지 그리기
            baseImage.draw(in: CGRect(origin: .zero, size: baseImage.size))
            
            // 각 손 포즈 관측 결과에 대해 컨투어 매핑 및 시각화 처리
            for observation in handObservations {
                // 손가락 매핑 및 색상 적용
                contourAnalyzer.mapFingerTipsToContours(
                    in: context.cgContext,
                    observation: observation,
                    contours: contours,
                    colors: [.red, .green, .blue, .orange, .purple],
                    displaySize: baseImage.size
                )
                
                // 손가락 방향 시각화 (화살표, 십자선, 각도 텍스트)
                contourAnalyzer.visualizeFingerDirections(
                    in: context.cgContext,
                    observation: observation,
                    contours: contours,
                    displaySize: baseImage.size
                )
                
                // 추가: NailMetricsAnalyzer를 통해 손톱 메트릭스 계산 및 시각화
                let metrics = nailMetricsAnalyzer.calculateAllFingerMetrics(
                    observation: observation,
                    contours: contours,
                    displaySize: baseImage.size
                )
                for m in metrics {
                    nailMetricsAnalyzer.visualizeNailMetrics(
                        in: context.cgContext,
                        metrics: m,
                        contour: contours.first { $0.center == m.contourCenter }?.path ?? UIBezierPath(),
                        arrowLength: 60.0,
                        arrowColor: .white
                    )
                }
            }
        }
        
        return finalImage
    }
    
    /// 세그멘테이션과 손 포즈 감지 결과를 기반으로 시각화를 진행합니다.
    func visualizeResults(image: UIImage, observations: [VNHumanHandPoseObservation]?, completion: @escaping (UIImage?, Error?) -> Void) {
        print("[NailProcessor] 결과 시각화 시작")
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
            print("[NailProcessor] 손 포즈 관측 결과가 없습니다. 원본 이미지만 반환합니다.")
            completion(image, nil)
        }
    }
}
