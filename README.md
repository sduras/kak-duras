# kak-duras

**Kakoune integration for duras**

[![License](https://img.shields.io/badge/license-ISC-blue)](https://opensource.org/licenses/ISC)

Open, append, and search [duras](https://github.com/sduras/duras) daily notes
from inside [Kakoune](https://kakoune.org/) — without spawning a nested editor.

duras keeps notes as plain text files at `$DURAS_DIR/YYYY/MM/YYYY-MM-DD.dn`.
No database, no daemon, no lock-in. This plugin pipes Kakoune selections and
clipboard text to the duras CLI, resolves note paths, and surfaces search
results as navigable buffers.

---

## Install

### plug.kak

```kak
plug "codeberg.org/duras/kak-duras"
```

### Manual

```sh
git clone https://github.com/sduras/kak-duras \
    ~/.config/kak/autoload/plugins/kak-duras
```

Kakoune sources everything under `~/.config/kak/autoload/` at startup.

---

## Quick start

Open today's note:

```kak
: duras-open
```

Append a thought — select lines with `x` or `%`, then:

```kak
: duras-append
```

Search across all notes:

```kak
: duras-search relayd
```

Press `<ret>` on a result to open that note. Press `<leader>do` to return to
today from anywhere.

That's the core loop. The rest is reference.

---

## Features

- **No nested editor.** `duras-open` resolves the path and calls `edit` —
  one Kakoune process, one buffer list.
- **Selection-aware append.** `duras-append` pipes `$kak_selection` directly
  to `duras append -`. Make any selection first: object, regex, multiple
  cursors collapsed to primary — then append.
- **New notes initialised correctly.** When a note does not exist yet, duras
  writes the header before the buffer opens. The plugin does not touch file
  creation itself.
- **Search results as a real buffer.** `*duras-search*` is a scratch buffer.
  Use `/`, `s`, or object selection on it before navigating.
- **Clipboard bridge.** Reads and writes via `pbpaste`/`pbcopy` (macOS),
  `xclip`, or `xsel` — whichever is present, checked by exit status.
- **Pure kakscript + POSIX shell.** No compiled components, no external
  dependencies beyond duras.

---

## Commands

| Command                   | Description                                        |
| ------------------------- | -------------------------------------------------- |
| `duras-open [date]`       | Open note. Date: `YYYY-MM-DD` or integer offset.   |
| `duras-append`            | Append current selection to today's note.          |
| `duras-append-buffer`     | Append entire buffer to today's note.              |
| `duras-append-text <text>`| Append literal text. Multiple words, no quoting.   |
| `duras-append-clipboard`  | Append system clipboard to today's note.           |
| `duras-search <keyword>`  | Search notes; navigate results with `<ret>`.       |
| `duras-clip-yank`         | Copy buffer to system clipboard.                   |
| `duras-clip-paste`        | Paste system clipboard below cursor.               |
| `duras-copy-path`         | Copy today's note path to system clipboard.        |
| `duras-stats`             | Show note counts, size, date range, streak.        |
| `duras-path`              | Print today's note path to the status bar.         |
| `duras-tags [tag]`        | List all tags, or notes containing `#tag`.         |

### Mappings

| Key           | Command                          |
| ------------- | -------------------------------- |
| `<leader>do`  | `duras-open` (today)             |
| `<leader>da`  | `duras-append-buffer`            |
| `<leader>dA`  | `duras-append` (selection)       |
| `<leader>dc`  | `duras-append-clipboard`         |
| `<leader>ds`  | `duras-search ` (prompt open)    |
| `<leader>dp`  | `duras-path`                     |

`<leader>` defaults to `\` in Kakoune.

---

## Configuration

duras.kak has no plugin-level options. Behaviour is controlled by duras
environment variables and standard Kakoune configuration.

### duras environment

```sh
export DURAS_DIR=~/notes          # default: ~/Documents/Notes
export DURAS_GPG_KEY=you@example  # for encrypted notes (duras -c, not this plugin)
```

Set these in your shell profile before starting Kakoune.

### Remapping keys

Replace or extend the defaults in `kakrc`:

```kak
# Replace <leader>da with a different key
unmap global normal <leader>da
map global normal <leader>n ': duras-append-buffer<ret>' -docstring 'duras: append buffer'
```

### Disabling default mappings

Comment out the `map global normal` block at the bottom of `rc/duras.kak`:

```kak
# map global normal <leader>do ...
# map global normal <leader>da ...
# ...
```

There is no `duras_no_mappings` option. Edit the source directly.

---

## Composing with Kakoune

duras.kak is an entry point. Once a note is open, Kakoune's selection model
applies in full.

**Append a regex match from a log file:**

```kak
: e /var/log/daemon.log       # open log
/ error.*relayd<ret>          # search
: duras-append<ret>           # append match to today's note
```

**Extract all TODO lines from the current buffer:**

```kak
%s^\*\s*TODO.*<ret>           # select all TODO lines
: duras-append<ret>           # send them to today's note
```

**Pipe search results through a shell tool before opening:**

In `*duras-search*`, results are plain text. Sort them:

```kak
%                             # select all
| sort -rk1<ret>              # sort by date descending, in place
```

**Append output of an arbitrary command without opening the buffer:**

```sh
git log --oneline -10 | duras append -
```

The plugin handles the Kakoune side. The CLI handles everything else.

---

## Clipboard priority

1. `pbcopy` / `pbpaste` — macOS, iOS (a-Shell)
2. `xclip` — Linux X11, XWayland
3. `xsel` — Linux X11, XWayland

Wayland: install `wl-clipboard`. Either use a wrapper that provides
`xclip`-compatible commands, or add `wl-copy`/`wl-paste` calls directly in
the clipboard block at the top of `rc/duras.kak`.

---

## Troubleshooting

**`duras-open` fails with "path failed"**

Check that `duras` is in `PATH` as seen by Kakoune:

```kak
: echo %sh{ command -v duras }
```

If empty, set `PATH` explicitly in `kakrc`:

```kak
set-option global path "%opt{path}:/usr/local/bin"
```

Or set it in your shell profile — Kakoune inherits the environment of the
shell that launched it.

**Clipboard commands do nothing**

Verify the clipboard tool is present:

```sh
which xclip || which xsel || which pbpaste
```

Install if missing:

```sh
# Debian / Ubuntu
apt install xclip

# Wayland
apt install wl-clipboard
```

**Search returns no results**

Confirm `DURAS_DIR` points to your notes:

```sh
duras dir
duras list
```

Encrypted notes (`.dn.gpg`) are skipped by `duras search`. Plain notes only.

**Append writes blank content**

`duras-append` sends `$kak_selection`. If the selection is a single cursor
with no extent, the content will be empty. Extend the selection first — `x`
for a line, `%` for the whole buffer, or use `duras-append-buffer` instead.

---

## Contributing

Bug reports and patches are welcome at
[codeberg.org/duras/kak-duras](https://codeberg.org/duras/kak-duras/issues).

Before opening an issue, confirm the bug is in the plugin and not in duras
itself by running the equivalent `duras` command directly from the shell.

For pull requests:

- POSIX shell only in `%sh{}` blocks
- Match the existing style: one `printf` per kak command emitted from shell
- New commands must satisfy the duras scope boundary: does this make notes
  more trustworthy, durable, or understandable in 10 years? If not, it belongs
  in a personal `kakrc`, not in this plugin
- Test against an actual duras install before submitting

---

## License

ISC — see [LICENSE](LICENSE).
