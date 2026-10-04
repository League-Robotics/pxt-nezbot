# WiFi on the calibration image

The image this repo publishes brings up the Planet X Ai-WB2-12F WiFi
module only when credentials have been provisioned into the board's
flash store. It then advertises `<name>.local:7654`.

**Required path: provision credentials over the wire, after flashing,
with `WIFICRED`.** No
password is ever baked into the hex, committed to this repo, or typed
into a `.ts` file at all -- it lives only in the board's own flash, set
by a host tool talking to the already-flashed board:

```
HELLO
WIFICRED SET 0 <ssid> <password> #1
WIFICRED #2                          -> wificred 0 1 <ssid>
(power cycle)
```

`DBG:wifi` reports `credsrc=2` when the stored credentials are active.
An empty store leaves this image's WiFi link disabled; it does not try
program-supplied or baked credentials. Full grammar and the host-tool
helpers (`tools/provision_wifi.py`,
`tools/robotlink.py`'s `wificred_set()`/`wificred_clear()`/
`wificred_list()`), and every `DBG:wifi` field are documented in the
DiffDrive repo's
[`docs/robot-connections.md`](https://github.com/League-Robotics/pxt-nezha-diffdrive/blob/master/docs/robot-connections.md#provisioning-credentials-from-a-host-tool-wificred) --
that page is the source of truth for the wire grammar; this page covers
what is specific to a board built from this repo.

```bash
# from a pxt-nezha-diffdrive checkout, using a radio relay to reach a
# board already running THIS repo's firmware (no WiFi needed yet)
WIFI_PW=hunter2example uv run python tools/provision_wifi.py \
    --radio gopiv --slot 0 --ssid MyNetwork --password-env WIFI_PW
```

**A flash MASS-ERASES the whole chip, so credentials written before a
flash do not survive it** (MEASURED gopiv 2026-09-09/10,
`pxt-nezha-diffdrive/captures/wifi-credential-store-20260909/notes.md`:
a store written pre-flash enumerated empty after `mbdeploy deploy
--remote gopiv`). **Provision AFTER flashing this repo's image, never
before** -- the same order every fleet build in the other repo already
follows.

## No compiled credential fallback

`main.ts` calls `diffDrive.setupRobot()`, which uses
`enableStoredWifiLink()`, not `setupWifi()`. A new board (or one that has been reflashed) stays
offline until `WIFICRED SET` writes a credential and the board is reset.
This prevents a stale or malformed build-time SSID from being retried
when the store is empty.

## Verified working — gopiv, 2026-09-09

`captures/wifi-calibration-20260909/gopiv-wifi-after.log`. The image is
this repo's own calibration build (`--profile
calibration-wifi-check-20260909b`, DiffDrive `v1.20260907.5`), flashed
to gopiv over the network with `mbdeploy deploy --remote gopiv`:

```
rogo: 'gopiv robot link' -> gopiv.local.:7654 -> 192.168.1.218 (txt name=gopiv role=robot link=v6 port=7654)
device NEZHA2 robot gopiv 2175407711
pong 48129
id diffdrive calibration-wifi-check-20260909b 1.20260907.5 gopiv
DBG:wifi state=5 ip=192.168.1.218 peer=-:0 tcp=1/1 to=0 restarts=0 sent=7 rx=6 drop=0 mdns=1/1 ... credsrc=1 trunc=0
```

`state=5` is `kReady`, `mdns=1/1` is the announcement out and the socket
open, `restarts=0` says it joined on the first attempt. PING, ID and
STATUS all answered over TCP. This historical run predates the
`WIFICRED` pin and shows `credsrc=1` from the old `setupWifi()` path;
new releases use `credsrc=2` instead.

## The failure this replaced, and how to read it

Before the fix the same board sat here for hours:

```
DBG:wifi state=2 ... restarts=2783 ... cmd=AT+CIPDINFO=1 reply=..OK.. credsrc=1 trunc=0
```

`state=2` is `kJoin`; `restarts=2783` is the whole AT sequence being
torn down and started over, forever. Note what it does NOT look like: a
module that is missing or unpowered answers nothing at all
(`reply=` empty, and see `gopiv-wifi-listen.log` in the DiffDrive repo's
`captures/fleet-flash-20260904/`). Here the module replies `..OK..`. The
hardware was fine the entire time.

**The historical cause was a wrong password.** The old, gitignored
`test/secrets.ts` held a different password from the fleet's credential
source. Current calibration images no longer compile that file or use
the program-supplied credential path.

**A wrong password and an out-of-range AP used to be indistinguishable
from `DBG:wifi`** — both used to present as `state=1/2` with a climbing
`restarts` and nothing more. Since the DiffDrive repo's sprint 038
ticket 001, `DBG:wifi` also carries `join=<code>`, the module's raw
`+CWJAP:<code>` from the most recent attempt (`-` when none was
captured) — vendor documentation reads `2` as wrong password, `3` as AP
not found, but those meanings are unconfirmed on this hardware, so
treat the code as a diagnostic hint, not a certainty. Full field list
in the DiffDrive repo's `docs/robot-connections.md`. Originally tracked
here as `clasi/issues/wifi-join-failure-does-not-say-why.md` in the
DiffDrive repo; now closed by that ticket.

## What the published release can and cannot do

The public GitHub release has no WiFi credentials compiled into it. A
flashed board is reachable over USB and radio, but not WiFi until
provisioned. Run `tools/provision_wifi.py` against the board after
flashing, then reset it. A flash erases the credential store; provisioning
before a flash does not survive. Nothing secret touches this repo or
the release artifact.

Then confirm with `rogo --discover <board>` (expect an IP) rather than
by assuming — an empty or wrong password fails silently apart from the
`DBG:wifi` line above.
