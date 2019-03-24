#import "MetalView.h"
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>
#import "mtlpp.hpp"

@interface MetalView ()
@property (nonatomic, strong) CAMetalLayer *metalLayer;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property mtlpp::RenderPipelineState pipeline;
@property mtlpp::Buffer positionBuffer;
@property mtlpp::Buffer colorBuffer;
@property mtlpp::Device device;
@property CVDisplayLinkRef displayLink;
@end

@implementation MetalView

- (CVReturn) getFrameForTime:(const CVTimeStamp*)outputTime
{
	@autoreleasepool {
		[self redraw];
		return kCVReturnSuccess;
	}
}

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

#if defined(TARGET_MACOS)
- (CALayer*)makeBackingLayer
{
	return [CAMetalLayer layer];
}
#endif

+ (Class)layerClass
{
	return [CAMetalLayer class];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder]))
	{
#if defined(TARGET_MACOS)
		[self setWantsLayer:true];
#endif // defined(TARGET_MACOS)
		
		[self buildDevice];
		[self buildVertexBuffers];
		[self buildPipeline];
		
#if defined(TARGET_MACOS)
		CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
		CVDisplayLinkSetOutputCallback(_displayLink, &dispatchGameLoop, (__bridge void *)(self));
		CVDisplayLinkStart(_displayLink);
#endif
	}
	return self;
}

- (void)dealloc
{
}

- (CGFloat)getScaleFactor
{
#if defined(TARGET_IOS) || defined(TARGET_TVOS)
	return [UIScreen mainScreen].scale;
#else
	return [self.window.screen backingScaleFactor];
#endif //  defined(TARGET_IOS) || defined(TARGET_TVOS)
}

- (void)buildDevice
{
    _device = mtlpp::Device::CreateSystemDefaultDevice();
	_metalLayer = (CAMetalLayer *)[self layer];
	_metalLayer.device = (__bridge id<MTLDevice>)_device.GetPtr();
	_metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
	//_metalLayer.contentsScale = [self getScaleFactor];
	_metalLayer.framebufferOnly = true;
	_metalLayer.opaque = true;
	_metalLayer.backgroundColor = nil;
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

- (void)redraw
{
	id<CAMetalDrawable> drawable = [self.metalLayer nextDrawable];
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
}

// source from: MetalBasic3D-OSX / MetalBasic3D-iOS
#if defined(TARGET_IOS) || defined(TARGET_TVOS)
- (void)didMoveToWindow
{
	self.contentScaleFactor = self.window.screen.nativeScale;
	// Test: [self getScaleFactor];
}

- (void)setContentScaleFactor:(CGFloat)contentScaleFactor
{
	[super setContentScaleFactor:contentScaleFactor];
	_layerSizeDidUpdate = YES;
}

- (void)layoutSubviews() {
	[super layoutSubviews];
	_layerSizeDidUpdate = YES;
}
#else

#endif

@end
