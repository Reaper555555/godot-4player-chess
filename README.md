# Godot 4-Player Chess (2v2)

2D multiplayer chess on a 16×8 board (two standard boards side-by-side).

## Current status (WIP)

**Core systems implemented:**
- Network (ENet host/client, lobby, chat, basic reconnection)
- GameState (16×8 board, 4 slots, initial placement, frozen players, turn order)
- ChessLogic (classic moves, check / checkmate / stalemate, cannot capture frozen pieces)
- BoardView (vector drawing of board + pieces, selection circle, move indicators)
- Main menu, Lobby UI, Game scene skeleton
- AudioManager + LocaleManager (RU/EN)

**Still missing / incomplete:**
- Full RPC synchronization of moves between peers
- Move animation (piece slides)
- Castling, en passant, pawn promotion UI
- Proper victory / draw voting UI
- Better badge placement & highlighting of current player
- Sound files (folder ready, add .ogg yourself)
- Full localization files
- Resolution selector
- Robust reconnection with full state snapshot

## Features (planned / partial)
- Local network (ENet) for up to 4 players + unlimited observers
- Custom teams, colors, turn order (with swap on conflict)
- Classic chess rules + special multiplayer checkmate (frozen players)
- Minimalistic vector pieces (color + outline)
- Russian / English UI
- Team + global chat (nickname in player color)
- Sounds, fullscreen, language switch

## Requirements
- Godot **4.7.2** or later

## How to run
1. Clone the repo
2. Open `project.godot` in Godot 4.7.2+
3. Press F5 (main menu → Play → Lobby)

## Board layout
Two standard 8×8 boards joined horizontally.
Slots: Top-Left, Bottom-Left, Top-Right, Bottom-Right.
Each player gets a full classic set. Pawns move forward relative to their side.

## Victory
Team wins when **all** players of the opposing team are checkmated.
Single checkmate/stalemate freezes that player (cannot move, pieces protected).
Draw by mutual team agreement or double stalemate.

Repo: https://github.com/Reaper555555/godot-4player-chess
