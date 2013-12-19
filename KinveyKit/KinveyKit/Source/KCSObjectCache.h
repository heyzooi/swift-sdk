//
//  KCSObjectCache.h
//  KinveyKit
//
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


#import <Foundation/Foundation.h>

@class KCSQuery2;
@class KCSDataModel;
@protocol KCSPersistable;
@protocol KCSOfflineUpdateDelegate;
@protocol KCSUser2;

@interface KCSObjectCache : NSObject

@property (nonatomic, strong) KCSDataModel* dataModel;

@property (atomic) BOOL preCalculatesResults;
@property (atomic) BOOL updatesLocalWithUnconfirmedSaves;
@property (atomic) BOOL offlineUpdateEnabled;

- (void) setOfflineUpdateDelegate:(id<KCSOfflineUpdateDelegate>)offlineUpdateDelegate;

- (NSArray*) pullQuery:(KCSQuery2*)query route:(NSString*)route collection:(NSString*)collection;
- (NSArray*) pullIds:(NSArray*)ids route:(NSString*)route collection:(NSString*)collection;
- (NSArray*) setObjects:(NSArray*)objArray forQuery:(KCSQuery2*)query route:(NSString*)route collection:(NSString*)collection;
- (BOOL) removeQuery:(KCSQuery2*)query route:(NSString*)route collection:(NSString*)collection;

- (void) addObjects:(NSArray*)objects route:(NSString*)route  collection:(NSString*)collection;
- (void) updateObject:(id<KCSPersistable>)object route:(NSString*)route collection:(NSString*)collection;
- (void) updateCacheForObject:(NSString*)objId withEntity:(NSDictionary*)entity atRoute:(NSString*)route collection:(NSString*)collection;

- (void) deleteObject:(NSString*)objId route:(NSString*)route collection:(NSString*)collection;
- (void) deleteObjects:(NSArray*)ids route:(NSString*)route collection:(NSString*)collection;

- (NSString*) addUnsavedObject:(id<KCSPersistable>)object entity:(NSDictionary*)entity route:(NSString*)route collection:(NSString*)collection method:(NSString*)method headers:(NSDictionary*)headers error:(NSError*)error;
- (NSString*) addUnsavedDelete:(NSString*)objId route:(NSString*)route collection:(NSString*)collection method:(NSString*)method headers:(NSDictionary*)headers error:(NSError*)error;
- (id) addUnsavedDeleteQuery:(KCSQuery2*)deleteQuery route:(NSString*)route collection:(NSString*)collection method:(NSString*)method headers:(NSDictionary*)headers error:(NSError*)error;

- (void)jsonImport:(NSArray*)entities route:(NSString*)route collection:(NSString*)collection;
- (NSArray*)jsonExport:(NSString*)route collection:(NSString*)collection;

//metadata
- (void) cacheActiveUser:(id<KCSUser2>)user;
- (id<KCSUser2>) lastActiveUser;


//destructive
- (void) clear;
@end