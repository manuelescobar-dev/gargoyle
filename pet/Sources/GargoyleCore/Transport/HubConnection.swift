import Foundation

/// Drives `HubState` from the hub's WebSocket, and keeps trying to get back.
///
/// All the behaviour worth testing lives in `HubState`. This is the part that can only
/// be verified by running it against a real hub.
@MainActor
public final class HubConnection {
  private let url: URL
  private let onChange: (Snapshot?) -> Void
  private let onSay: (String) -> Void
  private let onMenu: (Menu) -> Void
  private var everConnected = false
  private var state = HubState()
  private var task: URLSessionWebSocketTask?

  /// Backs off so a hub that's down doesn't mean a reconnect attempt every frame,
  /// but stays fast enough that starting the hub feels instant.
  private var retryDelay: Duration = .milliseconds(250)
  private static let maxRetryDelay: Duration = .seconds(10)

  public init(
    host: String = "127.0.0.1",
    port: Int = 7373,
    onChange: @escaping (Snapshot?) -> Void,
    onSay: @escaping (String) -> Void = { _ in },
    onMenu: @escaping (Menu) -> Void = { _ in }
  ) {
    url = URL(string: "ws://\(host):\(port)/socket")!
    self.onChange = onChange
    self.onSay = onSay
    self.onMenu = onMenu
  }

  public func start() {
    // Until a socket is actually open we don't know anything, and saying so is the point.
    onChange(state.latest)
    onMenu(state.menu)
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

          guard let data else { continue }
          let changed = self.state.received(data)
          self.retryDelay = .milliseconds(250)  // any good frame means we're healthy again

          if changed { self.onChange(self.state.latest) }
          self.onMenu(self.state.menu)
          if let situation = self.state.takeSituation() { self.onSay(situation) }

          // Coming back after being away is the one moment it greets you unprompted.
          if !self.everConnected {
            self.everConnected = true
            self.onSay("greeting")
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
