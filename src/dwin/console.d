/++
License: $(BOOST)
Authors: $(SIMENDSJO)
Source: $(MODULE_SOURCE_LINK)
++/
module dwin.console;

import dwin.core, dwin.error, dwin.nls;
private import std.exception;

private import win32.wincon;
pragma(lib, "kernel32.lib");
extern(Windows) {
    DWORD GetConsoleOriginalTitleW(LPTSTR, DWORD);
}
enum HANDLE STD_INPUT_HANDLE   = cast(HANDLE)-10;
enum HANDLE STD_OUTPUT_HANDLE  = cast(HANDLE)-11;
enum HANDLE STD_ERROR_HANDLE   = cast(HANDLE)-12;

struct Console {
    HANDLE handle;

    this(HANDLE console) {
        handle = console;
    }

    static @property Console stdin() {
        return Console(STD_INPUT_HANDLE);
    }

    static @property Console stdout() {
        return Console(STD_OUTPUT_HANDLE);
    }

    static @property Console stderr() {
        return Console(STD_ERROR_HANDLE);
    }

    static @property void outputCodePage(CodePage codePage) {
        winEnforce(SetConsoleOutputCP(codePage.handle));
    }

    static @property CodePage outputCodePage() {
        return CodePage(winEnforce(GetConsoleOutputCP()));
    }

    static @property void inputCodePage(CodePage codePage) {
        winEnforce(SetConsoleCP(codePage.handle));
    }

    static @property CodePage inputCodePage() {
        return CodePage(winEnforce(GetConsoleCP()));
    }

    static @property void codePage(CodePage codePage) {
        inputCodePage = codePage;
        outputCodePage = codePage;
    }

    static @property void title(Char)(const(Char[]) title) {
        winEnforce(SetConsoleTitle(toWinStringz(title)));
    }

    // DMD BUG: Cannot overload template with non-template
    static @property immutable(TCHAR[]) title()() {
        auto title = new TCHAR[128];
        winEnforce(GetConsoleTitle(title.ptr, title.length));
        return assumeUnique(title);
    }

    static @property immutable(TCHAR[]) originalTitle() {
        auto title = new TCHAR[128];
        winEnforce(GetConsoleOriginalTitleW(title.ptr, title.length));
        return assumeUnique(title);
    }
}
