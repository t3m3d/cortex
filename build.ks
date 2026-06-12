#!/usr/bin/env -S kcc -r
// build.ks — build cortex (pure-Krypton X11 file manager) to ./cortex.
//   ./build.ks                         -> ./cortex
//   CORTEX_OUT=/tmp/cortex ./build.ks  -> custom output path
//   CORTEX_RUN=1 ./build.ks            -> build to ./cortex and launch it
//
// KryptScript replacement for build.sh, run via `kcc -r` (on PATH from the
// Homebrew krypton install; `kr` also works). The `-r` runner does not
// forward positional args to the script, so the output path (CORTEX_OUT)
// and run-after-build (CORTEX_RUN=1) are taken from the environment
// rather than from $1 / --run.
import "k:env"

func chompStr(s) {
    let n = len(s)
    while n > 0 && (s[n - 1] == fromCharCode(10) || s[n - 1] == fromCharCode(13)) { n = n - 1 }
    emit substring(s, 0, n)
}
func isExec(p) { emit chompStr(exec("test -x '" + p + "' && echo 1")) == "1" }
func isDir(p)  { emit chompStr(exec("test -d '" + p + "' && echo 1")) == "1" }

just run {
    let out = envOr("CORTEX_OUT", "./cortex")

    // Locate the Krypton repo (for stdlib/x11.k) and a native driver.
    // Prefer CORTEX_KRYPTON_ROOT: `kcc -r` exports its own KRYPTON_ROOT into
    // this program (the active toolchain), so a plain KRYPTON_ROOT override on
    // the command line is clobbered — use CORTEX_KRYPTON_ROOT to force a
    // different checkout. Default falls back to the active KRYPTON_ROOT, then
    // a sibling ../krypton.
    let root = envOr("CORTEX_KRYPTON_ROOT", "")
    if root == "" { root = envOr("KRYPTON_ROOT", "") }
    if root == "" { root = chompStr(exec("cd ../krypton 2>/dev/null && pwd")) }
    if root == "" || isDir(root) == 0 {
        kp("build.ks: set KRYPTON_ROOT to your krypton checkout (stdlib/x11.k lives there)")
        exit("1")
    }

    let driver = root + "/bootstrap/kcc_driver_linux_x86_64"
    if isExec(driver) == 0 {
        driver = chompStr(exec("command -v kcc || command -v krypton || true"))
    }
    if driver == "" {
        kp("build.ks: no Krypton driver found (looked for " + root + "/bootstrap/kcc_driver_linux_x86_64, kcc, krypton)")
        exit("1")
    }

    kp("build.ks: KRYPTON_ROOT=" + root)
    kp("build.ks: " + driver + " cortex.k -o " + out)
    let rc = shellRun("KRYPTON_ROOT='" + root + "' '" + driver + "' cortex.k -o '" + out + "'")
    if rc != "0" {
        kp("build.ks: compile failed (rc=" + rc + ")")
        exit(rc)
    }

    if envOr("CORTEX_RUN", "") == "1" {
        exit(shellRun("'" + out + "'"))
    }
}
