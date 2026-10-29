import XCTest
@testable import AjarCore

final class HomebrewCleanupPolicyTests: XCTestCase {
    func testCleanupRequiresAnExactInvocationBeforeUIStartup() {
        XCTAssertEqual(HomebrewCleanupPolicy.invocation([]), .application)
        XCTAssertEqual(HomebrewCleanupPolicy.invocation(["--snapshot"]), .application)
        XCTAssertEqual(HomebrewCleanupPolicy.invocation(["--homebrew-cleanup"]), .cleanup)
        for args in [["--homebrew-cleanup", "extra"], ["--homebrew-cleanup=1"], ["--homebrew-unknown"]] {
            XCTAssertEqual(HomebrewCleanupPolicy.invocation(args), .invalid)
        }
    }

    func testOrphanedBundledRuntimesBlockCleanupWithoutKillingProjects() {
        XCTAssertTrue(HomebrewCleanupPolicy.hasAppRuntime(processTable:
            "/Applications/Ajar.app/Contents/Resources/Portless/node-arm64\n"))
        XCTAssertTrue(HomebrewCleanupPolicy.hasAppRuntime(processTable:
            "/Volumes/Custom Apps/Ajar.app/Contents/Resources/Portless/node-x64\n"))
        XCTAssertFalse(HomebrewCleanupPolicy.hasAppRuntime(processTable:
            "/usr/local/bin/node\n/Library/Application Support/Ajar/Portless/node-arm64\n/bin/zsh\n"))
    }
}
