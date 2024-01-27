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

_ENV = module()

keys = {
    capsLock = 2,
    backspace = 8,
    tab = 9,
    enter = 13,
    leftShift = 18,
    rightShift = 19,
    control = 22,
    fn = 24,
    escape = 27,
    space = 32,
    exclamationMark = 33,
    doubleQuote = 34,
    hash = 35,
    dollar = 36,
    percent = 37,
    ampersand = 38,
    singleQuote = 39,
    leftParenthesis = 40,
    rightParenthesis = 41,
    asterisk = 42,
    plus = 43,
    comma = 44,
    minus = 45,
    fullStop = 46,
    slash = 47,
    num0 = 48,
    num1 = 49,
    num2 = 50,
    num3 = 51,
    num4 = 52,
    num5 = 53,
    num6 = 54,
    num7 = 55,
    num8 = 56,
    num9 = 57,
    colon = 58,
    semicolon = 59,
    lessThan = 60,
    equals = 61,
    greaterThan = 62,
    questionMark = 63,
    atSign = 64,
    A = 65,
    B = 66,
    C = 67,
    D = 68,
    E = 69,
    F = 70,
    G = 71,
    H = 72,
    I = 73,
    J = 74,
    K = 75,
    L = 76,
    M = 77,
    N = 78,
    O = 79,
    P = 80,
    Q = 81,
    R = 82,
    S = 83,
    T = 84,
    U = 85,
    V = 86,
    W = 87,
    X = 88,
    Y = 89,
    Z = 90,
    leftSquareBracket = 91,
    backslash = 92,
    rightSquareBracket = 93,
    circumflex = 94,
    underscore = 95,
    a = 97,
    b = 98,
    c = 99,
    d = 100,
    e = 101,
    f = 102,
    g = 103,
    h = 104,
    i = 105,
    j = 106,
    k = 107,
    l = 108,
    m = 109,
    n = 110,
    o = 111,
    p = 112,
    q = 113,
    r = 114,
    s = 115,
    t = 116,
    u = 117,
    v = 118,
    w = 119,
    x = 120,
    y = 121,
    z = 122,
    leftCurlyBracket = 123,
    rightCurlyBracket = 125,
    tilde = 126,
    pound = 163,
    multiply = 215,
    divide = 247,
    homeKey = 4098,
    endKey = 4099,
    pgUp = 4100,
    pgDn = 4101,
    leftArrow = 4103,
    rightArrow = 4104,
    upArrow = 4105,
    downArrow = 4106,
    menu = 4150,
    dial = 4155,
    menuSoftkey = 10000,
    clipboardSoftkey = 10001,
    irSoftkey = 10002,
    zoomInSoftkey = 10003,
    zoomOutSoftkey = 10004,
}

series3aScanCodes = {
    -- Byte 0
    keys.enter,
    keys.rightArrow,
    keys.tab,
    keys.y,
    keys.leftArrow,
    keys.downArrow,
    keys.n,
    0, -- psion key
    
    -- Byte 1
    0, -- Sheet
    0, -- Time
    0,
    0,
    0,
    0,
    0,
    0,

    -- Byte 2
    0,
    keys.slash,
    keys.minus,
    keys.plus,
    keys.num0,
    keys.p,
    keys.asterisk,
    keys.leftShift,

    -- Byte 3
    0, -- Calc
    0, -- Agenda
    0,
    0,
    0,
    0,
    0,
    0,

    -- Byte 4
    keys.backspace,
    keys.k,
    keys.i,
    keys.num8,
    keys.num9,
    keys.o,
    keys.l,
    keys.control,

    -- Byte 5
    0, -- World
    0,
    0,
    0,
    0,
    0,
    0,
    0,

    -- Byte 6,
    0,
    keys.comma,
    0, -- help
    keys.m,
    keys.j,
    keys.u,
    keys.num7,
    keys.rightShift,

    -- Byte 7
    0,
    0, -- Data
    0,
    0,
    0,
    0,
    0,
    0,

    -- Byte 8,
    keys.space,
    keys.r,
    keys.num4,
    keys.num5,
    keys.t,
    keys.g,
    keys.b,
    0, -- Diamond

    -- Byte 9
    0,
    0, -- System
    0,
    0,
    0,
    0,
    0,
    0,

    -- Byte 10
    0,
    keys.f,
    keys.v,
    keys.c,
    keys.d,
    keys.e,
    keys.num3,
    keys.menu,

    -- Byte 11
    0,
    0, -- Word
    0,
    0,
    0,
    0,
    0,
    0,

    -- Byte 12
    0,
    keys.q,
    keys.a,
    keys.z,
    keys.s,
    keys.w,
    keys.x,
    0,

    -- Byte 13
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,

    -- Byte 14
    0,
    keys.num1,
    keys.num2,
    keys.num6,
    keys.fullStop,
    keys.upArrow,
    keys.h,
    0,

    -- Byte 15
    keys.escape,
    0,
    0,
    0,
    0,
    0,
    0,
    0,

    -- Byte 16
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,

    -- Byte 17
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,

    -- Byte 18
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,

    -- Byte 19
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
}
assert(#series3aScanCodes == 20*8)

return _ENV
