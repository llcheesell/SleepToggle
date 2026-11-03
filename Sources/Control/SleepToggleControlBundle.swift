import SwiftUI
import WidgetKit

/// ControlWidget は Widget を継承していないが、WidgetBundle に入れると
/// _ControlWidgetAdaptor が自動で橋渡しする。
@main
struct SleepToggleControlBundle: WidgetBundle {
    var body: some Widget {
        SleepToggleControl()
    }
}
