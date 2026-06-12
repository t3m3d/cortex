// cortex_wl — native Wayland build of cortex (no Xwayland, no libwayland).
// M6a: window + file grid drawn with the wayland.k framebuffer + embedded font,
// keyboard navigation, live resize. Shares cortex's green look. Icons are drawn
// with fb primitives here; SVG-raster blit (fbBlitBGRA) lands in M6b.
import "k:wayland"

// ── colors (0xRRGGBB) ───────────────────────────────────────────────────────
func cBg()    { emit 1973792 }   // #1e1e20
func cHdr()   { emit 2829358 }   // #2b2b2e
func cSide()  { emit 2368038 }   // #242426
func cText()  { emit 15263976 }  // #e8e8e9
func cMuted() { emit 8949625 }   // #889099
func cSel()   { emit 1985612 }   // #1e484c-ish soft green
func cGreenA(){ emit 2073699 }   // #1FA463
func cGreenB(){ emit 3722372 }   // #38CE84
func cLine()  { emit 1184275 }   // #121213 subtle pane divider

func chomp(s) {
    let p = s
    while len(p) > 0 && p[len(p) - 1] == fromCharCode(10) { p = substring(p, 0, len(p) - 1) }
    emit p
}
// countLines / nthLine are cortex.k helpers (NOT builtins) — copy them.
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
// global-name finder (defined before just-run; Krypton wants define-before-use)
func _wlFind(b, n, iface) {
    let off = 0
    while off + 8 <= n {
        let sz = wlSize(b, off)
        if sz < 8 { emit -1 }
        if wlObject(b, off) == 2 && wlOpcode(b, off) == 0 {
            if wlReadStr(b, off + 12) == iface { emit wlU32(b, off + 8) }
        }
        off = off + sz
    }
    emit -1
}

// ── file model (dirs-first, like cortex) ────────────────────────────────────
func openFile(path) { shellRun("xdg-open '" + path + "' >/dev/null 2>&1 &") }
func openTerm(cwd) { shellRun("cd '" + cwd + "' && setsid sh -c '${TERMINAL:-$(command -v ghostty kitty alacritty foot xterm 2>/dev/null | head -1)}' >/dev/null 2>&1 &") }
func buildEntries(cwd, showHidden, sortMode) {
    let flag = "-1p"
    if showHidden == 1 { flag = flag + "A" }
    if sortMode == 1 { flag = flag + "S" }
    if sortMode == 2 { flag = flag + "t" }
    let raw = exec("ls " + flag + " '" + cwd + "' 2>/dev/null")
    let dirs = ""
    let files = ""
    let line = ""
    let i = 0
    while i < len(raw) {
        let ch = raw[i]
        if ch == fromCharCode(10) {
            if line != "" {
                if line[len(line) - 1] == "/" { dirs = dirs + "d " + substring(line, 0, len(line) - 1) + "\n" }
                else { files = files + "f " + line + "\n" }
            }
            line = ""
        } else { line = line + ch }
        i += 1
    }
    emit "d ..\n" + dirs + files
}
// quick-access places: "label<TAB>path" lines, standard dirs that exist.
func _place(label, path) {
    if chomp(exec("test -d '" + path + "' && echo 1")) == "1" { emit label + fromCharCode(9) + path + "\n" }
    emit ""
}
func bookmarksPath() { emit homeDir() + "/.config/cortex/bookmarks" }
func buildPlaces() {
    let home = homeDir()
    let out = "Home" + fromCharCode(9) + home + "\n"
    out = out + _place("Desktop", home + "/Desktop")
    out = out + _place("Documents", home + "/Documents")
    out = out + _place("Downloads", home + "/Downloads")
    out = out + _place("Pictures", home + "/Pictures")
    out = out + _place("Music", home + "/Music")
    out = out + _place("Videos", home + "/Videos")
    out = out + "Filesystem" + fromCharCode(9) + "/\n"
    // user bookmarks (one path per line)
    let bm = exec("cat '" + bookmarksPath() + "' 2>/dev/null")
    let bn = countLines(bm)
    let bi = 0
    while bi < bn {
        let bp = nthLine(bm, bi)
        if bp != "" { out = out + basename(bp) + fromCharCode(9) + bp + "\n" }
        bi += 1
    }
    // mounted removable drives -> label \t mountpoint
    let dv = exec("lsblk -Pno LABEL,MOUNTPOINT,RM,TYPE,FSTYPE 2>/dev/null | while read l; do eval \"$l\"; if [ \"$TYPE\" = part ] && [ \"$RM\" = 1 ] && [ -n \"$MOUNTPOINT\" ]; then printf '%s\\t%s\\n' \"${LABEL:-drive}\" \"$MOUNTPOINT\"; fi; done")
    out = out + dv
    if len(dv) > 0 && dv[len(dv) - 1] != fromCharCode(10) { out = out + "\n" }
    emit out
}
func plLabel(s) { let t = indexOf(s, fromCharCode(9))  emit substring(s, 0, t) }
func plPath(s)  { let t = indexOf(s, fromCharCode(9))  emit substring(s, t + 1, len(s)) }
func PLY()      { emit HDRH() + 36 }   // first place row y
func menuItems() { emit "Open\nCut\nCopy\nPaste\nRename\nMove to Trash\nNew Folder\nOpen Terminal" }
func entIsDir(e, r) { emit nthLine(e, r)[0] == "d" }
func entName(e, r)  { let l = nthLine(e, r)  emit substring(l, 2, len(l)) }
func containsCI(s, q) {
    if q == "" { emit 1 }
    let ls = lowerStr(s)  let lq = lowerStr(q)
    let n = len(ls)  let m = len(lq)
    if m > n { emit 0 }
    let i = 0
    while i <= n - m {
        if substring(ls, i, i + m) == lq { emit 1 }
        i += 1
    }
    emit 0
}
func filterEntries(all, q) {
    let out = "d ..\n"
    let n = countLines(all)
    let i = 1
    while i < n {
        if containsCI(entName(all, i), q) == 1 { out = out + nthLine(all, i) + "\n" }
        i += 1
    }
    emit out
}
// breadcrumb (ported from cortex.k; char width = 8 here)
func crumbs(cwd) {
    let tab = fromCharCode(9)
    let home = homeDir()
    let out = "/" + tab + "/\n"
    let acc = ""
    let rest = cwd
    let underHome = cwd == home
    if len(cwd) > len(home) && substring(cwd, 0, len(home)) == home && cwd[len(home)] == "/" { underHome = 1 }
    if underHome == 1 { out = "~" + tab + home + "\n"  acc = home  rest = substring(cwd, len(home), len(cwd)) }
    let cur = ""
    let i = 0
    while i <= len(rest) {
        let ch = "/"
        if i < len(rest) { ch = rest[i] }
        if ch == "/" { if cur != "" { acc = acc + "/" + cur  out = out + cur + tab + acc + "\n"  cur = "" } }
        else { cur = cur + ch }
        i += 1
    }
    emit out
}
func crumbLabel(seg) { let t = indexOf(seg, fromCharCode(9))  emit substring(seg, 0, t) }
func crumbPath(seg)  { let t = indexOf(seg, fromCharCode(9))  emit substring(seg, t + 1, len(seg)) }
func drawCrumbs(px, W, H, font, x0, y, maxW, cwd) {
    let segs = crumbs(cwd)
    let n = countLines(segs)
    let cx = x0
    let i = 0
    while i < n {
        let lbl = crumbLabel(nthLine(segs, i))
        let wseg = len(lbl) * 8
        if cx + wseg > x0 + maxW { i = n }
        else {
            let col = cMuted()
            if i == n - 1 { col = cText() }
            fbDrawText(px, W, H, font, cx, y, lbl, col)
            cx = cx + wseg
            if i < n - 1 { fbDrawText(px, W, H, font, cx + 4, y, ">", cMuted())  cx = cx + 15 }
            i += 1
        }
    }
}
func crumbHit(cwd, x0, maxW, ex) {
    let segs = crumbs(cwd)
    let n = countLines(segs)
    let cx = x0
    let i = 0
    while i < n {
        let lbl = crumbLabel(nthLine(segs, i))
        let wseg = len(lbl) * 8
        if cx + wseg > x0 + maxW { emit "" }
        if ex >= cx && ex < cx + wseg { emit crumbPath(nthLine(segs, i)) }
        cx = cx + wseg
        if i < n - 1 { cx = cx + 15 }
        i += 1
    }
    emit ""
}
// multi-select: marked = newline-joined entry names
func markHas(marked, name) {
    if marked == "" { emit 0 }
    let key = fromCharCode(10) + name + fromCharCode(10)
    let hay = fromCharCode(10) + marked + fromCharCode(10)
    let n = len(hay)
    let m = len(key)
    let i = 0
    while i <= n - m {
        if substring(hay, i, i + m) == key { emit 1 }
        i += 1
    }
    emit 0
}
func markToggle(marked, name) {
    if markHas(marked, name) == 1 {
        let out = ""
        let n = countLines(marked)
        let i = 0
        while i < n {
            let ln = nthLine(marked, i)
            if ln != "" && ln != name { if out == "" { out = ln } else { out = out + fromCharCode(10) + ln } }
            i += 1
        }
        emit out
    }
    if marked == "" { emit name }
    emit marked + fromCharCode(10) + name
}
func markAll(entries) {
    let out = ""
    let n = countLines(entries)
    let i = 1
    while i < n {
        let nm = entName(entries, i)
        if nm != ".." { if out == "" { out = nm } else { out = out + fromCharCode(10) + nm } }
        i += 1
    }
    emit out
}
func trashMarked(cwd, marked) {
    let n = countLines(marked)
    let i = 0
    while i < n {
        let nm = nthLine(marked, i)
        if nm != "" && nm != ".." { shellRun("gio trash '" + joinDir(cwd, nm) + "' 2>/dev/null || trash-put '" + joinDir(cwd, nm) + "' 2>/dev/null") }
        i += 1
    }
}
func parentDir(cwd) {
    let i = len(cwd) - 1
    while i > 0 && cwd[i] != "/" { i = i - 1 }
    if i <= 0 { emit "/" }
    emit substring(cwd, 0, i)
}
func joinDir(cwd, name) { if cwd == "/" { emit "/" + name }  emit cwd + "/" + name }
func truncLines(s, n) {
    let out = ""
    let i = 0
    while i < n { out = out + nthLine(s, i) + "\n"  i += 1 }
    emit out
}
// US keycode->char map (X11 keycodes = evdev+8 = cortex_wl's kc). For text entry.
func setK(b, kc, ch) { bufSetByte(b, kc, charCode(ch)) }
func buildKeymap() {
    let b = bufNew(128)
    setK(b,24,"q") setK(b,25,"w") setK(b,26,"e") setK(b,27,"r") setK(b,28,"t")
    setK(b,29,"y") setK(b,30,"u") setK(b,31,"i") setK(b,32,"o") setK(b,33,"p")
    setK(b,38,"a") setK(b,39,"s") setK(b,40,"d") setK(b,41,"f") setK(b,42,"g")
    setK(b,43,"h") setK(b,44,"j") setK(b,45,"k") setK(b,46,"l")
    setK(b,52,"z") setK(b,53,"x") setK(b,54,"c") setK(b,55,"v") setK(b,56,"b")
    setK(b,57,"n") setK(b,58,"m")
    setK(b,10,"1") setK(b,11,"2") setK(b,12,"3") setK(b,13,"4") setK(b,14,"5")
    setK(b,15,"6") setK(b,16,"7") setK(b,17,"8") setK(b,18,"9") setK(b,19,"0")
    setK(b,65," ") setK(b,61,"/") setK(b,60,".") setK(b,20,"-") setK(b,49,"`")
    emit b
}
func keyChar(kmap, kc, shift) {
    if kc >= 128 { emit "" }
    let c = bufGetByte(kmap, kc)
    if c == 0 { emit "" }
    if shift == 1 {
        if c >= 97 && c <= 122 { emit fromCharCode(c - 32) }
        if kc == 20 { emit "_" }
        if kc == 49 { emit "~" }
    }
    emit fromCharCode(c)
}
func basename(p) {
    let i = len(p) - 1
    while i >= 0 && p[i] != "/" { i = i - 1 }
    emit substring(p, i + 1, len(p))
}

// ── geometry ────────────────────────────────────────────────────────────────
func HDRH()  { emit 48 }
func SIDEW() { emit 180 }
func CELLW() { emit 150 }
func CELLH() { emit 116 }
func PAD()   { emit 18 }
func gridCols(w) { let c = (w - SIDEW() - PAD() * 2) / CELLW()  if c < 1 { emit 1 }  emit c }
func LISTROWH()  { emit 34 }
// header right-side control centers (search / view / menu / close)
func hSearchX(w) { emit w - 138 }
func hViewX(w)   { emit w - 102 }
func hMenuX(w)   { emit w - 66 }
func hCloseX(w)  { emit w - 30 }
func hHit(cx, ex) { if ex >= cx - 15 && ex < cx + 15 { emit 1 }  emit 0 }
func colsFor(w, vm)  { if vm == 1 { emit 1 }  emit gridCols(w) }
func rowHFor(vm)     { if vm == 1 { emit LISTROWH() }  emit CELLH() }
func cellWFor(w, vm) { if vm == 1 { emit w - SIDEW() - PAD() * 2 }  emit CELLW() }

// ── drawn icons (fb primitives) ─────────────────────────────────────────────
// green folder ~ 56x44 at (x,y)
func drawFolder(px, W, H, x, y) {
    fbRoundRect(px, W, H, x, y + 4, 56, 40, 6, cGreenA())
    fbFillRect(px, W, x + 2, y, 22, 8, cGreenA())               // back tab
    fbRoundRect(px, W, H, x, y + 12, 56, 30, 6, cGreenB())      // front face
}
// white page ~ 40x48
func drawFile(px, W, H, x, y) {
    fbRoundRect(px, W, H, x, y, 40, 48, 4, cText())
    fbFillRect(px, W, x + 8, y + 14, 24, 3, cGreenA())
    fbFillRect(px, W, x + 8, y + 22, 18, 3, cMuted())
}

// ── header glyphs (drawn from primitives — no proportional font) ─────────────
// chevron: tip at (x,y). dir 0 = "<" (tip left), dir 1 = ">" (tip right). h~12.
func drawChevron(px, W, x, y, dir, col) {
    let k = 0
    while k <= 6 {
        let dx = 6 - k
        if dir == 1 { dx = k }
        fbFillRect(px, W, x + dx, y - 6 + k, 2, 2, col)
        fbFillRect(px, W, x + dx, y + 6 - k, 2, 2, col)
        k += 1
    }
}
// reload: ring with a small break + arrow notch
func drawReload(px, W, H, cx, cy, col, bg) {
    fbFillCircle(px, W, H, cx, cy, 7, col)
    fbFillCircle(px, W, H, cx, cy, 4, bg)
    fbFillRect(px, W, cx + 3, cy - 9, 6, 6, bg)
    fbFillRect(px, W, cx + 4, cy - 8, 5, 3, col)
    fbFillRect(px, W, cx + 7, cy - 9, 3, 5, col)
}
// magnifier: ring + diagonal handle
func drawSearchIcon(px, W, H, cx, cy, col, bg) {
    fbFillCircle(px, W, H, cx, cy, 6, col)
    fbFillCircle(px, W, H, cx, cy, 3, bg)
    let k = 0
    while k < 5 { fbFillRect(px, W, cx + 4 + k, cy + 4 + k, 2, 2, col)  k += 1 }
}
// hamburger: three stacked bars, top-left at (x,y)
func drawHamburger(px, W, x, y, col) {
    fbFillRect(px, W, x, y, 16, 2, col)
    fbFillRect(px, W, x, y + 5, 16, 2, col)
    fbFillRect(px, W, x, y + 10, 16, 2, col)
}
// 2x2 grid glyph (view switcher), top-left at (x,y)
func drawViewIcon(px, W, x, y, col) {
    fbFillRect(px, W, x, y, 6, 6, col)
    fbFillRect(px, W, x + 9, y, 6, 6, col)
    fbFillRect(px, W, x, y + 9, 6, 6, col)
    fbFillRect(px, W, x + 9, y + 9, 6, 6, col)
}
// 3-row list glyph (view switcher, list mode)
func drawListIcon(px, W, x, y, col) {
    fbFillRect(px, W, x, y, 3, 3, col)       fbFillRect(px, W, x + 5, y + 1, 10, 2, col)
    fbFillRect(px, W, x, y + 6, 3, 3, col)   fbFillRect(px, W, x + 5, y + 7, 10, 2, col)
    fbFillRect(px, W, x, y + 12, 3, 3, col)  fbFillRect(px, W, x + 5, y + 13, 10, 2, col)
}
// close "×" centered at (cx,cy)
func drawClose(px, W, cx, cy, col) {
    let k = 0
    while k < 10 {
        fbFillRect(px, W, cx - 5 + k, cy - 5 + k, 2, 2, col)
        fbFillRect(px, W, cx + 4 - k, cy - 5 + k, 2, 2, col)
        k += 1
    }
}


// ── icon raster pipeline (copied from cortex.k) ────────────────────────────
func homeDir() { emit chomp(exec("printf %s \"$HOME\"")) }
func iconBytes(sz) { emit sz * sz * 4 }
func hexNyb(c) {
    if c >= "0" && c <= "9" { emit charCode(c) - 48 }
    emit charCode(c) - 87
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
func rasterHex(name, svg, sz) {
    let dir = homeDir() + "/.cache/cortex"
    exec("mkdir -p '" + dir + "'")
    let svgf = dir + "/" + name + ".svg"
    let hexf = dir + "/" + name + "-" + sz + ".hex"
    writeFile(svgf, svg)
    shellRun("magick -background none -density " + (sz * 4) + " '" + svgf + "' -resize " + sz + "x" + sz + " -depth 8 BGRA:- 2>/dev/null | od -An -v -tx1 | tr -dc '0-9a-f' > '" + hexf + "'")
    emit chomp(readFile(hexf))
}
func lc1(c) { if c >= "A" && c <= "Z" { emit fromCharCode(charCode(c) + 32) }  emit c }
func lowerStr(s) {
    let out = ""
    let i = 0
    while i < len(s) { out = out + lc1(s[i])  i += 1 }
    emit out
}
func lastExt(name) {
    let i = len(name) - 1
    while i >= 0 && name[i] != "." { i = i - 1 }
    if i < 0 { emit "" }
    emit lowerStr(substring(name, i + 1, len(name)))
}
func extKind(name) {
    let e = lastExt(name)
    if e == "png" || e == "jpg" || e == "jpeg" || e == "gif" || e == "bmp" || e == "webp" || e == "svg" || e == "ico" || e == "tiff" { emit "image" }
    if e == "zip" || e == "tar" || e == "gz" || e == "tgz" || e == "bz2" || e == "xz" || e == "7z" || e == "rar" || e == "zst" { emit "archive" }
    if e == "mp3" || e == "wav" || e == "flac" || e == "ogg" || e == "m4a" || e == "opus" || e == "mp4" || e == "mkv" || e == "webm" || e == "avi" || e == "mov" { emit "media" }
    emit "file"
}
func folderSvg() {
    emit "<svg xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'>" +
         "<defs><linearGradient id='g' x1='0' y1='0' x2='0' y2='1'>" +
         "<stop offset='0' stop-color='#38CE84'/><stop offset='1' stop-color='#1E9E5E'/></linearGradient></defs>" +
         "<path d='M7 14 a3 3 0 0 1 3-3 h8.3 a2.5 2.5 0 0 1 1.8 .75 l2.6 2.6 a2.5 2.5 0 0 0 1.8 .75 H38 a3 3 0 0 1 3 3 v14 a3 3 0 0 1 -3 3 H10 a3 3 0 0 1 -3-3 z' fill='#13794A'/>" +
         "<rect x='13.5' y='16' width='21' height='15' rx='2.2' fill='#E7EFEA' transform='rotate(-5 24 23)'/>" +
         "<rect x='14.5' y='17' width='20' height='15' rx='2.2' fill='#FFFFFF'/>" +
         "<path d='M6 23.5 a3 3 0 0 1 3-3 h30 a3 3 0 0 1 3 3 v10.5 a3 3 0 0 1 -3 3 H9 a3 3 0 0 1 -3-3 z' fill='url(#g)'/>" +
         "<path d='M7.5 24 a2 2 0 0 1 2-2 h29 a2 2 0 0 1 2 2' fill='none' stroke='#6FE3A8' stroke-width='1.3' stroke-linecap='round' opacity='0.8'/></svg>"
}
func folderGlyph(inner) {
    emit "<svg xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'>" +
         "<defs><linearGradient id='g' x1='0' y1='0' x2='0' y2='1'>" +
         "<stop offset='0' stop-color='#38CE84'/><stop offset='1' stop-color='#1E9E5E'/></linearGradient></defs>" +
         "<path d='M7 14 a3 3 0 0 1 3-3 h8.3 a2.5 2.5 0 0 1 1.8 .75 l2.6 2.6 a2.5 2.5 0 0 0 1.8 .75 H38 a3 3 0 0 1 3 3 v14 a3 3 0 0 1 -3 3 H10 a3 3 0 0 1 -3-3 z' fill='#13794A'/>" +
         "<path d='M6 23.5 a3 3 0 0 1 3-3 h30 a3 3 0 0 1 3 3 v10.5 a3 3 0 0 1 -3 3 H9 a3 3 0 0 1 -3-3 z' fill='url(#g)'/>" +
         "<path d='M7.5 24 a2 2 0 0 1 2-2 h29 a2 2 0 0 1 2 2' fill='none' stroke='#6FE3A8' stroke-width='1.3' stroke-linecap='round' opacity='0.7'/>" +
         inner + "</svg>"
}
func docFolderSvg()  { emit folderGlyph("<rect x='20' y='25.5' width='8' height='10' rx='1' fill='#FFFFFF'/><rect x='21.5' y='28' width='5' height='1' fill='#1E9E5E'/><rect x='21.5' y='30' width='5' height='1' fill='#1E9E5E'/><rect x='21.5' y='32' width='3.5' height='1' fill='#1E9E5E'/>") }
func dlFolderSvg()   { emit folderGlyph("<path d='M24 25.5 v6.5 M20.5 29 l3.5 3.5 3.5 -3.5' fill='none' stroke='#FFFFFF' stroke-width='1.9' stroke-linecap='round' stroke-linejoin='round'/>") }
func musicFolderSvg(){ emit folderGlyph("<path d='M28 25 v7.4 a1.9 1.9 0 1 1 -1.5 -1.85 V27.2 l-4.4 1.1 v5.6 a1.9 1.9 0 1 1 -1.5 -1.85 V27.6 z' fill='#FFFFFF'/>") }
func picFolderSvg()  { emit folderGlyph("<rect x='18.5' y='27' width='11' height='8' rx='1.4' fill='#FFFFFF'/><rect x='22' y='25.6' width='4' height='1.8' rx='0.7' fill='#FFFFFF'/><circle cx='24' cy='31' r='2.1' fill='#1E9E5E'/>") }
func vidFolderSvg()  { emit folderGlyph("<rect x='19' y='26.5' width='10' height='8' rx='1.4' fill='#FFFFFF'/><path d='M22.8 28.6 l3.6 2 -3.6 2 z' fill='#1E9E5E'/>") }
func deskFolderSvg() { emit folderGlyph("<rect x='18.5' y='26' width='11' height='7' rx='1' fill='#FFFFFF'/><rect x='22.5' y='33.2' width='3' height='1.6' rx='0.4' fill='#FFFFFF'/><rect x='20' y='27.4' width='8' height='4.2' fill='#1E9E5E'/>") }
func fileSvg() {
    emit "<svg xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'>" +
         "<path d='M11 6 a3 3 0 0 1 3-3 h16 l10 10 v26 a3 3 0 0 1 -3 3 H14 a3 3 0 0 1 -3-3 z' fill='#FFFFFF' stroke='#D2D5DE' stroke-width='1.5'/>" +
         "<path d='M30 3 v8 a2 2 0 0 0 2 2 h8' fill='none' stroke='#D2D5DE' stroke-width='1.5'/>" +
         "<rect x='17' y='24' width='14' height='2.6' rx='1.3' fill='#1FA463'/>" +
         "<rect x='17' y='30' width='10' height='2.6' rx='1.3' fill='#AEB4C0'/></svg>"
}
func imageSvg() {
    emit "<svg xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'>" +
         "<rect x='8' y='9' width='32' height='30' rx='3.5' fill='#FFFFFF' stroke='#D2D5DE' stroke-width='1.5'/>" +
         "<circle cx='17' cy='18' r='3.2' fill='#34C77E'/>" +
         "<path d='M10 38 l10-12 6 7 6-6 6 11 z' fill='#1FA463'/></svg>"
}
func archiveSvg() {
    emit "<svg xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'>" +
         "<path d='M11 6 a3 3 0 0 1 3-3 h16 l10 10 v26 a3 3 0 0 1 -3 3 H14 a3 3 0 0 1 -3-3 z' fill='#FFFFFF' stroke='#D2D5DE' stroke-width='1.5'/>" +
         "<rect x='21.5' y='4' width='4' height='4' fill='#1FA463'/><rect x='21.5' y='10' width='4' height='4' fill='#34C77E'/>" +
         "<rect x='21.5' y='16' width='4' height='4' fill='#1FA463'/><rect x='21.5' y='22' width='4' height='4' fill='#34C77E'/>" +
         "<rect x='19.5' y='28' width='8' height='9' rx='1.5' fill='#1E9E5E'/>" +
         "<rect x='22.5' y='31' width='2' height='3.5' rx='1' fill='#EAF7F0'/></svg>"
}
func mediaSvg() {
    emit "<svg xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'>" +
         "<rect x='8' y='9' width='32' height='30' rx='4' fill='#FFFFFF' stroke='#D2D5DE' stroke-width='1.5'/>" +
         "<path d='M20 17.5 l12 6.5 -12 6.5 z' fill='#1FA463'/></svg>"
}
func homeSvg() {
    emit "<svg xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'>" +
         "<path d='M24 7 L6 23 h4 v15 a2 2 0 0 0 2 2 h24 a2 2 0 0 0 2-2 V23 h4 z' fill='#34C77E' stroke='#1E9E5E' stroke-width='1.2' stroke-linejoin='round'/>" +
         "<rect x='20' y='29' width='8' height='11' rx='1' fill='#13794A'/></svg>"
}
func driveSvg() {
    emit "<svg xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'>" +
         "<rect x='7' y='16' width='34' height='16' rx='3' fill='#E7EFEA' stroke='#1E9E5E' stroke-width='1.3'/>" +
         "<rect x='11' y='21' width='13' height='2.4' rx='1.2' fill='#1FA463'/>" +
         "<circle cx='34' cy='24' r='2.6' fill='#34C77E'/></svg>"
}
func placeIconFor(label, fb, home, drive, doc, dl, mus, pic, vid, desk) {
    if label == "Home" { emit home }
    if label == "Filesystem" { emit drive }
    if label == "Documents" { emit doc }
    if label == "Downloads" { emit dl }
    if label == "Music" { emit mus }
    if label == "Pictures" { emit pic }
    if label == "Videos" { emit vid }
    if label == "Desktop" { emit desk }
    emit fb
}
func folderIconFor(name, fb, doc, dl, mus, pic, vid, desk) {
    if name == "Documents" { emit doc }
    if name == "Downloads" { emit dl }
    if name == "Music" { emit mus }
    if name == "Pictures" { emit pic }
    if name == "Videos" { emit vid }
    if name == "Desktop" { emit desk }
    emit fb
}
func loadIcon(name, svg, sz) {
    let hex = rasterHex(name, svg, sz)
    if len(hex) >= iconBytes(sz) * 2 { emit hexToBuf(hex, iconBytes(sz)) }
    emit bufNew(iconBytes(sz))
}
func fileIconFor(name, fb, img, arc, med) {
    let k = extKind(name)
    if k == "image" { emit img }
    if k == "archive" { emit arc }
    if k == "media" { emit med }
    emit fb
}
func IBIG() { emit 64 }

// ── render ──────────────────────────────────────────────────────────────────
func draw(px, W, H, font, cwd, ent, sel, scroll, folderBig, fileBig, docBig, dlBig, musicBig, picBig, vidBig, deskBig, imageBig, archiveBig, mediaBig, places, folderSml, mode, textBuf, marked, viewMode, flSml, menuOpen, menuX, menuY, homeSml, driveSml, docSml, dlSml, musSml, picSml, vidSml, deskSml) {
    fbClear(px, W, H, cBg())
    fbFillRect(px, W, 0, HDRH(), SIDEW(), H - HDRH(), cSide())
    fbFillRect(px, W, SIDEW() - 1, HDRH(), 1, H - HDRH(), cLine())
    fbDrawText(px, W, H, font, 16, HDRH() + 16, "Quick access", cMuted())
    let np = countLines(places)
    let p = 0
    while p < np {
        let line = nthLine(places, p)
        let py = PLY() + p * 30
        if plPath(line) == cwd { fbRoundRect(px, W, H, 6, py - 4, SIDEW() - 12, 28, 8, cSel()) }
        fbBlitAlpha(px, W, H, 14, py - 4, placeIconFor(plLabel(line), folderSml, homeSml, driveSml, docSml, dlSml, musSml, picSml, vidSml, deskSml), 24, 24)
        fbDrawText(px, W, H, font, 44, py + 8, plLabel(line), cText())
        p += 1
    }
    fbFillRect(px, W, 0, 0, W, HDRH(), cHdr())
    fbFillRect(px, W, 0, HDRH() - 1, W, 1, cLine())
    fbFillCircle(px, W, H, 24, 24, 15, cSide())
    fbFillCircle(px, W, H, 60, 24, 15, cSide())
    fbFillCircle(px, W, H, 96, 24, 15, cSide())
    drawChevron(px, W, 21, 24, 0, cGreenB())
    drawChevron(px, W, 57, 24, 1, cGreenB())
    drawReload(px, W, H, 96, 24, cGreenB(), cSide())
    fbRoundRect(px, W, H, 124, 8, W - 124 - 160, 32, 8, cSide())
    drawCrumbs(px, W, H, font, 136, 18, W - 136 - 168, cwd)
    drawSearchIcon(px, W, H, hSearchX(W), 24, cMuted(), cHdr())
    if viewMode == 1 { drawListIcon(px, W, hViewX(W) - 7, 16, cMuted()) }
    else { drawViewIcon(px, W, hViewX(W) - 7, 16, cMuted()) }
    drawHamburger(px, W, hMenuX(W) - 8, 18, cMuted())
    drawClose(px, W, hCloseX(W), 24, cMuted())
    let cols = colsFor(W, viewMode)
    let n = countLines(ent)
    let i = 0
    while i < n {
        let col = i - i / cols * cols
        let row = i / cols
        if row >= scroll {
            let cellW = cellWFor(W, viewMode)
            let rowH = rowHFor(viewMode)
            let cx = SIDEW() + PAD() + col * cellW
            let cy = HDRH() + PAD() + (row - scroll) * rowH
            if cy < H - 10 {
                let nm = entName(ent, i)
                let ic = fileIconFor(nm, fileBig, imageBig, archiveBig, mediaBig)
                if entIsDir(ent, i) { ic = folderIconFor(nm, folderBig, docBig, dlBig, musicBig, picBig, vidBig, deskBig) }
                if viewMode == 1 {
                    if i == sel || markHas(marked, nm) == 1 { fbRoundRect(px, W, H, cx - 6, cy - 4, cellW - 8, rowH - 4, 8, cSel()) }
                    let slIc = folderSml
                    if entIsDir(ent, i) == 0 { slIc = flSml }
                    fbBlitAlpha(px, W, H, cx, cy + (rowH - 24) / 2, slIc, 24, 24)
                    fbDrawText(px, W, H, font, cx + 34, cy + rowH / 2 + 4, nm, cText())
                } else {
                    if i == sel || markHas(marked, nm) == 1 { fbRoundRect(px, W, H, cx - 6, cy - 6, cellW - 16, CELLH() - 12, 10, cSel()) }
                    fbBlitAlpha(px, W, H, cx + (cellW - 28 - IBIG()) / 2, cy + 2, ic, IBIG(), IBIG())
                    let maxc = (cellW - 20) / 8
                    let line1 = nm
                    let line2 = ""
                    if len(nm) > maxc {
                        line1 = substring(nm, 0, maxc)
                        line2 = substring(nm, maxc, len(nm))
                        if len(line2) > maxc { line2 = substring(line2, 0, maxc - 1) + "." }
                    }
                    let lx1 = cx + (cellW - 28 - len(line1) * 8) / 2
                    fbDrawText(px, W, H, font, lx1, cy + 64, line1, cText())
                    if line2 != "" {
                        let lx2 = cx + (cellW - 28 - len(line2) * 8) / 2
                        fbDrawText(px, W, H, font, lx2, cy + 80, line2, cText())
                    }
                }
            }
        }
        i += 1
    }
    fbFillRect(px, W, SIDEW(), H - 22, W - SIDEW(), 22, cHdr())
    fbFillRect(px, W, SIDEW(), H - 22, W - SIDEW(), 1, cLine())
    let st = (countLines(ent) - 1) + " items"
    if mode == 1 { st = "rename:  " + textBuf + "_" }
    if mode == 2 { st = "search:  " + textBuf + "_" }
    fbDrawText(px, W, H, font, SIDEW() + 12, H - 8, st, cMuted())
    if menuOpen == 1 {
        let items = menuItems()
        let mn = countLines(items)
        let mh = mn * 26 + 8
        fbRoundRect(px, W, H, menuX - 1, menuY - 1, 190, mh + 2, 7, cLine())
        fbRoundRect(px, W, H, menuX, menuY, 188, mh, 6, cHdr())
        let mi = 0
        while mi < mn {
            fbDrawText(px, W, H, font, menuX + 16, menuY + 18 + mi * 26, nthLine(items, mi), cText())
            mi += 1
        }
    }
}

just run {
    let fd = wlConnect()
    if fd < 0 { print("connect failed")  exit(1) }
    let REG=2  let COMP=3  let SHM=4  let WM=5  let SEAT=6  let KB=7  let PTR=8
    let SURF=9  let XS=10  let TOP=11  let POOL=12  let BUF=13

    wlGetRegistry(fd, REG)
    let rb = bufNew(8192)
    let rn = wlRecvInto(fd, rb, 8192)
    wlBind(fd, REG, _wlFind(rb, rn, "wl_compositor"), "wl_compositor", 4, COMP)
    wlBind(fd, REG, _wlFind(rb, rn, "wl_shm"), "wl_shm", 1, SHM)
    wlBind(fd, REG, _wlFind(rb, rn, "xdg_wm_base"), "xdg_wm_base", 1, WM)
    wlBind(fd, REG, _wlFind(rb, rn, "wl_seat"), "wl_seat", 5, SEAT)
    wlGetKeyboard(fd, SEAT, KB)
    wlGetPointer(fd, SEAT, PTR)
    wlCreateSurface(fd, COMP, SURF)
    wlGetXdgSurface(fd, WM, XS, SURF)
    wlGetToplevel(fd, XS, TOP)
    wlSetTitle(fd, TOP, "cortex")
    wlSetAppId(fd, TOP, "cortex")
    wlCommit(fd, SURF)

    let W = 900  let H = 600
    let cwd = chomp(exec("printf %s \"$HOME\""))
    let showHidden = 0  let sortMode = 0  let viewMode = 0
    let ent = buildEntries(cwd, showHidden, sortMode)
    let sel = 0  let scroll = 0
    let font = wlFontLoad()
    let big = IBIG()
    let folderBig  = loadIcon("folder", folderSvg(), big)
    let fileBig    = loadIcon("file", fileSvg(), big)
    let docBig     = loadIcon("docf", docFolderSvg(), big)
    let dlBig      = loadIcon("dlf", dlFolderSvg(), big)
    let musicBig   = loadIcon("musf", musicFolderSvg(), big)
    let picBig     = loadIcon("picf", picFolderSvg(), big)
    let vidBig     = loadIcon("vidf", vidFolderSvg(), big)
    let deskBig    = loadIcon("deskf", deskFolderSvg(), big)
    let imageBig   = loadIcon("img", imageSvg(), big)
    let archiveBig = loadIcon("arc", archiveSvg(), big)
    let mediaBig   = loadIcon("med", mediaSvg(), big)
    let folderSml  = loadIcon("foldersml", folderSvg(), 24)
    let flSml      = loadIcon("filesml", fileSvg(), 24)
    let homeSml    = loadIcon("homesml", homeSvg(), 24)
    let driveSml   = loadIcon("drivesml", driveSvg(), 24)
    let docSml     = loadIcon("docsml", docFolderSvg(), 24)
    let dlSml      = loadIcon("dlsml", dlFolderSvg(), 24)
    let musSml     = loadIcon("mussml", musicFolderSvg(), 24)
    let picSml     = loadIcon("picsml", picFolderSvg(), 24)
    let vidSml     = loadIcon("vidsml", vidFolderSvg(), 24)
    let deskSml    = loadIcon("desksml", deskFolderSvg(), 24)
    let places     = buildPlaces()
    let nextId = 12
    let prevBuf = 0  let prevPool = 0  let prevMfd = 0
    let mouseX = 0  let mouseY = 0  let ctrlDown = 0  let altDown = 0
    let hist = cwd + "\n"  let histIdx = 0  let lastCwd = cwd  let fromHist = 0
    let shiftDown = 0  let clipboard = ""  let clipOp = ""
    let mode = 0  let textBuf = ""  let kmap = buildKeymap()  let allEnt = ent  let marked = ""
    let menuOpen = 0  let menuX = 0  let menuY = 0  let menuTarget = 0

    let running = 1
    while running == 1 {
        let eb = bufNew(8192)
        let en = wlRecvInto(fd, eb, 8192)
        if en <= 0 { running = 0 }
        let off = 0
        let dirty = 0
        while off + 8 <= en {
            let obj = wlObject(eb, off)  let op = wlOpcode(eb, off)  let s = wlSize(eb, off)
            if s < 8 { off = en }
            else {
                if obj == WM && op == 0 { wlPong(fd, WM, wlU32(eb, off + 8)) }
                if obj == XS && op == 0 { wlAckConfigure(fd, XS, wlU32(eb, off + 8))  dirty = 1 }
                if obj == TOP && op == 0 {
                    let cw = wlU32(eb, off + 8)  let chh = wlU32(eb, off + 12)
                    if cw > 0 && chh > 0 { W = cw  H = chh }
                }
                if obj == 1 && op == 0 { print("wl error code=" + wlU32(eb, off + 12))  running = 0 }
                if obj == KB && op == 3 {
                    let st = wlU32(eb, off + 20)
                    if st == 1 {
                        let kc = wlKeyToKc(wlU32(eb, off + 16))
                        if mode == 1 || mode == 2 {
                            if kc == 9 { if mode == 2 { ent = allEnt  sel = 0 }  mode = 0  textBuf = ""  marked = "" }
                            else { if kc == 36 {
                                if mode == 1 { if textBuf != "" { shellRun("mv -n '" + cwd + "/" + entName(ent, sel) + "' '" + cwd + "/" + textBuf + "' 2>/dev/null")  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt } }
                                mode = 0  textBuf = ""  marked = ""
                            } else { if kc == 22 { if len(textBuf) > 0 { textBuf = substring(textBuf, 0, len(textBuf) - 1) }  if mode == 2 { ent = filterEntries(allEnt, textBuf)  sel = 0 } }
                            else { let ch2 = keyChar(kmap, kc, shiftDown)  if ch2 != "" { textBuf = textBuf + ch2  if mode == 2 { ent = filterEntries(allEnt, textBuf)  sel = 0 } } } } }
                        }
                        if mode == 0 {
                        let cols = colsFor(W, viewMode)
                        if kc == 114 { if sel + 1 < countLines(ent) { sel += 1 } }          // Right
                        if kc == 113 { if sel > 0 { sel -= 1 } }                            // Left
                        if kc == 116 { if sel + cols < countLines(ent) { sel += cols } }    // Down
                        if kc == 111 { if sel - cols >= 0 { sel -= cols } }                 // Up
                        if kc == 36 {                                                       // Enter
                            if entIsDir(ent, sel) {
                                let nm = entName(ent, sel)
                                if nm == ".." { cwd = parentDir(cwd) } else { cwd = joinDir(cwd, nm) }
                                allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt  sel = 0  scroll = 0  mode = 0  textBuf = ""  marked = ""
                                wlSetTitle(fd, TOP, "cortex - " + basename(cwd))
                            } else { openFile(joinDir(cwd, entName(ent, sel))) }
                        }
                        if kc == 22 { cwd = parentDir(cwd)  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt  sel = 0  scroll = 0  mode = 0  textBuf = ""  marked = "" }  // Backspace
                        if kc == 9 { running = 0 }                                          // Esc
                        if kc == 43 && ctrlDown == 1 { showHidden = 1 - showHidden  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt  sel = 0  scroll = 0  mode = 0  textBuf = ""  marked = "" }  // Ctrl+H hidden
                        if kc == 70 { openTerm(cwd) }                                        // F4 terminal
                        if kc == 71 { allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt }                  // F5 refresh
                        if kc == 110 && altDown == 1 { cwd = homeDir()  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt  sel = 0  scroll = 0  mode = 0  textBuf = ""  marked = ""  wlSetTitle(fd, TOP, "cortex - " + basename(cwd)) }  // Alt+Home
                        if kc == 54 && ctrlDown == 1 { if entName(ent, sel) != ".." { clipboard = joinDir(cwd, entName(ent, sel))  clipOp = "copy" } }  // Ctrl+C
                        if kc == 53 && ctrlDown == 1 { if entName(ent, sel) != ".." { clipboard = joinDir(cwd, entName(ent, sel))  clipOp = "cut" } }   // Ctrl+X
                        if kc == 55 && ctrlDown == 1 { if clipboard != "" { if clipOp == "cut" { shellRun("mv --backup=numbered '" + clipboard + "' '" + cwd + "/' 2>/dev/null")  clipboard = "" } else { shellRun("cp -r --backup=numbered '" + clipboard + "' '" + cwd + "/' 2>/dev/null") }  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt } }  // Ctrl+V
                        if kc == 119 { if marked != "" { trashMarked(cwd, marked)  marked = ""  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt  if sel >= countLines(ent) { sel = countLines(ent) - 1 } } else { if entName(ent, sel) != ".." { shellRun("gio trash '" + joinDir(cwd, entName(ent, sel)) + "' 2>/dev/null || trash-put '" + joinDir(cwd, entName(ent, sel)) + "' 2>/dev/null")  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt  if sel >= countLines(ent) { sel = countLines(ent) - 1 } } } }  // Delete -> trash (marked or single)
                        if kc == 57 && ctrlDown == 1 && shiftDown == 1 { shellRun("mkdir -p '" + cwd + "/New Folder'")  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt }  // Ctrl+Shift+N new folder
                        if kc == 57 && ctrlDown == 1 && shiftDown == 0 { shellRun("touch '" + cwd + "/New File'")  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt }  // Ctrl+N new file
                        if kc == 68 { if entName(ent, sel) != ".." { mode = 1  textBuf = entName(ent, sel) } }   // F2 rename
                        if kc == 41 && ctrlDown == 1 { mode = 2  textBuf = "" }              // Ctrl+F search
                        if kc == 23 { viewMode = 1 - viewMode  scroll = 0 }                  // Tab toggle view
                        if kc == 39 && ctrlDown == 1 { sortMode = sortMode + 1  if sortMode > 2 { sortMode = 0 }  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt  sel = 0  scroll = 0 }  // Ctrl+S sort
                        if kc == 27 && ctrlDown == 1 && shiftDown == 1 { if entName(ent, sel) != ".." { shellRun("cd '" + cwd + "' && cp -r --backup=numbered '" + entName(ent, sel) + "' '" + entName(ent, sel) + ".copy' 2>/dev/null")  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt } }  // Ctrl+Shift+R duplicate
                        if kc == 52 && ctrlDown == 1 && shiftDown == 1 { if entName(ent, sel) != ".." { shellRun("cd '" + cwd + "' && (zip -r -q '" + entName(ent, sel) + ".zip' '" + entName(ent, sel) + "' 2>/dev/null || tar czf '" + entName(ent, sel) + ".tar.gz' '" + entName(ent, sel) + "' 2>/dev/null)")  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt } }  // Ctrl+Shift+Z compress
                        if kc == 26 && ctrlDown == 1 { if entName(ent, sel) != ".." { shellRun("cd '" + cwd + "' && (bsdtar -xf '" + entName(ent, sel) + "' 2>/dev/null || tar xf '" + entName(ent, sel) + "' 2>/dev/null || unzip -o '" + entName(ent, sel) + "' 2>/dev/null)")  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt } }  // Ctrl+E extract
                        if kc == 58 && ctrlDown == 1 { shellRun("lsblk -Pno NAME,MOUNTPOINT,RM,TYPE,FSTYPE 2>/dev/null | while read l; do eval \"$l\"; if [ \"$TYPE\" = part ] && [ \"$RM\" = 1 ] && [ -n \"$FSTYPE\" ] && [ -z \"$MOUNTPOINT\" ]; then udisksctl mount -b \"/dev/$NAME\" >/dev/null 2>&1; fi; done")  places = buildPlaces() }  // Ctrl+M mount all
                        if kc == 28 && ctrlDown == 1 && shiftDown == 1 { shellRun("mkdir -p '" + homeDir() + "/.local/share/Trash/files' 2>/dev/null")  cwd = homeDir() + "/.local/share/Trash/files"  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt  sel = 0  scroll = 0  wlSetTitle(fd, TOP, "cortex - Trash") }  // Ctrl+Shift+T trash view
                        if kc == 65 && ctrlDown == 0 { if entName(ent, sel) != ".." { marked = markToggle(marked, entName(ent, sel)) } }  // Space mark
                        if kc == 38 && ctrlDown == 1 && shiftDown == 0 { marked = markAll(ent) }  // Ctrl+A select all
                        if kc == 38 && ctrlDown == 1 && shiftDown == 1 { marked = "" }  // Ctrl+Shift+A clear
                        if kc == 40 && ctrlDown == 1 && shiftDown == 0 { shellRun("mkdir -p \"$(dirname '" + bookmarksPath() + "')\"; grep -qxF '" + cwd + "' '" + bookmarksPath() + "' 2>/dev/null || echo '" + cwd + "' >> '" + bookmarksPath() + "'")  places = buildPlaces() }  // Ctrl+D bookmark
                        if kc == 40 && ctrlDown == 1 && shiftDown == 1 { shellRun("grep -vxF '" + cwd + "' '" + bookmarksPath() + "' > '" + bookmarksPath() + ".tmp' 2>/dev/null && mv '" + bookmarksPath() + ".tmp' '" + bookmarksPath() + "'")  places = buildPlaces() }  // Ctrl+Shift+D unbookmark
                        // keep selection visible
                        let vis = (H - HDRH() - PAD() - 10) / rowHFor(viewMode)
                        let srow = sel / cols
                        if srow < scroll { scroll = srow }
                        if srow >= scroll + vis { scroll = srow - vis + 1 }
                        }
                        dirty = 1
                    }
                }
                if obj == KB && op == 4 {
                    let dep = wlU32(eb, off + 12)
                    shiftDown = dep - dep / 2 * 2
                    ctrlDown = dep / 4 - dep / 8 * 2
                    altDown = dep / 8 - dep / 16 * 2
                }
                if obj == PTR && op == 0 { mouseX = wlFixed(eb, off + 16)  mouseY = wlFixed(eb, off + 20) }
                if obj == PTR && op == 2 { mouseX = wlFixed(eb, off + 12)  mouseY = wlFixed(eb, off + 16) }
                if obj == PTR && op == 3 {
                    if wlU32(eb, off + 16) == 272 && wlU32(eb, off + 20) == 1 {
                        if menuOpen == 1 {
                            let mrow = (mouseY - menuY - 4) / 26
                            if mouseX >= menuX && mouseX < menuX + 188 && mrow >= 0 && mrow < 8 {
                                let tn = entName(ent, menuTarget)
                                if mrow == 0 { if entIsDir(ent, menuTarget) { if tn == ".." { cwd = parentDir(cwd) } else { cwd = joinDir(cwd, tn) }  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt  sel = 0  scroll = 0  wlSetTitle(fd, TOP, "cortex - " + basename(cwd)) } else { openFile(joinDir(cwd, tn)) } }
                                if mrow == 1 { if tn != ".." { clipboard = joinDir(cwd, tn)  clipOp = "cut" } }
                                if mrow == 2 { if tn != ".." { clipboard = joinDir(cwd, tn)  clipOp = "copy" } }
                                if mrow == 3 { if clipboard != "" { if clipOp == "cut" { shellRun("mv --backup=numbered '" + clipboard + "' '" + cwd + "/' 2>/dev/null")  clipboard = "" } else { shellRun("cp -r --backup=numbered '" + clipboard + "' '" + cwd + "/' 2>/dev/null") }  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt } }
                                if mrow == 4 { if tn != ".." { sel = menuTarget  mode = 1  textBuf = tn } }
                                if mrow == 5 { if tn != ".." { shellRun("gio trash '" + joinDir(cwd, tn) + "' 2>/dev/null || trash-put '" + joinDir(cwd, tn) + "' 2>/dev/null")  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt } }
                                if mrow == 6 { shellRun("mkdir -p '" + cwd + "/New Folder'")  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt }
                                if mrow == 7 { openTerm(cwd) }
                            }
                            menuOpen = 0  dirty = 1
                        } else {
                        if mouseY < HDRH() && mouseX < 120 {
                            if mouseX >= 9 && mouseX < 39 { if histIdx > 0 { histIdx -= 1  cwd = nthLine(hist, histIdx)  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt  sel = 0  scroll = 0  mode = 0  textBuf = ""  marked = ""  fromHist = 1  wlSetTitle(fd, TOP, "cortex - " + basename(cwd)) } }
                            if mouseX >= 45 && mouseX < 75 { if histIdx < countLines(hist) - 1 { histIdx += 1  cwd = nthLine(hist, histIdx)  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt  sel = 0  scroll = 0  mode = 0  textBuf = ""  marked = ""  fromHist = 1  wlSetTitle(fd, TOP, "cortex - " + basename(cwd)) } }
                            if mouseX >= 81 && mouseX < 111 { allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt  places = buildPlaces() }
                            dirty = 1
                        }
                        if mouseY < HDRH() && mouseX >= W - 153 {
                            if hHit(hSearchX(W), mouseX) == 1 { mode = 2  textBuf = "" }
                            if hHit(hViewX(W), mouseX) == 1 { viewMode = 1 - viewMode  scroll = 0 }
                            if hHit(hMenuX(W), mouseX) == 1 { menuTarget = sel  menuOpen = 1  menuX = hMenuX(W) - 152  menuY = HDRH() }
                            if hHit(hCloseX(W), mouseX) == 1 { running = 0 }
                            dirty = 1
                        } else { if mouseY < HDRH() && mouseX >= 136 {
                            let cp = crumbHit(cwd, 136, W - 136 - 168, mouseX)
                            if cp != "" && cp != cwd { cwd = cp  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt  sel = 0  scroll = 0  mode = 0  textBuf = ""  marked = ""  wlSetTitle(fd, TOP, "cortex - " + basename(cwd))  dirty = 1 }
                        } }
                        if mouseX < SIDEW() && mouseY >= PLY() - 4 {
                            let prow = (mouseY - PLY() + 4) / 30
                            if prow >= 0 && prow < countLines(places) {
                                let tgt = plPath(nthLine(places, prow))
                                if tgt != cwd { cwd = tgt  allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt  sel = 0  scroll = 0  mode = 0  textBuf = ""  marked = ""  wlSetTitle(fd, TOP, "cortex - " + basename(cwd)) }
                            }
                            dirty = 1
                        }
                        if mouseX >= SIDEW() && mouseY >= HDRH() {
                            let cols = colsFor(W, viewMode)
                            let ccol = (mouseX - SIDEW() - PAD()) / cellWFor(W, viewMode)
                            let crow = (mouseY - HDRH() - PAD()) / rowHFor(viewMode) + scroll
                            let idx = crow * cols + ccol
                            if ccol >= 0 && ccol < cols && idx >= 0 && idx < countLines(ent) {
                                if idx == sel && entIsDir(ent, idx) {
                                    let nm = entName(ent, idx)
                                    if nm == ".." { cwd = parentDir(cwd) } else { cwd = joinDir(cwd, nm) }
                                    allEnt = buildEntries(cwd, showHidden, sortMode)  ent = allEnt  sel = 0  scroll = 0  mode = 0  textBuf = ""  marked = ""
                                    wlSetTitle(fd, TOP, "cortex - " + basename(cwd))
                                } else { sel = idx }
                            }
                            dirty = 1
                        }
                        }
                    }
                    if wlU32(eb, off + 16) == 273 && wlU32(eb, off + 20) == 1 {
                        if mouseX >= SIDEW() && mouseY >= HDRH() {
                            let cols = colsFor(W, viewMode)
                            let ccol = (mouseX - SIDEW() - PAD()) / cellWFor(W, viewMode)
                            let crow = (mouseY - HDRH() - PAD()) / rowHFor(viewMode) + scroll
                            let idx = crow * cols + ccol
                            if ccol >= 0 && ccol < cols && idx >= 0 && idx < countLines(ent) { sel = idx  menuTarget = idx }
                        }
                        menuOpen = 1  menuX = mouseX  menuY = mouseY
                        if menuX + 188 > W { menuX = W - 192 }
                        if menuY + 224 > H { menuY = H - 224 }
                        dirty = 1
                    }
                }
                if obj == PTR && op == 4 {
                    if wlU32(eb, off + 16) > 2000000000 { if scroll > 0 { scroll -= 1 } }
                    else { scroll += 1 }
                    let cc = colsFor(W, viewMode)
                    let trows = (countLines(ent) + cc - 1) / cc
                    let visr = (H - HDRH() - PAD() - 10) / rowHFor(viewMode)
                    if scroll > trows - visr { scroll = trows - visr }
                    if scroll < 0 { scroll = 0 }
                    dirty = 1
                }
                off = off + s
            }
        }
        if cwd != lastCwd {
            if fromHist == 0 { hist = truncLines(hist, histIdx + 1) + cwd + "\n"  histIdx = countLines(hist) - 1 }
            lastCwd = cwd  fromHist = 0
        }
        if dirty == 1 && running == 1 {
            // free previous frame (ids never reused — keep allocating fresh)
            if prevBuf != 0 { wlBufferDestroy(fd, prevBuf)  wlPoolDestroy(fd, prevPool)  sockClose(prevMfd) }
            let pool = nextId  let buf = nextId + 1  nextId = nextId + 2
            let stride = W * 4
            let sz = stride * H
            let m = memfdCreate(sz)
            let px = mmapShared(m, sz)
            draw(px, W, H, font, cwd, ent, sel, scroll, folderBig, fileBig, docBig, dlBig, musicBig, picBig, vidBig, deskBig, imageBig, archiveBig, mediaBig, places, folderSml, mode, textBuf, marked, viewMode, flSml, menuOpen, menuX, menuY, homeSml, driveSml, docSml, dlSml, musSml, picSml, vidSml, deskSml)
            wlCreatePool(fd, SHM, pool, m, sz)
            wlPoolCreateBuffer(fd, pool, buf, 0, W, H, stride, 1)
            wlSurfaceAttach(fd, SURF, buf, 0, 0)
            wlDamage(fd, SURF, 0, 0, W, H)
            wlCommit(fd, SURF)
            prevBuf = buf  prevPool = pool  prevMfd = m
        }
    }
    sockClose(fd)
}
