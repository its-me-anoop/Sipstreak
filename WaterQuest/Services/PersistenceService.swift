import Foundation
import CloudKit

final class PersistenceService {
    static let shared = PersistenceService()

    private let url: URL

    init(filename: String = "WaterQuestState.json") {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.url = directory.appendingPathComponent(filename)
    }

    func load<T: Decodable>(_ type: T.Type, fallback: T) -> T {
        guard let data = try? Data(contentsOf: url) else { return fallback }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(T.self, from: data)) ?? fallback
    }

    func save<T: Encodable>(_ value: T) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(value)
            let directory = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            try data.write(to: url, options: [.atomic])
        } catch {
            print("Failed to save WaterQuest state: \(error)")
        }
    }
}

struct SyncedAppState: Codable {
    var persistedState: PersistedState
    var hasOnboarded: Bool
    var updatedAt: Date
    var schemaVersion: Int
    var appThemeRawValue: Int?

    init(
        persistedState: PersistedState,
        hasOnboarded: Bool,
        updatedAt: Date,
        schemaVersion: Int = 1,
        appThemeRawValue: Int? = nil
    ) {
        self.persistedState = persistedState
        self.hasOnboarded = hasOnboarded
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
        self.appThemeRawValue = appThemeRawValue
    }
}

enum ServerSyncStatus: Equatable {
    case idle
    case syncing
    case unavailable
    case failed(String)
}

@MainActor
final class ServerSyncService: ObservableObject {
    @Published private(set) var status: ServerSyncStatus = .idle
    @Published private(set) var lastSyncDate: Date?

    private let container: CKContainer
    private let database: CKDatabase
    private let recordID = CKRecord.ID(recordName: "state")
    private let recordType = "WaterQuestState"
    private let payloadField = "payload"
    private let updatedAtField = "updatedAt"

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(container: CKContainer = .default()) {
        self.container = container
        self.database = container.privateCloudDatabase

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    /// Last-write-wins sync. Returns a remote snapshot when it is newer than local.
    func synchronize(localState: PersistedState, hasOnboarded: Bool, appThemeRawValue: Int) async -> SyncedAppState? {
        guard await isCloudAccountAvailable() else {
            status = .unavailable
            return nil
        }

        status = .syncing
        let localSnapshot = SyncedAppState(
            persistedState: localState,
            hasOnboarded: hasOnboarded,
            updatedAt: localState.lastUpdatedAt,
            appThemeRawValue: appThemeRawValue
        )

        do {
            let remoteRecord = try await fetchRemoteRecord()
            guard let remoteRecord else {
                try await save(snapshot: localSnapshot, existingRecord: nil)
                markSyncSuccess()
                return nil
            }

            let remoteSnapshot = try decodeSnapshot(from: remoteRecord)
            if isNewer(remoteSnapshot.updatedAt, than: localSnapshot.updatedAt) {
                markSyncSuccess()
                return remoteSnapshot
            }

            if isNewer(localSnapshot.updatedAt, than: remoteSnapshot.updatedAt) {
                try await save(snapshot: localSnapshot, existingRecord: remoteRecord)
            }

            markSyncSuccess()
            return nil
        } catch let ckError as CKError where ckError.code == .serverRecordChanged {
            do {
                if let latestRecord = try await fetchRemoteRecord() {
                    let latestSnapshot = try decodeSnapshot(from: latestRecord)
                    if isNewer(latestSnapshot.updatedAt, than: localSnapshot.updatedAt) {
                        markSyncSuccess()
                        return latestSnapshot
                    }
                    try await save(snapshot: localSnapshot, existingRecord: latestRecord)
                }
                markSyncSuccess()
                return nil
            } catch {
                status = .failed(error.localizedDescription)
                return nil
            }
        } catch {
            status = .failed(error.localizedDescription)
            return nil
        }
    }

    private func markSyncSuccess() {
        lastSyncDate = Date()
        status = .idle
    }

    private func isNewer(_ lhs: Date, than rhs: Date) -> Bool {
        lhs.timeIntervalSince1970 > rhs.timeIntervalSince1970 + 0.5
    }

    private func fetchRemoteRecord() async throws -> CKRecord? {
        do {
            return try await database.record(for: recordID)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            return nil
        }
    }

    private func save(snapshot: SyncedAppState, existingRecord: CKRecord?) async throws {
        let record = existingRecord ?? CKRecord(recordType: recordType, recordID: recordID)
        let fileURL = try writeSnapshotToTemporaryFile(snapshot)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        record[payloadField] = CKAsset(fileURL: fileURL)
        record[updatedAtField] = snapshot.updatedAt as CKRecordValue
        _ = try await database.save(record)
    }

    private func decodeSnapshot(from record: CKRecord) throws -> SyncedAppState {
        guard let asset = record[payloadField] as? CKAsset, let fileURL = asset.fileURL else {
            throw SyncError.missingPayload
        }

        let data = try Data(contentsOf: fileURL)
        var snapshot = try decoder.decode(SyncedAppState.self, from: data)
        if let updatedAt = record[updatedAtField] as? Date {
            snapshot.updatedAt = updatedAt
            snapshot.persistedState.lastUpdatedAt = updatedAt
        }
        return snapshot
    }

    private func writeSnapshotToTemporaryFile(_ snapshot: SyncedAppState) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WaterQuestSync", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let fileURL = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    private func isCloudAccountAvailable() async -> Bool {
        do {
            return try await accountStatus() == .available
        } catch {
            return false
        }
    }

    private func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    private enum SyncError: LocalizedError {
        case missingPayload

        var errorDescription: String? {
            switch self {
            case .missingPayload:
                return "Server payload missing."
            }
        }
    }
}
