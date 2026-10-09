# DrRacket Dark Mods

Rainbow brackets, VS Code-style syntax colors, and a dark window frame for DrRacket.

![DrRacket with rainbow brackets and a dark window](screenshots/demo.png)

This repo holds two independent packages. Install either one or both.

| Package | What it does | Platforms |
|---|---|---|
| [`drracket-rainbow`](drracket-rainbow) | Rainbow brackets, more syntax roles, "Monokai Rainbow" color scheme | Windows, macOS, Linux |
| [`drracket-dark-windows`](drracket-dark-windows) | Dark title bar, menu bar, toolbar, tabs and scrollbars | Windows only |

Tested with Racket 9.3 on Windows 11.

## drracket-rainbow

Stock DrRacket gives every identifier the same color. This plugin adds the roles VS Code shows:

| Role | Example | Color |
|---|---|---|
| Special forms | `define`, `lambda`, `cond`, `else`, `check-expect` | pink |
| Function being called | `sq` in `(sq x)` | green |
| Name being defined | `sq` in `(define (sq x) ...)` | green |
| Brackets, by nesting depth | `( [ (` | gold, purple, blue (repeats) |

It also adds a **Monokai Rainbow** color scheme for strings, numbers, comments and the REPL.

### Install

```bash
raco pkg install "https://github.com/AvocadoGG1/drracket-dark-mods.git?path=drracket-rainbow"
```

Restart DrRacket.
Then pick **Edit > Preferences > Colors > Color Schemes > Monokai Rainbow**.
That setting appears when DrRacket is in dark mode (**Background > White on Black**).

### Notes

- Only the token *color* changes, so indentation and paren matching behave exactly as before.
- **Check Syntax** paints its own identifier colors on top: imported names turn cyan and local names white.
  Editing the file brings the rainbow colors back.

## drracket-dark-windows

On Windows, DrRacket's window frame ignores dark mode.
This package darkens it in two parts.

1. **The plugin** (no admin needed) handles the title bar, the menu bar, the dropdown menus and the editor scrollbars.
2. **An optional patch** to racket/gui handles the toolbar, tabs and status bar.
   It needs Administrator rights, because Racket is installed under Program Files.

With Monocraft set as the menu and toolbar font:

![The dark window frame with the Monocraft font](screenshots/demo-monocraft.png)

### Install

```bash
raco pkg install "https://github.com/AvocadoGG1/drracket-dark-mods.git?path=drracket-dark-windows"
```

Then, optionally, apply the patch from an **Administrator** terminal:

```bash
racket -l- drracket-dark-windows/patch apply
```

Restart DrRacket.
See [drracket-dark-windows/README.md](drracket-dark-windows/README.md) for settings, custom fonts and how to undo.

## License

[MIT](LICENSE)
