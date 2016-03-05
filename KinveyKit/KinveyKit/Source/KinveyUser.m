//
//  KinveyUser.m
//  KinveyKit
//
//  Created by Brian Wilson on 12/1/11.
//  Copyright (c) 2011-2015 Kinvey. All rights reserved.
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

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"

#import "KinveyUser.h"
#import "KCSLogManager.h"
#import "KCSHiddenMethods.h"
#import "KinveyErrorCodes.h"
#import "KinveyUserService.h"
#import "KCSKeychain.h"
#import "KCSNetworkResponse.h"
#import "KCSPush.h"
#import "KinveyUser+Private.h"
#import "KCSMICLoginViewController.h"
#import "KCSUser2+KinveyUserService+Private.h"
#import "KCSClient+Private.h"
#import <Kinvey/Kinvey-Swift.h>
#import "KNVClient.h"

#pragma mark - Constants

NSString* const KCSUsername = @"username";
NSString* const KCSPassword = @"password";

NSString* const KCSUserAccessTokenKey = @"access_token";
NSString* const KCSUserAccessTokenSecretKey = @"access_token_secret";
NSString* const KCSUserAccessRefreshTokenKey = @"refresh_token";
NSString* const KCSUserAccessExpiresInKey = @"expires_in";

NSString* const KCSActiveUserChangedNotification = @"Kinvey.ActiveUser.Changed";

NSString* const KCSUserAttributeUsername = @"username";
NSString* const KCSUserAttributeSurname = @"last_name";
NSString* const KCSUserAttributeGivenname = @"first_name";
NSString* const KCSUserAttributeEmail = @"email";
NSString* const KCSUserAttributeSocialIdentity = @"_socialIdentity";
NSString* const KCSUserAttributeFacebookId = @"_socialIdentity.facebook.id";

#pragma mark - defines & functions

#define kDeviceTokensKey @"_devicetokens"

void setActive(KCSUser* user)
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    [KCSClient sharedClient].currentUser = user;
#pragma clang diagnostic pop
}

@interface KCSUser()

@property (nonatomic, strong) NSMutableDictionary* push;

@end

@implementation KCSUser

- (instancetype) init
{
    self = [super init];
    if (self){
        _username = nil;
        _password = nil;
        _userId = nil;
        _userAttributes = [NSMutableDictionary dictionary];
        _sessionAuth = nil;
        _surname = nil;
        _email = nil;
        _givenName = nil;
        _push = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (BOOL) hasSavedCredentials
{
    return [KCSUser2 hasSavedCredentials];
}

+ (void) clearSavedCredentials
{
    [KCSUser2 clearSavedCredentials];
}

-(KCSRequest*)refreshFromServer:(KCSCompletionBlock)completionBlock
{
    SWITCH_TO_MAIN_THREAD_COMPLETION_BLOCK(completionBlock);
    return [KCSUser2 refreshUser:(id)self options:nil completion:^(id<KCSUser2> user, NSError *error) {
        completionBlock(user?@[user]:nil, error);
    }];
}

#pragma mark - Create new Users
+(KCSRequest*)createAutogeneratedUser:(NSDictionary *)fieldsAndValues
                           completion:(KCSUserCompletionBlock)completionBlock
{
    SWITCH_TO_MAIN_THREAD_USER_BLOCK(completionBlock);
    return [KCSUser2 createAutogeneratedUser:fieldsAndValues completion:^(id<KCSUser2> user, NSError *error) {
        completionBlock(user, error, KCSUserNoInformation);
    }];
}

+(KCSRequest*)createAutogeneratedUser:(KCSUserCompletionBlock)completionBlock
{
    SWITCH_TO_MAIN_THREAD_USER_BLOCK(completionBlock);
    return [self createAutogeneratedUser:nil completion:completionBlock];
}

+(KCSRequest*)userWithUsername:(NSString *)username
                      password:(NSString *)password
               fieldsAndValues:(NSDictionary*)fieldsAndValues
           withCompletionBlock:(KCSUserCompletionBlock)completionBlock
{
    SWITCH_TO_MAIN_THREAD_USER_BLOCK(completionBlock);
    return [KCSUser2 createUserWithUsername:username password:password fieldsAndValues:fieldsAndValues completion:^(id<KCSUser2> user, NSError *error) {
        completionBlock(user, error, KCSUserNoInformation);
    }];
}

+(KCSRequest*)userWithUsername:(NSString *)username
                      password:(NSString *)password
           withCompletionBlock:(KCSUserCompletionBlock)completionBlock
{
    SWITCH_TO_MAIN_THREAD_USER_BLOCK(completionBlock);
    return [self userWithUsername:username
                         password:password
                  fieldsAndValues:nil
              withCompletionBlock:completionBlock];
}

# pragma mark - Init from credentials
+ (KCSUser *)initAndActivateWithSavedCredentials
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    KCSUser* clientActiveUser = [KCSClient sharedClient].currentUser;
#pragma clang diagnostic pop
    
    if (clientActiveUser != nil) {
        [[NSException exceptionWithName:NSInternalInconsistencyException reason:@"Attempting to init active user but there is already an active user" userInfo:nil] raise];
    }
    if ([KCSUser hasSavedCredentials] == YES) {
        KCSUser *createdUser = [[KCSAppdataStore caches] lastActiveUser];
        setActive(createdUser);
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated" 
    return [KCSClient sharedClient].currentUser;
#pragma clang diagnostic pop
}

- (void)initializeCurrentUser
{
    [KCSUser activeUser];
}

#pragma mark - Login

+(KCSRequest*)loginWithUsername: (NSString *)username
                       password: (NSString *)password
            withCompletionBlock:(KCSUserCompletionBlock)completionBlock
{
    SWITCH_TO_MAIN_THREAD_USER_BLOCK(completionBlock);
    return [KCSUser2 loginWithUsername:username password:password completion:^(id<KCSUser2> user, NSError *error) {
        completionBlock(user, error, KCSUserNoInformation);
    }];
}

+(KCSRequest*)loginWithSocialIdentity:(KCSUserSocialIdentifyProvider)provider
                     accessDictionary:(NSDictionary*)accessDictionary
                  withCompletionBlock:(KCSUserCompletionBlock)completionBlock;
{
    SWITCH_TO_MAIN_THREAD_USER_BLOCK(completionBlock);
    return [KCSUser2 connectWithAuthProvider:provider accessDictionary:accessDictionary completion:^(id<KCSUser2> user, NSError *error) {
        completionBlock(user, error, KCSUserNoInformation);
    }];
}

+(void)loginWithAuthorizationCodeLoginPage:(NSString *)redirectURI
{
    [KCSUser2 loginWithAuthorizationCodeLoginPage:redirectURI];
}

+(KCSRequest*)loginWithAuthorizationCodeAPI:(NSString *)redirectURI
                                    options:(NSDictionary *)options
                        withCompletionBlock:(KCSUserCompletionBlock)completionBlock
{
    SWITCH_TO_MAIN_THREAD_USER_BLOCK(completionBlock);
    return [KCSUser2 loginWithAuthorizationCodeAPI:redirectURI
                                           options:options
                                        completion:^(id<KCSUser2> user, NSError *error)
    {
        if (completionBlock) {
            completionBlock(user, error, KCSUserNoInformation);
        }
    }];
}

+(NSURL *)URLforLoginWithMICRedirectURI:(NSString *)redirectURI
{
    return [KCSUser2 URLforLoginWithMICRedirectURI:redirectURI];
}

+(NSURL *)URLforLoginWithMICRedirectURI:(NSString *)redirectURI
                                 client:(KNVClient*)client
{
    return [KCSUser2 URLforLoginWithMICRedirectURI:redirectURI
                                            client:client];
}

+(void)presentMICLoginViewControllerWithRedirectURI:(NSString*)redirectURI
                                withCompletionBlock:(KCSUserCompletionBlock)completionBlock
{
    SWITCH_TO_MAIN_THREAD_USER_BLOCK(completionBlock);
    KCSMICLoginViewController* micVC = [[KCSMICLoginViewController alloc] initWithRedirectURI:redirectURI
                                                                          withCompletionBlock:completionBlock];
    [self presentMICLoginViewController:micVC];
}

+(void)presentMICLoginViewControllerWithRedirectURI:(NSString*)redirectURI
                                            timeout:(NSTimeInterval)timeout
                                withCompletionBlock:(KCSUserCompletionBlock)completionBlock
{
    SWITCH_TO_MAIN_THREAD_USER_BLOCK(completionBlock);
    KCSMICLoginViewController* micVC = [[KCSMICLoginViewController alloc] initWithRedirectURI:redirectURI
                                                                                      timeout:timeout
                                                                          withCompletionBlock:completionBlock];
    [self presentMICLoginViewController:micVC];
}

+(void)presentMICLoginViewController:(KCSMICLoginViewController*)micVC
{
    UINavigationController* navigationVC = [[UINavigationController alloc] initWithRootViewController:micVC];
    
    UIViewController* viewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (viewController.presentedViewController) {
        viewController = viewController.presentedViewController;
    }
    [viewController presentViewController:navigationVC
                                 animated:YES
                               completion:nil];
}

+(BOOL)isValidMICRedirectURI:(NSString *)redirectURI
                      forURL:(NSURL *)url
{
    return [KCSUser2 isValidMICRedirectURI:redirectURI
                                    forURL:url];
}

+(void)parseMICRedirectURI:(NSString *)redirectURI
                    forURL:(NSURL *)url
       withCompletionBlock:(KCSUserCompletionBlock)completionBlock
{
    [self parseMICRedirectURI:redirectURI
                       forURL:url
                       client:[KCSClient sharedClient].client
          withCompletionBlock:completionBlock];
}

+(void)parseMICRedirectURI:(NSString *)redirectURI
                    forURL:(NSURL *)url
                    client:(KNVClient*)client
       withCompletionBlock:(KCSUserCompletionBlock)completionBlock
{
    SWITCH_TO_MAIN_THREAD_USER_BLOCK(completionBlock);
    [KCSUser2 parseMICRedirectURI:redirectURI
                           forURL:url
                           client:client
              withCompletionBlock:^(id<KCSUser2> user, NSError *error)
    {
        if (completionBlock) {
            completionBlock(user, error, KCSUserNoInformation);
        }
    }];
}

+(void)setMICApiVersion:(NSString *)micApiVersion
{
    [KCSUser2 setMICApiVersion:micApiVersion];
}

+(NSString *)micApiVersion
{
    return [KCSUser2 micApiVersion];
}

- (void)logout
{
    if (![self isEqual:[KCSUser activeUser]]){
        KCSLogError(@"Attempted to log out a user who is not the KCS Current User!");
    } else {
        self.username = nil;
        self.userId = nil;
        
        // Extract all of the items from the Array into a set, so adding the "new" device token does
        // the right thing.  This might be less efficient than just iterating, but these routines have
        // been optimized, we do this now, since there's no other place guarenteed to merge.
        // Login/create store this info
        [[KCSPush sharedPush] setDeviceToken:nil];
        
        [KCSUser clearSavedCredentials];
        [[KCSAppdataStore caches] clear];
        [KCSFileStore clearCachedFiles];
        
        // Set the currentUser to nil
        setActive(nil);
    }
}

-(KCSRequest*)removeWithCompletionBlock:(KCSCompletionBlock)completionBlock
{
    SWITCH_TO_MAIN_THREAD_COMPLETION_BLOCK(completionBlock);
    return [KCSUser2 deleteUser:(id)self
                        options:nil
                     completion:^(unsigned long count, NSError *errorOrNil)
    {
        completionBlock(@[],errorOrNil);
    }];
}

-(KCSRequest*)saveWithCompletionBlock:(KCSCompletionBlock)completionBlock
{
    SWITCH_TO_MAIN_THREAD_COMPLETION_BLOCK(completionBlock);
    return [KCSUser2 saveUser:(id)self
                      options:nil
                   completion:^(id<KCSUser2> user, NSError *error)
    {
        completionBlock(user?@[user]:nil, error);
    }];
}

- (id)getValueForAttribute: (NSString *)attribute
{
    // These hard-coded attributes are for legacy usage of the library
    if ([attribute isEqualToString:@"username"]){
        return self.username;
    } else if ([attribute isEqualToString:@"_id"]){
        return self.userId;
    } else {
        return [self.userAttributes objectForKey:attribute];
    }
}

- (void)setValue: (id)value forAttribute: (NSString *)attribute
{
    // These hard-coded attributes are for legacy usage of the library
    if ([attribute isEqualToString:@"username"]){
        self.username = (NSString *)value;
    } else if ([attribute isEqualToString:@"_id"]){
        self.userId = (NSString *)value;
    } else {
        [self.userAttributes setObject:value forKey:attribute];
    }
}

- (void) removeValueForAttribute:(NSString*)attribute
{
    if (![self.userAttributes objectForKey:attribute]) {
        KCSLogWarning(@"trying to remove attribute '%@'. This attribute does not exist for the user.", attribute);
    }
    [self.userAttributes removeObjectForKey:attribute];
}

- (void)setPassword:(NSString *)password
{
    DBAssert(password == nil, @"should not be setting password");
    _password = password;
}

#pragma mark - Kinvey Entity

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
                      @"push" : @"_push",
                      @"username" : KCSUserAttributeUsername,
                      @"email" : KCSUserAttributeEmail,
                      @"givenName" : KCSUserAttributeGivenname,
                      @"surname" : KCSUserAttributeSurname,
                      @"socialIdentity": KCSUserAttributeSocialIdentity,
                      @"metadata" : KCSEntityKeyMetadata
        };
    });
    
    return mappedDict;
}

- (NSString*) debugDescription
{
    NSMutableDictionary* attrs = [NSMutableDictionary dictionaryWithDictionary:_userAttributes];
    [attrs addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:self.username, @"username", self.email, @"email", self.givenName, @"given name", self.surname, @"surname", self.userId, @"userId", nil]];
    return [NSString stringWithFormat:@"%@: %@",[super debugDescription], attrs];
}

#pragma mark - Password

+(KCSRequest*)sendPasswordResetForUser:(NSString*)usernameOrEmail
                   withCompletionBlock:(KCSUserSendEmailBlock)completionBlock
{
    SWITCH_TO_MAIN_THREAD_USER_SEND_EMAIL_BLOCK(completionBlock);
    return [KCSUser2 sendPasswordResetForUsername:usernameOrEmail
                                       completion:completionBlock];
}

+(KCSRequest*)sendEmailConfirmationForUser:(NSString*)username
                       withCompletionBlock:(KCSUserSendEmailBlock)completionBlock
{
    SWITCH_TO_MAIN_THREAD_USER_SEND_EMAIL_BLOCK(completionBlock);
    return [KCSUser2 sendEmailConfirmationForUser:username
                                       completion:completionBlock];
}

+(KCSRequest*)sendForgotUsername:(NSString*)email
             withCompletionBlock:(KCSUserSendEmailBlock)completionBlock
{
    SWITCH_TO_MAIN_THREAD_USER_SEND_EMAIL_BLOCK(completionBlock);
    return [KCSUser2 sendForgotUsernameEmail:email
                                  completion:completionBlock];
}

+(KCSRequest*)checkUsername:(NSString*)potentialUsername
        withCompletionBlock:(KCSUserCheckUsernameBlock)completionBlock
{
    SWITCH_TO_MAIN_THREAD_USER_CHECK_USERNAME_BLOCK(completionBlock);
    return [KCSUser2 checkUsername:potentialUsername
                        completion:completionBlock];
}


#pragma mark - properties
+ (KCSUser *)activeUser
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    KCSUser* user = [KCSClient sharedClient].currentUser;
#pragma clang diagnostic pop
    if (!user) {
        user = [self initAndActivateWithSavedCredentials];
    }
    return user;
}

-(void)setPush:(NSMutableDictionary *)push
{
    @synchronized(self) {
        if (![push isKindOfClass:[NSMutableDictionary class]]) {
            push = push.mutableCopy;
        }
        _push = push;
    }
}

- (NSMutableSet*) deviceTokens
{
    @synchronized(self) {
        if (_push == nil) {
            self.push = [NSMutableDictionary dictionary];
        } else if (![_push isKindOfClass:[NSMutableDictionary class]]) {
            self.push = _push.mutableCopy;
        }
        if (_push[kDeviceTokensKey] == nil) {
            _push[kDeviceTokensKey] = [NSMutableSet set];
        } else if ([_push[kDeviceTokensKey] isKindOfClass:[NSArray class]]) {
            _push[kDeviceTokensKey] = [NSMutableSet setWithArray:_push[kDeviceTokensKey]];
        } else if ([_push[kDeviceTokensKey] isKindOfClass:[NSDictionary class]] &&
                   ![_push[kDeviceTokensKey] isKindOfClass:[NSMutableDictionary class]])
        {
            _push[kDeviceTokensKey] = ((NSDictionary*) _push[kDeviceTokensKey]).mutableCopy;
        }
        return _push[kDeviceTokensKey];
    }
}

-(KCSRequest*)changePassword:(NSString*)newPassword
             completionBlock:(KCSCompletionBlock)completionBlock
{
    SWITCH_TO_MAIN_THREAD_COMPLETION_BLOCK(completionBlock);
    return [KCSUser2 changePasswordForUser:(id)self
                                  password:newPassword
                                completion:^(id<KCSUser2> user, NSError *error)
    {
        NSArray* objs = user ? @[user] : @[];
        completionBlock(objs, error);
    }];
}

- (NSString *)authString
{
    if (!self.userId) {
        [[NSException exceptionWithName:NSInternalInconsistencyException reason:@"Active user does not have an `id` set." userInfo:@{@"user":self}] raise];
    }
    NSString* token = [KCSKeychain2 kinveyTokenForUserId:self.userId];
    NSString *authString = @"";
    if (token) {
        authString = [@"Kinvey " stringByAppendingString: token];
        KCSLogDebug(@"Current user found, using sessionauth (%@) => XXXXXXXXX", self.username);
    } else {
        KCSLogError(@"No session auth for current user found (%@)", self.username);
    }
    return authString;
}

- (NSString *)sessionAuth
{
    return [self authString];
}

- (void)handleErrorResponse:(KCSNetworkResponse *)response
{
    NSError* error = nil;
    NSDictionary* jsonObj = [response jsonObjectError:&error];
    if (!error && jsonObj != nil && [jsonObj isKindOfClass:[NSDictionary class]]) {
        NSString* errorCode = jsonObj[@"error"];
        if (response.code == KCSDeniedError) {
            BOOL shouldLogout = NO;
            if ([errorCode isEqualToString:@"UserLockedDown"]) {
                shouldLogout = YES;
            } else if ([errorCode isEqualToString:@"InvalidCredentials"] && [[KCSClient sharedClient].configuration.options[KCS_KEEP_USER_LOGGED_IN_ON_BAD_CREDENTIALS] boolValue] == NO) {
                shouldLogout = YES;
            }
            if (shouldLogout) {
                [self logout];
            }
        }
    }
}

#pragma mark - 
- (BOOL)isEqual:(id)object
{
    return [[object class] isEqual:[self class]] && [self.userId isEqualToString:[object userId]];
}

- (NSUInteger)hash
{
    return [self.userId hash];
}

@end

#pragma clang diagnostic pop
