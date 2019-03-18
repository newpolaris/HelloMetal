/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of our cross-platform view controller
*/

#import "AAPLViewController.h"
#import "AAPLRenderer.h"
#import "MetalView.h"

@implementation AAPLViewController
{
    MetalView *_view;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Set the view to use the default device
    _view = (MetalView *)self.view;
}

#if defined(TARGET_IOS) || defined(TARGET_TVOS)
- (BOOL)prefersStatusBarHidden {
	return YES;
}
#endif // defined(TARGET_IOS) || defined(TARGET_TVOS)

@end
