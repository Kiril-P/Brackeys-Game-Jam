# AGENT.md - Game Vision and Implementation Direction

## Project Core
- Working title: `Fractal Horizons`.
- Engine: Godot `4.5.1` (Forward+ Vulkan).
- Genre: first-person puzzle exploration in strange, non-Euclidean spaces.
- Primary inspirations: `Antichamber` and `Manifold Garden`.

## Current Implementation Status
- Gravity flipping is already implemented in project history.
- Portals are already implemented and are a core system.
- Going forward, design and implementation should follow the updated loop below.

## Updated Core Fantasy
The player explores a 4D-feeling world of impossible geometry and stabilizes unstable fractal objects.  
A companion guide character travels with the player, helps teach mechanics, and delivers humorous voice lines.

## Companion Guide Direction
- Companion style inspiration: Dani's Billy from Karlsen (friendly, comedic guide role).
- The guide explains goals, introduces mechanics, and provides reactive hints.
- Voice lines should be funny but still useful for player clarity and pacing.

## Gravity Rules (Important Change)
- Player-controlled gravity switching is the active core interaction.
- The companion follows and adapts to the player's current gravity orientation.
- Companion-driven shared gravity switching is not an active gameplay requirement right now.

## Progression Structure
- Player spawns in `GravityPlayground`, which is the onboarding hub.
- The cube in `GravityPlayground` is the level selector.
- Level 1 starts unlocked.
- Additional cube sides unlock sequentially as levels are completed.
- Locked sides remain visible but non-teleport until unlocked.

## Current Playable Content
- Level 1 is implemented and includes:
  - Infinite staircase illusion where backward traversal is required to progress.
  - Infinite doorway sequence with one correct route.
- Level 2 unlocks after Level 1 completion (currently early/placeholder content).
- Levels 3 and 4 remain locked for now.
- Level 5 is currently unused.

## Near-Term Gameplay Priorities
- Finish Level 1 overhaul tuning (stairs telegraph readability, dense-route state clarity, final seal readability).
- Validate the full Level 1 completion chain (seal success -> return gate -> hub return commit -> Level 2 unlock persistence).
- Keep companion guidance subtitle-first and voice-ready; add `.wav` assets incrementally without blocking gameplay flow.
- Run focused fairness playtests so each hint tier resolves confusion without removing discovery.
- Begin Level 2 planning/implementation only after Level 1 onboarding quality is stable.

## Puzzle and Space Design
- Use portal mechanics for spatial paradoxes, misdirection, and layered puzzle logic.
- Most levels should be enclosed spaces for controlled puzzle readability.
- Some levels can open into vast outer-space environments for contrast and scale.
- Every room should center on one stabilization objective tied to its local geometry.

## Visual and Rendering Direction
- Keep surreal, minimal, high-contrast world readability.
- Space background should be an infinite fractal field.
- Target look for open space: 3D Euclid Orchard aesthetic.
- Implement fractal-space visuals with GLSL ray marching shaders.
- Use unshaded world materials when needed to preserve stylized graphic clarity.

## Technical Notes for Agents
- Portals: continue leveraging SubViewport-based portal rendering and stencil/masking workflows.
- Physics controller: `CharacterBody3D` with `move_and_slide()` and manually managed gravity vectors.
- Camera orientation should remain stable during player-driven gravity realignments.
- Optimize expensive visuals/portals when off-screen to preserve frame rate.

## Design Guardrails
- Prioritize readability of puzzle intent over visual noise.
- Companion behavior must feel reliable: nearest-surface targeting should be predictable.
- Gravity transitions should feel intentional and teachable, not random.
- Progression gating must be clear: no puzzle completion, no room exit.
