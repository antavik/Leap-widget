import CoreGraphics

public enum WindowPlacement {

    public static func centeredOrigin(for size: CGSize, in visibleFrame: CGRect) -> CGPoint {
        CGPoint(x: (visibleFrame.midX - size.width / 2).rounded(),
                y: (visibleFrame.midY - size.height / 2).rounded())
    }

    public static func activeVisibleFrame(mouseLocation: CGPoint,
                                          screens: [ScreenGeometry],
                                          mainScreen: ScreenGeometry?) -> CGRect? {
        guard !screens.isEmpty else { return nil }

        if let hit = screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return hit.visibleFrame
        }
        return mainScreen?.visibleFrame ?? screens.first?.visibleFrame
    }

    public static func isOnScreen(_ frame: CGRect, screens: [ScreenGeometry]) -> Bool {
        // swiftlint:disable:next is_disjoint - CGRect, not Set; intersects(_:) differs for zero-size rects
        screens.contains { !$0.visibleFrame.intersection(frame).isEmpty }
    }
}
