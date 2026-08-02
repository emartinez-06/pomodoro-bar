import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    let borderAvailable: Bool

    @State private var launchAtLoginManaged = FileManager.default.fileExists(
        atPath: NSHomeDirectory() + "/Library/LaunchAgents/com.eim.pomodoro-bar.plist"
    )
    @State private var launchAtLoginEnabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: launchAtLoginBinding)
                    .disabled(launchAtLoginManaged)
                    .help(launchAtLoginManaged
                        ? "Already managed by the LaunchAgent installed via `make install`"
                        : "Start PomodoroBar automatically when you log in")
                Toggle("Play Sounds", isOn: $preferences.soundsEnabled)
            }

            Section("Timer") {
                Toggle("Auto-Advance Cycles", isOn: $preferences.autoAdvanceEnabled)
                    .help("Start the next work or break interval automatically when the current one ends, so a run needs a single Start and stops itself at the daily goal. Off: every interval waits for Shift+Cmd+A.")
                Stepper("Work: \(preferences.workMinutes) min", value: $preferences.workMinutes, in: 1...120)
                Stepper("Break: \(preferences.breakMinutes) min", value: $preferences.breakMinutes, in: 1...60)
                Stepper("Long break: \(preferences.longBreakMinutes) min", value: $preferences.longBreakMinutes, in: 1...60)
                Stepper("Rounds before long break: \(preferences.roundsBeforeLongBreak)", value: $preferences.roundsBeforeLongBreak, in: 2...12)
                Stepper("Daily goal: \(preferences.dailyGoal) sessions", value: $preferences.dailyGoal, in: 1...12)
            }

            Section("Focus Border") {
                Toggle("Enable Focus Border", isOn: $preferences.focusBorderEnabled)
                    .disabled(!borderAvailable)
                    .help(borderAvailable
                        ? "Outline the focused window with JankyBorders: work color during work, rest color during breaks"
                        : "Bundled JankyBorders binary not found")
                ColorPicker("Work color", selection: focusColorBinding, supportsOpacity: false)
                ColorPicker("Rest color", selection: restColorBinding, supportsOpacity: false)
            }

            Section {
                Button("Restore Defaults") {
                    preferences.restoreDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginEnabled },
            set: { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    launchAtLoginEnabled = newValue
                } catch {
                    NSLog("SettingsView: failed to \(newValue ? "register" : "unregister") login item: \(error)")
                }
            }
        )
    }

    private var focusColorBinding: Binding<Color> {
        Binding(
            get: { Color(NSColor(borderHex: preferences.focusColorHex) ?? .systemGreen) },
            set: { preferences.focusColorHex = NSColor($0).borderHex }
        )
    }

    private var restColorBinding: Binding<Color> {
        Binding(
            get: { Color(NSColor(borderHex: preferences.restColorHex) ?? .systemOrange) },
            set: { preferences.restColorHex = NSColor($0).borderHex }
        )
    }
}
