//
//  HJAsyncHttpDeliverer.m
//  Hydra Jelly Box
//
//  Created by Tae Hyun Na on 2013. 4. 4.
//  Copyright (c) 2014, P9 SOFT, Inc. All rights reserved.
//
//  Licensed under the MIT license.

#import "HJAsyncHttpDeliverer.h"


#define		kMultipartBoundaryString	@"----------i0am1default2boundary3for4hjasynchttpdeliverer5"
#define		kTransferBufferSize			8192


@interface HJAsyncHttpDeliverer() <NSStreamDelegate>
{
    NSMutableURLRequest		*_request;
    NSURLSession            *_session;
    NSURLSessionDataTask    *_dataTask;
    NSURLSessionUploadTask  *_uploadTask;
    NSURLResponse			*_response;
    NSMutableData			*_sendData;
    NSMutableData			*_receivedData;
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

- (NSString *) stringForUrlEncoded: (NSString *)string;
- (NSString *) stringForUrlEncodedFromDict: (NSMutableDictionary *)dict;
- (void) resetTransfer;
- (void) closeProducerStream;
- (NSString *) suggestFileNameForFilePath: (NSString *)filePath;
- (NSString *) suggestMimeTypeForFilePath: (NSString *)filePath;
- (BOOL) fillSendDataWithFormData;
- (BOOL) bindConnection;
- (NSInputStream *) makeBoundInputStreamWithBufferSize: (NSUInteger)bufferSize;
- (void) doneWithError;
- (void) postNotifyStatus: (NSDictionary *)paramDict;
- (void) pushNotifyStatusToMainThread: (NSDictionary *)paramDict;

@end


@implementation HJAsyncHttpDeliverer

@dynamic cachePolicy;
@dynamic timeoutInterval;
@dynamic urlString;
@dynamic method;
@dynamic transferBufferSize;

- (instancetype) initWithCloseQuery: (id)anQuery
{
	if( (self = [super initWithCloseQuery: anQuery]) != nil ) {
        if( [anQuery isKindOfClass: [HYQuery class]] == NO ) {
            return nil;
        }
		if( (_request = [[NSMutableURLRequest alloc] init]) == nil ) {
			return nil;
		}
		if( (_queryStringFieldDict = [[NSMutableDictionary alloc] init]) == nil ) {
			return nil;
		}
		if( (_headerFieldDict = [[NSMutableDictionary alloc] init]) == nil ) {
			return nil;
		}
		if( (_formDataFieldDict = [[NSMutableDictionary alloc] init]) == nil ) {
			return nil;
		}
		if( (_formDataFileNameDict = [[NSMutableDictionary alloc] init]) == nil ) {
			return nil;
		}
		if( (_formDataContentTypeDict = [[NSMutableDictionary alloc] init]) == nil ) {
			return nil;
		}
		if( (_sharedDict = [[NSMutableDictionary alloc] init]) == nil ) {
			return nil;
		}
		if( (_sendData = [[NSMutableData alloc] init]) == nil ) {
			return nil;
		}
		_multipartBoundaryString = kMultipartBoundaryString;
		_transferBufferSize = kTransferBufferSize;
        _session = [(HYQuery *)anQuery parameterForKey:HJAsyncHttpDelivererParameterKeySession];
	}
	
	return self;
}

- (void) dealloc
{
	[self resetTransfer];
}

- (NSString *) stringForUrlEncoded: (NSString *)string
{
	return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes( kCFAllocatorDefault, (CFStringRef)string, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8 ));
}

- (NSString *) stringForUrlEncodedFromDict: (NSMutableDictionary *)dict
{
	NSString		*key, *encodedKey;
	NSString		*value, *encodedValue;
	id				anObject;
	NSMutableString	*string;
	
	if( dict.count <= 0 ) {
		return nil;
	}
	
	if( (string = [[NSMutableString alloc] init]) == nil ) {
		return nil;
	}
	
	for( key in dict ) {
		anObject = dict[key];
        if( [anObject isKindOfClass: [NSNumber class]] == YES ) {
            value = [anObject stringValue];
        } else if( [anObject isKindOfClass: [NSString class]] == YES ) {
			value = (NSString *)anObject;
		} else if( [anObject isKindOfClass: [NSData class]] == YES ) {
			value = [[NSString alloc] initWithData: anObject encoding: NSUTF8StringEncoding];
		} else {
            value = [anObject description];
		}
		encodedKey = [self stringForUrlEncoded: key];
		encodedValue = [self stringForUrlEncoded: value];
		if( string.length <= 0 ) {
			[string appendFormat: @"%@=%@", encodedKey, encodedValue];
		} else {
			[string appendFormat: @"&%@=%@", encodedKey, encodedValue];
		}
	}
	
	return string;
}

- (void) resetTransfer
{
	if( _fileHandle != nil ) {
		[_fileHandle closeFile];
		_fileHandle = nil;
	}
    if( _dataTask != nil ) {
        [_dataTask cancel];
        _dataTask = nil;
    }
    if( _uploadTask != nil ) {
        [_uploadTask cancel];
        _uploadTask = nil;
    }
	
	if( _producerStream != nil ) {
		_producerStream.delegate = nil;
		[_producerStream removeFromRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
		[_producerStream close];
		_producerStream = nil;
	}
	
	if( _fileStream != nil ) {
		[_fileStream close];
		_fileStream = nil;
	}
	
	if( _response != nil ) {
		_response = nil;
	}
	_receivedData = nil;

	if( _buffer != NULL ) {
		free( _buffer );
		_buffer = NULL;
	}
	_bufferSize = 0;
}

- (void) closeProducerStream
{
	if( _producerStream != nil ) {
		_producerStream.delegate = nil;
		[_producerStream removeFromRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
		[_producerStream close];
		_producerStream = nil;
	}
}

- (NSString *) suggestFileNameForFilePath: (NSString *)filePath
{
	return filePath.lastPathComponent;
}

- (NSString *) suggestMimeTypeForFilePath: (NSString *)filePath
{
	NSString	*pathExtention;
	CFStringRef	uti;
	CFStringRef	mimeType;
	
	if( (pathExtention = filePath.pathExtension) == nil ) {
		return nil;
	}
	
	uti = UTTypeCreatePreferredIdentifierForTag( kUTTagClassFilenameExtension, (__bridge CFStringRef)pathExtention, NULL );
	mimeType = UTTypeCopyPreferredTagWithClass( uti, kUTTagClassMIMEType );
	CFRelease( uti );
	
	return CFBridgingRelease( mimeType );
}

- (BOOL) fillSendDataWithFormData
{
	NSData		*boundaryData;
	NSString	*fieldName;
	id			anObject;
	NSString	*value;
	NSData		*data;
	NSString	*fileName;
	NSString	*fileContentType;
	NSError		*error;
	
	_sendData.length = 0;
	
	boundaryData = [[NSString stringWithFormat: @"--%@\r\n", _multipartBoundaryString] dataUsingEncoding: NSUTF8StringEncoding];
	
    if( [_headerFieldDict[@"Content-Type"] isEqualToString: @"application/x-www-form-urlencoded"] == YES ) {
        if( _formDataFieldDict.count > 0 ) {
            if( (value = [self stringForUrlEncodedFromDict: _formDataFieldDict]) != nil ) {
                [_sendData appendData: [value dataUsingEncoding: NSUTF8StringEncoding]];
            }
        }
    } else if( [_headerFieldDict[@"Content-Type"] rangeOfString: @"multipart/form-data"].location != NSNotFound ) {
        if( _formDataFieldDict.count > 0 ) {
            for( fieldName in _formDataFieldDict ) {
                anObject = _formDataFieldDict[fieldName];
                if( [anObject isKindOfClass: [NSNumber class]] == YES ) {
                    value = [anObject stringValue];
                    [_sendData appendData: boundaryData];
                    [_sendData appendData: [[NSString stringWithFormat: @"Content-Disposition: form-data; name=\"%@\"\r\n\r\n%@\r\n", fieldName, value] dataUsingEncoding: NSUTF8StringEncoding]];
                } else if( [anObject isKindOfClass: [NSString class]] == YES ) {
                    value = (NSString *)anObject;
                    [_sendData appendData: boundaryData];
                    [_sendData appendData: [[NSString stringWithFormat: @"Content-Disposition: form-data; name=\"%@\"\r\n\r\n%@\r\n", fieldName, value] dataUsingEncoding: NSUTF8StringEncoding]];
                } else if( [anObject isKindOfClass: [NSData class]] == YES ) {
                    data = (NSData *)anObject;
                    fileName = _formDataFileNameDict[fieldName];
                    fileContentType = _formDataContentTypeDict[fieldName];
                    [_sendData appendData: boundaryData];
                    if( (fileName.length > 0) && (fileContentType.length > 0) ) {
                        [_sendData appendData: [[NSString stringWithFormat: @"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\nContent-Type: %@\r\n\r\n", fieldName, fileName, fileContentType] dataUsingEncoding: NSUTF8StringEncoding]];
                    } else {
                        [_sendData appendData: [[NSString stringWithFormat: @"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", fieldName] dataUsingEncoding: NSUTF8StringEncoding]];
                    }
                    [_sendData appendData: data];
                    [_sendData appendData: [[NSString stringWithFormat: @"\r\n"] dataUsingEncoding: NSUTF8StringEncoding]];
                } else {
                    value = [anObject description];
                    [_sendData appendData: boundaryData];
                    [_sendData appendData: [[NSString stringWithFormat: @"Content-Disposition: form-data; name=\"%@\"\r\n\r\n%@\r\n", fieldName, value] dataUsingEncoding: NSUTF8StringEncoding]];
                }
            }
            [_sendData appendData: [[NSString stringWithFormat: @"--%@--\r\n", _multipartBoundaryString] dataUsingEncoding: NSUTF8StringEncoding]];
        }
    } else if( [_headerFieldDict[@"Content-Type"] isEqualToString: @"application/json"] == YES ) {
        if( _formDataFieldDict.count > 0 ) {
            if( [NSJSONSerialization isValidJSONObject: _formDataFieldDict] == YES ) {
                if( (data = [NSJSONSerialization dataWithJSONObject: _formDataFieldDict options: NSJSONWritingPrettyPrinted error: &error]) != nil ) {
                    [_sendData appendData: data];
                }
            }
        } else {
            if( (data = [@"{}" dataUsingEncoding: NSUTF8StringEncoding]) != nil ) {
                [_sendData appendData: data];
            }
        }
    }
	
	if( _uploadFilePath.length > 0 ) {
		[_sendData appendData: boundaryData];
		[_sendData appendData: [[NSString stringWithFormat: @"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\nContent-Type: %@\r\n\r\n", _uploadFileFormDataField, _uploadFileName, _uploadFileContentType] dataUsingEncoding: NSUTF8StringEncoding]];
		_bufferSize = (_sendData.length > _transferBufferSize) ? _sendData.length : _transferBufferSize;
		if( (_buffer = (uint8_t *)malloc( (size_t)_bufferSize )) == NULL ) {
			return NO;
		}
		_filledSize = _sendData.length;
		_lookingIndex = 0;
		memcpy( _buffer, [_sendData bytes], _filledSize );
	}
	
	return YES;
}

- (BOOL) bindConnection
{
	NSUInteger			contentLength;
	NSInputStream		*inputStream;
	
	if( _uploadFilePath.length > 0 ) {
			
		if( (_fileStream = [[NSInputStream alloc] initWithFileAtPath: _uploadFilePath]) == nil ) {
			return NO;
		}
		[_fileStream open];
		
		if( (inputStream = [self makeBoundInputStreamWithBufferSize: _transferBufferSize]) == nil ) {
			return NO;
		}
		_producerStream.delegate = self;
		[_producerStream scheduleInRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
		[_producerStream open];
		
		[_sendData appendData: [[NSString stringWithFormat: @"\r\n--%@--\r\n", _multipartBoundaryString] dataUsingEncoding: NSUTF8StringEncoding]];
		
		contentLength = _sendData.length;
		contentLength += ((NSNumber *)[[NSFileManager defaultManager] attributesOfItemAtPath: _uploadFilePath error: NULL][NSFileSize]).unsignedIntegerValue;
		
		_request.HTTPBodyStream = inputStream;
		
	} else {
		
		if( (contentLength = _sendData.length) > 0 ) {
			_request.HTTPBody = _sendData;
		}
		
	}
	
	if( contentLength <= 0 ) {
		contentLength = _request.HTTPBody.length;
	}
	
	_lastUploadContentLengthNumber = @(contentLength);
	[_request setValue: @(contentLength).stringValue forHTTPHeaderField: @"Content-Length"];
	
	HYTRACE_BLOCK
	(
		HYTRACE( @"- HJAsyncHttpDeliverer [%d] request start", self.issuedId );
		HYTRACE( @"- url    [%@]", [_request URL] );
		HYTRACE( @"- method [%@]", [_request HTTPMethod] );
		for( NSString *key in [_request allHTTPHeaderFields] ) {
			HYTRACE( @"- header [%@][%@]", key, [_request allHTTPHeaderFields][key] );
		}
		if( [_uploadFilePath length] > 0 ) {
			HYTRACE( @"- body    STREAMMING" );
		} else {
			HYTRACE( @"- body    [%@]", [[NSString alloc] initWithData: [_request HTTPBody] encoding: NSUTF8StringEncoding] );
		}
	)
	
    if( _uploadFilePath.length > 0 ) {
        _uploadTask = [_session uploadTaskWithStreamedRequest:_request];
    } else {
        _uploadTask = [_session uploadTaskWithRequest:_request fromData:_sendData];
    }
    _uploadTask.taskDescription = [@(self.issuedId) stringValue];
    [_uploadTask resume];
	
	return YES;
}

- (NSInputStream *) makeBoundInputStreamWithBufferSize: (NSUInteger)bufferSize
{
	CFReadStreamRef			readStream;
	CFWriteStreamRef		writeStream;
	
	if( bufferSize == 0 ) {
		return nil;
	}
	
	readStream = NULL;
	writeStream = NULL;
	
	CFStreamCreateBoundPair( NULL, &readStream, &writeStream, (CFIndex)bufferSize );
	
	_producerStream = CFBridgingRelease( writeStream );
	
	return CFBridgingRelease( readStream );
}

- (void) doneWithError
{
	[self.closeQuery setParameter: @"Y" forKey: HJAsyncHttpDelivererParameterKeyFailed];
	
	if( _notifyStatus == YES ) {
		[self pushNotifyStatusToMainThread: @{HJAsyncHttpDelivererParameterKeyIssuedId: @((NSUInteger)self.issuedId),
											 HJAsyncHttpDelivererParameterKeyUrlString: _urlString,
											 HJAsyncHttpDelivererParameterKeyStatus: @((NSInteger)HJAsyncHttpDelivererStatusFailed)}
		 ];
	}
	
	[self done];
}

- (void) postNotifyStatus: (NSDictionary *)paramDict
{
	[[NSNotificationCenter defaultCenter] postNotificationName: HJAsyncHttpDelivererNotification object: self userInfo: paramDict];
}

- (void) pushNotifyStatusToMainThread: (NSDictionary *)paramDict
{
	[self performSelectorOnMainThread: @selector(postNotifyStatus:) withObject: paramDict waitUntilDone: NO];
}

- (BOOL) setGetWithUrlString: (NSString *)urlString
{
	if( urlString.length <= 0 ) {
		return NO;
	}
	
	self.urlString = urlString;
	[self setMethod: @"GET"];
	
	return YES;
}

- (BOOL) setGetWithUrlString: (NSString *)urlString queryStringDict: (NSDictionary *)queryStringDict
{
	if( [self setGetWithUrlString: urlString] == NO ) {
		return NO;
	}
	
	[self setValuesFromQueryStringDict: queryStringDict];
	
	return YES;
}

- (BOOL) setGetWithUrlString: (NSString *)urlString toFilePath: (NSString *)filePath
{
	if( filePath.length <= 0 ) {
		return NO;
	}
	
	if( [self setGetWithUrlString: urlString] == NO ) {
		return NO;
	}
	
	_downloadFilePath = filePath;
	
	return YES;
}

- (BOOL) setGetWithUrlString: (NSString *)urlString queryStringDict: (NSDictionary *)queryStringDict toFilePath: (NSString *)filePath
{
	if( [self setGetWithUrlString: urlString queryStringDict: queryStringDict] == NO ) {
		return NO;
	}
	
	[self setValuesFromQueryStringDict: queryStringDict];
    
    _downloadFilePath = filePath;
	
	return YES;
}

- (BOOL) setPostWithUrlString: (NSString *)urlString formDataDict: (NSDictionary *)dict contentType: (HJAsyncHttpDelivererPostContentType)contentType
{
	if( urlString.length <= 0 ) {
		return NO;
	}
    
	switch( contentType ) {
		case HJAsyncHttpDelivererPostContentTypeMultipart :
			[self setValue: [NSString stringWithFormat :@"multipart/form-data; boundary=%@", _multipartBoundaryString] forHeaderField: @"Content-Type"];
			break;
		case HJAsyncHttpDelivererPostContentTypeUrlEncoded :
			[self setValue: @"application/x-www-form-urlencoded" forHeaderField: @"Content-Type"];
			break;
		case HJAsyncHttpDelivererPostContentTypeApplicationJson :
			[self setValue: @"application/json" forHeaderField: @"Content-Type"];
			[self setValue: @"application/json" forHeaderField: @"Accept"];
			break;
		default :
			return NO;
	}
	
	self.urlString = urlString;
	self.method = @"POST";
	
	[self setValuesFromFormDataDict: dict];
	
	return YES;
}

- (BOOL) setPostUploadWithUrlString: (NSString *)urlString formDataField: (NSString *)fieldName fileName: (NSString *)fileName fileContentType: (NSString *)fileContentType data: (NSData *)data
{
	if( (urlString.length <= 0) || (fieldName.length <= 0) || (fileName.length <= 0) || (fileContentType.length <=0) || (data.length <= 0) ) {
		return NO;
	}
	
	[self setValue: [NSString stringWithFormat :@"multipart/form-data; boundary=%@", _multipartBoundaryString] forHeaderField: @"Content-Type"];
	self.urlString = urlString;
	[self setMethod: @"POST"];
	
	[self setData: data forFormDataField: fieldName fileName: fileName contentType: fileContentType];
	
	return YES;
}

- (BOOL) setPostUploadWithUrlString: (NSString *)urlString formDataField: (NSString *)fieldName fileName: (NSString *)fileName fileContentType: (NSString *)fileContentType filePath: (NSString *)filePath
{
	if( urlString.length <= 0 ) {
		return NO;
	}
	
	if( [self setFileForStreammingUpload: filePath forFormDataField: fieldName fileName: fileName contentType: fileContentType] == NO ) {
		return NO;
	}
	
	[self setValue: [NSString stringWithFormat :@"multipart/form-data; boundary=%@", _multipartBoundaryString] forHeaderField: @"Content-Type"];
	self.urlString = urlString;
	[self setMethod: @"POST"];
	
	return YES;
}

- (BOOL) setPutWithUrlString: (NSString *)urlString formDataDict: (NSDictionary *)dict contentType: (HJAsyncHttpDelivererPostContentType)contentType
{
    if( urlString.length <= 0 ) {
        return NO;
    }
    
    switch( contentType ) {
        case HJAsyncHttpDelivererPostContentTypeMultipart :
            [self setValue: [NSString stringWithFormat :@"multipart/form-data; boundary=%@", _multipartBoundaryString] forHeaderField: @"Content-Type"];
            break;
        case HJAsyncHttpDelivererPostContentTypeUrlEncoded :
            [self setValue: @"application/x-www-form-urlencoded" forHeaderField: @"Content-Type"];
            break;
        case HJAsyncHttpDelivererPostContentTypeApplicationJson :
            [self setValue: @"application/json" forHeaderField: @"Content-Type"];
            [self setValue: @"application/json" forHeaderField: @"Accept"];
            break;
        default :
            return NO;
    }
    
    self.urlString = urlString;
    [self setMethod: @"PUT"];
    
    [self setValuesFromFormDataDict: dict];
    
    return YES;
}

- (BOOL) setPutUploadWithUrlString: (NSString *)urlString formDataField: (NSString *)fieldName fileName: (NSString *)fileName fileContentType: (NSString *)fileContentType data: (NSData *)data
{
    if( (urlString.length <= 0) || (fieldName.length <= 0) || (fileName.length <= 0) || (fileContentType.length <=0) || (data.length <= 0) ) {
        return NO;
    }
    
    [self setValue: [NSString stringWithFormat :@"multipart/form-data; boundary=%@", _multipartBoundaryString] forHeaderField: @"Content-Type"];
    self.urlString = urlString;
    [self setMethod: @"PUT"];
    
    [self setData: data forFormDataField: fieldName fileName: fileName contentType: fileContentType];
    
    return YES;
}

- (BOOL) setPutUploadWithUrlString: (NSString *)urlString formDataField: (NSString *)fieldName fileName: (NSString *)fileName fileContentType: (NSString *)fileContentType filePath: (NSString *)filePath
{
    if( urlString.length <= 0 ) {
        return NO;
    }
    
    if( [self setFileForStreammingUpload: filePath forFormDataField: fieldName fileName: fileName contentType: fileContentType] == NO ) {
        return NO;
    }
    
    [self setValue: [NSString stringWithFormat :@"multipart/form-data; boundary=%@", _multipartBoundaryString] forHeaderField: @"Content-Type"];
    self.urlString = urlString;
    [self setMethod: @"PUT"];
    
    return YES;
}

- (BOOL) setDeleteWithUrlString: (NSString *)urlString formDataDict: (NSDictionary *)dict contentType: (HJAsyncHttpDelivererPostContentType)contentType
{
    if( urlString.length <= 0 ) {
        return NO;
    }
    
    switch( contentType ) {
        case HJAsyncHttpDelivererPostContentTypeMultipart :
            [self setValue: [NSString stringWithFormat :@"multipart/form-data; boundary=%@", _multipartBoundaryString] forHeaderField: @"Content-Type"];
            break;
        case HJAsyncHttpDelivererPostContentTypeUrlEncoded :
            [self setValue: @"application/x-www-form-urlencoded" forHeaderField: @"Content-Type"];
            break;
        case HJAsyncHttpDelivererPostContentTypeApplicationJson :
            [self setValue: @"application/json" forHeaderField: @"Content-Type"];
            [self setValue: @"application/json" forHeaderField: @"Accept"];
            break;
        default :
            return NO;
    }
    
    self.urlString = urlString;
    [self setMethod: @"DELETE"];
    
    [self setValuesFromFormDataDict: dict];
    
    return YES;
}

- (id) valueForQueryStringField: (NSString *)fieldName
{
    if( fieldName.length <= 0 ) {
        return nil;
    }
    
    return _queryStringFieldDict[fieldName];
}

- (BOOL) setValue: (id)value forQueryStringField: (NSString *)fieldName
{
	if( (value == nil) || (fieldName.length <= 0) ) {
		return NO;
	}
	
	_queryStringFieldDict[fieldName] = value;
	
	return YES;
}

- (BOOL) setValuesFromQueryStringDict: (NSDictionary *)dict
{
	if( dict.count <= 0 ) {
		return YES;
	}
	
	[_queryStringFieldDict setValuesForKeysWithDictionary: dict];
	
	return YES;
}

- (void) removeValueForQueryStringField: (NSString *)fieldName
{
	if( fieldName.length <= 0 ) {
		return;
	}
	
	[_queryStringFieldDict removeObjectForKey: fieldName];
}

- (void) clearAllQueryStringFields
{
	[_queryStringFieldDict removeAllObjects];
}

- (NSString *) valueForHeaderField: (NSString *)fieldName
{
    if( fieldName.length <= 0 ) {
        return nil;
    }
    
    return _headerFieldDict[fieldName];
}

- (BOOL) setValue: (NSString *)value forHeaderField: (NSString *)fieldName
{
	if( (value.length <= 0) || (fieldName.length <= 0) ) {
		return NO;
	}
	
	_headerFieldDict[fieldName] = value;
	
	return YES;
}

- (BOOL) setValuesFromHeaderFieldDict: (NSDictionary *)dict
{
	if( dict.count <= 0 ) {
		return YES;
	}
	
	[_headerFieldDict setValuesForKeysWithDictionary: dict];
	
	return YES;
}

- (void) removeValueForHeaderField: (NSString *)fieldName
{
	if( fieldName.length <= 0 ) {
		return;
	}
	
	[_headerFieldDict removeObjectForKey: fieldName];
}

- (void) clearAllHeaderFields
{
	[_headerFieldDict removeAllObjects];
}

- (id) valueForFormDataField: (NSString *)fieldName
{
    if( fieldName.length <= 0 ) {
        return nil;
    }
    
    return _formDataFieldDict[fieldName];
}

- (BOOL) setValue: (id)value forFormDataField: (NSString *)fieldName
{
	if( (value == nil) || (fieldName.length <= 0) ) {
		return NO;
	}
		
	_formDataFieldDict[fieldName] = value;
	
	return YES;
}

- (BOOL) setData: (NSData *)data forFormDataField: (NSString *)fieldName fileName: (NSString *)fileName contentType: (NSString *)contentType
{
	if( (data.length <= 0) || (fieldName.length <= 0) || (fileName.length <= 0) || (contentType.length <= 0) ) {
		return NO;
	}
	
	_formDataFieldDict[fieldName] = data;
	_formDataFileNameDict[fieldName] = fileName;
	_formDataContentTypeDict[fieldName] = contentType;
	
	return YES;
}

- (BOOL) setFileForStreammingUpload: (NSString *)filePath forFormDataField: (NSString *)fieldName fileName: (NSString *)fileName contentType: (NSString *)contentType
{
	BOOL		isDirectory;
	
	if( (filePath.length <= 0) || (fieldName.length <= 0) || (fileName.length <= 0) || (contentType.length <= 0) ) {
		return NO;
	}
	if( [[NSFileManager defaultManager] fileExistsAtPath: filePath isDirectory: &isDirectory] == NO ) {
		return NO;
	}
	if( isDirectory == YES ) {
		return NO;
	}
		
	_uploadFileFormDataField = fieldName;
	_uploadFileContentType = contentType;
	_uploadFileName = fileName;
	_uploadFilePath = filePath;
	
	if( _uploadFileName.length <= 0 ) {
		_uploadFileName = [self suggestFileNameForFilePath: _uploadFilePath];
	}
	if( _uploadFileContentType.length <= 0 ) {
		_uploadFileContentType = [self suggestMimeTypeForFilePath: _uploadFileName];
	}
	
	if( (_uploadFileName.length <= 0) || (_uploadFileContentType.length <= 0) ) {
		_uploadFileFormDataField = nil;
		_uploadFileContentType = nil;
		_uploadFileName = nil;
		_uploadFilePath = nil;
		return NO;
	}
	
	return YES;
}

- (BOOL) setValuesFromFormDataDict: (NSDictionary *)dict
{
	if( dict.count <= 0 ) {
		return YES;
	}
	
	[_formDataFieldDict setValuesForKeysWithDictionary: dict];
	
	return YES;
}

- (void) removeValueForFormDataField: (NSString *)fieldName
{
	if( fieldName.length <= 0 ) {
		return;
	}
	
	[_formDataFieldDict removeObjectForKey: fieldName];
}

- (void) clearAllFormDataFields
{
	[_formDataFieldDict removeAllObjects];
}

- (BOOL) setBodyData: (NSData *)bodyData
{
	if( bodyData.length <= 0 ) {
		return NO;
	}
	
	_request.HTTPBody = bodyData;
	
	return YES;
}

- (BOOL) didBind
{
	NSString		*baseDirectory;
	BOOL			isDirecotry;
	BOOL			fileCreated;
    BOOL            taskReady;
	NSString		*value;
	NSString		*urlStringWithQueries;
	NSURL			*url;
	
	[self resetTransfer];
	
	if( _notifyStatus == YES ) {
		[self pushNotifyStatusToMainThread: @{HJAsyncHttpDelivererParameterKeyIssuedId: @((NSUInteger)self.issuedId),
											 HJAsyncHttpDelivererParameterKeyUrlString: _urlString,
											 HJAsyncHttpDelivererParameterKeyStatus: @((NSInteger)HJAsyncHttpDelivererStatusStart)}
		 ];
	}
	
	if( (value = [self stringForUrlEncodedFromDict: _queryStringFieldDict]) == nil ) {
		urlStringWithQueries = _urlString;
	} else {
        if( [_urlString rangeOfString:@"?"].location == NSNotFound ) {
            urlStringWithQueries = [NSString stringWithFormat: @"%@?%@", _urlString, value];
        } else {
            urlStringWithQueries = [NSString stringWithFormat: @"%@&%@", _urlString, value];
        }
	}
	
	if( (url = [NSURL URLWithString: urlStringWithQueries]) == nil ) {
		url = [NSURL URLWithString: [urlStringWithQueries stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]];
	}
	_request.URL = url;
	
	if( _headerFieldDict.count > 0 ) {
		_request.allHTTPHeaderFields = _headerFieldDict;
	}
	
	if( ([_request.HTTPMethod isEqualToString: @"GET"] == YES) ) {
		
		_fileHandle = nil;
		fileCreated = NO;
        taskReady = YES;
		
		if( _downloadFilePath.length > 0 ) {
			if( (baseDirectory = _downloadFilePath.stringByDeletingLastPathComponent) != nil ) {
				if( [[NSFileManager defaultManager] fileExistsAtPath: baseDirectory isDirectory: &isDirecotry] == NO ) {
					[[NSFileManager defaultManager] createDirectoryAtPath: baseDirectory withIntermediateDirectories: YES attributes: nil error: nil];
				} else {
					if( isDirecotry == NO ) {
						[[NSFileManager defaultManager] removeItemAtPath: baseDirectory error: nil];
						[[NSFileManager defaultManager] createDirectoryAtPath: baseDirectory withIntermediateDirectories: YES attributes: nil error: nil];
					}
				}
				fileCreated = [[NSFileManager defaultManager] createFileAtPath: _downloadFilePath contents: nil attributes: nil];
			}
            if( (_fileHandle = [NSFileHandle fileHandleForWritingAtPath: _downloadFilePath]) == nil ) {
                taskReady = NO;
            }
		}
        if( taskReady == NO ) {
			[self.closeQuery setParameter: @"Y" forKey: HJAsyncHttpDelivererParameterKeyFailed];
			if( fileCreated == YES ) {
				[[NSFileManager defaultManager] removeItemAtPath: _downloadFilePath error: nil];
			}
			return NO;
        }
        _dataTask = [_session dataTaskWithRequest:_request];
        _dataTask.taskDescription = [@(self.issuedId) stringValue];
        [_dataTask resume];
		
		HYTRACE_BLOCK
		(
            if( _dataTask != nil ) {
				HYTRACE( @"- HJAsyncHttpDeliverer [%d] request start", self.issuedId );
				HYTRACE( @"- url    [%@]", [_request URL] );
				HYTRACE( @"- method [%@]", [_request HTTPMethod] );
				for( NSString *key in [_request allHTTPHeaderFields] ) {
					HYTRACE( @"- header [%@][%@]", key, [_request allHTTPHeaderFields][key] );
				}
				HYTRACE( @"- body    [%@]", [[NSString alloc] initWithData: [_request HTTPBody] encoding: NSUTF8StringEncoding] );
			}
		)
		
	} else if( ([_request.HTTPMethod isEqualToString: @"POST"] == YES) || ([_request.HTTPMethod isEqualToString: @"PUT"] == YES) || ([_request.HTTPMethod isEqualToString: @"DELETE"] == YES) ) {
		
		dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			
			if( [self fillSendDataWithFormData] == NO ) {
				[self resetTransfer];
				[self doneWithError];
			}
			
			dispatch_async( dispatch_get_main_queue(), ^{
				
				if( [[self.closeQuery parameterForKey: HJAsyncHttpDelivererParameterKeyFailed] boolValue] == NO ) {
					if( [self bindConnection] == NO ) {
						[self resetTransfer];
						[self doneWithError];
					}
				}
				
			});
			
		});
		
	} else {
        
        _dataTask = [_session dataTaskWithRequest:_request];
        _dataTask.taskDescription = [@(self.issuedId) stringValue];
        [_dataTask resume];
		
	}
	
	return YES;
}

- (void) willDone
{
	[self.closeQuery setParameter: @((NSUInteger)self.issuedId) forKey: HJAsyncHttpDelivererParameterKeyIssuedId];
}

- (void) willCancel
{
	[self.closeQuery setParameter: @((NSUInteger)self.issuedId) forKey: HJAsyncHttpDelivererParameterKeyIssuedId];
	[self.closeQuery setParameter: @"Y" forKey: HJAsyncHttpDelivererParameterKeyCanceled];
	[self.closeQuery setParameter: @(self.passedMilisecondFromBind) forKey: HJAsyncHttpDelivererParameterKeyWorkingTimeByMilisecond];
	
	if( _notifyStatus == YES ) {
		[self pushNotifyStatusToMainThread: @{HJAsyncHttpDelivererParameterKeyIssuedId: @((NSUInteger)self.issuedId),
											 HJAsyncHttpDelivererParameterKeyUrlString: _urlString,
											 HJAsyncHttpDelivererParameterKeyStatus: @((NSInteger)HJAsyncHttpDelivererStatusCanceled)}
		 ];
	}
}

- (void) willUnbind
{
	[self resetTransfer];
}

- (NSString *) brief
{
	return @"HJAsyncHttpDeliverer";
}

- (NSString *) customDataDescription
{
	NSString	*description;
	
	description = [NSString stringWithFormat: @"<request url=\"%@\" method=\"%@\"/>", _request.URL, _request.HTTPMethod];
	if( (self.limiterName).length > 0 ) {
		description = [description stringByAppendingFormat: @"<limiter name=\"%@\" count=\"%ld\"/>", self.limiterName, (long)self.limiterCount];
	}
	if( _uploadFileName.length > 0 ) {
		description = [description stringByAppendingFormat: @"<upload_file_name=\"%@\"", _uploadFileName];
	}
	if( _uploadFilePath.length > 0 ) {
		description = [description stringByAppendingFormat: @"<upload_file_path=\"%@\"", _uploadFilePath];
	}
	   
	return description;
}

- (NSURLRequestCachePolicy) cachePolicy
{
	return _request.cachePolicy;
}

- (void) setCachePolicy: (NSURLRequestCachePolicy)cachePolicy
{
	_request.cachePolicy = cachePolicy;
}

- (NSTimeInterval) timeoutInterval
{
	return _request.timeoutInterval;
}

- (void) setTimeoutInterval: (NSTimeInterval)timeoutInterval
{
	_request.timeoutInterval = timeoutInterval;
}

- (NSString *) urlString
{
	return _urlString;
}

- (void) setUrlString: (NSString *)urlString
{
	_urlString = urlString;
}

- (NSString *) method
{
	return _request.HTTPMethod;
}

- (void) setMethod: (NSString *)method
{
	_request.HTTPMethod = method;
}

- (NSInteger) transferBufferSize
{
	return _transferBufferSize;
}

- (void) setTransferBufferSize: (NSInteger)transferBufferSize
{
	if( transferBufferSize <= 0 ) {
		return;
	}
	
	_transferBufferSize = transferBufferSize;
}

#pragma mark -
#pragma mark NSStreamDelegate

- (void) stream: (NSStream *)theStream handleEvent: (NSStreamEvent)streamEvent
{
	NSUInteger		leftSize;
	NSInteger		writeBytes;
	NSNumber		*fileSizeNumber;
	NSData			*boundaryData;
	
	switch( streamEvent ) {
		case NSStreamEventOpenCompleted :
			if( _notifyStatus == YES ) {
				fileSizeNumber = (NSNumber *)[[NSFileManager defaultManager] attributesOfItemAtPath: _uploadFilePath error: NULL][NSFileSize];
				[self pushNotifyStatusToMainThread: @{HJAsyncHttpDelivererParameterKeyIssuedId: @((NSUInteger)self.issuedId),
													 HJAsyncHttpDelivererParameterKeyUrlString: _urlString,
													 HJAsyncHttpDelivererParameterKeyStatus: @((NSInteger)HJAsyncHttpDelivererstatusConnected),
													 HJAsyncHttpDelivererParameterKeyContentLength: fileSizeNumber}
				 ];
			}
			break;
		case NSStreamEventHasSpaceAvailable :
			//usleep( 500000 );
			if( (leftSize = (_filledSize - _lookingIndex)) <= 0 ) {
				if( _fileStream != nil ) {
					if( (_filledSize = [_fileStream read:(uint8_t *)_buffer maxLength: _transferBufferSize]) == 0 ) {
						[_fileStream close];
						_fileStream = nil;
						boundaryData = [[NSString stringWithFormat: @"\r\n--%@--\r\n", _multipartBoundaryString] dataUsingEncoding: NSUTF8StringEncoding];
						_filledSize = boundaryData.length;
						memcpy( _buffer, [boundaryData bytes], _filledSize );
					}
					_lookingIndex = 0;
				}
			}
			if( (leftSize = (_filledSize - _lookingIndex)) > 0 ) {
				if( (writeBytes = [_producerStream write: (const uint8_t *)(_buffer+_lookingIndex) maxLength: leftSize]) > 0 ) {
					_lookingIndex += writeBytes;
				} else {
					[self resetTransfer];
					[self doneWithError];
				}
			} else {
				if( _fileStream == nil ) {
					if( _notifyStatus == YES ) {
						[self pushNotifyStatusToMainThread: @{HJAsyncHttpDelivererParameterKeyIssuedId: @((NSUInteger)self.issuedId),
															 HJAsyncHttpDelivererParameterKeyUrlString: _urlString,
															 HJAsyncHttpDelivererParameterKeyStatus: @((NSInteger)HJAsyncHttpDelivererStatusDone)}
						 ];
					}
					[self closeProducerStream];
				}
			}
			break;
		case NSStreamEventErrorOccurred :
			[self resetTransfer];
			[self doneWithError];
			break;
		default :
			break;
	}
}

- (void) receiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler {
    
    NSURLSessionAuthChallengeDisposition authChallenge = NSURLSessionAuthChallengeUseCredential;
    if( _trustedHosts.count > 0 ) {
        if( [_trustedHosts containsObject:challenge.protectionSpace.host] == NO ) {
            authChallenge = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    }
    completionHandler(authChallenge, (authChallenge == NSURLSessionAuthChallengeUseCredential) ? [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] : nil);
}

- (void) receiveResponse: (NSURLResponse *)response
{
	_response = response;
	
	if( _notifyStatus == YES ) {
		[self pushNotifyStatusToMainThread: @{HJAsyncHttpDelivererParameterKeyIssuedId: @((NSUInteger)self.issuedId),
											 HJAsyncHttpDelivererParameterKeyUrlString: _urlString,
											 HJAsyncHttpDelivererParameterKeyStatus: @((NSInteger)HJAsyncHttpDelivererstatusConnected),
											 HJAsyncHttpDelivererParameterKeyContentLength: @(response.expectedContentLength)}
		 ];
	}
}

- (void) receiveData: (NSData *)data
{
	NSUInteger		transferLength;
	
	if( _fileHandle != nil ) {
        @try {
            [_fileHandle writeData: data];
        } @catch (NSException *exception) {
            [self failWithError:nil];
            return;
        }
        transferLength = (NSUInteger)_fileHandle.offsetInFile;
	} else {
		if( _receivedData == nil ) {
			_receivedData = [[NSMutableData alloc] init];
		}
		[_receivedData appendData: data];
		transferLength = _receivedData.length;
	}
    
	if( _notifyStatus == YES ) {
		[self pushNotifyStatusToMainThread: @{HJAsyncHttpDelivererParameterKeyIssuedId: @((NSUInteger)self.issuedId),
											 HJAsyncHttpDelivererParameterKeyUrlString: _urlString,
											 HJAsyncHttpDelivererParameterKeyStatus: @((NSInteger)HJAsyncHttpDelivererStatusTransfering),
											 HJAsyncHttpDelivererParameterKeyAmountTransferedLength: [NSNumber numberWithLongLong: transferLength],
											 HJAsyncHttpDelivererParameterKeyCurrentTransferedLength: [NSNumber numberWithLongLong: data.length]}
		 ];
	}
}

- (void) sendBodyData: (NSInteger)bytesWritten totalBytesWritten: (NSInteger)totalBytesWritten totalBytesExpectedToWrite: (NSInteger)totalBytesExpectedToWrite
{	
	if( _notifyStatus == YES ) {
		[self pushNotifyStatusToMainThread: @{HJAsyncHttpDelivererParameterKeyIssuedId: @((NSUInteger)self.issuedId),
											 HJAsyncHttpDelivererParameterKeyUrlString: _urlString,
											 HJAsyncHttpDelivererParameterKeyStatus: @((NSInteger)HJAsyncHttpDelivererStatusTransfering),
											 HJAsyncHttpDelivererParameterKeyContentLength: _lastUploadContentLengthNumber,
											 HJAsyncHttpDelivererParameterKeyAmountTransferedLength: @(totalBytesWritten),
                                             HJAsyncHttpDelivererParameterKeyExpectedTransferedLength: @(totalBytesExpectedToWrite),
											 HJAsyncHttpDelivererParameterKeyCurrentTransferedLength: @(bytesWritten)}
		 ];
	}
}

- (void) failWithError: (NSError *)error
{
	[self.closeQuery setParameter: @(self.passedMilisecondFromBind) forKey: HJAsyncHttpDelivererParameterKeyWorkingTimeByMilisecond];
	if( _response != nil ) {
		[self.closeQuery setParameter: _response forKey: HJAsyncHttpDelivererParameterKeyResponse];
	}
	
	HYTRACE_BLOCK
	(
		HYTRACE( @"- HJAsyncHttpDeliverer [%d] request failed", self.issuedId );
        HYTRACE( @"- status code [%ld]", (long)((NSHTTPURLResponse *)_response).statusCode );
		HYTRACE( @"- url [%@]", [_request URL] );
		HYTRACE( @"- method [%@]", [_request HTTPMethod] );
        NSDictionary *allHeaderFields = ((NSHTTPURLResponse *)_response).allHeaderFields;
		for( NSString *key in allHeaderFields ) {
			HYTRACE( @"- header [%@][%@]", key, allHeaderFields[key] );
		}
		HYTRACE( @"- body [%@]", [[NSString alloc] initWithData: [_request HTTPBody] encoding: NSUTF8StringEncoding] );
	)
	
	[self resetTransfer];
	[self doneWithError];
	
	if( _downloadFilePath.length > 0 ) {
		[[NSFileManager defaultManager] removeItemAtPath: _downloadFilePath error: nil];
		_downloadFilePath = nil;
	}
}

- (void) finishLoading
{
	[self.closeQuery setParameter: @(self.passedMilisecondFromBind) forKey: HJAsyncHttpDelivererParameterKeyWorkingTimeByMilisecond];
	if( _response != nil ) {
		[self.closeQuery setParameter: _response forKey: HJAsyncHttpDelivererParameterKeyResponse];
	}
	
    if( _fileHandle != nil ) {
        [_fileHandle closeFile];
        _fileHandle = nil;
    }
    if( _receivedData != nil ) {
        [self.closeQuery setParameter: _receivedData forKey: HJAsyncHttpDelivererParameterKeyBody];
    }
	
	HYTRACE_BLOCK
	(
        HYTRACE( @"- HJAsyncHttpDeliverer [%d] request end", self.issuedId );
        HYTRACE( @"- status code [%ld]", (long)((NSHTTPURLResponse *)_response).statusCode );
        HYTRACE( @"- url [%@]", [_request URL] );
        HYTRACE( @"- method [%@]", [_request HTTPMethod] );
         NSDictionary *allHeaderFields = ((NSHTTPURLResponse *)_response).allHeaderFields;
         for( NSString *key in allHeaderFields ) {
             HYTRACE( @"- header [%@][%@]", key, allHeaderFields[key] );
         }
		if( _receivedData != nil ) {
			HYTRACE( @"- body [%@]", [[NSString alloc] initWithData: _receivedData encoding: NSUTF8StringEncoding] );
		} else {
			if( ([_downloadFilePath length] > 0) && (_fileHandle != nil) ) {
				HYTRACE( @"- body length [%lld]", [_fileHandle offsetInFile] );
			} else {
				HYTRACE( @"- empty body" );
			}
		}
	)
	
	if( _notifyStatus == YES ) {
		[self pushNotifyStatusToMainThread: @{HJAsyncHttpDelivererParameterKeyIssuedId: @((NSUInteger)self.issuedId),
											 HJAsyncHttpDelivererParameterKeyUrlString: _urlString,
											 HJAsyncHttpDelivererParameterKeyStatus: @((NSInteger)HJAsyncHttpDelivererStatusDone)}
		 ];
	}
	
	[self resetTransfer];
	[self done];
}

@end
