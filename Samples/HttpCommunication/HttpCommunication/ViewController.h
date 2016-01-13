//
//  ViewController.h
//  HttpCommunication
//
//  Created by Tae Hyun, Na on 2015. 12. 23..
//  Copyright (c) 2015년 TeamP9. All rights reserved.
//
//  Licensed under the MIT license.

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UITextView *consoleTextView;
@property (weak, nonatomic) IBOutlet UITextField *serverApiUrlTextField;
@property (weak, nonatomic) IBOutlet UITextField *parameterTextField;
@property (weak, nonatomic) IBOutlet UIButton *getButton;
@property (weak, nonatomic) IBOutlet UIButton *postButton;
@property (weak, nonatomic) IBOutlet UIButton *downloadFileButton;
@property (weak, nonatomic) IBOutlet UIButton *uploadFileButton;
@property (weak, nonatomic) IBOutlet UIButton *transferButton;

@end

