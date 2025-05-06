//
//  SitReminderApp.swift
//  SitReminder
//
//  Created by Hu Gang on 2025/5/6.
//

import SwiftUI
import AppKit

@main
struct SitReminderApp: App {
   @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

   var body: some Scene {
      Settings {
         SettingsView()
      }
      .commands {
         CommandGroup(replacing: .appInfo) {
            Button("About SitReminder") {
               appDelegate.showAboutWindow()
            }
         }
      }
   }
}
