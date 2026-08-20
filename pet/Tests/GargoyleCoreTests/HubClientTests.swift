import Foundation
import Testing
@testable import GargoyleCore

/// Stands in for the hub so these stay deterministic — no ports, no timing, no flakes.
private final class StubProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var respond: @Sendable () -> (Int, Data)? = { nil }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func stopLoading() {}

  override func startLoading() {
    guard let (status, body) = Self.respond() else {
      client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
      return
    }
    let response = HTTPURLResponse(
      url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
    )!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: body)
    client?.urlProtocolDidFinishLoading(self)
  }
}

private func client(_ respond: @escaping @Sendable () -> (Int, Data)?) -> HubClient {
  StubProtocol.respond = respond
  let config = URLSessionConfiguration.ephemeral
  config.protocolClasses = [StubProtocol.self]
  return HubClient(session: URLSession(configuration: config))
}

private let valid = #"{"state":"working","embers":[],"mood":0,"blocked":0}"#.data(using: .utf8)!

/// Serialized: the stub's response is process-wide state, so running these in
/// parallel has them answering each other's requests.
@Suite(.serialized)
struct HubClientTests {
  @Test("a healthy hub yields a snapshot")
  func healthy() async {
    let snapshot = await client { (200, valid) }.fetch()
    #expect(snapshot?.state == .working)
  }

  // Every one of these must produce nil. The pet doesn't care *why* it can't see the
  // hub — only that it can't. Pretending otherwise is how a status display starts lying.
  @Test("an unreachable hub yields nil")
  func unreachable() async {
    #expect(await client { nil }.fetch() == nil)
  }

  @Test("a 500 yields nil")
  func serverError() async {
    #expect(await client { (500, valid) }.fetch() == nil)
  }

  @Test("a 200 with a garbage body yields nil")
  func garbageBody() async {
    #expect(await client { (200, Data("<html>nope</html>".utf8)) }.fetch() == nil)
  }

  @Test("an empty 200 yields nil")
  func emptyBody() async {
    #expect(await client { (200, Data()) }.fetch() == nil)
  }

  @Test("every failure mode presents as unreachable, never as quiet")
  func failuresNeverLookIdle() async {
    let quiet = MenuBarPresentation.from(
      Snapshot(state: .idle, embers: [], mood: 0, blocked: 0)
    )
    for response in [nil, (500, valid), (200, Data())] as [(Int, Data)?] {
      let presentation = MenuBarPresentation.from(await client { response }.fetch())
      #expect(presentation != quiet)
      #expect(presentation.summary == "hub unreachable")
    }
  }
}
