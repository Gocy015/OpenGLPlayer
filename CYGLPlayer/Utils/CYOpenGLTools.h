//
//  CYOpenGLTools.h
//  BeginOpenGLES
//
//  Created by Gocy on 2019/8/17.
//  Copyright © 2019 Gocy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/ES2/gl.h>

NS_ASSUME_NONNULL_BEGIN

@interface CYOpenGLTools : NSObject

+ (void)bindRenderLayer:(CALayer <EAGLDrawable> *)layer toContext:(EAGLContext *)context;

+ (void)bindRenderLayer:(CALayer <EAGLDrawable> *)layer toContext:(EAGLContext *)context withRenderBuffer:(GLuint *)renderBuffer frameBuffer:(GLuint *)frameBuffer;

+ (GLuint)textureFromImage:(UIImage *)image;

+ (GLuint)compileShaderWithName:(NSString *)name type:(GLenum)type;

+ (GLuint)programWithShader:(NSString *)shaderName;

+ (GLuint)programWithVertexShaderCode:(NSString *)vertexShader fragmentShaderCode:(NSString *)fragmentShader;

+ (GLuint)programWithVertexShaderCode:(NSString *)vertexCode fragmentShaderCode:(NSString *)fragmentCode beforeLinking:(void(^)(GLuint program))beforeLinkCallback;

+ (void)ensureContext:(EAGLContext *)context;

@end

NS_ASSUME_NONNULL_END
