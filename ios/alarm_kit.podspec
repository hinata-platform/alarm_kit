Pod::Spec.new do |s|
  s.name             = 'alarm_kit'
  s.version          = '0.1.0'
  s.summary          = 'AlarmKit for Flutter: alarms and timers on iOS and iPadOS 26.'
  s.description      = <<-DESC
Alarms and timers that ring through silent mode and Focus, with the system's
countdown Live Activity. AlarmKit needs no entitlement, only
NSAlarmKitUsageDescription in the app's Info.plist.
                       DESC
  s.homepage         = 'https://github.com/hinata-platform/alarm_kit'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Rebar Ahmad' => 'rebar.ahmad@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'alarm_kit/Sources/alarm_kit/**/*.swift'
  s.resource_bundles = { 'alarm_kit_privacy' => ['alarm_kit/Sources/alarm_kit/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  # AlarmKit exists from iOS 26 on; below that the plugin answers "unsupported".
  s.weak_frameworks = 'AlarmKit'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '6.0'
end
