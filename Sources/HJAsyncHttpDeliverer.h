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


typedef enum _HJAsyncHttpDelivererStatus_
{
	HJAsyncHttpDelivererStatusStart,
	HJAsyncHttpDelivererstatusConnected,
	HJAsyncHttpDelivererStatusTransfering,
	HJAsyncHttpDelivererStatusDone,
	HJAsyncHttpDelivererStatusCanceled,
	HJAsyncHttpDelivererStatusFailed
    
} HJAsyncHttpDelivererStatus;

typedef enum _HJAsyncHttpDelivererPostContentType_
{
	HJAsyncHttpDelivererPostContentTypeMultipart,
	HJAsyncHttpDelivererPostContentTypeUrlEncoded,
	HJAsyncHttpDelivererPostContentTypeApplicationJson
} HJAsyncHttpDelivererPostContentType;


@interface HJAsyncHttpDeliverer : HYAsyncTask <NSStreamDelegate>
{
	NSMutableURLRequest		*_request;
	NSURLConnection			*_connection;
	NSURLResponse			*_response;
	NSMutableData			*_sendData;
	NSMutableData			*_receivedData;
	BOOL					_notifyStatus;
	NSString				*_urlString;
	NSMutableDictionary		*_queryStringFieldDict;
	NSMutableDictionary		*_headerFieldDict;
	NSMutableDictionary		*_formDataFieldDict;
	NSMutableDictionary		*_formDataFileNameDict;
	NSMutableDictionary		*_formDataContentTypeDict;
	NSString				*_uploadFileFormDataField;
	NSString				*_uploadFileName;
	NSString				*_uploadFileContentType;
	NSString				*_uploadFilePath;
	NSString				*_downloadFilePath;
	NSFileHandle			*_fileHandle;
	NSString				*_multipartBoundaryString;
	NSArray					*_trustedHosts;
	NSNumber				*_lastUploadContentLengthNumber;
	NSInteger				_transferBufferSize;
	BOOL					_playWithLimitPool;
	uint8_t					*_buffer;
	NSUInteger				_bufferSize;
	NSUInteger				_filledSize;
	NSUInteger				_lookingIndex;
	NSOutputStream			*_producerStream;
	NSInputStream			*_fileStream;
	NSMutableDictionary		*_sharedDict;
}

- (BOOL) setGetWithUrlString: (NSString *)urlString;
- (BOOL) setGetWithUrlString: (NSString *)urlString queryStringDict: (NSDictionary *)queryStringDict;
- (BOOL) setGetWithUrlString: (NSString *)urlString toFilePath: (NSString *)filePath;
- (BOOL) setGetWithUrlString: (NSString *)urlString queryStringDict: (NSDictionary *)queryStringDict toFilePath: (NSString *)filePath;
- (BOOL) setPostWithUrlString: (NSString *)urlString formDataDict: (NSDictionary *)dict contentType: (HJAsyncHttpDelivererPostContentType)contentType;
- (BOOL) setPostUploadWithUrlString: (NSString *)urlString formDataField: (NSString *)fieldName fileName: (NSString *)fileName fileContentType: (NSString *)fileContentType data: (NSData *)data;
- (BOOL) setPostUploadWithUrlString: (NSString *)urlString formDataField: (NSString *)fieldName fileName: (NSString *)fileName fileContentType: (NSString *)fileContentType filePath: (NSString *)filePath;
- (BOOL) setPutWithUrlString: (NSString *)urlString formDataDict: (NSDictionary *)dict contentType: (HJAsyncHttpDelivererPostContentType)contentType;
- (BOOL) setPutUploadWithUrlString: (NSString *)urlString formDataField: (NSString *)fieldName fileName: (NSString *)fileName fileContentType: (NSString *)fileContentType data: (NSData *)data;
- (BOOL) setPutUploadWithUrlString: (NSString *)urlString formDataField: (NSString *)fieldName fileName: (NSString *)fileName fileContentType: (NSString *)fileContentType filePath: (NSString *)filePath;
- (BOOL) setDeleteWithUrlString: (NSString *)urlString formDataDict: (NSDictionary *)dict contentType: (HJAsyncHttpDelivererPostContentType)contentType;

- (BOOL) setValue: (id)value forQueryStringField: (NSString *)fieldName;
- (BOOL) setValuesFromQueryStringDict: (NSDictionary *)dict;
- (void) removeValueForQueryStringField: (NSString *)fieldName;
- (void) clearAllQueryStringFields;

- (BOOL) setValue: (NSString *)value forHeaderField: (NSString *)fieldName;
- (BOOL) setValuesFromHeaderFieldDict: (NSDictionary *)dict;
- (void) removeValueForHeaderField: (NSString *)fieldName;
- (void) clearAllHeaderFields;

- (BOOL) setValue: (NSString *)value forFormDataField: (NSString *)fieldName;
- (BOOL) setData: (NSData *)data forFormDataField: (NSString *)fieldName fileName: (NSString *)fileName contentType: (NSString *)contentType;
- (BOOL) setFileForStreammingUpload: (NSString *)filePath forFormDataField: (NSString *)fieldName fileName: (NSString *)fileName contentType: (NSString *)contentType;
- (BOOL) setValuesFromFormDataDict: (NSDictionary *)dict;
- (void) removeValueForFormDataField: (NSString *)fieldName;
- (void) clearAllFormDataFields;

- (BOOL) setBodyData: (NSData *)bodyData;

@property (nonatomic, assign) BOOL notifyStatus;
@property (nonatomic, assign) NSURLRequestCachePolicy cachePolicy;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;
@property (nonatomic, strong) NSString *urlString;
@property (nonatomic, strong) NSString *method;
@property (nonatomic, strong) NSString *multipartBoundaryString;
@property (nonatomic, strong) NSArray *trustedHosts;
@property (nonatomic, assign) NSInteger transferBufferSize;

@end
