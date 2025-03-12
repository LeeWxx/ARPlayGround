import React, {useState} from 'react';
import {
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  SafeAreaView,
  Image,
  ActivityIndicator,
  Alert,
} from 'react-native';
import {launchImageLibrary} from 'react-native-image-picker';
import { SegmentationModule } from '../NativeModules';

const SegmentationScreen = () => {
  const [selectedImage, setSelectedImage] = useState<string | null>(null);
  const [segmentedImage, setSegmentedImage] = useState<string | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);

  const selectImage = async () => {
    const result = await launchImageLibrary({
      mediaType: 'photo',
      includeBase64: true,
      quality: 0.8,
    });

    if (result.assets && result.assets[0]?.base64) {
      setSelectedImage(result.assets[0].base64);
      processImage(result.assets[0].base64);
    }
  };

  const processImage = async (imageBase64: string) => {
    try {
      setIsProcessing(true);
      const result = await SegmentationModule.processImage(imageBase64);
      setSegmentedImage(result);
    } catch (error) {
      Alert.alert('Error', 'Failed to process image');
      console.error(error);
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.imageContainer}>
        {selectedImage ? (
          <Image
            source={{uri: `data:image/jpeg;base64,${segmentedImage || selectedImage}`}}
            style={styles.image}
            resizeMode="contain"
          />
        ) : (
          <Text style={styles.placeholderText}>이미지를 선택해주세요</Text>
        )}
        {isProcessing && (
          <View style={styles.loadingContainer}>
            <ActivityIndicator size="large" color="#fff" />
            <Text style={styles.loadingText}>이미지 분석 중...</Text>
          </View>
        )}
      </View>
      <View style={styles.controlsContainer}>
        <TouchableOpacity style={styles.button} onPress={selectImage}>
          <Text style={styles.buttonText}>이미지 선택</Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  imageContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  image: {
    width: '100%',
    height: '100%',
  },
  placeholderText: {
    color: '#fff',
    fontSize: 16,
  },
  controlsContainer: {
    height: 100,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 20,
  },
  button: {
    backgroundColor: '#2196F3',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 8,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  loadingContainer: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    color: '#fff',
    marginTop: 10,
  },
});

export default SegmentationScreen; 