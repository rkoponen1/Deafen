//
//  StatusTextTests.swift
//  DeafenTests
//

import Testing
@testable import Deafen

struct StatusTextTests {
    @Test func noApps() {
        #expect(AppState.statusText(appNames: [], isDeafened: false, mutedProcessCount: 0) == "No apps selected")
        #expect(AppState.statusText(appNames: [], isDeafened: true, mutedProcessCount: 0) == "No apps selected")
    }

    @Test func listening() {
        #expect(AppState.statusText(appNames: ["Slack"], isDeafened: false, mutedProcessCount: 0) == "Listening to Slack")
    }

    @Test func silencedWhenProcessesAreMuted() {
        #expect(AppState.statusText(appNames: ["Slack"], isDeafened: true, mutedProcessCount: 2) == "Slack silenced")
    }

    @Test func waitingForSingleApp() {
        #expect(
            AppState.statusText(appNames: ["Slack"], isDeafened: true, mutedProcessCount: 0)
                == "Slack will be silenced as soon as it plays audio"
        )
    }

    @Test func waitingForSeveralAppsUsesPlural() {
        let text = AppState.statusText(appNames: ["Slack", "Discord"], isDeafened: true, mutedProcessCount: 0)
        #expect(text.hasSuffix("as soon as they play audio"))
        #expect(text.contains("Slack"))
        #expect(text.contains("Discord"))
    }
}
