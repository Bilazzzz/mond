//
//  utils.swift
//  mond
//
//  Created by ruter on 18.07.26.
//

import SwiftUI
import Darwin
import UIKit
import WebKit
import Combine

func is_debugged() -> Bool {
    var info = kinfo_proc()
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    var size = MemoryLayout<kinfo_proc>.stride

    let rc = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
    if rc != 0 { return false }

    let P_TRACED: Int32 = 0x00000800
    return (info.kp_proc.p_flag & P_TRACED) != 0
}

func is_supported() -> Bool {
    let v = ProcessInfo.processInfo.operatingSystemVersion

    return v.majorVersion == 27 &&
           v.minorVersion == 0 &&
           v.patchVersion == 0
}

func hasHomeButton() -> Bool {
    let windows = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }

    return (windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 0) == 0
}

enum AppPaths {
    static var backups: String {
        let url = backupsURL
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        return url.path
    }

    private static var backupsURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return baseURL.appendingPathComponent("backups", isDirectory: true)
    }
}

enum TweakPaths {
    static var gestalt = "/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
    static var gestalt_dir = "/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/"
}

// respring.swift: easy respring on all iOS versions (probably).
// Web approach developed by @neonmodder123, implemented in Swift here by @skadz108.
// 4/9/26, https://jailbreak.party

let respringDocument = """
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<style>
body { background: black; margin: 0; padding: 0; }
</style>
</head>
<body>
<script>
(function() {
    var container = document.createElement('div');
    container.style.cssText = 'perspective: 1px; perspective-origin: 9999999% 9999999%;';
    
    var el = document.createElement('div');
    el.style.cssText = 'transform: translateZ(9999999px); width: 1px; height: 1px;';
    
    container.appendChild(el);
    document.body.appendChild(container);
    
    setTimeout(function() {
        document.body.removeChild(container);
        location.reload();
    }, 300);
})();
</script>
</body>
</html>
"""

struct RespringView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(respringDocument, baseURL: nil)
    }
}

final class AppState: ObservableObject {
    @Published var show_respring = false
    @Published var exploit_succeeded = false
    @Published var poster_files: [URL] = []
    @Published var exploit_already_granted = false

    func respring() {
        show_respring = true
    }

    func append_poster_file(_ url: URL) {
        guard is_pb_archive(url) else {
            print("(pb) ignoring unsupported file: \(url.lastPathComponent)")
            return
        }

        if poster_files.contains(url) {
            return
        }

        _ = url.startAccessingSecurityScopedResource()
        poster_files.append(url)
        print("(pb) added file: \(url.lastPathComponent)")
    }

    func remove_poster_files(at offsets: IndexSet) {
        for index in offsets {
            poster_files[index].stopAccessingSecurityScopedResource()
        }

        poster_files.remove(atOffsets: offsets)
    }

    func clear_pb_files() {
        for url in poster_files {
            url.stopAccessingSecurityScopedResource()
        }

        poster_files.removeAll()
    }
}

func is_pb_archive(_ url: URL) -> Bool {
    switch url.pathExtension.lowercased() {
    case "tendies", "zip":
        return true
    default:
        return false
    }
}