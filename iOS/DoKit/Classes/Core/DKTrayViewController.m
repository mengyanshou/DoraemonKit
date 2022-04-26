/**
 * Copyright 2017 Beijing DiDi Infinity Technology and Development Co., Ltd.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "DKTrayViewController.h"
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

static void requestVideoGrant(void (^completionBlock)(BOOL isGranted));

static inline void safeMainThread(dispatch_block_t block);

@interface DKTrayViewController () <AVCaptureMetadataOutputObjectsDelegate>

@property (nonatomic, nullable, strong) AVCaptureSession *captureSession;

- (IBAction)buttonHandler;

@end

NS_ASSUME_NONNULL_END

void safeMainThread(dispatch_block_t block) {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), block);
    } else {
        block();
    }
}

void requestVideoGrant(void (^completionBlock)(BOOL isGranted)) {
    AVAuthorizationStatus authorizationStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authorizationStatus == AVAuthorizationStatusNotDetermined) {
        // Request system authority.
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            safeMainThread(^{
                completionBlock(granted);
            });
        }];
    } else if (authorizationStatus != AVAuthorizationStatusAuthorized) {
        completionBlock(NO);
    }
}

@implementation DKTrayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)buttonHandler {
    __weak typeof(self) weakSelf = self;
    requestVideoGrant(^(BOOL isGranted) {
        typeof(weakSelf) self = weakSelf;
        if (!isGranted) {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"相机权限未开启，请到「设置-隐私-相机」中允许访问您的相机" message:nil preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *openAlertAction = [UIAlertAction actionWithTitle:@"去开启" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull __attribute__((unused)) action) {
                NSURL *settingUrl = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                if (@available(iOS 13.0, *)) {
                    [self.view.window.windowScene openURL:settingUrl options:nil completionHandler:nil];
                } else if (@available(iOS 10.0, *)) {
                    [UIApplication.sharedApplication openURL:settingUrl options:@{} completionHandler:nil];
                } else {
                    if ([UIApplication.sharedApplication canOpenURL:settingUrl]) {
                        [UIApplication.sharedApplication openURL:settingUrl];
                    }
                }
            }];
            UIAlertAction *cancelAlertAction = [UIAlertAction actionWithTitle:@"暂不开启" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull __attribute__((unused)) action) {
            }];
            [alertController addAction:openAlertAction];
            [alertController addAction:cancelAlertAction];
            [self showViewController:alertController sender:nil];
        } else {
            AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
            NSCAssert(captureDevice, @"+[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] return nil.");
            
            NSError *error = nil;
            AVCaptureDeviceInput *captureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
            NSCAssert(!error && captureDeviceInput, @"AVCaptureDeviceInput creation is failed.");
            
            AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
            [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
            
            self.captureSession = [[AVCaptureSession alloc] init];
            [self.captureSession beginConfiguration];
            NSCAssert([self.captureSession canAddInput:captureDeviceInput], @"-[captureSession canAddInput:captureDeviceInput] is failed.");
            [self.captureSession addInput:captureDeviceInput];
            NSCAssert([self.captureSession canAddOutput:captureMetadataOutput], @"-[AVCaptureSession canAddOutput:captureMetadataOutput] return NO.");
            [self.captureSession addOutput:captureMetadataOutput];
            if ([captureMetadataOutput.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeQRCode]) {
                captureMetadataOutput.metadataObjectTypes = @[AVMetadataObjectTypeQRCode];
            }
            [self.captureSession commitConfiguration];
            
            AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
            captureVideoPreviewLayer.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
            [self.view.layer addSublayer:captureVideoPreviewLayer];
            
            [self.captureSession startRunning];
        }
    });
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    if (metadataObjects.count > 0) {
        AVMetadataObject *metadataObject = metadataObjects.firstObject;
        if ([metadataObject.type isEqualToString:AVMetadataObjectTypeQRCode] && [metadataObject isKindOfClass:AVMetadataMachineReadableCodeObject.class]) {
            [self.captureSession stopRunning];
            AVMetadataMachineReadableCodeObject *metadataMachineReadableCodeObject = (AVMetadataMachineReadableCodeObject *) metadataObject;
            NSLog(@"%@", metadataMachineReadableCodeObject.stringValue);
        }
    }
}

@end
