import FeatherS3Storage
import FeatherStorage
import Logging
import NIO
import SotoCore
import SotoS3
import XCTest

final class FeatherS3StorageTests: XCTestCase {

    // yep, this is horrible... will do it for now.
    static let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    static let logger = Logger(label: "test-logger")

    static let aws = AWSClient(
        credentialProvider: .static(
            accessKeyId: ProcessInfo.processInfo.environment["S3_ID"]!,
            secretAccessKey: ProcessInfo.processInfo.environment["S3_SECRET"]!
        ),
        options: .init(
            requestLogLevel: .info,
            errorLogLevel: .info
        ),
        httpClientProvider: .createNewWithEventLoopGroup(
            eventLoopGroup
        ),
        logger: logger
    )

    override class func tearDown() {
        try? aws.syncShutdown()
        eventLoopGroup.shutdownGracefully { _ in }
    }

    private func getTestStorage() -> FeatherStorage {
        let env = ProcessInfo.processInfo.environment

        let s3 = S3(
            client: Self.aws,
            region: .init(rawValue: env["S3_REGION"]!)
        )

        return FeatherS3Storage(
            s3: s3,
            bucketName: env["S3_BUCKET"]!,
            logger: .init(label: "s3-logger"),
            eventLoop: Self.eventLoopGroup.any()
        )
    }

    // MARK: - tests

    func testUpload() async throws {
        let storage = getTestStorage()
        let key = "test-01.txt"
        let contents = "lorem ipsum dolor sit amet"

        try await storage.upload(
            key: key,
            buffer: .init(string: contents)
        )
        let buffer = try await storage.download(
            key: key
        )

        guard let res = buffer.getString(at: 0, length: buffer.readableBytes)
        else {
            return XCTFail("Invalid byte buffer response data value.")
        }
        XCTAssertEqual(res, contents)
    }

    func testCreate() async throws {
        let storage = getTestStorage()
        let key = "dir01/dir02/dir03"
        try await storage.create(key: key)

        let list1 = try await storage.list(key: "dir01")
        XCTAssertEqual(list1, ["dir02"])

        let list2 = try await storage.list(key: "dir01/dir02")
        XCTAssertEqual(list2, ["dir03"])
    }

    func testList() async throws {
        let storage = getTestStorage()
        let key1 = "dir02/dir03"
        try await storage.create(key: key1)

        let key2 = "dir02/test-01.txt"
        try await storage.upload(
            key: key2,
            buffer: .init(string: "test")
        )

        let res = try await storage.list(key: "dir02")
        XCTAssertEqual(res, ["dir03", "test-01.txt"])
    }

    func testExists() async throws {
        let storage = getTestStorage()
        let key1 = "non-existing-thing"
        let exists1 = await storage.exists(key: key1)
        XCTAssertFalse(exists1)

        let key2 = "my/dir/"
        try await storage.create(key: key2)
        let exists2 = await storage.exists(key: key2)
        XCTAssertTrue(exists2)
    }

    func testListFile() async throws {
        let storage = getTestStorage()
        let key = "dir04/test-01.txt"
        try await storage.upload(
            key: key,
            buffer: .init(string: "test")
        )

        let res = try await storage.list(key: key)
        XCTAssertEqual(res, [])
    }

    func testCopy() async throws {
        let storage = getTestStorage()
        let key = "test-02.txt"
        try await storage.upload(
            key: key,
            buffer: .init(string: "lorem ipsum")
        )

        let dest = "test-03.txt"
        try await storage.copy(key: key, to: dest)

        let res1 = await storage.exists(key: key)
        XCTAssertTrue(res1)

        let res2 = await storage.exists(key: dest)
        XCTAssertTrue(res2)
    }

    func testMove() async throws {
        let storage = getTestStorage()
        let key = "test-04.txt"
        try await storage.upload(
            key: key,
            buffer: .init(string: "dolor sit amet")
        )

        let dest = "test-05.txt"
        try await storage.move(key: key, to: dest)

        let res1 = await storage.exists(key: key)
        XCTAssertFalse(res1)

        let res2 = await storage.exists(key: dest)
        XCTAssertTrue(res2)
    }

    func testDownload() async throws {
        let storage = getTestStorage()
        let key = "test-04.txt"
        let contents = "lorem ipsum dolor sit amet"

        try await storage.upload(
            key: key,
            buffer: .init(string: contents)
        )

        let buffer = try await storage.download(
            key: key
        )
        guard let res = buffer.getString(at: 0, length: buffer.readableBytes)
        else {
            return XCTFail("Invalid byte buffer response data value.")
        }
        XCTAssertEqual(res, contents)
    }
}
