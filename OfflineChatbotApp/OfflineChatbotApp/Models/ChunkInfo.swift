import Foundation

enum DownloadFileStatus: Equatable, Sendable {
    case waiting
    case downloading(progress: Double)
    case paused
    case completed
    case failed(error: String)
}

struct ChunkInfo: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let startByte: Int64
    let endByte: Int64
    var downloadedBytes: Int64
    var isCompleted: Bool
    var isPaused: Bool
    var isInProgress: Bool = false
    
    var size: Int64 {
        return endByte - startByte + 1
    }
    
    var progress: Double {
        guard size > 0 else { return 0.0 }
        return Double(downloadedBytes) / Double(size)
    }
    
    static func == (lhs: ChunkInfo, rhs: ChunkInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

struct FileChunkInfo: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let fileName: String
    let totalSize: Int64
    var chunks: [ChunkInfo]
    var downloadedBytes: Int64 = 0
    
    init(fileName: String, totalSize: Int64, chunks: [ChunkInfo]) {
        self.id = fileName // Use fileName as id for simplicity
        self.fileName = fileName
        self.totalSize = totalSize
        self.chunks = chunks
    }
    
    var isCompleted: Bool {
        return chunks.allSatisfy { $0.isCompleted }
    }
    
    var progress: Double {
        guard totalSize > 0 else { return 0.0 }
        return Double(downloadedBytes) / Double(totalSize)
    }
    
    static func == (lhs: FileChunkInfo, rhs: FileChunkInfo) -> Bool {
        return lhs.fileName == rhs.fileName
    }
}

struct DownloadFileInfo: Equatable, Sendable {
    let fileName: String
    let url: String
    let totalSize: Int64
    var downloadedSize: Int64
    var status: DownloadFileStatus
    
    var progress: Double {
        guard totalSize > 0 else { return 0.0 }
        return Double(downloadedSize) / Double(totalSize)
    }
    
    static func == (lhs: DownloadFileInfo, rhs: DownloadFileInfo) -> Bool {
        return lhs.fileName == rhs.fileName
    }
}