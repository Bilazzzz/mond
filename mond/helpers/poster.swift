//
//  poster.swift
//  mond
//
//  Created by ruter on 11.08.26.
//

import Foundation
import ZIPFoundation

enum pb_error: LocalizedError {
    case container_404
    case not_zip(URL)
    case no_descriptors(URL)

    nonisolated var errorDescription: String? {
        switch self {
        case .container_404:
            return "could not find the pb container."
        case .not_zip(let url):
            return "\(url.lastPathComponent) is not a valid tendies/zip archive."
        case .no_descriptors(let url):
            return "no descriptors found in \(url.lastPathComponent)."
        }
    }
}

enum pb {
    static let pb_bid = "com.apple.PosterBoard"
    static let collections_ext = "com.apple.WallpaperKit.CollectionsPoster"
    static let photos_ext = "com.apple.PhotosUIPrivate.PhotosPosterProvider"
    static let ext_version = "61"
    static let container_root = "/var/mobile/Containers/Data/Application"

    static func find_pb_container() throws -> URL {
        for child in list_containers(container_root) {
            let child_url = URL(fileURLWithPath: child, isDirectory: true)

            let hidden = child_url.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            if let id = read_meta_key(at: hidden, key: "MCMMetadataIdentifier"), id == pb_bid {
                return child_url
            }

            let plain = child_url.appendingPathComponent("com.apple.mobile_container_manager.metadata.plist")
            if let id = read_meta_key(at: plain, key: "MCMMetadataIdentifier"), id == pb_bid {
                return child_url
            }
        }

        throw pb_error.container_404
    }

    private static func read_meta_key(at url: URL, key: String) -> String? {
        var path_c = url.path.utf8CString.map { Int8($0) }
        let handle = bad_query(&path_c, true, nil, false, nil)
        guard handle >= 0 else { return nil }
        defer { bad_query_release(handle) }

        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }

        return plist[key] as? String
    }
    
    static func poster_extensions_root(container: URL) -> URL {
        container
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("PRBPosterExtensionDataStore")
            .appendingPathComponent(ext_version)
            .appendingPathComponent("Extensions")
    }

    static func descriptors_url(container: URL, ext: String) -> URL {
        poster_extensions_root(container: container)
            .appendingPathComponent(ext)
            .appendingPathComponent("descriptors")
    }

    static func apply(at urls: [URL]) throws -> Int {
        let container = try find_pb_container()
        var written = 0
        
        for url in urls {
            let unzip_dir = try unzip(url)
            defer { try? fm.removeItem(at: unzip_dir) }

            let descriptors = try find_descriptors(in: unzip_dir)
            guard !descriptors.isEmpty else { throw pb_error.no_descriptors(url) }

            for (ext, folders) in descriptors {
                for folder in folders {
                    guard folder.lastPathComponent != "__MACOSX" else { continue }
                    randomize_id(in: folder)
                    try write_descriptor(at: folder, container: container, ext: ext)
                    written += 1
                }
            }
        }
        
        return written
    }

    static func reset() throws {
        let container = try find_pb_container()
        let root = poster_extensions_root(container: container)

        guard fm.fileExists(atPath: root.path) else { return }

        for ext in (try? fm.contentsOfDirectory(atPath: root.path)) ?? [] {
            let desc_path = root.appendingPathComponent(ext).appendingPathComponent("descriptors")
            guard fm.fileExists(atPath: desc_path.path) else { continue }

            for item in (try? fm.contentsOfDirectory(atPath: desc_path.path)) ?? [] {
                try? fm.removeItem(at: desc_path.appendingPathComponent(item))
            }
        }
    }

    private static func unzip(_ url: URL) throws -> URL {
        guard let data = try? Data(contentsOf: url), data.count >= 4, data[0] == 0x50, data[1] == 0x4B else {
            throw pb_error.not_zip(url)
        }
        
        let dest = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        try fm.unzipItem(at: url, to: dest)
        
        return dest
    }

    private static func find_descriptors(in root: URL) throws -> [String: [URL]] {
        var result: [String: [URL]] = [:]

        if let container = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            .first(where: { $0.lastPathComponent.lowercased() == "container" }) {
            let ext_dir = poster_extensions_root(container: container)
            
            if fm.fileExists(atPath: ext_dir.path) {
                for ext in try fm.contentsOfDirectory(at: ext_dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                    let d = ext.appendingPathComponent("descriptors")
                    if fm.fileExists(atPath: d.path) {
                        for child in try fm.contentsOfDirectory(at: d, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                            guard child.lastPathComponent != "__MACOSX" else { continue }
                            result[ext.lastPathComponent, default: []].append(child)
                        }
                    }
                }
                
                return result
            }
        }

        if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let dir as URL in enumerator {
                guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
                let name = dir.lastPathComponent.lowercased()
                guard name.contains("descriptor") else { continue }
                result[name.hasPrefix("video") ? photos_ext : collections_ext, default: []].append(dir)
            }
        }
        
        return result
    }

    private static func write_descriptor(at src: URL, container: URL, ext: String) throws {
        let dest_dir = descriptors_url(container: container, ext: ext)
        let dest_url = dest_dir.appendingPathComponent(UUID().uuidString)

        if !fm.fileExists(atPath: dest_dir.path) {
            try fm.createDirectory(at: dest_dir, withIntermediateDirectories: true)
        }

        if fm.fileExists(atPath: dest_url.path) { try? fm.removeItem(at: dest_url) }
        try fm.copyItem(at: src, to: dest_url)
    }

    private static func randomize_id(in url: URL) {
        let id = Int.random(in: 9999...99999)
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return }
        
        for case let file as URL in enumerator {
            switch file.lastPathComponent {
                case "com.apple.posterkit.provider.descriptor.identifier":
                    try? String(id).data(using: .utf8)?.write(to: file)
                case "com.apple.posterkit.provider.contents.userInfo":
                    set_plist_val(key: "wallpaperRepresentingIdentifier", value: id, at: file)
                case "Wallpaper.plist":
                    set_plist_val(key: "identifier", value: id, at: file)
                default:
                    break
            }
        }
    }

    private static func set_plist_val(key: String, value: Any, at file: URL) {
        guard let data = fm.contents(atPath: file.path), var plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else { return }
        plist[key] = value
        guard let updated = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else { return }
        try? updated.write(to: file)
    }
}
