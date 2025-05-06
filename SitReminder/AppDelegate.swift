   //
//  AppDelegate.swift
//  SitReminder
//
//  Created by Hu Gang on 2025/5/6.
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
   var allReminderWindows: [NSWindow] = []
   var statusItem: NSStatusItem?
   var popover = NSPopover()
   var countdownTimer: Timer?
   var remainingSeconds: Int = 0
   @AppStorage("showCountdown") var showCountdown: Bool = true
   @AppStorage("reminderInterval") var reminderInterval: Double = 60
   var isDismissing = false // 新增：防止重入的状态标志
   
   func applicationDidFinishLaunching(_ notification: Notification) {
      print("AppDelegate: applicationDidFinishLaunching - Setting up status bar.")
      setupStatusBar()
      startCountdown(seconds: Int(reminderInterval * 60))
      NotificationCenter.default.addObserver(forName: Notification.Name("ReminderIntervalChanged"), object: nil, queue: .main) { _ in
         print("AppDelegate: Received ReminderIntervalChanged notification.")
         self.countdownTimer?.invalidate()
         self.startCountdown(seconds: Int(self.reminderInterval * 60))
      }
   }
   
   func setupStatusBar() {
      statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
      updateStatusBarTitle(remaining: remainingSeconds)
   }
   
   func updateStatusBarTitle(remaining: Int) {
      let minutes = remaining / 60
      let seconds = remaining % 60
      let timeString = String(format: "%02d:%02d", minutes, seconds)
      
      if let button = statusItem?.button {
         let icon = NSImage(named: "icon")
         icon?.isTemplate = true
         
         let attachment = VerticallyAlignedImageAttachment()
         attachment.image = icon
         let iconStr = NSAttributedString(attachment: attachment)
         
         let title = NSMutableAttributedString(attributedString: iconStr)
         if showCountdown {
            title.append(NSAttributedString(string: " \(timeString)"))
         }
         button.attributedTitle = title
         
         button.action = #selector(togglePopover(_:))
      }
   }
   
   @objc func togglePopover(_ sender: AnyObject?) {
      if popover.isShown {
         popover.performClose(sender)
      } else {
         popover.contentViewController = NSHostingController(rootView: ReminderPopupView())
         if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
         }
      }
   }
   
   func startCountdown(seconds: Int) {
      print("AppDelegate: Starting countdown for \(seconds) seconds.")
      remainingSeconds = seconds
      // Ensure previous timer is invalidated before creating a new one
      countdownTimer?.invalidate()
      countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
         if self.remainingSeconds > 0 {
            self.remainingSeconds -= 1
            self.updateStatusBarTitle(remaining: self.remainingSeconds)
         } else {
            timer.invalidate()
            print("AppDelegate: Countdown finished. Showing reminder window.")
            self.updateStatusBarTitle(remaining: 0)
            self.showReminderWindow()
         }
      }
   }
   
   func showReminderWindow() {
      print("AppDelegate: showReminderWindow called.")
      
      // 检查是否有可重用的窗口
      if !allReminderWindows.isEmpty {
         print("AppDelegate: Reusing existing window. Window count: \(allReminderWindows.count)")
         
         // 获取第一个窗口进行重用
         let windowToReuse = allReminderWindows[0]
         
         // 更新窗口内容
         let reminderView = ReminderOverlayView(appDelegateInstance: self)
         let hostingView = EscapableHostingView(rootView: reminderView, appDelegate: self)
         windowToReuse.contentView = hostingView
         
         // 使窗口可见并激活
         windowToReuse.makeFirstResponder(hostingView)
         windowToReuse.makeKeyAndOrderFront(nil)
         print("AppDelegate: Existing window made visible.")
      } else {
         // 如果没有窗口，创建一个新窗口
         print("AppDelegate: No existing windows found. Creating new window.")
         
         if let mainScreen = NSScreen.main {
            let windowWidth: CGFloat = 400
            let windowHeight: CGFloat = 200
            let frame = NSRect(x: mainScreen.frame.midX - windowWidth / 2,
                               y: mainScreen.frame.midY - windowHeight / 2,
                               width: windowWidth,
                               height: windowHeight)
            
            let reminderWindow = NSWindow(contentRect: frame,
                                          styleMask: [.titled, .closable],
                                          backing: .buffered, defer: false)
            reminderWindow.isOpaque = false
            reminderWindow.backgroundColor = NSColor.black.withAlphaComponent(0.4)
            print("AppDelegate: Creating main reminder window.")
            
            // 设置窗口内容
            let reminderView = ReminderOverlayView(appDelegateInstance: self)
            let hostingView = EscapableHostingView(rootView: reminderView, appDelegate: self)
            reminderWindow.contentView = hostingView
            reminderWindow.level = .floating
            
            // 设置第一响应者以捕获键盘事件
            reminderWindow.makeFirstResponder(hostingView)
            reminderWindow.makeKeyAndOrderFront(nil)
            
            // 添加到窗口数组中以便将来重用
            allReminderWindows.append(reminderWindow)
            print("AppDelegate: Main reminder window added. Window count: \(allReminderWindows.count)")
         }
      }
      
      print("AppDelegate: Reminder window now visible.")
   }
   
   @objc func dismissAllReminderWindows() {
      print("AppDelegate: Entering dismissAllReminderWindows")
      guard !isDismissing else {
          print("AppDelegate: Dismiss already in progress, ignoring.")
          return
      }
      isDismissing = true
      print("AppDelegate: isDismissing set to true")
 
      // Hide windows instead of closing them
      print("AppDelegate: Hiding \(allReminderWindows.count) windows instead of closing.")
      for window in allReminderWindows {
         print("AppDelegate: Hiding window: \(window)")
         window.orderOut(nil) // Hide window instead of closing it
      }
 
      // We no longer clear the array - windows are kept for reuse
      print("AppDelegate: Windows hidden. Keeping them for reuse.")
 
      // Reset the flag SYNCHRONOUSLY
      isDismissing = false
      print("AppDelegate: isDismissing reset to false.")
 
      // Restart countdown after a short delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
         guard let self = self else { return }
         print("DispatchQueue (Delayed): Restarting countdown.")
         self.startCountdown(seconds: Int(self.reminderInterval * 60))
         print("DispatchQueue (Delayed): Hiding app.")
         NSApp.hide(nil)
      }
   }
   
   func showAboutWindow() {
      let alert = NSAlert()
      alert.messageText = "SitReminder v1.0"
      alert.informativeText = "A tool for programmers to stay healthy.\n(c) 2025"
      alert.runModal()
   }
}
