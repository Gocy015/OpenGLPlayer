//
//  CYFrameBuffer.m
//  CYGLPlayer
//
//  Created by Gocy on 2019/9/3.
//  Copyright © 2019 Gocy. All rights reserved.
//

#import "CYFrameBuffer.h"

@interface CYFrameBuffer ()

@end

@implementation CYFrameBuffer

- (instancetype)initWithSize:(CGSize)size
{
    if (self = [super init]) {
        [self doInitWithSize:size];
    }
    return self;
}

- (void)doInitWithSize:(CGSize)size
{
    _size = size;
    glGenFramebuffers(1, &_frameBufferID);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferID);
    
    glGenTextures(1, &_textureID);
    glBindTexture(GL_TEXTURE_2D, _textureID);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, size.width, size.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _textureID, 0);
    
    glBindTexture(GL_TEXTURE_2D, 0);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    
    NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete frameBuffer: %d.", status);
    
}

@end
