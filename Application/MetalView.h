#if defined(TARGET_IOS) || defined(TARGET_TVOS)
#import <UIKit/UIKit.h>
#define PlatformView UIView
#else
#import <AppKit/AppKit.h>
#define PlatformView NSView
#endif

@interface MetalView : PlatformView
@end
