import NIO

public protocol FeatherStorage {

    // MARK: - crud

    func create(
        key: String
    ) async throws

    ///
    /// List the contents of a given object for a key
    ///
    func list(
        key: String?
    ) async throws -> [String]

    ///
    /// Check if a given key exists
    ///
    /// - Parameters:
    ///     - key: The unique key for the uploaded file
    ///
    /// - Returns:
    ///     A Bool value indicating the file's existence
    ///
    func exists(
        key: String
    ) async -> Bool

    ///
    /// Copy a file using a source key to a given destination key
    ///
    func copy(
        key: String,
        to: String
    ) async throws

    ///
    /// Move a file using a source key to a given destination key
    ///
    func move(
        key: String,
        to: String
    ) async throws

    ///
    /// Deletes the data under the given key
    ///
    func delete(
        key: String
    ) async throws

    // MARK: - upload / download

    func upload(
        key: String,
        buffer: ByteBuffer
    ) async throws

    func download(
        key: String
    ) async throws -> ByteBuffer
}
