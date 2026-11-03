import CoreGraphics

public enum WidgetGeometry: Sendable {
    case small, medium

    public static let contentPadding: CGFloat = 12

    public var tileSize: CGSize {
        switch self {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 364, height: 170)
        }
    }

    public var contentBox: CGSize {
        CGSize(width: tileSize.width - 2 * Self.contentPadding,
               height: tileSize.height - 2 * Self.contentPadding)
    }
}
