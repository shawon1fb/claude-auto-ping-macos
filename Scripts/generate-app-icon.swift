#!/usr/bin/env swift
//
// generate-app-icon.swift
//
// Renders the app icon programmatically with AppKit (no external tools or
// assets) and writes every size required by the macOS AppIcon set, plus an
// updated Contents.json. Run from the repo root:
//
//   swift Scripts/generate-app-icon.swift
//
// The artwork is a white "paperplane" glyph on a rounded indigo tile, matching
// the menu bar "running" symbol.

import AppKit
import Foundation

let iconSetPath = "Resources/Assets.xcassets/AppIcon.appiconset"

// macOS icon points and scales -> pixel sizes.
struct Entry { let size: Int; let scale: Int }
let entries: [Entry] = [
    Entry(size: 16, scale: 1), Entry(size: 16, scale: 2),
    Entry(size: 32, scale: 1), Entry(size: 32, scale: 2),
    Entry(size: 128, scale: 1), Entry(size: 128, scale: 2),
    Entry(size: 256, scale: 1), Entry(size: 256, scale: 2),
    Entry(size: 512, scale: 1), Entry(size: 512, scale: 2)
]

func renderIcon(pixels: Int) -> NSBitmapImageRep {
    let dimension = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: dimension, height: dimension)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Rounded tile with a small margin, like a standard macOS icon.
    let margin = dimension * 0.085
    let tile = NSRect(x: margin, y: margin,
                      width: dimension - margin * 2,
                      height: dimension - margin * 2)
    let radius = tile.width * 0.225

    // Vertical brand gradient (subtle, two close indigo shades).
    let top = NSColor(srgbRed: 0.40, green: 0.36, blue: 0.95, alpha: 1.0)
    let bottom = NSColor(srgbRed: 0.31, green: 0.27, blue: 0.84, alpha: 1.0)
    let path = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
    path.addClip()
    let gradient = NSGradient(starting: top, ending: bottom)!
    gradient.draw(in: tile, angle: -90)
    NSGraphicsContext.current?.cgContext.resetClip()

    // White paperplane glyph, centered.
    let config = NSImage.SymbolConfiguration(pointSize: dimension * 0.5, weight: .semibold)
    if let base = NSImage(systemSymbolName: "paperplane.fill", accessibilityDescription: nil),
       let symbol = base.withSymbolConfiguration(config) {
        let symbolSize = symbol.size
        let tinted = NSImage(size: symbolSize)
        tinted.lockFocus()
        NSColor.white.set()
        let bounds = NSRect(origin: .zero, size: symbolSize)
        symbol.draw(in: bounds)
        bounds.fill(using: .sourceAtop)
        tinted.unlockFocus()

        // The paperplane visually leans up-right; nudge it to look centered.
        let drawRect = NSRect(
            x: (dimension - symbolSize.width) / 2 - dimension * 0.01,
            y: (dimension - symbolSize.height) / 2 + dimension * 0.01,
            width: symbolSize.width,
            height: symbolSize.height
        )
        tinted.draw(in: drawRect)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to path: String) throws {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 1)
    }
    try data.write(to: URL(fileURLWithPath: path))
}

// Render each unique pixel size once, reuse for matching entries.
var cache: [Int: NSBitmapImageRep] = [:]
var images: [[String: String]] = []

for entry in entries {
    let pixels = entry.size * entry.scale
    let rep = cache[pixels] ?? renderIcon(pixels: pixels)
    cache[pixels] = rep
    let filename = "icon_\(entry.size)x\(entry.size)@\(entry.scale)x.png"
    try! writePNG(rep, to: "\(iconSetPath)/\(filename)")
    images.append([
        "idiom": "mac",
        "size": "\(entry.size)x\(entry.size)",
        "scale": "\(entry.scale)x",
        "filename": filename
    ])
}

let contents: [String: Any] = [
    "images": images,
    "info": ["author": "xcode", "version": 1]
]
let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: URL(fileURLWithPath: "\(iconSetPath)/Contents.json"))

print("Generated \(images.count) icon images in \(iconSetPath)")
