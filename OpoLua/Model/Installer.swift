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

protocol InstallerDelegate: AnyObject {

    func installer(_ installer: Installer, didFinishWithResult result: Installer.Result)

}

class Installer {

    typealias Result = Swift.Result<Directory.Item?, Error>

    static let didCompleteInstall = NSNotification.Name(rawValue: "InstallerDidCompleteInstall")

    let url: URL
    let destinationUrl: URL
    let sourceUrl: URL?
    let fileSystem: SystemFileSystem
    let psilua = PsiLuaEnv()

    weak var delegate: InstallerDelegate?

    init(url: URL, destinationUrl: URL, sourceUrl: URL?) {
        self.url = url
        self.destinationUrl = destinationUrl
        self.sourceUrl = sourceUrl
        self.fileSystem = SystemFileSystem(rootUrl: destinationUrl)
    }

    func run() {
        DispatchQueue.global().async {
            do {
                try self.fileSystem.prepare()
                self.fileSystem.metadata = Metadata(sourceUrl: self.sourceUrl)
                try self.psilua.installSisFile(path: self.url.path, handler: self)
                let item: Directory.Item?
                if let systemType = try Directory.Item.system(url: self.destinationUrl, env: self.psilua) {
                    item = Directory.Item(url: self.url, type: systemType, isWriteable: true)
                } else {
                    item = nil
                }
                self.delegate?.installer(self, didFinishWithResult: .success(item))
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Installer.didCompleteInstall, object: self)
                }
            } catch {
                // TODO: Clean up if we've failed to install the file.
                self.delegate?.installer(self, didFinishWithResult: .failure(error))
            }
        }
    }

}

extension Installer: SisInstallIoHandler {

    func fsop(_ op: Fs.Operation) -> Fs.Result {
        return fileSystem.perform(op)
    }

}
