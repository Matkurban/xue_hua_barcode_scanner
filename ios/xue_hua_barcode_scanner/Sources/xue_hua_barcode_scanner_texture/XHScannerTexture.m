#import "XHScannerTexture.h"

@implementation XHScannerTexture {
  CVPixelBufferRef _Nullable _latestPixelBuffer;
  NSLock *_lock;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _lock = [[NSLock alloc] init];
  }
  return self;
}

- (void)dealloc {
  [_lock lock];
  if (_latestPixelBuffer != NULL) {
    CVPixelBufferRelease(_latestPixelBuffer);
    _latestPixelBuffer = NULL;
  }
  [_lock unlock];
}

- (void)updatePixelBuffer:(CVPixelBufferRef)pixelBuffer {
  [_lock lock];
  if (_latestPixelBuffer != NULL) {
    CVPixelBufferRelease(_latestPixelBuffer);
    _latestPixelBuffer = NULL;
  }
  if (pixelBuffer != NULL) {
    CVPixelBufferRetain(pixelBuffer);
    _latestPixelBuffer = pixelBuffer;
  }
  [_lock unlock];
}

- (void)clearPixelBuffer {
  [self updatePixelBuffer:NULL];
}

- (CVPixelBufferRef _Nullable)copyPixelBuffer {
  [_lock lock];
  CVPixelBufferRef buffer = _latestPixelBuffer;
  if (buffer != NULL) {
    CVPixelBufferRetain(buffer);
  }
  [_lock unlock];
  return buffer;
}

@end
