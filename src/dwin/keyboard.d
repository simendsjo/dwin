/++
License: $(BOOST)
Authors: $(SIMENDSJO)
Source: $(MODULE_SOURCE_LINK)
++/
module dwin.keyboard;

import std.exception;

import dwin.core;
import dwin.error;

import win32.windef;
import win32.winuser;
private import win32.winnt;

@property immutable(TCHAR[]) keyboardLayoutName() {
    auto result = new TCHAR[KL_NAMELENGTH];
    auto len = winEnforce(GetKeyboardLayoutName(result.ptr));
    assert(len);
    return assumeUnique(result[0 .. len]);
}

@property HKL getKeyboardLayout(DWORD threadId = 0) {
    return GetKeyboardLayout(threadId);
}

