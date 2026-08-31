---
name: playtest
description: Run, screenshot and playtest this Godot Super Mario Bros. clone inside the container - downloads Godot, runs it headless under Xvfb with software GL, drives it with synthetic keyboard input, captures screenshots, and runs in-engine test harnesses. Use this whenever you change gameplay, physics, sprites, scenes or the HUD and want to see it actually working, whenever you need a screenshot of the game, whenever someone reports something looks wrong or broken in-game, and before pushing any gameplay change - the project has no automated tests, so running it really is the only way to catch regressions.
---

# Playtesting this game

The project is a Godot 4 game with no test suite, so the only real verification
is running it. That is possible in this container, and the setup below is known
to work end to end. Skipping it and reasoning from the code alone has repeatedly
missed real breakage — see *Lessons* at the bottom.

## Getting set up

```bash
bash .claude/skills/playtest/scripts/setup.sh
```

Installs `xvfb`, `imagemagick`, `xdotool`, `unzip`, downloads Godot 4.3, and
imports the project. Idempotent, so re-run it freely; only the first run pays
the ~50 MB download.

The project targets Godot 4.7 but 4.3 opens and runs it fine. That version gap
matters when writing files back — see *The .import trap*.

## Looking at the game

```bash
bash .claude/skills/playtest/scripts/run.sh                    # screenshot the main scene
WAIT=20 SHOT=later.png bash .claude/skills/playtest/scripts/run.sh
bash .claude/skills/playtest/scripts/run.sh res://test_foo.tscn   # run a test scene
```

Output lands in `/tmp/godot-playtest/out/`. Read the PNG — a blank or black
frame means the game did not really start, so check `out/game.log`.

## The two acceptance tests

Run both before pushing a gameplay change. They exist because each caught a bug
that unit-style assertions did not.

```bash
bash .claude/skills/playtest/scripts/idle_check.sh    # Mario must survive doing nothing
bash .claude/skills/playtest/scripts/playthrough.sh   # Mario must make progress when played
```

`idle_check.sh` stands still for ~20s and tiles the HUD timer. **The numbers must
only go down.** A sample that reads higher than the previous one means the stage
reloaded, i.e. Mario died — that is the signature of an enemy reaching the spawn
point.

`playthrough.sh` runs right while jumping and tiles the frames, so you can see
whether Mario advances or is stuck. Check the timer in these frames too.

## Writing an in-engine test harness

For logic that is awkward to reach through the keyboard (scoring, enemy state
machines, power-ups), a throwaway scene is far more reliable than timed input.
Create `test_x.gd` + `test_x.tscn` at the repo root, run it with `run.sh`, then
delete both.

```gdscript
extends Node
var _f := 0
func _ck(l, a, e):
    var ok = a == e
    if not ok: _f += 1
    print(("PASS  " if ok else "FAIL  ") + l + ": got %s, expected %s" % [a, e])

func _ready():
    # Add the game under the tree ROOT: the code uses absolute paths such as
    # /root/Main/Stage, and add_child() straight from _ready() is refused
    # ("parent node is busy setting up children"), hence call_deferred.
    var main = preload("res://main.tscn").instantiate()
    get_tree().root.add_child.call_deferred(main)
    for i in 5: await get_tree().process_frame

    var player = get_tree().get_first_node_in_group("player")
    _ck("player is there", player != null, true)

    print("=== %s ===" % ("ALL PASSED" if _f == 0 else "%d FAILURE(S)" % _f))
    get_tree().quit(_f)
```

Things that will otherwise waste your time:

- **Enemies are dormant off screen.** Goomba and Koopa carry a
  `VisibleOnScreenEnabler2D`, so one placed far from Mario never moves and every
  assertion about its behaviour fails. Move it next to the player first, then
  wait a few physics frames.
- **Transformations are not instant.** Setting `player.state` plays a ~1s
  transition and only then runs `_update_tree()`. Wait ~150 physics frames
  before asserting on the resulting sprite.
- **`reload_current_scene()` reloads *your harness*.** Anything that kills Mario
  (death, game over, the timer expiring) reloads the current scene, which is the
  harness itself — `get_tree()` then returns null and the run collapses. Verify
  death and game-over paths externally with `idle_check.sh` instead, or assert
  immediately and `quit()` before the deferred reload lands.
- **New `class_name` scripts need a rescan.** A harness referencing a freshly
  created class fails to parse until you re-run `--import` (or `setup.sh`).

## The .import trap

Godot 4.3 rewrites `*.import` files and silently drops keys that 4.7 wrote
(`compress/uastc_level` and friends). Committing that quietly downgrades the
project. After any run, before staging:

```bash
for f in $(git diff --name-only -- '*.import'); do git restore --worktree -- "$f"; done
```

Keep genuinely new `.import` files for assets you added — only restore the ones
you did not mean to touch. Never `git add -A` straight after a playtest without
checking `git status` for `.import` churn.

Adding a new sprite? Write it as **8-bit RGBA**. ImageMagick helpfully optimises
down to 4-bit when an image has few colours, and Godot 4.7 will not display the
result — a bug that looks exactly like "the sprite disappeared":

```bash
convert in.png -depth 8 -define png:color-type=6 PNG32:assets/sprites/out.png
identify -format "%z\n" assets/sprites/out.png   # must print 8
```

The `.import` sidecar can be hand-written in 4.7 format: copy an existing one
and replace the hashed path, which is just `md5("res://assets/sprites/<name>")`.

## Gotchas of the container

- `pkill -f Godot` also matches the shell command line running it and kills your
  own session. Match exactly (`pkill -x Xvfb`) or use PIDs.
- Vulkan cannot initialise under Xvfb; `--rendering-driver opengl3` is required
  or Godot exits at startup. The scripts already pass it.
- ALSA and PulseAudio errors in the log are just the container having no sound
  card. They are never the cause of a failure.
- Startup under software GL takes ~10s. Screenshotting sooner captures a black
  window.
- Passing `--resolution` makes a smaller window that sits inside the captured
  root image, which looks like the game is letterboxed when it is not. Leave it
  off unless you are testing window sizing.

## Lessons this skill exists to prevent

- A change that made enemies always active passed every assertion and looked
  right in screenshots, but made the game unplayable: the first Goomba walked
  into Mario's spawn and killed him on a loop. Only idling in the level exposed
  it, and it shipped and had to be reverted.
- The world silently vanished (HUD still drawn, level gone) because a window
  resize divided by not-yet-known camera bounds and set zoom to infinity.
  Rendering bugs like this are invisible to logic tests — you have to look at a
  frame.
