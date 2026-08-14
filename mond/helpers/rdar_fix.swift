//
//  rdar_fix.swift
//  mond
//
//  Fixes rdar:45025538 by patching IOMobileGraphicsFamily.plist
//

import Foundation

enum RDFixError: Error, LocalizedError {
    case failedToGrantAccess
    case failedToReadPlist
    case failedToWritePlist
    
    var errorDescription: String? {
        switch self {
        case .failedToGrantAccess: return "Failed to get sandbox access"
        case .failedToReadPlist: return "Failed to read plist"
        case .failedToWritePlist: return "Failed to write plist"
        }
    }
}

class RDFix {
    static let paths = [
        "/var/mobile/Library/Preferences/com.apple.iokit.IOMobileGraphicsFamily.plist",
        "/private/var/mobile/Library/Preferences/com.apple.iokit.IOMobileGraphicsFamily.plist"
    ]
    
    static let canvasForSubtype: [Int: (width: Int, height: Int)] = [
        2436: (1125, 2436),
        2556: (1179, 2556),
        2796: (1290, 2796),
        2976: (1290, 2796),
        2622: (1206, 2622),
        2868: (1320, 2868),
        2736: (1206, 2736),
    ]
    
    static func patch(subtype: Int) throws {
        guard let canvas = canvasForSubtype[subtype] else {
            print("(rdar_fix) no canvas mapping for subtype \(subtype)")
            return
        }
        
        print("(rdar_fix) starting patch for subtype \(subtype), canvas \(canvas.width)x\(canvas.height)")
        
        var patchedPath: String? = nil
        
        for path in paths {
            print("(rdar_fix) trying path: \(path)")
            
            var path_c = path.utf8CString.map { Int8($0) }
            let handle = path_c.withUnsafeMutableBufferPointer { ptr in
                bad_query(ptr.baseAddress, true, nil, false, nil)
            }
            
            print("(rdar_fix) bad_query returned: \(handle)")
            
            if handle >= 0 {
                patchedPath = path
                break
            }
        }
        
        guard let plistPath = patchedPath else {
            print("(rdar_fix) ERROR: failed to grant access to any path")
            throw RDFixError.failedToGrantAccess
        }
        
        let plistURL = URL(fileURLWithPath: plistPath)
        let backupPath = plistPath + ".bak"
        let backupURL = URL(fileURLWithPath: backupPath)
        
        // Backup
        if !FileManager.default.fileExists(atPath: backupPath) {
            try? FileManager.default.copyItem(at: plistURL, to: backupURL)
            print("(rdar_fix) backup created")
        }
        
        // Read
        guard let dict = NSMutableDictionary(contentsOf: plistURL) else {
            print("(rdar_fix) ERROR: failed to read plist")
            throw RDFixError.failedToReadPlist
        }
        
        print("(rdar_fix) current canvas_width=\(dict["canvas_width"] ?? "?"), canvas_height=\(dict["canvas_height"] ?? "?")")
        
        // Update
        dict["canvas_width"] = canvas.width
        dict["canvas_height"] = canvas.height
        
        // Write - try multiple methods
        var written = false
        
        // Method 1: NSMutableDictionary.write
        if dict.write(to: plistURL, atomically: true) {
            print("(rdar_fix) Method 1 (NSMutableDictionary.write) succeeded")
            written = true
        } else {
            print("(rdar_fix) Method 1 failed, trying Method 2")
            
            // Method 2: Data.write
            if let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0) {
                do {
                    try data.write(to: plistURL, options: .atomic)
                    print("(rdar_fix) Method 2 (Data.write) succeeded")
                    written = true
                } catch {
                    print("(rdar_fix) Method 2 failed: \(error)")
                }
            }
        }
        
        if !written {
            print("(rdar_fix) ERROR: all write methods failed")
            throw RDFixError.failedToWritePlist
        }
        
        print("(rdar_fix) SUCCESS: patched \(plistPath)")
        print("(rdar_fix) REBOOT required for IOMobileGraphicsFamily to take effect!")
    }
    
    static func restore() throws {
        for path in paths {
            let backupPath = path + ".bak"
            
            var path_c = path.utf8CString.map { Int8($0) }
            let handle = path_c.withUnsafeMutableBufferPointer { ptr in
                bad_query(ptr.baseAddress, true, nil, false, nil)
            }
            
            guard handle >= 0 else { continue }
            
            let plistURL = URL(fileURLWithPath: path)
            let backupURL = URL(fileURLWithPath: backupPath)
            
            if FileManager.default.fileExists(atPath: backupPath) {
                try? FileManager.default.removeItem(at: plistURL)
                try? FileManager.default.copyItem(at: backupURL, to: plistURL)
                print("(rdar_fix) restored from backup")
            }
            return
        }
        print("(rdar_fix) restore: no accessible path found")
    }
}