#if defined(TARGET_IOS) || defined(TARGET_TVOS)
@import UIKit;
#define PlatformView UIView
#else
@import AppKit;
#define PlatformView NSView
#endif

@interface MetalView : PlatformView
@end