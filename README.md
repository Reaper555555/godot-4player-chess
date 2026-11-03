# Godot 4-Player Chess (2v2) — v0.2

2D multiplayer chess on a **16×8** board (two 8×8 boards side by side).

**Repo:** https://github.com/Reaper555555/godot-4player-chess  
**Engine:** Godot **4.7.2**+

## Features
- Local network (ENet): host / join, up to 4 players + observers
- Lobby: slot, color, team, turn order (swap on conflict), ready, chat
- Classic moves + castling, en passant, promotion picker
- Multiplayer mate rules (frozen player, protected pieces)
- Team victory / draw voting (network)
- Move animation, selection rings, move dots
- Badges + current-player highlight
- Reconnect / late-join **state snapshot**
- Resolution presets + fullscreen (saved)
- RU/EN strings via `LocaleManager`
- CC0 SFX generator: `python3 tools/generate_sounds.py`

## Quick start
```bash
git clone https://github.com/Reaper555555/godot-4player-chess.git
cd godot-4player-chess
python3 tools/generate_sounds.py   # optional
# open project.godot in Godot 4.7.2 and press F5
```

## Notes
This is a solid playable prototype. Further polish: better UI layout scaling, richer reconnection of identity after peer id change, more thorough castling edge cases on 16-wide board.
