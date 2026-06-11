// cortex — a GUI file manager for Linux, in pure Krypton over raw X11.
// M1: open a window on the local display and run an event loop.
//
//   Build/run:  KRYPTON_ROOT=<krypton> kcc -r cortex.k
//   (needs an X/Xwayland display at $DISPLAY; connects via the unix socket.)

import "k:x11"

just run {
    // Connect to the local display (DISPLAY=:N -> /tmp/.X11-unix/XN).
    let fd = x11ConnectUnix(1)
    if fd < 0 {
        print("cortex: cannot connect to X display :1")
        exit(1)
    }
    let info = x11Handshake(fd)
    if !x11Accepted(info) {
        print("cortex: X handshake refused: " + x11FailReason(info))
        sockClose(fd)
        exit(1)
    }

    let root = x11Root(info)
    let white = x11WhitePixel(info)
    let black = x11BlackPixel(info)
    print("cortex: connected — root=" + root + " screen=" + x11ScreenWidth(info) + "x" + x11ScreenHeight(info))

    let win = x11GenId(info, 1)
    // event-mask: Expose(0x8000) | KeyPress(0x1) | ButtonPress(0x4) = 0x8005
    x11CreateWindow(fd, win, root, 100, 100, 720, 480, white, 32773)
    x11MapWindow(fd, win)
    print("cortex: window mapped (" + win + ") — press any key in it to quit")

    // Event loop.
    let ev = bufNew(32)
    let running = 1
    while running == 1 {
        let n = x11NextEvent(fd, ev)
        if n <= 0 { running = 0 }
        else {
            let t = x11EventType(ev)
            if t == 12 { print("cortex: Expose") }
            else if t == 2 { print("cortex: KeyPress -> quit"); running = 0 }
            else if t == 4 { print("cortex: ButtonPress @ " + x11EventX(ev) + "," + x11EventY(ev)) }
            else if t == 0 {
                print("cortex: X error code=" + bufGetByte(ev, 1) + " badval=" + bufGetDwordAt(ev, 4) + " minor=" + bufGetWordAt(ev, 8) + " major=" + bufGetByte(ev, 10))
                running = 0
            }
        }
    }
    sockClose(fd)
    print("cortex: bye")
}
