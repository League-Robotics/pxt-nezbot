# Nezha Robot Template — Start coding your robot

A MakeCode project template for driving an ElecFreaks
**Nezha** robot with the **DiffDrive** extension. Open this
in MakeCode, write a few lines of JavaScript, and your
robot drives straight, turns, and knows where it is.

**Hardware you need:**
- micro:bit **V2** (the extension is V2-only)
- ElecFreaks Nezha brick with two motors
- Left wheel on **M2**, right wheel on **M1**

---

## Quick start (no installs)

### 1. Open in MakeCode

Go to [makecode.microbit.org](https://makecode.microbit.org/),
click **Import**, and paste this repo's URL:

> https://github.com/League-Robotics/pxt-nezbot

### 2. Write your program

Open `main.ts` and start typing. The DiffDrive blocks appear
under the **DiffDrive** category. Everything is in centimeters,
centimeters per second, degrees, and degrees per second.

```typescript
// Drive a 30 cm square
input.onButtonPressed(Button.A, function () {
    diffDrive.resetPose()
    for (let i = 0; i < 4; i++) {
        diffDrive.move(30, 0)   // 30 cm straight
        diffDrive.move(0, 90)   // pivot 90° CCW
    }
})
```

### 3. Download and flash

Click **Download** in MakeCode. The `.hex` file goes onto
your micro:bit's drive — that's it.

---

## Local development (build and flash from your machine)

If you want to compile locally and flash directly from the
command line — no browser needed — you have two choices:
**npm run** scripts (beginner-friendly) or **make** targets.

### Prerequisites

- [Node.js](https://nodejs.org/) 20+
- [Docker](https://www.docker.com/) (for local compilation)
- micro:bit V2 plugged in via USB

Then run setup once:

```bash
npm run setup
```

This installs dependencies, the micro:bit PXT target, and the
DiffDrive extension from GitHub.

### npm run scripts

| Command | What it does |
|---------|-------------|
| `npm run setup` | Install dependencies + PXT target + extension |
| `npm run build` | Compile locally (uses yotta-compiler Docker image) |
| `npm run build:cloud` | Compile via MakeCode cloud service (no Docker needed) |
| `npm run deploy` | Build locally, then flash to the `MICROBIT` drive (macOS or Linux) |
| `npm run deploy:cloud` | Cloud build, then flash |
| `npm run code` | Start local MakeCode editor at http://localhost:3232 |
| `npm run clean` | Remove build artifacts |

### Make targets

| Command | What it does |
|---------|-------------|
| `make setup` | Install dependencies + PXT target + extension |
| `make build` | Compile locally (requires Docker) |
| `make build-cloud` | Compile via cloud service |
| `make deploy` | Build + flash to micro:bit |
| `make flash` | Flash a previously-built hex |
| `make code` | Start local MakeCode editor |
| `make docker-pull` | Pre-pull the yotta-compiler image |
| `make clean` | Remove build artifacts |

### Local vs cloud builds

**Local** (`make build` / `npm run build`) compiles on your
machine using the
[yotta-compiler](https://github.com/League-Microbit/yotta-compiler)
Docker image from GitHub Container Registry. `pxtarget.json` in
this repo points PXT at `ghcr.io/league-microbit/yotta-compiler:latest`
so you don't need to configure anything — the first build pulls
it automatically.

**Cloud** (`make build-cloud` / `npm run build:cloud`) sends your
code to MakeCode's compile service. No Docker required, but you
need an internet connection.

### Running the MakeCode editor locally

```bash
npm run code        # or: make code
```

Opens a browser window at http://localhost:3232 with a full
MakeCode editor that reads this project's files from disk.
Edits in the browser save directly back to `main.ts`. This
is the best workflow for iterating on blocks + code together.

---

## Dev container (VS Code / GitHub Codespaces)

This repo includes a `.devcontainer/devcontainer.json`
that gives you a complete development environment with
Node, Docker, PXT, and the yotta-compiler pre-installed.

### In VS Code

1. Install the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension
2. Open this repo
3. Click **Reopen in Container** when prompted
4. Wait for the post-create script to finish (`docker pull …`)
5. Run `make build` or `make code`

### In GitHub Codespaces

1. Open this repo on GitHub
2. Click **Code** → **Codespaces** → **Create codespace on main**
3. Wait for setup, then run `make build` or `make code`

The dev container forwards port 3232 so `make code` is
accessible from your local browser.

---

## What's included

| File | Purpose |
|------|---------|
| `main.ts` | Your program — this is where you write code |
| `main.blocks` | Block editor state (minimal starter) |
| `pxt.json` | Project config — declares the DiffDrive extension dependency |
| `pxtarget.json` | Points local builds at ghcr.io/league-microbit/yotta-compiler |
| `test.ts` | Smoke-test program compiled in CI, not shipped to students |
| `tsconfig.json` | TypeScript settings |
| `Makefile` | Build, deploy, flash, and editor targets |
| `scripts/` | Shell scripts backing the npm run / make targets |
| `.devcontainer/` | VS Code / Codespaces dev container config |

---

## The DiffDrive extension

This template depends on
[League-Microbit/pxt-diff-drive](https://github.com/League-Microbit/pxt-diff-drive),
which provides closed-loop differential drive control. It gives you:

- **Move blocks** — drive a distance, turn an angle, go to a point
- **Drive blocks** — continuous speed and turn rate
- **Pose** — the robot always knows its x, y, and heading
- **World tracking** — optional OTOS sensor for absolute positioning
- **Stall detection** — the robot stops if it runs into something

See the
[extension README](https://github.com/League-Microbit/pxt-diff-drive)
for the full block reference.

## License

MIT — see [LICENSE](LICENSE).