# MultiplicationMageTV

A native iPad & Apple TV app that wraps educational math web games with full **game controller support**.

## Features

- 🎮 Physical game controller support (MFi, Xbox, PlayStation)
- 🕹️ D-pad / thumbstick → arrow key injection into the web game
- 📱 iPad-first, Apple TV-ready
- 🎯 Game selection screen (add more games easily)
- ⌨️ Keyboard fallback when no controller is connected

## Games

| Game | Source |
|---|---|
| Multiplication Mage | timestables.com / tafeldiploma.nl |

## How it works

Games are loaded in a full-screen `WKWebView`. Controller inputs are mapped to keyboard events and injected via JavaScript — no game source code required.

## Requirements

- Xcode 15+
- iOS 16+ / iPadOS 16+
- Swift 5.9+

## Setup

1. Clone the repo
2. Open `MultiplicationMageTV.xcodeproj` in Xcode
3. Select your target device
4. Build & run

> ⚠️ For personal/family use only. Games are third-party content and not suitable for App Store distribution.
