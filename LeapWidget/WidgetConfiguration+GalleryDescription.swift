import WidgetKit
import SwiftUI

extension WidgetConfiguration {
    func galleryDescription(_ text: LocalizedStringResource) -> some WidgetConfiguration {
#if DEBUG
        description("\(String(localized: text))\n\(BuildStamp.current)")
#else
        description(text)
#endif
    }
}
