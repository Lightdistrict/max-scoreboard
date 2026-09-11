# MAX Scoreboard

Custom Icefuse-style scoreboard for MAX DarkRP. Rows are colored per-job, grouped/sorted by job name, and show avatar, SAM usergroup icon, country flag, OS icon, mic status, job title, and money with an up/down trend arrow. A pin button at the bottom keeps the board on screen without holding Tab.

## Install

Drop this whole folder into `garrysmod/addons/max_scoreboard/` on the server (via Physgun's Git tab or File Manager).

## Flags

Add your flag icons to:

```
materials/max_scoreboard/flags/<lowercase ISO country code>.png
```

Examples: `us.png`, `gb.png`, `ca.png`, `de.png`

Also add a `materials/max_scoreboard/flags/unknown.png` fallback for players whose country can't be detected (used for LAN/local testing too).

## Usergroup icons (SAM)

Add icons named after each SAM usergroup to:

```
materials/max_scoreboard/groups/<groupname>.png
```

Examples (match your SAM group names exactly, lowercase): `admin.png`, `moderator.png`, `owner.png`, `vip.png`

Also add `materials/max_scoreboard/groups/user.png` as the fallback for the default `user` group. The icon is skipped entirely for default `user` players so the board doesn't get cluttered with the same icon on everyone.

## OS icons

Already covered by three fixed filenames — just drop these three in:

```
materials/max_scoreboard/os/windows.png
materials/max_scoreboard/os/linux.png
materials/max_scoreboard/os/osx.png
```

## Pin button

The button at the bottom of the scoreboard toggles "pinned" mode — while pinned, releasing Tab won't close the board. Click it again to unpin (and close, if Tab isn't currently held).

## Notes

- Country detection uses a free GeoIP HTTP lookup (`ip-api.com`) run server-side per player on join. No API key needed, but it's rate-limited (45 req/min) — fine for normal player join rates.
- OS detection is self-reported by each client (via `system.IsLinux()`/`system.IsOSX()`) on spawn and relayed through the server to everyone else.
- Usergroup icon reads `ply:GetUserGroup()`, which SAM (via CAMI) keeps in sync — no extra SAM-side config needed.
- Money trend arrows show for 6 seconds after a player's DarkRP money changes, comparing against the last known value.
- To re-theme colors (background, header, arrows), edit the `COLOR_*` locals at the top of `lua/autorun/client/cl_max_scoreboard.lua`.
