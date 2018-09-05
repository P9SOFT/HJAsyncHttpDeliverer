//
//  SampleExecutor.m
//  HttpCommunication
//
//  Created by Tae Hyun Na on 2015. 12. 23.
//  Copyright (c) 2014, P9 SOFT, Inc. All rights reserved.
//
//  Licensed under the MIT license.

#import "SampleExecutor.h"
#import "HJAsyncHttpDeliverer.h"

@interface SampleExecutor () <NSURLSessionDataDelegate, NSURLSessionTaskDelegate>
{
    NSURLSession        *_session;
    NSMutableDictionary *_taskDict;
}

- (void)setTask:(HJAsyncHttpDeliverer *)deliverer forKey:(NSString *)key;
- (HJAsyncHttpDeliverer *)taskForKey:(NSString *)key;
- (void)removeTaskForKey:(NSString *)key;
- (HYResult *)resultForQuery:(id)anQuery;
- (BOOL)storeFailedResultWithQuery:(id)anQuery;

@end

@implementation SampleExecutor

- (instancetype)init
{
    if( (self = [super init]) != nil ) {
        if( (_session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil]) == nil ) {
            return nil;
        }
        if( (_taskDict = [NSMutableDictionary new]) == nil ) {
            return nil;
        }
    }
    
    return self;
}

- (void)dealloc
{
    [_session invalidateAndCancel];
    _session = nil;
}

- (NSString *)name
{
	return SampleExecutorName;
}

- (BOOL)calledExecutingWithQuery:(id)anQuery
{
	if( [[anQuery parameterForKey:SampleExecutorParameterKeyCloseQueryCall] boolValue] == YES ) {
		
        // prepare result
        HYResult *result = [self resultForQuery:anQuery];
        
        // check the result status of HJAsyncHttpDeliverer, and if not succeed, then store failed result.
        if( [[anQuery parameterForKey:HJAsyncHttpDelivererParameterKeyFailed] boolValue] == YES ) {
            return [self storeFailedResultWithQuery:anQuery];
        }
        
        // check received data from the result and preprocess it.
        // in this case, get NSMutableDictionary object by parsing JSON format.
        NSData *receivedData = [result parameterForKey:HJAsyncHttpDelivererParameterKeyBody];
        if( receivedData.length > 0 ) {
            NSMutableDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:receivedData options:NSJSONReadingMutableContainers error:nil];
            if( resultDict == nil ) {
                resultDict = [[NSMutableDictionary alloc] init];
                resultDict[@"rawData"] = [[NSString alloc] initWithData: receivedData encoding: NSUTF8StringEncoding];
            }
            // set wanted data to result for its key.
            [result setParameter:resultDict forKey:SampleExecutorParameterKeyResultDict];
        }
		
		// stored result will notify by name 'SampleExecutorName'
		[self storeResult:result];
        
        [self removeTaskForKey:[[anQuery parameterForKey:HJAsyncHttpDelivererParameterKeyIssuedId] stringValue]];
		
	} else {
		
		// check parameter
		id urlString = [anQuery parameterForKey:SampleExecutorParameterKeyUrlString];
		if( [urlString isKindOfClass:[NSString class]] == NO ) {
            return [self storeFailedResultWithQuery:anQuery];
		}
		
		// mark 'close query call' for distinguish query from 'HJAsyncHttpDeliverer'
		[anQuery setParameter:@"Y" forKey:SampleExecutorParameterKeyCloseQueryCall];
        
        // set session object to use.
        [anQuery setParameter:_session forKey:HJAsyncHttpDelivererParameterKeySession];
		
		// prepare HJAsyncHttpDeliverer object
        HJAsyncHttpDeliverer *asyncHttpDeliverer = [[HJAsyncHttpDeliverer alloc] initWithCloseQuery:anQuery];
        if( asyncHttpDeliverer == nil ) {
            return [self storeFailedResultWithQuery:anQuery];
        }
        
#warning set trust host if you deal with server by HTTPS
        // set trust host if you deal with server by HTTPS
        // and if you consider that support iOS 9 over then check 'NSAppTransportSecurity' key at Info.plist.
        // you can handle these information from some global values or parameters from query object, and so on. it's up to you.
        //
        // [asyncHttpDeliverer setTrustedHosts:@[@"www.p9soft.com"]];
        
        [self setTask:asyncHttpDeliverer forKey:[@(asyncHttpDeliverer.issuedId) stringValue]];
        
        // read parameter values from query object.
        SampleExecutorOperation operaiton = (SampleExecutorOperation)[[anQuery parameterForKey:SampleExecutorParameterKeyOperation] integerValue];
        NSDictionary *requestDict = [anQuery parameterForKey:SampleExecutorParameterKeyRequestDict];
        NSString *filePath = [anQuery parameterForKey:SampleExecutorParameterKeyFilePath];
        NSString *formDataFieldName = [anQuery parameterForKey:SampleExecutorParameterKeyFormDataFieldName];
        NSString *fileName = [anQuery parameterForKey:SampleExecutorParameterKeyFileName];
        NSString *contentType = [anQuery parameterForKey:SampleExecutorParameterKeyContentType];
        
        // set HJAsyncHttpDeliverer for each case.
        switch( operaiton ) {
            case SampleExecutorOperationGet :
                [asyncHttpDeliverer setGetWithUrlString:(NSString *)urlString queryStringDict:requestDict];
                break;
            case SampleExecutorOperationPost :
                [asyncHttpDeliverer setPostWithUrlString:(NSString *)urlString formDataDict:requestDict contentType:HJAsyncHttpDelivererPostContentTypeUrlEncoded];
                break;
            case SampleExecutorOperationDownloadFile :
                [asyncHttpDeliverer setGetWithUrlString:(NSString *)urlString queryStringDict:requestDict toFilePath:filePath];
                break;
            case SampleExecutorOperationUploadFile :
                [asyncHttpDeliverer setPostUploadWithUrlString:(NSString *)urlString formDataField:formDataFieldName fileName:fileName fileContentType:contentType filePath:filePath];
                break;
            default :
                return [self storeFailedResultWithQuery:anQuery];
        }
        
		// bind it
		[self bindAsyncTask:asyncHttpDeliverer];
		
	}
	
	return YES;
}

- (void)setTask:(HJAsyncHttpDeliverer *)deliverer forKey:(NSString *)key
{
    if( (deliverer == nil) && (key == nil) ) {
        return;
    }
    _taskDict[key] = deliverer;
}

- (HJAsyncHttpDeliverer *)taskForKey:(NSString *)key
{
    if( key == nil ) {
        return nil;
    }
    return _taskDict[key];
}

- (void)removeTaskForKey:(NSString *)key
{
    if( key == nil ) {
        return;
    }
    [_taskDict removeObjectForKey:key];
}

- (HYResult *)resultForQuery:(id)anQuery
{
    HYResult *result = [HYResult resultWithName:self.name];
    [result setParametersFromDictionary:[anQuery paramDict]];
    
    return result;
}

- (BOOL)storeFailedResultWithQuery:(id)anQuery
{
    HYResult *result = [self resultForQuery:anQuery];
    if( result == nil ) {
        return NO;
    }
    [result setParameter:@"Y" forKey:SampleExecutorParameterKeyFailedFlag];
    [self storeResult:result];
    
    return YES;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler
{
    HJAsyncHttpDeliverer *asyncHttpDeliverer = [self taskForKey:task.taskDescription];
    if( asyncHttpDeliverer == nil ) {
        return;
    }
    if( completionHandler != nil ) {
        completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    HJAsyncHttpDeliverer *asyncHttpDeliverer = [self taskForKey:dataTask.taskDescription];
    [asyncHttpDeliverer receiveResponse:response];
    if( completionHandler != nil ) {
        completionHandler(NSURLSessionResponseAllow);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    HJAsyncHttpDeliverer *asyncHttpDeliverer = [self taskForKey:dataTask.taskDescription];
    [asyncHttpDeliverer receiveData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    HJAsyncHttpDeliverer *asyncHttpDeliverer = [self taskForKey:task.taskDescription];
    [asyncHttpDeliverer sendBodyData:bytesSent totalBytesWritten:totalBytesSent totalBytesExpectedToWrite:totalBytesExpectedToSend];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error
{
    HJAsyncHttpDeliverer *asyncHttpDeliverer = [self taskForKey:task.taskDescription];
    if( error != nil ) {
        [asyncHttpDeliverer failWithError:error];
    } else {
        [asyncHttpDeliverer finishLoading];
    }
}

@end
