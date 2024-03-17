#!/usr/bin/env lua

--[[

Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe

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

sep=package.config:sub(1,1);dofile(arg[0]:sub(1, arg[0]:match(sep.."?()[^"..sep.."]+$") - 1).."cmdline.lua")

function main()
    local args = getopt({
        "filename",
        "fnName",
        "startAddr",
        all = true,
        help = true, h = "help",
    })
    local fnName = args.fnName
    local all = args.all
    if args.help then
        printf("Syntax: dumpopo.lua <filename> [--all]\n")
        printf("        dumpopo.lua <filename> [<fnName> [<startAddr>]]\n")
        return os.exit(false)
    end
    local data = readFile(args.filename)
    local startAddr = args.startAddr and tonumber(args.startAddr, 16)
    local verbose = all or fnName == nil
    opofile = require("opofile")
    runtime = require("runtime")
    local procTable, opxTable, era = opofile.parseOpo(data, verbose)
    local rt = runtime.newRuntime(nil, era)
    rt:addModule("C:\\module", procTable, opxTable)
    if fnName then
        opofile.printProc(rt:findProc(fnName:upper()))
        rt:dumpProc(fnName:upper(), startAddr)
    else
        for i, proc in ipairs(procTable) do
            printf("%d: ", i)
            opofile.printProc(proc)
            if all then
                rt:dumpProc(proc.name)
            end
        end
    end
end

pcallMain()
