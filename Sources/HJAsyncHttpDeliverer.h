//
//  HJAsyncHttpDeliverer.h
//  Hydra Jelly Box
//
//  Created by Tae Hyun Na on 2013. 4. 4.
//  Copyright (c) 2014, P9 SOFT, Inc. All rights reserved.
//
//  Licensed under the MIT license.

#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <Hydra/Hydra.h>


#define		HJAsyncHttpDelivererNotification							@"HJAsyncHttpDelivererNotifification"

#define		HJAsyncHttpDelivererParameterKeyFailed                      @"HJAsyncHttpDelivererParameterKeyFailed"
#define		HJAsyncHttpDelivererParameterKeyCanceled					@"HJAsyncHttpDelivererParameterKeyCanceled"
#define     HJAsyncHttpDelivererParameterKeySession                     @"HJAsyncHttpDelivererParameterKeySession"
#define		HJAsyncHttpDelivererParameterKeyUrlString					@"HJAsyncHttpDelivererParameterKeyUrlString"
#define		HJAsyncHttpDelivererParameterKeyResponse					@"HJAsyncHttpDelivererParameterKeyResponse"
#define		HJAsyncHttpDelivererParameterKeyBody						@"HJAsyncHttpDelivererParameterKeyBody"
#define		HJAsyncHttpDelivererParameterKeyIssuedId					@"HJAsyncHttpDelivererParameterKeyIssuedId"
#define		HJAsyncHttpDelivererParameterKeyStatus                      @"HJAsyncHttpDelivererParameterKeyStatus"
#define		HJAsyncHttpDelivererParameterKeyContentLength				@"HJAsyncHttpDelivererParameterKeyContentLength"
#define		HJAsyncHttpDelivererParameterKeyAmountTransferedLength      @"HJAsyncHttpDelivererParameterKeyAmountTransferedLength"
#define		HJAsyncHttpDelivererParameterKeyExpectedTransferedLength	@"HJAsyncHttpDelivererParameterKeyExpectedTransferedLength"
#define		HJAsyncHttpDelivererParameterKeyCurrentTransferedLength     @"HJAsyncHttpDelivererParameterKeyCurrentTransferedLength"
#define		HJAsyncHttpDelivererParameterKeyFilePath					@"HJAsyncHttpDelivererParameterKeyTransferedFilePath"
#define		HJAsyncHttpDelivererParameterKeyWorkingTimeByMilisecond     @"HJAsyncHttpDelivererParameterKeyWorkingTimeByMilisecond"


typedef NS_ENUM(NSInteger, HJAsyncHttpDelivererStatus)
{
	HJAsyncHttpDelivererStatusStart,
	HJAsyncHttpDelivererstatusConnected,
	HJAsyncHttpDelivererStatusTransfering,
	HJAsyncHttpDelivererStatusDone,
	HJAsyncHttpDelivererStatusCanceled,
	HJAsyncHttpDelivererStatusFailed
    
};

typedef NS_ENUM(NSInteger, HJAsyncHttpDelivererPostContentType)
{
	HJAsyncHttpDelivererPostContentTypeMultipart,
	HJAsyncHttpDelivererPostContentTypeUrlEncoded,
	HJAsyncHttpDelivererPostContentTypeApplicationJson
};


@interface HJAsyncHttpDeliverer : HYAsyncTask

- (BOOL) setGetWithUrlString: (NSString * _Nullable)urlString;
- (BOOL) setGetWithUrlString: (NSString * _Nullable)urlString queryStringDict: (NSDictionary * _Nullable)queryStringDict;
- (BOOL) setGetWithUrlString: (NSString * _Nullable)urlString toFilePath: (NSString * _Nullable)filePath;
- (BOOL) setGetWithUrlString: (NSString * _Nullable)urlString queryStringDict: (NSDictionary * _Nullable)queryStringDict toFilePath: (NSString * _Nullable)filePath;
- (BOOL) setPostWithUrlString: (NSString * _Nullable)urlString formDataDict: (NSDictionary * _Nullable)dict contentType: (HJAsyncHttpDelivererPostContentType)contentType;
- (BOOL) setPostWithUrlString: (NSString * _Nullable)urlString body:(NSData * _Nullable)body contentTypeValue: (NSString * _Nullable)contentTypeValue;
- (BOOL) setPostUploadWithUrlString: (NSString * _Nullable)urlString formDataField: (NSString * _Nullable)fieldName fileName: (NSString * _Nullable)fileName fileContentType: (NSString * _Nullable)fileContentType data: (NSData * _Nullable)data;
- (BOOL) setPostUploadWithUrlString: (NSString * _Nullable)urlString formDataField: (NSString * _Nullable)fieldName fileName: (NSString * _Nullable)fileName fileContentType: (NSString * _Nullable)fileContentType filePath: (NSString * _Nullable)filePath;
- (BOOL) setPutWithUrlString: (NSString * _Nullable)urlString formDataDict: (NSDictionary * _Nullable)dict contentType: (HJAsyncHttpDelivererPostContentType)contentType;
- (BOOL) setPutWithUrlString: (NSString * _Nullable)urlString body:(NSData * _Nullable)body contentTypeValue: (NSString * _Nullable)contentTypeValue;
- (BOOL) setPutUploadWithUrlString: (NSString * _Nullable)urlString formDataField: (NSString * _Nullable)fieldName fileName: (NSString * _Nullable)fileName fileContentType: (NSString * _Nullable)fileContentType data: (NSData * _Nullable)data;
- (BOOL) setPutUploadWithUrlString: (NSString * _Nullable)urlString formDataField: (NSString * _Nullable)fieldName fileName: (NSString * _Nullable)fileName fileContentType: (NSString * _Nullable)fileContentType filePath: (NSString * _Nullable)filePath;
- (BOOL) setDeleteWithUrlString: (NSString * _Nullable)urlString formDataDict: (NSDictionary * _Nullable)dict contentType: (HJAsyncHttpDelivererPostContentType)contentType;
- (BOOL) setDeleteWithUrlString: (NSString * _Nullable)urlString body:(NSData * _Nullable)body contentTypeValue: (NSString * _Nullable)contentTypeValue;

- (id _Nullable) valueForQueryStringField: (NSString * _Nullable)fieldName;
- (BOOL) setValue: (id _Nullable)value forQueryStringField: (NSString * _Nullable)fieldName;
- (BOOL) setValuesFromQueryStringDict: (NSDictionary * _Nullable)dict;
- (void) removeValueForQueryStringField: (NSString * _Nullable)fieldName;
- (void) clearAllQueryStringFields;

- (NSString * _Nullable) valueForHeaderField: (NSString * _Nullable)fieldName;
- (BOOL) setValue: (NSString * _Nullable)value forHeaderField: (NSString * _Nullable)fieldName;
- (BOOL) setValuesFromHeaderFieldDict: (NSDictionary * _Nullable)dict;
- (void) removeValueForHeaderField: (NSString * _Nullable)fieldName;
- (void) clearAllHeaderFields;

- (id _Nullable) valueForFormDataField: (NSString * _Nullable)fieldName;
- (BOOL) setValue: (id _Nullable)value forFormDataField: (NSString * _Nullable)fieldName;
- (BOOL) setData: (NSData * _Nullable)data forFormDataField: (NSString * _Nullable)fieldName fileName: (NSString * _Nullable)fileName contentType: (NSString * _Nullable)contentType;
- (BOOL) setFileForStreammingUpload: (NSString * _Nullable)filePath forFormDataField: (NSString * _Nullable)fieldName fileName: (NSString * _Nullable)fileName contentType: (NSString * _Nullable)contentType;
- (BOOL) setValuesFromFormDataDict: (NSDictionary * _Nullable)dict;
- (void) removeValueForFormDataField: (NSString * _Nullable)fieldName;
- (void) clearAllFormDataFields;

- (BOOL) setBodyData: (NSData * _Nullable)bodyData;

- (void) receiveChallenge:(NSURLAuthenticationChallenge * _Nullable)challenge completionHandler:(void (^_Nullable)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler;
- (void) receiveResponse: (NSURLResponse * _Nullable)response;
- (void) receiveData: (NSData * _Nullable)data;
- (void) sendBodyData: (NSInteger)bytesWritten totalBytesWritten: (NSInteger)totalBytesWritten totalBytesExpectedToWrite: (NSInteger)totalBytesExpectedToWrite;
- (void) failWithError: (NSError * _Nullable)error;
- (void) finishLoading;

@property (nonatomic, assign) BOOL notifyStatus;
@property (nonatomic, assign) NSURLRequestCachePolicy cachePolicy;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;
@property (nonatomic, strong) NSString * _Nullable urlString;
@property (nonatomic, strong) NSString * _Nullable method;
@property (nonatomic, strong) NSString * _Nullable multipartBoundaryString;
@property (nonatomic, strong) NSArray * _Nullable trustedHosts;
@property (nonatomic, assign) NSInteger transferBufferSize;

@end
