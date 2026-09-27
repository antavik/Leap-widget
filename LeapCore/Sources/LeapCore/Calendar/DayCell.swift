import SwiftUI
import WidgetKit

struct DayCell: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    let day: Day
    let isWeekend: Bool
    let showsOutsideDays: Bool
    let metrics: Theme.Metrics

    var body: some View {
        if day.isOutsideMonth && !showsOutsideDays {
            // Pin the placeholder to the standard row height. A bare
            // `Color.clear` would absorb extra vertical space and make rows
            // with hidden outside-month days taller than the others.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: metrics.rowHeight)
        } else if day.isToday && knocksOutToday {
            todayKnockout
                .frame(maxWidth: .infinity, minHeight: metrics.rowHeight)
        } else {
            number
                .foregroundStyle(numberStyle)
                .frame(maxWidth: .infinity, minHeight: metrics.rowHeight)
                .background {
                    if day.isToday {
                        Circle()
                            .fill(.red)
                            .frame(width: metrics.todayCircle, height: metrics.todayCircle)
                    }
                }
        }
    }

    // `verbatim` keeps day numbers as ASCII digits in every locale,
    // matching the grid's fixed monospaced-digit metrics.
    private var number: Text {
        Text(verbatim: "\(day.number)")
            .font(.system(size: metrics.day, weight: .semibold).monospacedDigit())
    }

    /// On macOS 26+ a dimmed (vibrant) or tinted (accented) desktop widget
    /// flattens colour to luminance, so the red circle turned a muddy grey
    /// behind white text. There the circle takes the primary style and the
    /// number is cut out of it, as the system Calendar widget does.
    private var knocksOutToday: Bool {
        guard #available(macOS 26, *) else { return false }
        return renderingMode != .fullColor
    }

    private var todayKnockout: some View {
        Circle()
            .fill(.primary)
            .frame(width: metrics.todayCircle, height: metrics.todayCircle)
            .overlay {
                number.blendMode(.destinationOut)
            }
            .compositingGroup()
            .widgetAccentable()
    }

    private var numberStyle: AnyShapeStyle {
        if day.isToday {
            AnyShapeStyle(.white)
        } else if day.isOutsideMonth {
            AnyShapeStyle(.tertiary)
        } else {
            AnyShapeStyle(isWeekend ? .secondary : .primary)
        }
    }
}
