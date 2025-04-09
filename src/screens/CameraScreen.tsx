import React, { useRef, useState } from 'react';
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

interface CameraViewProps {
  style?: ViewStyle;
}

const CameraView = requireNativeComponent<CameraViewProps>('CameraView');
const { CameraViewManager } = NativeModules;

const CameraScreen = () => {
  const cameraRef = useRef(null);
  const [processing, setProcessing] = useState(false);
  const [showingResult, setShowingResult] = useState(false);

  const handleCapture = async () => {
    if (processing || showingResult) return;
    
    try {
      setProcessing(true);
      const nodeId = findNodeHandle(cameraRef.current);
      if (nodeId) {
        await CameraViewManager.capturePhoto(nodeId);
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
      CameraViewManager.clearOverlay(nodeId);
      setShowingResult(false);
    }
  };

  return (
    <View style={styles.container}>
      <CameraView ref={cameraRef} style={styles.cameraView} />
      <View style={styles.buttonContainer}>
        <TouchableOpacity 
          style={[styles.button, (processing || showingResult) && styles.disabledButton]} 
          onPress={handleCapture}
          disabled={processing || showingResult}>
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
  },
  button: {
    backgroundColor: 'white',
    padding: 15,
    borderRadius: 40,
    width: 80,
    height: 80,
    justifyContent: 'center',
    alignItems: 'center',
  },
  disabledButton: {
    backgroundColor: 'gray',
    opacity: 0.7,
  },
  buttonText: {
    fontSize: 16,
    color: 'black',
  },
});

export default CameraScreen; 