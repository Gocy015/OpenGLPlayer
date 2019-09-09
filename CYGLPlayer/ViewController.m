//
//  ViewController.m
//  CYGLPlayer
//
//  Created by Gocy on 2019/9/2.
//  Copyright © 2019 Gocy. All rights reserved.
//

#import "ViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "CYGLPlayer.h"

@interface ViewController ()<UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) CYGLPlayer *player;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
}
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear: animated];
    NSURL *videoURL = [NSBundle.mainBundle URLForResource:@"u5408u6210_1_background" withExtension:@"mp4"];
    [self playWithURL:videoURL];
}

- (IBAction)selectVideo:(id)sender {
    UIImagePickerController *vc = [UIImagePickerController new];
    vc.delegate = self;
    vc.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    vc.mediaTypes = @[(NSString *)kUTTypeMovie];
    
    [self presentViewController:vc animated:YES completion:nil];
}


#pragma mark - Image Picker
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info
{
    [picker.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    
    NSURL *url = [info objectForKey:UIImagePickerControllerMediaURL];
    NSLog(@"MediaURL: %@", url);
    
    [self playWithURL:url];
}

- (void)playWithURL:(NSURL *)url
{
    if (self.player) {
        return;
    }
    self.player = [[CYGLPlayer alloc] initWithVideoURL:url];
    self.player.frame = self.view.bounds;
    self.player.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.player];
    [self.player play];
}

@end
