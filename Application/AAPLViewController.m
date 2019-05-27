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
#endif

#ifdef TARGET_IOS
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // run the game loop
    [_view dispatchGameLoop];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // end the gameloop
    [_view stopGameLoop];
}
#endif

@end
