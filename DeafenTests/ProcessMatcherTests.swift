//
//  ProcessMatcherTests.swift
//  DeafenTests
//

import Testing
@testable import Deafen

struct ProcessMatcherTests {
    let matcher = ProcessMatcher(
        bundleIDs: ["com.tinyspeck.slackmacgap"],
        bundlePaths: ["/Applications/Slack.app"]
    )

    @Test func exactBundleIDMatches() {
        #expect(matcher.matches(bundleID: "com.tinyspeck.slackmacgap"))
    }

    @Test func helperBundleIDMatches() {
        #expect(matcher.matches(bundleID: "com.tinyspeck.slackmacgap.helper"))
    }

    @Test(arguments: [nil, "", "com.tinyspeck.slackmacgapx", "com.tinyspeck", "com.hnc.Discord"])
    func otherBundleIDsDoNotMatch(bundleID: String?) {
        #expect(!matcher.matches(bundleID: bundleID))
    }

    @Test func executableInsideBundleMatches() {
        let path = "/Applications/Slack.app/Contents/Frameworks/Slack Helper (Renderer).app/Contents/MacOS/Slack Helper (Renderer)"
        #expect(matcher.matches(executablePath: path))
    }

    @Test func siblingAppWithSamePrefixDoesNotMatch() {
        #expect(!matcher.matches(executablePath: "/Applications/Slack.app Beta/Contents/MacOS/Slack"))
        #expect(!matcher.matches(executablePath: "/Applications/SlackTools.app/Contents/MacOS/SlackTools"))
    }

    @Test func emptyMatcherMatchesNothing() {
        let empty = ProcessMatcher(bundleIDs: [], bundlePaths: [])
        #expect(!empty.matches(bundleID: "com.tinyspeck.slackmacgap"))
        #expect(!empty.matches(executablePath: "/Applications/Slack.app/Contents/MacOS/Slack"))
    }
}
