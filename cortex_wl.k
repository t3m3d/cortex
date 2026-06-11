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
func buildEntries(cwd) {
    let raw = exec("ls -1p '" + cwd + "' 2>/dev/null")
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
    emit out
}
func plLabel(s) { let t = indexOf(s, fromCharCode(9))  emit substring(s, 0, t) }
func plPath(s)  { let t = indexOf(s, fromCharCode(9))  emit substring(s, t + 1, len(s)) }
func PLY()      { emit HDRH() + 36 }   // first place row y
func entIsDir(e, r) { emit nthLine(e, r)[0] == "d" }
func entName(e, r)  { let l = nthLine(e, r)  emit substring(l, 2, len(l)) }
func parentDir(cwd) {
    let i = len(cwd) - 1
    while i > 0 && cwd[i] != "/" { i = i - 1 }
    if i <= 0 { emit "/" }
    emit substring(cwd, 0, i)
}
func joinDir(cwd, name) { if cwd == "/" { emit "/" + name }  emit cwd + "/" + name }
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
    shellRun("convert -background none -density " + (sz * 4) + " '" + svgf + "' -resize " + sz + "x" + sz + " -depth 8 BGRA:- 2>/dev/null | xxd -p -c 0 > '" + hexf + "'")
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
func draw(px, W, H, font, cwd, ent, sel, scroll, folderBig, fileBig, docBig, dlBig, musicBig, picBig, vidBig, deskBig, imageBig, archiveBig, mediaBig, places, folderSml) {
    fbClear(px, W, H, cBg())
    fbFillRect(px, W, 0, HDRH(), SIDEW(), H - HDRH(), cSide())
    fbDrawText(px, W, H, font, 16, HDRH() + 16, "Quick access", cMuted())
    let np = countLines(places)
    let p = 0
    while p < np {
        let line = nthLine(places, p)
        let py = PLY() + p * 30
        if plPath(line) == cwd { fbRoundRect(px, W, H, 6, py - 4, SIDEW() - 12, 28, 8, cSel()) }
        fbBlitAlpha(px, W, H, 14, py - 4, folderSml, 24, 24)
        fbDrawText(px, W, H, font, 44, py + 8, plLabel(line), cText())
        p += 1
    }
    fbFillRect(px, W, 0, 0, W, HDRH(), cHdr())
    fbFillCircle(px, W, H, 24, 24, 15, cSide())
    fbFillCircle(px, W, H, 60, 24, 15, cSide())
    fbFillCircle(px, W, H, 96, 24, 15, cSide())
    fbDrawText(px, W, H, font, 18, 20, "<", cGreenB())
    fbDrawText(px, W, H, font, 54, 20, ">", cGreenB())
    fbDrawText(px, W, H, font, 90, 20, "o", cGreenB())
    fbRoundRect(px, W, H, 124, 8, W - 124 - 16, 32, 8, cSide())
    fbDrawText(px, W, H, font, 136, 18, cwd, cText())
    let cols = gridCols(W)
    let n = countLines(ent)
    let i = 0
    while i < n {
        let col = i - i / cols * cols
        let row = i / cols
        if row >= scroll {
            let cx = SIDEW() + PAD() + col * CELLW()
            let cy = HDRH() + PAD() + (row - scroll) * CELLH()
            if cy < H - 10 {
                if i == sel { fbRoundRect(px, W, H, cx - 6, cy - 6, CELLW() - 16, CELLH() - 12, 10, cSel()) }
                let nm = entName(ent, i)
                let ic = fileIconFor(nm, fileBig, imageBig, archiveBig, mediaBig)
                if entIsDir(ent, i) { ic = folderIconFor(nm, folderBig, docBig, dlBig, musicBig, picBig, vidBig, deskBig) }
                fbBlitAlpha(px, W, H, cx + (CELLW() - 28 - IBIG()) / 2, cy + 2, ic, IBIG(), IBIG())
                let maxc = (CELLW() - 24) / 8
                let lbl = nm
                if len(lbl) > maxc { lbl = substring(lbl, 0, maxc) }
                let lx = cx + (CELLW() - 28 - len(lbl) * 8) / 2
                fbDrawText(px, W, H, font, lx, cy + 66, lbl, cText())
            }
        }
        i += 1
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
    let ent = buildEntries(cwd)
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
    let places     = buildPlaces()
    let nextId = 12
    let prevBuf = 0  let prevPool = 0  let prevMfd = 0
    let mouseX = 0  let mouseY = 0

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
                        let cols = gridCols(W)
                        if kc == 114 { if sel + 1 < countLines(ent) { sel += 1 } }          // Right
                        if kc == 113 { if sel > 0 { sel -= 1 } }                            // Left
                        if kc == 116 { if sel + cols < countLines(ent) { sel += cols } }    // Down
                        if kc == 111 { if sel - cols >= 0 { sel -= cols } }                 // Up
                        if kc == 36 {                                                       // Enter
                            if entIsDir(ent, sel) {
                                let nm = entName(ent, sel)
                                if nm == ".." { cwd = parentDir(cwd) } else { cwd = joinDir(cwd, nm) }
                                ent = buildEntries(cwd)  sel = 0  scroll = 0
                                wlSetTitle(fd, TOP, "cortex - " + basename(cwd))
                            }
                        }
                        if kc == 22 { cwd = parentDir(cwd)  ent = buildEntries(cwd)  sel = 0  scroll = 0 }  // Backspace
                        if kc == 9 { running = 0 }                                          // Esc
                        // keep selection visible
                        let vis = (H - HDRH() - PAD() - 10) / CELLH()
                        let srow = sel / cols
                        if srow < scroll { scroll = srow }
                        if srow >= scroll + vis { scroll = srow - vis + 1 }
                        dirty = 1
                    }
                }
                if obj == PTR && op == 0 { mouseX = wlFixed(eb, off + 16)  mouseY = wlFixed(eb, off + 20) }
                if obj == PTR && op == 2 { mouseX = wlFixed(eb, off + 12)  mouseY = wlFixed(eb, off + 16) }
                if obj == PTR && op == 3 {
                    if wlU32(eb, off + 16) == 272 && wlU32(eb, off + 20) == 1 {
                        if mouseX < SIDEW() && mouseY >= PLY() - 4 {
                            let prow = (mouseY - PLY() + 4) / 30
                            if prow >= 0 && prow < countLines(places) {
                                let tgt = plPath(nthLine(places, prow))
                                if tgt != cwd { cwd = tgt  ent = buildEntries(cwd)  sel = 0  scroll = 0  wlSetTitle(fd, TOP, "cortex - " + basename(cwd)) }
                            }
                            dirty = 1
                        }
                        if mouseX >= SIDEW() && mouseY >= HDRH() {
                            let cols = gridCols(W)
                            let ccol = (mouseX - SIDEW() - PAD()) / CELLW()
                            let crow = (mouseY - HDRH() - PAD()) / CELLH() + scroll
                            let idx = crow * cols + ccol
                            if ccol >= 0 && ccol < cols && idx >= 0 && idx < countLines(ent) {
                                if idx == sel && entIsDir(ent, idx) {
                                    let nm = entName(ent, idx)
                                    if nm == ".." { cwd = parentDir(cwd) } else { cwd = joinDir(cwd, nm) }
                                    ent = buildEntries(cwd)  sel = 0  scroll = 0
                                    wlSetTitle(fd, TOP, "cortex - " + basename(cwd))
                                } else { sel = idx }
                            }
                            dirty = 1
                        }
                    }
                }
                if obj == PTR && op == 4 {
                    if wlU32(eb, off + 16) > 2000000000 { if scroll > 0 { scroll -= 1 } }
                    else { scroll += 1 }
                    let cc = gridCols(W)
                    let trows = (countLines(ent) + cc - 1) / cc
                    let visr = (H - HDRH() - PAD() - 10) / CELLH()
                    if scroll > trows - visr { scroll = trows - visr }
                    if scroll < 0 { scroll = 0 }
                    dirty = 1
                }
                off = off + s
            }
        }
        if dirty == 1 && running == 1 {
            // free previous frame (ids never reused — keep allocating fresh)
            if prevBuf != 0 { wlBufferDestroy(fd, prevBuf)  wlPoolDestroy(fd, prevPool)  sockClose(prevMfd) }
            let pool = nextId  let buf = nextId + 1  nextId = nextId + 2
            let stride = W * 4
            let sz = stride * H
            let m = memfdCreate(sz)
            let px = mmapShared(m, sz)
            draw(px, W, H, font, cwd, ent, sel, scroll, folderBig, fileBig, docBig, dlBig, musicBig, picBig, vidBig, deskBig, imageBig, archiveBig, mediaBig, places, folderSml)
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
