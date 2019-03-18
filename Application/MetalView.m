#import "MetalView.h"
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>

@interface MetalView ()
@property (nonatomic, strong) CAMetalLayer *metalLayer;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipeline;
@property (nonatomic, strong) id<MTLBuffer> positionBuffer;
@property (nonatomic, strong) id<MTLBuffer> colorBuffer;
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
	_device = MTLCreateSystemDefaultDevice();
	_metalLayer = (CAMetalLayer *)[self layer];
	_metalLayer.device = _device;
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
	
	self.positionBuffer = [self.device newBufferWithBytes:positions
												   length:sizeof(positions)
												  options:MTLResourceOptionCPUCacheModeDefault];
	self.colorBuffer = [self.device newBufferWithBytes:colors
												length:sizeof(colors)
											   options:MTLResourceOptionCPUCacheModeDefault];
}

- (void)buildPipeline
{
	id<MTLLibrary> library = [self.device newDefaultLibrary];
	id<MTLFunction> vertex = [library newFunctionWithName:@"basicVertex"];
	id<MTLFunction> fragment = [library newFunctionWithName:@"basicFragment"];
	
	MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
	pipelineDescriptor.colorAttachments[0].pixelFormat = self.metalLayer.pixelFormat;
	pipelineDescriptor.vertexFunction = vertex;
	pipelineDescriptor.fragmentFunction = fragment;
	
	NSError *error = nil;
	self.pipeline = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor
																error:&error];
	
	if (!self.pipeline)
	{
		NSLog(@"Error occurred when creating render pipeline state: %@", error);
	}
	
	self.commandQueue = [self.device newCommandQueue];
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
	id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPass];
	[commandEncoder pushDebugGroup:@"screen"];
	[commandEncoder setRenderPipelineState:self.pipeline];
	[commandEncoder setVertexBuffer:self.positionBuffer offset:0 atIndex:0];
	[commandEncoder setVertexBuffer:self.colorBuffer offset:0 atIndex:1];
	[commandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3 instanceCount:1];
	[commandEncoder popDebugGroup];
	[commandEncoder endEncoding];
	[commandBuffer presentDrawable:drawable];
	[commandBuffer commit];
}

// MetalBasic3D-OSX / MetalBasic3D-iOS
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
