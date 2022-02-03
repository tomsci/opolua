--[[

Copyright (c) 2021-2022 Jason Morley, Tom Sutcliffe

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

-- A default implementation of the iohandler interface, mapping to basic console
-- interactions using io.stdin and stdout.

local fmt = string.format

local statusRequests = {}

function print(val)
    printf("%s", val)
end

function editValue(params)
    local line = io.stdin:read()
    -- We don't support pressing esc to clear the line, oh well
    if params.allowCancel and line:byte(1, 1) == 27 then
        -- Close enough...
        return nil
    end
    return line
end

function getch()
    -- Can't really do this with what Lua's io provides, as stdin is always in line mode
    printf("GET called:")
    local ch = io.stdin:read(1)
    return ch:byte(1, 1)
end

function beep(freq, duration)
    printf("BEEP %gkHz for %gs", freq, duration)
end

function dialog(d)
    printf("---DIALOG---\n%s\n", d.title)
    for i, item in ipairs(d.items) do
        -- printf("ITEM:%d\n", item.type)
        printf("% 2d. ", i)
        if item.prompt and #item.prompt > 0 then
            printf("%s: ", item.prompt)
        end
        if item.type == dItemTypes.dCHOICE then
            printf("%s: %s (default=%d)\n", item.prompt, table.concat(item.choices, " / "), item.value)
        elseif item.value then
            printf("%s\n", item.value)
        else        end
    end
    for _, button in ipairs(d.buttons or {}) do
        printf("[Button %d]: %s\n", button.key, button.text)
    end
    -- TODO some actual editing support?
    printf("---END DIALOG---\n")
    return 0 -- meaning cancelled
end

function menu(m)
    local function fmtCode(code)
        local keycode = math.abs(code) & 0xFF
        if keycode >= string.byte("A") and keycode <= string.byte("Z") then
            return string.format("Ctrl-Shift-%s", string.char(keycode):upper())
        elseif keycode > 32 then
            return string.format("Ctrl-%s", string.char(keycode):upper())
        else
            return tostring(keycode)
        end
    end
    local function printCard(idx, card, lvl)
        local indent = string.rep(" ", lvl * 4)
        for i, item in ipairs(card) do
            local hightlightIdx = idx and 256 * (idx - 1) + (i - 1)
            printf("%s%s. %s [%s]\n", indent, hightlightIdx or "", item.text, fmtCode(item.keycode))
            if item.submenu then
                printCard(nil, item.submenu, lvl + 1)
            end
            if item.keycode < 0 then
                -- separator after
                printf("--\n")
            end
        end
    end

    printf("---MENU---\n")
    for menuIdx, card in ipairs(m) do
        printf("%s:\n", card.title)
        printCard(menuIdx, card, 0)
    end
    printf("---END MENU---\n")
    return 0, 0 -- ie cancelled
end

local function describeOp(op)
    local ret = fmt("%s x=%d y=%d", op.type, op.x, op.y)
    if op.type == "circle" then
        ret = ret .. fmt(" radius=%d fill=%d", op.r, op.fill)
    elseif op.type == "line" then
        ret = ret .. fmt(" x2=%d y2=%d", op.x2, op.y2)
    end
    return ret
end

function draw(ops)
    for _, op in ipairs(ops) do
        printf("%s\n", describeOp(op))
    end
end

function graphicsop(cmd, ...)
    printf("graphicsop %s\n", cmd)
    if cmd == "textsize" then
        local text = ...
        return 7 * #text, 11, 9
    end
    return 0 -- Pretend we succeed (probably)
end

function getScreenInfo()
    return 640, 240, KgCreate4GrayMode
end

local fsmaps = {}

function fsmap(devicePath, hostPath)
    table.insert(fsmaps, { devicePath = devicePath, hostPath = hostPath })
end

local function mapDevicePath(path)
    for _, m in ipairs(fsmaps) do
        -- printf("Considering devicePath %s -> %s for %s\n", m.devicePath, m.hostPath, path)
        if path:sub(1, #m.devicePath) == m.devicePath then
            return m.hostPath .. path:sub(#m.devicePath + 1):gsub("\\", "/")
        end
    end
    error("No device path mapping for "..path)
end

local function fileErrToOpl(errno)
    if errno == 2 then -- ENOENT = 2
        return KErrNotExists
    else
        return KErrNotReady
    end
end

function fsop(cmd, path, ...)
    local filename = mapDevicePath(path)
    if cmd == "exists" then
        -- printf("exists %s\n", filename)
        local f = io.open(filename, "r")
        if f then
            f:close()
            return KErrExists
        else
            return KErrNotExists
        end
    elseif cmd == "delete" then
        printf("delete %s\n", filename)
        local ok, err, errno = os.remove(filename)
        return ok and KErrNone or fileErrToOpl(errno)
    elseif cmd == "mkdir" then
        printf("mkdir %s\n", filename)
        local ret, err = os.execute(fmt('mkdir -p "%s"', filename))
        -- Not handling the already exists case, because mkdir -p doesn't. Don't care.
        if ret then
            return KErrNone
        else
            return KErrNotReady
        end
    elseif cmd == "write" then
        printf("write %s\n", filename)
        local data = ...
        local f, err, errno = io.open(filename, "wb")
        if f then
            f:write(data)
            f:close()
            return KErrNone
        else
            return fileErrToOpl(errno)
        end
    elseif cmd == "read" then
        local f, err, errno = io.open(filename, "rb")
        if f then
            local data = f:read("a")
            f:close()
            return data
        else
            return nil, fileErrToOpl(errno)
        end
    else
        error("Unrecognised fsop "..cmd)
    end
end

function asyncRequest(name, requestTable)
    assert(name == "getevent", "Unknown asyncRequest "..name)
    statusRequests[name] = requestTable
end

function waitForAnyRequest()
    -- This is a very cut-down implementation that doesn't handle much
    local eventRequest = statusRequests["getevent"]
    if not eventRequest then
        error("No outstanding requests we can complete, gonna error instead")
    end

    local ch = getch()
    eventRequest.ev:writeArray({ch}, DataTypes.ELong)
    eventRequest.var(0)
    statusRequests["getevent"] = nil
    return true
end

function createWindow(x, y, width, height, flags)
    return 0 -- Pretend we succeeded
end

function createBitmap(width, height)
    return 0 -- Pretend we succeeded
end

function getTime()
    return os.time()
end

function key()
    return 0
end

function opsync()
end

function getConfig(key)
    return ""
end

function setConfig(key, val)
    printf("setConfig(%q, %q)\n", key, val)
end

function setAppTitle(title)
end

function displayTaskList()
end

function setForeground()
end

function setBackground()
end

return _ENV
