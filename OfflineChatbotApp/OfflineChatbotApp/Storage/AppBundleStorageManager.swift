import Foundation

protocol StorageManagerProtocol {
    static func getModelsDirectory() -> URL?
    static func createModelDirectory(for tier: ModelTier) throws -> URL
    static func getAvailableSpace() -> Int64
    static func calculateDirectorySize(at url: URL) -> Int64
}

class AppBundleStorageManager: StorageManagerProtocol {
    
    static func getModelsDirectory() -> URL? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ [STORAGE] Cannot access Documents directory")
            return nil
        }
        
        let modelsDir = documentsDir.appendingPathComponent("Models")
        
        // Create Models directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: modelsDir.path) {
            do {
                try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true, attributes: nil)
                print("✅ [STORAGE] Created Models directory at: \(modelsDir.path)")
            } catch {
                print("❌ [STORAGE] Failed to create Models directory: \(error)")
                return nil
            }
        }
        
        return modelsDir
    }
    
    static func createModelDirectory(for tier: ModelTier) throws -> URL {
        guard let modelsDir = getModelsDirectory() else {
            throw DownloadError.unknown("Cannot access Models directory")
        }
        
        let modelDir = modelsDir.appendingPathComponent(tier.folderName)
        
        if !FileManager.default.fileExists(atPath: modelDir.path) {
            try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true, attributes: nil)
            print("✅ [STORAGE] Created model directory: \(modelDir.path)")
        }
        
        return modelDir
    }
    
    static func getAvailableSpace() -> Int64 {
        do {
            let documentsURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let values = try documentsURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                print("💾 [STORAGE] Available space for important usage: \(ByteCountFormatter.string(fromByteCount: capacity, countStyle: .file))")
                return capacity
            } else {
                print("❌ [STORAGE] Could not read volumeAvailableCapacityForImportantUsageKey attribute")
            }
        } catch {
            print("❌ [STORAGE] Failed to get available space: \(error.localizedDescription)")
        }
        return 0
    }
    
    static func calculateDirectorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            } catch {
                print("❌ [STORAGE] Failed to get file size for \(fileURL): \(error)")
            }
        }
        
        return totalSize
    }
    
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    static func cleanupTempFiles() {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let tempChunksDir = documentsDir.appendingPathComponent("temp_chunks")
        
        if FileManager.default.fileExists(atPath: tempChunksDir.path) {
            do {
                try FileManager.default.removeItem(at: tempChunksDir)
                print("✅ [STORAGE] Cleaned up temp files")
            } catch {
                print("❌ [STORAGE] Failed to cleanup temp files: \(error)")
            }
        }
    }
}