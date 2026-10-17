import XCTest

@testable import alarm_kit

/// The native half the app and its widget extension share: the metadata
/// ActivityKit matches by name and decodes in the extension.
class RunnerTests: XCTestCase {
  func testMetadataSurvivesTheTripToTheExtension() throws {
    guard #available(iOS 26.0, *) else { throw XCTSkip("AlarmKit needs iOS 26") }
    let sent = AlarmKitMetadata(kind: "work")
    let data = try JSONEncoder().encode(sent)
    let received = try JSONDecoder().decode(AlarmKitMetadata.self, from: data)
    XCTAssertEqual(received.kind, "work")
  }
}
