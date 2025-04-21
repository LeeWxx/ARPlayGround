import React, { useRef, useState, useEffect } from 'react';
import {
  StyleSheet,
  requireNativeComponent,
  NativeModules,
  TouchableOpacity,
  Text,
  View,
  findNodeHandle,
  ViewStyle,
} from 'react-native';

// 환경 변수 import
import { NAIL_BASE_URL } from '@env';

interface CameraViewProps {
  style?: ViewStyle;
  onCaptureComplete?: (event: any) => void;
  onError?: (event: any) => void;
}

export type NailShapeType = 'SQUARE' | 'ROUND' | 'ALMOND' | 'BALLERINA' | 'STILETTO';

interface FingerNailInfo {
  imageUrl: string;
  shape: NailShapeType;
}

export interface NailSetType {
  thumb?: FingerNailInfo;
  index?: FingerNailInfo;
  middle?: FingerNailInfo;
  ring?: FingerNailInfo;
  pinky?: FingerNailInfo;
}

// 네이티브 CameraView 컴포넌트 사용
const CameraView = requireNativeComponent<CameraViewProps>('CameraView');
const { CameraViewManager } = NativeModules;

console.log('CameraViewManager', CameraViewManager);

// CameraViewManager 타입 정의
interface CameraViewManagerType {
  setNailSet: (nodeId: number, nailSet: NailSetType) => void;
  capturePhoto: (nodeId: number) => Promise<void>;
  clearOverlay: (nodeId: number) => void;
}

// 타입 캐스팅
const EnhancedCameraViewManager = CameraViewManager as CameraViewManagerType;

// 네일 이미지 파일 식별자
const NAIL_IMAGE_ID = '2b/2b5c7a1f430ff527dda08c1dc298846ad2e03891810327e3b7ad65563bb32c92.png';

// 환경 변수와 상수를 조합하여 네일 세트 데이터 구성
const SAMPLE_NAIL_SET: NailSetType = {
  thumb: {
    imageUrl: `${NAIL_BASE_URL}/${NAIL_IMAGE_ID}`,
    shape: 'ROUND' as NailShapeType
  },
  index: {
    imageUrl: `${NAIL_BASE_URL}/${NAIL_IMAGE_ID}`,
    shape: 'SQUARE' as NailShapeType
  },
  middle: {
    imageUrl: `${NAIL_BASE_URL}/${NAIL_IMAGE_ID}`,
    shape: 'ALMOND' as NailShapeType
  },
  ring: {
    imageUrl: `${NAIL_BASE_URL}/${NAIL_IMAGE_ID}`,
    shape: 'BALLERINA' as NailShapeType
  },
  pinky: {
    imageUrl: `${NAIL_BASE_URL}/${NAIL_IMAGE_ID}`,
    shape: 'STILETTO' as NailShapeType
  }
};

const CameraScreen = () => {
  const cameraRef = useRef(null);
  const [processing, setProcessing] = useState(false);
  const [showingResult, setShowingResult] = useState(false);
  const [nailSetLoaded, setNailSetLoaded] = useState(false);

  useEffect(() => {
    const applyNailSet = async () => {
      try {
        // 노드 ID 가져오기
        const nodeId = findNodeHandle(cameraRef.current);
        if (!nodeId) {
          console.error('카메라 뷰 참조를 찾을 수 없습니다.');
          return;
        }
        
        // CameraViewManager를 통해 네일 세트 설정
        console.log('NAIL_BASE_URL:', NAIL_BASE_URL);
        console.log('NAIL_IMAGE_ID:', NAIL_IMAGE_ID);
        console.log('네일 세트 적용 시작', JSON.stringify(SAMPLE_NAIL_SET, null, 2));
        
        EnhancedCameraViewManager.setNailSet(nodeId, SAMPLE_NAIL_SET);
        
        // 지연 시간을 3초로 설정
        setTimeout(() => {
          setNailSetLoaded(true);
          console.log('네일 세트 적용 완료 및 로드됨');
        }, 3000);
      } catch (error) {
        console.error('네일 세트 적용 오류:', error);
        setNailSetLoaded(false);
      }
    };

    // 컴포넌트 마운트 시 약간 지연시켜 네일 세트 적용
    setTimeout(applyNailSet, 500);

    return () => {
      console.log('카메라 화면 언마운트');
    };
  }, []);

  const handleCapture = async () => {
    if (processing || showingResult || !nailSetLoaded) return;
    
    try {
      setProcessing(true);
      const nodeId = findNodeHandle(cameraRef.current);
      if (nodeId) {
        // CameraViewManager를 통해 캡처 수행
        await EnhancedCameraViewManager.capturePhoto(nodeId);
        setShowingResult(true);
      }
    } catch (error) {
      console.error('Error during capture and process:', error);
    } finally {
      setProcessing(false);
    }
  };

  const handleClearOverlay = () => {
    if (!showingResult) return;
    
    const nodeId = findNodeHandle(cameraRef.current);
    if (nodeId) {
      // CameraViewManager를 통해 오버레이 초기화
      EnhancedCameraViewManager.clearOverlay(nodeId);
      setShowingResult(false);
    }
  };

  return (
    <View style={styles.container}>
      <CameraView
        ref={cameraRef}
        style={styles.cameraView}
        onCaptureComplete={(event) => console.log('캡처 완료:', event.nativeEvent)}
        onError={(event) => console.error('오류 발생:', event.nativeEvent)}
      />
      <View style={styles.buttonContainer}>
        <TouchableOpacity 
          style={[styles.button, (processing || showingResult || !nailSetLoaded) && styles.disabledButton]} 
          onPress={handleCapture}
          disabled={processing || showingResult || !nailSetLoaded}>
          <Text style={styles.buttonText}>{processing ? '처리 중...' : '캡처'}</Text>
        </TouchableOpacity>
        <TouchableOpacity 
          style={[styles.button, !showingResult && styles.disabledButton]} 
          onPress={handleClearOverlay}
          disabled={!showingResult}>
          <Text style={styles.buttonText}>초기화</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'black',
  },
  cameraView: {
    flex: 1,
  },
  buttonContainer: {
    position: 'absolute',
    bottom: 30,
    left: 0,
    right: 0,
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 20,
    zIndex: 999,
  },
  button: {
    backgroundColor: 'rgba(255, 255, 255, 0.8)',
    padding: 15,
    borderRadius: 40,
    width: 80,
    height: 80,
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 5,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
  },
  disabledButton: {
    backgroundColor: 'rgba(128, 128, 128, 0.7)',
  },
  buttonText: {
    fontSize: 16,
    color: 'black',
    fontWeight: 'bold',
  },
});

export default CameraScreen; 
