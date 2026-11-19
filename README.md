# Lumen Client

A utility client for Minecraft Bedrock on iPad/iPhone. It's a `.dylib` you inject with KSign into **your own** decrypted Minecraft IPA. There are no combat or movement cheats.

## Install (KSign)
1. Download `LumenClient.dylib` from the latest build (Actions → build → artifact).
2. In KSign, import your Minecraft IPA.
3. Open its signing options → **Inject / Tweaks** → add `LumenClient.dylib`.
4. Sign, then install.
5. Open Minecraft. A toast says **"Lumen Client … loaded"** and an **L** button appears on the left edge.

## Phase 0/1 test checklist
| # | Test | Pass if |
|---|------|---------|
| 1 | Launch | Toast appears and the game doesn't crash |
| 2 | Xbox sign-in | You can sign in and join a server or Realm |
| 3 | Menu | Tapping **L** opens the menu and ✕ closes it. Touches outside the menu still control the game |
| 4 | Info tab | Shows "Frame hook: N frames" after you join a world |
| 5 | FPS Display | Number is close to the game's real FPS (60 or 120) |
| 6 | FPS Unlocker | On a ProMotion iPad, FPS goes above 60. Turning it off returns to normal |
| 7 | CPS Display | Tap fast and the count goes up; it drops to 0 within 1 s of stopping |
| 8 | Keystrokes | Keys light up while you press them (touch, keyboard, mouse or controller) |
| 9 | Clock / Session / Stopwatch | Time is right. Stopwatch: tap starts/stops, hold resets |
| 10 | Crosshair | Style, colour and size change instantly |
| 11 | Edit HUD | Drag, pinch and double-tap work, and the layout is the same after restarting |
| 12 | Profiles | Profile 1/2/3 each keep their own setup |
| 13 | Restart | Everything you set is still there after force-quitting |

## Safety
- Modules marked 🔧 read game memory. They stay off until your Minecraft version is mapped.
- If a launch crashes during startup, the next launch runs in **safe mode** with hooks off.
- **Server-safe** turns off the modules servers most often ban.

## Build
GitHub Actions builds every push to `main` on macOS. To build locally on a Mac with Xcode, run `sh build.sh`.
