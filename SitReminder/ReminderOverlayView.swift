   //
//  ReminderOverlayView.swift
//  SitReminder
//
//  Created by Hu Gang on 2025/5/6.
//

import SwiftUI
import AppKit

// Custom Hosting View to capture Esc key
class EscapableHostingView<Content>: NSHostingView<Content> where Content: View {

   // Store the AppDelegate instance
   private weak var appDelegateInstance: AppDelegate?

   // Custom initializer to accept the AppDelegate instance
   init(rootView: Content, appDelegate: AppDelegate) {
      self.appDelegateInstance = appDelegate
      super.init(rootView: rootView)
   }

   @MainActor required dynamic init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
   }
   
   @MainActor @preconcurrency required init(rootView: Content) {
      fatalError("init(rootView:) has not been implemented")
   }
   
   override var acceptsFirstResponder: Bool {
      return true
   }

   override func keyDown(with event: NSEvent) {
      if event.keyCode == 53 { // Esc key code
         // Use the stored appDelegateInstance
         if let delegate = appDelegateInstance {
            print("EscapableHostingView: Calling delegate.dismissAllReminderWindows()")
            delegate.dismissAllReminderWindows()
         } else {
            print("EscapableHostingView: Error - appDelegateInstance is nil.") // Keep error log
         }
      } else {
         // Pass other key events up the responder chain
         super.keyDown(with: event)
      }
   }
}

struct ReminderOverlayView: View {
   // Accept AppDelegate instance
   var appDelegateInstance: AppDelegate

   var body: some View {
      ZStack {
         Color.black.opacity(0.8).edgesIgnoringSafeArea(.all)
         VStack(spacing: 20) {
            Text(NSLocalizedString("TIME_TO_STAND_UP", comment: "Reminder to stand up"))
               .font(.largeTitle)
               .foregroundColor(.white)
            Button(NSLocalizedString("GOT_IT", comment: "Acknowledge reminder")) {
               print("Got it clicked")
               print("ReminderOverlayView: Button Clicked, calling dismiss via instance.")
               appDelegateInstance.dismissAllReminderWindows()
            }
         }
      }
   }
}

class ReminderOverlayWindow: NSWindow {
   init(screen: NSScreen, appDelegate: AppDelegate) {
      let screenFrame = screen.frame
      super.init(
         contentRect: screenFrame,
         styleMask: [.borderless],
         backing: .buffered,
         defer: false
      )
      self.setFrame(screenFrame, display: true)
      self.isReleasedWhenClosed = false
      self.level = .statusBar
      self.backgroundColor = .clear
      self.isOpaque = false
      self.ignoresMouseEvents = false
      self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
      self.contentView = EscapableHostingView(rootView: ReminderOverlayView(appDelegateInstance: appDelegate), appDelegate: appDelegate)
      self.alphaValue = 0.0
      self.makeKeyAndOrderFront(nil)
      NSAnimationContext.runAnimationGroup { context in
         context.duration = 0.4
         self.animator().alphaValue = 1.0
      }
   }
   
   // Override to handle Esc key press
   override func cancelOperation(_ sender: Any?) {
      print("ReminderOverlayWindow: cancelOperation called (Esc key pressed).")
      if let delegate = NSApp.delegate as? AppDelegate {
         print("ReminderOverlayWindow: Calling delegate.dismissAllReminderWindows() from cancelOperation.")
         delegate.dismissAllReminderWindows()
      }
   }
}
