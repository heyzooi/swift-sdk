//
//  KCSUser2.m
//  KinveyKit
//
//  Created by Michael Katz on 12/10/13.
//  Copyright (c) 2013 Kinvey. All rights reserved.
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

#import "KCSUser2.h"

#import "KCSHiddenMethods.h"
#import "KinveyCollection.h"
#import "KinveyUser.h"

#import "KinveyCoreInternal.h"
#import "KinveyDataStoreInternal.h"
#import "KinveyUserService.h"

#define KCSUserAttributeOAuthTokens @"_oauth"


@interface KCSUser2()
@property (nonatomic, strong) NSMutableDictionary *userAttributes;
@end

@implementation KCSUser2

- (instancetype) init
{
    self = [super init];
    if (self){
        _username = @"";
        _userId = @"";
        _userAttributes = [NSMutableDictionary dictionary];
    }
    return self;
}


+ (NSDictionary *)kinveyObjectBuilderOptions
{
    static NSDictionary *options = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        options = @{KCS_USE_DICTIONARY_KEY : @(YES),
                    KCS_DICTIONARY_NAME_KEY : @"userAttributes"};
    });
    
    return options;
}

- (NSDictionary *)hostToKinveyPropertyMapping
{
    static NSDictionary *mappedDict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mappedDict = @{@"userId" : KCSEntityKeyId,
                       //                       @"push" : @"_push",
                       @"username" : KCSUserAttributeUsername,
                       @"email" : KCSUserAttributeEmail,
                       @"givenName" : KCSUserAttributeGivenname,
                       @"surname" : KCSUserAttributeSurname,
                       @"metadata" : KCSEntityKeyMetadata,
//                       @"oauthTokens" : KCSUserAttributeOAuthTokens,
                       };
    });
    
    return mappedDict;
}

#warning FIx THESE:

- (NSString *)authString
{
    NSString* token = [KCSKeychain2 kinveyTokenForUserId:self.userId];
    NSString *authString = nil;
    if (token) {
        authString = [@"Kinvey " stringByAppendingString: token];
        KCSLogInfo(KCS_LOG_CONTEXT_USER, @"Current user found, using sessionauth (%@) => XXXXXXXXX", self.username);
    } else {
        KCSLogError(KCS_LOG_CONTEXT_USER, @"No session auth for current user found (%@)", self.username);
    }
    return authString;
}

- (void)handleErrorResponse:(KCSNetworkResponse *)response
{
    NSString* errorCode = [response jsonObject][@"error"];
    if (response.code == KCSDeniedError) {
        BOOL shouldLogout = NO;
        if ([errorCode isEqualToString:@"UserLockedDown"]) {
            shouldLogout = YES;
        } else if ([errorCode isEqualToString:@"InvalidCredentials"] && KCSConfigValueBOOL(KCS_KEEP_USER_LOGGED_IN_ON_BAD_CREDENTIALS) == NO) {
            shouldLogout = YES;
        }
        if (shouldLogout) {
            [self logout];
        }
    }
}

#pragma mark - KinveyKit1 compatability

- (void) refreshFromServer:(KCSCompletionBlock)completionBlock
{
    [KCSUser2 refreshUser:(id)self options:nil completion:^(id<KCSUser2> user, NSError *error) {
        completionBlock(user?@[user]:nil, error);
    }];
}

- (void) saveWithCompletionBlock:(KCSCompletionBlock)completionBlock
{
    [KCSUser2 saveUser:(id)self options:nil completion:^(id<KCSUser2> user, NSError *error) {
        completionBlock(user?@[user]:nil, error);
    }];
}

- (void) removeWithCompletionBlock:(KCSCompletionBlock)completionBlock
{
    [KCSUser2 deleteUser:(id)self options:nil completion:^(unsigned long count, NSError *errorOrNil) {
        completionBlock(@[],errorOrNil);
    }];
}


- (void) logout
{
    [KCSUser2 logoutUser:self];
}

@end