import Foundation
import Testing
@testable import GargoyleCore

/// The fixture both languages test against. The hub asserts it produces this shape;
/// the pet asserts it decodes it. Protocol drift can't ship silently.
private let fixture: Data = {
  var url = URL(fileURLWithPath: #filePath)
  for _ in 0..<4 { url.deleteLastPathComponent() }  // .../pet/Tests/GargoyleCoreTests/x.swift -> repo root
  return try! Data(contentsOf: url.appending(path: "protocol/fixtures/state.json"))
}()

@Test("decodes the shared protocol fixture")
func decodesFixture() throws {
  let s = try JSONDecoder().decode(Snapshot.self, from: fixture)
  #expect(s.state == .needsYou)
  #expect(s.embers.count == 3)
  #expect(s.blocked == 1)
  #expect(s.embers.map(\.label) == ["api-refactor", "gargoyle", "billing-fix"])
  #expect(s.embers.last?.status == .blocked)
  #expect(s.embers.first?.since != nil, "the surface needs this to rank by how long it's waited")
  #expect(s.attention == .badge, "the ladder travels with the state it applies to")
}

@Test("an attention level the pet has never heard of stays quiet")
func forwardCompatibleAttention() throws {
  let json = #"{"state":"idle","embers":[],"mood":0,"blocked":0,"attention":"klaxon"}"#.data(using: .utf8)!
  let s = try JSONDecoder().decode(Snapshot.self, from: json)
  #expect(s.attention == .silent, "an unknown level must never be louder than the quietest one")
}

@Test("a state the pet has never heard of degrades instead of crashing")
func forwardCompatibleState() throws {
  let json = #"{"state":"brooding","embers":[],"mood":0,"blocked":0}"#.data(using: .utf8)!
  let s = try JSONDecoder().decode(Snapshot.self, from: json)
  #expect(s.state == .unknown, "a hub newer than the pet must not be able to crash it")
}

@Test("an unrecognised ember status degrades too")
func forwardCompatibleStatus() throws {
  let json = #"{"state":"working","embers":[{"id":"a","label":"x","status":"reticulating"}],"mood":0,"blocked":0}"#
    .data(using: .utf8)!
  let s = try JSONDecoder().decode(Snapshot.self, from: json)
  #expect(s.embers.first?.status == .unrecognised)
}
