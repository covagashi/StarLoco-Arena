# DofusArena 2.70 server - quick start

Run your own DofusArena 2 server. No setup, no database to install, no
configuration to write.

## 1. Start the server

**Windows** - double-click `arena-server.exe`.

> Windows may show *"Windows protected your PC"*. That appears for any program
> without a paid code-signing certificate. Click **More info -> Run anyway**.
> If you would rather check first, compare the file against `checksums.txt`
> (see the bottom of this page).

**Linux / macOS** - open a terminal in this folder and run:

```
chmod +x arena-server
./arena-server
```

> macOS may say the app "cannot be opened because it is from an unidentified
> developer". Right-click the file -> **Open** -> **Open**, or run
> `xattr -d com.apple.quarantine arena-server` once.

You will see something like:

```
  DofusArena 2.70 server v0.1.0

  Game server   0.0.0.0:5555
  Web portal    http://localhost:8080

  Settings written to config.yaml - edit it and restart to change anything.
  Press Ctrl+C to stop.
```

**Leave this window open** while you play. `Ctrl + C` stops the server.

The server just created two files next to itself:

| File | What it is |
|---|---|
| `config.yaml` | Every setting, explained. Edit it and restart. |
| `arena.db` | The database: accounts, coaches, teams. **This is your save - back it up.** |

## 2. Create your account

Open the **web portal** address the server printed (usually
<http://localhost> or <http://localhost:8080>) and fill in the form.

> The **first account created becomes the administrator** of the server. If
> that should be you, register before anyone else does.

## 3. The game data

The card, spell and arena data fights need is already in the `data` folder next
to `arena-server` - nothing to do here. The startup message confirms it:

```
  Game data     907 cards, 203 spells, 47 arenas
                from /path/to/arena-server/data
```

Using another copy instead? Point `--data` at a folder holding `data.bdat`,
`indexes.bdat` and `maps/`, or set `data_dir` in `config.yaml` to the same
path - either replaces the bundled copy.

Note that this is the **server's own data** (card/spell/arena records), not the
playable game - see the next step for that.

## 4. Connect with the game client

The game client is the Godot client in the project repository (`godot/`):
start it and pick or type your server on the login screen - `127.0.0.1:5555`
on the same computer, or the server machine's address (e.g.
`192.168.1.20:5555`) from another one - then log in with the account you
registered.

> The client is getting its own art (2026-10-25: the retail art and the
> tools that converted it were removed). Until that lands there is no
> playable client download; the server itself works as described here.

Your coach is created inside the game the first time you connect.

The web portal shows the exact address your players should use - just send them
the portal link and they can register and read it themselves.

## Playing with friends

- **Same house / same Wi-Fi:** friends use your computer's local address
  (e.g. `192.168.1.20:5555`). Nothing else to do.
- **Over the internet:** forward TCP port `5555` (and the web portal port) on
  your router to the machine running the server. Treat this as you would any
  other program you expose - see `DISCLAIMER.md` and the security notes in the
  project repository.

## Common problems

| Problem | Fix |
|---|---|
| *"another program is already using that port"* | A server is still running from earlier - close it. Or change `addr` in `config.yaml`. |
| The web portal will not open | Check the address the server printed; it does not always use port 80. |
| *"No game data ... fights are unavailable"* | The `data` folder next to `arena-server` got separated from it, or `--data`/`data_dir` points somewhere empty - see step 3. |
| Client cannot connect | The server window must still be running. Allow it through the firewall when asked. |
| Forgot who the admin is | The first account registered. To start over, stop the server and delete `arena.db` (this erases everything). |

## Updating

The server tells you at startup when a newer version is out. To update, download
the new archive and replace `arena-server` - keep your `config.yaml`, `arena.db`
and `data` folder.

To turn that check off, set `enabled: false` under `update_check:` in
`config.yaml`. It only ever performs one anonymous request to GitHub's public
release page; nothing about your server or your players is sent, and nothing is
downloaded or installed automatically.

## Verifying your download

Each release ships a `checksums.txt`.

```
# Linux / macOS
sha256sum -c checksums.txt

# Windows PowerShell
Get-FileHash .\arena-server_v0.1.0_windows_amd64.zip -Algorithm SHA256
```

Compare the result with the matching line in `checksums.txt`.

---

Full documentation, source code and support:
<https://github.com/StarLoco/StarLoco-Arena>
Discord: <https://discord.com/invite/k3Yk9DuhgY>
