import UIKit
import AVFoundation

class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    static let shared = CameraManager()
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoCallback: ((UIImage?) -> Void)?
    
    private override init() {
        super.init()
    }
    
    // 지정된 뷰 내에서 카메라 미리보기를 설정합니다.
    func setupCamera(in view: UIView) {
        checkCameraPermission { [weak self] granted in
            guard let self = self else { return }
            if granted {
                self.configureSession(in: view)
            } else {
                DispatchQueue.main.async {
                    let label = UILabel(frame: view.bounds)
                    label.textAlignment = .center
                    label.text = "카메라 접근 권한이 필요합니다."
                    label.textColor = .white
                    label.backgroundColor = .red
                    view.addSubview(label)
                }
            }
        }
    }
    
    // 카메라 권한 확인 및 요청
    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        default:
            completion(false)
        }
    }
    
    // 카메라 세션 구성 및 미리보기 레이어 추가
    private func configureSession(in view: UIView) {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { return }
        captureSession.sessionPreset = .high
        
        // 후면 카메라 선택
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                 for: .video,
                                                 position: .back) else {
            print("사용 가능한 카메라가 없습니다")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                print("카메라 입력을 추가할 수 없습니다")
                return
            }
            
            // 비디오 출력 설정
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
            
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
            
            // 비디오 연결 설정 - 출력이 추가된 후에 해야 함
            if let connection = videoOutput.connection(with: .video) {
                // 비디오 방향 설정
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                // 비디오 미러링 설정
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = false
                }
            }
            
        } catch {
            print("카메라 입력 생성 오류: \(error)")
            return
        }
        
        // 미리보기 레이어 생성
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        
        DispatchQueue.main.async {
            if let previewLayer = self.previewLayer {
                previewLayer.frame = view.bounds
                // 미리보기 레이어 방향 설정
                previewLayer.connection?.videoOrientation = .portrait
                view.layer.insertSublayer(previewLayer, at: 0)
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
    }
    
    // 미리보기 레이어 반환
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        return previewLayer
    }
    
    // 카메라 세션 정지
    func stopCamera() {
        captureSession?.stopRunning()
    }
    
    // 카메라 세션 시작
    func startCamera() {
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession?.startRunning()
            }
        }
    }
    
    // 사진 캡처
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.photoCallback = completion
    }
    
    // 이미지 방향 수정
    private func fixImageOrientation(_ image: UIImage) -> UIImage {
        // 현재 디바이스 방향에 따라 이미지 회전
        let currentOrientation = UIDevice.current.orientation
        var imageOrientation: UIImage.Orientation
        
        imageOrientation = .up
        
        // 새 방향으로 이미지 생성
        if let cgImage = image.cgImage {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: imageOrientation)
        }
        
        return image
    }
    
    // AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let callback = photoCallback,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        // 기본 이미지 생성
        let image = UIImage(cgImage: cgImage)
        
        // 이미지 방향 수정
        let fixedImage = fixImageOrientation(image)
        
        callback(fixedImage)
        self.photoCallback = nil
    }
} 