//
//  diagnostics.swift
//  mond
//
//  Диагностика твиков и проверка совместимости
//

import Foundation
import UIKit

enum TweakStatus {
    case working
    case requiresSpoof
    case incompatible
    case unknown
}

class Diagnostics {
    
    /// Проверяет совместимость твиков с текущим устройством
    static func checkTweakCompatibility() -> [String: TweakStatus] {
        var results: [String: TweakStatus] = [:]
        
        let machine = machine_name()
        let iosVersion = doubleSystemVersion()
        
        // Charge Limit требует spoof на 15 Pro+ для работы на старых устройствах
        let chargeLimitDevices = ["iPhone15,2", "iPhone15,3", "iPhone16,1", "iPhone16,2", "iPhone17,1", "iPhone17,2"]
        if !chargeLimitDevices.contains(machine) {
            results["Charge Limit"] = .requiresSpoof
        } else {
            results["Charge Limit"] = .working
        }
        
        // Apple Intelligence работает только на 15 Pro+ или с spoof
        if iosVersion >= 18.1 {
            let aiDevices = ["iPhone15,2", "iPhone15,3", "iPhone16,1", "iPhone16,2", "iPhone17,1", "iPhone17,2", "iPhone18,1", "iPhone18,2", "iPhone18,3", "iPhone18,4"]
            if !aiDevices.contains(machine) {
                results["Apple Intelligence"] = .requiresSpoof
            } else {
                results["Apple Intelligence"] = .working
            }
        }
        
        // Visual Intelligence требует iOS 18.0+ и Camera Control
        if iosVersion >= 18.0 {
            let viDevices = ["iPhone17,1", "iPhone17,2", "iPhone18,1", "iPhone18,2", "iPhone18,3", "iPhone18,4"]
            if !viDevices.contains(machine) {
                results["Visual Intelligence"] = .requiresSpoof
            } else {
                results["Visual Intelligence"] = .working
            }
        } else {
            results["Visual Intelligence"] = .incompatible
        }
        
        return results
    }
    
    /// Генерирует отчёт о текущем состоянии
    static func generateReport() -> String {
        let machine = machine_name()
        let iosVersion = UIDevice.current.systemVersion
        let compatibility = checkTweakCompatibility()
        
        var report = """
        mond Diagnostics Report
        ======================
        Device: \(machine)
        iOS: \(iosVersion)
        
        Tweak Compatibility:
        """
        
        for (tweak, status) in compatibility {
            let statusText: String
            switch status {
            case .working: statusText = "✓ Working"
            case .requiresSpoof: statusText = "⚠ Requires Device Spoof"
            case .incompatible: statusText = "✗ Incompatible"
            case .unknown: statusText = "? Unknown"
            }
            report += "\n- \(tweak): \(statusText)"
        }
        
        return report
    }
    
    /// Проверяет все ли необходимые keys установлены
    static func verifyTweakKeys(requiredKeys: [String], in dict: NSMutableDictionary) -> [String] {
        var missing: [String] = []
        
        guard let cacheExtra = dict["CacheExtra"] as? NSMutableDictionary else {
            return requiredKeys
        }
        
        for key in requiredKeys {
            if cacheExtra[key] == nil {
                missing.append(key)
            }
        }
        
        return missing
    }
}