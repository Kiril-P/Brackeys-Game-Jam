b# Gameplay Mechanics Plan

## Design Pillars
- Readable mind-bending: every puzzle can feel surprising without feeling random.
- One variable at a time: teach one new rule per chamber, then combine rules later.
- Player-driven discovery with support: let players solve first, then use companion hints only when needed.
- Fast recovery loops: failed attempts should reset locally in under 20 seconds.
- Diegetic guidance: the companion robot is the primary hint and tutorial channel (voice-ready, subtitle-first fallback).
- No repeated filler interactions: avoid copy-paste "click anchor, door opens" loops.

## Mechanic Catalogue

### Existing Foundation (Keep)

#### Mechanic: Portal Reroute States
- Rule: interactables or triggers can switch a portal's runtime destination.
- Player verb: route planning and rerouting.
- First use: early Level 2 chamber.
- Combinations:
  - Orientation-gated seals.
  - Timed sprint windows.
  - Directional corridor memory.
- Failure handling:
  - Revert to last known stable route.
  - Keep nearby retry point.
  - Companion clarifies the currently active route state.

#### Mechanic: Orientation-Gated Progression
- Rule: triggers, seals, and gates validate only when player enters with a specific gravity orientation.
- Player verb: reorient gravity with intent.
- First use: Level 2 intro gate.
- Combinations:
  - Reroute state checks.
  - Sequence register.
  - One-way portal constraints.
- Failure handling:
  - Deny progression with clear feedback, not lethal punishment.
  - Maintain visible orientation glyph for the required state.

#### Mechanic: One Timed Sprint Beat
- Rule: short temporary window (8-12s) to execute traversal after setup.
- Player verb: quick movement execution under pressure.
- First use: end of first playable sector.
- Combinations:
  - Reroute + orientation at once.
- Failure handling:
  - Local reset near attempt start.
  - No long walk-backs.
  - Companion provides concise post-fail hint.

### New Mechanic A: Observation Collapse
- Rule: selected geometry toggles state based on whether the player camera is observing it continuously.
- Player verb: manipulate line-of-sight.
- First use: first chamber in second sector.
- Reusable patterns:
  - Look-away bridges.
  - Observed walls lock; unobserved walls dissolve.
  - "Watch this, move that" synchronization.
- Combinations:
  - Directional memory corridors.
  - Rerouted exits.
- Failure handling:
  - Emissive color telegraph for active/inactive state.
  - State transition dwell-time to avoid flicker confusion.
  - Never reveal instant-death transitions.

### New Mechanic B: Directional Memory Corridors
- Rule: corridor result depends on entry direction and/or traversal count state.
- Player verb: intentional backtracking and route memory.
- First use: second chamber in second sector.
- Reusable patterns:
  - Same doorway, different destination from opposite side.
  - Loop resolves only on Nth traversal.
  - Reset spur that restores expected loop state.
- Combinations:
  - Observation collapse.
  - Reroute console.
- Failure handling:
  - Direction glyphs at doorway frames.
  - State marker in corridor center.
  - Nearby reset option with no major penalty.

### New Mechanic C: Gravity Sequence Register
- Rule: progression requires entering a known sequence of gravity orientations (not just one orientation).
- Player verb: sequence execution and correction.
- First use: first chamber in third sector.
- Reusable patterns:
  - 3-step sequence early.
  - 4-5-step sequence later.
  - Partial decay on error (step back by 1) instead of hard full reset.
- Combinations:
  - One-way portals.
  - Timed final check.
  - Loop-state final gate.
- Failure handling:
  - Visible sequence progress indicator.
  - Wrong input feedback and current step callout.
  - Quick restart from current chamber.

### New Mechanic D: Recursive Pocket Rooms
- Rule: repeated traversal through a looped room increments room state until stabilization.
- Player verb: controlled repetition with state awareness.
- First use: first chamber in final sector.
- Reusable patterns:
  - State 0/1/2 modifies door topology.
  - Platform offsets change with each loop.
  - Portal target remaps per state.
- Combinations:
  - Sequence register for final stabilization gate.
  - Observation collapse windows.
- Failure handling:
  - Center-state marker (clear numeric/visual state).
  - Manual reset trigger always nearby.
  - Guaranteed non-softlock graph.

## Mechanic Combination Rules
- Introduce once, combine twice:
  - First encounter: standalone.
  - Second encounter: pair with one prior mechanic.
  - Third encounter: full synthesis gate.
- Keep puzzle complexity bounded:
  - Max 2 new constraints introduced in one room.
  - Do not combine timed pressure with unexplained rule changes.
- Preserve readability:
  - Every mechanic has persistent visual language (glyph, color, or state indicator).
  - Every fail has a nearby retry path.
- Anti-patterns (do not use):
  - Repeating identical anchor click three times with no rule change.
  - Hidden state changes with no telegraph.
  - Long backtracking after simple execution mistakes.

## Sector-by-Sector Progression

### Sector 1 (Current Level 2 Role, First Playable)
- Teach:
  - Portal reroute states.
  - Orientation-gated seals.
- Spike:
  - One short timed reroute sprint.
- Completion gate:
  - Requires reroute state + required orientation + timed success.

### Sector 2 (Current Level 3 Role)
- Teach:
  - Observation Collapse.
- Combine:
  - Observation Collapse + Directional Memory Corridors.
  - One reroute dependency.
- Completion gate:
  - Intentional backtracking solve with clear state telegraphs.

### Sector 3 (Current Level 4 Role)
- Teach:
  - Gravity Sequence Register.
- Combine:
  - Sequence register + one-way portal constraints.
- Completion gate:
  - Sequence lock opening recursive pocket access.

### Sector 4 (Current Level 5 Role, Final)
- Teach:
  - Recursive Pocket Rooms.
- Combine:
  - Controlled synthesis of all mechanic families.
- Completion gate:
  - Full stabilization objective.

## Reusable Technical Components

### 1) `ViewDependentGeometry`
- File: `res://scripts/mechanics/view_dependent_geometry.gd`
- Type: `class_name ViewDependentGeometry`
- Exports:
  - `shown_when_observed`
  - `dwell_time`
  - `target_mesh_path`
  - `target_collider_path`
- Signals:
  - `state_changed(active: bool)`

### 2) `DirectionalCorridorRouter`
- File: `res://scripts/mechanics/directional_corridor_router.gd`
- Type: `class_name DirectionalCorridorRouter`
- Exports:
  - `entry_a`
  - `entry_b`
  - `route_table`
  - `memory_mode`
- Signals:
  - `route_changed(route_id: StringName)`

### 3) `GravitySequenceLock`
- File: `res://scripts/mechanics/gravity_sequence_lock.gd`
- Type: `class_name GravitySequenceLock`
- Exports:
  - `required_sequence: PackedStringArray`
  - `decay_on_error: bool`
- Signals:
  - `progress_changed(step: int)`
  - `sequence_completed()`

### 4) `LoopStateController`
- File: `res://scripts/mechanics/loop_state_controller.gd`
- Type: `class_name LoopStateController`
- Exports:
  - `max_state`
  - `advance_on_portal_receive_paths`
  - `reset_trigger_path`
- Signals:
  - `loop_state_changed(state: int)`
  - `loop_stabilized()`

### 5) Flow Integration
- Update `res://scripts/world_gameplay_flow.gd` to be level-agnostic for completion commits and tutorial IDs.
- Keep progression persistence in `res://scripts/game_progress.gd`.
- Ensure first playable path aligns with current sector ordering decisions.

## Tutorial and Companion Hint Strategy

### Hint Philosophy
- Companion should feel like a clever guide, not a spoiler machine.
- Hints escalate by player struggle, not by fixed script timing.
- Voice lines are optional assets; subtitle timing is authoritative fallback.

### Hint Escalation Tiers
- Tier 0 (context line):
  - On room entry, define goal in one sentence.
- Tier 1 (nudge):
  - Trigger after first failed attempt or ~20-30s of no progress.
  - Suggest mechanic focus without giving exact solution.
- Tier 2 (directional hint):
  - Trigger after repeated failure count threshold.
  - Calls out one concrete next action.
- Tier 3 (explicit clue):
  - Optional accessibility tier for prolonged stuck states.
  - Reveals sequence fragment or correct first step.

### Companion Delivery Rules
- Use existing queue API (`queue_tutorial_line`) and HUD subtitle display.
- Enforce cooldown per hint topic to avoid repetition spam.
- Never interrupt critical traversal moments with long lines.
- Keep most lines under 3.5 seconds.

### Suggested Hint IDs (Voice-Ready)
- `sector1_intro`
- `reroute_nudge`
- `orientation_nudge`
- `timed_retry_hint`
- `observation_intro`
- `corridor_memory_hint`
- `sequence_intro`
- `sequence_error_hint`
- `loop_state_intro`
- `loop_reset_hint`
- `final_synthesis_hint`

### Voice Asset Convention
- Folder: `res://audio/companion/tutorial/`
- Filename: `<hint_id>.wav`
- Missing file behavior: subtitle-only fallback with provided duration.

## Fairness and Readability Rules
- Always show rule state:
  - Portal reroute state indicator.
  - Orientation glyph on required seals.
  - Sequence step progress indicator.
  - Loop state marker.
- Avoid hidden punishment:
  - No blind lethal drops from mechanic state changes.
  - No progress wipes for single mechanical mistakes (prefer decay or local reset).
- Keep retries short:
  - Target retry loop <= 20 seconds for core mechanic checks.
- Keep information local:
  - Required clues should be visible within the current chamber.

## Playtest Matrix

| Test | Scenario | Pass Criteria |
|---|---|---|
| Readability 1 | First encounter of each mechanic (no voice files) | Player can explain rule after 1-2 attempts |
| Retry speed | Failed solve in each chamber | Re-attempt possible in <= 20 seconds |
| Reroute correctness | Portal reroute state switching | Route state always matches indicator |
| Observation stability | Fast camera motion while toggling states | No confusing rapid flicker; dwell-time respected |
| Corridor memory | Entry direction + traversal count routing | Route table behaves deterministically |
| Sequence decay | Wrong gravity step in register | Decays by configured rule, no softlock |
| Loop safety | Recursive pocket room with repeated traversal | State advances/resets correctly; no dead state |
| Performance | Portal-heavy views on high and low_end profiles | No severe frame spikes from new mechanics |
| Persistence | Complete sector and relaunch | Unlock/completion state remains correct |

## Implementation Backlog (S/M/L)

### S
- Add root design glyph language (orientation, route, state markers).
- Define companion hint IDs and baseline subtitle copy.
- Add anti-pattern checklist to level review process.

### M
- Implement `ViewDependentGeometry`.
- Implement `GravitySequenceLock`.
- Add level-agnostic completion hook patterns in world flow.

### L
- Implement `DirectionalCorridorRouter` with traversal memory tables.
- Implement `LoopStateController` with robust reset and non-softlock guarantees.
- Full sector content pass using all mechanic combinations.

## Risks and Mitigations
- Risk: mechanics become too opaque.
  - Mitigation: strict visual telegraphs + tiered companion hints.
- Risk: excessive complexity from combining too many rules.
  - Mitigation: cap chamber complexity and enforce introduce-then-combine pacing.
- Risk: performance cost in portal-heavy rooms.
  - Mitigation: reuse existing profile/LOD systems and avoid unnecessary dynamic CSG.
- Risk: hint spam breaks immersion.
  - Mitigation: per-topic cooldown, event-based tiers, short lines only.

## Done Criteria
- Each mechanic has at least one standalone teaching room and one combined-use room.
- Companion hint tiers are implemented and testable without voice assets.
- All puzzle chambers pass retry-time and readability thresholds.
- No major softlocks in sequence/loop/state mechanics.
- Progression persistence remains stable across relaunch.
- Team has one authoritative design reference in this file and uses it for implementation decisions.
