import Foundation
import UIKit
import React

@objc(SegmentationModule)
class SegmentationModule: NSObject {
    
    @objc func processImage(_ imageBase64: String, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        guard let imageData = Data(base64Encoded: imageBase64),
              let image = UIImage(data: imageData) else {
            rejecter("ERROR", "Invalid image data", nil)
            return
        }
        
        SegmentationManager.shared.processImage(image) { resultImage, error in
            if let error = error {
                rejecter("ERROR", error.localizedDescription, error)
                return
            }
            
            guard let resultImage = resultImage,
                  let resultData = resultImage.jpegData(compressionQuality: 0.8) else {
                rejecter("ERROR", "Failed to process image", nil)
                return
            }
            
            let base64Result = resultData.base64EncodedString()
            resolver(base64Result)
        }
    }
    
    @objc static func requiresMainQueueSetup() -> Bool {
        return true
    }
} 