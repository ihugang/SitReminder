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
               Text("Reminder interval")
               Spacer()
#if DEBUG
               Stepper("\(Int(reminderInterval)) minutes", value: $reminderInterval, in: 1...180, step: 1)
#else
               Stepper("\(Int(reminderInterval)) minutes", value: $reminderInterval, in: 15...180, step: 5)
#endif
            }
            
            HStack {
               Text("Theme")
               Spacer()
               Picker("", selection: $theme) {
                  Text("Light").tag("light")
                  Text("Dark").tag("dark")
                  Text("Auto").tag("auto")
               }
               .labelsHidden()
               .pickerStyle(.segmented)
            }
            
            Toggle("Show countdown in menu bar", isOn: $showCountdown)
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
