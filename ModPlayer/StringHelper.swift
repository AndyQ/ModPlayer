//
//  StringHelper.swift
//  ModPlayer
//
//  Created by Andy Qua on 13/11/2019.
//  Copyright © 2019 Andy Qua. All rights reserved.
//

import Foundation

extension String {
    var utf8CString: UnsafeMutablePointer<Int8> {
        return UnsafeMutablePointer<Int8>(mutating:(self as NSString).utf8String!)
    }
}

func tupleToArray<Tuple, Value>(tuple:Tuple) -> [Value] {
    let reflect = Mirror(reflecting: tuple)
    let arr = reflect.children.compactMap { $0.value as? Value}
    return arr
}

func int8TupleToString<T>(tuple:T) -> String {
    let arr : [UInt8] = [Int8](tupleToArray(tuple: tuple)).map { UInt8($0) }
    let str = String(cString:arr)
    return str
}

func md5UInt8ToString<T>(tuple:T) -> String {
    let arr : [UInt8] = tupleToArray(tuple: tuple)
    let hexArr = arr.map { String(format:"%02x", $0 ) }

    if hexArr.count == 16 {
        return hexArr.reduce("") { $0 + $1 }
    }
    return ""

}


