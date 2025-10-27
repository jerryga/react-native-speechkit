#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(SpeechToText, RCTEventEmitter)

RCT_EXTERN_METHOD(startSpeechRecognition:(NSString *)fileURLString
                  autoStopAfter:(NSNumber *)autoStopAfter
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(stopSpeechRecognition)

@end
