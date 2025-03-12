import React from 'react';
import { requireNativeComponent, ViewProps } from 'react-native';

interface CameraProps extends ViewProps {
  // Add any camera-specific props here if needed
}

const RNCCameraView = requireNativeComponent<CameraProps>('RNCCameraView');

const Camera: React.FC<CameraProps> = (props) => {
  return <RNCCameraView {...props} />;
};

export default Camera; 