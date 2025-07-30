#!/usr/bin/env swift

import Foundation
import AppKit

let inputPath = "/Users/parkdawon/chatbot/OfflineChatbotApp/decoded_icon.png"
let outputDir = "/Users/parkdawon/chatbot/OfflineChatbotApp/OfflineChatbotApp/Assets.xcassets/AppIcon.appiconset"

let sizes: [(Int, String)] = [
    (40, "AppIcon-20x20@2x.png"),
    (60, "AppIcon-20x20@3x.png"),
    (58, "AppIcon-29x29@2x.png"),
    (87, "AppIcon-29x29@3x.png"),
    (80, "AppIcon-40x40@2x.png"),
    (120, "AppIcon-40x40@3x.png"),
    (120, "AppIcon-60x60@2x.png"),
    (180, "AppIcon-60x60@3x.png"),
    (20, "AppIcon-20x20@1x.png"),
    (29, "AppIcon-29x29@1x.png"),
    (40, "AppIcon-40x40@1x.png"),
    (76, "AppIcon-76x76@1x.png"),
    (152, "AppIcon-76x76@2x.png"),
    (167, "AppIcon-83.5x83.5@2x.png"),
    (1024, "AppIcon-1024x1024@1x.png")
]

guard let sourceImage = NSImage(contentsOfFile: inputPath) else {
    print("Failed to load source image")
    exit(1)
}

for (size, filename) in sizes {
    let newSize = NSSize(width: size, height: size)
    let newImage = NSImage(size: newSize)
    
    newImage.lockFocus()
    sourceImage.draw(in: NSRect(origin: .zero, size: newSize),
                     from: NSRect(origin: .zero, size: sourceImage.size),
                     operation: .copy,
                     fraction: 1.0)
    newImage.unlockFocus()
    
    guard let cgImage = newImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("Failed to create CGImage for \(filename)")
        continue
    }
    
    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG data for \(filename)")
        continue
    }
    
    let outputPath = "\(outputDir)/\(filename)"
    do {
        try pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Created \(filename)")
    } catch {
        print("Failed to write \(filename): \(error)")
    }
}

print("Icon generation complete")