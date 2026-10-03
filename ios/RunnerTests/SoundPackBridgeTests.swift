import XCTest

// SoundPackBridge.swift and SharedSounds.swift are compiled into this target,
// the way the other Shared sources are.

/// Stands in for Apple's `AssetPackManager`: what the store says about the
/// pack and which files it holds once downloaded.
final class FakeSoundPackStore: SoundPackStore {
    var stateAnswer = SoundPackWire.notDownloaded
    var downloadAnswer = SoundPackWire.downloaded
    var progressSteps: [Double] = []
    /// Path in the pack to a file on disk, present once "downloaded".
    var files: [String: URL] = [:]
    var downloads = 0

    func state(packID: String) async -> SoundPackWire { stateAnswer }

    func download(packID: String, progress: @escaping (Double?) -> Void) async -> SoundPackWire {
        downloads += 1
        progressSteps.forEach { progress($0) }
        return downloadAnswer
    }

    func fileURL(packID: String, path: String) -> URL? { files[path] }
}

final class SoundPackBridgeTests: XCTestCase {
    private var root: URL!
    private var sounds: URL!
    private var store: FakeSoundPackStore!
    private var converted: [String] = []
    private var failConvert = false

    private let bell = "pack_library_boxing_bell"
    private let pack = "sound_pack_library"

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SoundPackBridgeTests-\(UUID().uuidString)")
        sounds = root.appendingPathComponent("Sounds")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = FakeSoundPackStore()
        converted = []
        failConvert = false
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        try super.tearDownWithError()
    }

    private func bridge(store: SoundPackStore?) -> SoundPackBridge {
        SoundPackBridge(
            store: store,
            soundsDirectory: { [sounds] in sounds },
            convert: { [weak self] source, destination in
                guard let self, !self.failConvert else { return false }
                self.converted.append(source.lastPathComponent)
                return FileManager.default.createFile(atPath: destination.path, contents: Data([1, 2, 3]))
            }
        )
    }

    /// Puts [id] in the fake pack, as the store would after a download.
    private func packHolds(_ id: String) throws {
        let file = root.appendingPathComponent("pack/sounds/\(id).m4a")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([9]).write(to: file)
        store.files[SoundPackBridge.pathInPack(soundID: id)] = file
    }

    func testBelowIOS26ThePackNeedsANewerOS() async {
        let state = await bridge(store: nil).packState(pack)
        XCTAssertEqual(state, .needsNewerOs)
        let download = await bridge(store: nil).download(pack) { _ in }
        XCTAssertEqual(download, .needsNewerOs)
    }

    func testStateComesFromTheStore() async {
        store.stateAnswer = .unavailable
        let state = await bridge(store: store).packState(pack)
        XCTAssertEqual(state.dictionary["state"] as? String, "unavailable")
    }

    func testDownloadPassesProgressAndTheEnd() async {
        store.progressSteps = [0.25, 0.5, 1]
        var seen: [Double?] = []
        let end = await bridge(store: store).download(pack) { seen.append($0) }
        XCTAssertEqual(seen, [0.25, 0.5, 1])
        XCTAssertEqual(end, .downloaded)
        XCTAssertEqual(store.downloads, 1)
    }

    func testAnUnsafePackNameIsRefused() async {
        let state = await bridge(store: store).packState("../x")
        XCTAssertEqual(state, .unavailable)
        XCTAssertEqual(store.downloads, 0)
    }

    private func caf(_ id: String) -> URL { sounds.appendingPathComponent("\(id).caf") }

    func testInstallReportsThePackFilesAndConvertsNothing() throws {
        try packHolds(bell)
        let done = bridge(store: store).install(pack, soundIDs: [bell, "pack_library_missing"])
        XCTAssertEqual(done, [["id": bell, "path": store.files[SoundPackBridge.pathInPack(soundID: bell)]!.path]])
        XCTAssertTrue(converted.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: caf(bell).path))
    }

    func testOnlyASoundInUseGetsACaf() throws {
        let buzzer = "pack_library_buzzer_1"
        try packHolds(bell)
        try packHolds(buzzer)
        let b = bridge(store: store)
        b.syncCopies(inUse: [bell, "classic_siren"])
        XCTAssertEqual(converted, ["\(bell).m4a"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: caf(bell).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: caf(buzzer).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: sounds.appendingPathComponent("\(bell).partial.caf").path))
        // The picker plays the caf for the sound in use and the pack file for the other.
        let found = Dictionary(uniqueKeysWithValues: b.installed(pack, [bell, buzzer]).map { ($0["id"]!, $0["path"]!) })
        XCTAssertEqual(found[bell], caf(bell).path)
        XCTAssertEqual(found[buzzer], store.files[SoundPackBridge.pathInPack(soundID: buzzer)]!.path)
    }

    func testACafNoChoiceUsesIsRemoved() throws {
        try packHolds(bell)
        let b = bridge(store: store)
        b.syncCopies(inUse: [bell])
        b.syncCopies(inUse: ["pager_beep"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: caf(bell).path))
    }

    func testOtherSoundsAreNeverRemoved() throws {
        try FileManager.default.createDirectory(at: sounds, withIntermediateDirectories: true)
        for name in ["classic_siren.caf", "user_1.caf"] {
            FileManager.default.createFile(atPath: sounds.appendingPathComponent(name).path, contents: Data([1]))
        }
        bridge(store: store).syncCopies(inUse: [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: sounds.appendingPathComponent("classic_siren.caf").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sounds.appendingPathComponent("user_1.caf").path))
    }

    func testSyncIsSafeToRepeat() throws {
        try packHolds(bell)
        let b = bridge(store: store)
        b.syncCopies(inUse: [bell])
        b.syncCopies(inUse: [bell])
        XCTAssertEqual(converted.count, 1)
    }

    func testAFailedConversionLeavesNothingBehind() throws {
        try packHolds(bell)
        failConvert = true
        bridge(store: store).syncCopies(inUse: [bell])
        XCTAssertFalse(FileManager.default.fileExists(atPath: caf(bell).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: sounds.appendingPathComponent("\(bell).partial.caf").path))
    }

    func testACafInUseIsKeptWhenThePackIsGone() throws {
        try FileManager.default.createDirectory(at: sounds, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: caf(bell).path, contents: Data([1]))
        bridge(store: nil).syncCopies(inUse: [bell])
        XCTAssertTrue(FileManager.default.fileExists(atPath: caf(bell).path))
        XCTAssertEqual(bridge(store: nil).installed(pack, [bell]).count, 1)
    }

    func testTheLaunchPassRebuildsAMissingCafInUse() throws {
        // In use, but the caf is gone (a failed conversion or a lost file).
        try packHolds(bell)
        bridge(store: store).sync(inUse: [bell], choicesReadable: true, convertMissing: true) {}
        XCTAssertTrue(FileManager.default.fileExists(atPath: caf(bell).path))
        XCTAssertEqual(bridge(store: store).installed(pack, [bell]).first?["path"], caf(bell).path)
    }

    func testPublishSeesTheNewCafAndTheOldOneIsDeletedAfter() throws {
        let buzzer = "pack_library_buzzer_1"
        try packHolds(bell)
        try FileManager.default.createDirectory(at: sounds, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: caf(buzzer).path, contents: Data([1]))
        var seenAtPublish: (bell: Bool, buzzer: Bool)?
        bridge(store: store).sync(inUse: [bell], choicesReadable: true, convertMissing: true) {
            seenAtPublish = (
                FileManager.default.fileExists(atPath: caf(bell).path),
                FileManager.default.fileExists(atPath: caf(buzzer).path)
            )
        }
        XCTAssertEqual(seenAtPublish?.bell, true)
        XCTAssertEqual(seenAtPublish?.buzzer, true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: caf(buzzer).path))
    }

    func testUnreadableChoicesDeleteNothing() throws {
        try FileManager.default.createDirectory(at: sounds, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: caf(bell).path, contents: Data([1]))
        bridge(store: store).sync(inUse: [], choicesReadable: false, convertMissing: true) {}
        XCTAssertTrue(FileManager.default.fileExists(atPath: caf(bell).path))
    }

    func testTheLaunchSyncOnlyDeletes() throws {
        try packHolds(bell)
        bridge(store: store).syncCopies(inUse: [bell], convertMissing: false)
        XCTAssertTrue(converted.isEmpty)
    }

    func testInstallRefusesIdsThatAreNotPackSounds() throws {
        let done = bridge(store: store).install(pack, soundIDs: ["../evil", "user_1", "PACK_X"])
        XCTAssertTrue(done.isEmpty)
        bridge(store: store).syncCopies(inUse: ["../evil", "PACK_X"])
        XCTAssertTrue(converted.isEmpty)
    }

    func testAnEmptyCopyDoesNotCountAsInstalled() throws {
        try FileManager.default.createDirectory(at: sounds, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: caf(bell).path, contents: Data())
        XCTAssertTrue(bridge(store: store).installed(pack, [bell]).isEmpty)
    }

    func testPackPathIsTheFolderOfItsSounds() throws {
        try packHolds(bell)
        XCTAssertEqual(
            bridge(store: store).packPath(pack, anySoundID: bell),
            root.appendingPathComponent("pack/sounds").path
        )
        XCTAssertNil(bridge(store: store).packPath(pack, anySoundID: "pack_library_missing"))
        XCTAssertNil(bridge(store: nil).packPath(pack, anySoundID: bell))
    }

    func testAMissingPackSoundRingsTheClassicSirenThroughTheExtension() throws {
        let suite = "SoundPackBridgeTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        SharedSounds.publish(defaultFile: "\(bell).caf", perTopicFiles: [:], to: defaults)
        let name = SharedSounds.fileName(forTopic: nil, defaults: defaults) { $0 == SharedSounds.packFallbackFile }
        XCTAssertEqual(name, "classic_siren.caf")
        // A topic whose pack sound is gone plays the default first.
        SharedSounds.publish(defaultFile: "pager_beep.caf", perTopicFiles: ["prod": "\(bell).caf"], to: defaults)
        XCTAssertEqual(SharedSounds.fileName(forTopic: "prod", defaults: defaults) { $0 != "\(bell).caf" }, "pager_beep.caf")
    }
}
