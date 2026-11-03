# Godot 4-Player Chess (2v2)

2D multiplayer chess on a 16×8 board (two standard boards side-by-side).

## Status

**Working:**
- ENet lobby (host/join, slots, teams, colors, turn order swap, observers, chat)
- 16×8 board, 4 armies, classic moves
- Check / checkmate / stalemate → freeze player (pieces protected)
- Castling, en passant, **promotion picker** (Q/R/B/N)
- Server-validated move RPC + move animation
- Network **draw voting**
- Badges + **highlight of current player**
- Team / global chat (name in player color)
- AudioManager + **CC0 sound generator** (`python3 tools/generate_sounds.py`)
- RU/EN toggle, fullscreen

**Still soft / optional:**
- Full reconnection state snapshot
- Resolution preset menu
- Localization .po files
- Richer SFX (replace generated ones anytime)

## Setup
1. Clone https://github.com/Reaper555555/godot-4player-chess
2. Godot **4.7.2**+
3. Optional sounds:
   ```bash
   python3 tools/generate_sounds.py
   ```
4. F5 → Play → Lobby

## Rules
- Team wins when all opposing players are frozen (mate/stalemate).
- Frozen player cannot move; their pieces/king cannot be captured until unfrozen.
- Draw by full agreement of all players or both members of a team stalemated.
