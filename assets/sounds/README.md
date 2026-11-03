# Sounds (CC0)

Generate local placeholder SFX (public domain):

```bash
python3 tools/generate_sounds.py
```

Creates in this folder:
- `move` — ordinary move
- `capture`
- `check`
- `checkmate`
- `select`
- `ui_click`

(`.wav` always; `.ogg` if `ffmpeg` is installed)

You can replace these with any other free sounds (Freesound CC0, OpenGameArt, etc.).
`AudioManager` loads `.ogg` first, then `.wav`.

License of generated files: **CC0 1.0** (public domain).
