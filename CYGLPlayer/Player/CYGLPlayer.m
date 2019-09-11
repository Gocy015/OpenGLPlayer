//
//  CYGLPlayer.m
//  CYGLPlayer
//
//  Created by Gocy on 2019/9/3.
//  Copyright © 2019 Gocy. All rights reserved.
//

#import "CYGLPlayer.h"
#import "CYYUVRenderChain.h"
#import <AVFoundation/AVFoundation.h>
#import "CYOpenGLTools.h"
#import "CYGLDefines.h"


#define STRINGIFY(_str_) @""#_str_""
static NSString * kVertString = STRINGIFY
(
 attribute vec4 aPosition;
 attribute vec2 aSamplerCoordinate;
 varying vec2 vSamplerCoordinate;
 
 void main() {
     gl_Position = aPosition;
     vSamplerCoordinate = aSamplerCoordinate;
 }
 );

static NSString * kFragString = STRINGIFY
(
 precision mediump float;
 varying mediump vec2 vSamplerCoordinate;
 uniform sampler2D uSamplerTexture;
 
 void main() {
     vec4 textureColor = texture2D(uSamplerTexture, vSamplerCoordinate);
     gl_FragColor = textureColor;
 }
 );

@interface CYGLPlayer ()<CYYUVRenderOutput>

@property (nonatomic, strong) NSURL *videoURL;
@property (nonatomic, strong) AVPlayerItemVideoOutput *videoOutput;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayer *player;

@property (nonatomic, strong) CADisplayLink *renderLink;
@property (nonatomic, assign) NSTimeInterval lastFrameTime;
@property (nonatomic, assign) BOOL playWhenReady;

@property (nonatomic, strong) CYYUVRenderChain *chain;

// render output
@property (nonatomic, strong) EAGLContext *displayContext;
@property (nonatomic, strong) CAEAGLLayer *displayLayer;
@property (nonatomic, assign) GLuint displayFramebufferID;
@property (nonatomic, assign) GLuint displayRenderbufferID;
@property (nonatomic, assign) GLuint displayProgram;
@property (nonatomic, assign) CoordInfo *coords;
@property (nonatomic, assign) GLint textureSlot;

//test
@property (nonatomic, assign) GLuint testTextureID;


@end

static void *kPlayItemStatusContext;
static void *kPlayerStatusContext;

static const GLint kPositionAttributeIndex = 0;
static const GLint kSampleCoordsAttributeIndex = 1;

@implementation CYGLPlayer

- (instancetype)initWithVideoURL:(NSURL *)url
{
    self = [super init];
    if (self) {
        _videoURL = url;
        self.backgroundColor = UIColor.blackColor;
        self.bounds = UIScreen.mainScreen.bounds;
        [self _doInit];
    }
    return self;
}

- (void)_doInit
{
    // 事实证明这个 format 很重要，匹配不上是拿不到 pixelbuffer 的，想想也是，解码解不了
    // todo: 晚点再看从 avasset 获取 format 的代码
    NSDictionary *settings = @{
                               (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
                               (id)kCVPixelBufferOpenGLCompatibilityKey: @YES,
//                               (id)kCVPixelBufferBytesPerRowAlignmentKey:@(1),
//                               (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
                               };
    _playerItem = [AVPlayerItem playerItemWithURL:_videoURL];
    _videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:settings];
    
    _player = [[AVPlayer alloc] initWithPlayerItem:_playerItem];
    
    [_playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:&kPlayItemStatusContext];
    [_player addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:&kPlayerStatusContext];
    
    _chain = [CYYUVRenderChain new];
    [_chain addOutput:self];
    
    _coords = malloc(sizeof(CoordInfo) * 4);
    _coords[0] = (CoordInfo){{-1, -1, 0},{0, 0}};
    _coords[1] = (CoordInfo){{-1, 1, 0},{0, 1}};
    _coords[2] = (CoordInfo){{1, -1, 0},{1, 0}};
    _coords[3] = (CoordInfo){{1, 1, 0},{1, 1}};
    
    dispatch_sync_task(^{
       [self initDisplayContext];
    });
    
}

- (void)initDisplayContext
{
    _displayContext = _chain.context;//[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [CYOpenGLTools ensureContext:_displayContext];
    
    _displayLayer = [CAEAGLLayer new];
    _displayLayer.contentsScale = UIScreen.mainScreen.scale;
    _displayLayer.frame = self.layer.bounds;
    _displayLayer.backgroundColor = UIColor.cyanColor.CGColor;
    [self.layer addSublayer:_displayLayer];
    
    _displayProgram = [CYOpenGLTools programWithVertexShaderCode:kVertString fragmentShaderCode:kFragString beforeLinking:^(GLuint program) {
        glBindAttribLocation(program, kPositionAttributeIndex, "aPosition");
        glBindAttribLocation(program, kSampleCoordsAttributeIndex, "aSamplerCoordinate");
        
    }];
    
    _textureSlot = glGetUniformLocation(_displayProgram, "uSamplerTexture");
    
    [CYOpenGLTools bindRenderLayer:_displayLayer toContext:_displayContext withRenderBuffer:&_displayRenderbufferID frameBuffer:&_displayFramebufferID];
    
    _testTextureID = [CYOpenGLTools textureFromImage:[UIImage imageNamed:@"batman"]];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
//    _displayLayer.frame = self.layer.bounds;
}

- (void)dealloc
{
    if (_playerItem) {
        [_playerItem removeObserver:self forKeyPath:@"status" context:&kPlayItemStatusContext];
    }
    if (_coords) {
        free(_coords);
        _coords = NULL;
    }
}

- (void)play
{
    [self.renderLink invalidate];
    self.renderLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderLinkFired:)];
    self.renderLink.preferredFramesPerSecond = 60;
    
    self.playWhenReady = YES;
    if (self.playerItem.status != AVPlayerItemStatusReadyToPlay) {
        self.renderLink.paused = YES;
    } else {
        [self.player play];
    }
    [self.renderLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)renderLinkFired:(CADisplayLink *)displayLink
{
    CFTimeInterval nextFrameTime = displayLink.timestamp + displayLink.duration;
    CMTime nextFrameCMTime = [self.videoOutput itemTimeForHostTime:nextFrameTime];
    
    if (![self.videoOutput hasNewPixelBufferForItemTime:nextFrameCMTime]) {
        return ;
    }
    
    CMTime frameTime;
    CVPixelBufferRef pixelBuffer = [self.videoOutput copyPixelBufferForItemTime:nextFrameCMTime itemTimeForDisplay:&frameTime];
    
    if (!pixelBuffer) {
        return ;
    }
    
    NSTimeInterval thisFrameTime = CMTimeGetSeconds(frameTime);
    if (thisFrameTime - self.lastFrameTime > 0.1f) { // 掉帧？
        CVPixelBufferRelease(pixelBuffer);
        return;
    }
    
    [self.chain render:pixelBuffer];
    
    CVPixelBufferRelease(pixelBuffer);
    
    self.lastFrameTime = thisFrameTime;
}

#pragma mark - RenderOutput

- (void)cyyuv_frameBufferOutput:(CYFrameBuffer *)framebuffer
{
    [CYOpenGLTools ensureContext:_displayContext];
    
    
    glUseProgram(_displayProgram);
    glViewport(0, 0, framebuffer.size.width, framebuffer.size.height);
    
    glBindFramebuffer(GL_FRAMEBUFFER, _displayFramebufferID);
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, framebuffer.textureID);
    glUniform1i(_textureSlot, 1);
    
    GLuint buffer;
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ARRAY_BUFFER, buffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(CoordInfo) * 4, _coords, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(kPositionAttributeIndex);
    glVertexAttribPointer(kPositionAttributeIndex, 3, GL_FLOAT, GL_FALSE, sizeof(CoordInfo), (const GLvoid *)offsetof(CoordInfo, Position));
    
    glEnableVertexAttribArray(kSampleCoordsAttributeIndex);
    glVertexAttribPointer(kSampleCoordsAttributeIndex, 2, GL_FLOAT, GL_FALSE, sizeof(CoordInfo), (const GLvoid *)offsetof(CoordInfo, TextureCoords));
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glBindRenderbuffer(GL_RENDERBUFFER, _displayRenderbufferID);
    
    BOOL presented = [_displayContext presentRenderbuffer:GL_RENDERBUFFER];
    NSLog(@"rendering %i", presented);
//    glBindRenderbuffer(GL_RENDERBUFFER, 0);
//    glBindFramebuffer(GL_FRAMEBUFFER, 0);
//    glUseProgram(0);
//    glDeleteBuffers(1, &buffer);
    

    
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kPlayItemStatusContext) {
        if (self.playerItem.status == AVPlayerItemStatusReadyToPlay && self.playWhenReady) {
            self.playWhenReady = NO;
            NSLog(@"Player item ready");
            [_playerItem addOutput:_videoOutput];
            [self.player play];
            if (self.renderLink.paused) {
                self.renderLink.paused = NO;
            }
        }
    } else if (context == &kPlayerStatusContext) {
        NSLog(@"player status: %ld", (long)self.player.status);
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
