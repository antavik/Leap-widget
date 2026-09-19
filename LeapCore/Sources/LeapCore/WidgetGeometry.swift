import CoreGraphics

public enum WidgetGeometry: Sendable {
    case small, medium

    public static let contentPadding: CGFloat = 12

    public var tile: CGSize {
        switch self {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 364, height: 170)
        }
    }

    public var contentBox: CGSize {
        CGSize(width: tile.width - 2 * Self.contentPadding,
               height: tile.height - 2 * Self.contentPadding)
    }
}
