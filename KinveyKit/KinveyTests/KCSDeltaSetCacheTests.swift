//
//  KCSDeltaSetCacheTests.swift
//  KinveyKit
//
//  Created by Victor Barros on 2015-09-21.
//  Copyright © 2015 Kinvey. All rights reserved.
//

import UIKit

class KCSDeltaSetCacheTests: KCSTestCase {
    
    var collection: KCSCollection!
    var store: KCSBackgroundAppdataStore!
    var storeNoCache: KCSBackgroundAppdataStore!
    var query: KCSQuery!
    
    let timeout = NSTimeInterval(60 * 5)
    
    static var token: dispatch_once_t = 0
    
    override func setUp() {
        super.setUp()
        
        setupKCS()
        createAutogeneratedUser()
        
        query = KCSQuery(onField: "_acl.creator", withExactMatchForValue: KCSUser.activeUser())
        
        collection = KCSCollection(fromString: "city", ofClass: City.self)
        store = KCSBackgroundAppdataStore(
            collection: collection,
            options: [
                KCSStoreKeyCachePolicy: KCSCachePolicy.NetworkFirst.rawValue,
            ]
        )
        store.incrementalCache = .Enabled
        
        storeNoCache = KCSBackgroundAppdataStore(
            collection: collection,
            options: [
                KCSStoreKeyCachePolicy: KCSCachePolicy.None.rawValue,
            ]
        )
        
        dispatch_once(&KCSDeltaSetCacheTests.token) {
            var cities: [City] = []
            for _ in 1...10 {
                cities.append(City(name: "Boston"))
            }
            do {
                weak var expectationSave = self.expectationWithDescription("save")
                
                self.storeNoCache.saveObject(
                    cities,
                    withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                        XCTAssertNotNil(results)
                        XCTAssertNil(error)
                        
                        expectationSave?.fulfill()
                    },
                    withProgressBlock: nil
                )
                
                self.waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                    expectationSave = nil
                }
            }
        }
    }
    
    func removeAndLogoutActiveUser() {
        if let user = KCSUser.activeUser() {
            weak var expectationRemove = expectationWithDescription("remove")
            
            user.removeWithCompletionBlock({ (results: [AnyObject]!, error: NSError!) -> Void in
                expectationRemove?.fulfill()
            })
            
            waitForExpectationsWithTimeout(timeout) { (error: NSError?) -> Void in
                expectationRemove = nil
            }
            
            user.logout()
        }
    }
    
    override func tearDown() {
        removeAndLogoutActiveUser()
        
        super.tearDown()
    }
    
    func testMeasureQuery() {
        measureBlock { () -> Void in
            weak var expectationQuery = self.expectationWithDescription("query")
            
            self.store.queryWithQuery(
                self.query,
                withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                    XCTAssertNotNil(results)
                    XCTAssertNil(error)
                    
                    expectationQuery?.fulfill()
                },
                withProgressBlock: nil
            )
            
            self.waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                expectationQuery = nil
            }
        }
    }
    
    func testNoDeltaChanges() {
        var count = 0
        do {
            weak var expectationQuery = self.expectationWithDescription("query")
            
            store.queryWithQuery(
                query,
                withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                    XCTAssertNotNil(results)
                    XCTAssertNil(error)
                    
                    count += results.count
                    
                    expectationQuery?.fulfill()
                },
                withProgressBlock: nil
            )
            
            self.waitForExpectationsWithTimeout(timeout) { (error: NSError?) -> Void in
                expectationQuery = nil
            }
        }
        
        KCSObjectCache.setDeltaCacheBlock({ (delta: [NSObject : AnyObject]!, deletes: [NSObject : AnyObject]!, time: NSTimeInterval) -> Void in
            XCTAssertEqual(0, delta.count)
            XCTAssertEqual(0, deletes.count)
        })
        measureBlock { () -> Void in
            weak var expectationQuery2 = self.expectationWithDescription("query2")
            
            self.store.queryWithQuery(
                self.query,
                withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                    XCTAssertNotNil(results)
                    XCTAssertNil(error)
                    
                    if let results = results {
                        XCTAssertEqual(count, results.count)
                    }
                    
                    expectationQuery2?.fulfill()
                },
                withProgressBlock: nil
            )
            
            self.waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                expectationQuery2 = nil
            }
        }
    }
    
    func testDeltaCreate1NewRecord() {
        var count = 0
        do {
            weak var expectationQuery = self.expectationWithDescription("query")
            
            store.queryWithQuery(
                query,
                withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                    XCTAssertNotNil(results)
                    XCTAssertNil(error)
                    
                    count += results.count
                    
                    expectationQuery?.fulfill()
                },
                withProgressBlock: nil
            )
            
            self.waitForExpectationsWithTimeout(timeout) { (error: NSError?) -> Void in
                expectationQuery = nil
            }
        }
        
        KCSObjectCache.setDeltaCacheBlock({ (delta: [NSObject : AnyObject]!, deletes: [NSObject : AnyObject]!, time: NSTimeInterval) -> Void in
            XCTAssertEqual(1, delta.count)
            XCTAssertEqual(0, deletes.count)
        })
        measureBlock { () -> Void in
            do {
                weak var expectationSave = self.expectationWithDescription("save")
                
                let city = City(name: "Cambridge")
                self.storeNoCache.saveObject(
                    city,
                    withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                        XCTAssertNotNil(results)
                        XCTAssertNil(error)
                        
                        count += results.count
                        
                        expectationSave?.fulfill()
                    },
                    withProgressBlock: nil
                )
                
                self.waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                    expectationSave = nil
                }
            }
            
            weak var expectationQuery2 = self.expectationWithDescription("query2")
            
            self.store.queryWithQuery(
                self.query,
                withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                    XCTAssertNotNil(results)
                    XCTAssertNil(error)
                    
                    if let results = results {
                        XCTAssertEqual(count, results.count)
                    }
                    
                    expectationQuery2?.fulfill()
                },
                withProgressBlock: nil
            )
            
            self.waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                expectationQuery2 = nil
            }
        }
    }
    
    func testDeltaDelete1Record() {
        var cities: [City] = []
        for _ in 1...10 {
            weak var expectationSave = self.expectationWithDescription("save")
            
            let city = City(name: "Cambridge")
            self.storeNoCache.saveObject(
                city,
                withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                    XCTAssertNotNil(results)
                    XCTAssertNil(error)
                    
                    if let results = results {
                        XCTAssertEqual(1, results.count)
                        if let city = results.first {
                            cities.append(city as! City)
                        }
                    }
                    
                    expectationSave?.fulfill()
                },
                withProgressBlock: nil
            )
            
            self.waitForExpectationsWithTimeout(timeout) { (error: NSError?) -> Void in
                expectationSave = nil
            }
        }
        
        var count = 0
        
        do {
            weak var expectationQuery = self.expectationWithDescription("query")
            
            store.queryWithQuery(
                query,
                withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                    XCTAssertNotNil(results)
                    XCTAssertNil(error)
                    
                    count += results.count
                    
                    expectationQuery?.fulfill()
                },
                withProgressBlock: nil
            )
            
            self.waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                expectationQuery = nil
            }
        }
        
        var cityCount = 0
        KCSObjectCache.setDeltaCacheBlock({ (delta: [NSObject : AnyObject]!, deletes: [NSObject : AnyObject]!, time: NSTimeInterval) -> Void in
            XCTAssertEqual(0, delta.count)
            XCTAssertEqual(1, deletes.count)
        })
        measureBlock { () -> Void in
            do {
                weak var expectationDelete = self.expectationWithDescription("delete")
                
                self.storeNoCache.removeObject(
                    cities[cityCount++],
                    withCompletionBlock: { (_count: UInt, error: NSError!) -> Void in
                        XCTAssertEqual(1, _count)
                        XCTAssertNil(error)
                        
                        count -= Int(_count)
                        
                        expectationDelete?.fulfill()
                    },
                    withProgressBlock: nil
                )
                
                self.waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                    expectationDelete = nil
                }
            }
            
            weak var expectationQuery2 = self.expectationWithDescription("query2")
            
            self.store.queryWithQuery(
                self.query,
                withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                    XCTAssertNotNil(results)
                    XCTAssertNil(error)
                    
                    if let results = results {
                        XCTAssertEqual(count, results.count)
                    }
                    
                    expectationQuery2?.fulfill()
                },
                withProgressBlock: nil
            )
            
            self.waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                expectationQuery2 = nil
            }
        }
    }
    
    func testDeltaUpdate1Record() {
        weak var expectationSave = self.expectationWithDescription("save")
        
        var city = City(name: "Cambridge")
        storeNoCache.saveObject(
            city,
            withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                XCTAssertNotNil(results)
                XCTAssertNil(error)
                
                city = results.first as! City
                
                expectationSave?.fulfill()
            },
            withProgressBlock: nil
        )
        
        self.waitForExpectationsWithTimeout(timeout) { (error: NSError?) -> Void in
            expectationSave = nil
        }
        
        var count = 0
        
        do {
            weak var expectationQuery = self.expectationWithDescription("query")
            
            store.queryWithQuery(
                query,
                withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                    XCTAssertNotNil(results)
                    XCTAssertNil(error)
                    
                    count += results.count
                    
                    expectationQuery?.fulfill()
                },
                withProgressBlock: nil
            )
            
            self.waitForExpectationsWithTimeout(timeout) { (error: NSError?) -> Void in
                expectationQuery = nil
            }
        }
        
        KCSObjectCache.setDeltaCacheBlock({ (delta: [NSObject : AnyObject]!, deletes: [NSObject : AnyObject]!, time: NSTimeInterval) -> Void in
            XCTAssertEqual(1, delta.count)
            XCTAssertEqual(0, deletes.count)
        })
        measureBlock { () -> Void in
            do {
                weak var expectationUpdate = self.expectationWithDescription("update")
                
                city.name = "Newport"
                self.storeNoCache.saveObject(
                    city,
                    withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                        XCTAssertNotNil(results)
                        XCTAssertNil(error)
                        
                        expectationUpdate?.fulfill()
                    },
                    withProgressBlock: nil
                )
                
                self.waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                    expectationUpdate = nil
                }
            }
            
            weak var expectationQuery2 = self.expectationWithDescription("query2")
            
            self.store.queryWithQuery(
                self.query,
                withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                    XCTAssertNotNil(results)
                    XCTAssertNil(error)
                    
                    if let results = results {
                        XCTAssertEqual(count, results.count)
                    }
                    
                    expectationQuery2?.fulfill()
                },
                withProgressBlock: nil
            )
            
            self.waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                expectationQuery2 = nil
            }
        }
    }
    
    func testDeltaCreateUpdateDelete1Record() {
        var cities: [City] = []
        for _ in 1...10 {
            weak var expectationSave = self.expectationWithDescription("save")
            
            let city = City(name: "Cambridge")
            self.storeNoCache.saveObject(
                city,
                withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                    XCTAssertNotNil(results)
                    XCTAssertNil(error)
                    
                    cities.append(results.first as! City)
                    
                    expectationSave?.fulfill()
                },
                withProgressBlock: nil
            )
            
            self.waitForExpectationsWithTimeout(timeout) { (error: NSError?) -> Void in
                expectationSave = nil
            }
        }
        
        weak var expectationSave = self.expectationWithDescription("save")
        
        var city = City(name: "Cambridge")
        storeNoCache.saveObject(
            city,
            withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                XCTAssertNotNil(results)
                XCTAssertNil(error)
                
                city = results.first as! City
                
                expectationSave?.fulfill()
            },
            withProgressBlock: nil
        )
        
        self.waitForExpectationsWithTimeout(timeout) { (error: NSError?) -> Void in
            expectationSave = nil
        }
        
        var count = 0
        
        do {
            weak var expectationQuery = self.expectationWithDescription("query")
            
            store.queryWithQuery(
                query,
                withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                    XCTAssertNotNil(results)
                    XCTAssertNil(error)
                    
                    count += results.count
                    
                    expectationQuery?.fulfill()
                },
                withProgressBlock: nil
            )
            
            self.waitForExpectationsWithTimeout(timeout) { (error: NSError?) -> Void in
                expectationQuery = nil
            }
        }
        
        var citiesCount = 0
        KCSObjectCache.setDeltaCacheBlock({ (delta: [NSObject : AnyObject]!, deletes: [NSObject : AnyObject]!, time: NSTimeInterval) -> Void in
            XCTAssertEqual(2, delta.count)
            XCTAssertEqual(1, deletes.count)
        })
        measureBlock { () -> Void in
            do {
                weak var expectationSave = self.expectationWithDescription("save")
                
                let city = City(name: "Cambridge")
                self.storeNoCache.saveObject(
                    city,
                    withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                        XCTAssertNotNil(results)
                        XCTAssertNil(error)
                        
                        if let results = results {
                            XCTAssertEqual(1, results.count)
                        }
                        
                        count += results.count
                        
                        expectationSave?.fulfill()
                    },
                    withProgressBlock: nil
                )
                
                self.waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                    expectationSave = nil
                }
            }
            
            do {
                weak var expectationUpdate = self.expectationWithDescription("update")
                
                city.name = "Newport"
                self.storeNoCache.saveObject(
                    city,
                    withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                        XCTAssertNotNil(results)
                        XCTAssertNil(error)
                        
                        if let results = results {
                            XCTAssertEqual(1, results.count)
                        }
                        
                        expectationUpdate?.fulfill()
                    },
                    withProgressBlock: nil
                )
                
                self.waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                    expectationUpdate = nil
                }
            }
            
            do {
                weak var expectationDelete = self.expectationWithDescription("delete")
                
                self.storeNoCache.removeObject(
                    cities[citiesCount++],
                    withCompletionBlock: { (_count: UInt, error: NSError!) -> Void in
                        XCTAssertEqual(1, _count)
                        XCTAssertNil(error)
                        
                        count -= Int(_count)
                        
                        expectationDelete?.fulfill()
                    },
                    withProgressBlock: nil
                )
                
                self.waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                    expectationDelete = nil
                }
            }
            
            weak var expectationQuery2 = self.expectationWithDescription("query2")
            
            self.store.queryWithQuery(
                self.query,
                withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                    XCTAssertNotNil(results)
                    XCTAssertNil(error)
                    
                    if let results = results {
                        XCTAssertEqual(count, results.count)
                    }
                    
                    expectationQuery2?.fulfill()
                },
                withProgressBlock: nil
            )
            
            self.waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                expectationQuery2 = nil
            }
        }
    }
    
    func testDeltaDelete1000Record() {
        let collectionName = "persons"
        importPersons(collectionName)
        let originalNumber = 5000
        let deleteNumber = 1000
        
        deltaDelete(collectionName, originalNumber: originalNumber, deleteNumber: deleteNumber)
    }
    
    func testDeltaDelete4000Record() {
        let collectionName = "persons"
        importPersons(collectionName)
        let originalNumber = 5000
        let deleteNumber = 4000
        
        deltaDelete(collectionName, originalNumber: originalNumber, deleteNumber: deleteNumber)
    }
    
    func deltaDelete(collectionName: String, originalNumber: Int, deleteNumber: Int) {
        let collection = KCSCollection(fromString: collectionName, ofClass: NSDictionary.self)
        let store = KCSBackgroundAppdataStore(
            collection: collection,
            options: [
                KCSStoreKeyCachePolicy: KCSCachePolicy.NetworkFirst.rawValue,
            ]
        )
        store.incrementalCache = .Enabled
        
        let storeNoCache = KCSBackgroundAppdataStore(
            collection: collection,
            options: [
                KCSStoreKeyCachePolicy: KCSCachePolicy.None.rawValue,
            ]
        )
        
        let query = KCSQuery()
        
        do {
            let start = NSDate()
            var wait = true
            while (wait && NSDate().timeIntervalSinceDate(start) < 60 * 5) {
                weak var expectationCount = expectationWithDescription("count")
                
                store.countWithBlock({ (count: UInt, error: NSError!) -> Void in
                    wait = Int(count) < originalNumber
                    
                    expectationCount?.fulfill()
                })
                
                waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                    expectationCount = nil
                }
            }
            
            XCTAssertFalse(wait)
        }
        
        var results: [AnyObject]? = nil
        do {
            weak var expectationQuery = expectationWithDescription("query")
            
            store.queryWithQuery(
                query,
                withCompletionBlock: { (_results: [AnyObject]!, error: NSError!) -> Void in
                    results = _results
                    
                    XCTAssertNotNil(results)
                    XCTAssertNil(error)
                    
                    if let results = results {
                        XCTAssertEqual(originalNumber, results.count)
                    }
                    
                    expectationQuery?.fulfill()
                },
                withProgressBlock: nil
            )
            
            waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                expectationQuery = nil
            }
        }
        
        XCTAssertNotNil(results)
        
        if let results = results {
            XCTAssertTrue(results.count > 0)
            
            guard results.count > 0 else {
                return
            }
            
            for (var i = 0; i < deleteNumber;) {
                weak var expectationDelete = expectationWithDescription("delete")
                
                let deletes = Array(results[i..<Int(i+deleteNumber)])
                storeNoCache.removeObject(
                    deletes,
                    withCompletionBlock: { (count: UInt, error: NSError!) -> Void in
                        XCTAssertEqual(deleteNumber, Int(count))
                        XCTAssertNil(error)
                        
                        i += Int(count)
                        
                        expectationDelete?.fulfill()
                    },
                    withProgressBlock: nil
                )
                
                waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                    expectationDelete = nil
                }
            }
        }
        
        KCSObjectCache.setDeltaCacheBlock({ (delta: [NSObject : AnyObject]!, deletes: [NSObject : AnyObject]!, time: NSTimeInterval) -> Void in
            XCTAssertEqual(0, delta.count)
            XCTAssertEqual(deleteNumber, deletes.count)
        })
        do {
            weak var expectationQuery2 = expectationWithDescription("query2")
            
            store.queryWithQuery(
                query,
                withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                    XCTAssertNotNil(results)
                    XCTAssertNil(error)
                    
                    if let results = results {
                        XCTAssertEqual(originalNumber - deleteNumber, results.count)
                    }
                    
                    expectationQuery2?.fulfill()
                },
                withProgressBlock: nil
            )
            
            waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                expectationQuery2 = nil
            }
        }
    }
    
    func testDeltaUpdate1000Record() {
        KCSClient.sharedClient().clearCache()
        
        let collectionName = "persons"
//        importPersons(collectionName)
        let originalNumber = 5000
        let updateNumber = 1000
        
        deltaUpdate(collectionName, originalNumber: originalNumber, updateNumber: updateNumber)
    }
    
    func testDeltaUpdate4000Record() {
        KCSClient.sharedClient().clearCache()
        
        let collectionName = "persons"
//        importPersons(collectionName)
        let originalNumber = 5000
        let updateNumber = 4000
        
        deltaUpdate(collectionName, originalNumber: originalNumber, updateNumber: updateNumber)
    }
    
    func deltaUpdate(collectionName: String, originalNumber: Int, updateNumber: Int) {
        let collection = KCSCollection(fromString: collectionName, ofClass: NSDictionary.self)
        let store = KCSBackgroundAppdataStore(
            collection: collection,
            options: [
                KCSStoreKeyCachePolicy: KCSCachePolicy.NetworkFirst.rawValue,
            ]
        )
        store.incrementalCache = .Enabled
        
        let storeNoCache = KCSBackgroundAppdataStore(
            collection: collection,
            options: [
                KCSStoreKeyCachePolicy: KCSCachePolicy.None.rawValue,
            ]
        )
        
        let query = KCSQuery()
        
        do {
            let start = NSDate()
            var wait = true
            while (wait && NSDate().timeIntervalSinceDate(start) < 60 * 5) {
                weak var expectationCount = expectationWithDescription("count")
                
                store.countWithBlock({ (count: UInt, error: NSError!) -> Void in
                    wait = Int(count) < originalNumber
                    
                    expectationCount?.fulfill()
                })
                
                waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                    expectationCount = nil
                }
            }
            
            XCTAssertFalse(wait)
        }
        
        var results: [AnyObject]? = nil
        do {
            weak var expectationQuery = expectationWithDescription("query")
            
            store.queryWithQuery(
                query,
                withCompletionBlock: { (_results: [AnyObject]!, error: NSError!) -> Void in
                    results = _results
                    
                    XCTAssertNotNil(results)
                    XCTAssertNil(error)
                    
                    if let results = results {
                        XCTAssertEqual(originalNumber, results.count)
                    }
                    
                    expectationQuery?.fulfill()
                },
                withProgressBlock: nil
            )
            
            waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                expectationQuery = nil
            }
        }
        
        XCTAssertNotNil(results)
        
        if let results = results {
            XCTAssertTrue(results.count > 0)
            
            guard results.count > 0 else {
                return
            }
            
            let chunckSize = 200
            for (var i = 0; i < updateNumber;) {
                weak var expectationSave = expectationWithDescription("save")
                
                let slice = Array(results[i..<i+chunckSize])
                var updates = slice as! [[String : AnyObject]]
                for index in 0..<updates.count {
                    updates[index]["age"] = 0
                }
                storeNoCache.saveObject(
                    updates,
                    withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                        XCTAssertNotNil(results)
                        XCTAssertNil(error)
                        
                        if let results = results {
                            XCTAssertEqual(chunckSize, results.count)
                        }
                        
                        i += chunckSize
                        
                        expectationSave?.fulfill()
                    },
                    withProgressBlock: nil
                )
                
                waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                    expectationSave = nil
                }
            }
        }
        
        KCSObjectCache.setDeltaCacheBlock({ (delta: [NSObject : AnyObject]!, deletes: [NSObject : AnyObject]!, time: NSTimeInterval) -> Void in
            XCTAssertEqual(updateNumber, delta.count)
            XCTAssertEqual(0, deletes.count)
        })
        do {
            weak var expectationQuery2 = expectationWithDescription("query2")
            
            store.queryWithQuery(
                query,
                withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                    XCTAssertNotNil(results)
                    XCTAssertNil(error)
                    
                    if let results = results {
                        XCTAssertEqual(originalNumber, results.count)
                    }
                    
                    expectationQuery2?.fulfill()
                },
                withProgressBlock: nil
            )
            
            waitForExpectationsWithTimeout(self.timeout) { (error: NSError?) -> Void in
                expectationQuery2 = nil
            }
        }
    }
    
    func importPersons(collectionName: String) {
        let manageAPI = KCSManageAPI(kid: KCSClient.sharedClient().appKey)
        let baasAPI = KCSBaasAPI(kid: KCSClient.sharedClient().appKey, appSecret: KCSClient.sharedClient().appSecret, masterSecret: masterSecret)
        
        do {
            weak var expectationClear = expectationWithDescription("clear")
            
            baasAPI.clearCollection(
                collectionName,
                completionBlock: { (response: NSURLResponse?, json: [String : AnyObject]?, error: NSError?) -> Void in
                    XCTAssertNotNil(response)
                    XCTAssertNotNil(json)
                    XCTAssertNil(error)
                    
                    if let json = json {
                        XCTAssertNotNil(json["count"])
                        if let count = json["count"] {
                            XCTAssertEqual(1, count as? NSNumber)
                        }
                    }
                    
                    expectationClear?.fulfill()
                }
            )
            
            waitForExpectationsWithTimeout(timeout) { (error: NSError?) -> Void in
                expectationClear = nil
            }
        }
        
        do {
            weak var expectationLogin = expectationWithDescription("login")
            
            manageAPI.loginWithEmail(
                "victor@kinvey.com",
                password: "avT-UDD-aTS-6JT",
                completionBlock: { (response: NSURLResponse?, json: [String : AnyObject]?, error: NSError?) -> Void in
                    XCTAssertNotNil(response)
                    XCTAssertNotNil(json)
                    XCTAssertNil(error)
                    
                    expectationLogin?.fulfill()
                }
            )
            
            waitForExpectationsWithTimeout(timeout) { (error: NSError?) -> Void in
                expectationLogin = nil
            }
        }
        
        XCTAssertNotNil(manageAPI.token)
        
        if manageAPI.token != nil {
            weak var expectationImport = expectationWithDescription("import")
            
            let timeout = NSTimeInterval(60 * 5)
            
            let fileURL = NSBundle(forClass: KCSDeltaSetCacheTests.self).URLForResource("persons", withExtension: "csv")!
            manageAPI.importData(
                collectionName,
                fileURL: fileURL,
                timeout: timeout,
                completionBlock: { (response: NSURLResponse?, json: [String : AnyObject]?, error: NSError?) -> Void in
                    if let response = response {
                        if response.isKindOfClass(NSHTTPURLResponse.self) {
                            let httpResponse = response as! NSHTTPURLResponse
                            if 200 <= httpResponse.statusCode && httpResponse.statusCode < 300 {
                                NSLog("Import in progress or done!")
                            }
                        }
                    }
                    
                    expectationImport?.fulfill()
                }
            )
            
            waitForExpectationsWithTimeout(timeout) { (error: NSError?) -> Void in
                expectationImport = nil
            }
        }
    }
    
}
