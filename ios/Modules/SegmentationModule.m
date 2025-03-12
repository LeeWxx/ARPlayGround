#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(SegmentationModule, NSObject)

RCT_EXTERN_METHOD(processImage:(NSString *)imageBase64
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

@end 