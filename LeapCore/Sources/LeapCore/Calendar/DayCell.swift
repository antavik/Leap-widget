import SwiftUI

struct DayCell: View {
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
        } else {
            // `verbatim` keeps day numbers as ASCII digits in every locale,
            // matching the grid's fixed monospaced-digit metrics.
            Text(verbatim: "\(day.number)")
                .font(.system(size: metrics.day, weight: .semibold).monospacedDigit())
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
