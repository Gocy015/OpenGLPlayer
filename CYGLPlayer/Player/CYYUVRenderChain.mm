//
//  CYYUVRenderChain.m
//  CYGLPlayer
//
//  Created by Gocy on 2019/9/3.
//  Copyright © 2019 Gocy. All rights reserved.
//

#import "CYYUVRenderChain.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/EAGL.h>
#import "CYYUVRenderer.h"
#import "CYGLDefines.h"
#import "CYOpenGLTools.h"

@interface CYYUVRenderChainItem()

- (instancetype)initEmpty;

@end


@interface CYYUVRenderChain (){}

@property (nonatomic, strong) EAGLContext *context;
@property (nonatomic, strong) dispatch_queue_t processQueue;
@property (nonatomic, strong) NSMutableArray <CYYUVRenderChainItem *> *chainItems;
@property (nonatomic, strong) CYYUVRenderChainItem *yuvEntry;
@property (nonatomic, strong) NSPointerArray *outputs;

@end

static NSString * const _GLQueueIdentifier = @"com.gocy.glqueue";
static void *_GLQueueKey;

@implementation CYYUVRenderChain

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self doInit];
    }
    return self;
}

+ (dispatch_queue_t)glQueue
{
    static dispatch_once_t onceToken;
    static dispatch_queue_t _q = nil;
    dispatch_once(&onceToken, ^{
        _q = dispatch_queue_create("com.gocy.yuvchainqueue", NULL);
        dispatch_queue_set_specific(_q, _GLQueueKey, (__bridge void *)_GLQueueIdentifier, NULL);
    });
    
    return _q;
}

- (void)doInit
{
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    _processQueue = [self.class glQueue];
    _chainItems = [NSMutableArray new];
}

- (EAGLContext *)context
{
    return _context;
}

- (void)dealloc
{
    
}

- (void)addChainItem:(CYYUVRenderChainItem *)item
{
    if (item == nil) {
        return ;
    }
    
    dispatch_sync_task(^{
        if (self.chainItems.count == 0) {
            [self _initYUVRenderer];
        }
        [self.chainItems addObject:item];
    });
}

- (void)addOutput:(id<CYYUVRenderOutput>)output
{
    dispatch_sync_task(^{
        if (!self.outputs) {
            self.outputs = [NSPointerArray weakObjectsPointerArray];
        }
        [self.outputs addPointer:(__bridge void *)(output)];

    });}

- (void)render:(CVPixelBufferRef)pixelBuffer
{
//    GLenum err = glGetError();
    

    dispatch_sync_task(^{
        CYYUVRenderChainItem *prevItem = nil;
        
        [CYOpenGLTools ensureContext:self.context];
        
        if (self.chainItems.count == 0) {
            [self _initYUVRenderer];
        }
        
        self.yuvEntry.pixelBuffer = pixelBuffer;
        for (CYYUVRenderChainItem *item in self.chainItems) {
            if (prevItem) {
                [item renderAfterPreviousItem:prevItem inContext:self.context];
                CY_GET_GLERROR()
            }
            prevItem = item;
        }
        for (id <CYYUVRenderOutput> output in self.outputs.allObjects) {
            if (output) {
                [output cyyuv_frameBufferOutput:prevItem.frameBuffer];
                CY_GET_GLERROR()
            }
        }
    });
}

- (void)_initYUVRenderer
{
    if (self.yuvEntry) {
        return ;
    }
    
    self.yuvEntry = [[CYYUVRenderChainItem alloc] initEmpty];
    [self.chainItems addObject:self.yuvEntry];
    
    CYYUVRenderer *yuvRenderer = [CYYUVRenderer new];
    [self.chainItems addObject:yuvRenderer];
}

@end


@implementation CYYUVRenderChainItem

- (instancetype)initEmpty
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _frameBuffer = [[CYFrameBuffer alloc] initWithSize:UIScreen.mainScreen.bounds.size];
    }
    return self;
}

- (void)renderAfterPreviousItem:(CYYUVRenderChainItem *)item inContext:(EAGLContext *)context
{
    return;
}

@end

bool AlreadyInTargetQueue()
{
    if (dispatch_get_specific(_GLQueueKey) != NULL) {
        return true;
    }
    return false;
}

void dispatch_sync_task(dispatch_block_t blk)
{
    if (blk == nil) {
        return ;
    }
    if (AlreadyInTargetQueue()) {
        blk();
    } else {
        dispatch_sync([CYYUVRenderChain glQueue], blk);
    }
}
void dispatch_async_task(dispatch_block_t blk)
{
    if (blk == nil) {
        return ;
    }
    
    if (AlreadyInTargetQueue()) {
        blk();
    } else {
        dispatch_async([CYYUVRenderChain glQueue], blk);
    }
}
