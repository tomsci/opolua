// Copyright (c) 2021-2022 Jason Morley, Tom Sutcliffe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import CoreGraphics
import UIKit

struct BitmapFontInfo {
    struct MetadataJson: Codable {
        let name: String
        let charh: Int
        let ascent: Int
        let maxwidth: Int
        let encoding: String
        let firstch: UInt32
        let widths: [Int]
    }
    let bitmapName: String
    // Although it is not explicitly stated that String.Encoding values are
    // completely interchangeable with NSStringEncoding UInts it is heavily
    // implied by the fact that the compiler (somehow) knows more about this
    // than the docs and indicates NSUTF32StringEncoding must be replaced by
    // String.Encoding.utf32
    let encoding: String.Encoding
    let startIndex: UInt32
    let charw: Int
    let charh: Int // aka ascent + descent, same as the "point size" of a TTF font
    let ascent: Int
    let widths: [Int]

    init?(uid: UInt32) {
        let uidstr = String(uid, radix: 16, uppercase: true)
        guard let url = Bundle.main.url(forResource: "fonts/\(uidstr)/\(uidstr).json", withExtension: nil),
              let json = try? Data(contentsOf: url),
              let metadata = try? JSONDecoder().decode(MetadataJson.self, from: json) else {
            return nil
        }
        let cfenc = CFStringConvertIANACharSetNameToEncoding(metadata.encoding as CFString)
        if cfenc == kCFStringEncodingInvalidId {
            return nil
        }
        let nsenc = CFStringConvertEncodingToNSStringEncoding(cfenc)
        let encoding = String.Encoding(rawValue: nsenc)

        self.init(bitmapName: uidstr, encoding: encoding, startIndex: metadata.firstch, charw: metadata.maxwidth,
            charh: metadata.charh, ascent: metadata.ascent, widths: metadata.widths)
    }

    init(bitmapName: String, encoding: String.Encoding, startIndex: UInt32, charw: Int, charh: Int, ascent: Int, widths: [Int]) {
        self.bitmapName = bitmapName
        self.encoding = encoding
        self.startIndex = startIndex
        self.charw = charw
        self.charh = charh
        self.ascent = ascent
        self.widths = widths
    }
}

class BitmapFontRenderer {
    let font: BitmapFontInfo
    private let img: CGImage
    private var charCache: [Character: CGImage] = [:]
    let imagew: Int
    let imageh: Int
    var charw: Int { return font.charw }
    var charh: Int { return font.charh }
    var charsPerRow: Int { return imagew / charw }
    var numRows: Int { return imageh / charh }

    init(font: BitmapFontInfo) {
        self.font = font
        self.img = UIImage(named: "fonts/\(font.bitmapName)/\(font.bitmapName)")!.cgImage!.inverted()!
        self.imagew = self.img.width
        self.imageh = self.img.height
    }

    func imageIndexFor(char: Character) -> Int? {
        if char.unicodeScalars.count != 1 {
            return nil
        }
        let codepoint: UInt32
        if font.encoding == .utf32 {
            codepoint = char.unicodeScalars.first!.value
        } else {
            if let data = String(char).data(using: font.encoding) {
                var b: UInt8 = 0
                assert(data.count == 1) // not gonna handle multibyte encodings here...
                data.copyBytes(to: &b, count: 1)
                codepoint = UInt32(b)
            } else {
                // If it can't even be represented in the image's charset, we can't have an index for it
                return nil
            }
        }
        let maxValue = font.startIndex + UInt32(self.charsPerRow * self.numRows)
        if codepoint >= font.startIndex && codepoint < maxValue {
            return Int(codepoint - font.startIndex)
        } else {
            return nil
        }
    }

    func imageCharWidth(_ char: Character) -> Int? {
        if let idx = imageIndexFor(char: char) {
            return font.widths[idx]
        } else {
            return nil
        }
    }

    static func getCharName(_ ch: Character) -> String {
        return ch.unicodeScalars.map({ String(format:"U+%04X", $0.value) }).joined(separator: "_")
    }

    func individualImageForChar(_ char: Character) -> CGImage? {
        let charName = Self.getCharName(char)
        return UIImage(named: "fonts/\(font.bitmapName)/\(charName)")?.cgImage
    }

    func getCharWidth(_ char: Character) -> Int {
        if let w = imageCharWidth(char) {
            return w
        } else {
            if let img = getImageForChar(char) {
                return img.width
            } else {
                return 0
            }
        }
    }

    func getTextSize<T>(_ text: T) -> (Int, Int) where T : StringProtocol {
        var maxw = 0
        var w = 0
        var h = charh
        for ch in text {
            if ch == "\n" {
                maxw = max(maxw, w)
                w = 0
                h = h + charh // assuming there's something after the newline anyway...
            } else {
                w = w + getCharWidth(ch)
            }
        }
        return (max(w, maxw), h)
    }

    func getImageForChar(_ char: Character) -> CGImage? {
        if let img = charCache[char] {
            return img
        }
        if let img = calculateImageForChar(char) {
            charCache[char] = img
            return img
        }
        return nil
    }

    private func calculateImageForChar(_ char: Character) -> CGImage? {
        if let idx = imageIndexFor(char: char) {
            let width = font.widths[idx]
            if width == 0 {
                return nil
            }
            let uidx = UInt32(idx)
            let x = Int(uidx % UInt32(self.charsPerRow))
            let y = Int(uidx / UInt32(self.charsPerRow))
            return self.img.cropping(to: CGRect(x: x * charw, y: y * charh, width: width, height: charh))!
        } else {
            return individualImageForChar(char)
        }
    }
}

class BitmapFontCache {
    static var shared = BitmapFontCache()
    private var cache: [String : BitmapFontRenderer] = [:] // Map of bitmapName key to BitmapFontRenderer

    func getRenderer(font: BitmapFontInfo, simulateBold: Bool = false) -> BitmapFontRenderer {
        if let result = cache[font.bitmapName] {
            return result
        } else {
            let result = BitmapFontRenderer(font: font)
            cache[font.bitmapName] = result
            return result
        }
    }
}
