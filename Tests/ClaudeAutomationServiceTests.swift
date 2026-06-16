import XCTest
@testable import ClaudeAutoPingMacos

final class ClaudeAutomationServiceTests: XCTestCase {
    private var controller: MockClaudeAppController!
    private var runner: MockAppleScriptRunner!
    private var clipboard: MockClipboardManager!
    private var service: ClaudeAutomationService!

    override func setUp() {
        super.setUp()
        controller = MockClaudeAppController()
        runner = MockAppleScriptRunner()
        clipboard = MockClipboardManager()
        service = ClaudeAutomationService(controller: controller, scriptRunner: runner, clipboard: clipboard)
    }

    private func config(pressReturn: Bool = true, dryRun: Bool = false) -> AutomationConfiguration {
        AutomationConfiguration(
            claudeAppPath: nil,
            newChatShortcut: .newChat,
            launchDelay: 0,
            newChatDelay: 0,
            sendDelay: 0,
            pressReturn: pressReturn,
            dryRun: dryRun
        )
    }

    func testSuccessfulSendPastesAndSends() async throws {
        let result = try await service.sendMessage("hello", configuration: config())
        XCTAssertTrue(result.didOpenNewChat)
        XCTAssertTrue(result.didPaste)
        XCTAssertTrue(result.didSend)
        XCTAssertEqual(clipboard.lastSetString, "hello")
        // Clipboard is snapshotted once and restored once.
        XCTAssertEqual(clipboard.snapshotCount, 1)
        XCTAssertEqual(clipboard.restoreCount, 1)
    }

    func testClipboardRestoredAfterFailure() async {
        runner.failOnSubstring = "keystroke \"v\"" // fail at paste
        runner.errorToThrow = .pasteFailed
        do {
            _ = try await service.sendMessage("hello", configuration: config())
            XCTFail("Expected an error")
        } catch {
            // Even on failure, the clipboard must be restored exactly once.
            XCTAssertEqual(clipboard.restoreCount, 1)
        }
    }

    func testPasteFailureMapsToPasteError() async {
        runner.failOnSubstring = "keystroke \"v\""
        runner.errorToThrow = .pasteFailed
        await assertThrows(.pasteFailed) {
            _ = try await self.service.sendMessage("hi", configuration: self.config())
        }
    }

    func testPermissionDeniedIsPreserved() async {
        runner.failOnSubstring = "keystroke \"n\"" // fail at new chat
        runner.errorToThrow = .automationPermissionDenied
        await assertThrows(.automationPermissionDenied) {
            _ = try await self.service.sendMessage("hi", configuration: self.config())
        }
    }

    func testNoReturnDoesNotSend() async throws {
        let result = try await service.sendMessage("hi", configuration: config(pressReturn: false))
        XCTAssertTrue(result.didPaste)
        XCTAssertFalse(result.didSend)
        // The Return key code must not have been issued.
        XCTAssertFalse(runner.sources.contains { $0.contains("key code 36") })
    }

    func testUnicodeAndBanglaPreservedOnClipboard() async throws {
        let message = "হ্যালো 👋 Claude"
        _ = try await service.sendMessage(message, configuration: config())
        XCTAssertEqual(clipboard.lastSetString, message)
    }

    func testClaudeNotFoundPropagates() async {
        controller.errorToThrow = .claudeNotInstalled
        await assertThrows(.claudeNotInstalled) {
            _ = try await self.service.sendMessage("hi", configuration: self.config())
        }
        // No clipboard work should have happened before readiness.
        XCTAssertEqual(clipboard.snapshotCount, 0)
    }

    // MARK: - Helpers

    private func assertThrows(
        _ expected: AutomationError,
        _ block: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await block()
            XCTFail("Expected \(expected) to be thrown", file: file, line: line)
        } catch let error as AutomationError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }
}
