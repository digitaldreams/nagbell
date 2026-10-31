import AppKit
import NagbellCore
import SwiftUI

struct ContentView: View {
    @Bindable var model: TimerModel
    @State private var editing: Preset?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Reminders").font(.headline)
                Spacer()
                Menu {
                    Toggle("Speak reminder", isOn: $model.speak)
                    Picker("Voice", selection: $model.voiceID) {
                        ForEach(model.voices, id: \.identifier) { Text("\($0.name) (\($0.language))") }
                    }
                    .pickerStyle(.menu) // submenu: the voice list is long
                    Divider()
                    Picker("Alarm sound", selection: $model.soundName) {
                        ForEach(model.sounds, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.inline)
                } label: { Image(systemName: "speaker.wave.2") }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Alarm sound")
                Button { editing = Preset(name: "", minutes: 15) } label: { Image(systemName: "plus") }
                    .help("Add reminder")
            }

            ForEach(model.presets) { preset in
                Button { model.start(preset) } label: {
                    HStack {
                        Text(preset.name)
                        Spacer()
                        Text("\(preset.minutes)m").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .help(preset.details)
                .contextMenu {
                    Button("Edit…") { editing = preset }
                    Button("Delete", role: .destructive) { model.presets.removeAll { $0.id == preset.id } }
                }
            }
            Text("Right-click a reminder to edit or delete").font(.caption2).foregroundStyle(.tertiary)

            if !model.timers.isEmpty { Divider() }
            ForEach(model.timers) { timer in
                TimerRow(timer: timer, model: model)
            }

            if let error = model.saveError { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .padding()
        .frame(width: 280)
        .background(model.anyDue ? Color.red.opacity(0.3) : Color.clear)
        .background(WindowGrabber { model.attach($0) })
        .sheet(item: $editing) { preset in
            PresetForm(preset: preset) { model.upsert($0) }
        }
    }
}

struct TimerRow: View {
    let timer: RunningTimer
    let model: TimerModel

    var body: some View {
        let due = timer.isDue(at: model.now)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: due ? "bell.fill" : "timer")
                Text(timer.name).bold()
                Spacer()
                if due {
                    Text("TIME UP").bold().foregroundStyle(.red)
                } else {
                    Text(formatCountdown(timer.remaining(at: model.now))).monospacedDigit()
                    Button { model.remove(timer) } label: { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                        .help("Cancel timer")
                }
            }
            if due {
                if !timer.details.isEmpty { Text(timer.details) }
                HStack {
                    Button("Done") { model.remove(timer) }
                    Button("Snooze 5m") { model.snooze(timer) }
                }
                .controlSize(.large)
            }
        }
    }
}

struct PresetForm: View {
    @State var preset: Preset
    let onSave: (Preset) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .trailing) {
            Form {
                TextField("Name", text: $preset.name)
                TextField("Description", text: $preset.details)
                HStack {
                    TextField("Minutes", value: $preset.minutes, format: .number)
                    Stepper("", value: $preset.minutes, in: 1...1440).labelsHidden()
                }
            }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { onSave(preset); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!preset.isValid)
            }
        }
        .padding()
        .frame(width: 320)
    }
}

/// SwiftUI doesn't expose its NSWindow; this invisible view hands it over once it's on screen.
struct WindowGrabber: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView { GrabberView(onWindow: onWindow) }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class GrabberView: NSView {
        let onWindow: (NSWindow) -> Void
        init(onWindow: @escaping (NSWindow) -> Void) {
            self.onWindow = onWindow
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError("not used") }
        override func viewDidMoveToWindow() {
            if let window { onWindow(window) }
        }
    }
}
