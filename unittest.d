/++
++/
import std.stdio;
pragma(lib, "dwin.lib");
import dwin.core;
import dwin.error;
import dwin.nls;

void main() {
    version(All) {
        lastError;          // dwin.error
        Locale("en-US");    // dwin.nls
    }
}
