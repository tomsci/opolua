--[[

Copyright (c) 2021 Jason Morley, Tom Sutcliffe

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]

_ENV = module()

local ops = require("ops")
local newStack = require("stack").newStack
local database = require("database")
local memory = require("memory")

Runtime = class {}

local sbyte = string.byte
local fmt = string.format

function Runtime:nextOp()
    local ip = self.ip
    local opCode = sbyte(self.data, ip+1)
    local op = ops.codes[opCode]
    if not op then
        printf("No op for code 0x%02X at 0x%08X\n", opCode, ip)
    end
    self.ip = ip + 1
    return opCode, op
end

function Runtime:ipUnpack(packFmt)
    local result, nextPos = string.unpack(packFmt, self.data, self.ip + 1)
    self.ip = nextPos - 1
    return result
end

function Runtime:ipString()
    return self:ipUnpack("s1")
end

function Runtime:IP8()
    return self:ipUnpack("B")
end

function Runtime:IPs8()
    return self:ipUnpack("b")
end

function Runtime:IPs16()
    return self:ipUnpack("<h")
end

function Runtime:IP16()
    return self:ipUnpack("<H")
end

function Runtime:IP32()
    return self:ipUnpack("<I4")
end

function Runtime:IPs32()
    return self:ipUnpack("<i4")
end

function Runtime:IPReal()
    return self:ipUnpack("<d")
end

local makeVar = memory.makeVar
database.makeVar = makeVar
local newArrayVal = memory.newArrayVal

function Runtime:getLocalVar(index, type, frame)
    -- ie things where index is just an offset from iFrameCell
    assert(type, "getLocalVar requires a type argument!")
    if not frame then
        frame = self.frame
    end
    local vars = frame.vars
    local var = vars[index]
    if not var then
        local maxLen = nil
        if type == DataTypes.EString then
            local stringFixupIndex = index - 1
            maxLen = assert(frame.proc.strings[stringFixupIndex], "Failed to find string fixup!")
        end
        var = makeVar(type, maxLen)
        var:setOrigin(frame.proc, index)
        vars[index] = var
    end
    if var() == nil then
        assert(frame.proc.fn == nil, "Cannot have an uninitialized local var in a Lua frame!")
        -- Even though the caller might be a LeftSide op and thus is about to
        -- assign to the var, so initialising the var might not actually be
        -- necessary, we'll do it anyway just to simplify the interface
        if isArrayType(type) then
            -- Have to apply array fixup (ie find array length from proc definition)
            local arrayFixupIndex = (type == DataTypes.EStringArray) and index - 3 or index - 2
            local len = assert(frame.proc.arrays[arrayFixupIndex], "Failed to find array fixup!")
            local stringMaxLen = nil
            if type == DataTypes.EStringArray then
                local stringFixupIndex = index - 1
                stringMaxLen = assert(frame.proc.strings[stringFixupIndex], "Failed to find string fixup for array!")
            end
            var(newArrayVal(type & 0xF, len, stringMaxLen))
        else
            var(DefaultSimpleTypes[type])
        end
    end
    return var
end

function Runtime:popParameter(stack)
    local type = stack:pop()
    assert(DataTypes[type], "Expected parameter type on stack")
    assert(not isArrayType(type), "Can't pass arrays on the stack?")
    local var = makeVar(type)
    local val = stack:pop()
    var(val)
    return var
end

function Runtime:getIndirectVar(index)
    -- Yep, magic numbers abound...
    local arrIdx = (index - (self.frame.proc.iTotalTableSize + 18)) // 2
    local result = self.frame.indirects[arrIdx + 1]
    if not result then
        -- for i, var in ipairs(self.frame.indirects) do
        --     printf("Indirect %i: %s\n", i, var())
        -- end
        error(string.format("Failed to resolve indirect index 0x%04x", index))
    end
    assert(result(), "Indirect has not yet been initialised?")
    return result
end

function Runtime:getVar(index, type, indirect)
    if indirect then
        return self:getIndirectVar(index)
    else
        return self:getLocalVar(index, type)
    end
end

-- Only for things that need to simulate a var (such as for making sync versions of async requests)
function Runtime:makeTemporaryVar(type, len, stringMaxLen)
    local result = makeVar(type)
    if isArrayType(type) then
        local val = newArrayVal(type & 0xF, len, stringMaxLen)
        result(val)
    end
    return result
end

function Runtime:addModule(path, procTable, opxTable)
    -- printf("addModule: %s\n", path)
    local name = oplpath.splitext(oplpath.basename(path)):upper()
    local mod = {
        -- Since 'name' isn't a legal procname (they're always uppercase in
        -- definitions, even though they're not necessarily when they are
        -- called) it is safe to use the same namespace as for the module's
        -- procnames.
        name = name,
        path = path,
        opxTable = opxTable,
    }
    for _, proc in ipairs(procTable) do
        mod[proc.name] = proc
    end
    table.insert(self.modules, mod)
    if not self.cwd then
        assert(oplpath.isabs(path), "Bad path for initial module!")
        self.cwd = path:sub(1, 3)
    end
end

function Runtime:unloadModule(path)
    for i, mod in ipairs(self.modules) do
        if mod.path == path then
            table.remove(self.modules, i)
            return
        end
    end
    printf("No loaded module found for %s!\n", path)
    error(KOplErrNotExists)
end

function Runtime:findProc(procName)
    -- procName must be upper cased
    for _, mod in ipairs(self.modules) do
        local proc = mod[procName]
        if proc then
            return proc
        end
    end
    error("No proc named "..procName.." found in loaded modules")
end

function Runtime:moduleForProc(proc)
    for _, mod in ipairs(self.modules) do
        for k, v in pairs(mod) do
            if v == proc then
                return mod
            end
        end
    end
    return nil
end

function Runtime:pushNewFrame(stack, proc, numParams)
    assert(numParams, "Must specify numParams!")
    if proc.params then
        assert(#proc.params == numParams, "Wrong number of arguments for proc "..proc.name)
    end

    local frame = {
        returnIP = self.ip,
        proc = proc,
        prevFrame = self.frame,
        vars = {},
        indirects = {},
    }
    self:setFrame(frame, proc.codeOffset)

    if not stack then
        -- Don't do any other runtime setup
        return
    end

    -- We don't need to define any globals, arrays or strings at this point,
    -- they are constructed when needed.

    -- COplRuntime leaves parameters stored on the stack and allocates a
    -- pointer in iIndirectTbl to access them. Since they're accessed the
    -- same way as externals, we have to do something similar, although
    -- there's no need to actually keep them on the stack, it's easier if we
    -- pop them here. We're ignoring the type-checking extra values that
    -- were pushed onto the stack prior to the RunProcedure call.

    for i = 1, numParams do
        local var = self:popParameter(stack)
        table.insert(frame.indirects, 1, var)
    end
    frame.returnStackSize = stack:getSize()
    if self.callTrace then
        printf("+%s() initstacksz=%d\n", proc.name, frame.returnStackSize)
    end

    for _, external in ipairs(proc.externals or {}) do
        -- Now resolve externals in the new fn by walking up the frame procs until
        -- we find a global with a matching name
        local parentFrame = frame
        local found
        while not found do
            parentFrame = parentFrame.prevFrame
            assert(parentFrame, "Failed to resolve external "..external.name)
            local parentProc = parentFrame.proc
            local globals
            if parentProc.fn then
                -- In Lua fns, globals are declared at runtime on a per-frame
                -- basis, rather than being a property of the proc
                globals = parentFrame.globals
            else
                globals = parentProc.globals
            end
            found = globals[external.name]
        end
        table.insert(frame.indirects, self:getLocalVar(found.offset, found.type, parentFrame))
        -- DEBUG
        -- printf("Fixed up external offset=0x%04X to indirect #%d\n", found.offset, #frame.indirects)
        -- for i, var in ipairs(self.frame.indirects) do
        --     printf("Indirect %i: %s\n", i, var())
        -- end
    end

    if proc.fn then
        -- It's a Lua-implemented proc meaning we don't just set ip and return
        -- to the event loop, we have to invoke it here. Conveniently
        -- frame.indirects contains exactly the proc args, in the right format.
        frame.globals = {}
        local args = {}
        for i, var in ipairs(frame.indirects) do
            args[i] = var()
        end
        local result = proc.fn(self, table.unpack(args))
        self:returnFromFrame(stack, result or 0)
    end
end

function Runtime:returnFromFrame(stack, val)
    if self.callTrace then
        printf("-%s()\n", self.frame.proc.name)
    end
    local prevFrame = self.frame.prevFrame
    stack:popTo(self.frame.returnStackSize)
    self:setFrame(prevFrame, self.frame.returnIP)
    if prevFrame then
        stack:push(val)
    end
end

function Runtime:setFrame(newFrame, ip)
    if newFrame then
        self.frame = newFrame
        self.ip = ip -- self.ip is always relative to self.frame.proc.data
        self.data = newFrame.proc.data -- which for convenience is also accessible as self.data
    else
        self.frame = nil
        self.ip = nil
        self.data = nil
    end
end

function Runtime:setFrameErrIp(errIp)
    self.frame.errIp = errIp
end

function Runtime:getLastError()
    return self.errorValue, self.errorLocation
end

function Runtime:getIp()
    return self.ip
end

function Runtime:setIp(ip)
    -- TODO should check it's still within the current frame
    local proc = self.frame.proc
    assert(ip, "Cannot set a nil ip!")
    if ip < proc.codeOffset or ip >= proc.codeOffset + proc.codeSize then
        error(fmt("Cannot jump to 0x%08X which is outside the current proc %s 0x%08X+%X",
            ip, proc.name, proc.codeOffset, proc.codeSize))
    end
    self.ip = ip
end

function Runtime:setTrap(flag)
    self.trap = flag
    if trap then
        -- Setting trap also clears current error
        self.errorValue = 0
    end
end

function Runtime:getTrap()
    return self.trap
end

function Runtime:iohandler()
    return self.ioh
end

function Runtime:currentProc()
    assert(self.frame and self.frame.proc, "No current process!")
    return self.frame.proc
end

function Runtime:setDialog(dlg)
    if dlg then
        dlg.frame = self.frame
    end
    self.dialog = dlg
end

function Runtime:getDialog()
    -- A dialog must always be setup and shown from the same frame
    assert(self.dialog and self.dialog.frame == self.frame, KOplStructure)
    return self.dialog
end

function Runtime:setMenu(m)
    if m then
        m.frame = self.frame
    end
    self.menu = m
end

function Runtime:getMenu()
    -- A menu must always be setup and shown from the same frame
    assert(self.menu and self.menu.frame == self.frame, KOplStructure)
    return self.menu
end

function Runtime:newGraphicsContext(id, width, height, isWindow, displayMode)
    local graphics = self:getGraphics()
    assert(graphics[id] == nil, "Graphics context already exists!")
    local newCtx = {
        id = id,
        displayMode = displayMode,
        mode = 0, -- set
        tmode = 0, -- set
        color = { 0, 0, 0 }, -- black
        bgcolor = { 255, 255, 255 }, -- white
        width = width,
        height = height,
        pos = { x = 0, y = 0 },
        isWindow = isWindow,
        font = FontIds[KDefaultFontUid],
        style = 0, -- normal text style
        penwidth = 1,
    }
    graphics[id] = newCtx
    -- Creating a new drawable always seems to update current
    graphics.current = newCtx
    return newCtx
end

function Runtime:getGraphics()
    if not self.graphics then
        self.graphics = {}
        local w, h = self.ioh.getScreenSize()
        self:newGraphicsContext(1, w, h, true)
        self.graphics.screen = {
            x = 0,
            y = 0,
            w = w // 7,
            h = h // 11,
            fontid = KFontCourierNormal11,
        }
        self.graphics.sprites = {}
    end
    return self.graphics
end

function Runtime:getGraphicsContext(id)
    local graphics = self:getGraphics()
    if id then
        return graphics[id]
    else
        return graphics.current
    end
end

function Runtime:setGraphicsContext(id)
    -- printf("setGraphicsContext %d\n", id)
    local graphics = self:getGraphics()
    local context = graphics[id]
    assert(context, KOplErrDrawNotOpen)
    graphics.current = context
end

function Runtime:closeGraphicsContext(id)
    local graphics = self:getGraphics()
    if id == graphics.current.id then
        graphics.current = graphics[1]
    end
    graphics[id] = nil
    self:flushGraphicsOps()
    self.ioh.graphicsop("close", id)
end

function Runtime:saveGraphicsState()
    local ctx = self:getGraphicsContext()
    return {
        id = ctx.id,
        mode = ctx.mode,
        tmode = ctx.tmode,
        color = ctx.color,
        bgcolor = ctx.bgcolor,
        pos = { x = ctx.pos.x, y = ctx.pos.y },
        font = ctx.font,
        style = ctx.style,
        flush = self:getGraphicsAutoFlush(),
    }
end

function Runtime:restoreGraphicsState(state)
    local ctx = self:getGraphicsContext(state.id)
    ctx.mode = state.mode
    ctx.tmode = state.tmode
    ctx.color = state.color
    ctx.bgcolor = state.bgcolor
    ctx.pos = { x = state.pos.x, y = state.pos.y }
    ctx.font = state.font
    ctx.style = state.style
    self:setGraphicsContext(state.id)
    self:setGraphicsAutoFlush(state.flush)
end

function Runtime:drawCmd(type, op)
    if not op then op = {} end
    local graphics = self:getGraphics()
    local context = graphics.current
    op.id = context.id
    op.type = type
    if not op.mode then
        op.mode = context.mode
    end
    op.color = context.color
    op.bgcolor = context.bgcolor
    if not op.x then
        op.x = context.pos.x
    end
    if not op.y then
        op.y = context.pos.y
    end
    op.style = context.style
    op.penwidth = context.penwidth
    op.tmode = context.tmode
    op.fontface = context.font.face
    op.fontsize = context.font.size
    op.fontbold = context.font.bold

    if graphics.buffer then
        table.insert(graphics.buffer, op)
    else
        self.ioh.draw({ op })
    end
end

function Runtime:flushGraphicsOps()
    local graphics = self:getGraphics()
    if graphics.buffer and graphics.buffer[1] then
        self.ioh.draw(graphics.buffer)
        graphics.buffer = {}
    end
end

function Runtime:setGraphicsAutoFlush(flag)
    local graphics = self:getGraphics()
    if flag then
        self:flushGraphicsOps()
        graphics.buffer = nil
    else
        if not graphics.buffer then
            graphics.buffer = {}
        end
    end
end

function Runtime:getGraphicsAutoFlush()
    return self:getGraphics().buffer == nil
end

function Runtime:openDb(logName, tableSpec, variables, op)
    assert(self.dbs[logName] == nil, KOplErrOpen)
    local path, tableName, fields = database.parseTableSpec(tableSpec)
    path = self:abs(path)
    if fields == nil then
        -- SIBO-style call where field names are derived from the variable names
        fields = {}
        for i, var in ipairs(variables) do
            local fieldName = var.name:gsub("[%%&$]$", {
                ["%"] = "i",
                ["&"] = "a",
                ["$"] = "s",
            })
            fields[i] = {
                name = fieldName,
                type = var.type,
                -- TODO string maxlen?
            }
        end
    end

    local readonly = op == "OpenR"
    -- Check if there are already any other open handles to this db
    local cpath = oplpath.canon(path)
    for _, db in pairs(self.dbs) do
        if oplpath.canon(db:getPath()) == cpath then
            if not readonly or db:isWriteable() then
                error(KOplErrInUse)
            end
        end
    end

    local db = database.new(path, readonly)
    -- See if db already exists
    local dbData, err = self.ioh.fsop("read", path)
    if dbData then
        db:load(dbData)
    elseif err == KOplErrNotExists and op == "Create" then
        -- This is fine
    else
        error(err)
    end

    if op == "Create" then
        db:createTable(tableName, fields)
    end

    db:setView(tableName, fields, variables)
    self.dbs[logName] = db
    self.dbs.current = logName
end

function Runtime:getDb(logName)
    local db = self.dbs[logName or self.dbs.current]
    assert(db, KOplErrClosed)
    return db
end

function Runtime:useDb(logName)
    self:getDb(logName) -- Check it's valid
    self.dbs.current = logName
end

function Runtime:closeDb()
    local db = self:getDb()
    if db:isModified() then
        local data = db:save()
        local err = self.ioh.fsop("write", db:getPath(), data)
        assert(err == KErrNone, err)
    end
    self.dbs[self.dbs.current] = nil
    self.dbs.current = nil
end

function Runtime:newFileHandle()
    local h = #self.files + 1
    local f = {
        h = h,
    }
    self.files[h] = f
    return f
end

function Runtime:getFile(handle)
    local f = self.files[handle]
    return f
end

function Runtime:closeFile(handle)
    self.files[handle] = nil
end

function Runtime:setResource(name, val)
    -- print("setResource", name, val)
    self.resources[name] = val
end

function Runtime:getResource(name)
    return self.resources[name]
end

function newModuleInstance(moduleName)
    -- Because opl.lua uses a shared upvalue for its runtime pointer, we need to
    -- give each runtime its own copy of the module, meaning we can't just
    -- require() it and we have to abuse the fact that we know
    -- OpoInterpreter.swift keeps package.searchers[2] as "the thing to call to
    -- load a .lua file" just like the stock Lua runtime does.
    local loader = package.searchers[2](moduleName)
    assert(type(loader) == "function", loader)
    local instance = loader()
    return instance
end

function newRuntime(handler)
    local rt = Runtime {
        allocs = {},
        dbs = {},
        modules = {},
        files = {},
        ioh = handler or require("defaultiohandler"),
        resources = {}, -- keyed by string, anything that code wants to use to provide singleton/mutex/etc semantics
        signal = 0,
    }

    local opl = newModuleInstance("opl")
    -- And make all the opl functions accessible as eg runtime:gUSE(1)
    for name, fn in pairs(opl) do
        if type(fn) == "function" then
            assert(rt[name] == nil, "Overlapping function names between Runtime and opl.lua!")
            rt[name] = function(self, ...) return opl[name](...) end
        end
    end
    opl._setRuntime(rt)
    rt.opl = opl
    return rt
end

function printInstruction(currentOpIdx, opCode, op, extra)
    printf("%08X: %02X [%s] %s\n", currentOpIdx, opCode, op, extra or "")
end

function Runtime:decodeNextInstruction()
    local currentIp = self.ip
    local opCode = sbyte(self.data, currentIp + 1)
    if not opCode then
        return fmt("%08X: ???", currentIp)
    end
    local op = ops.codes[opCode]
    self.ip = currentIp + 1
    local opDump = op and op.."_dump"
    local extra = ops[opDump] and ops[opDump](self)
    return fmt("%08X: %02X [%s] %s", currentIp, opCode, op or "?", extra or "")
end

function Runtime:dumpRawBytesUntil(newIp)
    while self.ip < newIp do
        local val = string.unpack("b", self.data, 1 + self.ip)
        local valu = string.unpack("B", self.data, 1 + self.ip)
        local ch = string.char(valu):gsub("[\x00-\x1F\x7F-\xFF]", "?")
        printf("%08X: %02X (%d) '%s'\n", self.ip, valu, val, ch)
        self.ip = self.ip + 1
    end

end

function Runtime:dumpProc(procName, startAddr)
    local proc = self:findProc(procName)
    local endIdx = proc.codeOffset + proc.codeSize
    self:pushNewFrame(nil, proc, #proc.params)
    if startAddr then
        self.ip = startAddr
    end
    local realCodeStart = proc.codeOffset
    while self.ip < endIdx do
        if self.ip == realCodeStart and string.unpack("B", self.data, 1 + self.ip) == 0xBF then
            -- Workaround for a main proc starting with a goto that jumps over some non-code
            -- data.
            local jmp = string.unpack("<i2", self.data, 1 + self.ip + 1)
            local newIp = self.ip + jmp
            print(self:decodeNextInstruction()) -- prints the goto
            self:dumpRawBytesUntil(newIp)
            realCodeStart = newIp
        elseif self.ip == realCodeStart and string.unpack("c3", self.data, 1 + self.ip) == "\x4F\x00\x5B" then
            -- Similarly, workaround a [StackByteAsWord] 0, [BranchIfFalse]
            local jmp = string.unpack("<i2", self.data, 1 + self.ip + 3)
            local newIp = self.ip + 2 + jmp
            print(self:decodeNextInstruction()) -- StackByteAsWord
            print(self:decodeNextInstruction()) -- BranchIfFalse
            self:dumpRawBytesUntil(newIp)
            realCodeStart = newIp
        else
            print(self:decodeNextInstruction())
        end
    end
    self:setFrame(nil)
end

local function run(self, stack)
    local opsync = self.ioh.opsync
    while self.ip do
        self.frame.lastIp = self.ip
        local opCode, op = self:nextOp()
        local opFn = ops[op]
        if not opFn then
            error(fmt("No implementation of op %s at codeOffset 0x%08X in %s\n", op, self.frame.lastIp, self.frame.proc.name))
        end
        if self.instructionDebug then
            local savedIp = self.ip
            self.ip = self.frame.lastIp
            print(self:decodeNextInstruction(), fmt("stack=%d", stack.n))
            self.ip = savedIp
        end
        ops[op](stack, self)
        opsync()
    end
end

function Runtime:setInstructionDebug(flag)
    self.instructionDebug = flag
end

function Runtime:setCallTrace(flag)
    self.callTrace = flag
end

ErrObj = {
    __tostring = function(self)
        return fmt("%s\n%s\n%s", self.msg or self.code, self.opoStack, self.luaStack)
    end
}
ErrObj.__index = ErrObj

local function findLocationOfFnOnStack(fn)
    local lvl = 2
    while true do
        local dbgInfo = debug.getinfo(lvl, "f")
        if dbgInfo == nil then
            -- fn not found on stack, shouldn't happen...
            return "?"
        elseif dbgInfo.func == fn then
            dbgInfo = debug.getinfo(lvl, "Sl")
            return fmt("%s:%d", dbgInfo.source:sub(2), dbgInfo.currentline)
        end
        lvl = lvl + 1
    end
end

local function addStacktraceToError(self, err, callingFrame)
    if callingFrame then
        -- Save caller info for later, when we're (potentially) adding this
        -- frame to a callstack in a subsequent higher-level error call. This
        -- avoids us having to do it every time there's a call to pcallProc
        -- which doesn't result in an error.
        assert(callingFrame.proc.fn, "There's a calling frame but no Lua fn?!")
        callingFrame.lastPcallSite = findLocationOfFnOnStack(callingFrame.proc.fn)
    end

    local frameDescs = {}
    local erroringFrame = self.frame
    local savedIp = self.ip
    -- In order to get instruction decode in the stacktrace we must swizzle
    -- frames around, but note we don't actually unwind them.
    while self.frame ~= callingFrame do
        local mod = self:moduleForProc(self.frame.proc)
        local info
        if self.frame.proc.fn then
            info = fmt("%s\\%s: [Lua] %s", mod.name, self.frame.proc.name, self.frame.lastPcallSite or "?")
        else
            self.ip = self.frame.lastIp
            info = fmt("%s\\%s:%s", mod.name, self.frame.proc.name, self:decodeNextInstruction())
        end
        table.insert(frameDescs, info)
        self:setFrame(self.frame.prevFrame)
    end
    self:setFrame(erroringFrame, savedIp) -- Restore correct stack frame
    local stack = table.concat(frameDescs, "\n")
    if err.opoStack then
        err.opoStack = err.opoStack.."\n"..stack
    else
        err.opoStack = stack
    end
end

function Runtime:getOpoStacktrace()
    local err = {}
    addStacktraceToError(self, err, nil)
    return err.opoStack
end

local function traceback(msgOrCode)
    local t = type(msgOrCode)
    if t == "table" then
        -- We've already got the Lua stacktrace, nothing more to do here
        return msgOrCode
    end

    local err = setmetatable({
        code = t == "number" and msgOrCode,
        luaStack = debug.traceback(nil, 2),
    }, ErrObj)
    if err.code then
        err.msg = fmt("%d (%s)", err.code, Errors[err.code] or "?")
    else
        err.msg = msgOrCode
    end
    return err
end

function Runtime:pcallProc(procName, ...)
    local callingFrame = self.frame
    assert(callingFrame == nil or callingFrame.proc.fn, "Cannnot callProc while still executing something else!")

    local proc = self:findProc(procName)
    local args = table.pack(...)
    assert(args.n == #proc.params, "Wrong number of arguments in call to "..procName)

    self.errorValue = KErrNone
    local stack = newStack()
    for i = 1, args.n do
        stack:push(args[i])
        stack:push(proc.params[i]) -- Hope this matches, should probably check...
    end

    self:pushNewFrame(stack, proc, args.n) -- sets self.frame and self.ip
    while self.ip do
        local ok, err = xpcall(run, traceback, self, stack)
        if not ok then
            addStacktraceToError(self, err, callingFrame)
            -- print(err)
            self.errorLocation = fmt("Error in %s\\%s", self:moduleForProc(self.frame.proc).name, self.frame.proc.name)
            if err.code and err.code ~= KStopErr then
                self.errorValue = err.code
                -- An error code that might potentially be handled by a Trap or OnErr
                if self.trap then
                    self.trap = false
                    -- And continue to next instruction
                else
                    -- See if this frame or any parent frame up to callingFrame has an error handler
                    while true do
                        if self.frame.errIp then
                            self.ip = self.frame.errIp
                            break
                        else
                            stack:popTo(self.frame.returnStackSize)
                            local prevFrame = self.frame.prevFrame
                            self:setFrame(prevFrame)
                            if prevFrame ~= callingFrame then
                                -- And loop again
                            else
                                return err
                            end
                        end
                    end
                end
            else
                self:setFrame(callingFrame)
                return err
            end
        end
    end
    assert(self.frame == callingFrame, "Frame was not restored on pcallProc exit!")
    return nil -- no error
end

function Runtime:callProc(procName, ...)
    local err = self:pcallProc(procName, ...)
    if err then
        error(err)
    end
end

function Runtime:loadModule(path)
    local origPath = path
    printf("Runtime:loadModule(%s)\n", origPath)
    -- First see if this is a real module
    local data = self.ioh.fsop("read", path)
    if not data then
        path = origPath..".opm"
        data = self.ioh.fsop("read", path)
    end
    if not data then
        path = origPath..".opo"
        data = self.ioh.fsop("read", path)
    end
    if data then
        local procTable, opxTable = require("opofile").parseOpo(data, self.instructionDebug)
        self:addModule(path, procTable, opxTable)
        return
    end

    -- If not, see if we have a built-in
    path = origPath
    local modName = oplpath.splitext(oplpath.basename(path:lower()))
    local ok, mod = pcall(newModuleInstance, "modules."..modName)

    if not ok then
        printf("Module %s (from %s) not found\n", modName, path)
        error(KOplErrNoMod)
    end

    local procTable = {}
    for k, v in pairs(mod) do
        assert(type(v) == "function", "Unexpected top-level value in module that isn't a function")
        local proc = {
            name = k:upper(),
            fn = v
        }
        table.insert(procTable, proc)
    end
    self:addModule(path, procTable)
    -- finally, import all the helper fns from opl.lua into mod's environment
    for name, fn in pairs(self.opl) do
        if not name:match("^_") then
            mod[name] = fn
        end
    end
end

function Runtime:declareGlobal(name, arrayLen)
    local frame = self.frame
    name = name:upper()
    assert(self.ip == nil and frame.proc.fn and frame.globals, "Can only declareGlobal from within a Lua module!")

    local valType
    if name:match("%%$") then
        valType = DataTypes.EWord
    elseif name:match("&$") then
        valType = DataTypes.ELong
    elseif name:match("%$$") then
        valType = DataTypes.EString
    else -- no suffix means float
        valType = DataTypes.EReal
    end

    -- We define our indexes (which are how externals map to locals) as simply
    -- being the position of the item in the frame vars table. We can skip
    -- figuring out a byte-exact frame index because nothing actually needs to
    -- know it.
    local index = #frame.vars + 1

    local var = makeVar(valType)
    frame.globals[name] = { offset = index, type = valType }
    frame.vars[index] = var

    if arrayLen then
        var(newArrayVal(valType, arrayLen))
    else
        var(DefaultSimpleTypes[valType])
    end
    return var
end

function Runtime:waitForAnyRequest()
    if self.signal > 0 then
        self.signal = self.signal - 1
        return
    end
    -- Have to make sure all ops are flushed before blocking
    self:flushGraphicsOps()
    local ok = self.ioh.waitForAnyRequest()
    -- A wait technically decrements the signal count, but completing it would
    -- increment it again hence a call to iohandler.waitForAnyRequest() that
    -- returns leaves the signal count unchanged.
    assert(ok, KStopErr)
end

function Runtime:waitForRequest(stat)
    local waits = -1
    repeat
        waits = waits + 1
        self:waitForAnyRequest()
    until not stat:isPending()
    -- And balance any waits we did for things that weren't stat
    self:requestSignal(waits)
end

function Runtime:checkCompletions()
    self.signal = self.signal + self.ioh.checkCompletions()
end

function Runtime:requestSignal(num)
    self.signal = self.signal + (num or 1)
end

function Runtime:getPath()
    return self.modules[1].path
end

function Runtime:getCwd()
    return self.cwd
end

function Runtime:setCwd(cwd)
    assert(oplpath.isabs(cwd), "Cannot set a non-absolute CWD!")
    assert(cwd:match("\\$"), "Cannot set a non-dir path as CWD!")
    self.cwd = cwd
end

function Runtime:abs(path)
    return oplpath.abs(path, self.cwd)
end

local function globToMatch(glob)
    local m = glob:gsub("[.+%%^$%(%)%[%]-]", "%%%0"):gsub("%?", "."):gsub("%*", ".*")
    return m
end

function Runtime:dir(path)
    -- printf("dir: %s\n", path)
    if path == "" then
        local result = self.dirResults and self.dirResults[1]
        if result then
            table.remove(self.dirResults, 1)
        end
        return result or ""
    end

    local dir, filenameFilter = oplpath.split(path)
    local contents, err = self.ioh.fsop("dir", oplpath.join(dir, ""))
    if not contents then
        error(err)
    end
    if #filenameFilter > 0 then
        local filtered = {}
        local m = "^"..globToMatch(filenameFilter).."$"
        for i, path in ipairs(contents) do
            local _, name = oplpath.split(path)
            -- printf("Checking %s against match %s\n", name, m)
            if name:match(m) then
                table.insert(filtered, path)
            end
        end
        self.dirResults = filtered
    else
        self.dirResults = contents
    end
    return self:dir("")
end

--[[
Cell address encoding scheme:

Allocs < 64KB get the format 0000xxxx to 7FFFxxxx (where xxxx is the offset
within the cell) meaning we can track up to 32k individual small allocations.

Allocs >= 64KB get the format 80xxxxxx to FFxxxxxx allowing for 128 huge
allocations (up to 16MB which seems like a reasonable upper limit).

allocations are indexed by their top 4 (for small allocs) or 2 (for big allocs)
bytes into runtime.allocs which is also reverse-indexed too. ie for the first
small alloc:

runtime.allocs[0x00010000] = AddrSlice {...}
runtime.allocs[addrSlice] = 0x00010000
]]

local kLargeAllocMask = 0xFF000000
local kSmallAllocMask = 0xFFFF0000
local kMaxSmallAlloc = 0xFFFF

local function baseAddress(addr)
    if addr & 0x80000000 > 0 then
        -- Large alloc
        return addr & kLargeAllocMask
    else
        return addr & kSmallAllocMask
    end
end

function Runtime:addrFromInt(addr)
    if type(addr) == "table" then
        -- It's already an AddrSlice
        return addr
    end
    addr = addr % (1<<32)
    local base = baseAddress(addr)
    local offset = addr - base
    result = self.allocs[base]
    if not result then
        error(string.format("Failed to find allocation for address 0x%08X", addr))
    end
    return result + offset
end

function Runtime:nextSmallAlloc()
    local addr = 0x00010000
    while self.allocs[addr] do
        addr = addr + 0x00010000
    end
    assert(addr < 0x80000000, "OOM!")
    return addr
end

function Runtime:nextLargeAlloc()
    local addr = 0x80000000
    while self.allocs[addr] do
        addr = addr + 0x01000000
    end
    assert(addr < 0xFFFFFFFF, "OOM!")
    return addr
end

function Runtime:addrToInt(addr)
    if type(addr) == "number" then
        return addr
    else
        -- Do we already have one?
        local key = addr.mem or addr.var -- track based on var or mem since AddrSlice objects are ephemeral
        local baseAddr = self.allocs[key]
        if not baseAddr then
            if addr.len > kMaxSmallAlloc then
                baseAddr = self:nextLargeAlloc()
            else
                baseAddr = self:nextSmallAlloc()
            end
            self.allocs[baseAddr] = addr:baseAddr()
            self.allocs[key] = baseAddr
            -- printf("%s -> 0x%08X\n", key, baseAddr)
        end
        return toint32(baseAddr + addr.offset)
    end
end

function Runtime:realloc(addr, sz)
    -- printf("Runtime:realloc(%s, %d)\n", addr, sz) --, self:getOpoStacktrace())
    local sz = (sz + 3) & ~3
    if addr == nil then
        local addr
        if self.ioh.realloc then
            local mem = self.ioh.realloc(nil, sz)
            addr = memory.AddrSlice {
                offset = 0,
                len = sz,
                mem = mem
            }
        else
            local var = self:makeTemporaryVar(DataTypes.ELongArray, sz // 4)
            addr = var()[1]:addressOf()
        end
        return self:addrToInt(addr)
    end

    assert(addr.offset == 0, "Cannot realloc a non-alloc'd address!")
    local k = addr.mem or addr.var
    local baseAddr = self.allocs[k]
    assert(baseAddr, "Can't find allocation in allocs table!")
    if sz == 0 then
        if addr.mem then
            self.ioh.realloc(addr.mem, 0)
        end
        self.allocs[k] = nil
        self.allocs[baseAddr] = nil
        return 0
    elseif sz < addr.len then
        addr.len = sz
    elseif sz > addr.len then
        local newAddr = self:realloc(nil, sz)
        newAddr:write(addr:read(addr.len))
        self:realloc(addr, 0)
        addr = newAddr
    end
    return self:addrToInt(addr)
end

function runOpo(fileName, procName, iohandler, verbose)
    local rt = newRuntime(iohandler)
    rt:setInstructionDebug(verbose)
    local data, err = rt:iohandler().fsop("read", fileName)
    if not data then
        error("Failed to read opo file data")
    end

    local procTable, opxTable = require("opofile").parseOpo(data, verbose)
    rt:addModule(fileName, procTable, opxTable)
    local procToCall = procName and procName:upper() or procTable[1].name
    local err = rt:pcallProc(procToCall)
    if err and err.code == KStopErr then
        -- Don't care about the distinction
        err = nil
    end
    return err
end

function installSis(data, iohandler)
    local rt = newRuntime(iohandler)
    local sis = require("sis")
    local sisfile = sis.parseSisFile(data, false)

    local langIdx = 1
    -- Find which language index refers to English (not worrying about extracting other langs just yet)
    for i, lang in ipairs(sisfile.langs) do
        if lang == "EN" then
            langIdx = i
            break
        end
    end

    for _, file in ipairs(sisfile.files) do
        if file.type == sis.FileType.File then
            -- extractFile(file, langIdx, dest)
            local path = file.dest:gsub("^.:\\", "C:\\")
            local dir = oplpath.dirname(path)
            if iohandler:fsop("isdir", dir) == KOplErrNotExists then
                rt:MKDIR(dir)
            end
            local data = file.data
            if not data then
                data = file.langData[langIdx]
            end
            local err = iohandler.fsop("write", path, data)
            assert(err == KErrNone, "Failed to write to "..path)
        end
    end
end

return _ENV
