//
//  KCSConnectionResponse.m
//  KinveyKit
//
//  Created by Brian Wilson on 11/23/11.
//  Copyright (c) 2011-2013 Kinvey. All rights reserved.
//
// This software is licensed to you under the Kinvey terms of service located at
// http://www.kinvey.com/terms-of-use. By downloading, accessing and/or using this
// software, you hereby accept such terms of service  (and any agreement referenced
// therein) and agree that you have read, understand and agree to be bound by such
// terms of service and are of legal age to agree to such terms with Kinvey.
//
// This software contains valuable confidential and proprietary information of
// KINVEY, INC and is subject to applicable licensing agreements.
// Unauthorized reproduction, transmission or distribution of this file and its
// contents is a violation of applicable laws.
//


#import "KCSConnectionResponse.h"
#import "KCS_SBJsonParser.h"
#import "KCSLogManager.h"
#import "KCSErrorUtilities.h"
#import "KinveyErrorCodes.h"
#import "NSString+KinveyAdditions.h"

@implementation KCSConnectionResponse

- (instancetype)initWithCode:(NSInteger)code responseData:(NSData *)data headerData:(NSDictionary *)header userData:(NSDictionary *)userDefinedData
{
    self = [super init];
    if (self){
        _responseCode = code;
        _responseData = data;
        _userData = userDefinedData;
        _responseHeaders = header;
    }
    
    return self;
}

+ (instancetype) connectionResponseWithCode:(NSInteger)code responseData:(NSData *)data headerData:(NSDictionary *)header userData:(NSDictionary *)userDefinedData
{
    // Return the autoreleased instance.
    if (code < 0){
        code = -1;
    }
    return [[KCSConnectionResponse alloc] initWithCode:code responseData:data headerData:header userData:userDefinedData];
}

- (NSString*) stringValue
{
    return [[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding];
}

- (id) jsonResponseValue:(NSError**) anError format:(NSStringEncoding)format
{
    KCS_SBJsonParser *parser = [[KCS_SBJsonParser alloc] init];
    NSString* string = [[NSString alloc] initWithData:self.responseData encoding:format];
    NSDictionary *jsonResponse = [parser objectWithData:[string dataUsingEncoding:NSUTF8StringEncoding]];
    if (parser.error) {
        KCSLogError(@"JSON Serialization retry failed: %@", parser.error);
        if (anError != NULL) {
            *anError = [KCSErrorUtilities createError:@{NSURLErrorFailingURLStringErrorKey : _userData[NSURLErrorFailingURLStringErrorKey]} description:parser.error errorCode:KCSInvalidJSONFormatError domain:KCSNetworkErrorDomain requestId:self.requestId];
        }
    }
    NSObject *jsonData = [jsonResponse valueForKey:@"result"];
    return jsonData;
}

- (id) jsonResponseValue:(NSError**) anError
{
    if (self.responseData == nil) {
        return nil;
    }
    if (self.responseData.length == 0) {
        return [NSData data];
    }
    //results are now wrapped by request in KCSRESTRequest, and need to unpack them here.
    KCS_SBJsonParser *parser = [[KCS_SBJsonParser alloc] init];
    NSDictionary *jsonResponse = [parser objectWithData:self.responseData];
    NSObject *jsonData = nil;
    if (parser.error) {
        KCSLogError(@"JSON Serialization failed: %@", parser.error);
        if ([parser.error isEqualToString:@"Broken Unicode encoding"]) {
            NSObject* reevaluatedObject = [self jsonResponseValue:anError format:NSASCIIStringEncoding];
            return reevaluatedObject;
        } else {
            if (anError != NULL) {
                *anError = [KCSErrorUtilities createError:@{NSURLErrorFailingURLStringErrorKey : _userData[NSURLErrorFailingURLStringErrorKey]}  description:parser.error errorCode:KCSInvalidJSONFormatError domain:KCSNetworkErrorDomain requestId:self.requestId];
            }
        }
    } else {
        jsonData = [jsonResponse valueForKey:@"result"];
        jsonData = jsonData ? jsonData : jsonResponse;
    }
    
    if (self.responseCode >= 400 && [jsonData isKindOfClass:[NSDictionary class]] && self.userData != nil && self.userData[NSURLErrorFailingURLStringErrorKey] != nil) {
        jsonData = [jsonData mutableCopy];
        ((NSMutableDictionary*)jsonData)[NSURLErrorFailingURLStringErrorKey] = self.userData[NSURLErrorFailingURLStringErrorKey];
    }
    
    return jsonData;
}

- (id) jsonResponseValue
{
    NSString* cytpe = [_responseHeaders valueForKey:@"Content-Type"];
    
    if (cytpe == nil || [cytpe containsStringCaseInsensitive:@"json"]) {
        return [self jsonResponseValue:nil];
    } else {
        if (_responseData.length == 0) {
            return @{};
        } else {
            KCSLogWarning(@"not a json repsonse");
            return @{@"debug" : [self stringValue]};
        }
    }
}

- (NSString*) requestId
{
    return [self.responseHeaders objectForKey:@"X-Kinvey-Request-Id"];
}

#pragma mark - debug
- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"%@ code: %ld", [super debugDescription], (long)_responseCode];
}

@end
