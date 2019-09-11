//
//  CYYUVRenderer.m
//  CYGLPlayer
//
//  Created by Gocy on 2019/9/3.
//  Copyright © 2019 Gocy. All rights reserved.
//

#import "CYYUVRenderer.h"
#import "CYOpenGLTools.h"
#import "CYGLDefines.h"

#define STRINGIFY(_str_) @""#_str_""

// uniform mat4 uModelViewProjMatrix;
// shader glsl
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
 uniform sampler2D uSamplerY;
 uniform sampler2D uSamplerUV;
 uniform float uFullRange;
 uniform mediump mat3 uColorConversionMatrix;
 
 void main() {
     mediump vec3 yuv;
     mediump vec3 rgb;
     // https://blog.csdn.net/CAICHAO1234/article/details/79260954
     if (uFullRange == 1.0) {
         yuv.x = texture2D(uSamplerY, vSamplerCoordinate).r;
         yuv.yz = texture2D(uSamplerUV, vSamplerCoordinate).ra - vec2(128.0 / 255.0, 128.0 / 255.0);
     } else {
         yuv.x = texture2D(uSamplerY, vSamplerCoordinate).r - (16.0 / 255.0);
         yuv.yz = texture2D(uSamplerUV, vSamplerCoordinate).ra - vec2(128.0 / 255.0, 128.0 / 255.0);
     }
     
     rgb = uColorConversionMatrix * yuv;
     gl_FragColor = vec4(rgb, 1);
 }
);


static const int kPositionAttributeIndex = 0;
static const int kSamplerAttributeIndex = 1;

static NSString * const kUniformYPlaneName = @"uSamplerY";
static NSString * const kUniformUVPlaneName = @"uSamplerUV";
static NSString * const kUniformColorConversionName = @"uColorConversionMatrix";
static NSString * const kUniformColorRangeName = @"uFullRange";

static GLfloat kColorConversion601FullRange[] = {
    1.0f,       1.0f,       1.0f,
    0.0f,       -0.343f,    1.765f,
    1.4f,       -0.711f,    0.0f,
};

@interface CYYUVRenderer (){
    CVOpenGLESTextureRef _lumaTexture;
    CVOpenGLESTextureRef _chromaTexture;
    CVOpenGLESTextureCacheRef _textureCache;
}

@property (nonatomic, assign) GLuint program;
@property (nonatomic, strong) NSMutableDictionary *uniformLocationMap;
@property (nonatomic, assign) CoordInfo *coords;

@end

@implementation CYYUVRenderer

- (instancetype)init
{
    self = [super init];
    if (self) {
        _uniformLocationMap = [NSMutableDictionary new];
        _coords = malloc(sizeof(CoordInfo) * 4);
        
        float val = 1;
        _coords[0] = (CoordInfo){{-val, -val, 0},{0, 0}};
        _coords[1] = (CoordInfo){{-val, val, 0},{0, 1}};
        _coords[2] = (CoordInfo){{val, -val, 0},{1, 0}};
        _coords[3] = (CoordInfo){{val, val, 0},{1, 1}};
    }
    return self;
}

- (void)renderAfterPreviousItem:(CYYUVRenderChainItem *)item inContext:(EAGLContext *)context
{
    if (_program == 0) {
        [self _doInitProgram];
    }
    
    glUseProgram(_program);
    
    GLsizei frameWidth = (GLsizei)CVPixelBufferGetWidth(item.pixelBuffer);
    GLsizei frameHeight = (GLsizei)CVPixelBufferGetHeight(item.pixelBuffer);
    
    CGSize frameSize = CGSizeMake(frameWidth, frameHeight);
    
    
    
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer.frameBufferID);
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    CGRect viewPort = [self viewPortForSize:frameSize];
    glViewport(viewPort.origin.x, viewPort.origin.y, viewPort.size.width, viewPort.size.height);
    
    GLuint buffer;
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ARRAY_BUFFER, buffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(CoordInfo) * 4, _coords, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(kPositionAttributeIndex);
    glVertexAttribPointer(kPositionAttributeIndex, 3, GL_FLOAT, GL_FALSE, sizeof(CoordInfo), (const GLvoid *)offsetof(CoordInfo, Position));
    
    glEnableVertexAttribArray(kSamplerAttributeIndex);
    glVertexAttribPointer(kSamplerAttributeIndex, 2, GL_FLOAT, GL_FALSE, sizeof(CoordInfo), (const GLvoid *)offsetof(CoordInfo, TextureCoords));
    
    GLint yIndex = [self uniformIndex:kUniformYPlaneName];
    GLint uvIndex = [self uniformIndex:kUniformUVPlaneName];
    
    CVOpenGLESTextureRef yTexture = [self openGLTextureFromPixelBuffer:item.pixelBuffer pixelFormat:GL_LUMINANCE planeIndex:0 size:frameSize context:context];
    CVOpenGLESTextureRef uvTexture = [self openGLTextureFromPixelBuffer:item.pixelBuffer pixelFormat:GL_LUMINANCE_ALPHA planeIndex:1 size:CGSizeMake((int32_t)frameSize.width >> 1, (int32_t)frameSize.height >> 1) context:context];

    //todo: cvrelease

    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, CVOpenGLESTextureGetName(yTexture));
    glUniform1i(yIndex, 1);

    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, CVOpenGLESTextureGetName(uvTexture));
    glUniform1i(uvIndex, 2);
    
//    glBindTexture(GL_TEXTURE_2D, self.frameBuffer.textureID);
    GLint colorIndex = [self uniformIndex:kUniformColorConversionName];
    GLint colorRangeIndex = [self uniformIndex:kUniformColorRangeName];
    
    // todo: logic to determine yuv range
    glUniformMatrix3fv(colorIndex, 1, GL_FALSE, kColorConversion601FullRange);
    glUniform1f(colorRangeIndex, 1.0);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    
    CFRelease(yTexture);
    CFRelease(uvTexture);
    
}

- (CGRect)viewPortForSize:(CGSize)size
{
    // aspect fit
    if (size.width == 0 || size.height == 0) {
        return CGRectZero;
    }
    CGFloat widthRatio = self.frameBuffer.size.width / size.width;
    CGFloat heightRatio = self.frameBuffer.size.height / size.height;
    
    CGFloat finalRatio = widthRatio;
    if (widthRatio > heightRatio) { // target height is higher, we need to scale based on height
        finalRatio = heightRatio;
    }
    
    CGFloat finalWidth = size.width * finalRatio;
    CGFloat finalHeight = size.height * finalRatio;
    
    CGFloat xGap = self.frameBuffer.size.width - finalWidth;
    CGFloat yGap = self.frameBuffer.size.height - finalHeight;
    return CGRectMake(xGap/2, yGap/2, finalWidth, finalHeight);
}

- (UIImage *)imageFromTextureWithwidth:(int)width height:(int)height {
    // glActiveTexture(GL_TEXTURE1); 先绑定某个纹理
    int size = width * height * 4;
    GLubyte *buffer = malloc(size);
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, buffer);
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer, size, NULL);
    int bitsPerComponent = 8;
    int bitsPerPixel = 32;
    int bytesPerRow = 4 * width;
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    CGImageRef imageRef = CGImageCreate(width, height, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    free(buffer);
    return image;
}

- (CVOpenGLESTextureRef)openGLTextureFromPixelBuffer:(CVPixelBufferRef)pixelBuffer pixelFormat:(GLint)format planeIndex:(size_t)planeIndex size:(CGSize)size context:(EAGLContext *)context
{
    if (_textureCache == NULL) {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, context, NULL, &_textureCache);
        NSAssert(err == kCVReturnSuccess, @"Unable to create texture cache.");
    }
    
    CVOpenGLESTextureRef cvTextureRef = NULL;
    CY_GET_GLERROR()
    CVReturn res = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _textureCache,
                                                       pixelBuffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       format,
                                                       size.width,
                                                       size.height,
                                                       format,
                                                       GL_UNSIGNED_BYTE,
                                                       planeIndex,
                                                       &cvTextureRef);
    
//    GLenum err = glGetError();
    NSAssert(res == kCVReturnSuccess, @"Unable to create texture.");

    // same as GL_TEXTURE_2D
    glBindTexture(CVOpenGLESTextureGetTarget(cvTextureRef), CVOpenGLESTextureGetName(cvTextureRef));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glFinish();
    
    return cvTextureRef;
}

- (void)_doInitProgram
{
    _program = [CYOpenGLTools programWithVertexShaderCode:kVertString fragmentShaderCode:kFragString beforeLinking:^(GLuint program) {
        glBindAttribLocation(program, kPositionAttributeIndex, "aPosition");
        glBindAttribLocation(program, kSamplerAttributeIndex, "aSamplerCoordinate");
    }];
    
    NSAssert(_program != 0, @"Fail to create program");
}

- (GLint)uniformIndex:(NSString *)name
{
    if (_uniformLocationMap[name] == nil) {
        GLint loc = glGetUniformLocation(_program, name.UTF8String);
        NSAssert(loc != -1, @"No uniform loc for name %@", name);
        
        _uniformLocationMap[name] = @(loc);
    }
    
    return [_uniformLocationMap[name] intValue];
}

@end
