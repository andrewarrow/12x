import SwiftUI
import Foundation
import os.log

// MARK: - Test Logging in Multiple Ways

// 1. Standard print
print("LOGGING TEST 1: Standard print")

// 2. NSLog
NSLog("LOGGING TEST 2: NSLog")

// 3. OS Log
os_log("LOGGING TEST 3: os_log", log: OSLog.default, type: .error)

// 4. Direct stderr
fputs("LOGGING TEST 4: Direct stderr write\n", stderr)

// 5. File logging
func writeToLogFile(_ message: String) {
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    let logFilePath = "\(documentsPath)/12x_test_log.txt"
    
    do {
        try message.write(to: URL(fileURLWithPath: logFilePath), atomically: true, encoding: .utf8)
        print("Successfully wrote to log file at: \(logFilePath)")
    } catch {
        print("Failed to write to log file: \(error)")
    }
}

writeToLogFile("LOGGING TEST 5: File write test")

// Connect to the main app
struct MainApp {
    static func main() {
        print("LOGGING TEST 6: From main() function")
        ConnectWithApp.main()
    }
}

// Call main function to start the app
MainApp.main()