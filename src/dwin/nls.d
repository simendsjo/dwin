/++
National Language Support

Windows globalization features

Bugs:
Code Page 20949 and 1147 is skipped as GetCPInfoEx fails for these code pages

See_Also:
$(UL
    $(LI $(MSDN dd319078.aspx,          National Language Support))
    $(LI $(MSDN dd318140(v=VS.85).aspx, Globalization Services))
    $(LI $(MSDN dd317752(v=VS.85).aspx, Code Pages))
)

Macros:
CP_LIST = $(MSDN dd317756(v=vs.85).aspx,    Code Page Identifiers)
CPINFO  = $(MSDN dd317781(VS.85).aspx,      CPINFOEX Structure)

License: $(BOOST)
Authors: $(SIMENDSJO)
Source: $(MODULE_SOURCE_LINK)
++/
module dwin.nls;

private import std.conv;
private import std.utf;
private import std.algorithm;
private import std.array;
debug private import std.stdio;
private import std.exception;
private import std.traits;

import dwin.core;
import dwin.error;

private import win32.winnt;
private import win32.winnls;
private import win32.winbase;

// Missing translated functions
pragma(lib, "kernel32.lib");
extern(Windows) {
    LCID LocaleNameToLCID(LPCWSTR, DWORD);
    BOOL IsValidLocaleName(LPCWSTR);
    alias BOOL function(LPWSTR, DWORD, LPARAM) LOCALE_ENUMPROCEX;
    BOOL EnumSystemLocalesEx(LOCALE_ENUMPROCEX, DWORD, LPARAM, LPVOID);
    int GetLocaleInfoEx(LPCWSTR, LCTYPE, LPWSTR, int);
    int LCIDToLocaleName(LCID, LPWSTR, int, DWORD);
}

enum CP_INSTALLED = 0x00000001;
enum CP_SUPPORTED = 0x00000002;

enum LOCALE_ALLOW_NEUTRAL_NAMES = 0x08000000;
enum LOCALE_ALL                 = 0;
enum LOCALE_INVARIANT           = MAKELCID(MAKELANGID(LANG_INVARIANT, SUBLANG_NEUTRAL), SORT_DEFAULT);

enum LOCALE_SLOCALIZEDDISPLAYNAME   = 0x00000002;
enum LOCALE_SLOCALIZEDLANGUAGENAME  = 0x0000006F;
enum LOCALE_SLOCALIZEDCOUNTRYNAME   = 0x00000006;
enum LOCALE_SENGLISHDISPLAYNAME     = 0x00000072;
enum LOCALE_SENGLISHLANGUAGENAME    = 0x00001001;
enum LOCALE_SENGLISHCOUNTRYNAME     = 0x00001002;
enum LOCALE_SPERCENT                = 0x00000076;
enum LOCALE_SPERMILLE               = 0x00000077;
enum LOCALE_SSHORTTIME              = 0x00000079;
enum LOCALE_SSORTLOCALE             = 0x0000007B;
enum LOCALE_SPOSINFINITY            = 0x0000006A;
enum LOCALE_SNEGINFINITY            = 0x0000006B;
enum LOCALE_SNATIVEDISPLAYNAME      = 0x00000073;
enum LOCALE_SNATIVELANGUAGENAME     = 0x00000004;
enum LOCALE_SNATIVECOUNTRYNAME      = 0x00000008;
enum LOCALE_SISO639LANGNAME2        = 0x00000067;
enum LOCALE_SISO3166CTRYNAME2       = 0x00000068;
enum LOCALE_SNAN                    = 0x00000069;
enum LOCALE_SNEGATIVESIGN           = 0x00000051;
// End translation

/++
++/
struct CodePage {
    immutable uint handle;
    private CPINFOEX _info;

    /// See_Also: $(CPINFO)
    @property immutable(CPINFOEX) info() {
        if(!_info.CodePage) {
            winEnforce(GetCPInfoEx(handle, 0/*reserved*/, cast(CPINFOEX*)&_info));
        }
        return _info;
    }

    /// See_Also: $(CP_LIST)
    this(uint codePage) {
        handle = codePage;
    }

    /// See_Also: $(CPINFO)
    @property uint maxCharSize() {
        return info.MaxCharSize;
    }

    /// ditto
    @property immutable(TCHAR)[] name() {
        int i;
        for(; i < info.CodePageName.length; ++i) {
            if(info.CodePageName[i] == '\0') break;
        }
        return info.CodePageName[0..i];
    }

    /// ditto
    @property TCHAR unicodeDefaultChar() {
        return info.UnicodeDefaultChar;
    }

    /// ditto
    @property ubyte[2] defaultChar() {
        return info.DefaultChar;
    }

    /// ditto
    @property ubyte[12] leadByte() {
        return info.LeadByte;
    }

    /// UTF-8 Code Page
    static @property CodePage utf8() {
        return CodePage(65001);
    }

    /++
    See_Also: $(MSDN dd317825(v=VS.85).aspx, EnumSystemCodePages)
    Returns: code pages on the system
    ++/
    static @property CodePage[] installed() {
        return getCodePages(CP_INSTALLED);
    }

    /// ditto
    static @property CodePage[] supported() {
        return getCodePages(CP_SUPPORTED);
    }

    /// ditto
    private static CodePage[] getCodePages(DWORD flags) {
        static CodePage[] result;
        if(!result.length)
            result.reserve(150);
        else
            result.clear();

        extern(Windows) static BOOL getNext(LPTSTR codePage) {
            immutable len = lstrlen(codePage);
            assert(len);
            uint codePageId = to!uint(codePage[0..len]);
            if(codePageId != 20949 && codePageId != 1147)
                result ~= CodePage(codePageId);
            return true;
        }

        winEnforce(EnumSystemCodePages(&getNext, flags));
        return result;
    }

    string toString() {
        return to!string(handle);
    }
}

/++
++/
struct Language {
    immutable WORD handle;

    invariant() {
        assert(handle);
    }

    this(WORD handle) {
        this.handle = handle;
    }

    this(USHORT primary, USHORT sub) {
        handle = MAKELANGID(primary, sub);
    }

    @property WORD primary() immutable {
        return PRIMARYLANGID(handle);
    }

    @property WORD sub() immutable {
        return SUBLANGID(handle);
    }

    static @property Language neutral() {
        return Language(LANG_NEUTRAL, SUBLANG_NEUTRAL);
    }

    static @property Language userDefault() {
        return Language(LANG_NEUTRAL, SUBLANG_DEFAULT);
    }

    static @property Language systemDefault() {
        return Language(LANG_NEUTRAL, SUBLANG_SYS_DEFAULT);
    }

    static @property Language customDefault() {
        return Language(LANG_NEUTRAL, SUBLANG_CUSTOM_DEFAULT);
    }

    static @property Language customUnspecifiedDefault() {
        return Language(LANG_NEUTRAL, SUBLANG_CUSTOM_UNSPECIFIED);
    }

    static @property Language customMultilingualUserInterfaceDefault() {
        return Language(LANG_NEUTRAL, SUBLANG_UI_CUSTOM_DEFAULT);
    }
}

/++
++/
struct SortOrder {
    immutable WORD handle;

    invariant() {
        assert(handle);
    }

    this(WORD sortId) {
        handle = sortId;
    }
}

/++
++/
struct Locale {
    immutable LCID handle;
    private immutable(TCHAR)[] _name;

    invariant() {
        assert(handle);
    }

    /// 
    this(LCID localeId) {
        handle = localeId;
    }

    /// 
    this(WORD languageId, WORD sortId) {
        handle = MAKELCID(languageId, sortId);
    }

    /// 
    this(Language language, SortOrder sort) {
        handle = MAKELCID(language.handle, sort.handle);
    }

    // FIXME: templated instead of TCHAR[], some bug prevents me..
    this(const TCHAR[] name, bool allowNeutral=true) {
        auto namez = toWinStringz(name);
        if(!IsValidLocaleName(namez))
            throw new Win32Exception("Unknown locale " ~ name);
        _name = to!(typeof(_name))(name);
        DWORD flags = allowNeutral ? LOCALE_ALLOW_NEUTRAL_NAMES : 0;
        handle = winEnforce(LocaleNameToLCID(namez, flags));
    }

    /// 
    @property Language language() const {
        return Language(LANGIDFROMLCID(handle));
    }

    /// 
    @property SortOrder sortOrder() const {
        return SortOrder(SORTIDFROMLCID(handle));
    }

    /// 
    @property static Locale threadLocale() {
        return Locale(GetThreadLocale());
    }

    /// 
    @property static void threadLocale(Locale locale) {
        SetThreadLocale(locale.handle);
    }

    /// 
    @property static void threadLocale(const TCHAR[] localeName) {
        threadLocale = Locale(localeName);
    }

    /// 
    @property immutable(TCHAR[]) name()
    out(result) {
        assert(isValidLocale(result));
        assert(result == _name);
    } body {
        if(!_name) {
            auto len = LCIDToLocaleName(handle, null, 0, LOCALE_ALLOW_NEUTRAL_NAMES) - 1 /* exclude \0 */;
            if(!len) {
                assert(handle == 127,
                        "Non-invariant locale, "~to!string(handle)~", is missing locale name");
                _name = ""w; // idup doesn't append \0, so the string is still null
            } else {
                assert(len > 0);
                auto buf = new TCHAR[len];
                winEnforce(LCIDToLocaleName(handle, buf.ptr, len, LOCALE_ALLOW_NEUTRAL_NAMES));
                _name = assumeUnique(buf);
            }
        }
        assert(_name);
        return _name;
    }

    /// 
    private immutable(TCHAR[]) getInfo(LCTYPE request) {
        auto namez = toWinStringz(name);
        immutable len = winEnforce(GetLocaleInfoEx(namez, request, null, 0));
        auto buf = new TCHAR[len];
        winEnforce(GetLocaleInfoEx(namez, request, buf.ptr, len));
        return assumeUnique(buf[0..len-1/*exclude \0*/]);
    }

    /// 
    @property immutable(TCHAR[]) localizedDisplayName() {
        return getInfo(LOCALE_SLOCALIZEDDISPLAYNAME);
    }

    /// 
    @property immutable(TCHAR[]) localizedCountryName() {
        return getInfo(LOCALE_SLOCALIZEDCOUNTRYNAME);
    }

    /// 
    @property immutable(TCHAR[]) localizedLanguageName() {
        return getInfo(LOCALE_SLOCALIZEDLANGUAGENAME);
    }

    /// 
    @property immutable(TCHAR[]) nativeDisplayName() {
        return getInfo(LOCALE_SNATIVEDISPLAYNAME);
    }

    /// 
    @property immutable(TCHAR[]) nativeCountryName() {
        return getInfo(LOCALE_SNATIVECOUNTRYNAME);
    }

    /// 
    @property immutable(TCHAR[]) nativeLanguageName() {
        return getInfo(LOCALE_SNATIVELANGUAGENAME);
    }

    /// 
    @property immutable(TCHAR[]) displayName() {
        return getInfo(LOCALE_SENGLISHDISPLAYNAME);
    }

    /// 
    @property immutable(TCHAR[]) countryName() {
        return getInfo(LOCALE_SENGLISHCOUNTRYNAME);
    }

    /// 
    @property immutable(TCHAR[]) languageName() {
        return getInfo(LOCALE_SENGLISHLANGUAGENAME);
    }

    /// 
    static bool isValidLocale(C)(C[] locale) if(isSomeChar!C) {
        return cast(bool)IsValidLocaleName(toWinStringz(locale));
    }

    /// 
    @property static Locale[] systemLocales() {
        return Locale.getSystemLocales(LOCALE_ALL);
    }

    /// 
    static Locale[] getSystemLocales(DWORD flags) {
        extern(Windows) static BOOL getNext(LPWSTR localeName, DWORD flags, LPARAM param) {
            auto locales = cast(Locale[]*)param;
            (*locales) ~= Locale(fromWinStringz(localeName));
            return true;
        }

        Locale[] locales;
        locales.reserve(512);
        winEnforce(EnumSystemLocalesEx(&getNext, flags, cast(LPARAM)&locales, null/*reserved*/));
        return locales;
    }

    /// 
    @property static Locale invariantLocale() {
        return Locale(LOCALE_INVARIANT);
    }

    /// 
    @property static Locale systemDefault() {
        return Locale(LOCALE_SYSTEM_DEFAULT);
    }

    /// 
    @property immutable(TCHAR[]) percentSymbol() {
        return getInfo(LOCALE_SPERCENT);
    }

    /// 
    @property immutable(TCHAR[]) permilleSymbol() {
        return getInfo(LOCALE_SPERMILLE);
    }

    /// 
    @property immutable(TCHAR[]) decimalSymbol() {
        return getInfo(LOCALE_SDECIMAL);
    }

    /// 
    @property immutable(TCHAR[]) listSeparatorSymbol() {
        return getInfo(LOCALE_SLIST);
    }

    /// 
    @property immutable(TCHAR[]) currencySymbol() {
        return getInfo(LOCALE_SCURRENCY);
    }

    /// 
    @property immutable(TCHAR[]) monetaryDecimalSymbol() {
        return getInfo(LOCALE_SMONDECIMALSEP);
    }

    // FIXME!
    /// 
    @property immutable(TCHAR[]) monetaryDecimalGrouping() {
        return getInfo(LOCALE_SMONGROUPING);
    }

    /// 
    @property immutable(TCHAR[]) monetaryThousandSeparatorSymbol() {
        return getInfo(LOCALE_SMONTHOUSANDSEP);
    }

    /// 
    @property immutable(TCHAR[]) isoCountry() {
        return getInfo(LOCALE_SISO3166CTRYNAME2);
    }

    /// 
    @property immutable(TCHAR[]) isoLanguage() {
        return getInfo(LOCALE_SISO639LANGNAME2);
    }

    /// 
    @property immutable(TCHAR[]) shortTime() {
        return shortTimes[0];
    }

    /// 
    @property immutable(TCHAR[][]) shortTimes() {
        // HACK: splitter, array etc doesn't work well with immutable values
        // yet, so lets cast away
        immutable sep = ';';
        auto times = cast(TCHAR[])getInfo(LOCALE_SSHORTTIME);
        auto splitted = array(splitter(times, sep));
        return assumeUnique(splitted);
    }

    /// 
    @property immutable(TCHAR[]) longDate() {
        return getInfo(LOCALE_SLONGDATE);
    }

    /// 
    @property immutable(TCHAR[]) amSymbol() {
        return getInfo(LOCALE_S1159);
    }

    /// 
    @property immutable(TCHAR[]) pmSymbol() {
        return getInfo(LOCALE_S2359);
    }

    /// 
    @property Locale sortLocale() {
        return Locale(getInfo(LOCALE_SSORTLOCALE));
    }

    /// 
    @property immutable(TCHAR[]) posInfinitySymbol() {
        return getInfo(LOCALE_SPOSINFINITY);
    }

    /// 
    @property immutable(TCHAR[]) negInfinitySymbol() {
        return getInfo(LOCALE_SNEGINFINITY);
    }

    /// 
    @property immutable(TCHAR[]) nanSymbol() {
        return getInfo(LOCALE_SNAN);
    }

    /// 
    @property immutable(TCHAR[]) negativeSymbol() {
        return getInfo(LOCALE_SNEGATIVESIGN);
    }
}
unittest {
}
