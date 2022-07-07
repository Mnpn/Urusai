//
//  AppDelegate.swift
//  Urusai
//
//  Created by Martin Persson on 2022-07-07.
//

import Cocoa
import AVFoundation

struct InputDevice {
    var id: AudioDeviceID       // e.g. 101
    var name: String            // e.g. "MacBook Pro Microphone"
    var manufacturer: String    // e.g. "Apple Inc."
    var uid: String             // e.g. "BuiltInMicrophoneDevice"
    var transportType: UInt32   // e.g. 1 (kAudioDeviceTransportTypeBuiltIn)
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var preferencesController: NSWindowController?
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    var lastDevice = InputDevice.init(id: 101, name: "Initial", manufacturer: "N/A", uid: "N/A", transportType: 1) // default MBP mic on my end
    var inputDevice = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // set default UserDefaults if they do not exist
        UserDefaults.standard.register(
            defaults: [
                "should_launch_at_startup": true,
                "should_show_menubar_item": true
            ]
        )

        addListenerBlock(listenerBlock: audioObjectPropertyListenerBlock,
                         onAudioObjectID: AudioObjectID(bitPattern: kAudioObjectSystemObject),
                         forPropertyAddress: inputDevice)
        let device = getCurrentlySetInputDevice()
        print(device)
        if device.transportType == 2 { // bluetooth input device?
            setAudioInputThing(device: lastDevice)
        } else {
            lastDevice = device
        }
        
        // create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Urusai")
            button.isHidden = !UserDefaults.standard.bool(forKey: "should_show_menubar_item")
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Urusai " + version + " (* ^ ω ^)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit Urusai", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        openPreferences()
    }

    func applicationWillTerminate(_ aNotification: Notification) { }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { return true }

    // https://stackoverflow.com/a/32211296/8523793
    func addListenerBlock(listenerBlock: @escaping AudioObjectPropertyListenerBlock, onAudioObjectID: AudioObjectID, forPropertyAddress: AudioObjectPropertyAddress) {
        var thing = forPropertyAddress
        if (kAudioHardwareNoError != AudioObjectAddPropertyListenerBlock(onAudioObjectID, &thing, nil, listenerBlock)) {
           print("Failed to add an AudioObject listener")
        }
    }

    func audioObjectPropertyListenerBlock(numberAddresses: UInt32, addresses: UnsafePointer<AudioObjectPropertyAddress>) {
       var index = 0
       while index < numberAddresses {
           let address: AudioObjectPropertyAddress = addresses[index]
           switch address.mSelector {
               case kAudioHardwarePropertyDefaultInputDevice:
                   let device = getCurrentlySetInputDevice()
                   print(device)
                   if device.transportType == 2 { // bluetooth input device?
                       setAudioInputThing(device: lastDevice)
                   } else {
                       lastDevice = device
                   }
               default:
                   print("We didn't expect this!")
           }
           index += 1
       }
    }

    func getCurrentlySetInputDevice() -> InputDevice {
        var deviceId = AudioDeviceID()
        let objectID = AudioObjectID(kAudioObjectSystemObject)
        var size = UInt32(0)
        AudioObjectGetPropertyDataSize(objectID, &inputDevice, 0, nil, &size)
        AudioObjectGetPropertyData(objectID, &inputDevice, 0, nil, &size, &deviceId)

        let name: String = {
            var name: CFString = "" as CFString
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceNameCFString, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            AudioObjectGetPropertyDataSize(deviceId, &address, 0, nil, &size)
            AudioObjectGetPropertyData(deviceId, &address, 0, nil, &size, &name)
            return name as String
        }()

        let manufacturer: String = {
            var manufacturer: CFString = "" as CFString
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceManufacturerCFString, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            AudioObjectGetPropertyDataSize(deviceId, &address, 0, nil, &size)
            AudioObjectGetPropertyData(deviceId, &address, 0, nil, &size, &manufacturer)
            return manufacturer as String
        }()

        let uid: String = {
            var uid: CFString = "" as CFString
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            AudioObjectGetPropertyDataSize(deviceId, &address, 0, nil, &size)
            AudioObjectGetPropertyData(deviceId, &address, 0, nil, &size, &uid)
            return uid as String
        }()

        let tt: UInt32 = {
            var transportType: UInt32 = 0
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyTransportType, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            AudioObjectGetPropertyDataSize(deviceId, &address, 0, nil, &size)
            AudioObjectGetPropertyData(deviceId, &address, 0, nil, &size, &transportType)
            switch transportType {
                case kAudioDeviceTransportTypeBuiltIn: return 1
                case kAudioDeviceTransportTypeBluetooth,
                     kAudioDeviceTransportTypeBluetoothLE: return 2
                case kAudioDeviceTransportTypeVirtual: return 3
                default: return 0
            }
        }()

        return InputDevice.init(id: deviceId, name: name, manufacturer: manufacturer, uid: uid, transportType: tt)
    }

 
    func setAudioInputThing(device: InputDevice) {
        var id = device.id
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &inputDevice, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id)
        NSLog("Changed the current audio input device to " + device.name + " (ID " + String(device.id) + ").")
    }
    
    @objc func openPreferences() {
        if preferencesWindowController?.window?.occlusionState.contains(.visible) ?? false { return }
        preferencesWindowController?.showWindow(self)
    }

    private lazy var preferencesWindowController: NSWindowController? = { // limit to one preference pane open at a time
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Preferences"), bundle: nil)
        return storyboard.instantiateInitialController() as? NSWindowController
    }()
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openPreferences()
        return false
    }
}
