   //
   //  SettingsView.swift
   //  SitReminder
   //
   //  Created by Hu Gang on 2025/5/6.
   //

import SwiftUI
import AppKit

   // Views
struct SettingsView: View {
   @AppStorage("reminderInterval") var reminderInterval: Double = 60
   @AppStorage("theme") var theme: String = "auto"
   @AppStorage("showCountdown") var showCountdown: Bool = true
   
   var body: some View {
      Form {
         VStack(alignment: .leading, spacing: 16) {
            HStack {
               Text(NSLocalizedString("REMINDER_INTERVAL", comment: "Reminder interval setting"))
               Spacer()
#if DEBUG
               Stepper(String(format: NSLocalizedString("MINUTES", comment: "Minutes format"), Int(reminderInterval)), value: $reminderInterval, in: 1...180, step: 1)
#else
               Stepper(String(format: NSLocalizedString("MINUTES", comment: "Minutes format"), Int(reminderInterval)), value: $reminderInterval, in: 15...180, step: 5)
#endif
            }
            
            HStack {
               Text(NSLocalizedString("THEME", comment: "Theme setting"))
               Spacer()
               Picker("", selection: $theme) {
                  Text(NSLocalizedString("LIGHT", comment: "Light theme")).tag("light")
                  Text(NSLocalizedString("DARK", comment: "Dark theme")).tag("dark")
                  Text(NSLocalizedString("AUTO", comment: "Auto theme")).tag("auto")
               }
               .labelsHidden()
               .pickerStyle(.segmented)
            }
            
            Toggle(NSLocalizedString("SHOW_COUNTDOWN", comment: "Show countdown setting"), isOn: $showCountdown)
         }
         .padding(.vertical, 10)
      }
      .padding()
      .frame(width: 300)
      .onChange(of: reminderInterval) { newValue in
         NotificationCenter.default.post(name: Notification.Name("ReminderIntervalChanged"), object: nil)
      }
   }
}
