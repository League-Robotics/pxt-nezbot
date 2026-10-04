#!/usr/bin/env bash
# code.sh — start the local MakeCode editor.
#
# Opens a browser window pointed at a local MakeCode server that
# reads this project's files from disk. Edits save directly back.
#
# Usage:
#   bash scripts/code.sh                # serve on default port (3232)
#   bash scripts/code.sh --port 8080    # serve on a specific port
#   bash scripts/code.sh --no-browser   # serve without launching a browser
#   HOST=0.0.0.0 bash scripts/code.sh   # bind all interfaces (see NOTE below)
#   BROWSER="Firefox" bash scripts/code.sh   # open in a different browser
set -euo pipefail

PORT="${PORT:-3232}"
# Bind the loopback interface, NOT 0.0.0.0.
#
# `pxt serve` builds the URL it opens (and prints) from this exact value:
#     http://<hostname>:<port>/#local_token=...
# With 0.0.0.0 that becomes "http://0.0.0.0:3232/...", which Safari refuses to
# navigate to — it opens an empty about:blank window instead. Binding localhost
# makes the URL one every browser can actually open.
#
# Container port-forwarding (devcontainer/Codespaces `forwardPorts`) works fine
# against a loopback-bound server, so this costs nothing there. Set HOST=0.0.0.0
# only if you need to reach the editor from another machine on the network.
HOST="${HOST:-localhost}"

# Chrome, NOT the system default browser.
#
# Downloading to the micro:bit from the editor uses WebUSB, and WebUSB only
# exists in Chromium-based browsers — Safari and Firefox do not implement it at
# all. On a Mac the default browser is usually Safari, so letting the system
# choose hands you an editor whose Download button cannot talk to the board.
BROWSER="${BROWSER:-Google Chrome}"
OPEN_BROWSER=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --port) PORT="$2"; shift 2 ;;
        --host) HOST="$2"; shift 2 ;;
        --browser) BROWSER="$2"; shift 2 ;;
        --no-browser|--noBrowser) OPEN_BROWSER=0; shift ;;
        *) shift ;;
    esac
done

cd "$(dirname "$0")/.."

# The editor's local workspace is <cwd>/projects/<name> — PXT creates that
# directory but never puts this project in it, so the editor would otherwise
# open an empty "My Projects" list instead of the program in this repo.
# Link projects/<repo-name> back to the repo root: the editor then loads this
# project's pxt.json (extensions included), main.ts and main.blocks straight
# from disk, and edits save back to the same files.
PROJECT_NAME="$(basename "$(pwd)")"
mkdir -p projects
if [ ! -L "projects/$PROJECT_NAME" ]; then
    ln -sfn .. "projects/$PROJECT_NAME"
    echo "Linked projects/$PROJECT_NAME -> this repo"
fi

# targetconfig.json — the server reads this path RELATIVE TO CWD (server.js
# "GET config" handler), but we deliberately run from the repo root rather than
# from the target dir so that projects/ above resolves to this repo. The file
# only ships inside the target, so without this link every editor request for it
# 404s with `Error: ENOENT ... targetconfig.json` and the editor loses the
# approved-extensions list it consults when resolving github: dependencies.
if [ ! -e targetconfig.json ] && [ -f node_modules/pxt-microbit/targetconfig.json ]; then
    ln -sfn node_modules/pxt-microbit/targetconfig.json targetconfig.json
fi

# New projects made in the editor start with this repo's extensions.
node scripts/new-project-template.mjs

# _history is MakeCode's undo-history scratch file. Delete a stale one at
# startup, because a stale one silently BRICKS SAVING for the whole project:
# the server's save path (pxt-core server.js) compares every file's on-disk
# bytes against the client's `prevContent` and returns 409 for the ENTIRE save
# if any single file disagrees --
#     merge error for _history: previous content changed...
# -- whereupon the editor puts up "Project Auto-Save Disabled" and quietly
# stops persisting anything. Edits still compile and download (the compiler
# reads the live buffer), so the project appears to work right up until you
# reload and find your changes gone. A MISSING file skips the check entirely
# (the read's error handler swallows it), so removing it is the fix, and the
# editor recreates it immediately. Cost is losing undo history across restarts.
# You hit this whenever the editor is killed while files change underneath it.
rm -f _history

# The local token authorises the editor's /api/* calls against this server.
# pxt generates one into ~/.pxt/config.json on first serve; we create it first so
# we know its value up front and can build a complete URL ourselves.
PXT_CONFIG="${HOME}/.pxt/config.json"
mkdir -p "$(dirname "$PXT_CONFIG")"
LOCAL_TOKEN="$(node -e '
const fs = require("fs"), p = process.argv[1];
let c = {};
try { c = JSON.parse(fs.readFileSync(p, "utf8")); } catch (e) {}
if (!c.localToken) {
    c.localToken = require("crypto").randomUUID();
    fs.writeFileSync(p, JSON.stringify(c, null, 4) + "\n");
}
process.stdout.write(c.localToken);
' "$PXT_CONFIG")"

# .header.json is how the editor identifies a project in its workspace. The
# filesystem workspace (fsworkspace listAsync) reuses this file's `id` verbatim
# when it is present, and only invents a random one when it is missing. Writing
# it ourselves gives the project a STABLE id, which is what lets us jump the
# browser straight to #header:<id> instead of dumping the user on the "My
# Projects" home screen to hunt for it.
HEADER_ID="$(node -e '
const fs = require("fs");
const cfg = JSON.parse(fs.readFileSync("pxt.json", "utf8"));
let h = {};
try { h = JSON.parse(fs.readFileSync(".header.json", "utf8")); } catch (e) {}
if (!h.id) {
    const now = Math.round(Date.now() / 1000);
    let targetVersion = "";
    try {
        targetVersion = JSON.parse(
            fs.readFileSync("node_modules/pxt-microbit/package.json", "utf8")
        ).version;
    } catch (e) {}
    // Field-for-field the shape pxt.workspace.freshHeader() produces.
    h = {
        target: "microbit",
        targetVersion,
        name: cfg.name,
        meta: {},
        editor: cfg.preferredEditor || "tsprj",
        pubId: "",
        pubCurrent: false,
        _rev: null,
        id: require("crypto").randomUUID(),
        recentUse: now,
        modificationTime: now,
        cloudUserId: null,
        cloudCurrent: false,
        cloudVersion: null,
        cloudLastSyncTime: 0,
        isDeleted: false,
    };
    fs.writeFileSync(".header.json", JSON.stringify(h, null, 4) + "\n");
}
process.stdout.write(h.id);
')"

# ?ws=fs selects the FILESYSTEM workspace. This is the flag that actually makes
# the editor read this repo. main.js picks its storage backend with
#     query.ws ? setupWorkspace(query.ws) : ... : isPxtElectron() ? "fs" : "browser"
# so outside the Electron app the default is "browser" — IndexedDB in the tab.
# Without ?ws=fs the editor never calls /api/list at all: the local server sits
# there serving nothing while the tab shows its own separate browser-local
# projects, which is exactly the empty, extension-less project we were seeing.
# #local_token authorises the /api/* calls; it does NOT switch the workspace.
#
# Order matters inside the fragment. main.js strips the token with
#     hash.replace(/(%23)?[#&?]*local_token.*/, "")
# which eats local_token AND everything after it — so #header: has to come first
# or it would be swallowed along with the token.
# /index.html, not /: the server 301s "/" to "/index.html" and the redirect
# DROPS the query string, silently taking ?ws=fs with it.
EDITOR_URL="http://${HOST}:${PORT}/index.html?ws=fs#header:${HEADER_ID}&local_token=${LOCAL_TOKEN}&wsport=$((PORT + 1))"

echo "=== MakeCode Local Editor ==="
echo "    Project:  $PROJECT_NAME"
echo "    Files:    $(pwd)"
echo ""
echo "    $EDITOR_URL"
echo ""
echo "    Press Ctrl+C to stop."
echo ""

# Open the browser ourselves rather than letting pxt do it: pxt's own URL has no
# #header:, so it always lands on the home screen. Always pass --no-browser
# through to pxt so only one window opens.
if [ "$OPEN_BROWSER" -eq 1 ]; then
    (
        # Wait for the port to accept connections before opening, otherwise the
        # browser races the server and shows a connection error.
        for _ in $(seq 1 120); do
            if nc -z "${HOST}" "${PORT}" 2>/dev/null; then
                break
            fi
            sleep 0.5
        done
        if command -v open >/dev/null 2>&1; then
            # -a "$BROWSER" first; fall back to the default browser if that
            # application is not installed on this machine.
            open -a "$BROWSER" "$EDITOR_URL" 2>/dev/null || {
                echo "WARNING: '$BROWSER' not found — falling back to the default browser." >&2
                echo "         WebUSB downloads need Chrome; Safari and Firefox cannot flash the micro:bit." >&2
                open "$EDITOR_URL"
            }
        elif command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$EDITOR_URL"
        else
            echo "No browser opener found — open the URL above manually."
        fi
    ) &
fi

# --just: serve WITHOUT rebuilding the editor target.
#
# Without it, `pxt serve` tries to build pxt-microbit from source and dies with
#   Build failed: target build failed: ENOENT: ... scandir 'libs'
# because a target build wants a checkout of pxt-microbit (which has libs/,
# sim/, etc.), not a project like this one. The server then starts anyway with
# no editor webapp, and the browser hangs forever on the MakeCode splash.
# The prebuilt webapp already ships in node_modules, so there is nothing to build.
#
# --wsport is derived from --port so a second editor on another port does not
# collide with the default websocket port (3233) of the first.
exec npx pxt serve \
    --just \
    --localbuild \
    --noSerial \
    --hostname "$HOST" \
    --port "$PORT" \
    --wsport "$((PORT + 1))" \
    --no-browser
