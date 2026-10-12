import SwiftUI
import UIKit

/// Sizes in the dashboard that depend on the text inside them.
///
/// The cards decide how many rows fit by dividing the card's height by a row's height, so the row
/// height has to grow when the person's text size does, or the rows are drawn at a size that clips
/// their own text and the "+N more" line prints over the last row. `scaled` gives a value as it should
/// be at the current text size; at the default size it is the number it was designed at.
enum DashboardMetrics {
    /// The space between Today cards: tighter on the iPhone, where every point of the screen counts, than on the
    /// iPad's grid. The iPhone's Large card is two cells and one gap tall, so the gap is shared with its layout.
    static let phoneGap: CGFloat = 8
    static let gridGap: CGFloat = 12

    static func scaled(_ designed: CGFloat, _ style: UIFont.TextStyle = .subheadline) -> CGFloat {
        UIFontMetrics(forTextStyle: style).scaledValue(for: designed)
    }

    /// The very largest text sizes (the Accessibility sizes in Settings → Accessibility → Display & Text
    /// Size). Cards stop trying to sit two across, because there is no room in half a screen.
    static func usesAccessibilityLayout(_ size: DynamicTypeSize) -> Bool {
        size.isAccessibilitySize
    }
}
