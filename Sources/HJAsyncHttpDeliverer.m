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


@interface HJAsyncHttpDeliverer( HJAsyncHttpDelivererPrivate )

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

@synthesize notifyStatus = _notifyStatus;
@dynamic cachePolicy;
@dynamic timeoutInterval;
@dynamic urlString;
@dynamic method;
@synthesize multipartBoundaryString = _multipartBoundaryString;
@synthesize trustedHosts = _trustedHosts;
@dynamic transferBufferSize;

- (id) initWithCloseQuery: (id)anQuery
{
	if( (self = [super initWithCloseQuery: anQuery]) != nil ) {
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
	
	if( [dict count] <= 0 ) {
		return nil;
	}
	
	if( (string = [[NSMutableString alloc] init]) == nil ) {
		return nil;
	}
	
	for( key in dict ) {
		anObject = [dict objectForKey: key];
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
		if( [string length] <= 0 ) {
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
	
	if( _connection != nil ) {
		[_connection cancel];
		_connection = nil;
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
	return [filePath lastPathComponent];
}

- (NSString *) suggestMimeTypeForFilePath: (NSString *)filePath
{
	NSString	*pathExtention;
	CFStringRef	uti;
	CFStringRef	mimeType;
	
	if( (pathExtention = [filePath pathExtension]) == nil ) {
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
	
	[_sendData setLength: 0];
	
	boundaryData = [[NSString stringWithFormat: @"--%@\r\n", _multipartBoundaryString] dataUsingEncoding: NSUTF8StringEncoding];
	
    if( [[_headerFieldDict objectForKey: @"Content-Type"] isEqualToString: @"application/x-www-form-urlencoded"] == YES ) {
        if( [_formDataFieldDict count] > 0 ) {
            if( (value = [self stringForUrlEncodedFromDict: _formDataFieldDict]) != nil ) {
                [_sendData appendData: [value dataUsingEncoding: NSUTF8StringEncoding]];
            }
        }
    } else if( [[_headerFieldDict objectForKey: @"Content-Type"] rangeOfString: @"multipart/form-data"].location != NSNotFound ) {
        if( [_formDataFieldDict count] > 0 ) {
            for( fieldName in _formDataFieldDict ) {
                anObject = [_formDataFieldDict objectForKey: fieldName];
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
                    fileName = [_formDataFileNameDict objectForKey: fieldName];
                    fileContentType = [_formDataContentTypeDict objectForKey: fieldName];
                    [_sendData appendData: boundaryData];
                    if( ([fileName length] > 0) && ([fileContentType length] > 0) ) {
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
    } else if( [[_headerFieldDict objectForKey: @"Content-Type"] isEqualToString: @"application/json"] == YES ) {
        if( [_formDataFieldDict count] > 0 ) {
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
	
	if( [_uploadFilePath length] > 0 ) {
		[_sendData appendData: boundaryData];
		[_sendData appendData: [[NSString stringWithFormat: @"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\nContent-Type: %@\r\n\r\n", _uploadFileFormDataField, _uploadFileName, _uploadFileContentType] dataUsingEncoding: NSUTF8StringEncoding]];
		_bufferSize = ([_sendData length] > _transferBufferSize) ? [_sendData length] : _transferBufferSize;
		if( (_buffer = (uint8_t *)malloc( (size_t)_bufferSize )) == NULL ) {
			return NO;
		}
		_filledSize = [_sendData length];
		_lookingIndex = 0;
		memcpy( _buffer, [_sendData bytes], _filledSize );
	}
	
	return YES;
}

- (BOOL) bindConnection
{
	NSUInteger			contentLength;
	NSInputStream		*inputStream;
	
	if( [_uploadFilePath length] > 0 ) {
			
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
		
		contentLength = [_sendData length];
		contentLength += [(NSNumber *)[[[NSFileManager defaultManager] attributesOfItemAtPath: _uploadFilePath error: NULL] objectForKey: NSFileSize] unsignedIntegerValue];
		
		[_request setHTTPBodyStream: inputStream];
		
	} else {
		
		if( (contentLength = [_sendData length]) > 0 ) {
			[_request setHTTPBody: _sendData];
		}
		
	}
	
	if( contentLength <= 0 ) {
		contentLength = [[_request HTTPBody] length];
	}
	
	_lastUploadContentLengthNumber = [NSNumber numberWithUnsignedInteger: contentLength];
	[_request setValue: [[NSNumber numberWithUnsignedInteger: contentLength] stringValue] forHTTPHeaderField: @"Content-Length"];
	
	HYTRACE_BLOCK
	(
		HYTRACE( @"- HJAsyncHttpDeliverer [%d] request start", _issuedId );
		HYTRACE( @"- url    [%@]", [_request URL] );
		HYTRACE( @"- method [%@]", [_request HTTPMethod] );
		for( NSString *key in [_request allHTTPHeaderFields] ) {
			HYTRACE( @"- header [%@][%@]", key, [[_request allHTTPHeaderFields] objectForKey: key] );
		}
		if( [_uploadFilePath length] > 0 ) {
			HYTRACE( @"- body    STREAMMING" );
		} else {
			HYTRACE( @"- body    [%@]", [[NSString alloc] initWithData: [_request HTTPBody] encoding: NSUTF8StringEncoding] );
		}
	)
	
	if( (_connection = [[NSURLConnection alloc] initWithRequest: _request delegate: self startImmediately: NO]) == nil ) {
		return NO;
	}
    [_connection scheduleInRunLoop: [NSRunLoop currentRunLoop] forMode: NSRunLoopCommonModes];
    [_connection start];
	
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
	[_closeQuery setParameter: @"Y" forKey: HJAsyncHttpDelivererParameterKeyFailed];
	
	if( _notifyStatus == YES ) {
		[self pushNotifyStatusToMainThread: [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSNumber numberWithUnsignedInteger:(NSUInteger)self.issuedId], HJAsyncHttpDelivererParameterKeyIssuedId,
											 _urlString, HJAsyncHttpDelivererParameterKeyUrlString,
											 [NSNumber numberWithInteger:(NSInteger)HJAsyncHttpDelivererStatusFailed], HJAsyncHttpDelivererParameterKeyStatus,
											 nil]
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
	if( [urlString length] <= 0 ) {
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
	if( [filePath length] <= 0 ) {
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
	if( [urlString length] <= 0 ) {
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
	[self setMethod: @"POST"];
	
	[self setValuesFromFormDataDict: dict];
	
	return YES;
}

- (BOOL) setPostUploadWithUrlString: (NSString *)urlString formDataField: (NSString *)fieldName fileName: (NSString *)fileName fileContentType: (NSString *)fileContentType data: (NSData *)data
{
	if( ([urlString length] <= 0) || ([fieldName length] <= 0) || ([fileName length] <= 0) || ([fileContentType length] <=0) || ([data length] <= 0) ) {
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
	if( [urlString length] <= 0 ) {
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
    if( [urlString length] <= 0 ) {
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
    if( ([urlString length] <= 0) || ([fieldName length] <= 0) || ([fileName length] <= 0) || ([fileContentType length] <=0) || ([data length] <= 0) ) {
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
    if( [urlString length] <= 0 ) {
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
    if( [urlString length] <= 0 ) {
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
    if( [fieldName length] <= 0 ) {
        return nil;
    }
    
    return [_queryStringFieldDict objectForKey:fieldName];
}

- (BOOL) setValue: (id)value forQueryStringField: (NSString *)fieldName
{
	if( (value == nil) || ([fieldName length] <= 0) ) {
		return NO;
	}
	
	[_queryStringFieldDict setObject: value forKey: fieldName];
	
	return YES;
}

- (BOOL) setValuesFromQueryStringDict: (NSDictionary *)dict
{
	if( [dict count] <= 0 ) {
		return YES;
	}
	
	[_queryStringFieldDict setValuesForKeysWithDictionary: dict];
	
	return YES;
}

- (void) removeValueForQueryStringField: (NSString *)fieldName
{
	if( [fieldName length] <= 0 ) {
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
    if( [fieldName length] <= 0 ) {
        return nil;
    }
    
    return [_headerFieldDict objectForKey:fieldName];
}

- (BOOL) setValue: (NSString *)value forHeaderField: (NSString *)fieldName
{
	if( ([value length] <= 0) || ([fieldName length] <= 0) ) {
		return NO;
	}
	
	[_headerFieldDict setObject: value forKey: fieldName];
	
	return YES;
}

- (BOOL) setValuesFromHeaderFieldDict: (NSDictionary *)dict
{
	if( [dict count] <= 0 ) {
		return YES;
	}
	
	[_headerFieldDict setValuesForKeysWithDictionary: dict];
	
	return YES;
}

- (void) removeValueForHeaderField: (NSString *)fieldName
{
	if( [fieldName length] <= 0 ) {
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
    if( [fieldName length] <= 0 ) {
        return nil;
    }
    
    return [_formDataFieldDict objectForKey:fieldName];
}

- (BOOL) setValue: (id)value forFormDataField: (NSString *)fieldName
{
	if( (value == nil) || ([fieldName length] <= 0) ) {
		return NO;
	}
		
	[_formDataFieldDict setObject: value forKey: fieldName];
	
	return YES;
}

- (BOOL) setData: (NSData *)data forFormDataField: (NSString *)fieldName fileName: (NSString *)fileName contentType: (NSString *)contentType
{
	if( ([data length] <= 0) || ([fieldName length] <= 0) || ([fileName length] <= 0) || ([contentType length] <= 0) ) {
		return NO;
	}
	
	[_formDataFieldDict setObject: data forKey: fieldName];
	[_formDataFileNameDict setObject: fileName forKey: fieldName];
	[_formDataContentTypeDict setObject: contentType forKey: fieldName];
	
	return YES;
}

- (BOOL) setFileForStreammingUpload: (NSString *)filePath forFormDataField: (NSString *)fieldName fileName: (NSString *)fileName contentType: (NSString *)contentType
{
	BOOL		isDirectory;
	
	if( ([filePath length] <= 0) || ([fieldName length] <= 0) || ([fileName length] <= 0) || ([contentType length] <= 0) ) {
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
	
	if( [_uploadFileName length] <= 0 ) {
		_uploadFileName = [self suggestFileNameForFilePath: _uploadFilePath];
	}
	if( [_uploadFileContentType length] <= 0 ) {
		_uploadFileContentType = [self suggestMimeTypeForFilePath: _uploadFileName];
	}
	
	if( ([_uploadFileName length] <= 0) || ([_uploadFileContentType length] <= 0) ) {
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
	if( [dict count] <= 0 ) {
		return YES;
	}
	
	[_formDataFieldDict setValuesForKeysWithDictionary: dict];
	
	return YES;
}

- (void) removeValueForFormDataField: (NSString *)fieldName
{
	if( [fieldName length] <= 0 ) {
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
	if( [bodyData length] <= 0 ) {
		return NO;
	}
	
	[_request setHTTPBody: bodyData];
	
	return YES;
}

- (BOOL) didBind
{
	NSString		*baseDirectory;
	BOOL			isDirecotry;
	BOOL			fileCreated;
	NSString		*value;
	NSString		*urlStringWithQueries;
	NSURL			*url;
	
	[self resetTransfer];
	
	if( _notifyStatus == YES ) {
		[self pushNotifyStatusToMainThread: [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSNumber numberWithUnsignedInteger:(NSUInteger)self.issuedId], HJAsyncHttpDelivererParameterKeyIssuedId,
											 _urlString, HJAsyncHttpDelivererParameterKeyUrlString,
											 [NSNumber numberWithInteger:(NSInteger)HJAsyncHttpDelivererStatusStart], HJAsyncHttpDelivererParameterKeyStatus,
											 nil]
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
	[_request setURL: url];
	
	if( [_headerFieldDict count] > 0 ) {
		[_request setAllHTTPHeaderFields: _headerFieldDict];
	}
	
	if( ([[_request HTTPMethod] isEqualToString: @"GET"] == YES) ) {
		
		_fileHandle = nil;
		_connection = nil;
		fileCreated = NO;
		
		if( [_downloadFilePath length] > 0 ) {
			if( (baseDirectory = [_downloadFilePath stringByDeletingLastPathComponent]) != nil ) {
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
			_fileHandle = [NSFileHandle fileHandleForWritingAtPath: _downloadFilePath];
			if( _fileHandle != nil ) {
				_connection = [[NSURLConnection alloc] initWithRequest: _request delegate: self startImmediately: NO];
			}
		} else {
			_connection = [[NSURLConnection alloc] initWithRequest: _request delegate: self startImmediately: NO];
		}
		if( _connection == nil ) {
			[_closeQuery setParameter: @"Y" forKey: HJAsyncHttpDelivererParameterKeyFailed];
			if( fileCreated == YES ) {
				[[NSFileManager defaultManager] removeItemAtPath: _downloadFilePath error: nil];
			}
			return NO;
		}
        [_connection scheduleInRunLoop: [NSRunLoop currentRunLoop] forMode: NSRunLoopCommonModes];
        [_connection start];
		
		HYTRACE_BLOCK
		(
			if( _connection != nil ) {
				HYTRACE( @"- HJAsyncHttpDeliverer [%d] request start", _issuedId );
				HYTRACE( @"- url    [%@]", [_request URL] );
				HYTRACE( @"- method [%@]", [_request HTTPMethod] );
				for( NSString *key in [_request allHTTPHeaderFields] ) {
					HYTRACE( @"- header [%@][%@]", key, [[_request allHTTPHeaderFields] objectForKey: key] );
				}
				HYTRACE( @"- body    [%@]", [[NSString alloc] initWithData: [_request HTTPBody] encoding: NSUTF8StringEncoding] );
			}
		)
		
	} else if( ([[_request HTTPMethod] isEqualToString: @"POST"] == YES) || ([[_request HTTPMethod] isEqualToString: @"PUT"] == YES) || ([[_request HTTPMethod] isEqualToString: @"DELETE"] == YES) ) {
		
		dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			
			if( [self fillSendDataWithFormData] == NO ) {
				[self resetTransfer];
				[self doneWithError];
			}
			
			dispatch_async( dispatch_get_main_queue(), ^{
				
				if( [[_closeQuery parameterForKey: HJAsyncHttpDelivererParameterKeyFailed] boolValue] == NO ) {
					if( [self bindConnection] == NO ) {
						[self resetTransfer];
						[self doneWithError];
					}
				}
				
			});
			
		});
		
	} else {
		
		if( (_connection = [[NSURLConnection alloc] initWithRequest: _request delegate: self startImmediately: NO]) == nil ) {
			[_closeQuery setParameter: @"Y" forKey: HJAsyncHttpDelivererParameterKeyFailed];
			return NO;
		}
        [_connection scheduleInRunLoop: [NSRunLoop currentRunLoop] forMode: NSRunLoopCommonModes];
        [_connection start];
		
	}
	
	return YES;
}

- (void) willDone
{
	[_closeQuery setParameter: [NSNumber numberWithUnsignedInteger:(NSUInteger)self.issuedId] forKey: HJAsyncHttpDelivererParameterKeyIssuedId];
}

- (void) willCancel
{
	[_closeQuery setParameter: [NSNumber numberWithUnsignedInteger:(NSUInteger)self.issuedId] forKey: HJAsyncHttpDelivererParameterKeyIssuedId];
	[_closeQuery setParameter: @"Y" forKey: HJAsyncHttpDelivererParameterKeyCanceled];
	[_closeQuery setParameter: [NSNumber numberWithUnsignedInt: [self passedMilisecondFromBind]] forKey: HJAsyncHttpDelivererParameterKeyWorkingTimeByMilisecond];
	
	if( _notifyStatus == YES ) {
		[self pushNotifyStatusToMainThread: [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSNumber numberWithUnsignedInteger:(NSUInteger)self.issuedId], HJAsyncHttpDelivererParameterKeyIssuedId,
											 _urlString, HJAsyncHttpDelivererParameterKeyUrlString,
											 [NSNumber numberWithInteger:(NSInteger)HJAsyncHttpDelivererStatusCanceled], HJAsyncHttpDelivererParameterKeyStatus,
											 nil]
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
	if( [_limiterName length] > 0 ) {
		description = [description stringByAppendingFormat: @"<limiter name=\"%@\" count=\"%ld\"/>", _limiterName, (long)_limiterCount];
	}
	if( [_uploadFileName length] > 0 ) {
		description = [description stringByAppendingFormat: @"<upload_file_name=\"%@\"", _uploadFileName];
	}
	if( [_uploadFilePath length] > 0 ) {
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
	[_request setCachePolicy: cachePolicy];
}

- (NSTimeInterval) timeoutInterval
{
	return _request.timeoutInterval;
}

- (void) setTimeoutInterval: (NSTimeInterval)timeoutInterval
{
	[_request setTimeoutInterval: timeoutInterval];
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
	[_request setHTTPMethod: method];
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
				fileSizeNumber = (NSNumber *)[[[NSFileManager defaultManager] attributesOfItemAtPath: _uploadFilePath error: NULL] objectForKey: NSFileSize];
				[self pushNotifyStatusToMainThread: [NSDictionary dictionaryWithObjectsAndKeys:
													 [NSNumber numberWithUnsignedInteger:(NSUInteger)self.issuedId], HJAsyncHttpDelivererParameterKeyIssuedId,
													 _urlString, HJAsyncHttpDelivererParameterKeyUrlString,
													 [NSNumber numberWithInteger:(NSInteger)HJAsyncHttpDelivererstatusConnected], HJAsyncHttpDelivererParameterKeyStatus,
													 fileSizeNumber, HJAsyncHttpDelivererParameterKeyContentLength,
													 nil]
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
						_filledSize = [boundaryData length];
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
						[self pushNotifyStatusToMainThread: [NSDictionary dictionaryWithObjectsAndKeys:
															 [NSNumber numberWithUnsignedInteger:(NSUInteger)self.issuedId], HJAsyncHttpDelivererParameterKeyIssuedId,
															 _urlString, HJAsyncHttpDelivererParameterKeyUrlString,
															 [NSNumber numberWithInteger:(NSInteger)HJAsyncHttpDelivererStatusDone], HJAsyncHttpDelivererParameterKeyStatus,
															 nil]
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

#pragma mark -
#pragma mark NSURLConnection methods

- (void) connection: (NSURLConnection *)connection didReceiveResponse: (NSURLResponse *)response
{
	_response = response;
	
	if( _notifyStatus == YES ) {
		[self pushNotifyStatusToMainThread: [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSNumber numberWithUnsignedInteger:(NSUInteger)self.issuedId], HJAsyncHttpDelivererParameterKeyIssuedId,
											 _urlString, HJAsyncHttpDelivererParameterKeyUrlString,
											 [NSNumber numberWithInteger:(NSInteger)HJAsyncHttpDelivererstatusConnected], HJAsyncHttpDelivererParameterKeyStatus,
											 [NSNumber numberWithLongLong: [response expectedContentLength]], HJAsyncHttpDelivererParameterKeyContentLength,
											 nil]
		 ];
	}
}

- (BOOL) connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace: (NSURLProtectionSpace *)protectionSpace
{
	return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void) connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
	if( [challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust] == YES ) {
		if( [_trustedHosts containsObject:challenge.protectionSpace.host] == YES ) {
			[challenge.sender useCredential: [NSURLCredential credentialForTrust: challenge.protectionSpace.serverTrust] forAuthenticationChallenge: challenge];
		}
	}
	
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void) connection:( NSURLConnection *)connection didReceiveData: (NSData *)data
{
	NSUInteger		transferLength;
	
	if( _fileHandle != nil ) {
		[_fileHandle writeData: data];
		transferLength = (NSUInteger)[_fileHandle offsetInFile];
	} else {
		if( _receivedData == nil ) {
			_receivedData = [[NSMutableData alloc] init];
		}
		[_receivedData appendData: data];
		transferLength = [_receivedData length];
	}
	
	if( _notifyStatus == YES ) {
		[self pushNotifyStatusToMainThread: [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSNumber numberWithUnsignedInteger:(NSUInteger)self.issuedId], HJAsyncHttpDelivererParameterKeyIssuedId,
											 _urlString, HJAsyncHttpDelivererParameterKeyUrlString,
											 [NSNumber numberWithInteger:(NSInteger)HJAsyncHttpDelivererStatusTransfering], HJAsyncHttpDelivererParameterKeyStatus,
											 [NSNumber numberWithLongLong: transferLength], HJAsyncHttpDelivererParameterKeyAmountTransferedLength,
											 [NSNumber numberWithLongLong: [data length]], HJAsyncHttpDelivererParameterKeyCurrentTransferedLength,
											 nil]
		 ];
	}
}

- (void) connection: (NSURLConnection *)connection didSendBodyData: (NSInteger)bytesWritten totalBytesWritten: (NSInteger)totalBytesWritten totalBytesExpectedToWrite: (NSInteger)totalBytesExpectedToWrite
{	
	if( _notifyStatus == YES ) {
		[self pushNotifyStatusToMainThread: [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSNumber numberWithUnsignedInteger:(NSUInteger)self.issuedId], HJAsyncHttpDelivererParameterKeyIssuedId,
											 _urlString, HJAsyncHttpDelivererParameterKeyUrlString,
											 [NSNumber numberWithInteger:(NSInteger)HJAsyncHttpDelivererStatusTransfering], HJAsyncHttpDelivererParameterKeyStatus,
											 _lastUploadContentLengthNumber, HJAsyncHttpDelivererParameterKeyContentLength,
											 [NSNumber numberWithInteger:totalBytesWritten], HJAsyncHttpDelivererParameterKeyAmountTransferedLength,
                                             [NSNumber numberWithInteger:totalBytesExpectedToWrite], HJAsyncHttpDelivererParameterKeyExpectedTransferedLength,
											 [NSNumber numberWithInteger:bytesWritten], HJAsyncHttpDelivererParameterKeyCurrentTransferedLength,
											 nil]
		 ];
	}
}

- (void) connection: (NSURLConnection *)connection didFailWithError: (NSError *)error
{
	[_closeQuery setParameter: [NSNumber numberWithUnsignedInt: [self passedMilisecondFromBind]] forKey: HJAsyncHttpDelivererParameterKeyWorkingTimeByMilisecond];
	if( _response != nil ) {
		[_closeQuery setParameter: _response forKey: HJAsyncHttpDelivererParameterKeyResponse];
	}
	
	HYTRACE_BLOCK
	(
		HYTRACE( @"- HJAsyncHttpDeliverer [%d] request failed", _issuedId );
        HYTRACE( @"- status code [%ld]", (long)((NSHTTPURLResponse *)_response).statusCode );
		HYTRACE( @"- url [%@]", [_request URL] );
		HYTRACE( @"- method [%@]", [_request HTTPMethod] );
		for( NSString *key in [_request allHTTPHeaderFields] ) {
			HYTRACE( @"- header [%@][%@]", key, [[_request allHTTPHeaderFields] objectForKey: key] );
		}
		HYTRACE( @"- body [%@]", [[NSString alloc] initWithData: [_request HTTPBody] encoding: NSUTF8StringEncoding] );
	)
	
	[self resetTransfer];
	[self doneWithError];
	
	if( [_downloadFilePath length] > 0 ) {
		[[NSFileManager defaultManager] removeItemAtPath: _downloadFilePath error: nil];
		_downloadFilePath = nil;
	}
}

- (void) connectionDidFinishLoading: (NSURLConnection *)connection
{
	[_closeQuery setParameter: [NSNumber numberWithUnsignedInt: [self passedMilisecondFromBind]] forKey: HJAsyncHttpDelivererParameterKeyWorkingTimeByMilisecond];
	if( _response != nil ) {
		[_closeQuery setParameter: _response forKey: HJAsyncHttpDelivererParameterKeyResponse];
	}
	
    if( _receivedData != nil ) {
        [_closeQuery setParameter: _receivedData forKey: HJAsyncHttpDelivererParameterKeyBody];
    }
	
	HYTRACE_BLOCK
	(
        HYTRACE( @"- HJAsyncHttpDeliverer [%d] request end", _issuedId );
        HYTRACE( @"- status code [%ld]", (long)((NSHTTPURLResponse *)_response).statusCode );
        HYTRACE( @"- url [%@]", [_request URL] );
        HYTRACE( @"- method [%@]", [_request HTTPMethod] );
        for( NSString *key in [_request allHTTPHeaderFields] ) {
            HYTRACE( @"- header [%@][%@]", key, [[_request allHTTPHeaderFields] objectForKey: key] );
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
		[self pushNotifyStatusToMainThread: [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSNumber numberWithUnsignedInteger:(NSUInteger)self.issuedId], HJAsyncHttpDelivererParameterKeyIssuedId,
											 _urlString, HJAsyncHttpDelivererParameterKeyUrlString,
											 [NSNumber numberWithInteger:(NSInteger)HJAsyncHttpDelivererStatusDone], HJAsyncHttpDelivererParameterKeyStatus,
											 nil]
		 ];
	}
	
	[self resetTransfer];
	[self done];
}

@end
