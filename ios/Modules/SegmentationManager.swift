    import UIKit
    import CoreML
    import Vision
    import Accelerate

    @objc class SegmentationManager: NSObject {
        static let shared = SegmentationManager()
        private let maxImageDimension: CGFloat = 1024.0
        private let modelInputSize = CGSize(width: 800, height: 800)  // 모델 입력 크기
        private var modelLoaded = false
        private var model: MLModel?

        private override init() {
            super.init()
            preloadModel()
        }
        
        // 모델 미리 로드
        private func preloadModel() {
            DispatchQueue.global(qos: .background).async {
                do {
                    guard let modelURL = Bundle.main.url(forResource: "model_final_coco", withExtension: "mlmodelc") else {
                        print("모델 파일을 찾을 수 없습니다")
                        return
                    }
                    
                    let config = MLModelConfiguration()
                    config.computeUnits = .cpuOnly
                    self.model = try MLModel(contentsOf: modelURL, configuration: config)
                    self.modelLoaded = true
                } catch {
                    print("모델 로드 실패: \(error)")
                }
            }
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

            // CGContext 생성 및 CGImage 만들기
            guard let context = CGContext(data: bitmapData,
                                        width: width,
                                        height: height,
                                        bitsPerComponent: 8,
                                        bytesPerRow: bytesPerRow,
                                        space: colorSpace,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else {
                return nil
            }
            guard let cgImage = context.makeImage() else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        }

        // UIImage를 MLMultiArray로 변환
        private func convertImageToMultiArray(_ image: UIImage) throws -> MLMultiArray {
            // 이미지를 모델 입력 크기로 리사이즈
            let resizedImage = resizeImageForModel(image)
            
            guard let cgImage = resizedImage.cgImage else {
                throw NSError(domain: "SegmentationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "CGImage 변환 실패"])
            }
            
            let width = Int(modelInputSize.width)
            let height = Int(modelInputSize.height)
            
            // RGB 채널을 위한 [1, 3, height, width] 형태의 MLMultiArray 생성
            let shape: [NSNumber] = [1, 3, NSNumber(value: height), NSNumber(value: width)]
            let multiArray = try MLMultiArray(shape: shape, dataType: .float32)
            
            // 색상 공간과 컨텍스트 생성
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var rawData = [UInt8](repeating: 0, count: width * height * 4) // RGBA를 위한 4
            let bytesPerPixel = 4
            let bytesPerRow = bytesPerPixel * width
            
            guard let context = CGContext(data: &rawData,
                                        width: width,
                                        height: height,
                                        bitsPerComponent: 8,
                                        bytesPerRow: bytesPerRow,
                                        space: colorSpace,
                                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
                throw NSError(domain: "SegmentationError", code: -2, userInfo: [NSLocalizedDescriptionKey: "컨텍스트 생성 실패"])
            }
            
            // 컨텍스트에 이미지 그리기
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            // float로 변환하고 [0, 1] 범위로 정규화
            for y in 0..<height {
                for x in 0..<width {
                    let offset = (y * width + x) * 4
                    let r = Float(rawData[offset]) / 255.0
                    let g = Float(rawData[offset + 1]) / 255.0
                    let b = Float(rawData[offset + 2]) / 255.0
                    
                    // CHW 형식으로 MLMultiArray에 저장
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

            // 모델 로드
            guard let modelURL = Bundle.main.url(forResource: "model_final_coco", withExtension: "mlmodelc") else {
                completion(nil, NSError(domain: "SegmentationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "모델 파일을 찾을 수 없습니다"]))
                return
            }

            do {
                let config = MLModelConfiguration()
                config.computeUnits = .cpuOnly  // GPU 대신 CPU로 실행
                
                // 미리 로드된 모델이 있으면 사용
                let modelToUse: MLModel
                if modelLoaded, let loadedModel = model {
                    modelToUse = loadedModel
                } else {
                    modelToUse = try MLModel(contentsOf: modelURL, configuration: config)
                }
                
                // 이미지를 MLMultiArray로 변환
                let inputArray = try convertImageToMultiArray(image)
                
                // 모델 입력 준비
                let input = try MLDictionaryFeatureProvider(dictionary: ["input_image": inputArray])
                
                // 추론 실행
                let output = try modelToUse.prediction(from: input)
                
                // 출력 multiarray 가져오기
                guard let segmentationMask = output.featureValue(for: "segmentation_mask")?.multiArrayValue else {
                    throw NSError(domain: "SegmentationError", code: -3, userInfo: [NSLocalizedDescriptionKey: "세그멘테이션 마스크 생성 실패"])
                }

                // 백그라운드에서 처리
                DispatchQueue.global(qos: .userInitiated).async {
                    autoreleasepool {
                        let width = Int(self.modelInputSize.width)
                        let height = Int(self.modelInputSize.height)
                        
                        guard let heatmapImage = self.createHeatmapFromMultiArray(segmentationMask,
                                                                                width: width,
                                                                                height: height) else {

                            DispatchQueue.main.async {
                                completion(nil, NSError(domain: "SegmentationError",
                                                    code: -4,
                                                    userInfo: [NSLocalizedDescriptionKey: "히트맵 이미지 생성 실패"]))
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
                completion(nil, error)
            }
        }
    }
