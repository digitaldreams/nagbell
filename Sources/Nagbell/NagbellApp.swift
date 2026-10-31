import AppKit
import AVFoundation
import NagbellCore
import SwiftUI

@main
struct NagbellApp: App {
    @State private var model = TimerModel()

    var body: some Scene {
        Window("Nagbell", id: "main") {
            ContentView(model: model)
        }
        .windowLevel(.floating)
        .windowResizability(.contentSize)
    }
}

@MainActor @Observable
final class TimerModel {
    var presets: [Preset] {
        didSet {
            do { try store.save(presets); saveError = nil } catch { saveError = "Couldn't save: \(error.localizedDescription)" }
        }
    }
    var timers: [RunningTimer] {
        didSet {
            keepAwake(!timers.isEmpty)
            do { try timerStore.save(timers) } catch { saveError = "Couldn't save timers: \(error.localizedDescription)" }
        }
    }
    var now = Date()
    var saveError: String?
    let sounds = soundNames(in: soundFolders)
    var soundName = UserDefaults.standard.string(forKey: "alarmSound") ?? "Glass" {
        didSet {
            UserDefaults.standard.set(soundName, forKey: "alarmSound")
            NSSound(named: oldValue)?.stop()
            NSSound(named: soundName)?.play() // preview
        }
    }
    var speak = UserDefaults.standard.bool(forKey: "speakReminder") {
        didSet { UserDefaults.standard.set(speak, forKey: "speakReminder") }
    }

    let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }.sorted { $0.name < $1.name }
    /// Default Rishi (male, Indian English). Siri voices aren't offered: apps can't reliably use them.
    var voiceID = UserDefaults.standard.string(forKey: "voice") ?? "com.apple.voice.compact.en-IN.Rishi" {
        didSet {
            UserDefaults.standard.set(voiceID, forKey: "voice")
            say(friendlyReminder(user: NSFullUserName(), reminders: [("Motor Off", "")])) // preview
        }
    }

    var anyDue: Bool { timers.contains { $0.isDue(at: now) } }

    private let store = PresetStore.standard
    private let timerStore = TimerStore.standard
    private weak var window: NSWindow?
    private var awake: NSObjectProtocol?
    private let voice = AVSpeechSynthesizer()
    private var chimes = 0

    init() {
        presets = store.load()
        timers = timerStore.load() // overdue ones ring right away
        let ticker = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        ticker.tolerance = 0.2 // lets macOS batch wakeups; the countdown still looks steady
        RunLoop.main.add(ticker, forMode: .common) // .common: keeps ticking while a menu is open
        keepAwake(!timers.isEmpty) // didSet doesn't run inside init
    }

    func start(_ preset: Preset) {
        now = Date() // tick skips updating `now` while idle, so refresh it before the countdown shows
        timers.append(RunningTimer(preset: preset, now: now))
    }
    func remove(_ timer: RunningTimer) { timers.removeAll { $0.id == timer.id } }
    func snooze(_ timer: RunningTimer) {
        guard let i = timers.firstIndex(where: { $0.id == timer.id }) else { return }
        timers[i].snooze(minutes: 5, now: Date())
    }

    func upsert(_ preset: Preset) {
        if let i = presets.firstIndex(where: { $0.id == preset.id }) { presets[i] = preset } else { presets.append(preset) }
    }

    func attach(_ window: NSWindow) {
        self.window = window
        window.styleMask.remove(.closable) // closing would hide running timers; quit with ⌘Q instead
        window.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
    }

    private func tick() {
        // Idle: don't touch `now`, otherwise the window redraws every second all day.
        guard !timers.isEmpty else { chimes = 0; return }
        let previous = now
        now = Date()
        if timers.contains(where: { $0.becameDue(from: previous, to: now) }) {
            window?.deminiaturize(nil)
            window?.orderFrontRegardless()
            NSApp.activate()
            NSApp.requestUserAttention(.criticalRequest)
        }
        // Two chimes, then the voice, repeat. Waits for each to finish so they never overlap.
        let sound = alarmSound(named: soundName)
        if !anyDue { chimes = 0 }
        if anyDue, sound?.isPlaying != true, !voice.isSpeaking {
            if speak, chimes >= 2 {
                let text = friendlyReminder(user: NSFullUserName(), reminders: timers.filter { $0.isDue(at: now) }.map { ($0.name, $0.details) })
                say(text)
                chimes = 0
            } else {
                sound?.play()
                chimes += 1
            }
        }
    }

    private func say(_ text: String) {
        voice.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: voiceID) // ponytail: missing voice falls back to the system default
        voice.speak(utterance)
    }

    /// Stops idle sleep and App Nap while timers run, otherwise a sleeping Mac mini never rings.
    private func keepAwake(_ on: Bool) {
        if on, awake == nil {
            awake = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Reminder timers running")
        } else if !on, let activity = awake {
            ProcessInfo.processInfo.endActivity(activity)
            awake = nil
        }
    }
}
