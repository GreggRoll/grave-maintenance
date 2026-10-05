# Grave Maintenance

A playable Godot 4.6.2 / GDScript prototype for 1–4 employees. One compact cemetery, four maintenance jobs, a five-minute work window, and no combat. Built milestone by milestone from an empty repository.

## Play now

Public game: **https://greggroll.github.io/grave-maintenance/**. Solo play is hosted on GitHub Pages. Co-op connects through a secure tunnel to this Mac; the Mac must remain awake and hosting must be running.

The development build is served at **http://localhost:8080**. Select **I'm ready**, then **Clock in** for solo play. Basic tools are offered by default. The local WebSocket server runs on port **9080**.

On macOS, double-click **Play Grave Maintenance.command** to start the web game and co-op server again. Keep its terminal window open while playing. It reuses running services and finds Godot in PATH, the development download, or its cache; if needed it downloads Godot 4.6.2 from the official GitHub release.

For an iPhone on the same Wi-Fi, open `http://<this Mac's LAN IP>:8080` in Safari. The server address defaults to the same hostname on port 9080. Touch controls appear automatically. Portrait and landscape layouts are supported; landscape offers a wider cemetery view. `?touch=1` enables the touch layout on desktop for inspection.

**Validation:** desktop browser solo and online play, iPhone-sized portrait layout, touch-button extraction, real scene input checks, six milestone suites, additional recovery/timing/payout regressions, and four independent clients talking through the public WSS tunnel. Physical iPhone Safari has not been tested.

## Public hosting

The `main` branch contains source; `gh-pages` contains only the browser export. GitHub Pages serves the client over HTTPS. Multiplayer uses a temporary Cloudflare Quick Tunnel to local port 9080, providing WSS without a router port-forward. The tunnel exposes only the game server. [GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages) is static hosting; [Quick Tunnels](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/) provide temporary public endpoints.

To restart public co-op hosting and publish its new endpoint, run from this folder:

```sh
python3 tools/host_public.py start
```

To stop public co-op hosting:

```sh
python3 tools/host_public.py stop
```

The hosting processes run independently of this terminal in the current macOS login session. Logging out, rebooting, or sleeping the Mac interrupts multiplayer. GitHub Pages remains available for solo play. Tunnel URLs change when restarted; the start command updates `server.json` on Pages automatically (deployment may take a minute). Logs and the background server build are in `~/Library/Caches/GraveMaintenance/PublicHosting/`. This prototype uses a temporary tunnel rather than an always-on backend.

After changing the game, export it with `tools/export_web.sh`, then run the public hosting start command again to publish the new build. Alternatively, `python3 tools/publish_pages.py --server-url wss://your-server.example` publishes a build for a permanent secure backend.

## Controls and shift

| Action | Keyboard / mouse | Touch |
|---|---|---|
| Move | WASD or arrow keys | Drag the left side; release to stop |
| Face | Mouse | Movement direction |
| Take / enter equipment | Left click the nearby tool | Face the desired item; Use / Take |
| Mow | Move while controlling the mower | Move while controlling the mower |
| Rake / blow leaves | Hold left click | Hold Use |
| Take a bag / deliver at dumpster | Left click | Use |
| Spray | One left click per spray | One tap of Use per spray |
| Hose / pressure washer | Hold left click | Hold Use |
| Drop / exit / return tool | Right click | Drop / Return |
| Extract | Left click near truck or Extract button | Use near truck or Extract button |

Equipment sits on the trailer south of the cemetery. Right click **inside the trailer's return area** to snap it back into storage. Returning tools does not extract you. Walk to the marked truck zone and intentionally extract. A warning allows leaving without all tools. Wagons/carts retain cargo when you exit; collect their bags at the northern dumpster before returning equipment.

The maintenance building and dumpster are north; 12 offset graves and 8 bins occupy the center; the truck, trailer, and leafy street are south. Walking the main path from truck to the building takes about 11 seconds at normal speed.

The clock maps one real second to one in-game minute: 10 PM at start, midnight at 120 seconds, 3 AM at exactly 300 seconds. Warnings occur at 270, 285, and 295 seconds. **Work and extraction close at 300 seconds.** Witches then rapidly eliminate anyone remaining; a 312-second fail-safe ends the aftermath. Early extraction or a team wipe can end a shift sooner. The timer uses monotonic wall time, so backgrounding a solo browser tab does not pause the deadline. Dead and extracted employees spectate the remaining crew.

## Four jobs, four consequences

- **Mowing:** cut grass changes visibly; progress counts cut cells. Faster, wider mowers carry more impact risk. Very light contact is safe. Severe grave collisions can wake that grave's zombie.
- **Leaves:** rake or blow the orange leaves while managing sound. Noise decays when paused. Staying above 85% noise for 2.5 seconds wakes a ghost; no ambient random ghost spawns.
- **Trash:** each of 8 bins contains one bag. Carry 1 by hand, 2 in a wagon, 4 in a cart. Deliver at the building's dumpster. Hard or accumulated mishandling can awaken a werewolf; tiny bumps and stationary bag drops are safe.
- **Graves:** unlimited spray / hose / washer. Stop at 95–105%. Spray uses one click per dose. Continuous tools trade precision for speed. Extended cleaning above 105%, or significant overshoot, wakes a vampire. Over-cleaning is never a water-capacity problem.

Zombies pathfind around solid obstacles and persist after acquiring a player. Ghosts pass through obstacles and periodically vanish. Werewolves chase quickly with line-of-sight and last-seen memory. Vampires stalk, telegraph, then burst when nearby. Each standard monster has a mistake trigger. Witches are the scheduled deadline consequence. There are no weapons or damage-to-monster systems.

## Money and ownership

`data/equipment.json` contains names, tiers, prices, capacities, work rates, sound, speeds, and risk values. `data/contract.json` contains the $1,000 maximum, $150 initial balance, and configurable 15% penalty per dead employee.

Each category pays 25% of the maximum, proportionally to its completion. Trash counts delivered bags and grave cleaning counts graves at least 95% clean. Death is the **only** payout deduction. A full team wipe pays $0. Online payouts split equally in cents across the original crew, with remainder cents distributed deterministically. Equipment loss removes ownership rather than deducting from the contract payout.

Each employee owns separate equipment instances with unique IDs. Lobby contributions form one shared physical trailer loadout with 18 visible storage slots. Employees can own up to 24 tool instances, and the lobby shows the team trailer capacity. Other employees can use and recover your tools. Returned equipment goes to its original owner, even after that employee dies. Tools left outside at departure are lost. Free basic replacements can be claimed in the shop after losing them; upgraded tools must be purchased again.

Ownership and cash save in `user://crew_profile.json` (browser IndexedDB for web). Contributed equipment is removed from available ownership at shift start, preventing reloads from returning risky equipment for free. Settlement restores returned tools and credits the payout once. Interrupted shifts retain pending receipts; reconnecting to the same live server can recover completed receipts. Starting another shift preserves older pending receipts.

For the MVP, local saves are trusted. There are no account logins, cloud saves, or anti-cheat economy. Two employees need independent browser profiles/devices, since tabs on one origin share the same saved employee. Reconnect receipts are bounded in server memory and do not survive a server restart. Mid-shift reconnect/spectator rejoin is not implemented; a disconnected employee is counted dead and drops equipment for the remaining crew to recover.

## Co-op

1. Connect to the WebSocket address in the lobby.
2. Host a public room, or enter a password and host a locked room.
3. Other employees join a public listing or enter the room code and password.
4. Offer/remove owned tools. Each card shows readiness, contribution names, and equipment value at risk.
5. Every employee must be ready. Only the room host can start. Any loadout change clears that employee's ready state.

Private rooms are omitted from the public listing. Password hashes stay on the server. Rooms are limited to four employees and reject mid-shift joining. Host authority transfers when the host leaves a lobby. The dedicated server runs all task, collision, inventory-in-match, threat, death, extraction, and payout logic; clients send bounded movement/action intent. Snapshots run at 20 Hz, input at 30 Hz. Pickup actions are serialized to prevent double ownership.

Internet hosting needs an accessible dedicated Godot server and an HTTPS site with a **WSS** reverse proxy. Set `window.GRAVE_SERVER_URL` in `web/shell.html` before starting the engine, or enter the deployed WSS address in the lobby. No remote hosting has been provisioned. Godot web clients cannot listen for incoming WebSockets, so browser co-op uses the supplied native dedicated server. See [Godot web export documentation](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html).

## Develop and test

Open `project.godot` with Godot 4.6.2, or use the Godot executable via `GODOT_BIN`:

```sh
export GODOT_BIN=/path/to/Godot
sh tools/run_server.sh
# In another terminal:
python3 tools/serve.py
```

Export a fresh single-threaded compatibility-renderer web build (install Godot's matching export templates first):

```sh
sh tools/export_web.sh
```

Run headless milestone and regression checks, followed by an isolated dedicated server and four clients:

```sh
python3 tools/test.py --network
```

The test harness rejects script errors as well as nonzero exits, enforces timeouts, isolates test profiles, and tears down its test server. Generated audio is original; `python3 tools/generate_audio.py` regenerates the small WAV cues. The procedural cemetery art needs no external art assets.

| Folder | Responsibility |
|---|---|
| `scripts/core` | Config catalog, authoritative shift orchestration |
| `scripts/world` | Cemetery layout, collision, A* navigation |
| `scripts/tasks` | Grass/leaves/payout, trash, cleaning |
| `scripts/equipment` | Equipment instances, storage, selection, recovery |
| `scripts/monsters` | Persistent threat behavior |
| `scripts/progression` | Local ownership, escrow, purchases, settlement |
| `scripts/network` | Server room service, WebSocket transport, client session |
| `scripts/ui` | Procedural renderer, mouse/touch input, audio cues |
| `data` | Configurable tuning and prices |
| `tests` | Milestone and multiplayer regressions |
| `web` / `tools` | Browser shell, export, serve, launch, test utilities |

Temporary silhouettes and simple arcade vehicle controls are intentional. Network movement currently uses authoritative snapshots without client prediction; high-latency internet play may feel less responsive than local play. Additional maps and tasks are outside this prototype's scope.
