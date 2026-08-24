import Foundation

/// The dots the creature shows while it works on something you said.
///
/// They have to move. A static ellipsis is indistinguishable from a bubble that got stuck,
/// which is precisely the impression a silent minute already gives.
public enum Thinking {
  public static func dots(at time: Double) -> String {
    String(repeating: ".", count: Int(time * 2) % 3 + 1)
  }
}
