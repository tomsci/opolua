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

// ER5 always uses CP1252 afaics, which also works for our ASCII-only error messages
private let kEnc = String.Encoding.windowsCP1252

extension UnsafeMutablePointer where Pointee == lua_State {

    func tostring(_ index: Int32, convert: Bool = false) -> String? {
        return tostring(index, encoding: kEnc, convert: convert)
    }
    func tostringarray(_ index: Int32) -> [String]? {
        return tostringarray(index, encoding: kEnc)
    }
    func tostring(_ index: Int32, key: String, convert: Bool = false) -> String? {
        return tostring(index, key: key, encoding: kEnc, convert: convert)
    }
    func tostringarray(_ index: Int32, key: String, convert: Bool = false) -> [String]? {
        return tostringarray(index, key: key, encoding: kEnc, convert: convert)
    }
    func push(_ string: String) {
        push(string, encoding: kEnc)
    }

}

private func traceHandler(_ L: LuaState!) -> Int32 {
    var msg = lua_tostring(L, 1)
    if msg == nil {  /* is error object not a string? */
        if luaL_callmeta(L, 1, "__tostring") != 0 &&  /* does it have a metamethod */
            lua_type(L, -1) == LUA_TSTRING { /* that produces a string? */
            return 1  /* that is the message */
        } else {
            let t = String(utf8String: luaL_typename(L, 1))!
            msg = lua_pushstring(L, "(error object is a \(t) value)")
        }
    }
    luaL_traceback(L, L, msg, 1)  /* append a standard traceback */
    return 1  /* return the traceback */
}

private func getInterpreterUpval(_ L: LuaState!) -> OpoInterpreter {
    let rawPtr = lua_topointer(L, lua_upvalueindex(1))!
    return Unmanaged<OpoInterpreter>.fromOpaque(rawPtr).takeUnretainedValue()
}

private func alert(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    let lines = L.tostringarray(1) ?? []
    let buttons = L.tostringarray(2) ?? []
    let ret = iohandler.alert(lines: lines, buttons: buttons)
    L.push(ret)
    return 1
}

private func getch(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    L.push(iohandler.getch())
    return 1
}

private func print_lua(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    iohandler.printValue(L.tostring(1, convert: true) ?? "<<STRING DECODE ERR>>")
    return 0
}

private func beep(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    iohandler.beep(frequency: lua_tonumber(L, 1), duration: lua_tonumber(L, 2))
    return 0
}

private func readLine(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    let b = L.toboolean(1)
    if let result = iohandler.readLine(escapeShouldErrorEmptyInput: b) {
        L.push(result)
    } else {
        L.pushnil()
    }
    return 1
}

private func dialog(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    let title = L.tostring(1, key: "title")
    let flags = Dialog.Flags(flags: L.toint(1, key: "flags") ?? 0)
    var items: [Dialog.Item] = []
    precondition(lua_getfield(L, 1, "items") == LUA_TTABLE, "Expected items table!")
    for _ in L.ipairs(-1, requiredType: .table) {
        let prompt = L.tostring(-1, key: "prompt") ?? ""
        let value = L.tostring(-1, key: "value") ?? ""
        let align: Dialog.Item.Alignment?
        if let rawAlign = L.tostring(-1, key: "align") {
            align = .init(rawValue: rawAlign)
        } else {
            align = nil
        }
        let min = L.tonumber(-1, key: "min")
        let max = L.tonumber(-1, key: "max")
        let choices = L.tostringarray(-1, key: "choices")

        if let t = Dialog.Item.ItemType(rawValue: L.toint(-1, key: "type") ?? -1) {
            let item = Dialog.Item(
                type: t,
                prompt: prompt,
                value: value,
                alignment: align,
                min: min,
                max: max,
                choices: choices)
            items.append(item)
        } else {
            print("Unknown dialog item type!")
        }
    }
    // leave items on the stack for doing fixups at the end

    var buttons: [Dialog.Button] = []
    if lua_getfield(L, 1, "buttons") == LUA_TTABLE {
        for _ in L.ipairs(-1, requiredType: .table) {
            let key = L.toint(-1, key: "key") ?? 0
            let text = L.tostring(-1, key: "text") ?? ""
            buttons.append(Dialog.Button(key: key, text: text))
        }
    }
    L.pop() // buttons
    let d = Dialog(title: title ?? "", items: items, buttons: buttons, flags: flags)
    let result = iohandler.dialog(d)
    // items is still on top of Lua stack here
    if result.result != 0 {
        // Update the values Lua-side
        precondition(result.values.count == d.items.count, "Bad number of result values!")
        for (i, value) in result.values.enumerated() {
            lua_rawgeti(L, -1, lua_Integer(i) + 1) // items[i]
            L.push(value)
            lua_setfield(L, -2, "value")
            L.pop() // items[i]
        }
    }
    L.push(result.result)
    return 1
}

private func menu(_ L: LuaState!) -> Int32 {
    func getMenu() -> Menu { // Assumes a menu table is on top of stack
        let title = L.tostring(-1, key: "title") ?? ""
        var items: [Menu.Item] = []
        for _ in L.ipairs(-1, requiredType: .table) {
            var rawcode = L.toint(-1, key: "keycode") ?? 0
            var flags = 0
            if rawcode < 0 {
                flags |= Menu.Item.Flags.separatorAfter.rawValue
                rawcode = -rawcode
            }
            flags = flags | (rawcode & ~0xFF)
            let keycode = rawcode & 0xFF
            let text = L.tostring(-1, key: "text") ?? ""
            var submenu: Menu? = nil
            if lua_getfield(L, -1, "submenu") == LUA_TTABLE {
                submenu = getMenu()
            }
            L.pop()
            items.append(Menu.Item(text: text, keycode: keycode, submenu: submenu, flags: Menu.Item.Flags(rawValue: flags)))
        }
        return Menu(title: title, items: items)
    }
    let iohandler = getInterpreterUpval(L).iohandler
    var menus: [Menu] = []
    for _ in L.ipairs(1, requiredType: .table) {
        menus.append(getMenu())
    }
    let highlight = L.toint(1, key: "highlight") ?? 0
    let m = Menu.Bar(menus: menus, highlight: highlight)
    let result = iohandler.menu(m)
    L.push(result.selected)
    L.push(result.highlighted)
    return 2
}

private func graphics(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    var ops: [Graphics.Operation] = []
    for _ in L.ipairs(1, requiredType: .table) {
        let id = L.toint(-1, key: "type") ?? 1
        let t = L.tostring(-1, key: "type") ?? ""
        let x = L.toint(-1, key: "x") ?? 0
        let y = L.toint(-1, key: "y") ?? 0
        let col = UInt8(L.toint(-1, key: "color") ?? 0)
        let color = Graphics.Color(r: col, g: col, b: col)
        let bgcol = UInt8(L.toint(-1, key: "bgcolor") ?? 255)
        let bgcolor = Graphics.Color(r: bgcol, g: bgcol, b: bgcol)
        let optype: Graphics.Operation.OpType
        switch (t) {
            case "cls": optype = .cls
            case "circle": optype = .circle(L.toint(-1, key: "r") ?? 0, (L.toint(-1, key: "fill") ?? 0) != 0)
            case "line": optype = .line(L.toint(-1, key: "x2") ?? 0, L.toint(-1, key: "y2") ?? 0)
            default:
                print("Unknown Graphics.Operation.OpType \(t)")
                continue
        }
        ops.append(Graphics.Operation(displayId: id, type: optype, x: x, y: y, color: color, bgcolor: bgcolor))
    }
    iohandler.draw(operations: ops)
    return 0
}

private func getScreenSize(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    let sz = iohandler.getScreenSize()
    L.push(sz.width)
    L.push(sz.height)
    return 2
}

class OpoInterpreter {
    private let L: LuaState
    var iohandler: OpoIoHandler

    init() {
        iohandler = DummyIoHandler() // For now...
        L = luaL_newstate()
        let libs: [(String, lua_CFunction)] = [
            ("_G", luaopen_base),
            (LUA_LOADLIBNAME, luaopen_package),
            (LUA_TABLIBNAME, luaopen_table),
            (LUA_IOLIBNAME, luaopen_io),
            (LUA_OSLIBNAME, luaopen_os),
            (LUA_STRLIBNAME, luaopen_string),
            (LUA_MATHLIBNAME, luaopen_math),
            (LUA_UTF8LIBNAME, luaopen_utf8),
            (LUA_DBLIBNAME, luaopen_debug)
        ]
        for (name, fn) in libs {
            luaL_requiref(L, name, fn, 1)
            lua_pop(L, 1)
        }

        // Now configure the require path
        let resources = Bundle.main.resourcePath!
        let searchPath = resources + "/?.lua"
        lua_getglobal(L, "package")
        lua_pushstring(L, searchPath)
        lua_setfield(L, -2, "path")
        lua_pop(L, 1) // package

        // Finally, run init.lua
        let err = luaL_dofile(L, resources + "/init.lua")
        if err != 0 {
            let errStr = String(validatingUTF8: lua_tostring(L, -1))!
            print(errStr)
            lua_pop(L, 1)
        }

        assert(lua_gettop(L) == 0) // In case we failed to balance stack during init
    }

    deinit {
        lua_close(L)
    }

    func pcall(_ narg: Int32, _ nret: Int32) -> Bool {
        let base = lua_gettop(L) - narg // Where the function is, and where the msghandler will be
        lua_pushcfunction(L, traceHandler)
        lua_insert(L, base)
        let err = lua_pcall(L, narg, nret, base);
        lua_remove(L, base)
        if err != 0 {
            let errStr = L.tostring(-1, convert: true)!
            print("Error: \(errStr)")
            L.pop()
            return false
        }
        return true
    }

    func makeIoHandlerBridge() {
        lua_newtable(L)
        let val = Unmanaged<OpoInterpreter>.passUnretained(self)
        lua_pushlightuserdata(L, val.toOpaque())
        let fns: [(String, lua_CFunction)] = [
            ("readLine", readLine),
            ("alert", alert),
            ("getch", getch),
            ("print", print_lua),
            ("beep", beep),
            ("dialog", dialog),
            ("menu", menu),
            ("graphics", graphics),
            ("getScreenSize", getScreenSize),
        ]
        L.setfuncs(fns, nup: 1)
    }

    enum ValType: Int {
        case Word = 0
        case Long = 1
        case Real = 2
        case String = 3
        case WordArray = 0x80
        case ELongArray = 0x81
        case ERealArray = 0x82
        case EStringArray = 0x83
    }

    struct Procedure {
        let name: String
        let arguments: [ValType]
    }

    func getProcedures(file: String) -> [Procedure]? {
        guard let data = FileManager.default.contents(atPath: file) else {
            return nil
        }
        lua_getglobal(L, "require")
        L.push("opofile")
        guard pcall(1, 1) else { return nil }
        lua_getfield(L, -1, "parseOpo")
        L.push(data)
        guard pcall(1, 1) else {
            L.pop() // opofile
            return nil
        }
        var procs: [Procedure] = []
        for _ in L.ipairs(-1, requiredType: .table) {
            let name = L.tostring(-1, key: "name")!
            var args: [ValType] = []
            if lua_getfield(L, -1, "params") == LUA_TTABLE {
                for _ in L.ipairs(-1, requiredType: .number) {
                    // insert at front because params are listed bass-ackwards
                    args.insert(ValType(rawValue: L.toint(-1)!)!, at: 0)
                }
            }
            L.pop() // params
            procs.append(Procedure(name: name, arguments: args))
        }
        L.pop(2) // procs, opofile
        return procs
    }

    func run(file: String, procedureName: String? = nil) {
        guard luaL_dofile(L, Bundle.main.path(forResource: "runopo", ofType: "lua")!) == 0 else {
            fatalError(L.tostring(-1, convert: true) ?? "Oh so much doom")
        }
        lua_settop(L, 0)
        lua_getglobal(L, "runOpo")
        L.push(file, encoding: .utf8)
        if let proc = procedureName {
            L.push(proc)
        } else {
            L.pushnil()
        }
        makeIoHandlerBridge()
        let _ = pcall(3, 0) // runOpo(file, proc, iohandler)
    }
}
