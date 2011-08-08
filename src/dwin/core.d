/++
Helper module

License: $(BOOST)
Authors: $(SIMENDSJO)
Source: $(MODULE_SOURCE_LINK)
++/
module dwin.core;

import std.traits, std.utf, std.traits, std.range, std.conv, std.exception;

import dwin.error;

public import win32.windef;
private import win32.winbase;

/++
Converts a $(D_KEYWORD string), $(D_KEYWORD wstring) or
$(D_KEYWORD dstring) to a null terminated string for passing to win32 API
calls.
++/
TCHAR* toWinStringz(S)(S str) {
    return toUTFz!(TCHAR*)(str);
}

/++
Converts from a Win32 string to D string array. Removes the null terminator
if it exists.
++/
TCHAR[] fromWinStringz(TCHAR* str) {
    auto len = lstrlen(str);
    // exclude \0
    if(len > 0 && str[len-1] == '\0')
        --len;
    return str[0..len];
}

/++
A safer way to store a win32 $(D_PSYMBOL HANDLE). Asserts or throws an
exception if using a closed $(D_PSYMBOL HANDLE).

Examples:
---------
auto h1 = new Handle(0); // asserts
auto h2 = new Handle(666); // asserts if invalid handle
auto h3 = new Handle(999);
h3.close();
auto handle = h3.handle; // asserts as handle is closed

auto h4 = new Handle(1010);
auto h5 = new Handle(1010);
h4.close();
handle = h5.handle; // asserts as h4 already closed the handle
--------
++/
final class Handle {
    private HANDLE _handle;

    @property HANDLE handle() {
        assert(_handle, "Handle is closed");
        return _handle;
    }

    invariant() {
        if(_handle) {
            DWORD flags;
            winEnforce(GetHandleInformation(_handle, &flags));
        }
    }

    this(HANDLE handle)
    in {
        assert(handle);
    } body {
        _handle = handle;
    }

    ~this() {
        if(_handle) close();
    }

    void close() {
        if(_handle) {
            winEnforce(CloseHandle(_handle));
            _handle = null;
        }
    }
}

/++
Embeds a private Handle instance as _handle_$(D_PARAM name)

You must initialize the handle in the constructor.

Params:
    name = Handle name. This will create a getter and setter property with
           the same name. The getter will get the underlying
           $(D_PSYMBOL HANDLE) instance, while the setter will set the
           $(D_PSYMBOL Handle) instance.  The close function will be named
           $(D_PARAM name)Close

Examples:
---------
struct S {
  EmbedHandle!"myHandle";

  this(HANDLE handle) {
    myHandle = new Handle(handle);
    assert(myHandle == handle);
  }
}

auto S = S(999); // 999 must be a valid handle, or else it asserts
assert(S.handle == 999);
S.myhandleClose();
auto h = S.handle; // assertion as handle is closed
---------
++/
mixin template EmbedHandle(string name) {
    mixin("private Handle _handle_"~name~";");

    mixin("@property HANDLE "~name~"() {
             assert(_handle_"~name~", \"Handle not initialized or already closed\");
             return _handle_"~name~".handle;
           }");

    mixin("private @property void "~name~"(Handle handle) {
               assert(!_handle_"~name~", \"Handle already set\");
               _handle_"~name~" = handle;
           }");

    mixin("void "~name~"Close() {
               if(_handle_"~name~") {
                  _handle_"~name~".close();
                  _handle_"~name~" = null;
               }
           }");
}

/++
As $(D_PSYMBOL EmbedHandle), but also adds a destructor to close the
$(D_PSYMBOL Handle).

BUGS:
Because only one destructor can exist, you can only add it to a
$(D_KEYWORD struct)/$(D_KEYWORD class) that doesn't already contain
a destructor.

Examples:
---------
struct S {
    mixin EmbedScopedHandle!"myHandle";
    this(HANDLE handle) {
        myHandle = new Handle(handle);
    }
}

HANDLE handle = 999; // assume 999 is a valid handle
{ auto s = S(handle);
  // do stuff with handle
} // handle closes here
auto s = S(handle); // assertion as handle is closed
---------
++/
mixin template EmbedScopedHandle(string name) {
    mixin EmbedHandle!name;
    mixin("~this() { "~name~"Close();}");
}

/* =================== toUTFz ======================= */

/++
    BUGS: STOLEN FROM PHOBOS TRUNK - REMOVE IN DMD 2.055!!

    Returns a C-style zero-terminated string equivalent to $(D str). $(D str)
    must not contain embedded $(D '\0')'s as any C function will treat the first
    $(D '\0') that it sees a the end of the string. If $(D str.empty) is
    $(D true), then a string containing only $(D '\0') is returned.

    $(D toUTFz) accepts any type of string and is templated on the type of
    character pointer that you wish to convert to. It will avoid allocating a
    new string if it can, but there's a decent chance that it will end up having
    to allocate a new string - particularly when dealing with character types
    other than $(D char).

    $(RED Warning 1:) If the result of $(D toUTFz) equals $(D str.ptr), then if
    anything alters the character one past the end of $(D str) (which is the
    $(D '\0') character terminating the string), then the string won't be
    zero-terminated anymore. The most likely scenarios for that are if you
    append to $(D str) and no reallocation takes place or when $(D str) is a
    slice of a larger array, and you alter the character in the larger array
    which is one character past the end of $(D str). Another case where it could
    occur would be if you had a mutable character array immediately after
    $(D str) in memory (for example, if they're member variables in a
    user-defined type with one declared right after the other) and that
    character array happened to start with $(D '\0'). Such scenarios will never
    occur if you immediately use the zero-terminated string after calling
    $(D toUTFz) and the C function using it doesn't keep a reference to it.
    Also, they are unlikely to occur even if you save the zero-terminated string
    (the cases above would be among the few examples of where it could happen).
    However, if you save the zero-terminate string and want to be absolutely
    certain that the string stays zero-terminated, then simply append a
    $(D '\0') to the string and use its $(D ptr) property rather than calling
    $(D toUTFz).

    $(RED Warning 2:) When passing a character pointer to a C function, and the
    C function keeps it around for any reason, make sure that you keep a
    reference to it in your D code. Otherwise, it may go away during a garbage
    collection cycle and cause a nasty bug when the C code tries to use it.

    Examples:
--------------------
auto p1 = toUTFz!(char*)("hello world");
auto p2 = toUTFz!(const(char)*)("hello world");
auto p3 = toUTFz!(immutable(char)*)("hello world");
auto p4 = toUTFz!(char*)("hello world"d);
auto p5 = toUTFz!(const(wchar)*)("hello world");
auto p6 = toUTFz!(immutable(dchar)*)("hello world"w);
--------------------
  +/
P toUTFz(P, S)(S str) @system
    if(isSomeString!S && isPointer!P && isSomeChar!(typeof(*P.init)) &&
       is(Unqual!(typeof(*P.init)) == Unqual!(ElementEncodingType!S)) &&
       is(immutable(Unqual!(ElementEncodingType!S)) == ElementEncodingType!S))
//immutable(C)[] -> C*, const(C)*, or immutable(C)*
{
    if(str.empty)
    {
        typeof(*P.init)[] retval = ['\0'];

        return retval.ptr;
    }

    alias Unqual!(ElementEncodingType!S) C;

    //If the P is mutable, then we have to make a copy.
    static if(is(Unqual!(typeof(*P.init)) == typeof(*P.init)))
        return toUTFz!(P, const(C)[])(cast(const(C)[])str);
    else
    {
        immutable p = str.ptr + str.length;

        // Peek past end of str, if it's 0, no conversion necessary.
        // Note that the compiler will put a 0 past the end of static
        // strings, and the storage allocator will put a 0 past the end
        // of newly allocated char[]'s.
        // Is p dereferenceable? A simple test: if the p points to an
        // address multiple of 4, then conservatively assume the pointer
        // might be pointing to a new block of memory, which might be
        // unreadable. Otherwise, it's definitely pointing to valid
        // memory.
        if((cast(size_t)p & 3) && *p == '\0')
            return str.ptr;

        return toUTFz!(P, const(C)[])(cast(const(C)[])str);
    }
}

P toUTFz(P, S)(S str) @system
    if(isSomeString!S && isPointer!P && isSomeChar!(typeof(*P.init)) &&
       is(Unqual!(typeof(*P.init)) == Unqual!(ElementEncodingType!S)) &&
       !is(immutable(Unqual!(ElementEncodingType!S)) == ElementEncodingType!S))
//C[] or const(C)[] -> C*, const(C)*, or immutable(C)*
{
    alias ElementEncodingType!S InChar;
    alias typeof(*P.init) OutChar;

    //const(C)[] -> const(C)* or
    //C[] -> C* or const(C)*
    static if((is(const(Unqual!InChar) == InChar) && is(const(Unqual!OutChar) == OutChar)) ||
              (!is(const(Unqual!InChar) == InChar) && !is(immutable(Unqual!OutChar) == OutChar)))
    {
        auto p = str.ptr + str.length;

        if((cast(size_t)p & 3) && *p == '\0')
            return str.ptr;

        str ~= '\0';
        return str.ptr;
    }
    //const(C)[] -> C* or immutable(C)* or
    //C[] -> immutable(C)*
    else
    {
        auto copy = uninitializedArray!(Unqual!OutChar[])(str.length + 1);
        copy[0 .. $ - 1] = str[];
        copy[$ - 1] = '\0';

        return cast(P)copy.ptr;
    }
}

P toUTFz(P, S)(S str)
    if(isSomeString!S && isPointer!P && isSomeChar!(typeof(*P.init)) &&
       !is(Unqual!(typeof(*P.init)) == Unqual!(ElementEncodingType!S)))
//C1[], const(C1)[], or immutable(C1)[] -> C2*, const(C2)*, or immutable(C2)*
{
    auto retval = appender!(typeof(*P.init)[])();

    foreach(dchar c; str)
        retval.put(c);
    retval.put('\0');

    return cast(P)retval.data.ptr;
}

//Verify Examples.
unittest
{
    auto p1 = toUTFz!(char*)("hello world");
    auto p2 = toUTFz!(const(char)*)("hello world");
    auto p3 = toUTFz!(immutable(char)*)("hello world");
    auto p4 = toUTFz!(char*)("hello world"d);
    auto p5 = toUTFz!(const(wchar)*)("hello world");
    auto p6 = toUTFz!(immutable(dchar)*)("hello world"w);
}

unittest
{
    import core.exception;
    import std.algorithm;
    import std.metastrings;
    import std.typetuple;

    size_t zeroLen(C)(const(C)* ptr)
    {
        size_t len = 0;

        while(*ptr != '\0')
        {
            ++ptr;
            ++len;
        }

        return len;
    }

    foreach(S; TypeTuple!(string, wstring, dstring))
    {
        alias Unqual!(typeof(S.init[0])) C;

        auto s1 = to!S("hello\U00010143\u0100\U00010143");
        auto temp = new C[](s1.length + 1);
        temp[0 .. $ - 1] = s1[0 .. $];
        temp[$ - 1] = '\n';
        --temp.length;
        auto s2 = assumeUnique(temp);
        assert(s1 == s2);

        foreach(P; TypeTuple!(C*, const(C)*, immutable(C)*))
        {
            auto p1 = toUTFz!P(s1);
            assert(p1[0 .. s1.length] == s1);
            assert(p1[s1.length] == '\0');

            auto p2 = toUTFz!P(s2);
            assert(p2[0 .. s2.length] == s2);
            assert(p2[s2.length] == '\0');
        }
    }

    void test(P, S)(S s, size_t line = __LINE__)
    {
        auto p = toUTFz!P(s);
        immutable len = zeroLen(p);
        enforce(cmp(s, p[0 .. len]) == 0,
                new AssertError(Format!("Unit test failed: %s %s", P.stringof, S.stringof),
                                __FILE__, line));
    }

    foreach(P; TypeTuple!(wchar*, const(wchar)*, immutable(wchar)*,
                          dchar*, const(dchar)*, immutable(dchar)*))
    {
        test!P("hello\U00010143\u0100\U00010143");
    }

    foreach(P; TypeTuple!(char*, const(char)*, immutable(char)*,
                          dchar*, const(dchar)*, immutable(dchar)*))
    {
        test!P("hello\U00010143\u0100\U00010143"w);
    }

    foreach(P; TypeTuple!(char*, const(char)*, immutable(char)*,
                          wchar*, const(wchar)*, immutable(wchar)*))
    {
        test!P("hello\U00010143\u0100\U00010143"d);
    }

    foreach(S; TypeTuple!(char[], wchar[], dchar[],
                          const(char)[], const(wchar)[], const(dchar)[]))
    {
        auto s = to!S("hello\U00010143\u0100\U00010143");

        foreach(P; TypeTuple!(char*, wchar*, dchar*,
                              const(char)*, const(wchar)*, const(dchar)*,
                              immutable(char)*, immutable(wchar)*, immutable(dchar)*))
        {
            test!P(s);
        }
    }
}


/* ================================ tests ================================== */

unittest
{
    debug(utf) printf("utf.toUTF.unittest\n");

    string c;
    wstring w;
    dstring d;

    c = "hello";
    w = toUTF16(c);
    assert(w == "hello");
    d = toUTF32(c);
    assert(d == "hello");
    c = toUTF8(w);
    assert(c == "hello");
    d = toUTF32(w);
    assert(d == "hello");

    c = toUTF8(d);
    assert(c == "hello");
    w = toUTF16(d);
    assert(w == "hello");


    c = "hel\u1234o";
    w = toUTF16(c);
    assert(w == "hel\u1234o");
    d = toUTF32(c);
    assert(d == "hel\u1234o");

    c = toUTF8(w);
    assert(c == "hel\u1234o");
    d = toUTF32(w);
    assert(d == "hel\u1234o");

    c = toUTF8(d);
    assert(c == "hel\u1234o");
    w = toUTF16(d);
    assert(w == "hel\u1234o");


    c = "he\U0010AAAAllo";
    w = toUTF16(c);
    //foreach (wchar c; w) printf("c = x%x\n", c);
    //foreach (wchar c; cast(wstring)"he\U0010AAAAllo") printf("c = x%x\n", c);
    assert(w == "he\U0010AAAAllo");
    d = toUTF32(c);
    assert(d == "he\U0010AAAAllo");

    c = toUTF8(w);
    assert(c == "he\U0010AAAAllo");
    d = toUTF32(w);
    assert(d == "he\U0010AAAAllo");

    c = toUTF8(d);
    assert(c == "he\U0010AAAAllo");
    w = toUTF16(d);
    assert(w == "he\U0010AAAAllo");
}
