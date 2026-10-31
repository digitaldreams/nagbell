import AppKit
import Foundation
import Testing
@testable import NagbellCore

let t0 = Date(timeIntervalSince1970: 1_000_000)

@Test func presetNeedsNameAndSaneMinutes() {
    #expect(Preset(name: "Motor Off", minutes: 20).isValid)
    #expect(!Preset(name: "   ", minutes: 20).isValid)
    #expect(!Preset(name: "Milk", minutes: 0).isValid)
    #expect(!Preset(name: "Milk", minutes: 1441).isValid)
}

@Test func startingPresetSetsDueTime() {
    let timer = RunningTimer(preset: Preset(name: "Milk", details: "Oven", minutes: 15), now: t0)
    #expect(timer.dueAt == t0.addingTimeInterval(900))
    #expect(timer.name == "Milk")
    #expect(timer.details == "Oven")
}

@Test func remainingAndDue() {
    let timer = RunningTimer(preset: Preset(name: "Milk", minutes: 1), now: t0)
    #expect(timer.remaining(at: t0.addingTimeInterval(20)) == 40)
    #expect(!timer.isDue(at: t0.addingTimeInterval(59)))
    #expect(timer.isDue(at: t0.addingTimeInterval(60)))
    #expect(timer.remaining(at: t0.addingTimeInterval(500)) == 0)
}

@Test func snoozePushesDueFromNow() {
    var timer = RunningTimer(preset: Preset(name: "Milk", minutes: 1), now: t0)
    let late = t0.addingTimeInterval(120)
    timer.snooze(minutes: 5, now: late)
    #expect(timer.dueAt == late.addingTimeInterval(300))
}

@Test func formatsCountdown() {
    #expect(formatCountdown(0) == "00:00")
    #expect(formatCountdown(0.4) == "00:01")
    #expect(formatCountdown(872) == "14:32")
    #expect(formatCountdown(3900) == "1:05:00")
}

@Test func storeRoundTrip() throws {
    let store = PresetStore(url: tempFile())
    let presets = [Preset(name: "Rice", details: "Gas stove", minutes: 12)]
    try store.save(presets)
    #expect(store.load() == presets)
}

@Test func storeMissingFileGivesDefaults() {
    #expect(PresetStore(url: tempFile()).load() == Preset.defaults)
}

@Test func storeCorruptFileIsBackedUpNotLost() throws {
    let url = tempFile()
    try Data("not json".utf8).write(to: url)
    #expect(PresetStore(url: url).load() == Preset.defaults)
    let backup = url.appendingPathExtension("bak")
    #expect(try String(contentsOf: backup, encoding: .utf8) == "not json")
}

@Test func storeMovesPresetsFromLegacyLocation() throws {
    let legacy = tempFile(), url = tempFile()
    let presets = [Preset(name: "Rice", minutes: 12)]
    try PresetStore(url: legacy).save(presets)
    #expect(PresetStore(url: url, legacy: legacy).load() == presets)
    #expect(FileManager.default.fileExists(atPath: url.path))
    #expect(!FileManager.default.fileExists(atPath: legacy.path))
}

func tempFile() -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("presets.json")
}

@Test func becameDueOnlyOnTheCrossingTick() {
    let timer = RunningTimer(preset: Preset(name: "Milk", minutes: 1), now: t0)
    #expect(timer.becameDue(from: t0.addingTimeInterval(59), to: t0.addingTimeInterval(60)))
    #expect(!timer.becameDue(from: t0.addingTimeInterval(60), to: t0.addingTimeInterval(61)))
    #expect(!timer.becameDue(from: t0.addingTimeInterval(10), to: t0.addingTimeInterval(11)))
    // Mac woke from sleep long after due → still counts as the crossing tick
    #expect(timer.becameDue(from: t0.addingTimeInterval(30), to: t0.addingTimeInterval(3600)))
}

@Test func listsSoundNamesFromFoldersSortedWithoutDuplicates() throws {
    let a = tempFile(), b = tempFile()
    for dir in [a, b] { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
    for file in ["Glass.aiff", "Basso.aiff", ".DS_Store", "notes.txt"] { try Data().write(to: a.appendingPathComponent(file)) }
    for file in ["Glass.aiff", "Chime.wav"] { try Data().write(to: b.appendingPathComponent(file)) }
    let missing = tempFile()
    #expect(soundNames(in: [a, b, missing]) == ["Basso", "Chime", "Glass"])
}

@Test func friendlyReminderTalksLikeAFriend() {
    #expect(friendlyReminder(user: "Tuhin Bepari", reminders: [("Motor Off", "Switch off the water motor")])
        == "Hey Tuhin, it's time for Motor Off. Switch off the water motor. Did you do it yet? If not, please do it right now.")
    #expect(friendlyReminder(user: "Tuhin", reminders: [("Motor Off", "Switch off the water motor."), ("Milk", "")])
        == "Hey Tuhin, you have 2 reminders. Motor Off: Switch off the water motor. Milk. Did you do them yet? If not, please do them right now.")
    #expect(friendlyReminder(user: "", reminders: [("Milk", "  ")])
        == "Hey, it's time for Milk. Did you do it yet? If not, please do it right now.")
}

@Test @MainActor func missingAlarmSoundFallsBackToGlass() {
    #expect(alarmSound(named: "Basso")?.name == "Basso")
    #expect(alarmSound(named: "Deleted Custom Sound")?.name == "Glass")
}

@Test func timerStoreKeepsTimersAcrossLaunches() throws {
    let store = TimerStore(url: tempFile())
    #expect(store.load().isEmpty)
    let timers = [RunningTimer(preset: Preset(name: "Milk", minutes: 15), now: t0)]
    try store.save(timers)
    #expect(store.load() == timers)
}
