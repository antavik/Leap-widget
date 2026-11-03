import XCTest

/// The accessibility tree and the automated audit – the two things no
/// in-process render can reach. SwiftUI builds the tree lazily for an attached
/// assistive client; XCUITest is one, `swift test` is not.
@MainActor
final class AccessibilityAuditUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = AppDriver.launched()
    }

    override func tearDown() async throws {
        app.terminate()
        app = nil
    }

    /// Scoped rather than blanket: a type dropped wholesale stops reporting
    /// everything it covers; a filtered issue stays named and visible.
    private static let auditTypes: XCUIAccessibilityAuditType = [
        .contrast, .elementDetection, .hitRegion, .sufficientElementDescription
    ]

    func testOnboardingWindowPassesTheAccessibilityAudit() throws {
        let window = app.windows["Leap Widget"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        try app.performAccessibilityAudit(for: Self.auditTypes,
                                          Self.ignoringKnownIssues)
    }

    /// A placed widget is drawn by WidgetKit in another process, so hosting
    /// the same view in-process is the only way its tree can be read.
    func testAccessibilityPreviewExposesExactlyOneElement() throws {
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.waitForExistence(timeout: 10))

        menuBar.menuBarItems["Debug"].click()
        menuBar.menuItems["Accessibility Preview"].click()

        let preview = app.windows["Accessibility Preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))

        let onboarding = app.windows["Leap Widget"]
        onboarding.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertTrue(onboarding.waitForNonExistence(timeout: 5))

        // `accessibilityElement(children: .ignore)`: no day cell and no week
        // number may leak as a child.
        let elements = preview.descendants(matching: .any)
            .allElementsBoundByAccessibilityElement
            .filter { !$0.label.isEmpty }

        XCTAssertEqual(elements.count, 1,
                       "the grid published \(elements.count) elements: "
                       + elements.map { $0.label }.joined(separator: " | "))

        let spoken = try XCTUnwrap(elements.first?.label)
        XCTAssertTrue(spoken.hasPrefix("Today is"),
                      "unexpected spoken summary: \(spoken)")

        try app.performAccessibilityAudit(for: Self.auditTypes,
                                          Self.ignoringKnownIssues)
    }

    /// Filtered by hand rather than by dropping a whole audit type; each is
    /// named and costs one line to un-filter.
    ///
    /// `performAccessibilityAudit` is `@MainActor` and calls this handler
    /// synchronously, so the element arrives on the main actor and only the
    /// `@Sendable` signature hides that.
    private static let ignoringKnownIssues:
    @Sendable (XCUIAccessibilityAuditIssue) -> Bool = { issue in
        let element = issue.element
        let (elementType, label) = MainActor.assumeIsolated {
            (element?.elementType ?? .any, element?.label ?? "")
        }

        switch issue.auditType {
        // 1. SwiftUI publishes the hosting view's root as an unlabelled
        //    group. Labelling a pure container would make VoiceOver announce
        //    a wrapper that means nothing.
        case .sufficientElementDescription where
            elementType == .group && label.isEmpty:
            return true

        // 2. Elements built with `accessibilityElement(children: .ignore)`
        //    publish the right label but no AX role AppKit recognises, so the
        //    audit says "Unknown role". The role mapping is the framework's.
        case .sufficientElementDescription
            where issue.compactDescription.contains("Unknown role")
            && (label.hasPrefix("Today is") || label.hasPrefix("Step ")):
            return true

        // 3. The donation row's links and AppKit's Touch Bar proxy carry no
        //    description of their own. Neither is a thing this app draws.
        case .sufficientElementDescription
            where elementType == .link || elementType == .touchBar:
            return true

        default:
            // Anything unnamed is worth reading: leave a trace beside the
            // failure.
            NSLog("AUDIT unfiltered: type=%lu elementType=%lu label=%@ detail=%@",
                  issue.auditType.rawValue,
                  elementType.rawValue,
                  label,
                  issue.compactDescription)
            return false
        }
    }
}
