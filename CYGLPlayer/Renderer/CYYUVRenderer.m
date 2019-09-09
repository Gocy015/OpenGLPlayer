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
// uniform sampler2D uSamplerY;
// uniform sampler2D uSamplerUV;
 
 void main() {
//     mediump vec3 yuv;
//     mediump vec3 rgb;
//
//     yuv.x = texture2D(uSamplerY, vSamplerCoordinate).r - (16.0 / 255.0);
//     yuv.yz = texture2D(uSamplerUV, vSamplerCoordinate).ra - vec2(128.0 / 255.0, 128.0 / 255.0);
//
//     rgb = yuv;
     gl_FragColor = vec4(0.3, 0.5, 0.7, 1.0);
 }
);


static const int kPositionAttributeIndex = 0;
static const int kSamplerAttributeIndex = 1;

static NSString * const kUniformYPlaneName = @"uSamplerY";
static NSString * const kUniformUVPlaneName = @"uSamplerUV";

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
        _coords[0] = (CoordInfo){{-1, -1, 0},{0, 0}};
        _coords[1] = (CoordInfo){{-1, 1, 0},{0, 1}};
        _coords[2] = (CoordInfo){{1, -1, 0},{1, 0}};
        _coords[3] = (CoordInfo){{1, 1, 0},{1, 1}};
    }
    return self;
}

- (void)renderAfterPreviousItem:(CYYUVRenderChainItem *)item inContext:(EAGLContext *)context
{
    if (_program == 0) {
        [self _doInitProgram];
    }
    
    glUseProgram(_program);
    
    CGSize frameSize = self.frameBuffer.size;
    
    glClearColor(0.0f, 1.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, frameSize.width, frameSize.height);
    
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer.frameBufferID);
    
    GLuint buffer;
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ARRAY_BUFFER, buffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(CoordInfo) * 4, _coords, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(kPositionAttributeIndex);
    glVertexAttribPointer(kPositionAttributeIndex, 3, GL_FLOAT, GL_FALSE, sizeof(CoordInfo), (const GLvoid *)offsetof(CoordInfo, Position));
    
    glEnableVertexAttribArray(kSamplerAttributeIndex);
    glVertexAttribPointer(kSamplerAttributeIndex, 2, GL_FLOAT, GL_FALSE, sizeof(CoordInfo), (const GLvoid *)offsetof(CoordInfo, TextureCoords));
    
//    GLint yIndex = [self uniformIndex:kUniformYPlaneName];
//    GLint uvIndex = [self uniformIndex:kUniformUVPlaneName];
//
//    CVOpenGLESTextureRef yTexture = [self openGLTextureFromPixelBuffer:item.pixelBuffer pixelFormat:GL_LUMINANCE planeIndex:0 size:frameSize context:context];
//    CVOpenGLESTextureRef uvTexture = [self openGLTextureFromPixelBuffer:item.pixelBuffer pixelFormat:GL_LUMINANCE_ALPHA planeIndex:1 size:CGSizeMake((int32_t)frameSize.width >> 1, (int32_t)frameSize.height >> 1) context:context];
//
//    //todo: cfrelease
//
//    glActiveTexture(GL_TEXTURE1);
//    glBindTexture(GL_TEXTURE_2D, CVOpenGLESTextureGetName(yTexture));
//    glUniform1i(yIndex, 1);
//
//    glActiveTexture(GL_TEXTURE2);
//    glBindTexture(GL_TEXTURE_2D, CVOpenGLESTextureGetName(uvTexture));
//    glUniform1i(uvIndex, 2);
    
//    glBindTexture(GL_TEXTURE_2D, self.frameBuffer.textureID);
    CY_GET_GLERROR();
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    CY_GET_GLERROR();
//    glActiveTexture(GL_TEXTURE1);
//    glBindTexture(GL_TEXTURE_2D, self.frameBuffer.textureID);
//    UIImage *result = [self imageFromTextureWithwidth:frameSize.width height:frameSize.height];
//    NSLog(@"%@", result);
  
    
    glUseProgram(0);
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
    
    NSAssert(res == kCVReturnSuccess, @"Unable to create texture.");

    // same as GL_TEXTURE_2D
    glBindTexture(CVOpenGLESTextureGetTarget(cvTextureRef), CVOpenGLESTextureGetName(cvTextureRef));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
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
