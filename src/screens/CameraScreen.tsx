import React, { useRef } from 'react';
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

  const handleCapture = async () => {
    try {
      const nodeId = findNodeHandle(cameraRef.current);
      if (nodeId) {
        await CameraViewManager.capturePhoto(nodeId);
      }
    } catch (error) {
      console.error('Error during capture and process:', error);
    }
  };

  const handleClearOverlay = () => {
    const nodeId = findNodeHandle(cameraRef.current);
    if (nodeId) {
      CameraViewManager.clearOverlay(nodeId);
    }
  };

  return (
    <View style={styles.container}>
      <CameraView ref={cameraRef} style={styles.cameraView} />
      <View style={styles.buttonContainer}>
        <TouchableOpacity style={styles.button} onPress={handleCapture}>
          <Text style={styles.buttonText}>캡처</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.button} onPress={handleClearOverlay}>
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
  buttonText: {
    fontSize: 16,
    color: 'black',
  },
});

export default CameraScreen; 