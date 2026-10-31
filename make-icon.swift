// Draws the app icon ("Never forget the small things": a sticky note with a clock) and builds AppIcon.icns.
// Run: swift make-icon.swift   (only needed when the design changes; AppIcon.icns is kept in the repo)
import AppKit

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
func hex(_ v: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: a)
}

// Background: macOS rounded square (824pt body on the 1024 grid), deep navy so the yellow note pops.
let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
NSGradient(starting: hex(0x2A4D7A), ending: hex(0x12233D))!.draw(in: body, angle: -90)

// Note, tilted a little like it was stuck on by hand.
ctx.saveGState()
ctx.translateBy(x: 512, y: 500)
ctx.rotate(by: -5 * .pi / 180)
let s: CGFloat = 540, h = s / 2, fold: CGFloat = 120
let note = NSBezierPath()
note.move(to: NSPoint(x: -h, y: -h + fold * 0)); note.line(to: NSPoint(x: h - fold, y: -h))
note.line(to: NSPoint(x: h, y: -h + fold)); note.line(to: NSPoint(x: h, y: h)); note.line(to: NSPoint(x: -h, y: h)); note.close()
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 40, color: hex(0x000000, 0.45).cgColor)
hex(0xFFD54A).setFill(); note.fill()
ctx.restoreGState()
NSGradient(starting: hex(0xFFE27A), ending: hex(0xFFC83D))!.draw(in: note, angle: -90)

// Curled corner, bottom right.
let curl = NSBezierPath()
curl.move(to: NSPoint(x: h - fold, y: -h)); curl.line(to: NSPoint(x: h, y: -h + fold))
curl.curve(to: NSPoint(x: h - fold, y: -h), controlPoint1: NSPoint(x: h - fold * 0.55, y: -h + fold * 0.95),
           controlPoint2: NSPoint(x: h - fold * 0.95, y: -h + fold * 0.55))
hex(0xE0A422).setFill(); curl.fill()

// Clock: ink outline, four ticks, hands at "almost time" (11:55), red centre.
let ink = hex(0x2B2B33), r: CGFloat = 165
let face = NSBezierPath(ovalIn: NSRect(x: -r, y: -r + 15, width: r * 2, height: r * 2))
face.lineWidth = 30; ink.setStroke(); face.stroke()
let c = NSPoint(x: 0, y: 15)
func line(_ angle: CGFloat, from a: CGFloat, to b: CGFloat, width: CGFloat, color: NSColor = ink) {
    let p = NSBezierPath(); let rad = (90 - angle) * .pi / 180
    p.move(to: NSPoint(x: c.x + a * cos(rad), y: c.y + a * sin(rad)))
    p.line(to: NSPoint(x: c.x + b * cos(rad), y: c.y + b * sin(rad)))
    p.lineWidth = width; p.lineCapStyle = .round; color.setStroke(); p.stroke()
}
for a in stride(from: 0, to: 360, by: 90) { line(CGFloat(a), from: r - 55, to: r - 30, width: 22) }
line(-2.5, from: 0, to: r - 95, width: 30)   // hour hand, just before 12
line(-30, from: 0, to: r - 35, width: 22)    // minute hand at 55
hex(0xE5484D).setFill()
NSBezierPath(ovalIn: NSRect(x: c.x - 26, y: c.y - 26, width: 52, height: 52)).fill()
ctx.restoreGState()

// Red pin holding the note: the "sticky" part.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 6, height: -10), blur: 14, color: hex(0x000000, 0.4).cgColor)
NSGradient(starting: hex(0xFF6B6B), ending: hex(0xC92A2A))!
    .draw(in: NSBezierPath(ovalIn: NSRect(x: 462, y: 712, width: 76, height: 76)), relativeCenterPosition: NSPoint(x: -0.4, y: 0.4))
ctx.restoreGState()

// Write the 1024 PNG, then every size macOS wants, then the .icns.
let dir = URL(fileURLWithPath: "AppIcon.iconset")
try? FileManager.default.removeItem(at: dir)
try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
let master = dir.appendingPathComponent("icon_512x512@2x.png")
try! rep.representation(using: .png, properties: [:])!.write(to: master)
for (px, name) in [(16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"), (128, "128x128"),
                   (256, "128x128@2x"), (256, "256x256"), (512, "256x256@2x"), (512, "512x512")] {
    let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    p.arguments = ["-z", "\(px)", "\(px)", master.path, "--out", dir.appendingPathComponent("icon_\(name).png").path]
    p.standardOutput = FileHandle.nullDevice; try! p.run(); p.waitUntilExit()
}
let i = Process(); i.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
i.arguments = ["-c", "icns", dir.path, "-o", "AppIcon.icns"]; try! i.run(); i.waitUntilExit()
try? FileManager.default.removeItem(at: dir)
print("AppIcon.icns written")
