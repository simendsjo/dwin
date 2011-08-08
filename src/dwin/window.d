/++
Window

See_Also:

License: $(BOOST)
Authors: $(SIMENDSJO)
Source: $(MODULE_SOURCE_LINK)
++/
module dwin.window;

import dwin.core;
import dwin.error;

import win32.winuser;

/++
++/
struct Window {
    immutable HWND handle;
    private bool _destroyed;

    invariant() {
        assert(handle);
        assert(!_destroyed && (_destroyed || IsWindow(handle)),
            "Win32 window handle is destroyed");
    }

    /++
    ++/
    this(HWND window) {
        handle = window;
    }

    /++
    ++/
    this(
        DWORD dwExStyle,
        LPCTSTR lpClassName,
        LPCTSTR lpWindowName,
        DWORD dwStyle,
        int x, int y,
        int nWidth, int nHeight,
        HWND hWndParent,
        HMENU hMenu,
        HINSTANCE hInstance,
        LPVOID lpParam)
    {
        handle = winEnforce(
            CreateWindowEx(dwExStyle, lpClassName,
                lpWindowName, dwStyle, x, y, nWidth, nHeight, hWndParent,
                hMenu, hInstance, lpParam));
    }

    /// 
    bool showWindow(DWORD state) {
        return cast(bool)ShowWindow(handle, state);
    }

    /// 
    void show() {
        showWindow(SW_SHOW);
    }

    /// 
    void hide() {
        showWindow(SW_HIDE);
    }

    /// 
    void minimize() {
        showWindow(SW_MINIMIZE);
    }

    /// 
    void maximize() {
        showWindow(SW_MAXIMIZE);
    }

    /// 
    void restore() {
        winEnforce(OpenIcon(handle));
    }

    /// 
    void move(int x, int y, int w, int h, bool redraw) {
        winEnforce(MoveWindow(handle, x, y, w, h, redraw));
    }

    /// 
    bool visible() {
        return cast(bool)IsWindowVisible(handle);
    }

    /// 
    bool minimized() {
        return cast(bool)IsIconic(handle);
    }

    /// 
    void destroy() {
        winEnforce(DestroyWindow(handle));
        _destroyed = true;
    }

    /// 
    void update() {
        winEnforce(UpdateWindow(handle));
    }

    /// 
    bool isAncestorOf(Window child) {
        return !IsChild(handle, child.handle);
    }

    /// 
    bool isDescendantOf(Window parent) {
        return cast(bool)IsChild(parent.handle, handle);
    }

    /// 
    Window getAncestor(UINT flags) {
        return Window(GetAncestor(handle, flags));
    }

    /// 
    @property Window ancestorRoot() {
        return getAncestor(GA_ROOT);
    }

    /// 
    @property Window ancestorParent() {
        return getAncestor(GA_PARENT);
    }

    /// 
    @property Window ancestorRootOwner() {
        return getAncestor(GA_ROOTOWNER);
    }

    /// 
    @property Window parent() {
        return Window(GetParent(handle));
    }

    /// 
    @property RECT clientRect() {
        RECT rect;
        winEnforce(GetClientRect(handle, &rect));
        return rect;
    }

    /// 
    static @property Window desktopWindow() {
        return Window(GetDesktopWindow());
    }

    /// 
    static @property Window shellWindow() {
        return Window(GetShellWindow());
    }

    /// 
    void bringToTop() {
        winEnforce(BringWindowToTop(handle));
    }

    /// 
    static @property bool anyPopup() {
        return cast(bool)AnyPopup();
    }

    /// 
    static @property Window foreGroundWindow() {
        return Window(GetForegroundWindow());
    }

    /// 
    @property Window lastActivePopup() {
        return Window(GetLastActivePopup(handle));
    }

    /// 
    @property Window topWindow() {
        return Window(winEnforce(GetTopWindow(handle)));
    }

    /// 
    @property bool isHungAppWindow() {
        return cast(bool)IsHungAppWindow(handle);
    }

    /// 
    @property bool isZoomed() {
        return cast(bool)IsZoomed(handle);
    }

    /// 
    static @property bool isGUIThread() {
        return cast(bool)IsGUIThread(false);
    }

    /// 
    static void setGUIThread() {
        if(!isGUIThread) {
            winEnforce(IsGUIThread(true));
        }
    }

    /// 
    static Window windowFromPoint(POINT point) {
        return Window(WindowFromPoint(point));
    }

    /// 
    Window childWindowFromPoint(POINT point) {
        return Window(ChildWindowFromPoint(handle, point));
    }

    /// 
    Window realChildWindowFromPoint(POINT point) {
        return Window(RealChildWindowFromPoint(handle, point));
    }

    /// 
    @property void text(Char)(const(Char[]) caption) {
        winEnforce(SetWindowText(handle, toWinStringz(caption)));
    }
}
