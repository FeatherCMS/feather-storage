import FeatherStorage
import Foundation
import Logging
import NIOCore
import SotoS3

public struct FeatherS3Storage {

    let s3: S3
    let bucketName: String
    let logger: Logger
    let eventLoop: EventLoop

    public init(
        s3: S3,
        bucketName: String,
        logger: Logger,
        eventLoop: EventLoop
    ) {
        self.s3 = s3
        self.bucketName = bucketName
        self.logger = logger
        self.eventLoop = eventLoop
    }
}

extension FeatherS3Storage: FeatherStorage {

    ///
    /// Creates an empty key (directory)
    ///
    public func create(
        key: String
    ) async throws {
        let safeKey = key.split(separator: "/").joined(separator: "/") + "/"
        _ = try await s3.putObject(
            .init(
                bucket: bucketName,
                contentLength: 0,
                key: safeKey
            ),
            logger: logger,
            on: eventLoop
        )
    }

    ///
    /// List objects under a given key (returning the relative keys)
    ///
    public func list(
        key: String? = nil
    ) async throws -> [String] {
        let list = try await s3.listObjects(
            .init(
                bucket: bucketName,
                prefix: key
            ),
            logger: logger,
            on: eventLoop
        )
        let keys = (list.contents ?? []).map(\.key).compactMap { $0 }
        var dropCount = 0
        if let prefix = key {
            dropCount = prefix.split(separator: "/").count
        }
        return keys.compactMap {
            $0.split(separator: "/").dropFirst(dropCount).map(String.init).first
        }
    }

    ///
    /// Check if a file exists using a key
    ///
    public func exists(
        key: String
    ) async -> Bool {
        do {
            _ = try await s3.getObject(
                .init(
                    bucket: bucketName,
                    key: key
                ),
                logger: logger,
                on: eventLoop
            )
            return true
        }
        catch {
            return false
        }
    }

    ///
    /// Copy existing object to a new key
    ///
    public func copy(
        key source: String,
        to destination: String
    ) async throws {
        let exists = await exists(key: source)
        guard exists else {
            throw FeatherStorageError.keyNotExists
        }

        _ = try await s3.copyObject(
            .init(
                bucket: bucketName,
                copySource: bucketName + "/" + source,
                key: destination
            ),
            logger: logger,
            on: eventLoop
        )
    }

    ///
    /// Move existing object to a new key
    ///
    public func move(
        key source: String,
        to destination: String
    ) async throws {
        let exists = await exists(key: source)
        guard exists else {
            throw FeatherStorageError.keyNotExists
        }
        _ = try await copy(key: source, to: destination)
        try await delete(key: source)
    }

    ///
    /// Removes a file resource using a key
    ///
    public func delete(
        key: String
    ) async throws {
        _ = try await s3.deleteObject(
            .init(
                bucket: bucketName,
                key: key
            ),
            logger: logger,
            on: eventLoop
        )
    }

    // MARK: - upload / download

    ///
    /// Uploads a file using a key and a data object returning the resolved URL of the uploaded file
    ///
    public func upload(
        key: String,
        buffer: ByteBuffer
    ) async throws {
        _ = try await s3.putObject(
            .init(
                body: .byteBuffer(buffer),
                bucket: bucketName,
                key: key
            ),
            logger: logger,
            on: eventLoop
        )
    }

    ///
    /// Download object data using a key
    ///
    public func download(
        key: String
    ) async throws -> ByteBuffer {
        let exists = await exists(key: key)
        guard exists else {
            throw FeatherStorageError.keyNotExists
        }
        let response = try await s3.getObject(
            .init(
                bucket: bucketName,
                key: key
            ),
            logger: logger,
            on: eventLoop
        )
        guard let buffer = response.body?.asByteBuffer() else {
            throw FeatherStorageError.invalidResponse
        }
        return buffer
    }
}
