# drracket-dark-windows

A dark window frame for DrRacket on Windows.

| Part | Handled by | Admin needed? |
|---|---|---|
| Title bar | plugin (`win32-dark.rkt`, DWM API) | no |
| Menu bar | plugin (subclasses the window and draws the bar itself) | no |
| Dropdown menus | plugin (uxtheme dark mode) | no |
| Editor scrollbars | plugin (`DarkMode_Explorer` window theme) | no |
| Toolbar, tabs, status bar | `patch.rkt` patches racket/gui | **yes**, once |

The editor colors themselves come from DrRacket's color schemes.
The [`drracket-rainbow`](../drracket-rainbow) package adds a matching one.

## Why the patch?

On Windows, racket/gui draws panels using the Windows "button face" system colors, and a plugin can't change those.
The patch adds a small module, `dark-chrome.rkt`, to racket/gui and changes 4 files to use it.
It swaps in the dark colors and an optional custom font.

- By default it only affects DrRacket, not other racket/gui programs (see `drracket-only` under Settings).
- The original files are backed up to `gui-lib-patch/backup/` before anything changes.
- Upgrading Racket replaces racket/gui, which removes the patch. Re-run `apply` afterwards.

Run these from an **Administrator** terminal:

```bash
racket -l- drracket-dark-windows/patch apply
```

```bash
racket -l- drracket-dark-windows/patch status
```

```bash
racket -l- drracket-dark-windows/patch revert
```

## Settings

The settings live in `%APPDATA%\Racket\drracket-dark-windows.rktd`, which DrRacket creates on first launch.
Restart DrRacket after editing it.

| Key | Default | Meaning |
|---|---|---|
| `enabled` | `#t` | Turns everything off without uninstalling. |
| `drracket-only` | `#t` | When `#t`, the patch only affects DrRacket itself, not other racket/gui programs. |
| `background` | `(37 37 38)` | Toolbar, tabs and menu bar color, as `(r g b)`. |
| `hover` | `(62 62 66)` | Hovered or open menu-bar item. |
| `foreground` | `(220 220 220)` | Text color. |
| `disabled` | `(128 128 128)` | Disabled menu text. |
| `control-font` | `#f` | Font for the toolbar, tabs and status bar. `#f` means the Windows default. |
| `menu-font` | `#f` | Font for the menu bar. `#f` means the Windows default. |
| `menu-font-points` | `9` | Menu bar font size. |

For example, to use the Minecraft-style [Monocraft](https://github.com/IdreesInc/Monocraft) font, install it and then set:

```racket
(control-font . "Monocraft") (menu-font . "Monocraft")
```

## Uninstall

1. Revert the patch from an Administrator terminal:

   ```bash
   racket -l- drracket-dark-windows/patch revert
   ```

2. Remove the package:

   ```bash
   raco pkg remove drracket-dark-windows
   ```

## Known limits

- Native widgets in dialogs (push buttons, text fields, check boxes) keep the light Windows look.
- Dropdown menu items use the Windows menu font.
- The menu bar and dark dropdowns rely on undocumented Windows behavior, so a Windows update could break them.
  If that happens, set `enabled` to `#f`.
- Tested with Racket 9.3 on Windows 11. The patch refuses to apply if racket/gui's source doesn't match what it expects.
