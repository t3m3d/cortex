// cortex — a GUI file manager for Linux, in pure Krypton over raw X11.
// M7: title bar + toolbar (Back / Forward / Refresh + typeable address bar),
// quick-access sidebar, icon-grid main view. Sets WM_CLASS/WM_NAME ("cortex")
// so Hyprland & other WMs can target it with window rules / per-app keybinds.
//
//   Build/run:  KRYPTON_ROOT=<krypton> kcc -r cortex.k

import "k:x11"

// ── geometry / colors (24-bit TrueColor: pixel = R<<16 | G<<8 | B) ─────
func W()         { emit 1000 }
func H()         { emit 620 }
func TITLEH()    { emit 26 }
func TBARH()     { emit 52 }
func TOP()       { emit 78 }          // TITLEH + TBARH (content origin y)
func STATUSH()   { emit 24 }          // bottom status bar
func TBICON()    { emit 22 }          // toolbar button glyph size
func ROWH()      { emit 24 }
func SIDEBAR()   { emit 190 }
func rgb(r, g, b) { emit r * 65536 + g * 256 + b }
func pick(d, l, dk) { if d == 1 { emit dk }  emit l }
// ── theme palette (d = 1 dark, 0 light) ──────────────────────────────
func cWhite()     { emit 16777215 }
func cBlack()     { emit 0 }
func cGreen()     { emit 2073699 }   // 0x1FA463 accent (both themes)
func cFolder()    { emit 15909198 }  // fallback rects
func cFile()      { emit 12434877 }
func cBg(d)       { emit pick(d, rgb(255,255,255), rgb(27,29,34)) }     // window / main / rows
func cText(d)     { emit pick(d, rgb(32,33,36),    rgb(227,229,233)) }
func cTitle(d)    { emit pick(d, rgb(237,239,242), rgb(22,24,28)) }
func cTitleTx(d)  { emit pick(d, rgb(60,64,67),    rgb(200,205,212)) }
func cToolbar(d)  { emit pick(d, rgb(222,227,233), rgb(36,39,46)) }
func cBtn(d)      { emit pick(d, rgb(233,237,241), rgb(46,50,59)) }     // soft circle
func cAddr(d)     { emit pick(d, rgb(255,255,255), rgb(42,46,54)) }
func cAddrBd(d)   { emit pick(d, rgb(194,200,208), rgb(60,65,75)) }
func cSide(d)     { emit pick(d, rgb(241,243,245), rgb(32,35,41)) }
func cSideTx(d)   { emit pick(d, rgb(60,64,67),    rgb(192,197,205)) }
func cDivider(d)  { emit pick(d, rgb(214,219,224), rgb(51,55,63)) }
func cSel(d)      { emit pick(d, rgb(31,164,99),   rgb(52,199,126)) }   // krypton green
func cSelLite(d)  { emit pick(d, rgb(216,242,228), rgb(26,58,44)) }     // soft green selection
func cMenu(d)     { emit pick(d, rgb(255,255,255), rgb(40,43,50)) }
func cMenuHi(d)   { emit pick(d, rgb(31,164,99),   rgb(52,199,126)) }
func MENUW()      { emit 168 }
func MENUROW()    { emit 26 }
func menuItems()  { emit "Open\nCut\nCopy\nPaste\nRename\nMove to Trash\nNew Folder\nOpen Terminal\nDuplicate\nCompress\nProperties" }
func helpText() {
    emit "cortex — keyboard shortcuts\n \nEnter / double-click    open file or folder\nBackspace               go up\nAlt+Left / Alt+Right    back / forward\nAlt+Home                home folder\ntype a name             jump to it\narrows / PageUp/Down     move selection\nHome / End              first / last\nCtrl+L                  edit address bar\nF2                      rename\nSpace                   mark / unmark item\nCtrl+A                  select all\nCtrl+Shift+A            clear selection\nDelete                  trash selection (or item)\nCtrl+C / X / V          copy / cut / paste\nCtrl+N                  new file\nCtrl+Shift+N            new folder\nCtrl+I                  properties\nCtrl+Shift+C            copy path\nCtrl+H                  toggle hidden\nCtrl+S                  cycle sort\nCtrl+F                  search (Enter = subfolders)\nF5                      refresh\nCtrl+D                  bookmark dir\nCtrl+Shift+D            remove bookmark\nCtrl+E                  extract archive\nCtrl+Shift+Z            compress to zip\nCtrl+Shift+R            duplicate\nCtrl+Shift+T            trash view\nCtrl+M                  mount all drives\nF4                      open terminal here\nright-click             context menu\nright-click a drive     unmount it\nF1                      this help\nEsc                     close / quit"
}
func ICONSML()   { emit 20 }
func ICONBIG()   { emit 96 }
func CELLW()     { emit 160 }
func CELLH()     { emit 150 }
func GRIDPAD()   { emit 16 }
func charW()     { emit 6 }

// toolbar button geometry — three 36px white squares, then the address bar
func BTNW()   { emit 36 }
func btnY()   { emit TITLEH() + 8 }
func backX()  { emit 10 }
func fwdX()   { emit 52 }
func refX()   { emit 94 }
func addrX()  { emit 142 }

// ── custom cortex icons (edit these SVGs to restyle) ──────────────────
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

func driveSvg() {
    emit "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24'>" +
         "<rect x='3' y='7' width='18' height='10' rx='2.5' fill='#1E9E5E'/>" +
         "<rect x='3' y='7' width='18' height='5' rx='2.5' fill='#34C77E'/>" +
         "<circle cx='17.5' cy='14' r='1.3' fill='#EAF7F0'/></svg>"
}

// toolbar symbols (green), rasterized like the file icons
func backSvg() {
    emit "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24'>" +
         "<path d='M16 4 L7 12 L16 20 Z' fill='#1FA463'/></svg>"
}
func fwdSvg() {
    emit "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24'>" +
         "<path d='M8 4 L17 12 L8 20 Z' fill='#1FA463'/></svg>"
}
func reloadSvg() {
    emit "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24'>" +
         "<path d='M19 12 a7 7 0 1 1 -2.05-4.95' fill='none' stroke='#1FA463' stroke-width='2.6' stroke-linecap='round'/>" +
         "<path d='M19 4 L19 9 L14 9 Z' fill='#1FA463'/></svg>"
}

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
func iconBytes(sz) { emit sz * sz * 4 }

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

// ── string helpers ────────────────────────────────────────────────────
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
// first `n` lines of s, each with a trailing newline
func truncLines(s, n) {
    let out = ""
    let i = 0
    while i < n {
        out = out + nthLine(s, i) + "\n"
        i += 1
    }
    emit out
}
func basename(p) {
    let i = len(p) - 1
    while i >= 0 && p[i] != "/" { i = i - 1 }
    emit substring(p, i + 1, len(p))
}
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
// classify a filename into an icon kind: image / archive / media / file
func extKind(name) {
    let e = lastExt(name)
    if e == "png" || e == "jpg" || e == "jpeg" || e == "gif" || e == "bmp" || e == "webp" || e == "svg" || e == "ico" || e == "tiff" { emit "image" }
    if e == "zip" || e == "tar" || e == "gz" || e == "tgz" || e == "bz2" || e == "xz" || e == "7z" || e == "rar" || e == "zst" { emit "archive" }
    if e == "mp3" || e == "wav" || e == "flac" || e == "ogg" || e == "m4a" || e == "opus" || e == "mp4" || e == "mkv" || e == "webm" || e == "avi" || e == "mov" { emit "media" }
    emit "file"
}

// ── icon rasterization ────────────────────────────────────────────────
func rasterHex(name, svg, sz) {
    let dir = homeDir() + "/.cache/cortex"
    exec("mkdir -p '" + dir + "'")
    let svgf = dir + "/" + name + ".svg"
    let hexf = dir + "/" + name + "-" + sz + ".hex"
    writeFile(svgf, svg)
    exec("convert -background none -density " + (sz * 4) + " '" + svgf + "' -resize " + sz + "x" + sz + " -depth 8 BGRA:- 2>/dev/null | xxd -p -c 0 > '" + hexf + "'")
    emit chomp(readFile(hexf))
}

// grid columns / label clip
func gridCols(w) {
    let c = (w - SIDEBAR() - 2 * GRIDPAD()) / CELLW()
    if c < 1 { emit 1 }
    emit c
}
// max grid-row scroll given item count, columns and the viewport height
func maxScroll(nrows, cols, viewH) {
    let totalRows = (nrows + cols - 1) / cols
    let visRows = viewH / CELLH()
    let m = totalRows - visRows
    if m < 0 { m = 0 }
    emit m
}
func clipLabel(name) {
    let max = (CELLW() - 6) / charW()
    if len(name) <= max { emit name }
    emit substring(name, 0, max - 1) + "."
}

// ── X11 US-keyboard keycode -> char (for the address bar) ─────────────
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

// ── places (quick-access sidebar) ──────────────────────────────────────
func homeDir() { emit chomp(exec("printf %s \"$HOME\"")) }

// dark mode? config file wins (~/.config/cortex/config: theme=dark|light|auto),
// else the system preference (gsettings color-scheme / gtk-theme), else light.
func detectDark() {
    let cfg = homeDir() + "/.config/cortex/config"
    let t = chomp(exec("grep -iE '^[ ]*theme[ ]*=' '" + cfg + "' 2>/dev/null | head -1 | sed 's/[^=]*=//' | tr -d ' '"))
    if t == "dark" { emit 1 }
    if t == "light" { emit 0 }
    // auto / unset -> system
    let cs = exec("gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null")
    if contains(cs, "dark") { emit 1 }
    let gtk = exec("gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null")
    if contains(gtk, "dark") || contains(gtk, "Dark") { emit 1 }
    emit 0
}
func existsDir(p) { emit chomp(exec("test -d '" + p + "' && echo y")) == "y" }
func bookmarksPath() { emit homeDir() + "/.config/cortex/bookmarks" }
func lastDirPath() { emit homeDir() + "/.config/cortex/lastdir" }
func addPlace(out, label, path) { emit out + label + "|" + path + "\n" }
func maybeAdd(out, label, path) {
    if existsDir(path) { emit addPlace(out, label, path) }
    emit out
}
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
func addBookmark(cwd) {
    exec("mkdir -p \"$(dirname '" + bookmarksPath() + "')\"")
    exec("echo '" + cwd + "' >> '" + bookmarksPath() + "'")
}

// the n-th '|'-separated field of s
func fieldAt(s, n) {
    let start = 0
    let f = 0
    let i = 0
    while i <= len(s) {
        if i == len(s) || s[i] == "|" {
            if f == n { emit substring(s, start, i) }
            f += 1
            start = i + 1
        }
        i += 1
    }
    emit ""
}

// External/removable drives via lsblk — listed whether or not they're mounted
// (most setups don't auto-mount). One "label|mountpoint|device" per line;
// mountpoint is empty for unmounted drives (click mounts them via udisksctl).
func buildDevices() {
    emit chomp(exec("lsblk -Pno NAME,LABEL,MOUNTPOINT,RM,TYPE,FSTYPE 2>/dev/null | while read l; do eval \"$l\"; if [ \"$TYPE\" = part ] && [ \"$RM\" = 1 ] && [ -n \"$FSTYPE\" ]; then printf '%s|%s|%s\\n' \"${LABEL:-$NAME}\" \"$MOUNTPOINT\" \"/dev/$NAME\"; fi; done"))
}
func mountAllDrives() {
    exec("lsblk -Pno NAME,MOUNTPOINT,RM,TYPE,FSTYPE 2>/dev/null | while read l; do eval \"$l\"; if [ \"$TYPE\" = part ] && [ \"$RM\" = 1 ] && [ -n \"$FSTYPE\" ] && [ -z \"$MOUNTPOINT\" ]; then udisksctl mount -b \"/dev/$NAME\" >/dev/null 2>&1; fi; done")
}

// Combined sidebar model: lines "kind|label|path". kind h=header (not clickable),
// p=place (folder icon), d=device (drive icon).
func sbItem(out, kind, label, path) { emit out + kind + "|" + label + "|" + path + "\n" }
func buildSidebar() {
    let out = sbItem("", "h", "Quick access", "")
    let pl = buildPlaces()
    let n = countLines(pl)
    let i = 0
    while i < n {
        let ln = nthLine(pl, i)
        out = sbItem(out, "p", beforeBar(ln), afterBar(ln))
        i += 1
    }
    let dv = buildDevices()
    let m = countLines(dv)
    if m > 0 {
        out = sbItem(out, "h", "Drives", "")
        let j = 0
        while j < m {
            let ln = nthLine(dv, j)
            out = sbItem(out, "d", beforeBar(ln), afterBar(ln))
            j += 1
        }
    }
    emit out
}

// ── directory model ────────────────────────────────────────────────────
// open / file-op helpers
func openFile(path) { exec("setsid xdg-open '" + path + "' >/dev/null 2>&1 &") }
func newFolder(cwd) { exec("mkdir -p '" + cwd + "/New Folder'") }
func renameTo(cwd, old, nw) { exec("mv -n '" + cwd + "/" + old + "' '" + cwd + "/" + nw + "' 2>/dev/null") }
func trashItem(path) { exec("gio trash '" + path + "' 2>/dev/null || trash-put '" + path + "' 2>/dev/null || true") }
func trashMarked(cwd, marked) {
    let n = countLines(marked)
    let i = 0
    while i < n {
        let nm = nthLine(marked, i)
        if nm != "" && nm != ".." { trashItem(joinDir(cwd, nm)) }
        i += 1
    }
}
// newline-joined absolute paths of the marked entries (for the clipboard)
func clipFromMarked(cwd, marked) {
    let out = ""
    let n = countLines(marked)
    let i = 0
    while i < n {
        let nm = nthLine(marked, i)
        if nm != "" && nm != ".." { let p = joinDir(cwd, nm)  if out == "" { out = p } else { out = out + fromCharCode(10) + p } }
        i += 1
    }
    emit out
}
// paste each clipboard path (newline-joined) into cwd; op = "cut" moves, else copies
func pasteClip(cwd, clipboard, op) {
    let n = countLines(clipboard)
    let i = 0
    while i < n {
        let src = nthLine(clipboard, i)
        if src != "" {
            if op == "cut" { exec("mv --backup=numbered '" + src + "' '" + cwd + "/' 2>/dev/null") }
            else { exec("cp -r --backup=numbered '" + src + "' '" + cwd + "/' 2>/dev/null") }
        }
        i += 1
    }
}
func newFile(cwd) { exec("touch '" + cwd + "/New File'") }
func copyPath(path) { exec("printf '%s' '" + path + "' | wl-copy 2>/dev/null || printf '%s' '" + path + "' | xclip -sel clip 2>/dev/null") }
func showProps(path, name) {
    exec("notify-send -a cortex 'cortex — " + name + "' \"$(stat --printf 'Size: %s bytes\\nType: %F\\nPerms: %A\\nModified: %y' '" + path + "' 2>/dev/null)\" 2>/dev/null")
}
func removeBookmark(cwd) {
    let bp = bookmarksPath()
    exec("grep -vxF '" + cwd + "' '" + bp + "' > '" + bp + ".tmp' 2>/dev/null && mv '" + bp + ".tmp' '" + bp + "' 2>/dev/null")
}
func extractArchive(cwd, name) {
    exec("cd '" + cwd + "' && (bsdtar -xf '" + name + "' 2>/dev/null || tar xf '" + name + "' 2>/dev/null || unzip -o '" + name + "' 2>/dev/null)")
}
func duplicateEntry(cwd, name) {
    exec("cd '" + cwd + "' && cp -r --backup=numbered '" + name + "' '" + name + ".copy' 2>/dev/null")
}
func compressEntry(cwd, name) {
    exec("cd '" + cwd + "' && (zip -r -q '" + name + ".zip' '" + name + "' 2>/dev/null || tar czf '" + name + ".tar.gz' '" + name + "' 2>/dev/null)")
}
func openTerminal(cwd) {
    exec("cd '" + cwd + "' && setsid sh -c '${TERMINAL:-$(command -v ghostty kitty alacritty foot wezterm xterm 2>/dev/null | head -1)}' >/dev/null 2>&1 &")
}

func sortName(m) { if m == 1 { emit "size" }  if m == 2 { emit "date" }  emit "name" }
func buildEntries(cwd, showHidden, sortMode) {
    let flag = "-1p"
    if showHidden == 1 { flag = flag + "A" }
    if sortMode == 1 { flag = flag + "S" }   // size
    if sortMode == 2 { flag = flag + "t" }   // date
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
func entryIsDir(entries, row) { emit nthLine(entries, row)[0] == "d" }
func entryName(entries, row)  { let l = nthLine(entries, row)  emit substring(l, 2, len(l)) }
func rowOfName(entries, name) {
    let n = countLines(entries)
    let i = 0
    while i < n {
        if entryName(entries, i) == name { emit i }
        i += 1
    }
    emit -1
}
// multi-select: `marked` is a newline-joined set of entry NAMES in the current dir.
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
        let nm = entryName(entries, i)
        if nm != ".." { if out == "" { out = nm } else { out = out + fromCharCode(10) + nm } }
        i += 1
    }
    emit out
}

func lc1(c) { if c >= "A" && c <= "Z" { emit fromCharCode(charCode(c) + 32) }  emit c }
func hasPrefixCI(s, p) {
    if len(p) > len(s) { emit 0 }
    let i = 0
    while i < len(p) {
        if lc1(s[i]) != lc1(p[i]) { emit 0 }
        i += 1
    }
    emit 1
}
func containsCI(s, q) {
    let n = len(s)
    let m = len(q)
    if m == 0 { emit 1 }
    let i = 0
    while i <= n - m {
        if hasPrefixCI(substring(s, i, i + m), q) == 1 { emit 1 }
        i += 1
    }
    emit 0
}
// recursive search: find -printf '%y %P' emits 'd path'/'f path' lines that
// match cortex's entry format exactly; relative paths work with joinDir.
func deepFind(cwd, q) {
    if q == "" { emit "d ..\n" }
    emit "d ..\n" + chomp(exec("cd '" + cwd + "' && find . -mindepth 1 -iname '*" + q + "*' -not -path '*/.*/*' -printf '%y %P\\n' 2>/dev/null | head -300"))
}
// filter an entry list to names containing `q` (case-insensitive); keeps ".."
func filterEntries(all, q) {
    if q == "" { emit all }
    let out = ""
    let n = countLines(all)
    let i = 0
    while i < n {
        let line = nthLine(all, i)
        let nm = substring(line, 2, len(line))
        if nm == ".." { out = out + line + "\n" }
        else { if containsCI(nm, q) == 1 { out = out + line + "\n" } }
        i += 1
    }
    emit out
}
// first entry index whose name starts with `prefix` (case-insensitive), or -1
func findPrefix(entries, prefix) {
    let n = countLines(entries)
    let i = 0
    while i < n {
        if hasPrefixCI(entryName(entries, i), prefix) == 1 { emit i }
        i += 1
    }
    emit 0 - 1
}

func buildStatus(cwd, entries) {
    let n = countLines(entries) - 1   // minus ".."
    if n < 0 { n = 0 }
    let free = chomp(exec("df -h --output=avail '" + cwd + "' 2>/dev/null | tail -1 | tr -d ' '"))
    emit n + " items     " + free + " free"
}
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
// borderless circular button that blends into the toolbar: a soft filled
// circle (cBtn, a hair off the bar colour) with the green glyph composited
// onto that same colour so its square corners vanish inside the circle.
func drawBtn(fd, win, gcCircle, x, raw, scratch, haveIcons, dark) {
    let d = 34
    let off = (BTNW() - d) / 2
    x11FillArc(fd, win, gcCircle, x + off, btnY() + off, d, d, 0, 23040)
    if haveIcons == 1 {
        let io = (BTNW() - TBICON()) / 2
        blitIcon(fd, win, gcCircle, x + io, btnY() + io, raw, scratch, cBtn(dark), TBICON())
    }
}

// address-bar text clipped to its field (shows the tail when too long)
func addrShow(text, fieldW, focused) {
    let max = fieldW / charW() - 1
    let t = text
    if focused == 1 { t = text + "_" }
    if len(t) <= max { emit t }
    emit "." + substring(t, len(t) - max + 1, len(t))
}

func repaint(fd, info, cwd, entries, sel, places, w, h, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) {
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
    let gcTitle = x11GenId(info, 16)
    let gcTitleTx = x11GenId(info, 17)
    let gcBtn = x11GenId(info, 18)
    let gcAddr = x11GenId(info, 19)
    let gcAddrBd = x11GenId(info, 20)
    let gcBtnBd = x11GenId(info, 21)
    let gcAddrTx = x11GenId(info, 22)
    let gcStat = x11GenId(info, 23)

    let sy = h - STATUSH()
    // base + chrome
    x11FillRect(fd, win, gcClear, 0, 0, w, h)
    x11FillRect(fd, win, gcSide, 0, TOP(), SIDEBAR(), sy - TOP())
    x11FillRect(fd, win, gcDiv, SIDEBAR(), TOP(), 1, sy - TOP())

    // title bar
    x11FillRect(fd, win, gcTitle, 0, 0, w, TITLEH())
    x11ImageText8(fd, win, gcTitleTx, 10, 18, "cortex   " + cwd)

    // toolbar
    x11FillRect(fd, win, gcBar, 0, TITLEH(), w, TBARH())
    drawBtn(fd, win, gcBtn, backX(), backRaw, scratch, haveIcons, dark)
    drawBtn(fd, win, gcBtn, fwdX(), fwdRaw, scratch, haveIcons, dark)
    drawBtn(fd, win, gcBtn, refX(), reloadRaw, scratch, haveIcons, dark)
    // address field (aligned with the buttons)
    let afW = w - addrX() - 10
    x11FillRect(fd, win, gcAddrBd, addrX(), btnY(), afW, BTNW())
    x11FillRect(fd, win, gcAddr, addrX() + 1, btnY() + 1, afW - 2, BTNW() - 2)
    let shown = cwd
    if addrFocused == 1 { shown = addr }
    x11ImageText8(fd, win, gcAddrTx, addrX() + 8, btnY() + BTNW() / 2 + 4, addrShow(shown, afW - 12, addrFocused))

    // sidebar — combined model: headers + places (folder icon) + devices (drive)
    let np = countLines(places)
    let p = 0
    while p < np {
        let y = TOP() + p * ROWH()
        let line = nthLine(places, p)
        let kind = fieldAt(line, 0)
        if kind == "h" {
            x11ImageText8(fd, win, gcSideTx, 12, y + 17, fieldAt(line, 1))
        } else {
            let rowBg = cSide(dark)
            if fieldAt(line, 2) == cwd { x11FillRect(fd, win, gcSelBox, 0, y, SIDEBAR(), ROWH())  rowBg = cSelLite(dark) }
            if haveIcons == 1 {
                if kind == "d" { blitIcon(fd, win, gcRow, 10, y + 2, driveSml, scratch, rowBg, ICONSML()) }
                else { blitIcon(fd, win, gcRow, 10, y + 2, folderSml, scratch, rowBg, ICONSML()) }
            }
            x11ImageText8(fd, win, gcSideTx, 36, y + 17, fieldAt(line, 1))
        }
        p += 1
    }

    // main icon grid
    let bx = SIDEBAR()
    let cols = gridCols(w)
    let nrows = countLines(entries)
    let i = 0
    while i < nrows {
        let col = i - i / cols * cols
        let rowi = i / cols
        if rowi >= scroll {
            let cy = TOP() + GRIDPAD() + (rowi - scroll) * CELLH()
            if cy < sy {
                let cx = bx + GRIDPAD() + col * CELLW()
                let bg = cBg(dark)
                let lblGc = gcRow
                if markHas(marked, entryName(entries, i)) == 1 {
                    x11FillRect(fd, win, gcSelBox, cx, cy, CELLW() - 8, CELLH() - 8)
                    bg = cSelLite(dark)
                    lblGc = gcLblSel
                }
                if i == sel {
                    x11FillRect(fd, win, gcSelBox, cx, cy, CELLW() - 8, CELLH() - 8)
                    bg = cSelLite(dark)
                    lblGc = gcLblSel
                }
                let ix = cx + (CELLW() - ICONBIG()) / 2
                let iy = cy + 10
                if haveIcons == 1 {
                    if entryIsDir(entries, i) { blitIcon(fd, win, gcRow, ix, iy, folderBig, scratch, bg, ICONBIG()) }
                    else {
                        let k = extKind(entryName(entries, i))
                        let ic = fileBig
                        if k == "image" { ic = imageBig }
                        if k == "archive" { ic = archiveBig }
                        if k == "media" { ic = mediaBig }
                        blitIcon(fd, win, gcRow, ix, iy, ic, scratch, bg, ICONBIG())
                    }
                }
                let disp = clipLabel(entryName(entries, i))
                let lx = cx + (CELLW() - len(disp) * charW()) / 2
                x11ImageText8(fd, win, lblGc, lx, cy + 10 + ICONBIG() + 16, disp)
            }
        }
        i += 1
    }

    // status bar (bottom, full width) — or the rename field when renaming
    x11FillRect(fd, win, gcBar, 0, sy, w, STATUSH())
    x11FillRect(fd, win, gcDiv, 0, sy, w, 1)
    if renaming == 1 {
        x11ImageText8(fd, win, gcStat, 10, sy + 16, "rename to:  " + renameText + "_")
    } else { if searchMode == 1 {
        x11ImageText8(fd, win, gcStat, 10, sy + 16, "search:  " + searchText + "_")
    } else {
        let statTxt = buildStatus(cwd, entries)
        if marked != "" { statTxt = countLines(marked) + " selected     " + statTxt }
        x11ImageText8(fd, win, gcStat, 10, sy + 16, statTxt)
        if sel >= 0 && sel < nrows {
            let snm = entryName(entries, sel)
            x11ImageText8(fd, win, gcStat, w - len(snm) * charW() - 12, sy + 16, snm)
        }
    } }

    // context menu (on top of everything)
    if menuOpen == 1 {
        let gcMenu = x11GenId(info, 24)
        let gcMenuBd = x11GenId(info, 25)
        let gcMenuTx = x11GenId(info, 26)
        let items = menuItems()
        let mn = countLines(items)
        let mh = mn * MENUROW() + 8
        x11FillRect(fd, win, gcMenuBd, menuX, menuY, MENUW(), mh)
        x11FillRect(fd, win, gcMenu, menuX + 1, menuY + 1, MENUW() - 2, mh - 2)
        let mi = 0
        while mi < mn {
            x11ImageText8(fd, win, gcMenuTx, menuX + 14, menuY + 6 + mi * MENUROW() + 16, nthLine(items, mi))
            mi += 1
        }
    }

    // help overlay (centered)
    if helpOpen == 1 {
        let gcM = x11GenId(info, 24)
        let gcMb = x11GenId(info, 25)
        let gcMt = x11GenId(info, 26)
        let ht = helpText()
        let hn = countLines(ht)
        let hw = 470
        let hh = hn * 18 + 26
        let hx = (w - hw) / 2
        let hy = (h - hh) / 2
        x11FillRect(fd, win, gcMb, hx - 1, hy - 1, hw + 2, hh + 2)
        x11FillRect(fd, win, gcM, hx, hy, hw, hh)
        let li = 0
        while li < hn {
            x11ImageText8(fd, win, gcMt, hx + 18, hy + 20 + li * 18, nthLine(ht, li))
            li += 1
        }
    }
}

just run {
    let fd = x11ConnectUnix(1)
    if fd < 0 { print("cortex: cannot connect to X display :1"); exit(1) }
    let info = x11Handshake(fd)
    if !x11Accepted(info) { print("cortex: handshake refused"); sockClose(fd); exit(1) }

    let dark = detectDark()
    let root = x11Root(info)
    let win = x11GenId(info, 1)
    x11CreateWindow(fd, win, root, 80, 60, W(), H(), cBg(dark), 163845)
    // window identity so Hyprland/WMs can match it (class:cortex / title cortex)
    x11SetClass(fd, win, "cortex", "cortex")
    x11SetTitle(fd, win, "cortex")
    // advertise WM_DELETE_WINDOW so the WM's close action sends a ClientMessage
    // we can quit on (InternAtom replies must be read before mapping).
    let wmProtocols = x11InternAtom(fd, "WM_PROTOCOLS")
    let wmDelete = x11InternAtom(fd, "WM_DELETE_WINDOW")
    x11SetWmProtocols(fd, win, wmProtocols, wmDelete)
    let netIcon = x11InternAtom(fd, "_NET_WM_ICON")   // intern before mapping (has a reply)

    let font = x11GenId(info, 2)
    x11OpenFont(fd, font, "fixed")

    let gcClear   = x11GenId(info, 3)   x11CreateGC(fd, gcClear,   win, cBg(dark),     cBg(dark),     font)
    let gcBar     = x11GenId(info, 4)   x11CreateGC(fd, gcBar,     win, cToolbar(dark),cToolbar(dark),font)
    let gcPath    = x11GenId(info, 5)   x11CreateGC(fd, gcPath,    win, cText(dark),   cBtn(dark),    font)
    let gcRow     = x11GenId(info, 6)   x11CreateGC(fd, gcRow,     win, cText(dark),   cBg(dark),     font)
    let gcFolder  = x11GenId(info, 9)   x11CreateGC(fd, gcFolder,  win, cFolder(),     cBg(dark),     font)
    let gcFile    = x11GenId(info, 10)  x11CreateGC(fd, gcFile,    win, cFile(),       cBg(dark),     font)
    let gcSide    = x11GenId(info, 11)  x11CreateGC(fd, gcSide,    win, cSide(dark),   cSide(dark),   font)
    let gcSideTx  = x11GenId(info, 12)  x11CreateGC(fd, gcSideTx,  win, cSideTx(dark), cSide(dark),   font)
    let gcDiv     = x11GenId(info, 13)  x11CreateGC(fd, gcDiv,     win, cDivider(dark),cDivider(dark),font)
    let gcSelBox  = x11GenId(info, 14)  x11CreateGC(fd, gcSelBox,  win, cSelLite(dark),cSelLite(dark),font)
    let gcLblSel  = x11GenId(info, 15)  x11CreateGC(fd, gcLblSel,  win, cText(dark),   cSelLite(dark),font)
    let gcTitle   = x11GenId(info, 16)  x11CreateGC(fd, gcTitle,   win, cTitle(dark),  cTitle(dark),  font)
    let gcTitleTx = x11GenId(info, 17)  x11CreateGC(fd, gcTitleTx, win, cTitleTx(dark),cTitle(dark),  font)
    let gcBtn     = x11GenId(info, 18)  x11CreateGC(fd, gcBtn,     win, cBtn(dark),    cBtn(dark),    font)
    let gcAddr    = x11GenId(info, 19)  x11CreateGC(fd, gcAddr,    win, cAddr(dark),   cAddr(dark),   font)
    let gcAddrBd  = x11GenId(info, 20)  x11CreateGC(fd, gcAddrBd,  win, cAddrBd(dark), cAddrBd(dark), font)
    let gcBtnBd   = x11GenId(info, 21)  x11CreateGC(fd, gcBtnBd,   win, cBg(dark),     cBg(dark),     font)
    let gcAddrTx  = x11GenId(info, 22)  x11CreateGC(fd, gcAddrTx,  win, cText(dark),   cAddr(dark),   font)
    let gcStat    = x11GenId(info, 23)  x11CreateGC(fd, gcStat,    win, cSideTx(dark), cToolbar(dark),font)
    let gcMenu    = x11GenId(info, 24)  x11CreateGC(fd, gcMenu,    win, cMenu(dark),   cMenu(dark),   font)
    let gcMenuBd  = x11GenId(info, 25)  x11CreateGC(fd, gcMenuBd,  win, cAddrBd(dark), cAddrBd(dark), font)
    let gcMenuTx  = x11GenId(info, 26)  x11CreateGC(fd, gcMenuTx,  win, cText(dark),   cMenu(dark),   font)

    x11MapWindow(fd, win)

    let sml = ICONSML()
    let big = ICONBIG()
    let tbz = TBICON()
    let folderSmlHex = rasterHex("folder", folderSvg(), sml)
    let folderBigHex = rasterHex("folder", folderSvg(), big)
    let fileBigHex   = rasterHex("file", fileSvg(), big)
    let imageBigHex  = rasterHex("image", imageSvg(), big)
    let archiveBigHex = rasterHex("archive", archiveSvg(), big)
    let mediaBigHex  = rasterHex("media", mediaSvg(), big)
    let haveIcons = 0
    let driveSmlHex  = rasterHex("drive", driveSvg(), sml)
    let folderSml = bufNew(iconBytes(sml))
    let folderBig = bufNew(iconBytes(big))
    let fileBig   = bufNew(iconBytes(big))
    let imageBig   = bufNew(iconBytes(big))
    let archiveBig = bufNew(iconBytes(big))
    let mediaBig   = bufNew(iconBytes(big))
    let driveSml  = bufNew(iconBytes(sml))
    if len(folderSmlHex) >= iconBytes(sml) * 2 && len(folderBigHex) >= iconBytes(big) * 2 && len(fileBigHex) >= iconBytes(big) * 2 {
        haveIcons = 1
        folderSml = hexToBuf(folderSmlHex, iconBytes(sml))
        folderBig = hexToBuf(folderBigHex, iconBytes(big))
        fileBig   = hexToBuf(fileBigHex, iconBytes(big))
        imageBig   = fileBig
        archiveBig = fileBig
        mediaBig   = fileBig
        if len(imageBigHex) >= iconBytes(big) * 2 { imageBig = hexToBuf(imageBigHex, iconBytes(big)) }
        if len(archiveBigHex) >= iconBytes(big) * 2 { archiveBig = hexToBuf(archiveBigHex, iconBytes(big)) }
        if len(mediaBigHex) >= iconBytes(big) * 2 { mediaBig = hexToBuf(mediaBigHex, iconBytes(big)) }
        if len(driveSmlHex) >= iconBytes(sml) * 2 { driveSml = hexToBuf(driveSmlHex, iconBytes(sml)) }
        // _NET_WM_ICON: [w, h, w*h ARGB]. BGRA bytes == LE CARDINAL of 0xAARRGGBB,
        // so the folder raster doubles as the icon pixels (taskbar/alt-tab icon).
        let npx = big * big
        let ib = bufNew(8 + npx * 4)
        bufSetByte(ib, 0, big)
        bufSetByte(ib, 4, big)
        let k = 0
        while k < npx * 4 { bufSetByte(ib, 8 + k, bufGetByte(folderBig, k))  k += 1 }
        x11ChangeProp32(fd, win, netIcon, 6, ib, 2 + npx)
    }
    // toolbar glyphs (green)
    let backRaw = bufNew(iconBytes(tbz))
    let fwdRaw = bufNew(iconBytes(tbz))
    let reloadRaw = bufNew(iconBytes(tbz))
    if haveIcons == 1 {
        let bh = rasterHex("back", backSvg(), tbz)
        let fh = rasterHex("fwd", fwdSvg(), tbz)
        let rh = rasterHex("reload", reloadSvg(), tbz)
        if len(bh) >= iconBytes(tbz) * 2 { backRaw = hexToBuf(bh, iconBytes(tbz)) }
        if len(fh) >= iconBytes(tbz) * 2 { fwdRaw = hexToBuf(fh, iconBytes(tbz)) }
        if len(rh) >= iconBytes(tbz) * 2 { reloadRaw = hexToBuf(rh, iconBytes(tbz)) }
    }
    let scratch = bufNew(iconBytes(big))
    let kmap = buildKeymap()

    let cwd = chomp(exec("pwd"))
    let savedDir = chomp(readFile(lastDirPath()))
    if savedDir != "" && chomp(exec("test -d '" + savedDir + "' && echo 1")) == "1" { cwd = savedDir }
    x11SetTitle(fd, win, "cortex - " + basename(cwd))
    let showHidden = 0
    let sortMode = 0
    let searchMode = 0
    let marked = ""
    let searchText = ""  marked = ""
    let allEntries = buildEntries(cwd, showHidden, sortMode)
    let entries = allEntries
    let places = buildSidebar()
    let sel = 0
    let scroll = 0
    let renaming = 0
    let renameText = ""
    let clipboard = ""
    let clipOp = ""
    let typeBuf = ""
    let typeTime = 0
    let menuOpen = 0
    let menuX = 0
    let menuY = 0
    let menuTarget = 0 - 1
    let helpOpen = 0
    let lastRow = 0 - 1
    let lastTime = 0
    let curW = W()
    let curH = H()
    let hist = cwd + "\n"
    let histIdx = 0
    let addr = cwd
    let addrFocused = 0

    let ev = bufNew(32)
    let running = 1
    while running == 1 {
        let n = x11NextEvent(fd, ev)
        if n <= 0 { running = 0 }
        else {
            let t = x11EventType(ev)
            if t == 12 {
                // re-scan devices on (re)expose so hot-plugged drives show up
                places = buildSidebar()
                repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig)
            } else if t == 22 {
                curW = x11EventWidth(ev)
                curH = x11EventHeight(ev)
                repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig)
            } else if t == 4 {
                let ex = x11EventX(ev)
                let ey = x11EventY(ev)
                let time = bufGetDwordAt(ev, 4)
                let btn = x11KeyDetail(ev)
                if helpOpen == 1 {
                    helpOpen = 0
                    repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig)
                } else if menuOpen == 1 {
                    // click while the context menu is open: run an item or dismiss
                    menuOpen = 0
                    let tgt = menuTarget
                    if ex >= menuX && ex < menuX + MENUW() && ey >= menuY + 4 {
                        let mi = (ey - menuY - 4) / MENUROW()
                        if mi == 0 { if tgt >= 0 { if entryIsDir(entries, tgt) { let nm = entryName(entries, tgt)  if nm == ".." { cwd = parentDir(cwd) } else { cwd = joinDir(cwd, nm) }  hist = truncLines(hist, histIdx + 1) + cwd + "\n"  histIdx = countLines(hist) - 1  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries  sel = 0  scroll = 0  searchMode = 0  searchText = ""  marked = ""  x11SetTitle(fd, win, "cortex - " + basename(cwd)) } else { openFile(joinDir(cwd, entryName(entries, tgt))) } } }
                        else if mi == 1 { if tgt >= 0 && entryName(entries, tgt) != ".." { clipboard = joinDir(cwd, entryName(entries, tgt))  clipOp = "cut" } }
                        else if mi == 2 { if tgt >= 0 && entryName(entries, tgt) != ".." { clipboard = joinDir(cwd, entryName(entries, tgt))  clipOp = "copy" } }
                        else if mi == 3 { if clipboard != "" { pasteClip(cwd, clipboard, clipOp)  if clipOp == "cut" { clipboard = ""  clipOp = "" }  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries } }
                        else if mi == 4 { if tgt >= 0 && entryName(entries, tgt) != ".." { sel = tgt  renaming = 1  renameText = entryName(entries, tgt) } }
                        else if mi == 5 { if tgt >= 0 && entryName(entries, tgt) != ".." { trashItem(joinDir(cwd, entryName(entries, tgt)))  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries  if sel >= countLines(entries) { sel = countLines(entries) - 1 } } }
                        else if mi == 6 { newFolder(cwd)  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries  let nf = rowOfName(entries, "New Folder")  if nf >= 0 { sel = nf  renaming = 1  renameText = "" } }
                        else if mi == 7 { openTerminal(cwd) }
                        else if mi == 8 { if tgt >= 0 && entryName(entries, tgt) != ".." { duplicateEntry(cwd, entryName(entries, tgt))  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries } }
                        else if mi == 9 { if tgt >= 0 && entryName(entries, tgt) != ".." { compressEntry(cwd, entryName(entries, tgt))  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries } }
                        else if mi == 10 { if tgt >= 0 && entryName(entries, tgt) != ".." { showProps(joinDir(cwd, entryName(entries, tgt)), entryName(entries, tgt)) } }
                    }
                    repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig)
                } else if btn == 3 && ex < SIDEBAR() && ey >= TOP() {
                    // right-click a drive in the sidebar -> unmount/eject it
                    let pr = (ey - TOP()) / ROWH()
                    if pr >= 0 && pr < countLines(places) {
                        let line = nthLine(places, pr)
                        if fieldAt(line, 0) == "d" && fieldAt(line, 2) != "" {
                            exec("udisksctl unmount -b '" + fieldAt(line, 3) + "' >/dev/null 2>&1")
                            places = buildSidebar()
                            repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig)
                        }
                    }
                } else if btn == 3 {
                    // right-click -> open context menu over the cell under cursor
                    menuTarget = 0 - 1
                    if ex >= SIDEBAR() && ey >= TOP() && ey < curH - STATUSH() {
                        let cols = gridCols(curW)
                        let col = (ex - SIDEBAR() - GRIDPAD()) / CELLW()
                        let rowi = (ey - TOP() - GRIDPAD()) / CELLH() + scroll
                        let idx = rowi * cols + col
                        if col >= 0 && col < cols && idx >= 0 && idx < countLines(entries) { sel = idx  menuTarget = idx }
                    }
                    menuOpen = 1
                    menuX = ex
                    menuY = ey
                    if menuX + MENUW() > curW { menuX = curW - MENUW() - 4 }
                    let menuH = countLines(menuItems()) * MENUROW() + 8
                    if menuY + menuH > curH { menuY = curH - menuH - 4 }
                    repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig)
                } else if btn == 4 || btn == 5 {
                    // mouse wheel -> scroll the grid
                    let ms = maxScroll(countLines(entries), gridCols(curW), curH - STATUSH() - TOP() - GRIDPAD())
                    if btn == 4 { if scroll > 0 { scroll = scroll - 1 } }
                    else { if scroll < ms { scroll = scroll + 1 } }
                    repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig)
                } else if ey >= TITLEH() && ey < TOP() {
                    // toolbar
                    addrFocused = 0
                    if ex >= backX() && ex < backX() + BTNW() {
                        if histIdx > 0 { histIdx = histIdx - 1  cwd = nthLine(hist, histIdx)  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries  sel = 0  scroll = 0  searchMode = 0  searchText = ""  marked = ""  x11SetTitle(fd, win, "cortex - " + basename(cwd)) }
                    } else if ex >= fwdX() && ex < fwdX() + BTNW() {
                        if histIdx < countLines(hist) - 1 { histIdx = histIdx + 1  cwd = nthLine(hist, histIdx)  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries  sel = 0  scroll = 0  searchMode = 0  searchText = ""  marked = ""  x11SetTitle(fd, win, "cortex - " + basename(cwd)) }
                    } else if ex >= refX() && ex < refX() + BTNW() {
                        allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries
                        places = buildSidebar()
                    } else if ex >= addrX() {
                        addrFocused = 1
                        addr = cwd
                    }
                    repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig)
                } else if ey >= TOP() {
                    addrFocused = 0
                    if ex < SIDEBAR() {
                        let pr = (ey - TOP()) / ROWH()
                        if pr >= 0 && pr < countLines(places) {
                            let line = nthLine(places, pr)
                            let kind = fieldAt(line, 0)
                            let dest = fieldAt(line, 2)
                            // drive with no mountpoint -> mount it via udisksctl
                            if kind == "d" && dest == "" {
                                let dev = fieldAt(line, 3)
                                dest = chomp(exec("udisksctl mount -b '" + dev + "' 2>&1 | sed -n 's/.* at //p' | sed 's/[.]$//'"))
                            }
                            if kind != "h" && dest != "" && existsDir(dest) {
                                cwd = dest
                                hist = truncLines(hist, histIdx + 1) + cwd + "\n"
                                histIdx = countLines(hist) - 1
                                allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries
                                sel = 0  scroll = 0  searchMode = 0  searchText = ""  marked = ""
                                places = buildSidebar()
                                x11SetTitle(fd, win, "cortex - " + basename(cwd))
                            }
                        }
                    } else {
                        let cols = gridCols(curW)
                        let col = (ex - SIDEBAR() - GRIDPAD()) / CELLW()
                        let rowi = (ey - TOP() - GRIDPAD()) / CELLH() + scroll
                        let idx = rowi * cols + col
                        if col >= 0 && col < cols && idx >= 0 && idx < countLines(entries) {
                            let dbl = idx == lastRow && time - lastTime < 400
                            sel = idx
                            if dbl {
                                let name = entryName(entries, idx)
                                if entryIsDir(entries, idx) {
                                    let dst = cwd
                                    if name == ".." { dst = parentDir(cwd) } else { dst = joinDir(cwd, name) }
                                    cwd = dst
                                    hist = truncLines(hist, histIdx + 1) + cwd + "\n"
                                    histIdx = countLines(hist) - 1
                                    allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries
                                    sel = 0  scroll = 0  searchMode = 0  searchText = ""  marked = ""
                                    x11SetTitle(fd, win, "cortex - " + basename(cwd))
                                } else {
                                    openFile(joinDir(cwd, name))   // open with default app
                                }
                            }
                            lastRow = idx
                            lastTime = time
                        }
                    }
                    repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig)
                }
            } else if t == 2 {
                let kc = x11KeyDetail(ev)
                let state = bufGetWordAt(ev, 28)
                let shift = state - state / 2 * 2
                let ctrl = state / 4 - state / 8 * 2
                let alt = state / 8 - state / 16 * 2
                if renaming == 1 {
                    // inline rename of the selected item
                    if kc == 9 { renaming = 0 }                                  // Esc cancel
                    else if kc == 36 {                                          // Enter commit
                        if renameText != "" {
                            renameTo(cwd, entryName(entries, sel), renameText)
                            allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries
                        }
                        renaming = 0
                    }
                    else if kc == 22 { if len(renameText) > 0 { renameText = substring(renameText, 0, len(renameText) - 1) } }
                    else {
                        let ch = keyChar(kmap, kc, shift)
                        if ch != "" { renameText = renameText + ch }
                    }
                    repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig)
                } else if searchMode == 1 {
                    // incremental filter of the current folder
                    if kc == 9 { searchMode = 0  searchText = ""  marked = ""  entries = allEntries  sel = 0 }
                    else if kc == 36 { allEntries = deepFind(cwd, searchText)  entries = allEntries  searchMode = 0  sel = 0  scroll = 0 }
                    else if kc == 22 { if len(searchText) > 0 { searchText = substring(searchText, 0, len(searchText) - 1) }  entries = filterEntries(allEntries, searchText)  sel = 0 }
                    else {
                        let ch = keyChar(kmap, kc, shift)
                        if ch != "" { searchText = searchText + ch  entries = filterEntries(allEntries, searchText)  sel = 0 }
                    }
                    repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig)
                } else if addrFocused == 1 {
                    // editing the address bar
                    if kc == 9 { addrFocused = 0 }                              // Esc
                    else if kc == 36 {                                          // Enter -> go
                        if existsDir(addr) {
                            cwd = chomp(addr)
                            hist = truncLines(hist, histIdx + 1) + cwd + "\n"
                            histIdx = countLines(hist) - 1
                            allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries
                            sel = 0  scroll = 0  searchMode = 0  searchText = ""  marked = ""
                            x11SetTitle(fd, win, "cortex - " + basename(cwd))
                        }
                        addrFocused = 0
                    }
                    else if kc == 22 { if len(addr) > 0 { addr = substring(addr, 0, len(addr) - 1) } }   // Backspace
                    else {
                        let ch = keyChar(kmap, kc, shift)
                        if ch != "" { addr = addr + ch }
                    }
                    repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig)
                } else {
                    if kc == 9 { if helpOpen == 1 { helpOpen = 0  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) } else { if marked != "" { marked = ""  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) } else { running = 0 } } }  // Esc: clear selection, else quit
                    else if kc == 67 { if helpOpen == 1 { helpOpen = 0 } else { helpOpen = 1 }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // F1 help
                    else if (kc == 25 || kc == 24) && ctrl == 1 { running = 0 }  // Ctrl+W / Ctrl+Q close
                    else if kc == 58 && ctrl == 1 { mountAllDrives()  places = buildSidebar()  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Ctrl+M mount all drives
                    else if kc == 38 && ctrl == 1 && shift == 0 { marked = markAll(entries)  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Ctrl+A select all
                    else if kc == 38 && ctrl == 1 && shift == 1 { marked = ""  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Ctrl+Shift+A clear selection
                    else if kc == 65 { if sel >= 0 && sel < countLines(entries) && entryName(entries, sel) != ".." { marked = markToggle(marked, entryName(entries, sel)) }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Space toggle mark
                    else if kc == 113 && alt == 1 { if histIdx > 0 { histIdx = histIdx - 1  cwd = nthLine(hist, histIdx)  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries  addr = cwd  sel = 0  scroll = 0  searchMode = 0  searchText = ""  marked = ""  x11SetTitle(fd, win, "cortex - " + basename(cwd)) }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Alt+Left back
                    else if kc == 114 && alt == 1 { if histIdx < countLines(hist) - 1 { histIdx = histIdx + 1  cwd = nthLine(hist, histIdx)  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries  addr = cwd  sel = 0  scroll = 0  searchMode = 0  searchText = ""  marked = ""  x11SetTitle(fd, win, "cortex - " + basename(cwd)) }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Alt+Right forward
                    else if kc == 110 && alt == 1 { cwd = homeDir()  hist = truncLines(hist, histIdx + 1) + cwd + "\n"  histIdx = countLines(hist) - 1  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries  addr = cwd  sel = 0  scroll = 0  searchMode = 0  searchText = ""  marked = ""  x11SetTitle(fd, win, "cortex - " + basename(cwd))  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Alt+Home home dir
                    else if kc == 46 && ctrl == 1 { addrFocused = 1  addr = cwd  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Ctrl+L address
                    else if kc == 41 && ctrl == 1 { searchMode = 1  searchText = ""  marked = ""  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Ctrl+F search
                    else if kc == 71 { allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries  places = buildSidebar()  searchMode = 0  searchText = ""  marked = ""  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // F5 refresh
                    else if kc == 40 && ctrl == 1 && shift == 1 { removeBookmark(cwd)  places = buildSidebar()  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Ctrl+Shift+D unbookmark
                    else if kc == 26 && ctrl == 1 { if sel >= 0 && sel < countLines(entries) && entryIsDir(entries, sel) == 0 { extractArchive(cwd, entryName(entries, sel))  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Ctrl+E extract
                    else if kc == 27 && ctrl == 1 && shift == 1 { if sel >= 0 && sel < countLines(entries) && entryName(entries, sel) != ".." { duplicateEntry(cwd, entryName(entries, sel))  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Ctrl+D duplicate
                    else if kc == 52 && ctrl == 1 && shift == 1 { if sel >= 0 && sel < countLines(entries) && entryName(entries, sel) != ".." { compressEntry(cwd, entryName(entries, sel))  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Ctrl+Shift+Z compress
                    else if kc == 28 && ctrl == 1 && shift == 1 { exec("mkdir -p '" + homeDir() + "/.local/share/Trash/files' 2>/dev/null")  cwd = homeDir() + "/.local/share/Trash/files"  hist = truncLines(hist, histIdx + 1) + cwd + "\n"  histIdx = countLines(hist) - 1  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries  addr = cwd  sel = 0  scroll = 0  searchMode = 0  searchText = ""  marked = ""  x11SetTitle(fd, win, "cortex - Trash")  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Ctrl+Shift+T trash view
                    else if kc == 36 {                                          // Enter -> open sel (dir) / open file
                        if entryIsDir(entries, sel) {
                            let name = entryName(entries, sel)
                            if name == ".." { cwd = parentDir(cwd) } else { cwd = joinDir(cwd, name) }
                            hist = truncLines(hist, histIdx + 1) + cwd + "\n"
                            histIdx = countLines(hist) - 1
                            allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries
                            sel = 0  scroll = 0  searchMode = 0  searchText = ""  marked = ""
                            x11SetTitle(fd, win, "cortex - " + basename(cwd))
                        } else { openFile(joinDir(cwd, entryName(entries, sel))) }
                        repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig)
                    }
                    else if kc == 43 && ctrl == 1 { if showHidden == 1 { showHidden = 0 } else { showHidden = 1 }  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries  sel = 0  scroll = 0  searchMode = 0  searchText = ""  marked = ""  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Ctrl+H hidden
                    else if kc == 39 && ctrl == 1 { sortMode = sortMode + 1  if sortMode > 2 { sortMode = 0 }  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries  sel = 0  scroll = 0  searchMode = 0  searchText = ""  marked = ""  x11SetTitle(fd, win, "cortex - " + basename(cwd) + " [" + sortName(sortMode) + "]")  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Ctrl+S cycle sort
                    else if kc == 31 && ctrl == 1 { if sel >= 0 && sel < countLines(entries) { showProps(joinDir(cwd, entryName(entries, sel)), entryName(entries, sel)) } }  // Ctrl+I properties
                    else if kc == 57 && ctrl == 1 && shift == 0 { newFile(cwd)  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries  let nf = rowOfName(entries, "New File")  if nf >= 0 { sel = nf  renaming = 1  renameText = "" }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Ctrl+N new file
                    else if kc == 54 && ctrl == 1 && shift == 1 { if sel >= 0 && sel < countLines(entries) { copyPath(joinDir(cwd, entryName(entries, sel))) } }  // Ctrl+Shift+C copy path
                    else if kc == 57 && ctrl == 1 && shift == 1 { newFolder(cwd)  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries  let nf = rowOfName(entries, "New Folder")  if nf >= 0 { sel = nf  renaming = 1  renameText = "" }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // n new folder
                    else if kc == 70 { openTerminal(cwd) }                       // F4 terminal here
                    else if kc == 68 { if sel >= 0 && sel < countLines(entries) && entryName(entries, sel) != ".." { renaming = 1  renameText = entryName(entries, sel) }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // F2 rename
                    else if kc == 119 { if marked != "" { trashMarked(cwd, marked)  marked = ""  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries  if sel >= countLines(entries) { sel = countLines(entries) - 1 } } else { if sel >= 0 && sel < countLines(entries) && entryName(entries, sel) != ".." { trashItem(joinDir(cwd, entryName(entries, sel)))  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries  if sel >= countLines(entries) { sel = countLines(entries) - 1 } } }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Delete -> trash
                    else if kc == 54 && ctrl == 1 && shift == 0 { if marked != "" { clipboard = clipFromMarked(cwd, marked)  clipOp = "copy" } else { if sel >= 0 && entryName(entries, sel) != ".." { clipboard = joinDir(cwd, entryName(entries, sel))  clipOp = "copy" } } }  // Ctrl+C
                    else if kc == 53 && ctrl == 1 && shift == 0 { if marked != "" { clipboard = clipFromMarked(cwd, marked)  clipOp = "cut" } else { if sel >= 0 && entryName(entries, sel) != ".." { clipboard = joinDir(cwd, entryName(entries, sel))  clipOp = "cut" } } }   // Ctrl+X
                    else if kc == 55 && ctrl == 1 {                                                                            // Ctrl+V paste
                        if clipboard != "" {
                            pasteClip(cwd, clipboard, clipOp)
                            if clipOp == "cut" { clipboard = ""  clipOp = "" }
                            allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries
                        }
                        repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig)
                    }
                    else if kc == 22 { cwd = parentDir(cwd)  hist = truncLines(hist, histIdx + 1) + cwd + "\n"  histIdx = countLines(hist) - 1  allEntries = buildEntries(cwd, showHidden, sortMode)  entries = allEntries  sel = 0  scroll = 0  searchMode = 0  searchText = ""  marked = ""  x11SetTitle(fd, win, "cortex - " + basename(cwd))  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }
                    else if kc == 40 && ctrl == 1 { addBookmark(cwd)  places = buildSidebar()  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }
                    else if kc == 116 { let c = gridCols(curW)  if sel + c < countLines(entries) { sel = sel + c }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }
                    else if kc == 111 { let c = gridCols(curW)  if sel - c >= 0 { sel = sel - c }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }
                    else if kc == 114 { if sel + 1 < countLines(entries) { sel += 1 }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }
                    else if kc == 113 { if sel > 0 { sel = sel - 1 }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }
                    else if kc == 117 { let vh = curH - STATUSH() - TOP() - GRIDPAD()  let ms = maxScroll(countLines(entries), gridCols(curW), vh)  let pg = vh / CELLH()  if pg < 1 { pg = 1 }  scroll = scroll + pg  if scroll > ms { scroll = ms }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // PageDown
                    else if kc == 112 { let vh = curH - STATUSH() - TOP() - GRIDPAD()  let pg = vh / CELLH()  if pg < 1 { pg = 1 }  scroll = scroll - pg  if scroll < 0 { scroll = 0 }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // PageUp
                    else if kc == 110 { scroll = 0  sel = 0  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // Home
                    else if kc == 115 { let ms = maxScroll(countLines(entries), gridCols(curW), curH - STATUSH() - TOP() - GRIDPAD())  scroll = ms  if countLines(entries) > 0 { sel = countLines(entries) - 1 }  repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig) }  // End
                    else if ctrl == 0 {
                        // type-ahead: jump selection to the first matching name
                        let ch = keyChar(kmap, kc, shift)
                        if ch != "" {
                            let now = bufGetDwordAt(ev, 4)
                            if now - typeTime > 1000 { typeBuf = "" }
                            typeTime = now
                            typeBuf = typeBuf + ch
                            let found = findPrefix(entries, typeBuf)
                            if found >= 0 {
                                sel = found
                                let rowi = found / gridCols(curW)
                                let vis = (curH - STATUSH() - TOP() - GRIDPAD()) / CELLH()
                                if rowi < scroll { scroll = rowi }
                                if rowi >= scroll + vis { scroll = rowi - vis + 1 }
                            }
                            repaint(fd, info, cwd, entries, sel, places, curW, curH, folderSml, folderBig, fileBig, scratch, haveIcons, addr, addrFocused, backRaw, fwdRaw, reloadRaw, dark, driveSml, scroll, renaming, renameText, menuOpen, menuX, menuY, helpOpen, searchMode, searchText, marked, imageBig, archiveBig, mediaBig)
                        }
                    }
                }
            } else if t == 33 {
                // ClientMessage — WM close request (WM_DELETE_WINDOW @ data[12])
                if bufGetDwordAt(ev, 12) == wmDelete { running = 0 }
            } else if t == 0 {
                print("cortex: X error code=" + bufGetByte(ev, 1) + " major=" + bufGetByte(ev, 10))
                running = 0
            }
        }
    }
    exec("mkdir -p '" + homeDir() + "/.config/cortex' 2>/dev/null")
    writeFile(lastDirPath(), cwd)
    sockClose(fd)
}
