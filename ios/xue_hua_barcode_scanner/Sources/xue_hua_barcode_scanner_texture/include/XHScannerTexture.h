#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

/// Pure Objective-C FlutterTexture so Swift never emits
/// `CVPixelBufferRef __unsafe_unretained` in the generated -Swift.h
/// (which triggers -Wignored-attributes during module builds).
@interface XHScannerTexture : NSObject <FlutterTexture>

- (void)updatePixelBuffer:(nullable CVPixelBufferRef)pixelBuffer;
- (void)clearPixelBuffer;

@end

NS_ASSUME_NONNULL_END
