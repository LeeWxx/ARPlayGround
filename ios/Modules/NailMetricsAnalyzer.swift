import UIKit
import Vision

class NailMetricsAnalyzer: NailMetricsAnalyzing {
    
    // 손가락 관절 매핑 정보 (DIP 및 TIP 관절 정의)
    static let fingerJointMapping: [(name: String, dip: VNHumanHandPoseObservation.JointName, tip: VNHumanHandPoseObservation.JointName)] = [
        ("thumb", .thumbIP, .thumbTip),
        ("index", .indexDIP, .indexTip),
        ("middle", .middleDIP, .middleTip),
        ("ring", .ringDIP, .ringTip),
        ("little", .littleDIP, .littleTip)
    ]
    
    func calculateAllFingerMetrics(
        observation: VNHumanHandPoseObservation,
        contours: [(path: UIBezierPath, center: CGPoint)],
        displaySize: CGSize
    ) -> [NailMetrics] {
        var results: [NailMetrics] = []
        
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else {
            print("인식된 관절 정보 없음")
            return []
        }
        
        for (name, dipJoint, tipJoint) in NailMetricsAnalyzer.fingerJointMapping {
            guard let dipPointValue = recognizedPoints[dipJoint],
                  let tipPointValue = recognizedPoints[tipJoint],
                  dipPointValue.confidence > 0.2,
                  tipPointValue.confidence > 0.2 else {
                print("\(name) 손가락 관절 정보 부족")
                continue
            }
            
            let dipPoint = CGPoint(
                x: dipPointValue.location.x * displaySize.width,
                y: (1 - dipPointValue.location.y) * displaySize.height
            )
            let tipPoint = CGPoint(
                x: tipPointValue.location.x * displaySize.width,
                y: (1 - tipPointValue.location.y) * displaySize.height
            )
            
            var closestContour: UIBezierPath?
            var closestCenter: CGPoint?
            var minDistance: CGFloat = CGFloat.greatestFiniteMagnitude
            
            for (contour, center) in contours {
                let distance = hypot(center.x - tipPoint.x, center.y - tipPoint.y)
                if distance < minDistance {
                    minDistance = distance
                    closestContour = contour
                    closestCenter = center
                }
            }
            
            guard let contour = closestContour, let center = closestCenter else {
                print("\(name) 손가락에 적합한 컨투어 없음")
                continue
            }
            
            let (angle, width, height) = Self.calculateNailMetrics(
                contour: contour,
                dipPoint: dipPoint,
                tipPoint: tipPoint
            )
            
            let metrics = NailMetrics(
                fingerName: name,
                contourCenter: center,
                angle: angle,
                width: width,
                height: height,
                dipPoint: dipPoint,
                tipPoint: tipPoint
            )
            results.append(metrics)
        }
        return results
    }
    
    static func calculateNailMetrics(
        contour: UIBezierPath,
        dipPoint: CGPoint,
        tipPoint: CGPoint
    ) -> (angle: CGFloat, width: CGFloat, height: CGFloat) {
        let center = CGPoint(x: contour.bounds.midX, y: contour.bounds.midY)
        let dx = tipPoint.x - dipPoint.x
        let dy = tipPoint.y - dipPoint.y
        
        let angle = atan2(dx, -dy)
        let degrees = angle * 180 / .pi
        
        let copy = contour.copy() as! UIBezierPath
        let translateTransform = CGAffineTransform(translationX: -center.x, y: -center.y)
        copy.apply(translateTransform)
        let rotateTransform = CGAffineTransform(rotationAngle: -angle)
        copy.apply(rotateTransform)
        let bounds = copy.bounds
        
        return (degrees, bounds.width, bounds.height)
    }
    
    func visualizeNailMetrics(
        in context: CGContext,
        metrics: NailMetrics,
        contour: UIBezierPath,
        arrowLength: CGFloat,
        arrowColor: UIColor
    ) {
        Self.drawDirectionArrow(
            in: context,
            from: metrics.dipPoint,
            to: metrics.tipPoint,
            length: arrowLength,
            color: arrowColor
        )
        
        Self.drawDimensionCrosshair(
            in: context,
            contour: contour,
            angle: metrics.angle,
            width: metrics.width,
            height: metrics.height,
            color: arrowColor
        )
        
        Self.drawAngleText(
            in: context,
            angle: metrics.angle,
            startPoint: metrics.dipPoint,
            endPoint: CGPoint(
                x: metrics.dipPoint.x + cos(metrics.angle * .pi / 180) * arrowLength,
                y: metrics.dipPoint.y + sin(metrics.angle * .pi / 180) * arrowLength
            ),
            color: arrowColor
        )
    }
    
    // MARK: - 내부 시각화 유틸리티 (private)
    
    private static func drawDirectionArrow(
        in context: CGContext,
        from startPoint: CGPoint,
        to endPoint: CGPoint,
        length: CGFloat,
        color: UIColor
    ) {
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let magnitude = sqrt(dx * dx + dy * dy)
        guard magnitude > 0 else { return }
        
        let unitDx = dx / magnitude
        let unitDy = dy / magnitude
        
        let arrowEndPoint = CGPoint(
            x: startPoint.x + unitDx * length,
            y: startPoint.y + unitDy * length
        )
        let headLength = length * 0.2
        
        context.setLineWidth(2.0)
        context.setStrokeColor(color.cgColor)
        context.beginPath()
        context.move(to: startPoint)
        context.addLine(to: arrowEndPoint)
        context.strokePath()
        
        let angle1 = atan2(unitDy, unitDx) + .pi * 3 / 4
        let angle2 = atan2(unitDy, unitDx) - .pi * 3 / 4
        
        let arrowPoint1 = CGPoint(
            x: arrowEndPoint.x - headLength * cos(angle1),
            y: arrowEndPoint.y - headLength * sin(angle1)
        )
        let arrowPoint2 = CGPoint(
            x: arrowEndPoint.x - headLength * cos(angle2),
            y: arrowEndPoint.y - headLength * sin(angle2)
        )
        
        context.beginPath()
        context.move(to: arrowEndPoint)
        context.addLine(to: arrowPoint1)
        context.strokePath()
        
        context.beginPath()
        context.move(to: arrowEndPoint)
        context.addLine(to: arrowPoint2)
        context.strokePath()
    }
    
    private static func drawDimensionCrosshair(
        in context: CGContext,
        contour: UIBezierPath,
        angle: CGFloat,
        width: CGFloat,
        height: CGFloat,
        color: UIColor
    ) {
        let contourCenter = CGPoint(
            x: contour.bounds.midX,
            y: contour.bounds.midY
        )
        let angleRad = angle * .pi / 180
        let lineLength: CGFloat = max(width, height) / 2
        
        context.setLineWidth(1.0)
        context.setLineDash(phase: 0, lengths: [4, 4])
        
        let verticalEnd1 = CGPoint(
            x: contourCenter.x + lineLength * cos(angleRad),
            y: contourCenter.y + lineLength * sin(angleRad)
        )
        let verticalEnd2 = CGPoint(
            x: contourCenter.x - lineLength * cos(angleRad),
            y: contourCenter.y - lineLength * sin(angleRad)
        )
        
        context.beginPath()
        context.move(to: verticalEnd1)
        context.addLine(to: verticalEnd2)
        context.strokePath()
        
        let horizontalEnd1 = CGPoint(
            x: contourCenter.x + lineLength * cos(angleRad + .pi / 2),
            y: contourCenter.y + lineLength * sin(angleRad + .pi / 2)
        )
        let horizontalEnd2 = CGPoint(
            x: contourCenter.x - lineLength * cos(angleRad + .pi / 2),
            y: contourCenter.y - lineLength * sin(angleRad + .pi / 2)
        )
        
        context.beginPath()
        context.move(to: horizontalEnd1)
        context.addLine(to: horizontalEnd2)
        context.strokePath()
        
        context.setLineDash(phase: 0, lengths: [])
        
        let heightText = String(format: "H: %.1f", height)
        heightText.draw(
            at: CGPoint(x: verticalEnd1.x + 5, y: (verticalEnd1.y + verticalEnd2.y) / 2),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: color
            ]
        )
        
        let widthText = String(format: "W: %.1f", width)
        widthText.draw(
            at: CGPoint(x: (horizontalEnd1.x + horizontalEnd2.x) / 2, y: horizontalEnd1.y - 15),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: color
            ]
        )
    }
    
    private static func drawAngleText(
        in context: CGContext,
        angle: CGFloat,
        startPoint: CGPoint,
        endPoint: CGPoint,
        color: UIColor
    ) {
        let textPoint = CGPoint(
            x: (startPoint.x + endPoint.x) / 2 + 15,
            y: (startPoint.y + endPoint.y) / 2
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: color
        ]
        let angleText = String(format: "%+.0f°", angle)
        angleText.draw(at: textPoint, withAttributes: attributes)
    }
}
