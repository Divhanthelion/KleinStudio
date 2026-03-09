import Foundation
import AppKit

struct FolderItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let isDirectory: Bool
}

class WorkspaceManager: ObservableObject {
    static let shared = WorkspaceManager()
    
    let rootURL: URL
    @Published var currentFolderURL: URL
    @Published var contents: [FolderItem] = []
    
    init() {
        let picturesDir = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        self.rootURL = picturesDir.appendingPathComponent("KleinStudio")
        self.currentFolderURL = rootURL
        
        // Ensure root exists
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
        refreshContents()
    }
    
    func refreshContents() {
        do {
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .creationDateKey]
            let urls = try FileManager.default.contentsOfDirectory(at: currentFolderURL, includingPropertiesForKeys: resourceKeys, options: .skipsHiddenFiles)
            
            var items: [FolderItem] = []
            for url in urls {
                let resources = try url.resourceValues(forKeys: Set(resourceKeys))
                let isDir = resources.isDirectory ?? false
                items.append(FolderItem(name: url.lastPathComponent, url: url, isDirectory: isDir))
            }
            
            // Sort: folders first, then files by creation date (newest first is preferred but alphabetic is fine for now)
            self.contents = items.sorted { a, b in
                if a.isDirectory && !b.isDirectory { return true }
                if !a.isDirectory && b.isDirectory { return false }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        } catch {
            print("Failed to refresh contents: \(error)")
        }
    }
    
    func createFolder(name: String) {
        let newURL = currentFolderURL.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: true, attributes: nil)
            refreshContents()
        } catch {
            print("Failed to create folder: \(error)")
        }
    }
    
    func renameItem(at url: URL, newName: String) {
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(at: url, to: newURL)
            refreshContents()
        } catch {
            print("Failed to rename item: \(error)")
        }
    }
    
    func deleteItem(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            refreshContents()
        } catch {
            print("Failed to delete item: \(error)")
        }
    }
    
    func saveImage(_ image: NSImage, prompt: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = formatter.string(from: Date())
        
        let safePrompt = prompt.prefix(20).replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "/", with: "-")
        let filename = "\(dateString)_\(safePrompt).png"
        let fileURL = currentFolderURL.appendingPathComponent(filename)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return
        }
        
        do {
            try pngData.write(to: fileURL)
            DispatchQueue.main.async {
                self.refreshContents()
            }
        } catch {
            print("Failed to save image: \(error)")
        }
    }
}
