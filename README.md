# Godot 4-Player Chess (2v2)

2D multiplayer chess on a 16×8 board (two standard boards side-by-side).

## Features
- Local network (ENet) for up to 4 players + unlimited observers
- Custom teams, colors, turn order
- Classic chess rules + special multiplayer checkmate (frozen players cannot move; their pieces/king cannot be captured until unfrozen)
- Minimalistic vector pieces (color + outline)
- Russian / English UI with language switch
- Reconnection support with state recovery
- Team chat + global chat (nickname in player color)
- Move animation, possible moves as circles, selected piece highlight
- Sounds for moves, check, checkmate, etc.
- Resolution selection + fullscreen

## Requirements
- Godot **4.7.2** or later (4.7.x branch recommended)

## How to play
1. Open project in Godot 4.7.2+
2. One player hosts, others join by local IP
3. In lobby: choose slot (position on board), color, team number, turn order (1-4)
4. When all ready — host starts the game
5. Observers can join anytime

## Board layout
Two standard 8×8 boards joined horizontally (files 0-7 left, 8-15 right).
Slots:
- Top-Left
- Bottom-Left
- Top-Right
- Bottom-Right

Each player has a full classic set. Pawns move forward relative to their side.

## Victory conditions
- Team wins when all opposing team players are checkmated
- Stalemate to both players of a team = draw
- Single player stalemate/checkmate = frozen (cannot move)
- Draw by mutual agreement (both teams must agree via vote)

## Project structure (WIP)
```
project.godot
scenes/
scripts/
assets/
locales/
```

Work in progress. Architecture and core systems are being implemented.

Repo: https://github.com/Reaper555555/godot-4player-chess
