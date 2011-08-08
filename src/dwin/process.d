/++
Process and thread

License: $(BOOST)
Authors: $(SIMENDSJO)
Source: $(MODULE_SOURCE_LINK)
++/
module dwin.process;

import std.exception;

import dwin.core;
import dwin.error;

// Missing translated functions
pragma(lib, "psapi.lib");
extern(Windows) {
    BOOL EnumProcesses(DWORD*, DWORD, DWORD*);
    HANDLE CreateToolhelp32Snapshot(DWORD, DWORD);
}
// End missing translated functions

import win32.windef;
import win32.psapi;

struct Snapshot {
    mixin EmbedScopedHandle!"handle";

    this(DWORD flags, DWORD procId) {
        handle = new Handle(winEnforce(CreateToolhelp32Snapshot(flags, procId)));
    }
}

/++
    Returns:
        An array containing all running process id's in the system
++/
@property immutable(DWORD[]) processIds()
out(result) {
    assert(result.length >= 2);
    assert(result[0] == 0, "System Idle process (PID:0) missing");
    assert(result[1] == 4, "System process (PID:4) missing");
} body {
    auto procIds = new DWORD[256];
    DWORD bytes, received;

    for(received = procIds.length; received == procIds.length; procIds.length += 64) {
        winEnforce(EnumProcesses(
                    procIds.ptr,
                    procIds.length * procIds[0].sizeof,
                    &bytes));
        received = bytes / procIds[0].sizeof;
    }

    return assumeUnique(procIds[0 .. received]);
}
