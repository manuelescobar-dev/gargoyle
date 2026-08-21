import AVFoundation
import AppKit
import Carbon.HIToolbox
import Speech

/// Hold a key, say the thing.
///
/// Some answers are faster spoken than typed — a gym set, a meal, a quick question — and
/// the creature is already the thing you'd be talking to.
///
/// Carbon's `RegisterEventHotKey` rather than a global `NSEvent` monitor, because the
/// monitor needs Accessibility permission and this doesn't. Recognition is on-device;
/// nothing here goes to a server.
@MainActor
public final class PushToTalk {
  /// ⌥Space. Held, not tapped — nothing starts listening because you brushed a key.
  private static let keyCode = UInt32(kVK_Space)
  private static let modifiers = UInt32(optionKey)

  private let onStart: () -> Void
  private let onFinish: (String?) -> Void

  private var hotKey: EventHotKeyRef?
  private var handler: EventHandlerRef?

  private let recognizer = SFSpeechRecognizer()
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private let engine = AVAudioEngine()
  private var heard = ""

  public init(onStart: @escaping () -> Void, onFinish: @escaping (String?) -> Void) {
    self.onStart = onStart
    self.onFinish = onFinish
  }

  /// Permission is asked for on first use, not at launch — a creature that demands the
  /// microphone the moment it appears is a creature people delete.
  public func start() {
    var eventTypes = [
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
    ]

    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, context in
        guard let context else { return noErr }
        let me = Unmanaged<PushToTalk>.fromOpaque(context).takeUnretainedValue()

        var kind = UInt32(0)
        if let event { kind = GetEventKind(event) }
        MainActor.assumeIsolated {
          kind == UInt32(kEventHotKeyPressed) ? me.beginListening() : me.endListening()
        }
        return noErr
      },
      2,
      &eventTypes,
      Unmanaged.passUnretained(self).toOpaque(),
      &handler
    )

    var id = EventHotKeyID(signature: OSType(0x4741_5247), id: 1) // 'GARG'
    let status = RegisterEventHotKey(
      Self.keyCode, Self.modifiers, id, GetApplicationEventTarget(), 0, &hotKey
    )
    Trace.log(status == noErr ? "push-to-talk: ⌥Space registered" : "push-to-talk: hotkey unavailable (\(status))")
  }

  public func stop() {
    if let hotKey { UnregisterEventHotKey(hotKey) }
    if let handler { RemoveEventHandler(handler) }
    hotKey = nil
    handler = nil
  }

  private func beginListening() {
    guard task == nil else { return }

    SFSpeechRecognizer.requestAuthorization { [weak self] status in
      guard status == .authorized else {
        Trace.log("push-to-talk: speech not authorised (\(status.rawValue))")
        return
      }
      MainActor.assumeIsolated { self?.listen() }
    }
  }

  private func listen() {
    guard let recognizer, recognizer.isAvailable else {
      Trace.log("push-to-talk: no recogniser available")
      return
    }

    heard = ""
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    // On-device where the machine supports it: what you say to a creature on your desk
    // has no business leaving it.
    request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
    self.request = request

    let input = engine.inputNode
    input.removeTap(onBus: 0)
    input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
      request.append(buffer)
    }

    engine.prepare()
    do {
      try engine.start()
    } catch {
      Trace.log("push-to-talk: microphone unavailable — \(error)")
      return
    }

    onStart()
    task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
      guard let result else { return }
      MainActor.assumeIsolated { self?.heard = result.bestTranscription.formattedString }
    }
  }

  private func endListening() {
    guard task != nil else { return }

    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    request?.endAudio()

    // A moment for the recogniser to finish the last word before we take what it heard.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.task?.cancel()
        self.task = nil
        self.request = nil

        let said = self.heard.trimmingCharacters(in: .whitespacesAndNewlines)
        Trace.log("push-to-talk: heard \(said.isEmpty ? "(nothing)" : said)")
        self.onFinish(said.isEmpty ? nil : said)
      }
    }
  }
}
