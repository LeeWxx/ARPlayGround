import UIKit
import Vision

/// Vision API를 사용하여 손 포즈(관절) 감지 기능을 제공하는 클래스
@objcMembers class HandPoseDetector: NSObject, HandPoseDetecting {
    /// 싱글톤 인스턴스
    static let shared = HandPoseDetector()
    
    /// 마지막 처리 시간 (밀리초)
    private(set) var lastProcessingTime: Double = 0
    
    private override init() {
        super.init()
    }
    
    // MARK: - HandPoseDetecting 프로토콜 구현
    
    /// 이미지에서 손 포즈(관절)를 감지합니다.
    ///
    /// - Parameters:
    ///   - image: 분석할 원본 이미지
    ///   - completion: 감지된 손 포즈 관측 결과와 에러를 전달하는 콜백
    func detectHandPose(on image: UIImage, completion: @escaping ([VNHumanHandPoseObservation]?, Error?) -> Void) {
        print("[HandPoseDetector] 손 포즈 감지 시작.")
        
        // 모델 입력용으로 필요한 경우 이미지 리사이즈
        let resizedImage = ImageResizer.shared.resizeImageForModel(image, preserveAspectRatio: true)
        print("[HandPoseDetector] 이미지 리사이즈 완료.")
        
        guard let cgImage = resizedImage.cgImage else {
            print("[HandPoseDetector] 에러: CGImage 변환 실패")
            completion(nil, NSError(domain: "HandPoseDetector", code: -2, userInfo: [NSLocalizedDescriptionKey: "CGImage 변환 실패"]))
            return
        }
        print("[HandPoseDetector] CGImage 변환 완료.")
        
        // Vision 내장 손 포즈 감지 요청 생성
        let handPoseRequest = VNDetectHumanHandPoseRequest()
        handPoseRequest.maximumHandCount = 2  // 최대 2개 손 감지
        
        // 추론 시작 시각 기록
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([handPoseRequest])
            
            // 추론 종료 시각 기록 및 소요 시간 계산 (밀리초 단위)
            self.lastProcessingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("[HandPoseDetector] 추론 시간: \(self.lastProcessingTime) ms")
            
            print("[HandPoseDetector] 손 포즈 감지 성공.")
            let observations = handPoseRequest.results as? [VNHumanHandPoseObservation] ?? []
            print("[HandPoseDetector] 감지된 손 개수: \(observations.count)")
            
            if observations.isEmpty {
                print("[HandPoseDetector] 감지된 손이 없습니다.")
                completion([], nil)
                return
            }
            
            // 최대 2개 손으로 제한
            let limitedObservations = Array(observations.prefix(2))
            print("[HandPoseDetector] 처리할 손 개수: \(limitedObservations.count)")
            completion(limitedObservations, nil)
        } catch {
            print("[HandPoseDetector] 손 포즈 감지 에러: \(error)")
            completion(nil, error)
        }
    }
    
    /// 감지된 손 포즈를 시각화합니다.
    ///
    /// - Parameters:
    ///   - image: 원본 이미지
    ///   - observations: 감지된 손 포즈 관측 결과
    ///   - completion: 시각화된 이미지와 에러를 전달하는 콜백
    func visualizeHandPose(on image: UIImage, observations: [VNHumanHandPoseObservation], completion: @escaping (UIImage?, Error?) -> Void) {
        print("[HandPoseDetector] 손 포즈 시각화 시작.")
        
        // 표시용 이미지 리사이즈
        let displayImage = ImageResizer.shared.resizeImageForDisplay(image)
        
        // 이미지 그리기 컨텍스트 생성
        UIGraphicsBeginImageContextWithOptions(displayImage.size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        // 원본 이미지 그리기
        displayImage.draw(in: CGRect(origin: .zero, size: displayImage.size))
        
        // 그리기 컨텍스트 가져오기
        guard let context = UIGraphicsGetCurrentContext() else {
            print("[HandPoseDetector] 그래픽 컨텍스트 생성 실패")
            completion(nil, NSError(domain: "HandPoseDetector", code: -1, userInfo: [NSLocalizedDescriptionKey: "그래픽 컨텍스트 생성 실패"]))
            return
        }
        
        // 이미지 좌표계에서 Vision 좌표계로 변환
        let imageSize = displayImage.size
        let transform = CGAffineTransform.identity
            .scaledBy(x: imageSize.width, y: imageSize.height)
            .translatedBy(x: 0, y: 1)
            .scaledBy(x: 1, y: -1)
        
        // 각 손 관측 결과에 대해 처리
        for (index, observation) in observations.enumerated() {
            let handColor: UIColor = index == 0 ? .red : .blue
            
            // 손 관절 그리기
            drawHandLandmarks(observation: observation, in: context, transform: transform, color: handColor)
        }
        
        // 최종 이미지 가져오기
        guard let resultImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("[HandPoseDetector] 결과 이미지 생성 실패")
            completion(nil, NSError(domain: "HandPoseDetector", code: -3, userInfo: [NSLocalizedDescriptionKey: "결과 이미지 생성 실패"]))
            return
        }
        
        // 추론 시간 표시
        let finalImage = drawProcessingTime(on: resultImage, time: self.lastProcessingTime)
        print("[HandPoseDetector] 손 포즈 시각화 완료.")
        completion(finalImage, nil)
    }
    
    // MARK: - 내부 유틸리티 메서드
    
    /// 하나의 손 관측 결과에서 관절을 그립니다.
    private func drawHandLandmarks(observation: VNHumanHandPoseObservation, in context: CGContext, transform: CGAffineTransform, color: UIColor) {
        // 손가락 정의
        let fingers = [
            VNHumanHandPoseObservation.JointName.thumbTip,
            VNHumanHandPoseObservation.JointName.indexTip,
            VNHumanHandPoseObservation.JointName.middleTip,
            VNHumanHandPoseObservation.JointName.ringTip,
            VNHumanHandPoseObservation.JointName.littleTip
        ]
        
        do {
            // 각 손가락의 모든 관절 가져오기
            let thumbPoints = try observation.recognizedPoints(.thumb)
            let indexFingerPoints = try observation.recognizedPoints(.indexFinger)
            let middleFingerPoints = try observation.recognizedPoints(.middleFinger)
            let ringFingerPoints = try observation.recognizedPoints(.ringFinger)
            let littleFingerPoints = try observation.recognizedPoints(.littleFinger)
            let wristPoint = try observation.recognizedPoints(.all)[VNHumanHandPoseObservation.JointName.wrist]
            
            // 모든 관절점 배열
            let allPoints = [thumbPoints, indexFingerPoints, middleFingerPoints, ringFingerPoints, littleFingerPoints]
            
            // 그리기 설정
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(3.0)
            context.setLineCap(.round)
            
            // 각 손가락별로 그리기
            for (i, fingerPoints) in allPoints.enumerated() {
                guard var startPoint = wristPoint else { continue }
                
                // 손가락의 각 관절을 순회
                for (_, jointPoint) in fingerPoints where jointPoint.confidence > 0.3 {
                    let endPoint = jointPoint
                    
                    // 변환된 시작점과 끝점 계산
                    let transformedStart = startPoint.location.applying(transform)
                    let transformedEnd = endPoint.location.applying(transform)
                    
                    // 선 그리기
                    context.beginPath()
                    context.move(to: CGPoint(x: transformedStart.x, y: transformedStart.y))
                    context.addLine(to: CGPoint(x: transformedEnd.x, y: transformedEnd.y))
                    context.strokePath()
                    
                    // 관절점 그리기
                    let jointRadius: CGFloat = 5.0
                    context.fillEllipse(in: CGRect(
                        x: transformedEnd.x - jointRadius,
                        y: transformedEnd.y - jointRadius,
                        width: jointRadius * 2,
                        height: jointRadius * 2
                    ))
                    
                    // 다음 관절을 위해 시작점 업데이트
                    startPoint = endPoint
                }
                
                // 손가락 끝 관절 강조
                if let tipPoint = fingerPoints[fingers[i]], tipPoint.confidence > 0.3 {
                    let transformedTip = tipPoint.location.applying(transform)
                    let tipRadius: CGFloat = 8.0
                    
                    // 손가락 끝 원 그리기
                    context.setFillColor(color.cgColor)
                    context.fillEllipse(in: CGRect(
                        x: transformedTip.x - tipRadius,
                        y: transformedTip.y - tipRadius,
                        width: tipRadius * 2,
                        height: tipRadius * 2
                    ))
                }
            }
        } catch {
            print("[HandPoseDetector] 관절 그리기 에러: \(error)")
        }
    }
    
    /// 처리 시간을 이미지에 표시합니다.
    private func drawProcessingTime(on image: UIImage, time: Double) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(image.size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        // 원본 이미지 그리기
        image.draw(in: CGRect(origin: .zero, size: image.size))
        
        // 시간 텍스트 준비
        let timeText = String(format: "추론 시간: %.1f ms", time)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle,
            .strokeColor: UIColor.black,
            .strokeWidth: -2.0
        ]
        
        // 텍스트 그리기
        let textRect = CGRect(x: 10, y: 30, width: image.size.width - 20, height: 30)
        timeText.draw(in: textRect, withAttributes: attributes)
        
        // 최종 이미지 반환
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
} 