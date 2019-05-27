#if defined(TARGET_IOS) || defined(TARGET_TVOS)
#import <UIKit/UIKit.h>
#define PlatformView UIView
#else
#import <AppKit/AppKit.h>
#define PlatformView NSView
#endif

#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>

@interface MetalView : PlatformView
// the current drawable created within the view's CAMetalLayer
@property (nonatomic, readonly) id<CAMetalDrawable> currentDrawable;
@property (nonatomic) NSUInteger interval;

// Used to pause and resume the controller.
@property (nonatomic, getter=isPaused) BOOL paused;
- (void)dispatchGameLoop;
- (void)stopGameLoop;
@end
