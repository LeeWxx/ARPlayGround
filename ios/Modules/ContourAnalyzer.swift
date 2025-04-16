import UIKit
import Vision

class ContourAnalyzer: ContourAnalyzing {
    
    // MARK: - 1단계: 컨투어 추출 및 필터링
    
    func extractContours(from segmentationMask: UIImage) -> [(path: UIBezierPath, center: CGPoint)] {
        guard let cgMask = segmentationMask.cgImage else {
            print("Segmentation mask에서 CGImage 추출 실패")
            return []
        }
        
        let contoursRequest = VNDetectContoursRequest()
        contoursRequest.contrastAdjustment = 2.0
        contoursRequest.detectsDarkOnLight = true
        contoursRequest.maximumImageDimension = Int(segmentationMask.size.width)
        
        let handler = VNImageRequestHandler(cgImage: cgMask, options: [:])
        do {
            try handler.perform([contoursRequest])
        } catch {
            print("컨투어 감지 요청 오류: \(error)")
            return []
        }
        
        guard let contoursObservation = contoursRequest.results?.first as? VNContoursObservation else {
            print("컨투어 결과 없음")
            return []
        }
        
        let contourPaths = extractContourPaths(from: contoursObservation, imageSize: segmentationMask.size)
        let validContours = filterValidContours(contourPaths, imageSize: segmentationMask.size)
        return validContours
    }
    
    private func extractContourPaths(
        from contoursObservation: VNContoursObservation,
        imageSize: CGSize
    ) -> [UIBezierPath] {
        var contourPaths: [UIBezierPath] = []
        let imageWidth = imageSize.width
        let imageHeight = imageSize.height
        
        for index in 0..<contoursObservation.contourCount {
            if let contour = try? contoursObservation.contour(at: index) {
                let path = UIBezierPath()
                let points = contour.normalizedPoints.map { point -> CGPoint in
                    let x = CGFloat(point.x) * imageWidth
                    let y = (1 - CGFloat(point.y)) * imageHeight
                    return CGPoint(x: x, y: y)
                }
                
                if let firstPoint = points.first {
                    path.move(to: firstPoint)
                    for pt in points.dropFirst() {
                        path.addLine(to: pt)
                    }
                    path.close()
                    contourPaths.append(path)
                }
            }
        }
        print("전체 컨투어 개수: \(contourPaths.count)")
        return contourPaths
    }
    
    private func filterValidContours(
        _ contourPaths: [UIBezierPath],
        imageSize: CGSize
    ) -> [(path: UIBezierPath, center: CGPoint)] {
        var validContours: [(path: UIBezierPath, center: CGPoint)] = []
        let imageArea = imageSize.width * imageSize.height
        
        for (index, contour) in contourPaths.enumerated() {
            let bounds = contour.bounds
            let area = bounds.width * bounds.height
            let areaRatio = area / imageArea
            
            // 너무 큰 컨투어(배경) 제외
            if areaRatio > 0.3 {
                print("큰 컨투어 무시 (배경): \(index), 크기: \(bounds.width)x\(bounds.height), 면적 비율: \(areaRatio)")
                continue
            }
            // 너무 작은 컨투어(노이즈) 제외
            if area < 100 {
                continue
            }
            let centerPoint = CGPoint(x: bounds.midX, y: bounds.midY)
            validContours.append((path: contour, center: centerPoint))
            if area > 500 {
                print("유효한 컨투어 \(index): 크기 \(bounds.width)x\(bounds.height), 면적 \(area), 면적 비율: \(areaRatio), 중심: \(centerPoint)")
            }
        }
        return validContours
    }
    
    // MARK: - 2단계: 손가락 매핑 및 시각화 처리
    
    func mapFingerTipsToContours(
        in context: CGContext,
        observation: VNHumanHandPoseObservation,
        contours: [(path: UIBezierPath, center: CGPoint)],
        colors: [UIColor],
        displaySize: CGSize
    ) {
        let fingerTipNames: [VNHumanHandPoseObservation.JointName] = [
            .thumbTip, .indexTip, .middleTip, .ringTip, .littleTip
        ]
        
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else { return }
        
        for (index, joint) in fingerTipNames.enumerated() {
            guard let fingerPointValue = recognizedPoints[joint],
                  fingerPointValue.confidence > 0.2 else { continue }
            
            let fingerPoint = CGPoint(
                x: fingerPointValue.location.x * displaySize.width,
                y: (1 - fingerPointValue.location.y) * displaySize.height
            )
            
            // 손가락 TIP을 표시 (노란색 원)
            let detectionCircle = UIBezierPath(
                arcCenter: fingerPoint,
                radius: 5.0,
                startAngle: 0,
                endAngle: CGFloat.pi * 2,
                clockwise: true
            )
            context.setFillColor(UIColor.yellow.cgColor)
            context.addPath(detectionCircle.cgPath)
            context.fillPath()
            
            // 가장 가까운 컨투어 찾기
            var closestContour: UIBezierPath?
            var closestCenter: CGPoint?
            var minDistance: CGFloat = CGFloat.greatestFiniteMagnitude
            
            for (contour, center) in contours {
                let distance = hypot(center.x - fingerPoint.x, center.y - fingerPoint.y)
                if distance < minDistance {
                    minDistance = distance
                    closestContour = contour
                    closestCenter = center
                }
            }
            
            // 해당 손가락의 컨투어가 있다면 색상 적용
            if let contourToDraw = closestContour {
                let color = colors[index % colors.count]
                context.setStrokeColor(color.cgColor)
                context.addPath(contourToDraw.cgPath)
                context.strokePath()
                
                context.setFillColor(color.withAlphaComponent(0.5).cgColor)
                context.addPath(contourToDraw.cgPath)
                context.fillPath()
                
                if let center = closestCenter {
                    print("손가락 \(joint)와 가장 가까운 컨투어 - 거리: \(minDistance), 중심: \(center)")
                }
            }
        }
    }
    
    func visualizeFingerDirections(
        in context: CGContext,
        observation: VNHumanHandPoseObservation,
        contours: [(path: UIBezierPath, center: CGPoint)],
        displaySize: CGSize
    ) {
        // 상위 단계에서 NailMetricsAnalyzer를 사용하여 손톱 메트릭스를 계산 후 시각화합니다.
        let fingerMetrics = NailMetricsAnalyzer().calculateAllFingerMetrics(
            observation: observation,
            contours: contours,
            displaySize: displaySize
        )
        
        print("\n===== 손톱 메트릭스 계산 결과 =====")
        for metrics in fingerMetrics {
            print(metrics.description)
        }
        print("===================================\n")
        
        for metrics in fingerMetrics {
            // 컨투어 중심 또는 영역이 해당 손가락 메트릭스에 맞으면 시각화 수행
            for (contour, _) in contours {
                if contour.bounds.contains(metrics.contourCenter) {
                    NailMetricsAnalyzer.visualizeNailMetrics(
                        in: context,
                        metrics: metrics,
                        contour: contour,
                        arrowLength: 60.0,
                        arrowColor: .white
                    )
                    break
                }
            }
        }
    }
}
