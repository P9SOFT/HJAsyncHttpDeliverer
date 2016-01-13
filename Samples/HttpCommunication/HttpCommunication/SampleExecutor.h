//
//  SampleExecutor.h
//  HttpCommunication
//
//  Created by Tae Hyun, Na on 2015. 2. 20..
//  Copyright (c) 2015년 TeamP9. All rights reserved.
//
//  Licensed under the MIT license.

#import <UIKit/UIKit.h>
#import <Hydra/Hydra.h>

#define     SampleExecutorName      @"sampleExecutorName"

#define     SampleExecutorParameterKeyCloseQueryCall        @"sampleExecutorParameterKeyCloseQueryCall"
#define     SampleExecutorParameterKeyOperation             @"sampleExecutorParameterKeyOperation"
#define     SampleExecutorParameterKeyFailedFlag            @"sampleExecutorParameterKeyFailedFlag"
#define     SampleExecutorParameterKeyUrlString             @"sampleExecutorParameterKeyUrlString"
#define     SampleExecutorParameterKeyRequestDict           @"sampleExecutorParameterKeyRequestDict"
#define     SampleExecutorParameterKeyResultDict            @"sampleExecutorParameterKeyResultDict"
#define     SampleExecutorParameterKeyFilePath              @"sampleExecutorParameterKeyFilePath"
#define     SampleExecutorParameterKeyFormDataFieldName     @"sampleExecutorParameterKeyFormDataFieldName"
#define     SampleExecutorParameterKeyFileName              @"sampleExecutorParameterKeyFileName"
#define     SampleExecutorParameterKeyContentType           @"sampleExecutorParameterKeyContentType"

typedef enum _SampleExecutorOperation_
{
    SampleExecutorOperationDummy,
    SampleExecutorOperationGet,
    SampleExecutorOperationPost,
    SampleExecutorOperationDownloadFile,
    SampleExecutorOperationUploadFile
    
} SampleExecutorOperation;

@interface SampleExecutor : HYExecuter

@end
