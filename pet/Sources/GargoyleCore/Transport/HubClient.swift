import Foundation

/// Reads the hub's snapshot over HTTP.
///
/// M0 only. Issue #8 replaces polling with the push socket, at which point the
/// pet stops asking and starts being told.
public struct HubClient: Sendable {
  private let url: URL
  private let session: URLSession

  public init(host: String = "127.0.0.1", port: Int = 7373, session: URLSession? = nil) {
    url = URL(string: "http://\(host):\(port)/state")!

    // Shorter than the poll interval on purpose: a hung hub must not stack up
    // requests, and a stalled read is indistinguishable from an absent hub anyway.
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 1.5
    self.session = session ?? URLSession(configuration: config)
  }

  /// `nil` for every failure mode — refused, timed out, garbage body, wrong status.
  /// The pet doesn't care *why* it can't see the hub, only that it can't, and pretending
  /// otherwise is how a status display ends up lying.
  public func fetch() async -> Snapshot? {
    guard let (data, response) = try? await session.data(from: url),
          (response as? HTTPURLResponse)?.statusCode == 200,
          let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
    else { return nil }
    return snapshot
  }
}
