import AppKit
import Foundation
import Testing
@testable import GargoyleCore

/// Renders each state to `creatures/octopus/previews/`. Off by default — set
/// `GARGOYLE_RENDER_PREVIEWS=1` to regenerate.
///
/// Worth having: the 48px squint test is the only one that really matters for a creature,
/// and you can't run it on an assertion.
@MainActor
@Test(.enabled(if: ProcessInfo.processInfo.environment["GARGOYLE_RENDER_PREVIEWS"] == "1"))
func renderPreviews() throws {
  let cases: [(String, CreatureInputs)] = [
    ("asleep", CreatureInputs(state: 0, load: 0, blocked: 0, mood: 0)),
    ("idle", CreatureInputs(state: 1, load: 0, blocked: 0, mood: 0)),
    ("working-3", CreatureInputs(state: 2, load: 3, blocked: 0, mood: 0.3)),
    ("working-7", CreatureInputs(state: 2, load: 7, blocked: 0, mood: 0.95)),
    ("needs-you", CreatureInputs(state: 3, load: 4, blocked: 1, mood: 0.5)),
    ("unknown", CreatureInputs(state: 8, load: 0, blocked: 0, mood: 0)),
  ]

  var root = URL(fileURLWithPath: #filePath)
  for _ in 0..<4 { root.deleteLastPathComponent() }
  let out = root.appending(path: "creatures/octopus/previews")
  try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

  for (name, inputs) in cases {
    for (suffix, side) in [("", 220.0), ("@48", 48.0)] {
      let view = OctopusView(frame: NSRect(x: 0, y: 0, width: side, height: side))
      var withGaze = inputs
      withGaze.gazeX = 0.4
      withGaze.gazeY = 0.2
      view.pose = .from(withGaze)

      guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
      view.cacheDisplay(in: view.bounds, to: rep)
      guard let png = rep.representation(using: .png, properties: [:]) else { continue }
      try png.write(to: out.appending(path: "\(name)\(suffix).png"))
    }
  }
  print("wrote previews to \(out.path)")
}
