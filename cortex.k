// cortex — a GUI file manager for Linux, in pure Krypton over raw X11.
// M2: open a window and draw the current directory's entries as text.
//
//   Build/run:  KRYPTON_ROOT=<krypton> kcc -r cortex.k
//   (needs an X/Xwayland display; connects via the unix socket.)

import "k:x11"
import "k:fsx"

// Draw `text` clipped to one line at row `row` (0-based), black on white.
func drawRow(fd, win, gc, row, text) {
    x11ImageText8(fd, win, gc, 8, 24 + row * 16, text)
}

// Repaint: white background, cwd header, then one entry per row.
func repaint(fd, win, gc, bgGc, cwd) {
    x11FillRect(fd, win, bgGc, 0, 0, 720, 480)
    drawRow(fd, win, gc, 0, "cortex  " + cwd)
    drawRow(fd, win, gc, 1, "----------------------------------------")
    let listing = listDir(cwd)
    let row = 2
    let line = ""
    let i = 0
    while i < len(listing) {
        let ch = listing[i]
        if ch == fromCharCode(10) {
            if line != "" { drawRow(fd, win, gc, row, line)  row += 1 }
            line = ""
        } else {
            line = line + ch
        }
        i += 1
    }
    if line != "" { drawRow(fd, win, gc, row, line) }
}

func cwdOf() {
    let p = exec("pwd")
    // strip trailing newline
    while len(p) > 0 && p[len(p) - 1] == fromCharCode(10) { p = substring(p, 0, len(p) - 1) }
    emit p
}

just run {
    let fd = x11ConnectUnix(1)
    if fd < 0 { print("cortex: cannot connect to X display :1"); exit(1) }
    let info = x11Handshake(fd)
    if !x11Accepted(info) { print("cortex: handshake refused: " + x11FailReason(info)); sockClose(fd); exit(1) }

    let root = x11Root(info)
    let white = x11WhitePixel(info)
    let black = x11BlackPixel(info)

    let win = x11GenId(info, 1)
    x11CreateWindow(fd, win, root, 100, 100, 720, 480, white, 32773)  // Expose|KeyPress|ButtonPress

    let font = x11GenId(info, 2)
    x11OpenFont(fd, font, "fixed")
    let gc = x11GenId(info, 3)
    x11CreateGC(fd, gc, win, black, white, font)   // text: black on white
    let bgGc = x11GenId(info, 4)
    x11CreateGC(fd, bgGc, win, white, white, font) // background fill

    x11MapWindow(fd, win)
    let cwd = cwdOf()
    print("cortex: listing " + cwd)

    let ev = bufNew(32)
    let running = 1
    while running == 1 {
        let n = x11NextEvent(fd, ev)
        if n <= 0 { running = 0 }
        else {
            let t = x11EventType(ev)
            if t == 12 { repaint(fd, win, gc, bgGc, cwd) }       // Expose
            else if t == 2 { running = 0 }                        // KeyPress -> quit
            else if t == 0 { print("cortex: X error code=" + bufGetByte(ev, 1) + " major=" + bufGetByte(ev, 10)); running = 0 }
        }
    }
    sockClose(fd)
}
