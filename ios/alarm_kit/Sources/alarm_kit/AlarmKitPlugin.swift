import ActivityKit
import AlarmKit
import AppIntents
import Flutter
import SwiftUI
import UIKit

/// The Flutter side of AlarmKit (iOS and iPadOS 26).
///
/// Below iOS 26 every call answers `unsupported` and the streams stay silent,
/// so an app can call into the plugin on any version without guarding it.
public final class AlarmKitPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    AlarmKitHostApiSetup.setUp(binaryMessenger: messenger, api: AlarmKitHost())
    AlarmUpdatesStreamHandler.register(with: messenger, streamHandler: AlarmUpdatesHandler())
    AuthorizationUpdatesStreamHandler.register(
      with: messenger, streamHandler: AuthorizationUpdatesHandler())
  }
}

/// The app's buttons for an alarm.
///
/// AlarmKit runs a `LiveActivityIntent` when the stop or the secondary button
/// is pressed, in the app's process, also when the app is not running. Swift
/// types do not cross the channel, so Dart names a key for each button and the
/// app maps the key to one of its own intents here, before the first alarm is
/// scheduled (in `application(_:didFinishLaunchingWithOptions:)`):
///
/// ```swift
/// AlarmKitIntents.register { key in
///   switch key {
///   case "stop": return StopTimerIntent()
///   default: return nil
///   }
/// }
/// ```
///
/// Without a provider, or for a key it does not know, the button only does what
/// the system does: it silences the alarm.
public enum AlarmKitIntents {
  nonisolated(unsafe) private static var provider: ((String) -> Any?)?

  @available(iOS 17.0, *)
  public static func register(_ provider: @escaping (String) -> (any LiveActivityIntent)?) {
    self.provider = { key in provider(key) }
  }

  @available(iOS 17.0, *)
  static func intent(_ key: String?) -> (any LiveActivityIntent)? {
    guard let key else { return nil }
    return provider?(key) as? any LiveActivityIntent
  }
}

/// What the widget extension knows about an alarm besides its presentation.
  ///
/// One optional word the app chooses, nothing else, because the system keeps
/// this outside the app for as long as the alarm exists. The extension needs
/// the same type, under the same name: copy `AlarmKitMetadata.swift` from the
/// package's `ios/Templates` into it (`dart run alarm_kit:setup`).
@available(iOS 26.0, *)
public struct AlarmKitMetadata: AlarmMetadata {
  public var kind: String?

  public init(kind: String? = nil) {
    self.kind = kind
  }
}

private func unsupported() -> PigeonError {
  PigeonError(code: "unsupported", message: "AlarmKit needs iOS or iPadOS 26.", details: nil)
}

private final class AlarmKitHost: AlarmKitHostApi {
  func isSupported() throws -> Bool {
    if #available(iOS 26.0, *) { return true }
    return false
  }

  func authorizationState() throws -> AuthorizationMessage {
    guard #available(iOS 26.0, *) else { throw unsupported() }
    return AlarmManager.shared.authorizationState.message
  }

  func requestAuthorization() async throws -> AuthorizationMessage {
    guard #available(iOS 26.0, *) else { throw unsupported() }
    do {
      return try await AlarmManager.shared.requestAuthorization().message
    } catch {
      throw failure(error)
    }
  }

  func schedule(configuration: ConfigurationMessage) async throws -> AlarmMessage {
    guard #available(iOS 26.0, *) else { throw unsupported() }
    guard let id = UUID(uuidString: configuration.id) else {
      throw PigeonError(code: "invalidId", message: "Not a UUID: \(configuration.id)", details: nil)
    }
    do {
      let alarm = try await AlarmManager.shared.schedule(
        id: id, configuration: configuration.alarmConfiguration())
      return alarm.message
    } catch {
      throw failure(error)
    }
  }

  func countdown(id: String) throws {
    guard #available(iOS 26.0, *) else { throw unsupported() }
    try act(id) { try AlarmManager.shared.countdown(id: $0) }
  }

  func cancel(id: String) throws {
    guard #available(iOS 26.0, *) else { throw unsupported() }
    try act(id) { try AlarmManager.shared.cancel(id: $0) }
  }

  func stop(id: String) throws {
    guard #available(iOS 26.0, *) else { throw unsupported() }
    try act(id) { try AlarmManager.shared.stop(id: $0) }
  }

  func pause(id: String) throws {
    guard #available(iOS 26.0, *) else { throw unsupported() }
    try act(id) { try AlarmManager.shared.pause(id: $0) }
  }

  func resume(id: String) throws {
    guard #available(iOS 26.0, *) else { throw unsupported() }
    try act(id) { try AlarmManager.shared.resume(id: $0) }
  }

  func alarms() throws -> [AlarmMessage] {
    guard #available(iOS 26.0, *) else { throw unsupported() }
    do {
      return try AlarmManager.shared.alarms.map(\.message)
    } catch {
      throw failure(error)
    }
  }

  private func act(_ raw: String, _ body: (UUID) throws -> Void) throws {
    guard let id = UUID(uuidString: raw) else {
      throw PigeonError(code: "invalidId", message: "Not a UUID: \(raw)", details: nil)
    }
    do {
      try body(id)
    } catch {
      throw failure(error)
    }
  }

  /// The limit of alarms per app is not published; it gets a code of its own
  /// so an app can tell the person instead of failing quietly.
  private func failure(_ error: Error) -> PigeonError {
    if #available(iOS 26.0, *),
      let alarmError = error as? AlarmManager.AlarmError,
      alarmError == .maximumLimitReached
    {
      return PigeonError(
        code: "maximumLimitReached", message: "The system holds no more alarms for this app.",
        details: nil)
    }
    return PigeonError(code: "failed", message: String(describing: error), details: nil)
  }
}

/// `alarmUpdates` as a stream: one long-lived task per listener, ended when
/// Dart cancels.
private final class AlarmUpdatesHandler: AlarmUpdatesStreamHandler {
  private var task: Task<Void, Never>?

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<AlarmListMessage>) {
    task?.cancel()
    guard #available(iOS 26.0, *) else { return }
    // Flutter calls in on the main thread and the task stays there.
    nonisolated(unsafe) let sink = sink
    task = Task { @MainActor in
      for await alarms in AlarmManager.shared.alarmUpdates {
        if Task.isCancelled { break }
        sink.success(AlarmListMessage(alarms: alarms.map(\.message)))
      }
    }
  }

  override func onCancel(withArguments arguments: Any?) {
    task?.cancel()
    task = nil
  }
}

private final class AuthorizationUpdatesHandler: AuthorizationUpdatesStreamHandler {
  private var task: Task<Void, Never>?

  override func onListen(
    withArguments arguments: Any?, sink: PigeonEventSink<AuthorizationUpdateMessage>
  ) {
    task?.cancel()
    guard #available(iOS 26.0, *) else { return }
    // Flutter calls in on the main thread and the task stays there.
    nonisolated(unsafe) let sink = sink
    task = Task { @MainActor in
      for await state in AlarmManager.shared.authorizationUpdates {
        if Task.isCancelled { break }
        sink.success(AuthorizationUpdateMessage(state: state.message))
      }
    }
  }

  override func onCancel(withArguments arguments: Any?) {
    task?.cancel()
    task = nil
  }
}

// MARK: - Messages to AlarmKit

@available(iOS 26.0, *)
private func color(_ argb: Int64) -> Color {
  let value = UInt32(truncatingIfNeeded: argb)
  return Color(
    .sRGB,
    red: Double((value >> 16) & 0xFF) / 255,
    green: Double((value >> 8) & 0xFF) / 255,
    blue: Double(value & 0xFF) / 255,
    opacity: Double((value >> 24) & 0xFF) / 255)
}

/// The app's own words, already in the reader's language.
@available(iOS 26.0, *)
private func localized(_ value: String) -> LocalizedStringResource {
  LocalizedStringResource(stringLiteral: value)
}

@available(iOS 26.0, *)
extension ButtonMessage {
  var button: AlarmButton {
    AlarmButton(text: localized(self.text), textColor: color(textColor), systemImageName: systemImageName)
  }
}

@available(iOS 26.0, *)
extension PresentationMessage {
  var presentation: AlarmPresentation {
    let behavior: AlarmPresentation.Alert.SecondaryButtonBehavior? =
      switch alert.secondaryBehavior {
      case .countdown: .countdown
      case .custom: .custom
      case nil: nil
      }
    // The stop button is optional only from iOS 26.1 on; Dart always sends one.
    let alertPart = AlarmPresentation.Alert(
      title: localized(alert.title), stopButton: alert.stopButton.button,
      secondaryButton: alert.secondaryButton?.button, secondaryButtonBehavior: behavior)
    return AlarmPresentation(
      alert: alertPart,
      countdown: countdown.map {
        AlarmPresentation.Countdown(title: localized($0.title), pauseButton: $0.pauseButton?.button)
      },
      paused: paused.map {
        AlarmPresentation.Paused(title: localized($0.title), resumeButton: $0.resumeButton.button)
      })
  }
}

@available(iOS 26.0, *)
extension ScheduleMessage {
  var schedule: Alarm.Schedule? {
    if let fixedMillis {
      return .fixed(Date(timeIntervalSince1970: Double(fixedMillis) / 1000))
    }
    guard let hour, let minute else { return nil }
    let days: [Locale.Weekday] = (weekdays ?? []).compactMap { day in
      switch day {
      case 1: .sunday
      case 2: .monday
      case 3: .tuesday
      case 4: .wednesday
      case 5: .thursday
      case 6: .friday
      case 7: .saturday
      default: nil
      }
    }
    return .relative(
      Alarm.Schedule.Relative(
        time: .init(hour: Int(hour), minute: Int(minute)),
        repeats: days.isEmpty ? .never : .weekly(days)))
  }
}

@available(iOS 26.0, *)
extension ConfigurationMessage {
  func alarmConfiguration() -> AlarmManager.AlarmConfiguration<AlarmKitMetadata> {
    let attributes = AlarmAttributes<AlarmKitMetadata>(
      presentation: presentation.presentation,
      metadata: metadataKind.map { AlarmKitMetadata(kind: $0) },
      tintColor: color(tintColor))
    let alertSound: AlertConfiguration.AlertSound = sound.map { .named($0) } ?? .default
    let countdownDuration =
      preAlert == nil && postAlert == nil
      ? nil : Alarm.CountdownDuration(preAlert: preAlert, postAlert: postAlert)
    return AlarmManager.AlarmConfiguration(
      countdownDuration: countdownDuration,
      schedule: schedule?.schedule,
      attributes: attributes,
      stopIntent: AlarmKitIntents.intent(stopIntent),
      secondaryIntent: AlarmKitIntents.intent(secondaryIntent),
      sound: alertSound)
  }
}

// MARK: - AlarmKit to messages

@available(iOS 26.0, *)
extension AlarmManager.AuthorizationState {
  var message: AuthorizationMessage {
    switch self {
    case .notDetermined: .notDetermined
    case .denied: .denied
    case .authorized: .authorized
    @unknown default: .notDetermined
    }
  }
}

@available(iOS 26.0, *)
extension Alarm {
  var message: AlarmMessage {
    let state: AlarmStateMessage =
      switch self.state {
      case .scheduled: .scheduled
      case .countdown: .countdown
      case .paused: .paused
      case .alerting: .alerting
      @unknown default: .scheduled
      }
    return AlarmMessage(
      id: id.uuidString.lowercased(), state: state,
      preAlert: countdownDuration?.preAlert, postAlert: countdownDuration?.postAlert,
      schedule: schedule?.message)
  }
}

@available(iOS 26.0, *)
extension Alarm.Schedule {
  var message: ScheduleMessage {
    switch self {
    case .fixed(let date):
      return ScheduleMessage(fixedMillis: Int64(date.timeIntervalSince1970 * 1000))
    case .relative(let relative):
      let days: [Int64]
      switch relative.repeats {
      case .weekly(let weekdays):
        days = weekdays.map { day in
          switch day {
          case .sunday: 1
          case .monday: 2
          case .tuesday: 3
          case .wednesday: 4
          case .thursday: 5
          case .friday: 6
          case .saturday: 7
          @unknown default: 0
          }
        }
      default:
        days = []
      }
      return ScheduleMessage(
        hour: Int64(relative.time.hour), minute: Int64(relative.time.minute), weekdays: days)
    @unknown default:
      return ScheduleMessage()
    }
  }
}
