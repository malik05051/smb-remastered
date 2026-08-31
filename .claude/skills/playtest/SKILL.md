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

Installs `xvfb`, `imagemagick`, `xdotool`, `unzip`, downloads Godot 4.7, and
imports the project. Idempotent, so re-run it freely; only the first run pays
the ~100 MB download.

4.7 is the version `project.godot` targets, which keeps the working tree clean
— see *Use the version the project targets* for why that matters.

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

## Use the version the project targets

`setup.sh` pins Godot **4.7**, matching `config/features` in `project.godot`.
Keep it that way. An older build opens the project but rewrites every
`*.import` file on import, silently dropping keys the newer editor wrote
(`compress/uastc_level` and friends) — committing that quietly downgrades the
project for everyone else. On a matching version there is no such churn, so
after a playtest `git status` stays clean.

If you ever do run an older build, restore what it touched before staging:

```bash
for f in $(git diff --name-only -- '*.import'); do git restore --worktree -- "$f"; done
```

## Adding assets and scripts

Let Godot generate its own sidecar files rather than hand-writing them. Add the
`.png` or `.gd`, run `setup.sh` (or any script, which imports first), then
commit whatever Godot produced alongside it:

- new textures get a `.png.import`
- new scripts get a `.gd.uid` — the repo tracks these, and a script added
  outside the editor simply has none until an import pass creates it

Hand-writing an `.import` by hand is possible (the hashed path is just
`md5("res://path/to/file.png")`) but fragile: it is easy to omit the `uid` line
and end up with a resource the editor resolves inconsistently. Running the
import is cheaper and correct.

For sprites, match the repo's existing convention of 8-bit RGBA — ImageMagick
optimises the bit depth down when an image has few colours, and while a
low-depth PNG does load in 4.7 (tested), staying consistent with every other
sprite avoids a variable when something looks wrong:

```bash
convert in.png -depth 8 -define png:color-type=6 PNG32:assets/sprites/out.png
identify -format "%z\n" assets/sprites/out.png   # prints 8
```

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
