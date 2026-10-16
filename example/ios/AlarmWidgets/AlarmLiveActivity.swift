import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

/// The countdown of an alarm_kit timer on the lock screen and in the Dynamic
/// Island. A starting point: the system draws the ringing alert itself, this
/// extension draws the countdown and the paused state.
///
/// Add it to the extension's `WidgetBundle`:
///
/// ```swift
/// if #available(iOSApplicationExtension 26.0, *) {
///   AlarmLiveActivity()
/// }
/// ```
@available(iOS 26.0, *)
struct AlarmLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: AlarmAttributes<AlarmKitMetadata>.self) { context in
      HStack {
        Text(title(context))
          .font(.headline)
        Spacer()
        clock(context.state)
          .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
          .foregroundStyle(context.attributes.tintColor)
      }
      .padding()
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(title(context)).font(.headline)
        }
        DynamicIslandExpandedRegion(.trailing) {
          clock(context.state)
            .font(.title2.monospacedDigit())
            .foregroundStyle(context.attributes.tintColor)
        }
      } compactLeading: {
        Image(systemName: "timer").foregroundStyle(context.attributes.tintColor)
      } compactTrailing: {
        clock(context.state)
          .monospacedDigit()
          .frame(maxWidth: 52)
          .foregroundStyle(context.attributes.tintColor)
      } minimal: {
        Image(systemName: "timer").foregroundStyle(context.attributes.tintColor)
      }
    }
  }

  private func title(_ context: ActivityViewContext<AlarmAttributes<AlarmKitMetadata>>)
    -> LocalizedStringResource
  {
    let presentation = context.attributes.presentation
    switch context.state.mode {
    case .paused: return presentation.paused?.title ?? presentation.alert.title
    case .countdown: return presentation.countdown?.title ?? presentation.alert.title
    default: return presentation.alert.title
    }
  }

  @ViewBuilder
  private func clock(_ state: AlarmPresentationState) -> some View {
    switch state.mode {
    case .countdown(let countdown):
      Text(timerInterval: Date.now...countdown.fireDate, countsDown: true)
    case .paused(let paused):
      Text(
        Duration.seconds(paused.totalCountdownDuration - paused.previouslyElapsedDuration),
        format: .time(pattern: .minuteSecond))
    default:
      Text(verbatim: "0:00")
    }
  }
}
