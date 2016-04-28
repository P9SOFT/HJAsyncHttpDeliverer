//
//  ViewController.m
//  HttpCommunication
//
//  Created by Tae Hyun Na on 2015. 12. 23.
//  Copyright (c) 2014, P9 SOFT, Inc. All rights reserved.
//
//  Licensed under the MIT license.

#import "ViewController.h"
#import "SampleManager.h"

@interface ViewController ()

@property (weak, nonatomic) UIButton *selectedButton;

- (void)resignFirstResponderAll;
- (NSDictionary *)dictionaryFromParameterTextField;
- (void)appendTextToConsole:(NSString *)text;
- (void)sampleManagerNotificationHandler:(NSNotification *)notificaion;
- (IBAction)operationSelectButtonsTouchUpInside:(id)sender;
- (IBAction)transferButtonTouchUpInside:(id)sender;

@end

@implementation ViewController

- (id)init
{
    if( (self = [super init]) != nil ) {
        // observe SampleManager's notificaion.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sampleManagerNotificationHandler:) name:SampleManagerNotification object:nil];
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // set getButton's status to selected.
    [self operationSelectButtonsTouchUpInside:_getButton];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)resignFirstResponderAll
{
    if( [self.serverApiUrlTextField isFirstResponder] == YES ) {
        [self.serverApiUrlTextField resignFirstResponder];
    }
    if( [self.parameterTextField isFirstResponder] == YES ) {
        [self.parameterTextField resignFirstResponder];
    }
}

- (NSDictionary *)dictionaryFromParameterTextField
{
    if( self.parameterTextField.text.length == 0 ) {
        return nil;
    }
    
    NSMutableDictionary *paramDict = [NSMutableDictionary new];
    if( paramDict == nil ) {
        return nil;
    }
    
    // string "a=1&b=2" to dictionary {"a":"1","b":"2"}
    NSArray *parameters = [self.parameterTextField.text componentsSeparatedByString:@"&"];
    for( NSString *parameter in parameters ) {
        NSArray *pair = [parameter componentsSeparatedByString:@"="];
        if( [pair count] != 2 ) {
            return nil;
        }
        paramDict[pair[0]] = pair[1];
    }
    
    return [NSDictionary dictionaryWithDictionary:paramDict];
}

- (void)appendTextToConsole:(NSString *)text
{
    if( [text length] == 0 ) {
        return;
    }
    
    // append text and scroll to last.
    self.consoleTextView.text = [self.consoleTextView.text stringByAppendingString:text];
    if( self.consoleTextView.text.length > 0 ) {
        [self.consoleTextView scrollRangeToVisible:NSMakeRange(self.consoleTextView.text.length-1, 1)];
        self.consoleTextView.scrollEnabled = NO;
        self.consoleTextView.scrollEnabled = YES;
    }
}

- (void)sampleManagerNotificationHandler:(NSNotification *)notificaion
{
    NSDictionary *userInfo = notificaion.userInfo;
    
    [self appendTextToConsole:[NSString stringWithFormat:@"<< RESULT\n%@\n%@\n", userInfo[SampleManagerNotifyParameterKeyServerApiUrlString], userInfo[SampleManagerNotifyParameterKeyResultDict]]];
}

- (IBAction)operationSelectButtonsTouchUpInside:(id)sender
{
    [self resignFirstResponderAll];
    _selectedButton.selected = NO;
    _selectedButton = (UIButton *)sender;
    _selectedButton.selected = YES;
}

- (IBAction)transferButtonTouchUpInside:(id)sender
{
    [self resignFirstResponderAll];
    NSString *serverApiUrl = self.serverApiUrlTextField.text;
    if( serverApiUrl.length == 0 ) {
        return;
    }
    if( ([serverApiUrl rangeOfString:@"http://"].location != 0) && ([serverApiUrl rangeOfString:@"https://"].location != 0) ) {
        serverApiUrl = [NSString stringWithFormat:@"http://%@", serverApiUrl];
    }
    NSDictionary *paramDict = [self dictionaryFromParameterTextField];

    // request HTTP GET method to SampleManager.
    if( self.getButton.selected == YES ) {
        self.transferButton.enabled = NO;
        if( [paramDict count] > 0 ) {
            [self appendTextToConsole:[NSString stringWithFormat:@">> REQUEST\n%@\n%@\n", serverApiUrl, paramDict]];
        } else {
            [self appendTextToConsole:[NSString stringWithFormat:@">> REQUEST\n%@\n", serverApiUrl]];
        }
        [[SampleManager defaultManager] requestServerApi:serverApiUrl httpMethod:@"GET" parameterDict:nil completion:^(NSMutableDictionary *resultDict) {
            // you can handle result data with completion block code, here or can handle with notification handler, above.
            // it's up to you.
            self.transferButton.enabled = YES;
        }];
    // request HTTP POST method to SampleManager.
    } else if( self.postButton.selected == YES ) {
        self.transferButton.enabled = NO;
        if( [paramDict count] > 0 ) {
            [self appendTextToConsole:[NSString stringWithFormat:@">> REQUEST\n%@\n%@\n", serverApiUrl, paramDict]];
        } else {
            [self appendTextToConsole:[NSString stringWithFormat:@">> REQUEST\n%@\n", serverApiUrl]];
        }
        [[SampleManager defaultManager] requestServerApi:serverApiUrl httpMethod:@"POST" parameterDict:paramDict completion:^(NSMutableDictionary *resultDict) {
            self.transferButton.enabled = YES;
        }];
    // request download file to SampleManager.
    } else if( self.downloadFileButton.selected == YES ) {
        self.transferButton.enabled = NO;
        NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentPath = [searchPaths objectAtIndex:0];
        NSString *filePath = [NSString stringWithFormat:@"%@/sample.png", documentPath];
        [[SampleManager defaultManager] requestServerApi:serverApiUrl parameterDict:paramDict downloadFileTo:filePath completion:^(NSMutableDictionary *resultDict) {
            self.transferButton.enabled = YES;
        }];
    // request upload file to SampleManager.
    } else if( self.uploadFileButton.selected == YES ) {
        self.transferButton.enabled = NO;
        NSString *filePath = [NSString stringWithFormat:@"%@/sample.png", [[NSBundle mainBundle] resourcePath]];
        [[SampleManager defaultManager] requestServerApi:serverApiUrl parameterDict:paramDict formDataFieldName:@"uploadfile" fileName:@"sample.png" contentType:@"image/png" uploadFileFrom:filePath completion:^(NSMutableDictionary *resultDict) {
            self.transferButton.enabled = YES;
        }];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self resignFirstResponderAll];
}

@end
