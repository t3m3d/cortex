// cortex — a GUI file manager for Linux, in pure Krypton over raw X11.
// M4: left "quick access" sidebar (default places + user bookmarks) beside
// the main file view. Double-click / Enter opens dirs, Backspace / ".." up,
// 'b' bookmarks the current dir, Esc quits.
//
//   Build/run:  KRYPTON_ROOT=<krypton> kcc -r cortex.k

import "k:x11"

// ── geometry / colors (24-bit TrueColor: pixel = R<<16 | G<<8 | B) ─────
func W()         { emit 980 }
func H()         { emit 600 }
func TOOLBAR()   { emit 36 }
func ROWH()      { emit 24 }
func SIDEBAR()   { emit 190 }
func ICONX()     { emit 12 }
func cWhite()    { emit 16777215 }   // 0xFFFFFF
func cBlack()    { emit 0 }
func cToolbar()  { emit 14211288 }   // 0xD8E0E8
func cSide()     { emit 15660020 }   // 0xEEF1F4 sidebar bg
func cDivider()  { emit 13160660 }   // 0xC8CED4
func cSel()      { emit 4101887 }    // 0x3E97FF
func cFolder()   { emit 15909198 }   // 0xF2C14E (fallback rect)
func cFile()     { emit 12434877 }   // 0xBDB7BD (fallback rect)
func cSelLite()  { emit 14478847 }   // 0xDCE9FF light selection (grid)
func ICONSML()   { emit 20 }         // sidebar icon
func ICONBIG()   { emit 96 }         // main-grid icon
func CELLW()     { emit 160 }
func CELLH()     { emit 150 }
func GRIDPAD()   { emit 16 }
func charW()     { emit 6 }          // "fixed" font advance

// ── custom cortex icons (edit these SVGs to restyle — distinct on purpose) ─
// Indigo rounded folder; white page-with-fold + indigo accent. Rasterized at
// runtime via ImageMagick (convert) to raw BGRA, alpha-composited onto each
// row background, blitted with x11PutImage.
func folderSvg() {
    emit "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24'>" +
         "<path d='M2 7 a2 2 0 0 1 2-2 h5 l2 2 h9 a2 2 0 0 1 2 2 v8 a2 2 0 0 1 -2 2 H4 a2 2 0 0 1 -2-2 z' fill='#5B4FE0'/>" +
         "<path d='M2 10 h20 v7 a2 2 0 0 1 -2 2 H4 a2 2 0 0 1 -2-2 z' fill='#7C71F2'/></svg>"
}
func fileSvg() {
    emit "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24'>" +
         "<path d='M5 3 a1 1 0 0 1 1-1 h8 l5 5 v14 a1 1 0 0 1 -1 1 H6 a1 1 0 0 1 -1-1 z' fill='#ffffff' stroke='#C7C7D6'/>" +
         "<path d='M14 2 v5 a1 1 0 0 0 1 1 h4' fill='none' stroke='#C7C7D6'/>" +
         "<rect x='8' y='12' width='8' height='1.6' rx='0.8' fill='#5B4FE0'/>" +
         "<rect x='8' y='15' width='6' height='1.6' rx='0.8' fill='#9AA0AE'/></svg>"
}

func hexNyb(c) {
    if c >= "0" && c <= "9" { emit charCode(c) - 48 }
    emit charCode(c) - 87   // a-f -> 10-15
}
func hexToBuf(hex, nbytes) {
    let b = bufNew(nbytes)
    let i = 0
    while i < nbytes {
        bufSetByte(b, i, hexNyb(hex[i * 2]) * 16 + hexNyb(hex[i * 2 + 1]))
        i += 1
    }
    emit b
}
// Rasterize an embedded SVG to BGRA hex at size `sz`, regenerated each launch
// so edits show immediately. Goes via a cache file (big-icon hex is large;
// readFile of hex text is NUL-safe). Returns the hex string ("" on failure).
// len() works on the string (len() on a buf always returns 0).
func rasterHex(name, svg, sz) {
    let dir = homeDir() + "/.cache/cortex"
    exec("mkdir -p '" + dir + "'")
    let svgf = dir + "/" + name + ".svg"
    let hexf = dir + "/" + name + "-" + sz + ".hex"
    writeFile(svgf, svg)
    // -density sz*4 renders the 24px-viewBox SVG natively at `sz` (crisp),
    // instead of rasterizing at 24 and upscaling (soft).
    exec("convert -background none -density " + (sz * 4) + " '" + svgf + "' -resize " + sz + "x" + sz + " -depth 8 BGRA:- 2>/dev/null | xxd -p -c 0 > '" + hexf + "'")
    emit chomp(readFile(hexf))
}
func iconBytes(sz) { emit sz * sz * 4 }

// Alpha-composite raw BGRA (sz x sz) over a solid bg pixel into `scratch`
// (BGRX), then blit.
func blitIcon(fd, win, gc, x, y, raw, scratch, bg, sz) {
    let bgB = bg - bg / 256 * 256
    let bgG = bg / 256 - bg / 65536 * 256
    let bgR = bg / 65536 - bg / 65536 / 256 * 256
    let npx = sz * sz
    let i = 0
    while i < npx {
        let o = i * 4
        let a = bufGetByte(raw, o + 3)
        let ia = 255 - a
        bufSetByte(scratch, o,     (bufGetByte(raw, o) * a + bgB * ia) / 255)
        bufSetByte(scratch, o + 1, (bufGetByte(raw, o + 1) * a + bgG * ia) / 255)
        bufSetByte(scratch, o + 2, (bufGetByte(raw, o + 2) * a + bgR * ia) / 255)
        bufSetByte(scratch, o + 3, 0)
        i += 1
    }
    x11PutImage(fd, win, gc, x, y, sz, sz, scratch)
}

// grid columns that fit the main pane at window width w (>=1)
func gridCols(w) {
    let c = (w - SIDEBAR() - 2 * GRIDPAD()) / CELLW()
    if c < 1 { emit 1 }
    emit c
}
// clip a label to the cell width ("fixed" font is charW px/char)
func clipLabel(name) {
    let max = (CELLW() - 6) / charW()
    if len(name) <= max { emit name }
    emit substring(name, 0, max - 1) + "."
}

// ── string helpers ─────────────────────────────────────────────────────
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
    if n > 0 && s[n - 1] != fromCharCode(10) { c += 1 }
    emit c
}
func basename(p) {
    let i = len(p) - 1
    while i >= 0 && p[i] != "/" { i = i - 1 }
    emit substring(p, i + 1, len(p))
}
// field before / after the first '|' in "label|path"
func beforeBar(s) {
    let i = 0
    while i < len(s) && s[i] != "|" { i += 1 }
    emit substring(s, 0, i)
}
func afterBar(s) {
    let i = 0
    while i < len(s) && s[i] != "|" { i += 1 }
    emit substring(s, i + 1, len(s))
}
func chomp(s) {
    let p = s
    while len(p) > 0 && p[len(p) - 1] == fromCharCode(10) { p = substring(p, 0, len(p) - 1) }
    emit p
}

// ── places (quick-access sidebar) ──────────────────────────────────────
func homeDir() { emit chomp(exec("printf %s \"$HOME\"")) }
func existsDir(p) { emit chomp(exec("test -d '" + p + "' && echo y")) == "y" }
func bookmarksPath() { emit homeDir() + "/.config/cortex/bookmarks" }

func addPlace(out, label, path) { emit out + label + "|" + path + "\n" }
func maybeAdd(out, label, path) {
    if existsDir(path) { emit addPlace(out, label, path) }
    emit out
}

// Build "label|path" lines: defaults that exist, then saved bookmarks.
func buildPlaces() {
    let home = homeDir()
    let out = addPlace("", "Home", home)
    out = maybeAdd(out, "Desktop", home + "/Desktop")
    out = maybeAdd(out, "Documents", home + "/Documents")
    out = maybeAdd(out, "Downloads", home + "/Downloads")
    out = maybeAdd(out, "Pictures", home + "/Pictures")
    out = maybeAdd(out, "Music", home + "/Music")
    out = maybeAdd(out, "Videos", home + "/Videos")
    out = addPlace(out, "Filesystem", "/")
    // user bookmarks (one path per line)
    let bm = readFile(bookmarksPath())
    let i = 0
    let line = ""
    while i < len(bm) {
        let ch = bm[i]
        if ch == fromCharCode(10) {
            if line != "" && existsDir(line) { out = addPlace(out, basename(line), line) }
            line = ""
        } else { line = line + ch }
        i += 1
    }
    if line != "" && existsDir(line) { out = addPlace(out, basename(line), line) }
    emit out
}
func placeLabel(places, row) { emit beforeBar(nthLine(places, row)) }
func placePath(places, row)  { emit afterBar(nthLine(places, row)) }

func addBookmark(cwd) {
    exec("mkdir -p \"$(dirname '" + bookmarksPath() + "')\"")
    exec("echo '" + cwd + "' >> '" + bookmarksPath() + "'")
}

// ── directory model ────────────────────────────────────────────────────
func buildEntries(cwd) {
    let raw = exec("ls -1Ap '" + cwd + "' 2>/dev/null")
    let out = "d ..\n"
    let line = ""
    let i = 0
    while i < len(raw) {
        let ch = raw[i]
        if ch == fromCharCode(10) {
            if line != "" {
                if line[len(line) - 1] == "/" { out = out + "d " + substring(line, 0, len(line) - 1) + "\n" }
                else { out = out + "f " + line + "\n" }
            }
            line = ""
        } else { line = line + ch }
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

// ── drawing ────────────────────────────────────────────────────────────
func drawFolder(fd, win, gc, x, y) {
    x11FillRect(fd, win, gc, x, y + 5, 20, 12)
    x11FillRect(fd, win, gc, x, y + 2, 9, 4)
}
func drawFile(fd, win, gc, x, y) {
    x11FillRect(fd, win, gc, x + 3, y + 3, 14, 15)
}

func repaint(fd, info, cwd, entries, sel, places, w, h, folderSml, folderBig, fileBig, scratch, haveIcons) {
    let win = x11GenId(info, 1)
    let gcClear = x11GenId(info, 3)
    let gcBar = x11GenId(info, 4)
    let gcPath = x11GenId(info, 5)
    let gcRow = x11GenId(info, 6)
    let gcFolder = x11GenId(info, 9)
    let gcFile = x11GenId(info, 10)
    let gcSide = x11GenId(info, 11)
    let gcSideTx = x11GenId(info, 12)
    let gcDiv = x11GenId(info, 13)
    let gcSelBox = x11GenId(info, 14)
    let gcLblSel = x11GenId(info, 15)

    // chrome — sized to the live window (ConfigureNotify), so the sidebar
    // reaches the bottom at any size.
    x11FillRect(fd, win, gcClear, 0, 0, w, h)
    x11FillRect(fd, win, gcSide, 0, TOOLBAR(), SIDEBAR(), h - TOOLBAR())
    x11FillRect(fd, win, gcBar, 0, 0, w, TOOLBAR())
    x11FillRect(fd, win, gcDiv, SIDEBAR(), TOOLBAR(), 1, h - TOOLBAR())
    x11ImageText8(fd, win, gcPath, 10, 24, cwd + "      [b]ookmark  [bksp]up  [esc]quit")

    // sidebar list (small icons)
    x11ImageText8(fd, win, gcSideTx, 12, TOOLBAR() + 17, "Quick access")
    let np = countLines(places)
    let p = 0
    while p < np {
        let y = TOOLBAR() + (p + 1) * ROWH()
        if haveIcons == 1 { blitIcon(fd, win, gcRow, 10, y + 2, folderSml, scratch, cSide(), ICONSML()) }
        else { drawFolder(fd, win, gcFolder, 10, y) }
        x11ImageText8(fd, win, gcSideTx, 36, y + 17, placeLabel(places, p))
        p += 1
    }

    // main pane: icon grid with the name centred under each icon
    let bx = SIDEBAR()
    let cols = gridCols(w)
    let nrows = countLines(entries)
    let i = 0
    while i < nrows {
        let col = i - i / cols * cols
        let rowi = i / cols
        let cx = bx + GRIDPAD() + col * CELLW()
        let cy = TOOLBAR() + GRIDPAD() + rowi * CELLH()
        let bg = cWhite()
        let lblGc = gcRow
        if i == sel {
            x11FillRect(fd, win, gcSelBox, cx, cy, CELLW() - 8, CELLH() - 8)
            bg = cSelLite()
            lblGc = gcLblSel
        }
        let ix = cx + (CELLW() - ICONBIG()) / 2
        let iy = cy + 8
        if haveIcons == 1 {
            if entryIsDir(entries, i) { blitIcon(fd, win, gcRow, ix, iy, folderBig, scratch, bg, ICONBIG()) }
            else { blitIcon(fd, win, gcRow, ix, iy, fileBig, scratch, bg, ICONBIG()) }
        } else {
            if entryIsDir(entries, i) { drawFolder(fd, win, gcFolder, ix, iy) }
            else { drawFile(fd, win, gcFile, ix, iy) }
        }
        let disp = clipLabel(entryName(entries, i))
        let lx = cx + (CELLW() - len(disp) * charW()) / 2
        x11ImageText8(fd, win, lblGc, lx, cy + 8 + ICONBIG() + 16, disp)
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
    // event-mask: Expose(0x8000)|KeyPress(0x1)|ButtonPress(0x4)|
    // StructureNotify(0x20000) = 0x28005 = 163845 (StructureNotify -> resize).
    x11CreateWindow(fd, win, root, 80, 60, W(), H(), cWhite(), 163845)

    let font = x11GenId(info, 2)
    x11OpenFont(fd, font, "fixed")

    let gcClear   = x11GenId(info, 3)   x11CreateGC(fd, gcClear,   win, cWhite(),   cWhite(),  font)
    let gcBar     = x11GenId(info, 4)   x11CreateGC(fd, gcBar,     win, cToolbar(), cToolbar(),font)
    let gcPath    = x11GenId(info, 5)   x11CreateGC(fd, gcPath,    win, cBlack(),   cToolbar(),font)
    let gcRow     = x11GenId(info, 6)   x11CreateGC(fd, gcRow,     win, cBlack(),   cWhite(),  font)
    let gcSel     = x11GenId(info, 7)   x11CreateGC(fd, gcSel,     win, cWhite(),   cSel(),    font)
    let gcSelFill = x11GenId(info, 8)   x11CreateGC(fd, gcSelFill, win, cSel(),     cSel(),    font)
    let gcFolder  = x11GenId(info, 9)   x11CreateGC(fd, gcFolder,  win, cFolder(),  cWhite(),  font)
    let gcFile    = x11GenId(info, 10)  x11CreateGC(fd, gcFile,    win, cFile(),    cWhite(),  font)
    let gcSide    = x11GenId(info, 11)  x11CreateGC(fd, gcSide,    win, cSide(),    cSide(),   font)
    let gcSideTx  = x11GenId(info, 12)  x11CreateGC(fd, gcSideTx,  win, cBlack(),   cSide(),   font)
    let gcDiv     = x11GenId(info, 13)  x11CreateGC(fd, gcDiv,     win, cDivider(), cDivider(),font)
    let gcSelBox  = x11GenId(info, 14)  x11CreateGC(fd, gcSelBox,  win, cSelLite(), cSelLite(),font)
    let gcLblSel  = x11GenId(info, 15)  x11CreateGC(fd, gcLblSel,  win, cBlack(),   cSelLite(),font)

    x11MapWindow(fd, win)

    // icons at two sizes: small (sidebar) + big (main grid)
    let sml = ICONSML()
    let big = ICONBIG()
    let folderSmlHex = rasterHex("folder", folderSvg(), sml)
    let folderBigHex = rasterHex("folder", folderSvg(), big)
    let fileBigHex   = rasterHex("file", fileSvg(), big)
    let haveIcons = 0
    let folderSml = bufNew(iconBytes(sml))
    let folderBig = bufNew(iconBytes(big))
    let fileBig   = bufNew(iconBytes(big))
    if len(folderSmlHex) >= iconBytes(sml) * 2 && len(folderBigHex) >= iconBytes(big) * 2 && len(fileBigHex) >= iconBytes(big) * 2 {
        haveIcons = 1
        folderSml = hexToBuf(folderSmlHex, iconBytes(sml))
        folderBig = hexToBuf(folderBigHex, iconBytes(big))
        fileBig   = hexToBuf(fileBigHex, iconBytes(big))
    }
    let scratch = bufNew(iconBytes(big))

    let cwd = chomp(exec("pwd"))
    let entries = buildEntries(cwd)
    let places = buildPlaces()
    let sel = 0
    let lastRow = 0 - 1
    let lastTime = 0
    let curW = W()
    let curH = H()

    let ev = bufNew(32)
    let running = 1
    while running == 1 {
        let n = x11NextEvent(fd, ev)
        if n <= 0 { running = 0 }
        else {
            let t = x11EventType(ev)
            if t == 12 {
                repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons)
            } else if t == 22 {
                // ConfigureNotify: window resized — width@20, height@22.
                curW = x11EventWidth(ev)
                curH = x11EventHeight(ev)
                repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons)
            } else if t == 4 {
                let ex = x11EventX(ev)
                let ey = x11EventY(ev)
                let time = bufGetDwordAt(ev, 4)
                if ey >= TOOLBAR() {
                    if ex < SIDEBAR() {
                        // sidebar: row 0 is the header, places follow
                        let pr = (ey - TOOLBAR()) / ROWH() - 1
                        if pr >= 0 && pr < countLines(places) {
                            cwd = placePath(places, pr)
                            entries = buildEntries(cwd)
                            sel = 0
                            repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons)
                        }
                    } else {
                        // main grid hit-test
                        let cols = gridCols(curW)
                        let col = (ex - SIDEBAR() - GRIDPAD()) / CELLW()
                        let rowi = (ey - TOOLBAR() - GRIDPAD()) / CELLH()
                        let idx = rowi * cols + col
                        if col >= 0 && col < cols && idx >= 0 && idx < countLines(entries) {
                            let dbl = idx == lastRow && time - lastTime < 400
                            sel = idx
                            if dbl && entryIsDir(entries, idx) {
                                let name = entryName(entries, idx)
                                if name == ".." { cwd = parentDir(cwd) } else { cwd = joinDir(cwd, name) }
                                entries = buildEntries(cwd)
                                sel = 0
                            }
                            lastRow = idx
                            lastTime = time
                            repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons)
                        }
                    }
                }
            } else if t == 2 {
                let kc = x11KeyDetail(ev)
                if kc == 9 { running = 0 }                                  // Esc
                else if kc == 36 {                                          // Enter
                    if entryIsDir(entries, sel) {
                        let name = entryName(entries, sel)
                        if name == ".." { cwd = parentDir(cwd) } else { cwd = joinDir(cwd, name) }
                        entries = buildEntries(cwd)
                        sel = 0
                    }
                    repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons)
                }
                else if kc == 22 { cwd = parentDir(cwd)  entries = buildEntries(cwd)  sel = 0  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons) }   // Backspace
                else if kc == 56 { addBookmark(cwd)  places = buildPlaces()  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons) }                     // 'b'
                else if kc == 116 { let c = gridCols(curW)  if sel + c < countLines(entries) { sel = sel + c }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons) }   // Down (row)
                else if kc == 111 { let c = gridCols(curW)  if sel - c >= 0 { sel = sel - c }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons) }                   // Up (row)
                else if kc == 114 { if sel + 1 < countLines(entries) { sel += 1 }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons) }               // Right
                else if kc == 113 { if sel > 0 { sel = sel - 1 }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons) }                               // Left
            } else if t == 0 {
                print("cortex: X error code=" + bufGetByte(ev, 1) + " major=" + bufGetByte(ev, 10))
                running = 0
            }
        }
    }
    sockClose(fd)
}
