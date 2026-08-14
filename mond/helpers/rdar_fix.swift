//
//  rdar_fix.swift
//  mond
//
//  Fixes rdar:45025538 by patching IOMobileGraphicsFamily.plist
//  to match the spoofed ArtworkDeviceSubType.
//

import Foundation

enum RDFixError: Error, LocalizedError {
    case failedToGrantAccess
    case failedToReadPlist
    case failedToWritePlist
    
    var errorDescription: String? {
        switch self {
        case .failedToGrantAccess: return "Failed to get sandbox access to IOMobileGraphicsFamily.plist"
        case .failedToReadPlist: return "Failed to read IOMobileGraphicsFamily.plist"
        case .failedToWritePlist: return "Failed to write IOMobileGraphicsFamily.plist"
        }
    }
}

class RDFix {
    static let plistPath = "/var/mobile/Library/Preferences/com.apple.iokit.IOMobileGraphicsFamily.plist"
    static let backupPath = "/var/mobile/Library/Preferences/com.apple.iokit.IOMobileGraphicsFamily.plist.bak"
    
    /// Canvas dimensions for each ArtworkDeviceSubType
    static let canvasForSubtype: [Int: (width: Int, height: Int)] = [
        2436: (1125, 2436),  // iPhone X / iPhone X Gestures
        2556: (1179, 2556),  // iPhone 14 Pro
        2796: (1290, 2796),  // iPhone 14 Pro Max
        2976: (1290, 2796),  // iPhone 15 Pro Max (approx)
        2622: (1206, 2622),  // iPhone 16 Pro
        2868: (1320, 2868),  // iPhone 16 Pro Max
        2736: (1206, 2736),  // iPhone Air
    ]
    
    /// Patch IOMobileGraphicsFamily.plist to match the given ArtworkDeviceSubType
    static func patch(subtype: Int) throws {
        guard let canvas = canvasForSubtype[subtype] else {
            print("(rdar_fix) no canvas mapping for subtype \(subtype), skipping")
            return
        }
        
        // 1. Get sandbox access to the plist
        var path_c = plistPath.utf8CString.map { Int8($0) }
        let handle = path_c.withUnsafeMutableBufferPointer { ptr in
            bad_query(ptr.baseAddress, true, nil, false, nil)
        }
        
        guard handle >= 0 else {
            print("(rdar_fix) failed to grant access: \(handle)")
            throw RDFixError.failedToGrantAccess
        }
        
        print("(rdar_fix) granted access to IOMobileGraphicsFamily.plist")
        
        // 2. Backup original file
        let plistURL = URL(fileURLWithPath: plistPath)
        let backupURL = URL(fileURLWithPath: backupPath)
        
        if !FileManager.default.fileExists(atPath: backupPath) {
            try? FileManager.default.copyItem(at: plistURL, to: backupURL)
            print("(rdar_fix) created backup at \(backupPath)")
        }
        
        // 3. Read plist
        guard let dict = NSMutableDictionary(contentsOf: plistURL) else {
            print("(rdar_fix) failed to read plist")
            throw RDFixError.failedToReadPlist
        }
        
        // 4. Update canvas values
        dict["canvas_width"] = canvas.width
        dict["canvas_height"] = canvas.height
        
        print("(rdar_fix) setting canvas_width=\(canvas.width), canvas_height=\(canvas.height)")
        
        // 5. Write back
        guard dict.write(to: plistURL, atomically: true) else {
            print("(rdar_fix) failed to write plist")
            throw RDFixError.failedToWritePlist
        }
        
        print("(rdar_fix) successfully patched IOMobileGraphicsFamily.plist")
    }
    
    /// Restore original IOMobileGraphicsFamily.plist from backup
    static func restore() throws {
        var path_c = plistPath.utf8CString.map { Int8($0) }
        let handle = path_c.withUnsafeMutableBufferPointer { ptr in
            bad_query(ptr.baseAddress, true, nil, false, nil)
        }
        
        guard handle >= 0 else {
            print("(rdar_fix) failed to grant access for restore: \(handle)")
            throw RDFixError.failedToGrantAccess
        }
        
        let plistURL = URL(fileURLWithPath: plistPath)
        let backupURL = URL(fileURLWithPath: backupPath)
        
        if FileManager.default.fileExists(atPath: backupPath) {
            try FileManager.default.removeItem(at: plistURL)
            try FileManager.default.copyItem(at: backupURL, to: plistURL)
            print("(rdar_fix) restored IOMobileGraphicsFamily.plist from backup")
        } else {
            print("(rdar_fix) no backup found, nothing to restore")
        }
    }
}