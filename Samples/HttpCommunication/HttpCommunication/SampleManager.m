//
//  SampleManager.m
//  HttpCommunication
//
//  Created by Tae Hyun Na on 2015. 12. 23.
//  Copyright (c) 2014, P9 SOFT, Inc. All rights reserved.
//
//  Licensed under the MIT license.

#import "SampleManager.h"
#import "SampleExecutor.h"

@interface SampleManager (SampleManagerPrivate)

- (NSMutableDictionary *)sampleExecutorHandlerWithResult:(HYResult *)result;

@end

@implementation SampleManager

@synthesize standby = _standby;

- (NSString *) name
{
	return SampleManagerNotification;
}

- (NSString *) brief
{
	return @"Sample manager";
}

+ (SampleManager *)defaultManager
{
	static dispatch_once_t	once;
	static SampleManager	*sharedInstance;
	
	dispatch_once(&once, ^{ sharedInstance = [[self alloc] init];});
	
	return sharedInstance;
}

- (BOOL)standbyWithWorkerName:(NSString *)workerName
{
	if( (self.standby == YES) || (workerName.length <= 0) ) {
		return NO;
	}
	
	// regist executor with handling method
	[self registExecuter: [[SampleExecutor alloc] init] withWorkerName:workerName action:@selector(sampleExecutorHandlerWithResult:)];
	
	_standby = YES;
	
	return YES;
}

- (void)requestServerApi:(NSString *)serverApiUrlString httpMethod:(NSString *)httpMethod parameterDict:(NSDictionary *)parameterDict completion:(void (^)(NSMutableDictionary *))completion
{
    // check parameter
    if( (serverApiUrlString.length == 0) || (([httpMethod isEqualToString:@"GET"] == NO) && ([httpMethod isEqualToString:@"POST"] == NO)) ) {
        if( completion != nil ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
        }
    }
    
    // make query
    HYQuery *query;
    if( (query = [self queryForExecutorName:SampleExecutorName]) == nil ) {
        if( completion != nil ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
        }
    }
    
    // set url string of server api with its key.
    [query setParameter:serverApiUrlString forKey:SampleExecutorParameterKeyUrlString];
    
    // set operation of executor by checking http method parameter.
    // parameter value "GET" to 'SampleExecutorOperationGet'.
    if( [httpMethod isEqualToString:@"GET"] == YES ) {
        
        [query setParameter:@(SampleExecutorOperationGet) forKey:SampleExecutorParameterKeyOperation];
        
    // we checked parameter 'httpMethod' above and in this case, 'httpMethod' have value @"POST"
    // so, set to 'SampleExecutorOperationPost'.
    } else {
        
        [query setParameter:@(SampleExecutorOperationPost) forKey:SampleExecutorParameterKeyOperation];
        
    }
    
    // set parameter dictionary with its key, and it'll used query string of http GET method or post parameter of http POST method.
    [query setParameter:parameterDict forKey:SampleExecutorParameterKeyRequestDict];
    
    // set completion handler for task after http communiation.
    [query setParameter:completion forKey:SampleManagerNotifyParameterKeyCompletionBlock];
    
    // now, query object prepared, push it to hydra.
    [[Hydra defaultHydra] pushQuery:query];
}

- (void)requestServerApi:(NSString *)serverApiUrlString parameterDict:(NSDictionary *)parameterDict downloadFileTo:(NSString *)filePath completion:(void (^)(NSMutableDictionary *))completion
{
    // check parameter
    if( (serverApiUrlString.length == 0) || (filePath.length == 0) ) {
        if( completion != nil ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
        }
    }
    
    // make query
    HYQuery *query;
    if( (query = [self queryForExecutorName:SampleExecutorName]) == nil ) {
        if( completion != nil ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
        }
    }
    
    // set url string of server api with its key.
    [query setParameter:serverApiUrlString forKey:SampleExecutorParameterKeyUrlString];
    
    // set operation of executor. in this case, set 'SampleExecutorOperationDownloadFile' for download file.
    [query setParameter:@(SampleExecutorOperationDownloadFile) forKey:SampleExecutorParameterKeyOperation];
    
    // set parameter dictinary with its key, and it'll used query string of http GET method.
    [query setParameter:parameterDict forKey:SampleExecutorParameterKeyRequestDict];
    
    // set file path string with its key. it'll be file path of downloaded file.
    [query setParameter:filePath forKey:SampleExecutorParameterKeyFilePath];
    
    // set completion handler for task after http communiation.
    [query setParameter:completion forKey:SampleManagerNotifyParameterKeyCompletionBlock];
    
    // now, query object prepared, push it to hydra.
    [[Hydra defaultHydra] pushQuery:query];
}

- (void)requestServerApi:(NSString *)serverApiUrlString parameterDict:(NSDictionary *)parameterDict formDataFieldName:(NSString *)formDataFieldName fileName:(NSString *)fileName contentType:(NSString *)contentType uploadFileFrom:(NSString *)filePath completion:(void (^)(NSMutableDictionary *))completion
{
    // check parameter
    if( (serverApiUrlString.length == 0) || (formDataFieldName.length == 0) || (fileName.length == 0) || (contentType.length == 0) || (filePath.length == 0) ) {
        if( completion != nil ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
        }
    }
    
    // make query and push to hydra
    HYQuery *query;
    if( (query = [self queryForExecutorName:SampleExecutorName]) == nil ) {
        if( completion != nil ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
        }
    }
    
    // set url string of server api with its key.
    [query setParameter:serverApiUrlString forKey:SampleExecutorParameterKeyUrlString];
    
    // set operation of executor. in this case, set 'SampleExecutorOperationUploadFile' for upload file.
    [query setParameter:@(SampleExecutorOperationUploadFile) forKey:SampleExecutorParameterKeyOperation];
    
    // set parameter dictinary with its key, and it'll used post parameter of http POST method.
    [query setParameter:parameterDict forKey:SampleExecutorParameterKeyRequestDict];
    
    [query setParameter:formDataFieldName forKey:SampleExecutorParameterKeyFormDataFieldName];
    
    [query setParameter:fileName forKey:SampleExecutorParameterKeyFileName];
    
    [query setParameter:contentType forKey:SampleExecutorParameterKeyContentType];
    
    // set file path string with its key. path of file content data will be upload.
    [query setParameter:filePath forKey:SampleExecutorParameterKeyFilePath];
    
    // set completion handler for task after http communiation.
    [query setParameter:completion forKey:SampleManagerNotifyParameterKeyCompletionBlock];
    
    // now, query object prepared, push it to hydra.
    [[Hydra defaultHydra] pushQuery:query];
}

- (NSMutableDictionary *)sampleExecutorHandlerWithResult:(HYResult *)result
{
    // get complete handler.
    void (^completionBlock)(NSMutableDictionary *) = [result parameterForKey:SampleManagerNotifyParameterKeyCompletionBlock];
    
    // prepare dictionary object, and it'll have values for notification feedback.
    NSMutableDictionary *paramDict = [NSMutableDictionary new];
    if( paramDict == nil ) {
        if( completionBlock != nil ) {
            completionBlock(nil);
        }
        return nil;
    }
    
    // check parameters and set to dicationary object for feedback if need.
    // here check server api string,
    NSString *serverApiString = [result parameterForKey:SampleExecutorParameterKeyUrlString];
    if( serverApiString == nil ) {
        if( completionBlock != nil ) {
            completionBlock(nil);
        }
        return nil;
    }
    paramDict[SampleManagerNotifyParameterKeyServerApiUrlString] = serverApiString;
    
    // and request parameters,
    NSMutableDictionary *requestDict = [result parameterForKey:SampleExecutorParameterKeyRequestDict];
    if( requestDict != nil ) {
        paramDict[SampleManagerNotifyParameterKeyRequestDict] = requestDict;
    }
    
    // and received result parameters,
    NSMutableDictionary * resultDict = [result parameterForKey:SampleExecutorParameterKeyResultDict];
    if( resultDict != nil ) {
        paramDict[SampleManagerNotifyParameterKeyResultDict] = resultDict;
    }
    
    // and failed flag.
    if( [[result parameterForKey:SampleExecutorParameterKeyFailedFlag] boolValue] == YES ) {
        paramDict[SampleManagerNotifyParameterKeyFailedFlag] = @"Y";
    }
    
    // if completion block specified, then call it.
    if( completionBlock != nil ) {
        completionBlock(paramDict);
    }
    
    // if 'paramDict' is empty, then we don't have to notification, so return 'nil'.
    if( paramDict.count == 0 ) {
        return nil;
    }
	
	// 'paramDict' will be 'userInfo' of notification, 'SampleManagerNotification'.
	return paramDict;
}

@end
