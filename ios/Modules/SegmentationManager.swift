import UIKit
import CoreML
import Vision
import Accelerate

@objc class SegmentationManager: NSObject {
    static let shared = SegmentationManager()
    private let maxImageDimension: CGFloat = 1024.0
    private let modelInputSize = CGSize(width: 256, height: 256)  // 모델 입력 크기

    private override init() {
        super.init()
    }

    // 이미지 리사이즈 함수 (모델 입력용)
    private func resizeImageForModel(_ image: UIImage) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(modelInputSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: modelInputSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage ?? image
    }

    // 이미지 리사이즈 함수 (디스플레이용)
    private func resizeImageForDisplay(_ image: UIImage) -> UIImage {
        let size = image.size
        let widthRatio = maxImageDimension / size.width
        let heightRatio = maxImageDimension / size.height
        let scale = min(widthRatio, heightRatio)

        if scale >= 1.0 {
            return image
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage ?? image
    }

    // MLMultiArray로부터 바이너리 마스크 이미지를 생성하는 함수
    private func createHeatmapFromMultiArray(_ multiArray: MLMultiArray, width: Int, height: Int) -> UIImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow

        // 메모리 할당
        let bitmapData = UnsafeMutablePointer<UInt8>.allocate(capacity: totalBytes)
        defer {
            bitmapData.deallocate()
        }

        // 각 픽셀에 대해 이진화 처리 (0 -> 투명, 1 -> 흰색)
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let pixelOffset = y * bytesPerRow + x * bytesPerPixel
                
                if index < multiArray.count {
                    let value = multiArray[index].doubleValue
                    // 임계값 0.5를 기준으로 이진화
                    if value > 0.5 {
                        // 흰색 (255, 255, 255)으로 설정
                        bitmapData[pixelOffset + 0] = 255  // R
                        bitmapData[pixelOffset + 1] = 255  // G
                        bitmapData[pixelOffset + 2] = 255  // B
                        bitmapData[pixelOffset + 3] = 255  // A (불투명)
                    } else {
                        // 완전 투명으로 설정
                        bitmapData[pixelOffset + 0] = 0    // R
                        bitmapData[pixelOffset + 1] = 0    // G
                        bitmapData[pixelOffset + 2] = 0    // B
                        bitmapData[pixelOffset + 3] = 0    // A (투명)
                    }
                } else {
                    // 범위를 벗어난 경우 투명하게 처리
                    bitmapData[pixelOffset + 0] = 0
                    bitmapData[pixelOffset + 1] = 0
                    bitmapData[pixelOffset + 2] = 0
                    bitmapData[pixelOffset + 3] = 0
                }
            }
        }

        // CGContext를 생성하고, CGImage를 만듦
        guard let context = CGContext(data: bitmapData,
                                    width: width,
                                    height: height,
                                    bitsPerComponent: 8,
                                    bytesPerRow: bytesPerRow,
                                    space: colorSpace,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            print("Failed to create CGContext")
            return nil
        }
        guard let cgImage = context.makeImage() else {
            print("Failed to create CGImage")
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    // Convert UIImage to MLMultiArray
    private func convertImageToMultiArray(_ image: UIImage) throws -> MLMultiArray {
        // 이미지를 모델 입력 크기로 리사이즈
        let resizedImage = resizeImageForModel(image)
        
        guard let cgImage = resizedImage.cgImage else {
            throw NSError(domain: "SegmentationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"])
        }
        
        // Create MLMultiArray with shape [1, 3, 256, 256] for RGB channels
        let shape: [NSNumber] = [1, 3, 256, 256]
        let multiArray = try MLMultiArray(shape: shape, dataType: .float32)
        
        // Create color space and context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: 256 * 256 * 4) // 4 for RGBA
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * 256
        
        guard let context = CGContext(data: &rawData,
                                    width: 256,
                                    height: 256,
                                    bitsPerComponent: 8,
                                    bytesPerRow: bytesPerRow,
                                    space: colorSpace,
                                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw NSError(domain: "SegmentationError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create context"])
        }
        
        // Draw image into context
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 256, height: 256))
        
        // Convert to float and normalize to [0, 1]
        for y in 0..<256 {
            for x in 0..<256 {
                let offset = (y * 256 + x) * 4
                let r = Float(rawData[offset]) / 255.0
                let g = Float(rawData[offset + 1]) / 255.0
                let b = Float(rawData[offset + 2]) / 255.0
                
                // Store in MLMultiArray in CHW format
                multiArray[[0, 0, y, x] as [NSNumber]] = NSNumber(value: r)
                multiArray[[0, 1, y, x] as [NSNumber]] = NSNumber(value: g)
                multiArray[[0, 2, y, x] as [NSNumber]] = NSNumber(value: b)
            }
        }
        
        return multiArray
    }

    // 이미지 처리 함수: UIImage를 받아 모델 실행 후 히트맵 생성 및 원본 이미지에 오버레이
    @objc func processImage(_ image: UIImage, completion: @escaping (UIImage?, Error?) -> Void) {
        // 이미지 리사이즈 (디스플레이용)
        let displayImage = resizeImageForDisplay(image)
        print("Processing image of size: \(displayImage.size)")

        // 모델 로드
        guard let modelURL = Bundle.main.url(forResource: "model_final_coco", withExtension: "mlmodelc") else {
            print("Model file not found")
            completion(nil, NSError(domain: "SegmentationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file not found"]))
            return
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuOnly  // GPU 대신 CPU로 실행
            let model = try MLModel(contentsOf: modelURL, configuration: config)
            
            // Convert image to MLMultiArray (256x256)
            let inputArray = try convertImageToMultiArray(image)
            
            // Prepare model input
            let input = try MLDictionaryFeatureProvider(dictionary: ["input_image": inputArray])
            
            // Run inference
            let output = try model.prediction(from: input)
            
            // Get output multiarray
            guard let segmentationMask = output.featureValue(for: "segmentation_mask")?.multiArrayValue else {
                throw NSError(domain: "SegmentationError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to get segmentation mask"])
            }

            // Process in background
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    guard let heatmapImage = self.createHeatmapFromMultiArray(segmentationMask, 
                                                                            width: 256, 
                                                                            height: 256) else {
                        print("Failed to create heatmap image")
                        DispatchQueue.main.async {
                            completion(nil, NSError(domain: "SegmentationError", 
                                                 code: -4, 
                                                 userInfo: [NSLocalizedDescriptionKey: "Failed to create heatmap image"]))
                        }
                        return
                    }

                    // 히트맵 이미지를 디스플레이 이미지 크기로 리사이즈
                    UIGraphicsBeginImageContextWithOptions(displayImage.size, false, 0.0)
                    displayImage.draw(in: CGRect(origin: .zero, size: displayImage.size))
                    heatmapImage.draw(in: CGRect(origin: .zero, size: displayImage.size), 
                                    blendMode: .normal, 
                                    alpha: 0.6)
                    let resultImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()

                    DispatchQueue.main.async {
                        completion(resultImage, nil)
                    }
                }
            }
        } catch {
            print("Model loading/execution error: \(error)")
            completion(nil, error)
        }
    }
}
