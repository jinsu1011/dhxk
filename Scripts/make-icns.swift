#!/usr/bin/env swift

import Foundation

let iconsetPath = CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.iconset"
let outputPath = CommandLine.arguments.dropFirst(2).first ?? "Resources/AppIcon.icns"

let chunks: [(type: String, filename: String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"),
]

func bigEndianBytes(_ value: UInt32) -> [UInt8] {
    let encoded = value.bigEndian
    return withUnsafeBytes(of: encoded) { Array($0) }
}

var payload = Data()
for chunk in chunks {
    let url = URL(fileURLWithPath: iconsetPath).appendingPathComponent(chunk.filename)
    guard let png = try? Data(contentsOf: url) else {
        FileHandle.standardError.write(Data("Missing icon file: \(url.path)\n".utf8))
        exit(1)
    }

    payload.append(Data(chunk.type.utf8))
    payload.append(contentsOf: bigEndianBytes(UInt32(png.count + 8)))
    payload.append(png)
}

var output = Data("icns".utf8)
output.append(contentsOf: bigEndianBytes(UInt32(payload.count + 8)))
output.append(payload)

do {
    try output.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    print("Created \(outputPath) (\(output.count) bytes)")
} catch {
    FileHandle.standardError.write(Data("Unable to write ICNS: \(error)\n".utf8))
    exit(1)
}
