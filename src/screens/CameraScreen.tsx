import React, { useRef } from 'react';
import {
  StyleSheet,
  requireNativeComponent,
  View,
  ViewStyle,
} from 'react-native';

interface CameraViewProps {
  style?: ViewStyle;
}

const CameraView = requireNativeComponent<CameraViewProps>('CameraView');

const CameraScreen = () => {
  const cameraRef = useRef(null);

  return (
    <View style={styles.container}>
      <CameraView ref={cameraRef} style={styles.cameraView} />
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
});

export default CameraScreen; 