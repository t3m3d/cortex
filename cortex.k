// cortex — a GUI file manager for Linux, in pure Krypton over raw X11.
// M3: graphical view — toolbar + folder/file icons + mouse select +
// double-click / Enter to open dirs, Backspace / ".." to go up, Esc quits.
//
//   Build/run:  KRYPTON_ROOT=<krypton> kcc -r cortex.k

import "k:x11"

// ── geometry / colors (24-bit TrueColor: pixel = R<<16 | G<<8 | B) ─────
func W()        { emit 880 }
func H()        { emit 560 }
func TOOLBAR()  { emit 36 }
func ROWH()     { emit 24 }
func ICONX()    { emit 12 }
func TEXTX()    { emit 40 }
func cWhite()   { emit 16777215 }   // 0xFFFFFF
func cBlack()   { emit 0 }
func cToolbar() { emit 14211288 }   // 0xD8E0E8 soft blue-grey
func cSel()     { emit 4101887 }    // 0x3E97FF selection blue
func cFolder()  { emit 15909198 }   // 0xF2C14E folder yellow
func cFile()    { emit 12434877 }   // 0xBDB7BD file grey

// ── small string helpers ──────────────────────────────────────────────
func nthLine(s, idx) {
    let n = len(s)
    let cur = 0
    let start = 0
    let i = 0
    while i < n {
        if s[i] == fromCharCode(10) {
            if cur == idx { emit substring(s, start, i) }
            cur += 1
            start = i + 1
        }
        i += 1
    }
    if cur == idx { emit substring(s, start, n) }
    emit ""
}
func countLines(s) {
    if s == "" { emit 0 }
    let n = len(s)
    let c = 0
    let i = 0
    while i < n {
        if s[i] == fromCharCode(10) { c += 1 }
        i += 1
    }
    // count a final non-empty line with no trailing newline
    if n > 0 && s[n - 1] != fromCharCode(10) { c += 1 }
    emit c
}

// ── directory model ───────────────────────────────────────────────────
// One entry per line, "d name" (dir) or "f name" (file). ".." prepended.
func buildEntries(cwd) {
    let raw = exec("ls -1Ap '" + cwd + "' 2>/dev/null")
    let out = "d ..\n"
    let line = ""
    let i = 0
    while i < len(raw) {
        let ch = raw[i]
        if ch == fromCharCode(10) {
            if line != "" {
                if line[len(line) - 1] == "/" {
                    out = out + "d " + substring(line, 0, len(line) - 1) + "\n"
                } else {
                    out = out + "f " + line + "\n"
                }
            }
            line = ""
        } else {
            line = line + ch
        }
        i += 1
    }
    emit out
}
func entryIsDir(entries, row) { emit nthLine(entries, row)[0] == "d" }
func entryName(entries, row)  { let l = nthLine(entries, row)  emit substring(l, 2, len(l)) }

func parentDir(cwd) {
    let i = len(cwd) - 1
    while i > 0 && cwd[i] != "/" { i = i - 1 }
    if i <= 0 { emit "/" }
    emit substring(cwd, 0, i)
}
func joinDir(cwd, name) {
    if cwd == "/" { emit "/" + name }
    emit cwd + "/" + name
}

// ── drawing ───────────────────────────────────────────────────────────
// Folder icon: yellow body + tab. File icon: grey page.
func drawFolder(fd, win, gcBody, x, y) {
    x11FillRect(fd, win, gcBody, x, y + 5, 20, 12)
    x11FillRect(fd, win, gcBody, x, y + 2, 9, 4)
}
func drawFile(fd, win, gcBody, x, y) {
    x11FillRect(fd, win, gcBody, x + 3, y + 3, 14, 15)
}

// GC/window resource ids are deterministic (x11GenId(info, n)), so recompute
// them here instead of threading a struct through (struct int fields don't
// round-trip on the Linux native backend).
func repaint(fd, info, cwd, entries, sel) {
    let win = x11GenId(info, 1)
    let gcClear = x11GenId(info, 3)
    let gcBar = x11GenId(info, 4)
    let gcPath = x11GenId(info, 5)
    let gcRow = x11GenId(info, 6)
    let gcSel = x11GenId(info, 7)
    let gcSelFill = x11GenId(info, 8)
    let gcFolder = x11GenId(info, 9)
    let gcFile = x11GenId(info, 10)

    // clear whole window white, then toolbar
    x11FillRect(fd, win, gcClear, 0, 0, W(), H())
    x11FillRect(fd, win, gcBar, 0, 0, W(), TOOLBAR())
    x11ImageText8(fd, win, gcPath, 10, 24, cwd)

    let nrows = countLines(entries)
    let i = 0
    while i < nrows {
        let y = TOOLBAR() + i * ROWH()
        let isDir = entryIsDir(entries, i)
        let name = entryName(entries, i)
        let textGc = gcRow
        if i == sel {
            x11FillRect(fd, win, gcSelFill, 0, y, W(), ROWH())
            textGc = gcSel
        }
        if isDir { drawFolder(fd, win, gcFolder, ICONX(), y) }
        else { drawFile(fd, win, gcFile, ICONX(), y) }
        x11ImageText8(fd, win, textGc, TEXTX(), y + 17, name)
        i += 1
    }
}

just run {
    let fd = x11ConnectUnix(1)
    if fd < 0 { print("cortex: cannot connect to X display :1"); exit(1) }
    let info = x11Handshake(fd)
    if !x11Accepted(info) { print("cortex: handshake refused"); sockClose(fd); exit(1) }

    let root = x11Root(info)
    let win = x11GenId(info, 1)
    x11CreateWindow(fd, win, root, 80, 80, W(), H(), cWhite(), 32773)  // Expose|KeyPress|ButtonPress

    let font = x11GenId(info, 2)
    x11OpenFont(fd, font, "fixed")

    // one GC per color (backend has no ChangeGC; cheap to pre-create)
    let gcClear   = x11GenId(info, 3)   x11CreateGC(fd, gcClear,   win, cWhite(),  cWhite(), font)
    let gcBar     = x11GenId(info, 4)   x11CreateGC(fd, gcBar,     win, cToolbar(),cToolbar(),font)
    let gcPath    = x11GenId(info, 5)   x11CreateGC(fd, gcPath,    win, cBlack(),  cToolbar(),font)
    let gcRow     = x11GenId(info, 6)   x11CreateGC(fd, gcRow,     win, cBlack(),  cWhite(), font)
    let gcSel     = x11GenId(info, 7)   x11CreateGC(fd, gcSel,     win, cWhite(),  cSel(),   font)
    let gcSelFill = x11GenId(info, 8)   x11CreateGC(fd, gcSelFill, win, cSel(),    cSel(),   font)
    let gcFolder  = x11GenId(info, 9)   x11CreateGC(fd, gcFolder,  win, cFolder(), cWhite(), font)
    let gcFile    = x11GenId(info, 10)  x11CreateGC(fd, gcFile,    win, cFile(),   cWhite(), font)

    x11MapWindow(fd, win)

    let cwd = exec("pwd")
    while len(cwd) > 0 && cwd[len(cwd) - 1] == fromCharCode(10) { cwd = substring(cwd, 0, len(cwd) - 1) }
    let entries = buildEntries(cwd)
    let sel = 0
    let lastRow = 0 - 1
    let lastTime = 0

    let ev = bufNew(32)
    let running = 1
    while running == 1 {
        let n = x11NextEvent(fd, ev)
        if n <= 0 { running = 0 }
        else {
            let t = x11EventType(ev)
            if t == 12 {
                repaint(fd, info, cwd, entries, sel)
            } else if t == 4 {
                // ButtonPress: pick row, select; double-click opens dirs.
                let ey = x11EventY(ev)
                let time = bufGetDwordAt(ev, 4)
                if ey >= TOOLBAR() {
                    let row = (ey - TOOLBAR()) / ROWH()
                    if row < countLines(entries) {
                        let dbl = row == lastRow && time - lastTime < 400
                        sel = row
                        if dbl && entryIsDir(entries, row) {
                            let name = entryName(entries, row)
                            if name == ".." { cwd = parentDir(cwd) }
                            else { cwd = joinDir(cwd, name) }
                            entries = buildEntries(cwd)
                            sel = 0
                        }
                        lastRow = row
                        lastTime = time
                        repaint(fd, info, cwd, entries, sel)
                    }
                }
            } else if t == 2 {
                // KeyPress: Esc(9) quit, Enter(36) open, Backspace(22) up,
                // Up(111)/Down(116) move selection.
                let kc = x11KeyDetail(ev)
                if kc == 9 { running = 0 }
                else if kc == 36 {
                    if entryIsDir(entries, sel) {
                        let name = entryName(entries, sel)
                        if name == ".." { cwd = parentDir(cwd) } else { cwd = joinDir(cwd, name) }
                        entries = buildEntries(cwd)
                        sel = 0
                    }
                    repaint(fd, info, cwd, entries, sel)
                }
                else if kc == 22 { cwd = parentDir(cwd)  entries = buildEntries(cwd)  sel = 0  repaint(fd, info, cwd, entries, sel) }
                else if kc == 116 { if sel + 1 < countLines(entries) { sel += 1 }  repaint(fd, info, cwd, entries, sel) }
                else if kc == 111 { if sel > 0 { sel = sel - 1 }  repaint(fd, info, cwd, entries, sel) }
            } else if t == 0 {
                print("cortex: X error code=" + bufGetByte(ev, 1) + " seq=" + bufGetWordAt(ev, 2) + " badval=" + bufGetDwordAt(ev, 4) + " minor=" + bufGetWordAt(ev, 8) + " major=" + bufGetByte(ev, 10) + " b0=" + bufGetByte(ev, 0))
                running = 0
            } else {
                print("cortex: event type=" + t)
            }
        }
    }
    sockClose(fd)
}
