import Testing
import CoreGraphics
@testable import LeapCore

@Suite("Window placement")
struct WindowPlacementTests {
    private let builtIn = ScreenGeometry(
        frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: 0, y: 70, width: 1440, height: 805))

    private let external = ScreenGeometry(
        frame: CGRect(x: -1920, y: 120, width: 1920, height: 1080),
        visibleFrame: CGRect(x: -1920, y: 120, width: 1920, height: 1055))

    private let onboardingSize = CGSize(width: 480, height: 620)

    @Test func centresInsideAScreenThatDoesNotStartAtTheOrigin() {
        let origin = WindowPlacement.centeredOrigin(for: onboardingSize, in: external.visibleFrame)

        #expect(origin.x == -1200)   // -1920 + (1920 - 480) / 2
        #expect(origin.y == 338)     // 120 + (1055 - 620) / 2, rounded up

        let frame = CGRect(origin: origin, size: onboardingSize)
        #expect(frame.midX == external.visibleFrame.midX)
        #expect(abs(frame.midY - external.visibleFrame.midY) <= 0.5)   // rounded to whole points
    }

    @Test func centringRespectsTheUsableAreaRatherThanTheWholeDisplay() {
        let origin = WindowPlacement.centeredOrigin(for: onboardingSize, in: builtIn.visibleFrame)
        let frame = CGRect(origin: origin, size: onboardingSize)

        #expect(builtIn.visibleFrame.contains(frame))
        #expect(frame.minY > builtIn.frame.minY)   // clear of the Dock
        #expect(frame.maxY < builtIn.frame.maxY)   // clear of the menu bar
    }

    @Test func originsLandOnWholePoints() {
        let odd = CGSize(width: 481, height: 619)
        let origin = WindowPlacement.centeredOrigin(for: odd, in: builtIn.visibleFrame)

        #expect(origin.x == origin.x.rounded())
        #expect(origin.y == origin.y.rounded())
    }

    @Test func aWindowLargerThanTheScreenOverhangsEvenly() {
        let huge = CGSize(width: 2000, height: 1200)
        let origin = WindowPlacement.centeredOrigin(for: huge, in: builtIn.visibleFrame)

        #expect(origin.x < builtIn.visibleFrame.minX)
        #expect(origin.y < builtIn.visibleFrame.minY)

        let frame = CGRect(origin: origin, size: huge)
        #expect(abs(frame.midX - builtIn.visibleFrame.midX) <= 0.5)
        #expect(abs(frame.midY - builtIn.visibleFrame.midY) <= 0.5)
    }

    @Test func thePointerPicksTheScreen() {
        let screens = [builtIn, external]

        let onExternal = WindowPlacement.activeVisibleFrame(
            mouseLocation: CGPoint(x: -1000, y: 600), screens: screens, mainScreen: builtIn)
        #expect(onExternal == external.visibleFrame)

        let onBuiltIn = WindowPlacement.activeVisibleFrame(
            mouseLocation: CGPoint(x: 700, y: 400), screens: screens, mainScreen: builtIn)
        #expect(onBuiltIn == builtIn.visibleFrame)
    }

    @Test func aPointerOutsideEveryScreenFallsBackToTheFocusedOne() {
        let screens = [builtIn, external]
        // Left of the built-in screen and below the external one, which starts
        // 120pt up.
        let gap = CGPoint(x: -100, y: 50)

        #expect(WindowPlacement.activeVisibleFrame(
            mouseLocation: gap, screens: screens, mainScreen: external) == external.visibleFrame)
        #expect(WindowPlacement.activeVisibleFrame(
            mouseLocation: gap, screens: screens, mainScreen: nil) == builtIn.visibleFrame)
    }

    @Test func noScreensYieldsNoFrame() {
        #expect(WindowPlacement.activeVisibleFrame(
            mouseLocation: .zero, screens: [], mainScreen: builtIn) == nil)
    }

    @Test func offScreenWindowsAreDetectedAfterADisplayGoesAway() {
        let onExternal = CGRect(x: -1200, y: 500, width: 480, height: 620)

        #expect(WindowPlacement.isOnScreen(onExternal, screens: [builtIn, external]))
        #expect(!WindowPlacement.isOnScreen(onExternal, screens: [builtIn]))
        #expect(!WindowPlacement.isOnScreen(onExternal, screens: []))
    }

    @Test func aPartlyVisibleWindowCountsAsOnScreen() {
        let straddling = CGRect(x: -240, y: 400, width: 480, height: 620)
        #expect(WindowPlacement.isOnScreen(straddling, screens: [builtIn]))
    }
}
