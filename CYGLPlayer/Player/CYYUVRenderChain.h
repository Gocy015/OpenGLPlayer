//
//  CYYUVRenderChain.h
//  CYGLPlayer
//
//  Created by Gocy on 2019/9/3.
//  Copyright © 2019 Gocy. All rights reserved.
//


#import <UIKit/UIKit.h>
#import "CYFrameBuffer.h"
#import <AVFoundation/AVFoundation.h>

@class CYYUVRenderChainItem;
@interface CYYUVRenderChainItem: NSObject

@property (nonatomic, strong) CYFrameBuffer *frameBuffer;
@property (nonatomic, assign) CVPixelBufferRef pixelBuffer;

- (void)renderAfterPreviousItem:(CYYUVRenderChainItem *)item inContext:(EAGLContext *)context;

@end

@protocol CYYUVRenderOutput<NSObject>

- (void)cyyuv_frameBufferOutput:(CYFrameBuffer *)framebuffer;

@end


#if defined __cplusplus
extern "C" {
#endif
    
    void dispatch_sync_task(dispatch_block_t blk);
    void dispatch_async_task(dispatch_block_t blk);
    
#if defined __cplusplus
};
#endif

@interface CYYUVRenderChain : NSObject

- (EAGLContext *)context;

- (void)addChainItem:(CYYUVRenderChainItem *)item;

- (void)addOutput:(id <CYYUVRenderOutput>)output;

- (void)render:(CVPixelBufferRef)pixelBuffer;

@end
