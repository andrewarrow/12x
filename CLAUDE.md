# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## App Overview
12x is an iOS application that facilitates Bluetooth connectivity between devices. The app solves the problem of letting two users connect and transfer info. The first page you see is a list of nearby
bluetooth devices with the ones that are this same app IsSameApp highlighted in blue. Those are the
devices you can communicate with. The rest are just visible in the list but you cannot select them.

When you select an IsSameApp device the detail page has a simple calendar with just the current 12
months of the year and the ability to edit 1 day on each month. For that 1 day you can edit a title and a location. These are both saved to your local device (core user) and transmitted over bluetooth.

When the receiving phone gets this information it replaces it's calendar data with what the
other phone sent over.

## Build and Run Commands
- Build: `xcodebuild -project connectWith___.xcodeproj -scheme connectWith___ build`
- Run: `xcodebuild -project connectWith___.xcodeproj -scheme connectWith___ run`
- Alternatively, open and run in Xcode IDE

## Code Style Guidelines
- **Imports**: Group in order: Foundation, SwiftUI, CoreBluetooth, Combine, UIKit
- **Formatting**: 4-space indentation, clear spacing around operators
- **Types**: Use descriptive names with camelCase for variables/functions, clear documentation
- **Organization**: Use `// MARK: - ` for code section separation
- **Properties**: Private properties prefixed with underscore (e.g., `_currentRssi`)
- **Error Handling**: Use optional binding with `if let`/`guard let`, provide descriptive messages
- **SwiftUI Views**: Follow composition pattern with subviews for readability
- **State Management**: Use appropriate property wrappers (@Published, @State, @EnvironmentObject)

## Architecture
- MVVM-like structure with Views and Models
- BluetoothManager as central state manager
- SwiftUI for UI components
- CoreBluetooth for device communication

## Development Notes
- iOS deployment target: 16.0
- Swift version: 5.0
- Bluetooth implementation using CoreBluetooth
- For Bluetooth-related changes, add debug logging with timestamps

## Specific Implementation Rules
Lots of debugging please.


