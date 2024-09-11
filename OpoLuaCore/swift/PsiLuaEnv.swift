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
import Lua
import CLua

// ER5 always uses CP1252 afaics, which also works for our ASCII-only error messages
public let kDefaultEpocEncoding: LuaStringEncoding = .stringEncoding(.windowsCP1252)
// And SIBO uses CP850 (which is handled completely differently and has an inconsistent name to boot)
public let kSiboEncoding: LuaStringEncoding = .cfStringEncoding(.dosLatin1)

public class PsiLuaEnv {

    internal let L: LuaState

    public init() {
        L = LuaState(libraries: [.package, .table, .io, .os, .string, .math, .utf8, .debug])
        L.setDefaultStringEncoding(kDefaultEpocEncoding)

        let srcRoot = Bundle.module.url(forResource: "init",
                                        withExtension: "lua",
                                        subdirectory: "src")!.deletingLastPathComponent()
        L.setRequireRoot(srcRoot.path)

        // Finally, run init.lua
        require("init")
        L.pop()
        assert(L.gettop() == 0) // In case we failed to balance stack during init
    }

    deinit {
        L.close()
    }

    private func logpcall(_ nargs: CInt, _ nret: CInt) -> Bool {
        do {
            try L.pcall(nargs: nargs, nret: nret)
            return true
        } catch {
            print("Error: \(error.localizedDescription)")
            return false
        }
    }

    internal func require(_ library: String) {
        L.getglobal("require")
        L.push(utf8String: library)
        guard logpcall(1, 1) else {
            fatalError("Failed to load \(library).lua!")
        }
    }

    public struct LocalizedString {
        public var value: String
        public var locale: Locale

        public init(_ value: String, locale: Locale) {
            self.value = value
            self.locale = locale
        }
    }

    public enum AppEra: String, Codable {
        case sibo
        case er5
    }

    public struct AppInfo {
        public let captions: [LocalizedString]
        public let uid3: UInt32
        public let icons: [Graphics.MaskedBitmap]
        public let era: AppEra
    }

    public func appInfo(for path: String) -> AppInfo? {
        let top = L.gettop()
        defer {
            L.settop(top)
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            return nil
        }
        require("aif")
        L.rawget(-1, utf8Key: "parseAif")
        L.remove(-2) // aif module
        L.push(data)
        guard logpcall(1, 1) else { return nil }

        return L.toAppInfo(-1)
    }

    public func getMbmBitmaps(path: String) -> [Graphics.Bitmap]? {
        let top = L.gettop()
        defer {
            L.settop(top)
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            return nil
        }
        require("recognizer")
        L.rawget(-1, key: "getMbmBitmaps")
        L.remove(-2) // recognizer module
        L.push(data)
        guard logpcall(1, 1) else { return nil }
        // top of stack should now be bitmap array
        let result: [Graphics.Bitmap]? = L.todecodable(-1)
        return result
    }

    public struct UnknownEpocFile: Codable {
        public let uid1: UInt32
        public let uid2: UInt32
        public let uid3: UInt32
    }

    public struct MbmFile: Codable {
        public let bitmaps: [Graphics.Bitmap]
    }

    public struct OplFile: Codable {
        public let text: String
    }

    public struct SoundFile: Codable {
        public let data: Data
    }

    public struct OpaFile {
        public let uid3: UInt32
        public let appInfo: AppInfo? // For SIBO-era apps
        public let era: AppEra
    }

    public struct OpoFile : Codable {
        public let era: AppEra
    }

    public struct ResourceFile: Codable {
        public let idOffset: UInt32?
    }

    public struct SisFile: Codable {
        public let name: [String: String]
        public let uid: UInt32
        public let version: String
        public let languages: [String]
    }

    public enum FileType: String, Codable {
        case unknown
        case aif
        case database
        case mbm
        case opl
        case opa
        case opo
        case resource
        case sound
        case sis
    }

    public enum FileInfo {
        case unknown
        case unknownEpoc(UnknownEpocFile)
        case aif(AppInfo)
        case database
        case mbm(MbmFile)
        case opl(OplFile)
        case opa(OpaFile)
        case opo(OpoFile)
        case resource(ResourceFile)
        case sound(SoundFile)
        case sis(SisFile)
    }

    public func recognize(path: String) -> FileType {
        let top = L.gettop()
        defer {
            L.settop(top)
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            return .unknown
        }
        require("recognizer")
        L.rawget(-1, key: "recognize")
        L.remove(-2) // recognizer module
        L.push(data)
        guard logpcall(1, 1) else {
            return .unknown
        }
        guard let type = L.tostring(-1, key: "type") else {
            return .unknown
        }
        return FileType(rawValue: type) ?? .unknown
    }

    public func getFileInfo(path: String) -> FileInfo {
        let top = L.gettop()
        defer {
            L.settop(top)
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            return .unknown
        }
        require("recognizer")
        L.rawget(-1, key: "recognize")
        L.remove(-2) // recognizer module
        L.push(data)
        guard logpcall(1, 1) else {
            return .unknown
        }
        guard let typeStr = L.tostring(-1, key: "type") else {
            return .unknown
        }
        guard let type = FileType(rawValue: typeStr) else {
            fatalError("Unhandled type \(typeStr)")
        }

        switch type {
        case .aif:
            if let info = L.toAppInfo(-1) {
                return .aif(info)
            }
        case .database:
            return .database
        case .mbm:
            if let info: MbmFile = L.todecodable(-1) {
                return .mbm(info)
            }
        case .opl:
            if let info: OplFile = L.todecodable(-1) {
                return .opl(info)
            }
        case .opa:
            if let appInfo: AppInfo = L.toAppInfo(-1) {
                let opa = OpaFile(uid3: appInfo.uid3, appInfo: appInfo, era: appInfo.era)
                return .opa(opa)
            } else if let eraString = L.tostring(-1, key: "era"),
                      let era = AppEra(rawValue: eraString),
                      let uid3Int = L.toint(-1, key: "uid3"),
                      let uid3 = UInt32(exactly: uid3Int) {
                return .opa(OpaFile(uid3: uid3, appInfo: nil, era: era))
            }
        case .opo:
            if let info: OpoFile = L.todecodable(-1) {
                return .opo(info)
            }
        case .resource:
            if let info: ResourceFile = L.todecodable(-1) {
                return .resource(info)
            }
        case .sis:
            if let info: SisFile = L.todecodable(-1) {
                return .sis(info)
            }
        case .sound:
            if let info: SoundFile = L.todecodable(-1) {
                return .sound(info)
            }
        case .unknown:
            if let info: UnknownEpocFile = L.todecodable(-1) {
                return .unknownEpoc(info)
            }
        }
        return .unknown
    }

    public enum OpoArgumentType: Int {
        case Word = 0
        case Long = 1
        case Real = 2
        case String = 3
        case WordArray = 0x80
        case ELongArray = 0x81
        case ERealArray = 0x82
        case EStringArray = 0x83
    }

    public struct OpoProcedure {
        public let name: String
        public let arguments: [OpoArgumentType]
    }

    public func getProcedures(opoFile: String) -> [OpoProcedure]? {
        guard let data = FileManager.default.contents(atPath: opoFile) else {
            return nil
        }
        require("opofile")
        L.rawget(-1, key: "parseOpo")
        L.remove(-2) // opofile
        L.push(data)
        guard logpcall(1, 1) else {
            return nil
        }
        var procs: [OpoProcedure] = []
        for _ in L.ipairs(-1) {
            let name = L.tostring(-1, key: "name")!
            var args: [OpoArgumentType] = []
            if L.rawget(-1, key: "params") == .table {
                for _ in L.ipairs(-1) {
                    // insert at front because params are listed bass-ackwards
                    args.insert(OpoArgumentType(rawValue: L.toint(-1)!)!, at: 0)
                }
            }
            L.pop() // params
            procs.append(OpoProcedure(name: name, arguments: args))
        }
        L.pop() // procs
        return procs
    }

    internal static let fsop: lua_CFunction = { (L: LuaState!) -> CInt in
        let wrapper: FsHandlerWrapper = L.touserdata(lua_upvalueindex(1))!
        let iohandler = wrapper.iohandler

        guard let cmd = L.tostring(1) else {
            return 0
        }
        guard let path = L.tostring(2) else {
            return 0
        }
        let op: Fs.Operation.OpType
        switch cmd {
        case "exists":
            op = .exists
        case "stat":
            op = .stat
        case "isdir":
            op = .isdir
        case "delete":
            op = .delete
        case "mkdir":
            op = .mkdir
        case "rmdir":
            op = .rmdir
        case "write":
            if let data = L.todata(3) {
                op = .write(Data(data))
            } else {
                return 0
            }
        case "read":
            op = .read
        case "dir":
            op = .dir
        case "rename":
            guard let dest = L.tostring(3) else {
                print("Missing param to rename")
                L.push(Fs.Err.notReady.rawValue)
                return 1
            }
            op = .rename(dest)
        default:
            print("Unimplemented fsop \(cmd)!")
            L.push(Fs.Err.notReady.rawValue)
            return 1
        }

        let result = iohandler.fsop(Fs.Operation(path: path, type: op))
        switch (result) {
        case .err(let err):
            if err != .none {
                print("Error \(err) for cmd \(op) path \(path)")
            }
            if cmd == "read" || cmd == "dir" || cmd == "stat" {
                L.pushnil()
                L.push(err.rawValue)
                return 2
            } else {
                L.push(err.rawValue)
                return 1
            }
        case .data(let data):
            L.push(data)
            return 1
        case .strings(let strings):
            L.newtable(narr: CInt(strings.count), nrec: 0)
            for (i, string) in strings.enumerated() {
                L.rawset(-1, key: i + 1, value: string)
            }
            return 1
        case .stat(let stat):
            L.newtable()
            L.rawset(-1, key: "size", value: Int64(stat.size))
            L.rawset(-1, key: "lastModified", value: stat.lastModified.timeIntervalSince1970)
            return 1
        }
    }

    public func installSisFile(path: String, handler: SisInstallIoHandler) throws {
        let top = L.gettop()
        defer {
            L.settop(top)
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            throw LuaArgumentError(errorString: "Couldn't read \(path)")
        }
        require("runtime")
        L.rawget(-1, utf8Key: "installSis")
        L.push(data)
        makeFsIoHandlerBridge(handler)
        try L.pcall(nargs: 2, nret: 0)
    }

    internal func makeFsIoHandlerBridge(_ handler: FileSystemIoHandler) {
        L.newtable()
        L.push(FsHandlerWrapper(iohandler: handler))
        let fns: [String: lua_CFunction] = [
            "fsop": { L in return autoreleasepool { return PsiLuaEnv.fsop(L) } },
        ]
        L.setfuncs(fns, nup: 1)
    }

}

fileprivate class FsHandlerWrapper: PushableWithMetatable {
    init(iohandler: FileSystemIoHandler) {
        self.iohandler = iohandler
    }
    static let metatable = Metatable<FsHandlerWrapper>()

    let iohandler: FileSystemIoHandler
}

internal extension LuaState {
    func toAppInfo(_ index: CInt) -> PsiLuaEnv.AppInfo? {
        let L = self
        if isnoneornil(index) {
            return nil
        }
        let era: PsiLuaEnv.AppEra = L.getdecodable(index, key: "era") ?? .er5
        let encoding = era == .er5 ? kDefaultEpocEncoding : kSiboEncoding
        L.rawget(index, key: "captions")
        var captions: [PsiLuaEnv.LocalizedString] = []
        for (languageIndex, captionIndex) in L.pairs(-1) {
            guard let language = L.tostring(languageIndex),
                  let caption = L.tostring(captionIndex, encoding: encoding)
            else {
                return nil
            }
            captions.append(.init(caption, locale: Locale(identifier: language)))
        }
        L.pop()

        guard let uid3 = L.toint(index, key: "uid3") else {
            return nil
        }

        L.rawget(index, key: "icons")
        var icons: [Graphics.MaskedBitmap] = []
        // Need to refactor the Lua data structure before we can make MaskedBitmap decodable
        for _ in L.ipairs(-1) {
            if let bmp = L.todecodable(-1, type: Graphics.Bitmap.self) {
                var mask: Graphics.Bitmap? = nil
                if L.rawget(-1, key: "mask") == .table {
                    mask = L.todecodable(-1)
                }
                L.pop()
                icons.append(Graphics.MaskedBitmap(bitmap: bmp, mask: mask))
            }
        }
        L.pop() // icons
        return PsiLuaEnv.AppInfo(captions: captions, uid3: UInt32(uid3), icons: icons, era: era)
    }
}
