//
//  mg.swift
//  mond
//
//  Created by ruter on 16.07.26.
//

import Foundation
import Darwin
import MachO
import UIKit

var _cache_data_offsets: [String: Int] = [:]

func cache_data_offset(_ key: String) -> Int {
    if let cached = _cache_data_offsets[key] {
        return cached
    }

    let lib_mg = "/usr/lib/libMobileGestalt.dylib"
    dlopen(lib_mg, RTLD_GLOBAL)

    var header: UnsafePointer<mach_header_64>?
    for i in 0..<_dyld_image_count() {
        if String(cString: _dyld_get_image_name(i)) == lib_mg {
            header = unsafeBitCast(_dyld_get_image_header(i), to: UnsafePointer<mach_header_64>.self)
            break
        }
    }
    guard let header else { return 0 }

    var text_size: UInt = 0
    guard let cstring = getsectiondata(header, "__TEXT", "__cstring", &text_size) else { return 0 }
    let cstr = cstring.withMemoryRebound(to: CChar.self, capacity: Int(text_size)) { $0 }

    var key_ptr = cstr
    while Int(key_ptr - cstr) < Int(text_size) {
        if String(cString: key_ptr) == key { break }
        key_ptr += strlen(key_ptr) + 1
    }

    var const_size: UInt = 0
    var ptr = getsectiondata(header, "__AUTH_CONST", "__const", &const_size)?.withMemoryRebound(to: UInt.self, capacity: Int(const_size) / 8) { $0 }
    if ptr == nil {
        ptr = getsectiondata(header, "__DATA_CONST", "__const", &const_size)?.withMemoryRebound(to: UInt.self, capacity: Int(const_size) / 8) { $0 }
    }

    guard let ptr else { return 0 }
    let uint_count = Int(const_size) / MemoryLayout<UInt>.stride
    for i in 0..<uint_count {
        if ptr[i] == UInt(bitPattern: key_ptr) {
            // Verify we don't read past the end of the __const section
            // Reading UInt16 at byte offset 0x9a from ptr.advanced(by: i) requires 0x9a + 2 bytes available
            let byte_offset = i * MemoryLayout<UInt>.stride + 0x9a
            guard byte_offset + MemoryLayout<UInt16>.stride <= Int(const_size) else {
                _cache_data_offsets[key] = 0
                return 0
            }
            
            let offset = Int((ptr.advanced(by: i).withMemoryRebound(to: UInt16.self, capacity: 1) { $0[0x9a / 2] }) << 3)
            _cache_data_offsets[key] = offset
            return offset
        }
    }

    _cache_data_offsets[key] = 0
    return 0
}