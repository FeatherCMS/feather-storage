import FeatherStorage
import Foundation
import Logging
import NIOCore
import NIOPosix

extension NonBlockingFileIO {

    fileprivate func write(
        fileHandle: NIOFileHandle,
        buffer: ByteBuffer,
        eventLoop: EventLoop
    ) async throws {
        try await write(
            fileHandle: fileHandle,
            buffer: buffer,
            eventLoop: eventLoop
        ).get()
    }

    fileprivate func openFile(
        path: String,
        mode: NIOFileHandle.Mode,
        flags: NIOFileHandle.Flags = .default,
        eventLoop: EventLoop
    ) async throws -> NIOFileHandle {
        try await openFile(
            path: path,
            mode: mode,
            flags: flags,
            eventLoop: eventLoop
        ).get()
    }

    fileprivate func readFileSize(
        fileHandle: NIOFileHandle,
        eventLoop: EventLoop
    ) async throws -> Int64 {
        try await readFileSize(
            fileHandle: fileHandle,
            eventLoop: eventLoop
        )
        .get()
    }

    fileprivate func read(
        fileHandle: NIOFileHandle,
        byteCount: Int,
        allocator: ByteBufferAllocator,
        eventLoop: EventLoop
    ) async throws -> ByteBuffer {
        try await read(
            fileHandle: fileHandle,
            byteCount: byteCount,
            allocator: allocator,
            eventLoop: eventLoop
        ).get()
    }
}

extension FileManager {

    fileprivate func directoryExists(at location: URL) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(
            atPath: location.path,
            isDirectory: &isDir
        )
        return isDir.boolValue
    }

    fileprivate func createDirectory(at location: URL) throws {
        try FileManager.default.createDirectory(
            at: location,
            withIntermediateDirectories: true
        )
    }
}

public struct FeatherFileStorage: FeatherStorage {
    let workDir: String
    let threadPool: NIOThreadPool
    let logger: Logger
    let eventLoop: EventLoop

    public init(
        workDir: String,
        threadPool: NIOThreadPool,
        logger: Logger,
        eventLoop: EventLoop
    ) {
        self.workDir = workDir
        self.threadPool = threadPool
        self.logger = logger
        self.eventLoop = eventLoop
    }
}

extension FeatherFileStorage {

    public var workUrl: URL { .init(fileURLWithPath: workDir) }

    public func create(
        key: String
    ) async throws {
        try FileManager.default.createDirectory(
            at: workUrl.appendingPathComponent(key),
            withIntermediateDirectories: true
        )
    }

    public func list(
        key: String?
    ) async throws -> [String] {
        let dirUrl = workUrl.appendingPathComponent(key ?? "")
        if FileManager.default.directoryExists(at: dirUrl) {
            return try FileManager.default.contentsOfDirectory(
                atPath: dirUrl.path
            )
        }
        return []
    }

    public func copy(
        key source: String,
        to destination: String
    ) async throws {
        let exists = await exists(key: source)
        guard exists else {
            throw FeatherStorageError.keyNotExists
        }
        try await delete(key: destination)
        let sourceUrl = workUrl.appendingPathComponent(source)
        let destinationUrl = workUrl.appendingPathComponent(destination)
        let location = destinationUrl.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: location)
        try FileManager.default.copyItem(at: sourceUrl, to: destinationUrl)
    }

    public func move(
        key source: String,
        to destination: String
    ) async throws {
        try await copy(key: source, to: destination)
        try await delete(key: source)
    }

    public func delete(
        key: String
    ) async throws {
        guard await exists(key: key) else {
            return
        }
        let fileUrl = workUrl.appendingPathComponent(key)
        try FileManager.default.removeItem(atPath: fileUrl.path)
    }

    public func exists(key: String) async -> Bool {
        let fileUrl = workUrl.appendingPathComponent(key)
        return FileManager.default.fileExists(atPath: fileUrl.path)
    }

    public func upload(
        key: String,
        buffer: ByteBuffer
    ) async throws {
        let fileUrl = workUrl.appendingPathComponent(key)
        let location = fileUrl.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: location)

        let fileio = NonBlockingFileIO(threadPool: threadPool)
        let handle = try await fileio.openFile(
            path: fileUrl.path,
            mode: .write,
            flags: .allowFileCreation(),
            eventLoop: eventLoop
        )
        do {
            try await fileio.write(
                fileHandle: handle,
                buffer: buffer,
                eventLoop: eventLoop
            )
            try handle.close()
        }
        catch {
            try handle.close()
            throw error
        }
    }

    public func download(
        key: String
    ) async throws -> ByteBuffer {
        let exists = await exists(key: key)
        guard exists else {
            throw FeatherStorageError.keyNotExists
        }
        let sourceUrl = workUrl.appendingPathComponent(key)
        let fileio = NonBlockingFileIO(threadPool: threadPool)
        let handle = try await fileio.openFile(
            path: sourceUrl.path,
            mode: .read,
            eventLoop: eventLoop
        )
        do {
            let size = try await fileio.readFileSize(
                fileHandle: handle,
                eventLoop: eventLoop
            )

            let buffer = try await fileio.read(
                fileHandle: handle,
                byteCount: Int(size),
                allocator: .init(),
                eventLoop: eventLoop
            )
            try handle.close()
            return buffer
        }
        catch {
            try handle.close()
            throw error
        }
    }
}
