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

// ── render ──────────────────────────────────────────────────────────────────
func draw(px, W, H, font, cwd, ent, sel, scroll) {
    fbClear(px, W, H, cBg())
    fbFillRect(px, W, 0, HDRH(), SIDEW(), H - HDRH(), cSide())
    fbDrawText(px, W, H, font, 14, HDRH() + 14, "Quick access", cMuted())
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
                if entIsDir(ent, i) { drawFolder(px, W, H, cx + (CELLW() - 28 - 56) / 2, cy + 6) }
                else { drawFile(px, W, H, cx + (CELLW() - 28 - 40) / 2, cy + 4) }
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
    let nextId = 12
    let prevBuf = 0  let prevPool = 0  let prevMfd = 0

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
            draw(px, W, H, font, cwd, ent, sel, scroll)
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
