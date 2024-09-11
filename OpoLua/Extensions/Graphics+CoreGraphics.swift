// Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe
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

import OpoLuaCore

extension Graphics.MaskedBitmap {

    var cgImage: CGImage? {
        get {
            let img = CGImage.from(bitmap: self.bitmap)
            if let maskBmp = self.mask {
                var maskImg: CGImage?
                if maskBmp.size != self.bitmap.size {
                    // We don't (yet) deal with masks of a mismatching size,
                    // something that EPOC apps seem to do all too frequently
                    return img
                } else if maskBmp.mode == .gray2 {
                    // 1BPP image masks are inverted relative to other bit
                    // depths which actually makes them aligned with how
                    // CoreGraphics expects them!
                    maskImg  = CGImage.from(bitmap: maskBmp)
                } else {
                    maskImg = CGImage.from(bitmap: maskBmp).inverted()?.stripAlpha(grayscale: true)
                }
                if let maskImg = maskImg {
                    return img.masking(maskImg)
                }
            }
            // Fallback for no mask or failed mask
            return img
        }
    }

}

