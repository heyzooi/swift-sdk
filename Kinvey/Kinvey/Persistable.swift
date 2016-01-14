//
//  Persistable.swift
//  Kinvey
//
//  Created by Victor Barros on 2015-12-08.
//  Copyright © 2015 Kinvey. All rights reserved.
//

import Foundation
import KinveyKit
import CoreData

public protocol Persistable: JsonObject {
    
    static func kinveyCollectionName() -> String
    static func kinveyPropertyMapping() -> [String : String]
    
}

extension Persistable {
    
    public static var idKey: String {
        get {
            let idKey = kinveyPropertyMapping()
                .filter { keyValuePair in keyValuePair.1 == PersistableIdKey }
                .reduce(PersistableIdKey) { (_, keyValuePair) in keyValuePair.0 }
            return idKey
        }
    }
    
    public static var aclKey: String? {
        get {
            let filtered = kinveyPropertyMapping()
                .filter { keyValuePair in keyValuePair.1 == PersistableAclKey }
            if filtered.count > 0 {
                let idKey = filtered.reduce(PersistableAclKey) { (_, keyValuePair) in keyValuePair.0 }
                return idKey
            }
            return nil
        }
    }
    
    public var kinveyObjectId: String? {
        get {
            if let persistable = self as? AnyObject,
                let id = persistable.valueForKey(self.dynamicType.idKey) as? String
            {
                return id
            }
            return nil
        }
        set {
            if let persistable = self as? AnyObject {
                persistable.setValue(newValue, forKey: self.dynamicType.idKey)
            }
        }
    }
    
    public var kinveyAcl: Acl? {
        get {
            if let persistable = self as? AnyObject,
                let aclKey = self.dynamicType.aclKey,
                let acl = persistable.valueForKey(aclKey) as? Acl
            {
                return acl
            }
            return nil
        }
        set {
            if let persistable = self as? AnyObject, let aclKey = self.dynamicType.aclKey {
                persistable.setValue(newValue, forKey: aclKey)
            }
        }
    }
    
    subscript(key: String) -> AnyObject? {
        get {
            if let obj = self as? NSObject {
                return obj.valueForKey(key)
            }
            return nil
        }
        set {
            if let obj = self as? NSObject {
                obj.setValue(newValue, forKey: key)
            }
        }
    }
    
    public func toJson() -> [String : AnyObject] {
        var json: [String : AnyObject] = [:]
        if let obj = self as? NSObject {
            let propertyMap = self.dynamicType.kinveyPropertyMapping()
            for keyValuePair in propertyMap {
                if let value = obj.valueForKey(keyValuePair.0) {
                    json[keyValuePair.1] = value
                }
            }
        }
        return json
    }
    
    public func loadFromJson(json: [String : AnyObject]) {
        if let obj = self as? NSObject {
            let propertyMap = self.dynamicType.kinveyPropertyMapping()
            for keyValuePair in propertyMap {
                if let value = json[keyValuePair.1] {
                    obj.setValue(value, forKey: keyValuePair.0)
                }
            }
        }
    }
    
}
