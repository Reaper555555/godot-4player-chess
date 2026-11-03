# Godot 4-Player Chess (2v2)

2D multiplayer chess on a 16×8 board (two standard boards side-by-side).

## Current status

**Implemented:**
- Network (ENet host/client, lobby, chat, basic reconnection)
- GameState (16×8, 4 slots, placement, frozen players, turn order, en passant target)
- ChessLogic (classic moves, check/mate/stalemate, castling, en passant, promotion detection)
- BoardView (vector board + pieces, selection, move circles)
- Move animation (straight-line slide)
- RPC move sync with server validation
- Main menu, Lobby, Game scenes
- Badges, turn highlight, team/global chat
- Draw offer button (simplified voting)
- Auto-queen on promotion
- AudioManager + LocaleManager stubs

**Still incomplete:**
- Promotion choice UI (currently always Queen)
- Full team-based draw voting protocol over network
- Highlight of current player more clearly
- Sound files (add .ogg to `assets/sounds/`)
- Localization .po files
- Resolution selector
- Full state snapshot on reconnect

## Requirements
Godot **4.7.2**+

## How to run
1. Clone https://github.com/Reaper555555/godot-4player-chess
2. Open in Godot 4.7.2+
3. F5 → Play → Lobby (Host / Join by IP)

## Rules summary
- 4 players, flexible teams, custom turn order 1–4
- Classic piece moves; pawns only forward relative to their side
- Checkmate/stalemate freezes a player (cannot move; pieces cannot be captured)
- Team wins when all opposing players are frozen
- Draw by agreement or both members of a team stalemated
