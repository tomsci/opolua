// Copyright (c) 2021-2023 Jason Morley, Tom Sutcliffe
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

import UIKit

extension CGContext {

    func gXBorder(type: Graphics.BorderType, frame: CGRect) {
        let filename = String(format: "%05X", type.rawValue)

        guard let url = Bundle.main.url(forResource: filename, withExtension: "png", subdirectory: "Borders") else {
            print("No resource found for border type \(type) (\(filename).png)")
            return
        }
        let image = UIImage(contentsOfFile: url.path)!
        // I don't really understand why we have to limit the inset size so agressively here, but
        // limiting to half the frame size is not sufficient to avoid some weird artifacts
        let inset = min(min(frame.width, frame.height) / 3, 10)
        let button = image.resizableImage(withCapInsets: UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset), resizingMode: .stretch)
        let view = UIImageView(image: button)
        saveGState()
        self.translateBy(x: frame.origin.x, y: frame.origin.y)
        view.frame = CGRect(origin: .zero, size: frame.size)
        view.layer.render(in: self)
        restoreGState()
    }

}
