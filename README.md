# AGORA — a grassroots barter app, through the GLP cascade

AGORA is a small barter economy written as a grassroots social contract and
compiled to a running app by the cascade of Ehud Shapiro's
[GLP repository](https://github.com/EShapiro2/GLP): English clauses → act
schemas → grassroots check → platform (vGLP) → GLP → agents.

Members of a market list one-of-a-kind items, post offers and wants to the
market's wall, which its keeper relays to every member (seeing a post makes you
know its poster), and swap items by mutual consent.

This repository holds only the AGORA files; they are laid over the GLP
repository at a pinned commit (see `Dockerfile`).

## What is here

| Path | What |
|---|---|
| `overlay/programs/agora/AGORA.txt` | the contract in English, with its pragmas (the app's tabs and buttons) |
| `overlay/programs/agora/AGORA.glp` | the act schemas (the formal half of the contract) |
| `overlay/cascade/AGORA/` | the recorded cascade run: schemas, verdict, platform, compiled GLP, play log |
| `overlay/programs/vglp/cva/agora/` | a scripted play (alice, bob, carol trade a bike for jam) |
| `overlay/programs/vglp/cva/agora_live/` | the live harness: four agents, alice, bob, carol, dave, in one heap |
| `overlay/agora_server/` | the web server (Dart) that runs the live harness and is every person; the page |
| `tools/add_to_cascade.sh` | registers `agora` in the GLP repo's `cascade.sh` |

## Run the cascade yourself

With the GLP repo checked out at the pinned commit and Dart installed:

```
cp -r overlay/. <GLP>/
bash tools/add_to_cascade.sh <GLP>
cd <GLP> && bash cascade.sh agora
```

## Deploy on Render

1. On Render: **New → Blueprint**, pick this repository. Render reads `render.yaml`.
2. Set `APP_KEY` to a word of your choice when asked.
3. Open `https://<your-app>.onrender.com/?key=<APP_KEY>`.

Each acting step runs the real platform in the GLP engine, which is CPU-heavy
(about 3 s of CPU per act on a laptop). `render.yaml` asks for the Starter
plan; the Free plan works but is very slow, and it sleeps when idle, which
resets the world.

## Run locally on Windows, without Docker

Install [Git](https://git-scm.com/download/win) and the [Dart SDK](https://dart.dev/get-dart), then double-click `run_windows.bat` (or run it from cmd) and open <http://localhost:8080>.

## Run locally with Docker (Windows, Mac or Linux)

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/), then in this folder:

```
docker build -t agora .
docker run -p 8080:10000 agora
```

and open <http://localhost:8080>.
