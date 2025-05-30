   //
//  AppDelegate.swift
//  SitReminder
//
//  Created by Hu Gang on 2025/5/6.
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
   var allReminderWindows: [NSWindow] = [] // 主提醒窗口
   var allDimWindows: [NSWindow] = [] // 用于变暗屏幕的窗口
   var settingsWindow: NSWindow? // 保持对设置窗口的强引用
   var statusItem: NSStatusItem?
   
   // 暂停相关属性
   var isPaused: Bool = false // 是否处于暂停状态
   var pauseEndTime: Date? // 暂停结束时间
   var pauseTimer: Timer? // 暂停定时器
   var popover = NSPopover()
   var countdownTimer: Timer?
   var remainingSeconds: Int = 0
   @AppStorage("showCountdown") var showCountdown: Bool = true
   @AppStorage("reminderInterval") var reminderInterval: Double = 60
   @AppStorage("appLanguage") var appLanguage: String = "auto"
   var isDismissing = false // 新增：防止重入的状态标志
   
   func applicationDidFinishLaunching(_ notification: Notification) {
      print("AppDelegate: applicationDidFinishLaunching - Setting up status bar.")
      
      // 应用用户选择的语言设置
      applyLanguageSetting()
      
      setupStatusBar()
      startCountdown(seconds: Int(reminderInterval * 60))
      
      // 监听提醒间隔变化
      NotificationCenter.default.addObserver(forName: Notification.Name("ReminderIntervalChanged"), object: nil, queue: .main) { _ in
         print("AppDelegate: Received ReminderIntervalChanged notification.")
         self.countdownTimer?.invalidate()
         self.startCountdown(seconds: Int(self.reminderInterval * 60))
      }
      
      // 监听语言变化
      NotificationCenter.default.addObserver(forName: Notification.Name("LanguageChanged"), object: nil, queue: .main) { _ in
         print("AppDelegate: Received LanguageChanged notification.")
         self.applyLanguageSetting()
      }
   }
   
   // 应用语言设置
   private func applyLanguageSetting() {
      if appLanguage != "auto" {
         // 设置应用程序的语言
         UserDefaults.standard.set([appLanguage], forKey: "AppleLanguages")
         print("AppDelegate: Applied language setting: \(appLanguage)")
      } else {
         // 使用系统语言
         UserDefaults.standard.removeObject(forKey: "AppleLanguages")
         print("AppDelegate: Using system language")
      }
      UserDefaults.standard.synchronize()
   }
   
   func setupStatusBar() {
      statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
      updateStatusBarTitle(remaining: remainingSeconds)
   }
   
   func updateStatusBarTitle(remaining: Int) {
      if let button = statusItem?.button {
         let icon = NSImage(named: "icon")
         icon?.isTemplate = true
         
         let attachment = VerticallyAlignedImageAttachment()
         attachment.image = icon
         let iconStr = NSAttributedString(attachment: attachment)
         
         let title = NSMutableAttributedString(attributedString: iconStr)
         
         if isPaused {
            // 如果处于暂停状态，显示暂停图标
            title.append(NSAttributedString(string: " ⛔"))
         } else if showCountdown {
            // 如果未暂停且开启了倒计时显示
            let minutes = remaining / 60
            let seconds = remaining % 60
            let timeString = String(format: "%02d:%02d", minutes, seconds)
            title.append(NSAttributedString(string: " \(timeString)"))
         }
         
         button.attributedTitle = title
         button.action = #selector(togglePopover(_:))
      }
   }
   
   // 创建并显示状态栏菜单
   @objc func togglePopover(_ sender: AnyObject?) {
      let menu = NSMenu()
      
      // 添加当前状态信息
      if isPaused, let endTime = pauseEndTime {
         let formatter = DateFormatter()
         formatter.dateFormat = "HH:mm"
         let endTimeString = formatter.string(from: endTime)
         
         let statusMenuItem = NSMenuItem(title: String(format: NSLocalizedString("PAUSED_UNTIL", comment: "Paused until time"), endTimeString), action: nil, keyEquivalent: "")
         statusMenuItem.isEnabled = false
         menu.addItem(statusMenuItem)
         
         // 添加取消暂停选项
         menu.addItem(NSMenuItem(title: NSLocalizedString("CANCEL_PAUSE", comment: "Cancel pause"), action: #selector(cancelPause), keyEquivalent: "c"))
      } else {
         let statusMenuItem = NSMenuItem(title: String(format: NSLocalizedString("NEXT_REMINDER", comment: "Next reminder time"), formatTimeRemaining()), action: nil, keyEquivalent: "")
         statusMenuItem.isEnabled = false
         menu.addItem(statusMenuItem)
      }
      
      menu.addItem(NSMenuItem.separator())
      
      // 添加设置选项
      menu.addItem(NSMenuItem(title: NSLocalizedString("SETTINGS", comment: "Settings menu item"), action: #selector(showSettings), keyEquivalent: ","))
      
      // 添加立即提醒选项
      menu.addItem(NSMenuItem(title: NSLocalizedString("REMIND_NOW", comment: "Remind now menu item"), action: #selector(showReminderNow), keyEquivalent: "r"))
      
      // 添加重置计时器选项
      menu.addItem(NSMenuItem(title: NSLocalizedString("RESET_TIMER", comment: "Reset timer menu item"), action: #selector(resetTimer), keyEquivalent: "t"))
      
      // 添加暂停菜单
      let pauseMenu = NSMenu()
      pauseMenu.addItem(NSMenuItem(title: NSLocalizedString("PAUSE_1_HOUR", comment: "Pause for 1 hour"), action: #selector(pauseForOneHour), keyEquivalent: "1"))
      pauseMenu.addItem(NSMenuItem(title: NSLocalizedString("PAUSE_2_HOURS", comment: "Pause for 2 hours"), action: #selector(pauseForTwoHours), keyEquivalent: "2"))
      pauseMenu.addItem(NSMenuItem(title: NSLocalizedString("PAUSE_UNTIL_TOMORROW", comment: "Pause until tomorrow"), action: #selector(pauseForToday), keyEquivalent: "t"))
      
      let pauseMenuItem = NSMenuItem(title: NSLocalizedString("PAUSE_MENU", comment: "Pause menu"), action: nil, keyEquivalent: "p")
      pauseMenuItem.submenu = pauseMenu
      menu.addItem(pauseMenuItem)
      
      menu.addItem(NSMenuItem.separator())
      
      // 添加关于选项
      menu.addItem(NSMenuItem(title: NSLocalizedString("ABOUT", comment: "About menu item"), action: #selector(showAboutWindow), keyEquivalent: "a"))
      
      // 添加退出选项
      menu.addItem(NSMenuItem(title: NSLocalizedString("QUIT", comment: "Quit menu item"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
      
      // 显示菜单
      if let button = statusItem?.button {
         let point = NSPoint(x: button.bounds.midX, y: button.bounds.midY)
         menu.popUp(positioning: nil, at: point, in: button)
      }
   }
   
   // 格式化剩余时间
   private func formatTimeRemaining() -> String {
      let minutes = remainingSeconds / 60
      let seconds = remainingSeconds % 60
      return String(format: "%02d:%02d", minutes, seconds)
   }
   
   // 显示设置窗口
   @objc func showSettings() {
      // 如果设置窗口已经存在，就重用它
      if let existingWindow = settingsWindow {
         existingWindow.makeKeyAndOrderFront(nil)
         NSApp.activate(ignoringOtherApps: true)
         return
      }
      
      // 创建新的设置窗口
      let newSettingsWindow = NSWindow(
         contentRect: NSRect(x: 0, y: 0, width: 350, height: 250),
         styleMask: [.titled, .closable],
         backing: .buffered,
         defer: false)
      
      newSettingsWindow.title = "SitReminder 设置"
      newSettingsWindow.center()
      
      // 创建 SwiftUI 视图
      let settingsView = SettingsView()
      let hostingView = NSHostingView(rootView: settingsView)
      newSettingsWindow.contentView = hostingView
      
      // 设置窗口关闭时的回调
      newSettingsWindow.isReleasedWhenClosed = false // 防止窗口关闭时被释放
      newSettingsWindow.delegate = self // 设置委托以处理窗口关闭事件
      
      // 保存对窗口的引用
      self.settingsWindow = newSettingsWindow
      
      // 显示窗口
      newSettingsWindow.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
   }
   
   // 立即显示提醒
   @objc func showReminderNow() {
      countdownTimer?.invalidate()
      remainingSeconds = 0
      updateStatusBarTitle(remaining: 0)
      showReminderWindow()
   }
   
   // 重置计时器
   @objc func resetTimer() {
      countdownTimer?.invalidate()
      startCountdown(seconds: Int(reminderInterval * 60))
   }
   
   // MARK: - 暂停相关方法
   
   // 暂停 1 小时
   @objc func pauseForOneHour() {
      pauseReminders(hours: 1)
   }
   
   // 暂停 2 小时
   @objc func pauseForTwoHours() {
      pauseReminders(hours: 2)
   }
   
   // 今日暂停
   @objc func pauseForToday() {
      // 计算到今天结束还有多少小时
      let now = Date()
      let calendar = Calendar.current
      let endOfDay = calendar.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
      let secondsUntilEndOfDay = endOfDay.timeIntervalSince(now)
      let hoursUntilEndOfDay = secondsUntilEndOfDay / 3600
      
      pauseReminders(hours: hoursUntilEndOfDay)
   }
   
   // 暂停提醒的通用方法
   private func pauseReminders(hours: TimeInterval) {
      // 取消当前的倒计时器
      countdownTimer?.invalidate()
      
      // 设置暂停状态
      isPaused = true
      
      // 计算暂停结束时间
      pauseEndTime = Date().addingTimeInterval(hours * 60 * 60)
      
      // 更新状态栏图标
      updateStatusBarTitle(remaining: remainingSeconds)
      
      // 创建暂停定时器
      pauseTimer?.invalidate()
      pauseTimer = Timer.scheduledTimer(withTimeInterval: hours * 60 * 60, repeats: false) { [weak self] _ in
         self?.resumeReminders()
      }
      
      print("AppDelegate: Reminders paused for \(Int(hours)) hours until \(pauseEndTime?.description ?? "unknown time")")
   }
   
   // 恢复提醒
   @objc func cancelPause() {
      resumeReminders()
   }
   
   // 恢复提醒的内部方法
   private func resumeReminders() {
      // 取消暂停定时器
      pauseTimer?.invalidate()
      pauseTimer = nil
      
      // 重置暂停状态
      isPaused = false
      pauseEndTime = nil
      
      // 重新启动倒计时
      startCountdown(seconds: Int(reminderInterval * 60))
      
      print("AppDelegate: Reminders resumed")
   }
   
   func startCountdown(seconds: Int) {
      print("AppDelegate: Starting countdown for \(seconds) seconds.")
      remainingSeconds = seconds
      // Ensure previous timer is invalidated before creating a new one
      countdownTimer?.invalidate()
      
      // 如果处于暂停状态，不启动倒计时
      if isPaused {
         print("AppDelegate: Countdown paused until \(pauseEndTime?.description ?? "unknown time")")
         updateStatusBarTitle(remaining: remainingSeconds)
         return
      }
      
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
      
      // 第一步：创建或重用变暗窗口，覆盖所有屏幕
      createOrReuseAllDimWindows()
      
      // 第二步：创建或重用主提醒窗口
      if !allReminderWindows.isEmpty {
         print("AppDelegate: Reusing existing reminder window.")
         
         // 获取第一个窗口进行重用
         let windowToReuse = allReminderWindows[0]
         
         // 更新窗口内容
         let reminderView = ReminderOverlayView(appDelegateInstance: self)
         let hostingView = EscapableHostingView(rootView: reminderView, appDelegate: self)
         windowToReuse.contentView = hostingView
         
         // 使窗口可见并激活
         windowToReuse.makeFirstResponder(hostingView)
         windowToReuse.makeKeyAndOrderFront(nil)
         print("AppDelegate: Existing reminder window made visible.")
      } else {
         // 如果没有窗口，创建一个新窗口
         print("AppDelegate: No existing reminder window found. Creating new one.")
         
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
            reminderWindow.backgroundColor = NSColor.clear // 使用透明背景，因为我们有变暗窗口
            print("AppDelegate: Creating main reminder window.")
            
            // 设置窗口内容
            let reminderView = ReminderOverlayView(appDelegateInstance: self)
            let hostingView = EscapableHostingView(rootView: reminderView, appDelegate: self)
            reminderWindow.contentView = hostingView
            reminderWindow.level = .floating + 1 // 确保在变暗窗口之上
            
            // 设置第一响应者以捕获键盘事件
            reminderWindow.makeFirstResponder(hostingView)
            reminderWindow.makeKeyAndOrderFront(nil)
            
            // 添加到窗口数组中以便将来重用
            allReminderWindows.append(reminderWindow)
            print("AppDelegate: Main reminder window added.")
         }
      }
      
      print("AppDelegate: All windows now visible.")
   }
   
   // 创建一个自定义视图来处理 Esc 键事件
   class DimWindowView: NSView {
      weak var appDelegate: AppDelegate?
      
      init(frame: NSRect, appDelegate: AppDelegate) {
         self.appDelegate = appDelegate
         super.init(frame: frame)
      }
      
      required init?(coder: NSCoder) {
         fatalError("init(coder:) has not been implemented")
      }
      
      override var acceptsFirstResponder: Bool {
         return true
      }
      
      override func keyDown(with event: NSEvent) {
         if event.keyCode == 53 { // Esc 键码
            print("DimWindowView: Esc key detected.")
            if let delegate = appDelegate {
               print("DimWindowView: Calling delegate.dismissAllReminderWindows()")
               delegate.dismissAllReminderWindows()
            }
         } else {
            super.keyDown(with: event)
         }
      }
   }
   
   // 创建或重用变暗窗口，覆盖所有屏幕
   private func createOrReuseAllDimWindows() {
      // 检查是否需要创建新的变暗窗口
      if allDimWindows.count < NSScreen.screens.count {
         print("AppDelegate: Creating new dim windows for \(NSScreen.screens.count - allDimWindows.count) screens.")
         
         // 为每个屏幕创建变暗窗口
         for (index, screen) in NSScreen.screens.enumerated() {
            // 如果这个索引位置已经有窗口，跳过
            if index < allDimWindows.count {
               continue
            }
            
            // 创建覆盖整个屏幕的变暗窗口
            let dimWindow = NSWindow(contentRect: screen.frame,
                                    styleMask: .borderless,
                                    backing: .buffered,
                                    defer: false)
            dimWindow.backgroundColor = NSColor.black.withAlphaComponent(0.5) // 半透明黑色
            dimWindow.level = .floating // 浮动层级，但低于提醒窗口
            dimWindow.ignoresMouseEvents = false // 允许接收鼠标事件以便处理 Esc 键
            dimWindow.isOpaque = false
            dimWindow.hasShadow = false
            dimWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // 在所有工作区显示
            
            // 设置自定义视图以处理 Esc 键
            let dimView = DimWindowView(frame: screen.frame, appDelegate: self)
            dimWindow.contentView = dimView
            dimWindow.makeFirstResponder(dimView)
            
            // 添加到变暗窗口数组
            allDimWindows.append(dimWindow)
            print("AppDelegate: Created dim window for screen \(index + 1).")
         }
      } else {
         // 如果已有窗口，更新它们的内容视图
         for (index, window) in allDimWindows.enumerated() {
            if index < NSScreen.screens.count {
               let screen = NSScreen.screens[index]
               // 更新窗口位置以适应可能的屏幕变化
               window.setFrame(screen.frame, display: true)
               
               // 确保窗口有正确的内容视图
               if !(window.contentView is DimWindowView) {
                  let dimView = DimWindowView(frame: screen.frame, appDelegate: self)
                  window.contentView = dimView
                  window.makeFirstResponder(dimView)
               }
            }
         }
      }
      
      // 显示所有变暗窗口
      for window in allDimWindows {
         window.orderFront(nil)
      }
      print("AppDelegate: All dim windows are now visible.")
   }
   
   @objc func dismissAllReminderWindows() {
      print("AppDelegate: Entering dismissAllReminderWindows")
      guard !isDismissing else {
          print("AppDelegate: Dismiss already in progress, ignoring.")
          return
      }
      isDismissing = true
      print("AppDelegate: isDismissing set to true")
 
      // 隐藏所有提醒窗口
      print("AppDelegate: Hiding \(allReminderWindows.count) reminder windows.")
      for window in allReminderWindows {
         print("AppDelegate: Hiding reminder window: \(window)")
         window.orderOut(nil) // 隐藏而不是关闭
      }
      
      // 隐藏所有变暗窗口
      print("AppDelegate: Hiding \(allDimWindows.count) dim windows.")
      for window in allDimWindows {
         print("AppDelegate: Hiding dim window: \(window)")
         window.orderOut(nil) // 隐藏而不是关闭
      }
 
      // 保留窗口数组以便重用
      print("AppDelegate: All windows hidden. Keeping them for reuse.")
 
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
   
   @objc func showAboutWindow() {
      let alert = NSAlert()
      alert.messageText = NSLocalizedString("ABOUT_TITLE", comment: "About window title")
      alert.informativeText = NSLocalizedString("ABOUT_TEXT", comment: "About window text")
      alert.runModal()
   }
   
   // MARK: - NSWindowDelegate
   
   // 处理窗口关闭事件
   func windowWillClose(_ notification: Notification) {
      if let closedWindow = notification.object as? NSWindow {
         // 检查是否是设置窗口
         if closedWindow == settingsWindow {
            print("设置窗口即将关闭")
            // 我们不立即释放窗口，只是将其隐藏
            // 下次打开时会重用这个窗口
         }
      }
   }
}
