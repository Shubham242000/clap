// One-off script to generate AppIcon.icns. Run with: swift generate_icon.swift
import Cocoa

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size)
let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
NSColor(calibratedRed: 1.0, green: 0.882, blue: 0.337, alpha: 1.0).setFill() // matches landing page --yellow
path.fill()

let paletteConfig = NSImage.SymbolConfiguration(paletteColors: [NSColor(calibratedWhite: 0.086, alpha: 1.0)]) // matches --ink
let sizeConfig = NSImage.SymbolConfiguration(pointSize: size * 0.52, weight: .bold)
let config = sizeConfig.applying(paletteConfig)

if let symbol = NSImage(systemSymbolName: "hands.clap.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
    symbol.isTemplate = false
    let symRect = NSRect(
        x: (size - symbol.size.width) / 2,
        y: (size - symbol.size.height) / 2,
        width: symbol.size.width,
        height: symbol.size.height
    )
    symbol.draw(in: symRect)
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("render failed")
}
try! png.write(to: URL(fileURLWithPath: "icon_1024.png"))
print("wrote icon_1024.png")
