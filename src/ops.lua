_ENV = module()

local fns = require("fns")
local fmt = string.format
local Word, Long, Real, String = DataTypes.EWord, DataTypes.ELong, DataTypes.EReal, DataTypes.EString
local WordArray, LongArray, RealArray, StringArray = DataTypes.EWordArray, DataTypes.ELongArray, DataTypes.ERealArray, DataTypes.EStringArray

codes = {
    [0x00] = "SimpleDirectRightSideInt",
    [0x01] = "SimpleDirectRightSideLong",
    [0x02] = "SimpleDirectRightSideFloat",
    [0x03] = "SimpleDirectRightSideString",
    [0x04] = "SimpleDirectLeftSideInt",
    [0x05] = "SimpleDirectLeftSideLong",
    [0x06] = "SimpleDirectLeftSideFloat",
    [0x07] = "SimpleDirectLeftSideString",
    [0x08] = "SimpleInDirectRightSideInt",
    [0x09] = "SimpleInDirectRightSideLong",
    [0x0A] = "SimpleInDirectRightSideFloat",
    [0x0B] = "SimpleInDirectRightSideString",
    [0x0C] = "SimpleInDirectLeftSideInt",
    [0x0D] = "SimpleInDirectLeftSideLong",
    [0x0E] = "SimpleInDirectLeftSideFloat",
    [0x0F] = "SimpleInDirectLeftSideString",
    [0x10] = "ArrayDirectRightSideInt",
    [0x11] = "ArrayDirectRightSideLong",
    [0x12] = "ArrayDirectRightSideFloat",
    [0x13] = "ArrayDirectRightSideString",
    [0x14] = "ArrayDirectLeftSideInt",
    [0x15] = "ArrayDirectLeftSideLong",
    [0x16] = "ArrayDirectLeftSideFloat",
    [0x17] = "ArrayDirectLeftSideString",
    [0x18] = "ArrayInDirectRightSideInt",
    [0x19] = "ArrayInDirectRightSideLong",
    [0x1A] = "ArrayInDirectRightSideFloat",
    [0x1B] = "ArrayInDirectRightSideString",
    [0X1C] = "ArrayInDirectLeftSideInt",
    [0x1D] = "ArrayInDirectLeftSideLong",
    [0x1E] = "ArrayInDirectLeftSideFloat",
    [0x1F] = "ArrayInDirectLeftSideString",
    [0x20] = "FieldRightSideInt",
    [0x21] = "FieldRightSideLong",
    [0x22] = "FieldRightSideFloat",
    [0x23] = "FieldRightSideString",
    [0x24] = "FieldLeftSideInt",
    [0x25] = "FieldLeftSideLong",
    [0x26] = "FieldLeftSideFloat",
    [0x27] = "FieldLeftSideString",
    [0x28] = "ConstantInt",
    [0x29] = "ConstantLong",
    [0x2A] = "ConstantFloat",
    [0x2B] = "ConstantString",
    [0x2C] = "IllegalOpCode",
    [0x2D] = "IllegalOpCode",
    [0x2E] = "IllegalOpCode",
    [0x2F] = "IllegalOpCode",
    [0x30] = "CompareLessThanInt",
    [0x31] = "CompareLessThanLong",
    [0x32] = "CompareLessThanFloat",
    [0x33] = "CompareLessThanString",
    [0x34] = "CompareLessOrEqualInt",
    [0x35] = "CompareLessOrEqualLong",
    [0x36] = "CompareLessOrEqualFloat",
    [0x37] = "CompareLessOrEqualString",
    [0x38] = "CompareGreaterThanInt",
    [0x39] = "CompareGreaterThanLong",
    [0x3A] = "CompareGreaterThanFloat",
    [0x3B] = "CompareGreaterThanString",
    [0x3C] = "CompareGreaterOrEqualInt",
    [0x3D] = "CompareGreaterOrEqualLong",
    [0x3E] = "CompareGreaterOrEqualFloat",
    [0x3F] = "CompareGreaterOrEqualString",
    [0x40] = "CompareEqualInt",
    [0x41] = "CompareEqualLong",
    [0x42] = "CompareEqualFloat",
    [0x43] = "CompareEqualString",
    [0x44] = "CompareNotEqualInt",
    [0x45] = "CompareNotEqualLong",
    [0x46] = "CompareNotEqualFloat",
    [0x47] = "CompareNotEqualString",
    [0x48] = "AddInt",
    [0x49] = "AddLong",
    [0x4A] = "AddFloat",
    [0x4B] = "AddString",
    [0x4C] = "SubtractInt",
    [0x4D] = "SubtractLong",
    [0x4E] = "SubtractFloat",
    [0x4F] = "StackByteAsWord",
    [0x50] = "MultiplyInt",
    [0x51] = "MultiplyLong",
    [0x52] = "MultiplyFloat",
    [0x53] = "RunProcedure",
    [0x54] = "DivideInt",
    [0x55] = "DivideLong",
    [0x56] = "DivideFloat",
    [0x57] = "CallFunction",
    [0x58] = "PowerOfInt",
    [0x59] = "PowerOfLong",
    [0x5A] = "PowerOfFloat",
    [0x5B] = "BranchIfFalse",
    [0x5C] = "AndInt",
    [0x5D] = "AndLong",
    [0x5E] = "AndFloat",
    [0x5F] = "StackByteAsLong",
    [0x60] = "OrInt",
    [0x61] = "OrLong",
    [0x62] = "OrFloat",
    [0x63] = "StackWordAsLong",
    [0x64] = "NotInt",
    [0x65] = "NotLong",
    [0x66] = "NotFloat",
    [0x67] = "Statement16",
    [0x68] = "UnaryMinusInt",
    [0x69] = "UnaryMinusLong",
    [0x6A] = "UnaryMinusFloat",
    [0x6B] = "CallProcByStringExpr",
    [0x6C] = "PercentLessThan",
    [0x6D] = "PercentGreaterThan",
    [0x6E] = "PercentAdd",
    [0x6F] = "PercentSubtract",
    [0x70] = "PercentMultiply",
    [0x71] = "PercentDivide",
    [0x72] = "IllegalOpCode",
    [0x73] = "IllegalOpCode",
    [0x74] = "ZeroReturnInt",
    [0x75] = "ZeroReturnLong",
    [0x76] = "ZeroReturnFloat",
    [0x77] = "NullReturnString",
    [0x78] = "LongToInt",
    [0x79] = "FloatToInt",
    [0x7A] = "FloatToLong",
    [0x7B] = "IntToLong",
    [0x7C] = "IntToFloat",
    [0x7D] = "LongToFloat",
    [0x7E] = "LongToUInt",
    [0x7F] = "FloatToUInt",
    [0x80] = "DropInt",
    [0x81] = "DropLong",
    [0x82] = "DropFloat",
    [0x83] = "DropString",
    [0x84] = "AssignInt",
    [0x85] = "AssignLong",
    [0x86] = "AssignFloat",
    [0x87] = "AssignString",
    [0x88] = "PrintInt",
    [0x89] = "PrintLong",
    [0x8A] = "PrintFloat",
    [0x8B] = "PrintString",
    [0x8C] = "LPrintInt",
    [0x8D] = "LPrintLong",
    [0x8E] = "LPrintFloat",
    [0x8F] = "LPrintString",
    [0x90] = "PrintSpace",
    [0x91] = "LPrintSpace",
    [0x92] = "PrintCarriageReturn",
    [0x93] = "LPrintCarriageReturn",
    [0x94] = "InputInt",
    [0x95] = "InputLong",
    [0x96] = "InputFloat",
    [0x97] = "InputString",
    [0x98] = "PokeW",
    [0x99] = "PokeL",
    [0x9A] = "PokeD",
    [0x9B] = "PokeStr",
    [0x9C] = "PokeB",
    [0x9D] = "Append",
    [0x9E] = "At",
    [0x9F] = "Back",
    [0xA0] = "Beep",
    [0xA1] = "Close",
    [0xA2] = "Cls",
    [0xA3] = "IllegalOpCode",
    [0xA4] = "Copy",
    [0xA5] = "Create",
    [0xA6] = "Cursor",
    [0xA7] = "Delete",
    [0xA8] = "Erase",
    [0xA9] = "Escape",
    [0xAA] = "First",
    [0xAB] = "Vector",
    [0xAC] = "Last",
    [0xAD] = "LClose",
    [0xAE] = "LoadM",
    [0xAF] = "LOpen",
    [0xB0] = "Next",
    [0xB1] = "OnErr",
    [0xB2] = "Off",
    [0xB3] = "OffFor",
    [0xB4] = "Open",
    [0xB5] = "Pause",
    [0xB6] = "Position",
    [0xB7] = "IoSignal",
    [0xB8] = "Raise",
    [0xB9] = "Randomize",
    [0xBA] = "Rename",
    [0xBB] = "Stop",
    [0xBC] = "Trap",
    [0xBD] = "Update",
    [0xBE] = "Use",
    [0xBF] = "GoTo",
    [0xC0] = "Return",
    [0xC1] = "UnLoadM",
    [0xC2] = "Edit",
    [0xC3] = "Screen2",
    [0xC4] = "OpenR",
    [0xC5] = "gSaveBit",
    [0xC6] = "gClose",
    [0xC7] = "gUse",
    [0xC8] = "gSetWin",
    [0xC9] = "gVisible",
    [0xCA] = "gFont",
    [0xCB] = "gUnloadFont",
    [0xCC] = "gGMode",
    [0xCD] = "gTMode",
    [0xCE] = "gStyle",
    [0xCF] = "gOrder",
    [0xD0] = "IllegalOpCode",
    [0xD1] = "gCls",
    [0xD2] = "gAt",
    [0xD3] = "gMove",
    [0xD4] = "gPrintWord",
    [0xD5] = "gPrintLong",
    [0xD6] = "gPrintDbl",
    [0xD7] = "gPrintStr",
    [0xD8] = "gPrintSpace",
    [0xD9] = "gPrintBoxText",
    [0xDA] = "gLineBy",
    [0xDB] = "gBox",
    [0xDC] = "gCircle",
    [0xDD] = "gEllipse",
    [0xDE] = "gPoly",
    [0xDF] = "gFill",
    [0xE0] = "gPatt",
    [0xE1] = "gCopy",
    [0xE2] = "gScroll",
    [0xE3] = "gUpdate",
    [0xE4] = "GetEvent",
    [0xE5] = "gLineTo",
    [0xE6] = "gPeekLine",
    [0xE7] = "Screen4",
    [0xE8] = "IoWaitStat",
    [0xE9] = "IoYield",
    [0xEA] = "mInit",
    [0xEB] = "mCard",
    [0xEC] = "dInit",
    [0xED] = "dItem",
    [0xEE] = "IllegalOpCode",
    [0xEF] = "IllegalOpCode",
    [0xF0] = "Busy",
    [0xF1] = "Lock",
    [0xF2] = "gInvert",
    [0xF3] = "gXPrint",
    [0xF4] = "gBorder",
    [0xF5] = "gClock",
    [0xF6] = "IllegalOpCode",
    [0xF7] = "IllegalOpCode",
    [0xF8] = "MkDir",
    [0xF9] = "RmDir",
    [0xFA] = "SetPath",
    [0xFB] = "SecsToDate",
    [0xFC] = "gIPrint",
    [0xFD] = "IllegalOpCode",
    [0xFE] = "IllegalOpCode",
    [0xFF] = "NextOpcodeTable",
    [0x100] = "gGrey",
    [0x101] = "DefaultWin",
    [0x102] = "IllegalOpCode",
    [0x103] = "IllegalOpCode",
    [0x104] = "Font",
    [0x105] = "Style",
    [0x106] = "IllegalOpCode",
    [0x107] = "IllegalOpCode",
    [0x108] = "IllegalOpCode",
    [0x109] = "IllegalOpCode",
    [0x10A] = "IllegalOpCode",
    [0x10B] = "IllegalOpCode",
    [0x10C] = "FreeAlloc",
    [0x10D] = "IllegalOpCode",
    [0x10E] = "IllegalOpCode",
    [0x10F] = "gButton",
    [0x110] = "gXBorder",
    [0x111] = "IllegalOpCode",
    [0x112] = "IllegalOpCode",
    [0x113] = "IllegalOpCode",
    [0x114] = "ScreenInfo",
    [0x115] = "IllegalOpCode",
    [0x116] = "IllegalOpCode",
    [0x117] = "IllegalOpCode",
    [0x118] = "CallOpxFunc",
    [0x119] = "Statement32",
    [0x11A] = "Modify",
    [0x11B] = "Insert",
    [0x11C] = "Cancel",
    [0x11D] = "Put",
    [0x11E] = "DeleteTable",
    [0x11F] = "GotoMark",
    [0x120] = "KillMark",
    [0x121] = "ReturnFromEval",
    [0x122] = "GetEvent32",
    [0x123] = "GetEventA32",
    [0x124] = "gColor",
    [0x125] = "SetFlags",
    [0x126] = "SetDoc",
    [0x127] = "DaysToDate",
    [0x128] = "gInfo32",
    [0x129] = "IoWaitStat32",
    [0x12A] = "Compact",
    [0x12B] = "BeginTrans",
    [0x12C] = "CommitTrans",
    [0x12D] = "Rollback",
    [0x12E] = "ClearFlags",
    [0x12F] = "PointerFilter",
    [0x130] = "mCasc",
    [0x131] = "EvalExternalRightSideRef",
    [0x132] = "EvalExternalLeftSideRef",
    [0x133] = "dEditCheckbox", -- In 6.0 this opcode has actually been REDEFINED to gSetPenWidth
    [0x134] = "dEditMulti",
    [0x135] = "gColorInfo",
    [0x136] = "gColorBackground",
    [0x137] = "mCardX",
    [0x138] = "SetHelp",
    [0x139] = "ShowHelp",
    [0x13A] = "SetHelpUid",
    [0x13B] = "gXBorder32",
    [0x13C] = "IllegalOpCode",
    [0x13D] = "IllegalOpCode",
    [0x13E] = "IllegalOpCode",
    [0x13F] = "IllegalOpCode",
    [0x140] = "IllegalOpCode",
    [0x141] = "IllegalOpCode",
    [0x142] = "IllegalOpCode",
    [0x143] = "IllegalOpCode",
    [0x144] = "IllegalOpCode",
    [0x145] = "IllegalOpCode",
    [0x146] = "IllegalOpCode",
    [0x147] = "IllegalOpCode",
    [0x148] = "IllegalOpCode",
    [0x149] = "IllegalOpCode",
    [0x14A] = "IllegalOpCode",
    [0x14B] = "IllegalOpCode",
    [0x14C] = "IllegalOpCode",
    [0x14D] = "IllegalOpCode",
    [0x14E] = "IllegalOpCode",
    [0x14F] = "IllegalOpCode",
    [0x150] = "IllegalOpCode",
    [0x151] = "IllegalOpCode",
    [0x152] = "IllegalOpCode",
    [0x153] = "IllegalOpCode",
    [0x154] = "IllegalOpCode",
    [0x155] = "IllegalOpCode",
    [0x156] = "IllegalOpCode",
    [0x157] = "IllegalOpCode",
    [0x158] = "IllegalOpCode",
    [0x159] = "IllegalOpCode",
    [0x15A] = "IllegalOpCode",
    [0x15B] = "IllegalOpCode",
    [0x15C] = "IllegalOpCode",
    [0x15D] = "IllegalOpCode",
    [0x15E] = "IllegalOpCode",
    [0x15F] = "IllegalOpCode",
    [0x160] = "IllegalOpCode",
    [0x161] = "IllegalOpCode",
    [0x162] = "IllegalOpCode",
    [0x163] = "IllegalOpCode",
    [0x164] = "IllegalOpCode",
    [0x165] = "IllegalOpCode",
    [0x166] = "IllegalOpCode",
    [0x167] = "IllegalOpCode",
    [0x168] = "IllegalOpCode",
    [0x169] = "IllegalOpCode",
    [0x16A] = "IllegalOpCode",
    [0x16B] = "IllegalOpCode",
    [0x16C] = "IllegalOpCode",
    [0x16D] = "IllegalOpCode",
    [0x16E] = "IllegalOpCode",
    [0x16F] = "IllegalOpCode",
    [0x170] = "IllegalOpCode",
    [0x171] = "IllegalOpCode",
    [0x172] = "IllegalOpCode",
    [0x173] = "IllegalOpCode",
    [0x174] = "IllegalOpCode",
    [0x175] = "IllegalOpCode",
    [0x176] = "IllegalOpCode",
    [0x177] = "IllegalOpCode",
    [0x178] = "IllegalOpCode",
    [0x179] = "IllegalOpCode",
    [0x17A] = "IllegalOpCode",
    [0x17B] = "IllegalOpCode",
    [0x17C] = "IllegalOpCode",
    [0x17D] = "IllegalOpCode",
    [0x17E] = "IllegalOpCode",
    [0x17F] = "IllegalOpCode",
    [0x180] = "IllegalOpCode",
    [0x181] = "IllegalOpCode",
    [0x182] = "IllegalOpCode",
    [0x183] = "IllegalOpCode",
    [0x184] = "IllegalOpCode",
    [0x185] = "IllegalOpCode",
    [0x186] = "IllegalOpCode",
    [0x187] = "IllegalOpCode",
    [0x188] = "IllegalOpCode",
    [0x189] = "IllegalOpCode",
    [0x18A] = "IllegalOpCode",
    [0x18B] = "IllegalOpCode",
    [0x18C] = "IllegalOpCode",
    [0x18D] = "IllegalOpCode",
    [0x18E] = "IllegalOpCode",
    [0x18F] = "IllegalOpCode",
    [0x190] = "IllegalOpCode",
    [0x191] = "IllegalOpCode",
    [0x192] = "IllegalOpCode",
    [0x193] = "IllegalOpCode",
    [0x194] = "IllegalOpCode",
    [0x195] = "IllegalOpCode",
    [0x196] = "IllegalOpCode",
    [0x197] = "IllegalOpCode",
    [0x198] = "IllegalOpCode",
    [0x199] = "IllegalOpCode",
    [0x19A] = "IllegalOpCode",
    [0x19B] = "IllegalOpCode",
    [0x19C] = "IllegalOpCode",
    [0x19D] = "IllegalOpCode",
    [0x19E] = "IllegalOpCode",
    [0x19F] = "IllegalOpCode",
    [0x1A0] = "IllegalOpCode",
    [0x1A1] = "IllegalOpCode",
    [0x1A2] = "IllegalOpCode",
    [0x1A3] = "IllegalOpCode",
    [0x1A4] = "IllegalOpCode",
    [0x1A5] = "IllegalOpCode",
    [0x1A6] = "IllegalOpCode",
    [0x1A7] = "IllegalOpCode",
    [0x1A8] = "IllegalOpCode",
    [0x1A9] = "IllegalOpCode",
    [0x1AA] = "IllegalOpCode",
    [0x1AB] = "IllegalOpCode",
    [0x1AC] = "IllegalOpCode",
    [0x1AD] = "IllegalOpCode",
    [0x1AE] = "IllegalOpCode",
    [0x1AF] = "IllegalOpCode",
    [0x1B0] = "IllegalOpCode",
    [0x1B1] = "IllegalOpCode",
    [0x1B2] = "IllegalOpCode",
    [0x1B3] = "IllegalOpCode",
    [0x1B4] = "IllegalOpCode",
    [0x1B5] = "IllegalOpCode",
    [0x1B6] = "IllegalOpCode",
    [0x1B7] = "IllegalOpCode",
    [0x1B8] = "IllegalOpCode",
    [0x1B9] = "IllegalOpCode",
    [0x1BA] = "IllegalOpCode",
    [0x1BB] = "IllegalOpCode",
    [0x1BC] = "IllegalOpCode",
    [0x1BD] = "IllegalOpCode",
    [0x1BE] = "IllegalOpCode",
    [0x1BF] = "IllegalOpCode",
    [0x1C0] = "IllegalOpCode",
    [0x1C1] = "IllegalOpCode",
    [0x1C2] = "IllegalOpCode",
    [0x1C3] = "IllegalOpCode",
    [0x1C4] = "IllegalOpCode",
    [0x1C5] = "IllegalOpCode",
    [0x1C6] = "IllegalOpCode",
    [0x1C7] = "IllegalOpCode",
    [0x1C8] = "IllegalOpCode",
    [0x1C9] = "IllegalOpCode",
    [0x1CA] = "IllegalOpCode",
    [0x1CB] = "IllegalOpCode",
    [0x1CC] = "IllegalOpCode",
    [0x1CD] = "IllegalOpCode",
    [0x1CE] = "IllegalOpCode",
    [0x1CF] = "IllegalOpCode",
    [0x1D0] = "IllegalOpCode",
    [0x1D1] = "IllegalOpCode",
    [0x1D2] = "IllegalOpCode",
    [0x1D3] = "IllegalOpCode",
    [0x1D4] = "IllegalOpCode",
    [0x1D5] = "IllegalOpCode",
    [0x1D6] = "IllegalOpCode",
    [0x1D7] = "IllegalOpCode",
    [0x1D8] = "IllegalOpCode",
    [0x1D9] = "IllegalOpCode",
    [0x1DA] = "IllegalOpCode",
    [0x1DB] = "IllegalOpCode",
    [0x1DC] = "IllegalOpCode",
    [0x1DD] = "IllegalOpCode",
    [0x1DE] = "IllegalOpCode",
    [0x1DF] = "IllegalOpCode",
    [0x1E0] = "IllegalOpCode",
    [0x1E1] = "IllegalOpCode",
    [0x1E2] = "IllegalOpCode",
    [0x1E3] = "IllegalOpCode",
    [0x1E4] = "IllegalOpCode",
    [0x1E5] = "IllegalOpCode",
    [0x1E6] = "IllegalOpCode",
    [0x1E7] = "IllegalOpCode",
    [0x1E8] = "IllegalOpCode",
    [0x1E9] = "IllegalOpCode",
    [0x1EA] = "IllegalOpCode",
    [0x1EB] = "IllegalOpCode",
    [0x1EC] = "IllegalOpCode",
    [0x1ED] = "IllegalOpCode",
    [0x1EE] = "IllegalOpCode",
    [0x1EF] = "IllegalOpCode",
    [0x1F0] = "IllegalOpCode",
    [0x1F1] = "IllegalOpCode",
    [0x1F2] = "IllegalOpCode",
    [0x1F3] = "IllegalOpCode",
    [0x1F4] = "IllegalOpCode",
    [0x1F5] = "IllegalOpCode",
    [0x1F6] = "IllegalOpCode",
    [0x1F7] = "IllegalOpCode",
    [0x1F8] = "IllegalOpCode",
    [0x1F9] = "IllegalOpCode",
    [0x1FA] = "IllegalOpCode",
    [0x1FB] = "IllegalOpCode",
    [0x1FC] = "IllegalOpCode",
    [0x1FD] = "IllegalOpCode",
    [0x1FE] = "IllegalOpCode",
    [0x1FF] = "IllegalOpCode",
}

function IllegalOpCode(stack)
    error(KOplErrIllegal)
end

local function index_dump(runtime)
    local index = runtime:IP16()
    return fmt("0x%04X", index)
end

local function IPs8_dump(runtime)
    local val = runtime:IPs8()
    return fmt("%d (0x%s)", val, fmt("%02X", val):sub(-2))
end

IP8_dump = fns.IP8_dump

local function IP16_dump(runtime)
    local index = runtime:IP16()
    return fmt("0x%04X", index)
end

local function IPs16_dump(runtime)
    local val = runtime:IPs16()
    return fmt("%d (0x%s)", val, fmt("%04X", val):sub(-4))
end

local function IPs32_dump(runtime)
    local val = runtime:IPs32()
    return fmt("%d (0x%s)", val, fmt("%08X", val):sub(-8))
end

local function numParams_dump(runtime)
    local numParams = runtime:IP8()
    return fmt("numParams=%d", numParams)
end

local function logName_dump(runtime)
    local logName = runtime:IP8()
    return fmt("%c", string.byte("A") + logName)
end

--[[
xxRightSide<TYPE> means basically push the value onto the stack, the name I
assume coming from the fact that this is what you'd call when the value
appears on the right hand side of an assignment operation.

xxLeftSide<TYPE> means push a reference of some sort to the variable, such
that a subsequent Assign<TYPE> call can assign to it.

We aren't concerned with database fields or type checking so we simplify the
stack usage considerably from what COplRuntime does.
]]

local function leftSide(stack, runtime, type, indirect)
    local index = runtime:IP16()
    local var = runtime:getVar(index, type, indirect)
    if isArrayType(type) then
        local pos = stack:pop()
        var = var()[pos]
    end
    stack:push(var)
end

local function rightSide(stack, runtime, type, indirect)
    leftSide(stack, runtime, type, indirect)
    stack:push(stack:pop()())
end

function SimpleDirectRightSideInt(stack, runtime) -- 0x00
    return rightSide(stack, runtime, Word, false)
end
SimpleDirectRightSideInt_dump = index_dump

function SimpleDirectRightSideLong(stack, runtime) -- 0x01
    return rightSide(stack, runtime, Long, false)
end
SimpleDirectRightSideLong_dump = index_dump

function SimpleDirectRightSideFloat(stack, runtime) -- 0x02
    return rightSide(stack, runtime, Real, false)
end
SimpleDirectRightSideFloat_dump = index_dump

function SimpleDirectRightSideString(stack, runtime) -- 0x03
    return rightSide(stack, runtime, String, false)
end
SimpleDirectRightSideString_dump = index_dump

function SimpleDirectLeftSideInt(stack, runtime) -- 0x04
    return leftSide(stack, runtime, Word, false)
end
SimpleDirectLeftSideInt_dump = index_dump

function SimpleDirectLeftSideLong(stack, runtime) -- 0x05
    return leftSide(stack, runtime, Long, false)
end
SimpleDirectLeftSideLong_dump = index_dump

function SimpleDirectLeftSideFloat(stack, runtime) -- 0x06
    return leftSide(stack, runtime, Real, false)
end
SimpleDirectLeftSideFloat_dump = index_dump

function SimpleDirectLeftSideString(stack, runtime) -- 0x07
    return leftSide(stack, runtime, String, false)
end
SimpleDirectLeftSideString_dump = index_dump

function SimpleInDirectRightSideInt(stack, runtime) -- 0x08
    return rightSide(stack, runtime, Word, true)
end
SimpleInDirectRightSideInt_dump = index_dump

function SimpleInDirectRightSideLong(stack, runtime) -- 0x09
    return rightSide(stack, runtime, Long, true)
end
SimpleInDirectRightSideLong_dump = index_dump

function SimpleInDirectRightSideFloat(stack, runtime) -- 0x0A
    return rightSide(stack, runtime, Real, true)
end
SimpleInDirectRightSideFloat_dump = index_dump

function SimpleInDirectRightSideString(stack, runtime) -- 0x0B
    return rightSide(stack, runtime, String, true)
end
SimpleInDirectRightSideString_dump = index_dump

function SimpleInDirectLeftSideInt(stack, runtime) -- 0x0C
    return leftSide(stack, runtime, Word, true)
end
SimpleInDirectLeftSideInt_dump = index_dump

function SimpleInDirectLeftSideLong(stack, runtime) -- 0x0D
    return leftSide(stack, runtime, Long, true)
end
SimpleInDirectLeftSideLong_dump = index_dump

function SimpleInDirectLeftSideFloat(stack, runtime) -- 0x0E
    return leftSide(stack, runtime, Real, true)
end
SimpleInDirectLeftSideFloat_dump = index_dump

function SimpleInDirectLeftSideString(stack, runtime) -- 0x0F
    return leftSide(stack, runtime, String, true)
end
SimpleInDirectLeftSideString_dump = index_dump

function ArrayDirectRightSideInt(stack, runtime) -- 0x10
    return rightSide(stack, runtime, WordArray, false)
end
ArrayDirectRightSideInt_dump = index_dump

function ArrayDirectRightSideLong(stack, runtime) -- 0x11
    return rightSide(stack, runtime, LongArray, false)
end
ArrayDirectRightSideLong_dump = index_dump

function ArrayDirectRightSideFloat(stack, runtime) -- 0x12
    return rightSide(stack, runtime, RealArray, false)
end
ArrayDirectRightSideFloat_dump = index_dump

function ArrayDirectRightSideString(stack, runtime) -- 0x13
    return rightSide(stack, runtime, StringArray, false)
end
ArrayDirectRightSideString_dump = index_dump

function ArrayDirectLeftSideInt(stack, runtime) -- 0x14
    return leftSide(stack, runtime, WordArray, false)
end
ArrayDirectLeftSideInt_dump = index_dump

function ArrayDirectLeftSideLong(stack, runtime) -- 0x15
    return leftSide(stack, runtime, LongArray, false)
end
ArrayDirectLeftSideLong_dump = index_dump

function ArrayDirectLeftSideFloat(stack, runtime) -- 0x16
    return leftSide(stack, runtime, RealArray, false)
end
ArrayDirectLeftSideFloat_dump = index_dump

function ArrayDirectLeftSideString(stack, runtime) -- 0x17
    return leftSide(stack, runtime, StringArray, false)
end
ArrayDirectLeftSideString_dump = index_dump

function ArrayInDirectRightSideInt(stack, runtime) -- 0x18
    return rightSide(stack, runtime, WordArray, true)
end
ArrayInDirectRightSideInt_dump = index_dump

function ArrayInDirectRightSideLong(stack, runtime) -- 0x19
    return rightSide(stack, runtime, LongArray, true)
end
ArrayInDirectRightSideLong_dump = index_dump

function ArrayInDirectRightSideFloat(stack, runtime) -- 0x1A
    return rightSide(stack, runtime, RealArray, true)
end
ArrayInDirectRightSideFloat_dump = index_dump

function ArrayInDirectRightSideString(stack, runtime) -- 0x1B
    return rightSide(stack, runtime, StringArray, true)
end
ArrayInDirectRightSideString_dump = index_dump

function ArrayInDirectLeftSideInt(stack, runtime) -- 0x1C
    return leftSide(stack, runtime, WordArray, true)
end
ArrayInDirectLeftSideInt_dump = index_dump

function ArrayInDirectLeftSideLong(stack, runtime) -- 0x1D
    return leftSide(stack, runtime, LongArray, true)
end
ArrayInDirectLeftSideLong_dump = index_dump

function ArrayInDirectLeftSideFloat(stack, runtime) -- 0x1E
    return leftSide(stack, runtime, RealArray, true)
end
ArrayInDirectLeftSideFloat_dump = index_dump

function ArrayInDirectLeftSideString(stack, runtime) -- 0x1F
    return leftSide(stack, runtime, StringArray, true)
end
ArrayInDirectLeftSideString_dump = index_dump

local function fieldLeftSide(stack, runtime)
    local logName = runtime:IP8()
    local fieldName = stack:pop()
    local db = runtime:getDb(logName)
    local var = assert(db.currentVars[fieldName], KOplErrNoFld)
    stack:push(var)
end

local function fieldRightSide(stack, runtime)
    fieldLeftSide(stack, runtime)
    stack:push(stack:pop()())
end

FieldRightSideInt = fieldRightSide -- 0x20
FieldRightSideInt_dump = logName_dump

FieldRightSideLong = fieldRightSide -- 0x21
FieldRightSideLong_dump = logName_dump

FieldRightSideFloat = fieldRightSide -- 0x22
FieldRightSideFloat_dump = logName_dump

FieldRightSideString = fieldRightSide -- 0x23
FieldRightSideString_dump = logName_dump

FieldLeftSideInt = fieldLeftSide -- 0x24
FieldLeftSideInt_dump = logName_dump

FieldLeftSideLong = fieldLeftSide -- 0x25
FieldLeftSideLong_dump = logName_dump

FieldLeftSideFloat = fieldLeftSide -- 0x26
FieldLeftSideFloat_dump = logName_dump

FieldLeftSideString = fieldLeftSide -- 0x27
FieldLeftSideString_dump = logName_dump

function ConstantInt(stack, runtime) -- 0x28
    local val = runtime:IPs16()
    stack:push(val)
end
ConstantInt_dump = IPs16_dump

function ConstantLong(stack, runtime) -- 0x29
    local val = runtime:IPs32()
    stack:push(val)
end

ConstantLong_dump = IPs32_dump

function ConstantFloat(stack, runtime) -- 0x2A
    local val = runtime:IPReal()
    stack:push(val)
end

function ConstantFloat_dump(runtime)
    local val = runtime:IPReal()
    return fmt("%g", val)
end

function ConstantString(stack, runtime) -- 0x2B
    local str = runtime:ipString()
    stack:push(str)
end

function ConstantString_dump(runtime)
    local str = runtime:ipString()
    return fmt('"%s"', hexEscape(str))
end

function CompareLessThanUntyped(stack)
    local right = stack:pop()
    local left = stack:pop()
    stack:push(left < right)
end

CompareLessThanInt = CompareLessThanUntyped -- 0x30
CompareLessThanLong = CompareLessThanUntyped -- 0x31
CompareLessThanFloat = CompareLessThanUntyped -- 0x32
CompareLessThanString = CompareLessThanUntyped -- 0x33

function CompareLessOrEqualUntyped(stack)
    local right = stack:pop()
    local left = stack:pop()
    stack:push(left <= right)
end

CompareLessOrEqualInt = CompareLessOrEqualUntyped -- 0x34
CompareLessOrEqualLong = CompareLessOrEqualUntyped -- 0x35
CompareLessOrEqualFloat = CompareLessOrEqualUntyped -- 0x36
CompareLessOrEqualString = CompareLessOrEqualUntyped -- 0x37

function CompareGreaterThanUntyped(stack)
    local right = stack:pop()
    local left = stack:pop()
    stack:push(left > right)
end

CompareGreaterThanInt = CompareGreaterThanUntyped -- 0x38
CompareGreaterThanLong = CompareGreaterThanUntyped -- 0x39
CompareGreaterThanFloat = CompareGreaterThanUntyped -- 0x3A
CompareGreaterThanString = CompareGreaterThanUntyped -- 0x3B

function CompareGreaterOrEqualUntyped(stack)
    local right = stack:pop()
    local left = stack:pop()
    stack:push(left >= right)
end

CompareGreaterOrEqualInt = CompareGreaterOrEqualUntyped -- 0x3C
CompareGreaterOrEqualLong = CompareGreaterOrEqualUntyped -- 0x3D
CompareGreaterOrEqualFloat = CompareGreaterOrEqualUntyped -- 0x3E
CompareGreaterOrEqualString = CompareGreaterOrEqualUntyped -- 0x3F

function CompareEqualUntyped(stack)
    local right = stack:pop()
    local left = stack:pop()
    stack:push(left == right)
end

CompareEqualInt = CompareEqualUntyped -- 0x40
CompareEqualLong = CompareEqualUntyped -- 0x41
CompareEqualFloat = CompareEqualUntyped -- 0x42
CompareEqualString = CompareEqualUntyped -- 0x43

function CompareNotEqualUntyped(stack)
    local right = stack:pop()
    local left = stack:pop()
    stack:push(left ~= right)
end

CompareNotEqualInt = CompareNotEqualUntyped -- 0x44
CompareNotEqualLong = CompareNotEqualUntyped -- 0x45
CompareNotEqualFloat = CompareNotEqualUntyped -- 0x46
CompareNotEqualString = CompareNotEqualUntyped -- 0x47

function AddUntyped(stack)
    local right = stack:pop()
    local left = stack:pop()
    stack:push(left + right)
end

AddInt = AddUntyped -- 0x48
AddLong = AddUntyped -- 0x49
AddFloat = AddUntyped -- 0x4A

function AddString(stack) -- 0x4B
    local right = stack:pop()
    local left = stack:pop()
    stack:push(left .. right)
end

function SubtractUntyped(stack)
    local right = stack:pop()
    local left = stack:pop()
    stack:push(left - right)
end

SubtractInt = SubtractUntyped -- 0x4C
SubtractLong = SubtractUntyped -- 0x4D
SubtractFloat = SubtractUntyped -- 0x4E

function StackByteAsWord(stack, runtime) -- 0x4F
    local val = runtime:IPs8()
    stack:push(val)
end

StackByteAsWord_dump = IPs8_dump

function MultiplyUntyped(stack)
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push(left * right)
    end
end

MultiplyInt = MultiplyUntyped -- 0x50
MultiplyLong = MultiplyUntyped -- 0x51
MultiplyFloat = MultiplyUntyped -- 0x52

local function decodeRunProc(runtime)
    local procIdx = runtime:IP16()
    local name, numParams
    local proc = runtime:currentProc()
    for _, subproc in ipairs(proc.subprocs) do
        if subproc.offset == procIdx then
            name = subproc.name
            numParams = subproc.numParams
            break
        end
    end
    return procIdx, name, numParams
end

function RunProcedure(stack, runtime) -- 0x53
    local procIdx, name, numParams = decodeRunProc(runtime)
    assert(name, "Subproc not found for index "..tostring(procIdx))
    local proc = runtime:findProc(name)
    runtime:pushNewFrame(stack, proc, numParams)
end

function RunProcedure_dump(runtime)
    local procIdx, name, numParams = decodeRunProc(runtime)
    return fmt('0x%04X (name="%s" nargs=%s)', procIdx, name or "?", tostring(numParams or "?"))
end

function DivideInt(stack) -- 0x54
    local denominator = stack:pop()
    if denominator == 0 then
        error(KOplErrDivideByZero)
    end
    stack:push(stack:pop() // denominator)
end

DivideLong = DivideInt -- 0x55

function DivideFloat(stack) -- 0x56
    local denominator = stack:pop()
    if denominator == 0 then
        error(KOplErrDivideByZero)
    end
    stack:push(stack:pop() / denominator)
end

function CallFunction(stack, runtime) -- 0x57
    local fnIdx = runtime:IP8()
    local fnName = fns.codes[fnIdx]
    local fn = assert(fns[fnName], "Function "..fnName.. " not implemented!")
    fn(stack, runtime)
end

function CallFunction_dump(runtime)
    local fnIdx = runtime:IP8()
    local fnName = fns.codes[fnIdx]
    local dumpFn = fns[fnName.."_dump"]
    return fmt("0x%02X (%s)%s", fnIdx, fnName or "?", dumpFn and dumpFn(runtime) or "")
end

function PowerOfUntyped(stack)
    local powerOf = stack:pop()
    local number = stack:pop()
    if powerOf <= 0 and number == 0 then
        -- No infs here thank you very much
        error(KOplErrInvalidArgs)
    end
    stack:push(number ^ powerOf)
end

PowerOfInt = PowerOfUntyped -- 0x58
PowerOfLong = PowerOfUntyped -- 0x59
PowerOfFloat = PowerOfUntyped -- 0x5A

function BranchIfFalse(stack, runtime) -- 0x5B
    local ip = runtime:getIp() - 1 -- Because ip points to just after us
    local relJmp = runtime:IPs16()
    if stack:pop() == 0 then
        runtime:setIp(ip + relJmp)
    end
end

function BranchIfFalse_dump(runtime)
    local ip = runtime:getIp() - 1 -- Because ip points to just after us
    local relJmp = runtime:IPs16()
    return fmt("%d (->0x%08X)", relJmp, ip + relJmp)
end

function AndInt(stack) -- 0x5C
    local right = stack:pop()
    local left = stack:pop()
    stack:push(left & right)
end

AndLong = AndInt -- 0x5D

function AndFloat(stack) -- 0x5E
    local right = stack:pop()
    local left = stack:pop()
    -- Weird one, this
    stack:push((left ~= 0) and (right ~= 0))
end

StackByteAsLong = StackByteAsWord -- 0x5F
StackByteAsLong_dump = IPs8_dump

function OrInt(stack) -- 0x60
    local right = stack:pop()
    local left = stack:pop()
    stack:push(left | right)
end

OrLong = OrInt -- 0x61

function OrFloat(stack) -- 0x62
    local right = stack:pop()
    local left = stack:pop()
    stack:push((left ~= 0) or (right ~= 0))
end

function StackWordAsLong(stack, runtime) -- 0x63
    local val = runtime:IPs16()
    stack:push(val)
end

StackWordAsLong_dump = IPs16_dump

function NotInt(stack) -- 0x64
    stack:push(~stack:pop())
end

NotLong = NotInt -- 0x65

function NotFloat(stack) -- 0x66
    stack:push(stack:pop() ~= 0)
end

function OplDebug(pos)
    printf("Statement number %d\n", pos)
end

function Statement16(stack, runtime) -- 0x67
    local pos = runtime:IP16()
    OplDebug(pos)
end

Statement16_dump = IP16_dump

function UnaryMinusUntyped(stack)
    stack:push(-stack:pop())
end

UnaryMinusInt = UnaryMinusUntyped -- 0x68
UnaryMinusLong = UnaryMinusUntyped -- 0x69
UnaryMinusFloat = UnaryMinusUntyped -- 0x6A

function CallProcByStringExpr(stack, runtime) -- 0x6B
    local numParams = runtime:IP8()
    local type = runtime:IP8()
    local procName = stack:remove(stack:getSize() - numParams*2)
    local proc = runtime:findProc(procName:upper())
    runtime:pushNewFrame(stack, proc, numParams)
end

function CallProcByStringExpr_dump(runtime)
    local numParams = runtime:IP8()
    local type = runtime:IP8()
    return fmt("nargs=%d type=%s", numParams, type)
end

function PercentLessThan(stack, runtime) -- 0x6C
    error("Unimplemented opcode PercentLessThan!")
end

function PercentGreaterThan(stack, runtime) -- 0x6D
    error("Unimplemented opcode PercentGreaterThan!")
end

function PercentAdd(stack, runtime) -- 0x6E
    error("Unimplemented opcode PercentAdd!")
end

function PercentSubtract(stack, runtime) -- 0x6F
    error("Unimplemented opcode PercentSubtract!")
end

function PercentMultiply(stack, runtime) -- 0x70
    error("Unimplemented opcode PercentMultiply!")
end

function PercentDivide(stack, runtime) -- 0x71
    error("Unimplemented opcode PercentDivide!")
end

function ZeroReturn(stack, runtime)
    runtime:returnFromFrame(stack, 0)
end

ZeroReturnInt = ZeroReturn -- 0x74
ZeroReturnLong = ZeroReturn -- 0x75
ZeroReturnFloat = ZeroReturn -- 0x76

function NullReturnString(stack, runtime) -- 0x77
    runtime:returnFromFrame(stack, "")
end

local function NoOp()
end

LongToInt = NoOp -- 0x78

function FloatToInt(stack, runtime) -- 0x79
    return fns.IntLong(stack, runtime) -- no idea why these are duplicated
end

FloatToLong = FloatToInt -- 0x7A

IntToLong = NoOp -- 0x7B
IntToFloat = NoOp -- 0x7C
LongToFloat = NoOp -- 0x7D
LongToUInt = NoOp -- 0x7E
FloatToUInt = NoOp -- 0x7F

function DropUntyped(stack)
    stack:pop()
end

DropInt = DropUntyped -- 0x80
DropLong = DropUntyped -- 0x81
DropFloat = DropUntyped -- 0x82
DropString = DropUntyped -- 0x83

function AssignUntyped(stack, runtime)
    local val = stack:pop()
    local var = stack:pop()
    var(val)
end

AssignInt = AssignUntyped -- 0x84
AssignLong = AssignUntyped -- 0x85
AssignFloat = AssignUntyped -- 0x86
AssignString = AssignUntyped -- 0x87

function PrintUntyped(stack, runtime)
    if stack then
        runtime:iohandler().print(stack:pop())
    end
end

PrintInt = PrintUntyped -- 0x88
PrintLong = PrintUntyped -- 0x89
PrintFloat = PrintUntyped -- 0x8A
PrintString = PrintUntyped -- 0x8B

function LPrintInt(stack, runtime) -- 0x8C
    error("Unimplemented opcode LPrintInt!")
end

function LPrintLong(stack, runtime) -- 0x8D
    error("Unimplemented opcode LPrintLong!")
end

function LPrintFloat(stack, runtime) -- 0x8E
    error("Unimplemented opcode LPrintFloat!")
end

function LPrintString(stack, runtime) -- 0x8F
    error("Unimplemented opcode LPrintString!")
end

function PrintSpace(stack, runtime) -- 0x90
    runtime:iohandler().print(" ")
end

function LPrintSpace(stack, runtime) -- 0x91
    error("Unimplemented opcode LPrintSpace!")
end

function PrintCarriageReturn(stack, runtime) -- 0x92
    runtime:iohandler().print("\n")
end

function LPrintCarriageReturn(stack, runtime) -- 0x93
    error("Unimplemented opcode LPrintCarriageReturn!")
end

function InputInt(stack, runtime) -- 0x94
    local var = stack:pop()
    local trapped = runtime:getTrap()
    local result
    while result == nil do
        local line = runtime:iohandler().readLine(trapped)
        result = tonumber(line)
        if result == nil then
            if trapped then
                -- We can error and the trap check in runtime will deal with it
                error(KOplErrGenFail)
            else
                -- iohandler is responsible for outputting a linefeed after reading the line
                runtime:iohandler().print("?")
                -- And go round again
            end
        end
    end
    var(result)
    runtime:setTrap(false)
end

InputLong = InputInt -- 0x95
InputFloat = InputInt -- 0x96

function InputString(stack, runtime) -- 0x97
    local var = stack:pop()
    local trapped = runtime:getTrap()
    local line = runtime:iohandler().readLine(trapped)
    var(line)
    runtime:setTrap(false)
end

function PokeW(stack, runtime) -- 0x98
    error("Unimplemented opcode PokeW!")
end

function PokeL(stack, runtime) -- 0x99
    error("Unimplemented opcode PokeL!")
end

function PokeD(stack, runtime) -- 0x9A
    error("Unimplemented opcode PokeD!")
end

function PokeStr(stack, runtime) -- 0x9B
    error("Unimplemented opcode PokeStr!")
end

function PokeB(stack, runtime) -- 0x9C
    error("Unimplemented opcode PokeB!")
end

function Append(stack, runtime) -- 0x9D
    local db = runtime:getDb()
    db:appendRecord()
    runtime:setTrap(false)
end

function At(stack, runtime) -- 0x9E
    error("Unimplemented opcode At!")
end

function Back(stack, runtime) -- 0x9F
    local db = runtime:getDb()
    db:setPos(db:getPos() - 1)
end

function Beep(stack, runtime) -- 0xA0
    local pitch = stack:pop()
    local freq = 512 / (pitch + 1) -- in Khz
    local duration = stack:pop() * 1/32 -- in seconds
    runtime:iohandler().beep(freq, duration)
end

function Close(stack, runtime) -- 0xA1
    runtime:closeDb()
    runtime:setTrap(false)
end

function Cls(stack, runtime) -- 0xA2
    error("Unimplemented opcode Cls!")
end

function Copy(stack, runtime) -- 0xA4
    error("Unimplemented opcode Copy!")
end

local function parseOpenOrCreate(runtime)
    local logName = runtime:IP8()
    local fields = {}
    while true do
        local type = runtime:IP8()
        if type == 0xFF then
            break
        end
        local field = runtime:ipString()
        table.insert(fields, { name = field, type = type })
    end
    return logName, fields
end

function Create(stack, runtime) -- 0xA5
    local logName, fields = parseOpenOrCreate(runtime)
    local tableSpec = stack:pop()
    runtime:openDb(logName, tableSpec, fields, "Create")
    runtime:setTrap(false)
end

function Create_dump(runtime)
    local logName, fields = parseOpenOrCreate(runtime)
    local fieldNames = {}
    for i, field in ipairs(fields) do fieldNames[i] = field.name end
    return fmt("logName=%d fields=%s", logName, table.concat(fieldNames, ", "))
end

function Cursor(stack, runtime) -- 0xA6
    error("Unimplemented opcode Cursor!")
end

function Delete(stack, runtime) -- 0xA7
    local filename = stack:pop()
    assert(#filename > 0, KOplErrName)
    local err = runtime:iohandler().fsop("delete", filename)
    if err ~= 0 then
        error(err)
    end
    runtime:setTrap(false)
end

function Erase(stack, runtime) -- 0xA8
    local db = runtime:getDb()
    db:deleteRecord()
    runtime:setTrap(false)
end

function Escape(stack, runtime) -- 0xA9
    local state = runtime:IP8()
    -- We don't care
end

function Escape_dump(runtime)
    return fmt("state=%d", runtime:IP8())
end

function First(stack, runtime) -- 0xAA
    local db = runtime:getDb()
    db:setPos(1)
end

function Vector(stack, runtime) -- 0xAB
    local ip = runtime:getIp()
    local maxIndex = runtime:IP16()
    local index = stack:pop()
    if index == 0 or index > maxIndex then
        runtime:setIp(ip + 2 + maxIndex * 2)
    else
        runtime:setIp(ip + index * 2)
        local relJmp = runtime:IPs16()
        runtime:setIp(ip - 1 + relJmp)
    end
end

function Vector_dump(runtime)
    local ip = runtime:getIp() - 1
    local maxIndex = runtime:IP16()
    local strings = {}
    for i = 1, maxIndex do
        local relJmp = runtime:IPs16()
        strings[i] = fmt("%08X     %d (->0x%08X)", runtime:getIp() - 2, relJmp, ip + relJmp)
    end
    return fmt("maxIndex=%d\n%s", maxIndex, table.concat(strings, "\n"))
end

function Last(stack, runtime) -- 0xAC
    local db = runtime:getDb()
    db:setPos(db:getCount())
end

function LClose(stack, runtime) -- 0xAD
    error("Unimplemented opcode LClose!")
end

function LoadM(stack, runtime) -- 0xAE
    runtime:loadModule(stack:pop())
    runtime:setTrap(false)
end

function LOpen(stack, runtime) -- 0xAF
    error("Unimplemented opcode LOpen!")
end

function Next(stack, runtime) -- 0xB0
    local db = runtime:getDb()
    db:setPos(db:getPos() + 1)
end

local function decodeOnErr(runtime)
    local offset = runtime:IP16()
    local newIp
    if offset ~= 0 then
        newIp = runtime:getIp() + offset - 3
    end
    return newIp, offset
end

function OnErr(stack, runtime) -- 0xB1
    runtime:setFrameErrIp(decodeOnErr(runtime))
end

function OnErr_dump(runtime)
    local newIp, offset = decodeOnErr(runtime)
    return newIp and fmt("%d (->0x%08X)", offset, newIp) or "OFF"
end

function Off(stack, runtime) -- 0xB2
    error("Unimplemented opcode Off!")
end

function OffFor(stack, runtime) -- 0xB3
    error("Unimplemented opcode OffFor!")
end

function Open(stack, runtime) -- 0xB4
    local logName, fields = parseOpenOrCreate(runtime)
    local tableSpec = stack:pop()
    runtime:openDb(logName, tableSpec, fields, "Open")
    runtime:setTrap(false)
end

Open_dump = Create_dump

function Pause(stack, runtime) -- 0xB5
    error("Unimplemented opcode Pause!")
end

function Position(stack, runtime) -- 0xB6
    local pos = stack:pop()
    local db = runtime:getDb()
    db:setPos(pos)
    runtime:setTrap(false)
end

function IoSignal(stack, runtime) -- 0xB7
    runtime:requestSignal()
end

function Raise(stack, runtime) -- 0xB8
    error(stack:pop())
end

function Randomize(stack, runtime) -- 0xB9
    math.randomseed(stack:pop())
end

function Rename(stack, runtime) -- 0xBA
    error("Unimplemented opcode Rename!")
end

function Stop(stack, runtime) -- 0xBB
    -- OPL uses User::Leave(0) for this (and for returning from the main fn) but
    -- I can't bring myself to error with a zero code so KStopErr is a made-up
    -- value that's somthing more obvious
    error(KStopErr)
end

function Trap(stack, runtime) -- 0xBC
    runtime:setTrap(true)
end

function Update(stack, runtime) -- 0xBD
    local db = runtime:getDb()
    db:updateRecord()
    runtime:setTrap(false)
end

function Use(stack, runtime) -- 0xBE
    runtime:useDb(runtime:IP8())
    runtime:setTrap(false)
end

Use_dump = logName_dump

function GoTo(stack, runtime) -- 0xBF
    local ip = runtime:getIp() - 1 -- Because ip points to just after us
    local relJmp = runtime:IPs16()
    runtime:setIp(ip + relJmp)
end

function GoTo_dump(runtime)
    local ip = runtime:getIp() - 1 -- Because ip points to just after us
    local relJmp = runtime:IPs16()
    return fmt("%d (->0x%08X)", relJmp, ip + relJmp)
end

function Return(stack, runtime) -- 0xC0
    local val = stack:pop()
    runtime:returnFromFrame(stack, val)
end

function UnLoadM(stack, runtime) -- 0xC1
    local module = stack:pop()
    runtime:unloadModule(module)
    runtime:setTrap(false)
end

function Edit(stack, runtime) -- 0xC2
    error("Unimplemented opcode Edit!")
end

function Screen2(stack, runtime) -- 0xC3
    error("Unimplemented opcode Screen2!")
end

function OpenR(stack, runtime) -- 0xC4
    local logName, fields = parseOpenOrCreate(runtime)
    local tableSpec = stack:pop()
    runtime:openDb(logName, tableSpec, fields, "OpenR")
    runtime:setTrap(false)
end

OpenR_dump = Open_dump

function gSaveBit(stack, runtime) -- 0xC5
    error("Unimplemented opcode gSaveBit!")
end

function gClose(stack, runtime) -- 0xC6
    local id = stack:pop()
    local graphics = runtime:getGraphics()
    assert(id ~= 1, KOplErrInvalidArgs) -- Cannot close the console
    runtime:iohandler().graphicsop("close", id)
    if id == graphics.current.id then
        graphics.current = graphics[1]
    end
    runtime:setTrap(false)
end

function gUse(stack, runtime) -- 0xC7
    local graphics = runtime:getGraphics()
    local drawable = graphics[stack:pop()]
    assert(drawable, KOplErrDrawNotOpen)
    graphics.current = drawable
    runtime:setTrap(false)
end

function gSetWin(stack, runtime) -- 0xC8
    error("Unimplemented opcode gSetWin!")
end

function gVisible(stack, runtime) -- 0xC9
    local graphics = runtime:getGraphics()
    assert(graphics.current.isWindow, KOplErrInvalidWindow)
    local show = runtime:IP8() == 1
    runtime:iohandler().graphicsop("show", graphics.current.id, show)
end

gVisible_dump = IP8_dump

function gFont(stack, runtime) -- 0xCA
    local uid = stack:pop()
    printf("TODO gFont 0x%08X\n", uid)
    runtime:setTrap(false)
end

function gUnloadFont(stack, runtime) -- 0xCB
    error("Unimplemented opcode gUnloadFont!")
end

function gGMode(stack, runtime) -- 0xCC
    getGraphics().current.mode = stack:pop()
end

function gTMode(stack, runtime) -- 0xCD
    error("Unimplemented opcode gTMode!")
end

function gStyle(stack, runtime) -- 0xCE
    local style = stack:pop()
    printf("TODO gStyle %d", style)
end

function gOrder(stack, runtime) -- 0xCF
    local pos = stack:pop()
    local id = stack:pop()

    local graphics = runtime:getGraphics()
    assert(graphics[id] and graphics[id].isWindow, KOplErrInvalidWindow)

    runtime:iohandler().graphicsop("order", id, pos)
end

function gCls(stack, runtime) -- 0xD1
    local graphics = runtime:getGraphics()
    local context = graphics.current
    context.pos = { x = 0, y = 0 }
    runtime:drawCmd("cls")
end

function gAt(stack, runtime) -- 0xD2
    runtime:getGraphics().current.pos = stack:popPoint()
end

function gMove(stack, runtime) -- 0xD3
    error("Unimplemented opcode gMove!")
end

function gPrintWord(stack, runtime) -- 0xD4
    error("Unimplemented opcode gPrintWord!")
end

function gPrintLong(stack, runtime) -- 0xD5
    error("Unimplemented opcode gPrintLong!")
end

function gPrintDbl(stack, runtime) -- 0xD6
    error("Unimplemented opcode gPrintDbl!")
end

function gPrintStr(stack, runtime) -- 0xD7
    error("Unimplemented opcode gPrintStr!")
end

function gPrintSpace(stack, runtime) -- 0xD8
    error("Unimplemented opcode gPrintSpace!")
end

function gPrintBoxText(stack, runtime) -- 0xD9
    local numParams = runtime:IP8()
    local margin = 0
    local bottom = 0
    local top = 0
    local align = 2 -- left
    if numParams > 4 then
        margin = stack:pop()
    end
    if numParams > 3 then
        bottom = stack:pop()
    end
    if numParams > 2 then
        top = stack:pop()
    end
    if numParams > 1 then
        align = stack:pop()
    end
    local width = stack:pop()
    local text = stack:pop()
    printf("TODO gPrintBoxText %s\n", text)
end

gPrintBoxText_dmp = numParams_dump

function gLineBy(stack, runtime) -- 0xDA
    local graphics = runtime:getGraphics()
    local context = graphics.current
    local endPoint = stack:popPoint()
    -- relative pos; make abs
    endPoint.x = context.pos.x + endPoint.x
    endPoint.y = context.pos.y + endPoint.y
    runtime:drawCmd("line", { x2 = endPoint.x, y2 = endPoint.y })
    context.pos = endPoint
end

function gBox(stack, runtime) -- 0xDB
    local height = stack:pop()
    local width = stack:pop()
    runtime:drawCmd("box", { width = width, height = height })
end

function gCircle(stack, runtime) -- 0xDC
    local hasFill = runtime:IP8()
    local graphics = runtime:getGraphics()
    local context = graphics.current
    local fill = 0
    if hasFill ~= 0 then
        fill = stack:pop()
    end
    local radius = stack:pop()
    runtime:drawCmd("circle", { r = radius, fill = fill })
end

function gCircle_dump(runtime)
    local hasFill = runtime:IP8()
    return fmt("hasfill=%d", hasFill)
end

function gEllipse(stack, runtime) -- 0xDD
    error("Unimplemented opcode gEllipse!")
end

function gPoly(stack, runtime) -- 0xDE
    error("Unimplemented opcode gPoly!")
end

function gFill(stack, runtime) -- 0xDF
    error("Unimplemented opcode gFill!")
end

function gPatt(stack, runtime) -- 0xE0
    error("Unimplemented opcode gPatt!")
end

function gCopy(stack, runtime) -- 0xE1
    local mode = stack:pop()
    local srcRect = stack:popRect()
    local srcId = stack:pop()
    runtime:drawCmd("copy", {
        srcid = srcId,
        srcx = srcRect.x,
        srcy = srcRect.y,
        mode = mode,
        width = srcRect.w,
        height = srcRect.h
    })
    runtime:setTrap(false)
end

function gScroll(stack, runtime) -- 0xE2
    error("Unimplemented opcode gScroll!")
end

function gUpdate(stack, runtime) -- 0xE3
    local flag = runtime:IP8()
    local graphics = runtime:getGraphics()
    local context = graphics.current
    if flag == 255 then -- gUPDATE
        -- Flush now
        runtime:flushGraphicsOps()
        return
    end
    if flag == 0 then -- gUPDATE OFF
        if not graphics.buffer then
            graphics.buffer = {}
        end
    else -- gUPDATE ON
        runtime:flushGraphicsOps()
        graphics.buffer = nil
    end
end

function gUpdate_dump(runtime)
    local flag = runtime:IP8()
    return fmt("flag=%d", flag)
end

function GetEvent(stack, runtime) -- 0xE4
    error("Unimplemented opcode GetEvent!")
end

function gLineTo(stack, runtime) -- 0xE5
    local graphics = runtime:getGraphics()
    local context = graphics.current
    local endPoint = stack:popPoint()
    runtime:drawCmd("line", { x2 = endPoint.x, y2 = endPoint.y })
    context.pos = endPoint
end

function gPeekLine(stack, runtime) -- 0xE6
    error("Unimplemented opcode gPeekLine!")
end

function Screen4(stack, runtime) -- 0xE7
    error("Unimplemented opcode Screen4!")
end

function IoWaitStat(stack, runtime) -- 0xE8
    error("Unimplemented opcode IoWaitStat!")
end

function IoYield(stack, runtime) -- 0xE9
    runtime:iohandler().waitForAnyRequest()
end

function mInit(stack, runtime) -- 0xEA
    runtime:setMenu({
        cascades = {},
    })
end

function mCard(stack, runtime) -- 0xEB
    local numParams = runtime:IP8()
    local menu = runtime:getMenu()
    local card = {}
    for i = 1, numParams do
        local item = {}
        item.keycode = stack:pop()
        item.text = stack:pop()
        if item.text:match(">$") then
            -- It's a cascade
            local cascade = menu.cascades[item.text]
            if cascade then
                item.text = item.text:sub(1, -2)
                item.submenu = cascade
            else
                -- We're suppose to just ignore its cascadiness
                print("CASCADE NOT FOUND")
            end
        end
        -- Last item is popped first
        table.insert(card, 1, item)
    end
    card.title = stack:pop()
    table.insert(menu, card)
end

mCard_dump = numParams_dump

function dInit(stack, runtime) -- 0xEC
    local numParams = runtime:IP8()
    local dialog = {
        flags = 0,
        items = {}
    }
    if numParams == 2 then
        dialog.flags = stack:pop()
    end
    if numParams >= 1 then
        dialog.title = stack:pop()
    end
    runtime:setDialog(dialog)
end

dInit_dump = numParams_dump

function dItem(stack, runtime) -- 0xED
    local itemType = runtime:IP8()
    local dialog = runtime:getDialog()
    local item = { type = itemType }
    if itemType == dItemTypes.dTEXT then
        local flagToAlign = { [0] = "left", [1] = "right", [2] = "center" }
        local flags = 0
        if runtime:IP8() ~= 0 then
            flags = stack:pop()
        end
        item.align = flagToAlign[flags & 3]
        item.value = stack:pop()
        item.prompt = stack:pop()
        item.selectable = (flags & 0x400) > 0
        if item.prompt == "" and item.value == "" and (flags & 0x800) > 0 then
            item = { type = dItemTypes.dSEPARATOR }
        end
        -- Ignoring the other flags for now
    elseif itemType == dItemTypes.dCHOICE then
        local commaList = stack:pop()
        item.choices = {}
        for choice in commaList:gmatch("[^,]+") do
            table.insert(item.choices, choice)
        end
        item.prompt = stack:pop()
        item.variable = stack:pop()
        -- Have to resolve default choice here, and _not_ at the point of the DIALOG call!
        item.value = tostring(item.variable())
    elseif itemType == dItemTypes.dLONG or itemType == dItemTypes.dFLOAT or itemType == dItemTypes.dDATE or itemType == dItemTypes.dTIME then
        item.max = stack:pop()
        item.min = stack:pop()
        assert(item.max >= item.min, KOplErrInvalidArgs)
        local timeFlags
        if itemType == dItemTypes.dTIME then
            timeFlags = stack:pop()
            -- TODO something with timeFlags
        end
        item.prompt = stack:pop()
        item.variable = stack:pop()
        item.value = tostring(item.variable())
    elseif itemType == dItemTypes.dEDIT or itemType == dItemTypes.dEDITlen then
        item.max = 0
        if itemType == dItemTypes.dEDITlen then
            max = stack:pop()
        end
        item.prompt = stack:pop()
        item.variable = stack:pop()
        item.value = tostring(item.variable())
        item.type = dItemTypes.dEDIT -- No need to distinguish in higher layers
    elseif itemType == dItemTypes.dXINPUT then
        item.prompt = stack:pop()
        item.variable = stack:pop()
    elseif itemType == dItemTypes.dBUTTONS then
        assert(dialog.buttons == nil, KOplStructure)
        local numButtons = runtime:IP8()
        dialog.buttons = {}
        for i = 1, numButtons do
            local key = stack:pop()
            local text = stack:pop()
            table.insert(dialog.buttons, 1, { key = key, text = text })
        end
    else
        error("Unsupported dItem type "..itemType)
    end
    if itemType ~= dItemTypes.dBUTTONS then
        table.insert(dialog.items, item)
    end
end

function dItem_dump(runtime)
    local itemType = runtime:IP8()
    local extra = ""
    if itemType == dItemTypes.dBUTTONS then
        extra = fmt(" numButtons=%d", runtime:IP8())
    elseif itemType == dItemTypes.dTEXT then
        extra = fmt(" hasFlags=%d", runtime:IP8())
    end
    return fmt("%d (%s)%s", itemType, dItemTypes[itemType] or "?", extra)
end

function Busy(stack, runtime) -- 0xF0
    error("Unimplemented opcode Busy!")
end

Busy_dump = numParams_dump

function Lock(stack, runtime) -- 0xF1
    runtime:IP8()
    -- Don't care
end

Lock_dump = IPs8_dump

function gInvert(stack, runtime) -- 0xF2
    error("Unimplemented opcode gInvert!")
end

function gXPrint(stack, runtime) -- 0xF3
    error("Unimplemented opcode gXPrint!")
end

function gBorder(stack, runtime) -- 0xF4
    error("Unimplemented opcode gBorder!")
end

function gClock(stack, runtime) -- 0xF5
    error("Unimplemented opcode gClock!")
end

function MkDir(stack, runtime) -- 0xF8
    local path = stack:pop()
    local err = runtime:iohandler().fsop("mkdir", path)
    if err ~= KErrNone then
        error(err)
    end
    runtime:setTrap(false)
end

function RmDir(stack, runtime) -- 0xF9
    error("Unimplemented opcode RmDir!")
end

function SetPath(stack, runtime) -- 0xFA
    error("Unimplemented opcode SetPath!")
end

function SecsToDate(stack, runtime) -- 0xFB
    error("Unimplemented opcode SecsToDate!")
end

function gIPrint(stack, runtime) -- 0xFC
    runtime:IP8() -- TODO
    runtime:iohandler().print(stack:pop() .. "\n")
end

gIPrint_dump = numParams_dump

function NextOpcodeTable(stack, runtime) -- 0xFF
    local realOpcode = 256 + runtime:IP8()
    local fnName = codes[realOpcode]
    local realFn = _ENV[fnName]
    assert(realFn, "No function for "..fnName)
    realFn(stack, runtime)
end

function NextOpcodeTable_dump(runtime)
    local extendedCode = runtime:IP8()
    local realOpcode = 256 + extendedCode
    local fnName = codes[realOpcode]
    local dumpFn = _ENV[fnName.."_dump"]
    return fmt("%02X %s %s", extendedCode, fnName, dumpFn and dumpFn(runtime) or "")
end

function gGrey(stack, runtime) -- 0x100
    local mode = stack:pop()
    local val = mode == 1 and 0xAA or 0
    runtime:getGraphics().current.color = val
end

function DefaultWin(stack, runtime) -- 0x101
    error("Unimplemented opcode DefaultWin!")
end

function Font(stack, runtime) -- 0x104
    error("Unimplemented opcode Font!")
end

function Style(stack, runtime) -- 0x105
    error("Unimplemented opcode Style!")
end

function FreeAlloc(stack, runtime) -- 0x10C
    error("Unimplemented opcode FreeAlloc!")
end

function gButton(stack, runtime) -- 0x10F
    error("Unimplemented opcode gButton!")
end

function gXBorder(stack, runtime) -- 0x110
    error("Unimplemented opcode gXBorder!")
end

function ScreenInfo(stack, runtime) -- 0x114
    error("Unimplemented opcode ScreenInfo!")
end

function CallOpxFunc(stack, runtime) -- 0x118
    local opxNo = runtime:IP8()
    local fnIdx = runtime:IP16()
    local opx = runtime:moduleForProc(runtime:currentProc()).opxTable[1 + opxNo]
    assert(opx, "Bad opx id?")
    if not opx.module then
        opx.module = require("opx."..opx.filename:lower())
    end
    local fnName = opx.module.fns[fnIdx]
    assert(fnName, fmt("OPX function id %d not found in %s!", fnIdx, opx.filename))
    local fn = opx.module[fnName]
    assert(fn, "Unimplemented OPX function "..fnName.. " in "..opx.filename)
    fn(stack, runtime)
end

function CallOpxFunc_dump(runtime)
    local opxNo = runtime:IP8()
    local fnIdx = runtime:IP16()
    local opx = runtime:moduleForProc(runtime:currentProc()).opxTable[1 + opxNo]
    local fnName
    if opx then
        local ok, module = pcall(require, fmt("opx.%s", opx.filename:lower()))
        if ok then
            fnName = module.fns[fnIdx]
        end
    end

    return fmt("%d %d (%s %s)", opxNo, fnIdx, opx and opx.filename or "?", fnName or "?")
end

function Statement32(stack, runtime) -- 0x119
    error("Unimplemented opcode Statement32!")
end

function Modify(stack, runtime) -- 0x11A
    error("Unimplemented opcode Modify!")
end

function Insert(stack, runtime) -- 0x11B
    error("Unimplemented opcode Insert!")
end

function Cancel(stack, runtime) -- 0x11C
    error("Unimplemented opcode Cancel!")
end

function Put(stack, runtime) -- 0x11D
    error("Unimplemented opcode Put!")
end

function DeleteTable(stack, runtime) -- 0x11E
    error("Unimplemented opcode DeleteTable!")
end

function GotoMark(stack, runtime) -- 0x11F
    error("Unimplemented opcode GotoMark!")
end

function KillMark(stack, runtime) -- 0x120
    error("Unimplemented opcode KillMark!")
end

function ReturnFromEval(stack, runtime) -- 0x121
    error("Unimplemented opcode ReturnFromEval!")
end

function GetEvent32(stack, runtime) -- 0x122
    local stat = runtime:makeTemporaryVar(DataTypes.EWord)
    stat(KOplErrFilePending)
    local ev = stack:pop()

    runtime:iohandler().asyncRequest("getevent", stat, ev)
    runtime:waitForRequest(stat)
end

function GetEventA32(stack, runtime) -- 0x123
    local ev = stack:pop()
    local stat = stack:pop()[1]
    stat(KOplErrFilePending)
    runtime:iohandler().asyncRequest("getevent", stat, ev)
end

function gColor(stack, runtime) -- 0x124
    local blue = stack:pop()
    local green = stack:pop()
    local red = stack:pop()
    -- Not gonna bother too much about exact luminosity right now
    local val = (red + green + blue) // 3
    runtime:getGraphics().current.color = val
end

function SetFlags(stack, runtime) -- 0x125
    -- We don't care atm
end

function SetDoc(stack, runtime) -- 0x126
    error("Unimplemented opcode SetDoc!")
end

function DaysToDate(stack, runtime) -- 0x127
    error("Unimplemented opcode DaysToDate!")
end

function gInfo32(stack, runtime) -- 0x128
    -- error("Unimplemented opcode gInfo32!")
    local resultArray = stack:pop()
    -- Heh, ER5 doesn't have this bounds check but we can
    assert(#resultArray >= 48, "Too small an array passed to gInfo32!")
    local graphics = runtime:getGraphics()
    local data = {
        0, -- 1 reserved
        0, -- 2 reserved
        15, -- 3 font height
        15, -- 4 font descent
        12, -- 5 font ascent
        17, -- 6 width of '0' (really?)
        17, -- 7 max character width
        17, -- 8 font flags
        0, -- 9 font uid
        0, -- 10
        0, -- 11
        0, -- 12
        0, -- 13
        0, -- 14
        0, -- 15
        0, -- 16
        0, -- 17
        graphics.current.mode, -- 18
        0, -- 19 gTMode
        0, -- 20 gStyle
        0, -- 21 cursor state
        -1, -- 22 ID of window containing cursor
        0, -- 23 cursor width
        0, -- 24 cursor height
        0, -- 25 cursor ascent
        0, -- 26 cursor x
        0, -- 27 cursor y
        0, -- 28 drawableIsBitmap
        6, -- 29 cursor effects
        0, -- 30 color mode of current window
        0, -- 31 fg r
        0, -- 32 fg g
        0, -- 33 fg b
        255, -- 34 bg r
        255, -- 35 bg g
        255, -- 36 bg b
        0, -- 37
        0, -- 38
        0, -- 39
        0, -- 40
        0, -- 41
        0, -- 42
        0, -- 43
        0, -- 44
        0, -- 45
        0, -- 46
        0, -- 47
        0, -- 48
    }
    for i, val in ipairs(data) do
        resultArray[i](val)
    end
end

function IoWaitStat32(stack, runtime) -- 0x129
    error("Unimplemented opcode IoWaitStat32!")
end

function Compact(stack, runtime) -- 0x12A
    error("Unimplemented opcode Compact!")
end

function BeginTrans(stack, runtime) -- 0x12B
    error("Unimplemented opcode BeginTrans!")
end

function CommitTrans(stack, runtime) -- 0x12C
    error("Unimplemented opcode CommitTrans!")
end

function Rollback(stack, runtime) -- 0x12D
    error("Unimplemented opcode Rollback!")
end

function ClearFlags(stack, runtime) -- 0x12E
    error("Unimplemented opcode ClearFlags!")
end

function PointerFilter(stack, runtime) -- 0x12F
    error("Unimplemented opcode PointerFilter!")
end

function mCasc(stack, runtime) -- 0x130
    local numParams = runtime:IP8()
    local card = {}
    for i = 1, numParams do
        local keycode = stack:pop()
        local text = stack:pop()
        -- Last item is popped first
        table.insert(card, 1, { keycode = keycode, text = text })
    end
    local title = stack:pop()
    card.title = title
    runtime:getMenu().cascades[title..">"] = card
end

mCasc_dump = numParams_dump

function EvalExternalRightSideRef(stack, runtime) -- 0x131
    error("Unimplemented opcode EvalExternalRightSideRef!")
end

function EvalExternalLeftSideRef(stack, runtime) -- 0x132
    error("Unimplemented opcode EvalExternalLeftSideRef!")
end

function dEditCheckbox(stack, runtime) -- 0x133
    local dialog = runtime:getDialog()
    local item = { type = dItemTypes.dCHECKBOX }
    item.prompt = stack:pop()
    item.variable = stack:pop()
    item.value = tostring(item.variable())
    table.insert(dialog.items, item)
end

function gXBorder32(stack, runtime) -- 0x13B
    error("Unimplemented opcode gXBorder32!")
end

function SetHelpUid(stack, runtime) -- 0x13A
    error("Unimplemented opcode SetHelpUid!")
end

function ShowHelp(stack, runtime) -- 0x139
    error("Unimplemented opcode ShowHelp!")
end

function SetHelp(stack, runtime) -- 0x138
    error("Unimplemented opcode SetHelp!")
end

function mCardX(stack, runtime) -- 0x137
    error("Unimplemented opcode mCardX!")
end

function gColorBackground(stack, runtime) -- 0x136
    error("Unimplemented opcode gColorBackground!")
end

function gColorInfo(stack, runtime) -- 0x135
    error("Unimplemented opcode gColorInfo!")
end

function dEditMulti(stack, runtime) -- 0x134
    error("Unimplemented opcode dEditMulti!")
end

return _ENV
