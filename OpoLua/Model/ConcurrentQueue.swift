// Copyright (c) 2021 Jason Morley, Tom Sutcliffe
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

class ConcurrentQueue<T> {

    var condition = NSCondition()
    var items: [T] = []

    func append(_ item: T) {
        condition.lock()
        defer {
            condition.unlock()
        }
        items.append(item)
        condition.broadcast()
    }

    func takeFirst() -> T {
        condition.lock()
        defer {
            condition.unlock()
        }
        repeat {
            if let item = items.first {
                items.remove(at: 0)
                condition.broadcast()
                return item
            }
            condition.wait()
        } while true
    }

    func first(where predicate: (T) -> Bool) -> T? {
        condition.lock()
        defer {
            condition.unlock()
        }
        guard let index = items.firstIndex(where: predicate) else {
            return nil
        }
        condition.broadcast()
        return items.remove(at: index)
    }

    func isEmpty() -> Bool {
        condition.lock()
        let result = items.isEmpty
        condition.unlock()
        return result
    }
}
