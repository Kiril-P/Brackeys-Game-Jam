# Project State Handoff

Last updated: 2026-02-19
Workspace: `/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam`

## Critical Known Issue

- `Locked portal visuals are NOT working in runtime.`
- Functional lock behavior works (teleport lock + physical blockers), but the red visual layer/panels/laser bars are still not visible in play mode.
- Relevant files to debug next:
  - `/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam/scripts/world_gameplay_flow.gd`
  - `/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam/scenes/world.tscn`
- `LockVisuals` nodes exist in scene and blocker visuals are being configured in script, but result is still invisible in-game.

## What Has Been Implemented

## Core Flow and Progression

- Added persistent progression autoload:
  - `/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam/scripts/game_progress.gd`
  - Registered in `/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam/project.godot` as `GameProgress`.
- Progress save data supports:
  - unlocked levels
  - completed levels
  - seen tutorial lines
- Default progression starts with `level_1` unlocked.
- Completion chain currently unlocks `level_2` after `level_1` completion.

## World Orchestration

- Added world flow orchestrator:
  - `/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam/scripts/world_gameplay_flow.gd`
- Handles:
  - hub onboarding/tutorial triggers
  - cube side lock/unlock logic
  - Level 1 completion commit on hub return
  - subtitle forwarding via companion/hud hooks
- Level 1 is currently forced unlocked by default with:
  - `level1_starts_unlocked = true`

## Companion and HUD Systems

- Companion tutorial queue + voice-ready fallback:
  - `/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam/scripts/companion_tv.gd`
  - `/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam/scenes/companion_tv.tscn` (`VoicePlayer` node)
- Works without voice files:
  - if `.wav` missing, subtitles still run with fallback durations.
- Companion movement optimization pass implemented:
  - budgeted route scoring
  - cached physics query checks with TTL + quantized keys
  - click-reaction dedupe safety by frame id
- HUD improvements:
  - subtitle strip support in `/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam/scripts/gravity_debug_hud.gd`
  - debug gravity HUD hidden by default
  - `F3` toggle action support (`toggle_debug_hud`)

## Player/Runtime Stability

- Player out-of-bounds fail-safe settings added in:
  - `/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam/scripts/player_controller.gd`
- Runtime CSG bake preservation fix implemented in:
  - `/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam/scripts/runtime_csg_baker.gd`
  - non-CSG gameplay children are reparented before CSG roots are hidden.
- Temp scene artifact protection added:
  - `/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam/.gitignore` includes `*.tscn*.tmp`

## Docs Updated

- Project direction updated:
  - `/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam/.cursorrules/AGENT.md`
- Mechanics roadmap doc created:
  - `/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam/GAMEPLAY_MECHANICS_PLAN.md`

## Level 1 Changes (Detailed)

Level 1 now has a dedicated runtime state machine in:
`/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam/scripts/level_1_flow.gd`

### State Model

- `ENTRY`
- `STAIRS_LOOP`
- `DENSE_PORTAL`
- `FINAL_SEAL`
- `RETURN_OPEN`

Tracked runtime variables:

- `stairs_loops_completed`
- `dense_route_state` (0..2)
- `dense_fail_count`
- `final_seal_passed`

### Act A: Stair Loop + Backtrack Reveal

- `StairsLoopTrigger` increments loop count.
- Player must first confirm at least one loop.
- `ReverseRevealTrigger` checks movement direction:
  - must walk backward (while facing forward) through reveal lane.
- On success:
  - `DenseGate` opens
  - flow advances to dense portal phase
  - companion hint shifts to dense puzzle framing

### Act B: Dense Portal State Puzzle (Deterministic)

- Three choice triggers:
  - `DenseChoiceTriggerA`
  - `DenseChoiceTriggerB`
  - `DenseChoiceTriggerC`
- Choices update `dense_route_state` deterministically (not random).
- `dense_progress_portal.exit_portal` is rewired by state:
  - state `0` -> local loop target 0
  - state `1` -> local loop target 1
  - state `2` -> final-route target
- `DenseStateIndicator` nodes show active state visually (`State0/1/2`).
- Only state `2` advances to final chamber logic.

### Act C: Final Orientation Seal + Return

- `FinalOrientationSealTrigger` checks player gravity orientation.
- Required orientation defaults to `Vector3.LEFT` (`required_final_up`).
- Wrong orientation:
  - denies progress
  - emits explicit hint
- Correct orientation:
  - opens `ReturnGate`
  - marks final phase as passed
  - emits return-to-hub guidance

### Completion Commit Behavior

- `Level1CompleteTrigger` marks run as completion-ready only after final conditions.
- Completion is committed in world flow when player returns to hub through Level 1 cube link.
- Commit call:
  - `GameProgress.mark_completed("level_1")`
- Unlock result:
  - `level_2` unlocks immediately on successful commit.

### Scene Wiring Added for Level 1

In `/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam/scenes/world.tscn`:

- `Level 1/Level1Flow`
- `Level 1/StairsLoopTrigger`
- `Level 1/ReverseRevealTrigger`
- `Level 1/DenseGate`
- `Level 1/DenseChoiceTriggerA`
- `Level 1/DenseChoiceTriggerB`
- `Level 1/DenseChoiceTriggerC`
- `Level 1/DenseStateIndicator` (+ `State0/State1/State2`)
- `Level 1/FinalOrientationSealTrigger`
- `Level 1/ReturnGate`
- `Level 1/Level1CompleteTrigger`

## Locking and Blockers (Current State)

- Cube portal lock status is data-driven by progression state.
- Current lock stack:
  - teleport disabled on locked sides
  - teleport area monitoring disabled
  - hub-side `LockBlocker` collision enabled on locked sides
- Level 1 is intentionally unlocked now.
- Level 2/3/4 should be functionally blocked until unlocked.
- Visual presentation of those locks is currently broken in runtime (see critical issue at top).

## Boot/Runtime Validation Status

Latest smoke checks run in this workspace:

- `godot --headless --path '/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam' --quit`
- `godot --headless --path '/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam' --quit-after 20`

Both currently return cleanly (no script parse errors printed in these runs), including the previous invalid-script-UID concern.

## How To Playtest Every Small Change (Strict Workflow)

Use this exact loop for every micro-change, even tiny transforms/material edits.

1. Make one small change only.
2. Run boot smoke:
   - `godot --headless --path '/Users/kirilpetrovski/Documents/Coding/Game Dev/Brackeys-Game-Jam' --quit`
3. Open game and test only the behavior you changed.
4. Immediately run quick regression path:
   - spawn hub
   - enter Level 1
   - complete one loop interaction
   - return hub
5. Write result in a short changelog note:
   - change made
   - expected result
   - actual result
   - pass/fail
6. Only then do the next micro-change.

### Required Level 1 Micro-Tests After Any Level 1 Edit

1. `Stairs loop test`:
   - confirm forward repetition loops.
2. `Backtrack reveal test`:
   - confirm backward traversal through reveal lane opens `DenseGate`.
3. `Dense state test`:
   - confirm state indicator changes and portal route rewiring is deterministic.
4. `Final seal test`:
   - wrong gravity fails, correct gravity opens return gate.
5. `Commit test`:
   - completion triggers, return to hub, Level 2 unlock persists.

### Required Lock/Hub Micro-Tests After Any Portal Lock Edit

1. Level 1 is enterable at start.
2. Locked sides are physically blocked.
3. Locked-side companion hint triggers once with cooldown.
4. Unlock transition removes functional lock immediately.
5. Visual lock check currently expected to fail until fixed.

## Immediate Next Work Item Recommendation

Before Level 2 planning, fix lock visuals rendering so locked states are readable at a glance in-game.  
Keep gameplay lock behavior as-is since it is working; only fix visibility/render path.
