//
//  CYOpenGLTools.m
//  BeginOpenGLES
//
//  Created by Gocy on 2019/8/17.
//  Copyright © 2019 Gocy. All rights reserved.
//

#import "CYOpenGLTools.h"
#import <UIKit/UIKit.h>
#import "CYGLDefines.h"

@implementation CYOpenGLTools

+ (void)bindRenderLayer:(CALayer <EAGLDrawable> *)layer toContext:(EAGLContext *)context
{
    GLuint renderBuffer;
    GLuint frameBuffer;
    
    [self bindRenderLayer:layer toContext:context withRenderBuffer:&renderBuffer frameBuffer:&frameBuffer];
}

+ (void)bindRenderLayer:(CALayer<EAGLDrawable> *)layer toContext:(EAGLContext *)context withRenderBuffer:(GLuint *)renderBuffer frameBuffer:(GLuint *)frameBuffer
{
    
    glGenRenderbuffers(1, renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, *renderBuffer);
    NSLog(@"width before bufferstorage: %i", [self drawableWidth]);
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
    NSLog(@"width after bufferstorage: %i", [self drawableWidth]);
    
    glGenFramebuffers(1, frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, *frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, *renderBuffer);
    
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
//    NSLog(@"width after unbind: %i", [self drawableWidth]);
    
}

+ (GLuint)textureFromImage:(UIImage *)image
{
    CGImageRef imageRef = image.CGImage;
    
    GLuint width = (GLuint)CGImageGetWidth(imageRef);
    GLuint height = (GLuint)CGImageGetHeight(imageRef);
    
    CGRect rect = CGRectMake(0, 0, width, height);
    
    // draw image
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    void *imageData = malloc(width * height * 4);
    CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1, -1);
    CGColorSpaceRelease(colorSpace);
    CGContextClearRect(context, rect);
    CGContextDrawImage(context, rect, imageRef);
    
    // get texture
    GLuint textureID;
    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    
    // mapping, texture -> pixel https://learnopengl-cn.readthedocs.io/zh/latest/01%20Getting%20started/06%20Textures/
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    glBindTexture(GL_TEXTURE_2D, 0);
    
    CGContextRelease(context);
    free(imageData);
    
    return textureID;
}

+ (void)ensureContext:(EAGLContext *)context
{
    if ([EAGLContext currentContext] == context) {
        return ;
    }
    [EAGLContext setCurrentContext:context];
}

+ (GLuint)compileShaderWithName:(NSString *)name type:(GLenum)type
{
    NSString *shaderPath = [NSBundle.mainBundle pathForResource:name ofType:type == GL_VERTEX_SHADER ? @"vsh" : @"fsh"];
    NSError *error;
    
    NSString *shaderCode = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        NSLog(@"Unable to load shader: %@", error);
        exit(1);
    }
    
    return [self compileShaderCode:shaderCode type:type];
}

// 获取渲染缓存宽度
+ (GLint)drawableWidth {
    GLint backingWidth;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    
    return backingWidth;
}

// 获取渲染缓存高度
+ (GLint)drawableHeight {
    GLint backingHeight;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    return backingHeight;
}

+ (GLuint)programWithShader:(NSString *)shaderName
{
    GLuint vertexShader = [self compileShaderWithName:shaderName type:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShaderWithName:shaderName type:GL_FRAGMENT_SHADER];
    
    GLuint program = glCreateProgram();
    
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    
    glLinkProgram(program);
    
    GLint linkResult;
    glGetProgramiv(program, GL_LINK_STATUS, &linkResult);
    
    if (linkResult == GL_FALSE) {
        GLchar msg[256];
        glGetProgramInfoLog(program, sizeof(msg), 0, &msg[0]);
        NSString *errorMsg = [NSString stringWithUTF8String:msg];
        NSLog(@"Link failed: %@", errorMsg);
        exit(1);
    }
    return program;
}

+ (GLuint)programWithVertexShaderCode:(NSString *)vertexCode fragmentShaderCode:(NSString *)fragmentCode
{
    return [self programWithVertexShaderCode:vertexCode fragmentShaderCode:fragmentCode beforeLinking:nil];
}

+ (GLuint)programWithVertexShaderCode:(NSString *)vertexCode fragmentShaderCode:(NSString *)fragmentCode beforeLinking:(void(^)(GLuint program))beforeLinkCallback
{
    GLuint vertexShader = [self compileShaderCode:vertexCode type:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShaderCode:fragmentCode type:GL_FRAGMENT_SHADER];
    
    GLuint program = glCreateProgram();
    
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    
    if (beforeLinkCallback) {
        beforeLinkCallback(program);
    }
    
    glLinkProgram(program);
    
    GLint linkResult;
    glGetProgramiv(program, GL_LINK_STATUS, &linkResult);
    
    if (linkResult == GL_FALSE) {
        GLchar msg[256];
        glGetProgramInfoLog(program, sizeof(msg), 0, &msg[0]);
        NSString *errorMsg = [NSString stringWithUTF8String:msg];
        NSLog(@"Link failed: %@", errorMsg);
        exit(1);
    }
    return program;
}

+ (GLuint)compileShaderCode:(NSString *)shaderCode type:(GLenum)type
{
    GLuint shader = glCreateShader(type);
    
    const char *shaderSource = [shaderCode UTF8String];
    int sourceLength = (int)[shaderCode length];
    glShaderSource(shader, 1, &shaderSource, &sourceLength);
    
    glCompileShader(shader);
    
    GLint compileResult;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileResult);
    
    if (compileResult == GL_FALSE) {
        GLchar msg[256];
        glGetShaderInfoLog(shader, sizeof(msg), 0, &msg[0]);
        NSString *errorMsg = [NSString stringWithUTF8String:msg];
        NSLog(@"Compile failed: %@", errorMsg);
        exit(1);
    }
    
    return shader;
}

@end
