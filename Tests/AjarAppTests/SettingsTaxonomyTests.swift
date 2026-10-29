import AppKit
import XCTest
@testable import AjarApp

final class SettingsTaxonomyTests: XCTestCase {
    func testFourSectionsAndLegacyNavigation() {
        XCTAssertEqual(SettingsSection.allCases.map(\.rawValue), ["general", "ports", "projects", "about"])
        XCTAssertEqual(SettingsSection.restored("behavior"), .ports)
        XCTAssertEqual(SettingsSection.restored("projects"), .projects)
        XCTAssertEqual(SettingsSection.restored("unknown"), .general)
    }

    @MainActor
    func testImportsLeftOpenPreferencesOnceButNotFixedAddresses() {
        let suite = "Ajar.ImportTests.\(UUID().uuidString)", legacySuite = suite + ".legacy"
        let defaults = UserDefaults(suiteName: suite)!, legacy = UserDefaults(suiteName: legacySuite)!
        defer {
            defaults.removePersistentDomain(forName: suite)
            legacy.removePersistentDomain(forName: legacySuite)
        }
        legacy.set("dark", forKey: "leftopen.appearance")
        legacy.set([3000, 8080], forKey: "leftopen.ignoredPorts")
        legacy.set(true, forKey: "leftopen.fixedAddressHTTPS")
        defaults.set(30, forKey: "ajar.refreshInterval")
        legacy.set(300, forKey: "leftopen.refreshInterval")

        let settings = AppSettings(defaults: defaults, legacy: legacy)
        XCTAssertEqual(settings.appearance, .dark)
        XCTAssertEqual(settings.ignoredPorts, [3000, 8080])
        XCTAssertEqual(settings.refreshInterval, .seconds30, "Ajar's own value wins")
        XCTAssertNil(defaults.object(forKey: "ajar.fixedAddressHTTPS"), "Fixed addresses are set up again")

        settings.appearance = .light
        legacy.set("dark", forKey: "leftopen.appearance")
        XCTAssertEqual(AppSettings(defaults: defaults, legacy: legacy).appearance, .light, "Imported only once")
    }

    @MainActor
    func testAppearancePersistenceAndSystemInheritance() {
        let suite = "Ajar.AppearanceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.appearance, .system)
        XCTAssertNil(settings.appearance.nativeAppearance)
        for value in AppearancePreference.allCases {
            settings.appearance = value
            XCTAssertEqual(AppSettings(defaults: defaults).appearance, value)
        }
        XCTAssertEqual(AppearancePreference.light.nativeAppearance?.name, .aqua)
        XCTAssertEqual(AppearancePreference.dark.nativeAppearance?.name, .darkAqua)
        defaults.set("invalid", forKey: "ajar.appearance")
        XCTAssertEqual(AppSettings(defaults: defaults).appearance, .system)
    }
}
