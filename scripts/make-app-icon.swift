import AppKit

// A small, code-native utensil mark. Re-run with: swift scripts/make-app-icon.swift
let side = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                             isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
NSColor(red: 0.966, green: 0.967, blue: 0.95, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: side, height: side)).fill()
NSColor(red: 0.88, green: 0.91, blue: 0.85, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 158, y: 158, width: 708, height: 708)).fill()
let ink = NSColor(red: 0.19, green: 0.24, blue: 0.20, alpha: 1)
ink.setStroke()
let fork = NSBezierPath()
fork.lineWidth = 25
fork.lineCapStyle = .round
fork.lineJoinStyle = .round
fork.move(to: NSPoint(x: 320, y: 702))
fork.line(to: NSPoint(x: 320, y: 579))
fork.curve(to: NSPoint(x: 456, y: 579), controlPoint1: NSPoint(x: 320, y: 493), controlPoint2: NSPoint(x: 456, y: 493))
fork.line(to: NSPoint(x: 456, y: 702))
fork.move(to: NSPoint(x: 388, y: 707))
fork.line(to: NSPoint(x: 388, y: 316))
fork.stroke()
let knife = NSBezierPath()
knife.lineWidth = 25
knife.lineCapStyle = .round
knife.lineJoinStyle = .round
knife.move(to: NSPoint(x: 651, y: 706))
knife.curve(to: NSPoint(x: 555, y: 503), controlPoint1: NSPoint(x: 581, y: 686), controlPoint2: NSPoint(x: 550, y: 589))
knife.line(to: NSPoint(x: 652, y: 503))
knife.line(to: NSPoint(x: 651, y: 706))
knife.move(to: NSPoint(x: 652, y: 505))
knife.line(to: NSPoint(x: 652, y: 316))
knife.stroke()
NSGraphicsContext.restoreGraphicsState()
let url = URL(fileURLWithPath: "Petit Chef/Assets.xcassets/AppIcon.appiconset/app-icon.png")
try bitmap.representation(using: .png, properties: [:])!.write(to: url)
