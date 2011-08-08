/++
License: $(BOOST)
Authors: $(SIMENDSJO)
Source: $(MODULE_SOURCE_LINK)
++/
module dwin.error;

import dwin.core;

import std.conv, std.string, std.exception;

import win32.winbase;

class Win32Exception : Exception {
    public const DWORD code;

    @property public bool isSystemError() {
        return .isSystemError(code);
    }

    this(const(TCHAR)[] message) {
        code = 0;
        super(to!string(message));
    }

    this(char[] message) {
        code = 0;
        super(message.idup);
    }

    this(DWORD code, const(TCHAR)[] message) {
        this.code = code;
        super(to!string(message));
    }

    override string toString() {
        return to!string(code) ~ ": " ~ msg;
    }
}

void throwLastError() {
    auto code = GetLastError();
    assert(code, "Cannot throw last error as there isn't one");
    auto message = getErrorString(code);
    throw new Win32Exception(code, message);
}

T winEnforce(T, string file = __FILE__, int line = __LINE__)(T value, T expected) {
    if(value != expected)
        throwLastError();
    return value;
}

T winEnforce(T, string file = __FILE__, int line = __LINE__)(T value) {
    if(!value)
        throwLastError();
    return value;
}

@property DWORD lastError() {
    return GetLastError();
}

@property void lastError(DWORD code) {
    enforce(isSystemError(code), "You are not allowed to set system errors!");
    SetLastError(code);
}

@property bool isSystemError(DWORD code) {
    // bit 29 marks an user error code
    return (code & (1<<28)) == 0;
} unittest {
    assert( isSystemError(0b0000_0000_0000_0000_0000_0000_0000_0000));
    assert(!isSystemError(0b0001_0000_0000_0000_0000_0000_0000_0000));
}

immutable(TCHAR)[] getErrorString(DWORD errCode) {
    LPVOID msgBuf = null;
    scope(exit) LocalFree(cast(HANDLE)msgBuf);

    winEnforce(FormatMessage(
                FORMAT_MESSAGE_ALLOCATE_BUFFER |
                    FORMAT_MESSAGE_FROM_SYSTEM |
                    FORMAT_MESSAGE_IGNORE_INSERTS,
                null,
                errCode,
                MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                cast(LPTSTR)&msgBuf,
                0,
                null));

    assert(msgBuf);
    immutable len = lstrlen(cast(LPTSTR)msgBuf) * TCHAR.sizeof;
    assert(len >= 0);
    auto msg = cast(TCHAR[])msgBuf[0 .. len];

    // stip as the error ends in newline
    return stripRight(msg).idup;
} unittest {
}

enum ErrorMode : DWORD {
    FailCriticalErrors              = SEM_FAILCRITICALERRORS,
    NoAlignmentFaultExcept          = SEM_NOALIGNMENTFAULTEXCEPT,
    NoGeneralPurposeFaultErrorBox   = SEM_NOGPFAULTERRORBOX,
    NoOpenFileErrorBox              = SEM_NOOPENFILEERRORBOX,
}

@property ErrorMode errorMode() {
    return cast(ErrorMode)GetErrorMode();
}

@property ErrorMode errorMode(ErrorMode mode) {
    return cast(ErrorMode)SetErrorMode(cast(UINT)mode);
}

ErrorMode setErrorModeAll() {
    return cast(ErrorMode)SetErrorMode(0);
}

@property ErrorMode threadErrorMode() {
    return cast(ErrorMode)GetThreadErrorMode();
}

/+
@property ErrorMode threadErrorMode(ErrorMode mode) {
    LPDWORD prevMode;
    winEnforce(SetThreadErrorMode(mode, prevMode));
    return cast(ErrorMode)*prevMode;
}
+/

void beep(DWORD frequency, DWORD durationInMilliseconds) {
    assert(frequency >= 37 && frequency <= 32767, "Frequency out of range");
    assert(durationInMilliseconds >= 0);
    winEnforce(Beep(frequency, durationInMilliseconds));
}
