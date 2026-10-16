import SwiftUI
import WidgetKit

@main
struct AlarmWidgetsBundle: WidgetBundle {
  var body: some Widget {
    if #available(iOSApplicationExtension 26.0, *) {
      AlarmLiveActivity()
    }
  }
}
