//
//  String.swift
//  Kinvey
//
//  Created by Victor Barros on 2016-03-01.
//  Copyright © 2016 Kinvey. All rights reserved.
//

import Foundation

extension String {
    
    func toDate() -> Date? {
        switch self.characters.count {
            case 20:
                return NSDate2StringValueTransformer.rfc3339DateFormatter.date(from: self)
            case 24:
                return NSDate2StringValueTransformer.rfc3339MilliSecondsDateFormatter.date(from: self)
            default:
                return nil
        }
    }
    
    func substring(with rangeInt: Range<Int>) -> String {
        let startIndex = index(self.startIndex, offsetBy: rangeInt.lowerBound)
        let endIndex = index(self.startIndex, offsetBy: rangeInt.upperBound)
        return self[startIndex..<endIndex]
    }
    
}

extension NSString {
    
    func toDate() -> Date? {
        return (self as String).toDate()
    }
    
}
