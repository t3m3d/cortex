# cortex

A GUI file manager for Linux, written in **pure [Krypton](https://krypton-lang.org)**
talking the **X11 wire protocol directly** — no libX11, no xcb, no toolkit.
Linux-locked on purpose; built for and used on Hyprland (Xwayland).

The X11 client layer lives in the Krypton stdlib (`stdlib/x11.k`): connect over
the `/tmp/.X11-unix` socket, CreateWindow/MapWindow, GCs, FillRect, ImageText8,
PutImage, FillArc, properties (WM_CLASS / WM_NAME / WM_PROTOCOLS / _NET_WM_ICON),
and the event loop. The whole UI — icons, theming, compositing — is drawn by
cortex itself.

## Build & run

```sh
KRYPTON_ROOT=~/path/to/krypton \
  ~/path/to/krypton/bootstrap/kcc_driver_linux_x86_64 cortex.k -o /tmp/cortex
/tmp/cortex
```

Requires (runtime, optional but recommended): `ImageMagick` (`magick`/`convert`)
+ `xxd` for crisp raster icons, `gio`/`udisksctl` for trash & drive mounting,
`xdg-open` to open files, and a terminal for "open terminal here".

## Features

- **Icon grid & list views** (Tab, or Ctrl+1 / Ctrl+2; choice persists)
- **Quick-access sidebar** — Home/Desktop/Documents/… plus your bookmarks; the
  current location is highlighted
- **External drives** — removable partitions via `lsblk` (mounted or not);
  right-click to mount/unmount, Ctrl+M mounts all
- **File-type icons** — distinct glyphs for folders, images, archives, audio/
  video, and generic files (dirs listed first)
- **Toolbar** — back / forward / reload + a typeable address bar
- **Multi-select** — Space marks, Ctrl+A all; bulk copy / cut / trash
- **Search** — type to filter the folder, Enter to search subfolders
- **Light / dark theming** — from `~/.config/cortex/config` (`theme=dark|light|
  auto`) then system settings
- Remembers the last directory across sessions
- Light theme with a green "Krypton" accent throughout

## Keyboard shortcuts

| Key | Action |
|-----|--------|
| Enter / double-click | open file or folder |
| Backspace | go up |
| Alt+Left / Alt+Right | back / forward |
| Alt+Home | home folder |
| type a name | jump to it |
| arrows / PageUp/Down / Home / End | move selection |
| Tab, Ctrl+1 / Ctrl+2 | toggle / set icon & list view |
| Space | mark / unmark item |
| Ctrl+A / Ctrl+Shift+A | select all / clear selection |
| Delete | move selection (or item) to trash |
| Ctrl+C / Ctrl+X / Ctrl+V | copy / cut / paste (no-clobber) |
| Ctrl+N / Ctrl+Shift+N | new file / new folder (then type the name) |
| Ctrl+Shift+R | duplicate |
| Ctrl+E / Ctrl+Shift+Z | extract archive / compress to zip |
| F2 | rename |
| Ctrl+I | properties |
| Ctrl+Shift+C | copy path |
| Ctrl+H | toggle hidden files |
| Ctrl+S | cycle sort (name / size / date) |
| Ctrl+F | search (Enter = include subfolders) |
| F5 | refresh |
| Ctrl+D / Ctrl+Shift+D | bookmark / unbookmark current dir |
| Ctrl+Shift+T | trash view |
| Ctrl+M | mount all removable drives |
| Ctrl+L | edit address bar |
| F4 | open terminal here |
| F1 | this help overlay |
| Ctrl+W / Ctrl+Q / Esc | clear selection, then close |

## Config

`~/.config/cortex/`
- `config` — `theme=dark|light|auto`
- `bookmarks` — one path per line (managed via Ctrl+D / Ctrl+Shift+D)
- `lastdir` — restored on launch
- `view` — `grid` or `list`
