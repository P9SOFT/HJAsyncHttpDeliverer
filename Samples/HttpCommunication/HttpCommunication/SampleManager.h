//
//  SampleManager.h
//  HttpCommunication
//
//  Created by Tae Hyun Na on 2015. 12. 23.
//  Copyright (c) 2014, P9 SOFT, Inc. All rights reserved.
//
//  Licensed under the MIT license.

#import <UIKit/UIKit.h>
#import <Hydra/Hydra.h>

#define		SampleManagerNotification                           @"sampleManagerNotification"

#define		SampleManagerNotifyParameterKeyServerApiUrlString   @"sampleManagerNotifyParameterKeyServerApiUrlString"
#define     SampleManagerNotifyParameterKeyFailedFlag           @"sampleManagerNotifyParameterKeyFailedFlag"
#define     SampleManagerNotifyParameterKeyCompletionBlock      @"sampleManagerNotifyParameterKeyCompletionBlock"
#define     SampleManagerNotifyParameterKeyRequestDict          @"sampleManagerNotifyParameterKeyRequestDict"
#define		SampleManagerNotifyParameterKeyResultDict           @"sampleManagerNotifyParameterKeyResultDict"

@interface SampleManager : HYManager

+ (SampleManager *)defaultManager;
- (BOOL)standbyWithWorkerName:(NSString *)workerName;

- (void)requestServerApi:(NSString *)serverApiUrlString httpMethod:(NSString *)httpMethod parameterDict:(NSDictionary *)parameterDict completion:(void (^)(NSMutableDictionary *))completion;
- (void)requestServerApi:(NSString *)serverApiUrlString parameterDict:(NSDictionary *)parameterDict downloadFileTo:(NSString *)filePath completion:(void (^)(NSMutableDictionary *))completion;
- (void)requestServerApi:(NSString *)serverApiUrlString parameterDict:(NSDictionary *)parameterDict formDataFieldName:(NSString *)formDataFieldName fileName:(NSString *)fileName contentType:(NSString *)contentType uploadFileFrom:(NSString *)filePath completion:(void (^)(NSMutableDictionary *))completion;

@property (nonatomic, readonly) BOOL standby;

@end
