//
//  CYFrameBuffer.h
//  CYGLPlayer
//
//  Created by Gocy on 2019/9/3.
//  Copyright © 2019 Gocy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <OpenGLES/ES2/gl.h>

@interface CYFrameBuffer : NSObject

- (instancetype)initWithSize:(CGSize)size;

@property (nonatomic, assign) GLuint frameBufferID;
@property (nonatomic, assign) GLuint textureID;
@property (nonatomic, assign, readonly) CGSize size;


@end
