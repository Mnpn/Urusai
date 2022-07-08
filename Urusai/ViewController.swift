//
//  ViewController.swift
//  Urusai
//
//  Created by Martin Persson on 2022-07-07.
//

import Cocoa
import LaunchAtLogin

class ViewController: NSViewController {
    @IBOutlet weak var menubarToggle: NSButton!
    @IBOutlet weak var versionLabel: NSTextField!
    @IBOutlet var link: NSTextView!

    let df = UserDefaults.standard
    @objc dynamic var launchAtLogin = LaunchAtLogin.kvo

    override func viewDidLoad() {
        super.viewDidLoad()
        menubarToggle?.state = df.bool(forKey: "should_show_menubar_item") ? NSControl.StateValue.on : NSControl.StateValue.off
        
        // https://stackoverflow.com/questions/3015796
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        versionLabel.stringValue = "Urusai \(version) (build \(build))"
        
        // https://stackoverflow.com/questions/7055131
        // poke the automatic link detection..
        link.isEditable = true
        link.checkTextInDocument(nil)
        link.isEditable = false
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window!.styleMask.remove(.resizable)
        view.window!.center()
        NSApp.activate(ignoringOtherApps: true)
        view.window!.makeKeyAndOrderFront(nil)
    }

    @IBAction func menubarToggled(_ sender: NSButton) {
        let delegate = NSApplication.shared.delegate as! AppDelegate
        if sender.state == NSControl.StateValue.on {
            delegate.createMenu()
        } else {
            delegate.statusItem = nil // .isHidden hides the icon but does not remove its space
        }
        df.set(sender.state == NSControl.StateValue.on, forKey: "should_show_menubar_item")
    }
}

