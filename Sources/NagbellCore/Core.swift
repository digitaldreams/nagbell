import Foundation

public struct Preset: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var name: String
    public var details: String
    public var minutes: Int

    public init(name: String, details: String = "", minutes: Int) {
        self.name = name
        self.details = details
        self.minutes = minutes
    }

    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (1...1440).contains(minutes)
    }

    public static let defaults = [
        Preset(name: "Motor Off", details: "Switch off the water motor", minutes: 20),
        Preset(name: "Milk", details: "Check the milk in the oven", minutes: 15),
    ]
}

public struct RunningTimer: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let name: String
    public let details: String
    public private(set) var dueAt: Date

    public init(preset: Preset, now: Date) {
        name = preset.name
        details = preset.details
        dueAt = now.addingTimeInterval(TimeInterval(preset.minutes * 60))
    }

    public func remaining(at now: Date) -> TimeInterval { max(0, dueAt.timeIntervalSince(now)) }
    public func isDue(at now: Date) -> Bool { now >= dueAt }

    /// True only on the tick that crosses the due time, so the alarm grabs attention once, not every second.
    public func becameDue(from previous: Date, to now: Date) -> Bool { !isDue(at: previous) && isDue(at: now) }

    public mutating func snooze(minutes: Int, now: Date) {
        dueAt = now.addingTimeInterval(TimeInterval(minutes * 60))
    }
}

/// Rounds up, so the display only shows 00:00 once the timer is actually due.
public func formatCountdown(_ seconds: TimeInterval) -> String {
    let s = Int(seconds.rounded(.up))
    let (h, m, sec) = (s / 3600, s % 3600 / 60, s % 60)
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
}

public struct PresetStore: Sendable {
    public let url: URL
    /// Where presets lived before the app was renamed; moved to `url` on first load.
    public let legacy: URL?

    public init(url: URL, legacy: URL? = nil) { self.url = url; self.legacy = legacy }

    public static let standard = PresetStore(
        url: URL.applicationSupportDirectory.appendingPathComponent("Nagbell/presets.json"),
        legacy: URL.applicationSupportDirectory.appendingPathComponent("StickyTimer/presets.json"))

    /// Missing file → defaults. Unreadable file → moved to presets.json.bak (never silently overwritten), defaults.
    public func load() -> [Preset] {
        if let legacy, !FileManager.default.fileExists(atPath: url.path), FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.moveItem(at: legacy, to: url)
        }
        guard let data = try? Data(contentsOf: url) else { return Preset.defaults }
        if let presets = try? JSONDecoder().decode([Preset].self, from: data) { return presets }
        let backup = url.appendingPathExtension("bak")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: url, to: backup)
        return Preset.defaults
    }

    public func save(_ presets: [Preset]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(presets).write(to: url, options: .atomic)
    }
}

/// Folders macOS's NSSound(named:) searches; drop an .aiff into ~/Library/Sounds to add your own.
public let soundFolders = [
    URL.libraryDirectory.appendingPathComponent("Sounds"),
    URL(fileURLWithPath: "/System/Library/Sounds"),
]

public func soundNames(in folders: [URL]) -> [String] {
    let audio: Set = ["aiff", "aif", "wav", "caf", "mp3", "m4a"]
    let files = folders.flatMap { (try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)) ?? [] }
    return Set(files.filter { audio.contains($0.pathExtension.lowercased()) }.map { $0.deletingPathExtension().lastPathComponent }).sorted()
}

/// What the voice says when reminders are due. `user` is the full name; only the first name is spoken.
/// Each reminder is spoken with its description; an empty description is skipped.
public func friendlyReminder(user: String, reminders: [(name: String, details: String)]) -> String {
    let first = user.split(separator: " ").first.map { " \($0)" } ?? ""
    func sentence(_ s: String) -> String {
        let s = s.trimmingCharacters(in: .whitespaces)
        return s.isEmpty || ".!?".contains(s.last!) ? s : s + "."
    }
    if reminders.count == 1, let r = reminders.first {
        let details = sentence(r.details)
        return "Hey\(first), it's time for \(r.name).\(details.isEmpty ? "" : " " + details) Did you do it yet? If not, please do it right now."
    }
    let each = reminders.map { r in sentence(r.details).isEmpty ? "\(r.name)." : "\(r.name): \(sentence(r.details))" }
    return "Hey\(first), you have \(reminders.count) reminders. \(each.joined(separator: " ")) Did you do them yet? If not, please do them right now."
}
