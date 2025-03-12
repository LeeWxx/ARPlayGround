import {NativeModules} from 'react-native';

interface SegmentationModuleInterface {
  processImage(imageBase64: string): Promise<string>;
}

export const SegmentationModule = NativeModules.SegmentationModule as SegmentationModuleInterface;

export const {RNCCameraViewManager} = NativeModules; 