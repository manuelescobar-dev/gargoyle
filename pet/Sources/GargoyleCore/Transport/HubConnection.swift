import Foundation

/// Drives `HubState` from the hub's WebSocket, and keeps trying to get back.
///
/// All the behaviour worth testing lives in `HubState`. This is the part that can only
/// be verified by running it against a real hub.
@MainActor
public final class HubConnection {
  private let url: URL
  private let onChange: (Snapshot?) -> Void
  private var state = HubState()
  private var task: URLSessionWebSocketTask?

  /// Backs off so a hub that's down doesn't mean a reconnect attempt every frame,
  /// but stays fast enough that starting the hub feels instant.
  private var retryDelay: Duration = .milliseconds(250)
  private static let maxRetryDelay: Duration = .seconds(10)

  public init(
    host: String = "127.0.0.1",
    port: Int = 7373,
    onChange: @escaping (Snapshot?) -> Void
  ) {
    url = URL(string: "ws://\(host):\(port)/socket")!
    self.onChange = onChange
  }

  public func start() {
    // Until a socket is actually open we don't know anything, and saying so is the point.
    onChange(state.latest)
    connect()
  }

  private func connect() {
    let task = URLSession.shared.webSocketTask(with: url)
    self.task = task
    task.resume()
    listen(on: task)
  }

  private func listen(on task: URLSessionWebSocketTask) {
    Task { [weak self] in
      do {
        while true {
          let message = try await task.receive()
          guard let self else { return }

          let data: Data? = switch message {
          case .data(let d): d
          case .string(let s): Data(s.utf8)
          @unknown default: nil
          }

          if let data, self.state.received(data) {
            self.retryDelay = .milliseconds(250)  // a good frame means we're healthy again
            self.onChange(self.state.latest)
          }
        }
      } catch {
        await self?.dropped()
      }
    }
  }

  private func dropped() async {
    task?.cancel()
    task = nil

    // Immediately, without waiting for a timeout or a missed poll. Whatever would have
    // told us the state changed is exactly what disappeared.
    state.dropped()
    onChange(state.latest)

    try? await Task.sleep(for: retryDelay)
    retryDelay = min(retryDelay * 2, Self.maxRetryDelay)
    connect()
  }
}
