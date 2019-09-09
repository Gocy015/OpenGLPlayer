//
//  CYGLPlayer.h
//  CYGLPlayer
//
//  Created by Gocy on 2019/9/3.
//  Copyright © 2019 Gocy. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface CYGLPlayer : UIView

- (instancetype)initWithVideoURL:(NSURL *)url;

- (void)play;

@end

