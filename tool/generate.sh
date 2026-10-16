#!/bin/sh
# Regenerates the channel from pigeons/messages.dart.
#
# Pigeon writes its method codec as a plain global `var`, which Swift 6 rejects
# as shared mutable state. It is written once and only read after that, so it is
# marked `nonisolated(unsafe)` here instead of dropping the plugin to Swift 5.
# Flutter's headers predate Swift concurrency (`FlutterEndOfEventStream`), so
# the generated file imports them `@preconcurrency`. An `@async` handler hands
# the API and Flutter's reply to a main-actor task; both live on the main thread
# already, which Swift cannot see through Flutter's untyped callbacks.
set -e
cd "$(dirname "$0")/.."
dart run pigeon --input pigeons/messages.dart
swift=ios/alarm_kit/Sources/alarm_kit/Messages.g.swift
sed -i.bak \
  -e 's/^var messagesPigeonMethodCodec/nonisolated(unsafe) var messagesPigeonMethodCodec/' \
  -e 's/^  import Flutter$/  @preconcurrency import Flutter/' \
  -e 's/^        Task { @MainActor in$/        nonisolated(unsafe) let (api, reply) = (api, reply)\
        Task { @MainActor in/' \
  "$swift"
rm -f "$swift.bak"
dart format lib/src/messages.g.dart >/dev/null
