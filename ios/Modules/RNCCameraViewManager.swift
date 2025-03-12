import Foundation
import React

@objc(RNCCameraViewManager)
class RNCCameraViewManager: RCTViewManager {
    
    override func view() -> UIView! {
        return RNCCameraView()
    }
    
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
} 