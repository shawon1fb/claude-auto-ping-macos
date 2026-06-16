import XCTest
@testable import ClaudeAutoPingMacos

final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsWhenEmpty() {
        let store = UserDefaultsSettingsStore(defaults: defaults)
        let config = store.loadConfiguration()
        XCTAssertEqual(config.message, "hi")
        XCTAssertEqual(config.intervalPreset, .fiveHours)
        XCTAssertFalse(config.isEnabled)
        XCTAssertEqual(config.effectiveIntervalSeconds, 5 * 60 * 60)
    }

    func testSaveAndLoadRoundTrip() {
        let store = UserDefaultsSettingsStore(defaults: defaults)
        var config = SchedulerConfiguration()
        config.message = "নমস্কার"
        config.intervalPreset = .custom
        config.customIntervalSeconds = 90 * 60
        config.isEnabled = true
        store.saveConfiguration(config)

        let loaded = store.loadConfiguration()
        XCTAssertEqual(loaded.message, "নমস্কার")
        XCTAssertEqual(loaded.intervalPreset, .custom)
        XCTAssertEqual(loaded.customIntervalSeconds, 90 * 60)
        XCTAssertTrue(loaded.isEnabled)
    }

    func testStateRoundTrip() {
        let store = UserDefaultsSettingsStore(defaults: defaults)
        var state = SchedulerPersistentState()
        state.consecutiveFailures = 2
        state.nextScheduledDate = Date(timeIntervalSince1970: 1_700_000_000)
        store.saveState(state)

        let loaded = store.loadState()
        XCTAssertEqual(loaded.consecutiveFailures, 2)
        XCTAssertEqual(loaded.nextScheduledDate, state.nextScheduledDate)
    }

    func testInvalidStoredDataFallsBackToDefaults() {
        defaults.set(Data("not json".utf8), forKey: "scheduler.configuration")
        let store = UserDefaultsSettingsStore(defaults: defaults)
        let config = store.loadConfiguration()
        XCTAssertEqual(config.message, "hi")
    }

    func testMigrationStampsCurrentVersion() throws {
        // Simulate an older stored payload missing newer fields and with v0.
        let json = """
        {"version":0,"message":"older","intervalPreset":"oneHour","customIntervalSeconds":3600,
        "isEnabled":true,"startAutomatically":false,"launchAtLogin":false,"wakeRecoveryEnabled":true,
        "notifyOnSuccess":false,"notifyOnFailure":true,"newChatShortcut":{"key":"n","command":true,
        "shift":false,"option":false,"control":false},"launchDelay":3,"newChatDelay":1.5,"sendDelay":0.8,
        "pressReturnAutomatically":true,"duplicateCooldown":300,"logRetentionCount":100}
        """
        defaults.set(Data(json.utf8), forKey: "scheduler.configuration")
        let store = UserDefaultsSettingsStore(defaults: defaults)
        let config = store.loadConfiguration()
        XCTAssertEqual(config.version, SchedulerConfiguration.currentVersion)
        XCTAssertEqual(config.message, "older")
        XCTAssertTrue(config.isEnabled)
        // Keys absent from the older payload fall back to their defaults rather
        // than failing to decode.
        XCTAssertTrue(config.anchorToResetTime)
        XCTAssertNil(config.resetAnchorDate)
    }

    func testDecodingToleratesMissingKeys() {
        // A minimal payload with only a couple of keys must still decode.
        let json = #"{"message":"partial","intervalPreset":"twoHours"}"#
        defaults.set(Data(json.utf8), forKey: "scheduler.configuration")
        let store = UserDefaultsSettingsStore(defaults: defaults)
        let config = store.loadConfiguration()
        XCTAssertEqual(config.message, "partial")
        XCTAssertEqual(config.intervalPreset, .twoHours)
        XCTAssertEqual(config.logRetentionCount, 100) // default
        XCTAssertTrue(config.anchorToResetTime) // default
    }

    func testResetClearsStoredData() {
        let store = UserDefaultsSettingsStore(defaults: defaults)
        var config = SchedulerConfiguration()
        config.message = "changed"
        store.saveConfiguration(config)
        store.reset()
        XCTAssertEqual(store.loadConfiguration().message, "hi")
    }
}
