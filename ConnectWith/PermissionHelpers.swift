import Foundation
import CoreBluetooth
import UIKit
import SwiftUI

// MARK: - AppLogger Implementation
class AppLogger {
    static let shared = AppLogger()
    
    init() {}
    
    func logWindowHierarchy() {
        print("🔍 LOGGING WINDOW HIERARCHY:")
        let scenes = UIApplication.shared.connectedScenes
        let windowScenes = scenes.compactMap { $0 as? UIWindowScene }
        
        print("🔍 Connected scenes: \(scenes.count)")
        print("🔍 Window scenes: \(windowScenes.count)")
        
        for (i, windowScene) in windowScenes.enumerated() {
            print("🔍 Window scene #\(i):")
            let windows = windowScene.windows
            print("  - Windows count: \(windows.count)")
            
            for (j, window) in windows.enumerated() {
                print("  - Window #\(j):")
                print("    - Is key window: \(window.isKeyWindow)")
                print("    - Is hidden: \(window.isHidden)")
                print("    - Alpha: \(window.alpha)")
                print("    - Bounds: \(window.bounds)")
                print("    - Root view controller: \(String(describing: window.rootViewController?.description))")
                
                if let rootVC = window.rootViewController {
                    logViewControllerHierarchy(rootVC, indent: 6)
                }
                
                if let rootView = window.rootViewController?.view {
                    logViewHierarchy(rootView, indent: 6)
                }
            }
        }
    }
    
    private func logViewControllerHierarchy(_ viewController: UIViewController, indent: Int) {
        let indentation = String(repeating: " ", count: indent)
        print("\(indentation)ViewController: \(type(of: viewController))")
        
        if let presentedVC = viewController.presentedViewController {
            print("\(indentation)Presented ViewController:")
            logViewControllerHierarchy(presentedVC, indent: indent + 2)
        }
        
        if let navVC = viewController as? UINavigationController {
            print("\(indentation)Navigation Stack:")
            for (i, vc) in navVC.viewControllers.enumerated() {
                print("\(indentation)  [\(i)] \(type(of: vc))")
            }
        }
        
        if let tabVC = viewController as? UITabBarController {
            print("\(indentation)Tab View Controllers:")
            for (i, vc) in (tabVC.viewControllers ?? []).enumerated() {
                print("\(indentation)  Tab[\(i)] \(type(of: vc))")
                logViewControllerHierarchy(vc, indent: indent + 4)
            }
        }
        
        for child in viewController.children {
            logViewControllerHierarchy(child, indent: indent + 2)
        }
    }
    
    private func logViewHierarchy(_ view: UIView, indent: Int, maxDepth: Int = 3, currentDepth: Int = 0) {
        if currentDepth > maxDepth {
            return // Limit recursion depth
        }
        
        let indentation = String(repeating: " ", count: indent + (currentDepth * 2))
        print("\(indentation)View: \(type(of: view)), frame: \(view.frame), isHidden: \(view.isHidden), alpha: \(view.alpha)")
        
        for subview in view.subviews {
            logViewHierarchy(subview, indent: indent, maxDepth: maxDepth, currentDepth: currentDepth + 1)
        }
    }
    
    func logBluetoothState(_ manager: Any, name: String) {
        if let cbManager = manager as? CBCentralManager {
            print("🔵 Bluetooth Central Manager '\(name)' state: \(cbManager.state.rawValue)")
            if #available(iOS 13.1, *) {
                print("🔵 Bluetooth Central Manager '\(name)' authorization: \(cbManager.authorization.rawValue)")
            }
        } else if let pbManager = manager as? CBPeripheralManager {
            print("🔵 Bluetooth Peripheral Manager '\(name)' state: \(pbManager.state.rawValue)")
            if #available(iOS 13.1, *) {
                print("🔵 Bluetooth Peripheral Manager '\(name)' authorization: \(pbManager.authorization.rawValue)")
            }
        }
    }
}

// MARK: - Permission Dialog View Controller
class PermissionDialogViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        print("📱 PermissionDialogViewController viewDidLoad")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("📱 PermissionDialogViewController viewDidAppear")
        
        // Force UI update
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
}

// MARK: - Bluetooth Permission Handler
class BluetoothPermissionHandler {
    static let shared = BluetoothPermissionHandler()
    
    private var permissionViewController: PermissionDialogViewController?
    private var centralManager: CBCentralManager?
    private var permissionDelegate = PermissionDelegate()
    
    init() {}
    
    func forceShowPermissionDialog() {
        print("📱 BluetoothPermissionHandler: Forcing permission dialog")
        
        // Create an option dictionary that will cause the permission dialog to appear
        let options: [String: Any] = [
            CBCentralManagerOptionShowPowerAlertKey: true
        ]
        
        // Create manager on main queue to ensure dialog shows
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("📱 Creating CBCentralManager on main thread")
            
            // Create a manager with our delegate
            self.centralManager = CBCentralManager(
                delegate: self.permissionDelegate, 
                queue: .main,
                options: options
            )
            
            // Present a VC to ensure we're in the right UI state
            self.ensureViewControllerPresented()
        }
    }
    
    // Create and present an empty view controller to ensure we have a UI context
    private func ensureViewControllerPresented() {
        print("📱 Ensuring ViewController is presented")
        
        // Create a view controller if needed
        if permissionViewController == nil {
            permissionViewController = PermissionDialogViewController()
        }
        
        // Find the top-most view controller
        if let rootVC = UIApplication.shared.windows.first?.rootViewController {
            var topVC = rootVC
            while let presentedVC = topVC.presentedViewController {
                topVC = presentedVC
            }
            
            // Present our permission VC as a transparent overlay
            permissionViewController?.modalPresentationStyle = .overFullScreen
            permissionViewController?.modalTransitionStyle = .crossDissolve
            
            print("📱 Found top VC: \(type(of: topVC))")
            
            topVC.present(permissionViewController!, animated: false) {
                print("📱 PermissionViewController presented")
                
                // Give UI time to update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    
                    // Force the permission dialog by scanning
                    if let manager = self.centralManager, manager.state != .unauthorized {
                        print("📱 Starting scan to force permission dialog")
                        manager.scanForPeripherals(withServices: nil, options: nil)
                    }
                }
            }
        } else {
            print("📱 No root view controller found")
        }
    }
    
    // Delegate for handling Bluetooth callbacks
    private class PermissionDelegate: NSObject, CBCentralManagerDelegate {
        func centralManagerDidUpdateState(_ central: CBCentralManager) {
            print("📱 PermissionDelegate: centralManagerDidUpdateState - \(central.state.rawValue)")
            
            // If we have authorization, we can dismiss
            if #available(iOS 13.1, *) {
                print("📱 CBCentralManager authorization: \(central.authorization.rawValue)")
            }
        }
        
        func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
            print("📱 PermissionDelegate: willRestoreState")
        }
    }
}