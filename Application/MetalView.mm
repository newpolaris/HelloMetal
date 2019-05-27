#import "MetalView.h"
#import "mtlpp.hpp"

@interface MetalView ()
@property (nonatomic, strong) CAMetalLayer *metalLayer;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property mtlpp::RenderPipelineState pipeline;
@property mtlpp::Buffer positionBuffer;
@property mtlpp::Buffer colorBuffer;
@end

@implementation MetalView
{
@private
    
#ifdef TARGET_IOS
    CADisplayLink *_displayLink;
#else
    CVDisplayLinkRef _displayLink;
    dispatch_source_t _displaySource;
#endif
    
    mtlpp::Device _device;
    
    BOOL _layerSizeDidUpdate;
    BOOL _gameLoopPaused;
}
@synthesize currentDrawable = _currentDrawable;

- (id<MTLDevice>)getDevice
{
    return (__bridge id<MTLDevice>)_device.GetPtr();
}

- (CVReturn)getFrameForTime:(const CVTimeStamp*)outputTime
{
    dispatch_async (dispatch_get_main_queue (), ^{
        [self redraw];
    });
    return kCVReturnSuccess;
}

#if TARGET_IOS
- (void)dispatchGameLoop
{
    // create a game loop timer using a display link
    _displayLink = [[UIScreen mainScreen] displayLinkWithTarget:self
                                                       selector:@selector(redraw)];
    _displayLink.preferredFramesPerSecond = 60;
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                       forMode:NSDefaultRunLoopMode];
}
#else
// This is the renderer output callback function
static CVReturn dispatchGameLoop(CVDisplayLinkRef displayLink,
								 const CVTimeStamp *now,
								 const CVTimeStamp *outputTime,
								 CVOptionFlags flagsIn,
								 CVOptionFlags *flagsOut,
								 void *displayLinkContext)
{
	CVReturn result = [(__bridge MetalView*)displayLinkContext getFrameForTime:outputTime];
	return result;
}
#endif // TARGET_OSX

+ (Class)layerClass
{
	return [CAMetalLayer class];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self)
    {
        [self initCommon];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super initWithCoder:coder]))
	{
        [self initCommon];
	}
	return self;
}

- (void)initCommon
{
#ifdef TARGET_IOS
    _metalLayer = (CAMetalLayer *)self.layer;
#else
    self.wantsLayer = YES;
    self.layer = _metalLayer = [CAMetalLayer layer];
#endif
    
    _device = mtlpp::Device::CreateSystemDefaultDevice();
    
    _metalLayer.device = (__bridge id<MTLDevice>)_device.GetPtr();
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    _metalLayer.framebufferOnly = YES;
    _metalLayer.opaque = YES;
    _metalLayer.backgroundColor = nil;

    [self buildVertexBuffers];
    [self buildPipeline];
    
#if defined(TARGET_MACOS)
    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
    CVDisplayLinkSetOutputCallback(_displayLink, &dispatchGameLoop, (__bridge void *)(self));
    CVDisplayLinkStart(_displayLink);
#endif
}

- (void)dealloc
{
#ifdef TARGET_IOS
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: UIApplicationDidEnterBackgroundNotification
                                                  object: nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: UIApplicationWillEnterForegroundNotification
                                                  object: nil];
#endif
    
    if (_displayLink)
    {
        [self stopGameLoop];
    }
}

- (void)stopGameLoop
{
    if (_displayLink)
    {
#ifdef TARGET_IOS
        [_displayLink invalidate];
#else
        // Stop the display link BEFORE releasing anything in the view
        // otherwise the display link thread may call into the view and crash
        // when it encounters something that has been release
        CVDisplayLinkStop(_displayLink);
        dispatch_source_cancel(_displaySource);
        
        CVDisplayLinkRelease(_displayLink);
        _displaySource = nil;
#endif
    }
}

- (CGFloat)getScaleFactor
{
#if defined(TARGET_IOS) || defined(TARGET_TVOS)
	return [UIScreen mainScreen].scale;
#else
	return [self.window.screen backingScaleFactor];
#endif
}

- (void)buildVertexBuffers
{
	static const float positions[] =
	{
		0.0,  0.5, 0, 1,
		-0.5, -0.5, 0, 1,
		0.5, -0.5, 0, 1,
	};
	
	static const float colors[] =
	{
		1, 0, 0, 1,
		0, 1, 0, 1,
		0, 0, 1, 1,
	};
    _positionBuffer = _device.NewBuffer(positions, sizeof(positions), mtlpp::ResourceOptions::CpuCacheModeDefaultCache);
    _colorBuffer = _device.NewBuffer(colors, sizeof(colors), mtlpp::ResourceOptions::CpuCacheModeDefaultCache);
}

- (void)buildPipeline
{
	id<MTLLibrary> library = [(__bridge id<MTLDevice>)_device.GetPtr() newDefaultLibrary];
	id<MTLFunction> vertex = [library newFunctionWithName:@"basicVertex"];
	id<MTLFunction> fragment = [library newFunctionWithName:@"basicFragment"];
	
	MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
	pipelineDescriptor.colorAttachments[0].pixelFormat = self.metalLayer.pixelFormat;
	pipelineDescriptor.vertexFunction = vertex;
	pipelineDescriptor.fragmentFunction = fragment;
	
    ns::Error *error = nullptr;
    _pipeline = _device.NewRenderPipelineState(ns::Handle{(__bridge void*)pipelineDescriptor}, error);
	
	if (!self.pipeline)
	{
        NSError* nsError = error ? (__bridge NSError*)error->GetPtr() : nullptr;
        NSLog(@"Error occurred when creating render pipeline state: %@", nsError);
	}
	
    self.commandQueue = (__bridge id<MTLCommandQueue>)_device.NewCommandQueue().GetPtr();
}

- (id<CAMetalDrawable>)currentDrawable
{
    if (_currentDrawable == nil)
        _currentDrawable = [_metalLayer nextDrawable];
    
    return _currentDrawable;
}

- (void)redraw
{
	id<CAMetalDrawable> drawable = self.currentDrawable;
	id<MTLTexture> framebufferTexture = drawable.texture;
	
	MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor renderPassDescriptor];
	renderPass.colorAttachments[0].texture = framebufferTexture;
	renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1);
	renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
	renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
	
	id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
	id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPass];
    mtlpp::RenderCommandEncoder commandEncoder = ns::Handle{(__bridge void*)encoder};
    commandEncoder.PushDebugGroup("screen");
    commandEncoder.SetRenderPipelineState(self.pipeline);
    commandEncoder.SetVertexBuffer(self.positionBuffer, 0, 0);
    commandEncoder.SetVertexBuffer(self.colorBuffer, 0, 1);
    commandEncoder.Draw(mtlpp::PrimitiveType::Triangle, 0, 3, 1);
    commandEncoder.PopDebugGroup();
    commandEncoder.EndEncoding();
	[commandBuffer presentDrawable:drawable];
	[commandBuffer commit];
    
    _currentDrawable = nil;
}

#if defined(TARGET_IOS) || defined(TARGET_TVOS)
- (void)didMoveToWindow
{
	self.contentScaleFactor = self.window.screen.nativeScale;
}

- (void)setContentScaleFactor:(CGFloat)contentScaleFactor
{
	[super setContentScaleFactor:contentScaleFactor];
	_layerSizeDidUpdate = YES;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	_layerSizeDidUpdate = YES;
}
#else
- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    _layerSizeDidUpdate = YES;
}

- (void)setBoundsSize:(NSSize)newSize
{
    [super setBoundsSize:newSize];
    _layerSizeDidUpdate = YES;
}
- (void)viewDidChangeBackingProperties
{
    [super viewDidChangeBackingProperties];
    _layerSizeDidUpdate = YES;
}
#endif

@end
