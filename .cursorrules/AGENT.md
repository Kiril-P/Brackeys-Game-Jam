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
- Remove direct player-controlled gravity switching as the main interaction.
- The companion always tries to stand on the nearest valid wall/surface.
- When the companion attaches to a new surface, gravity updates for both:
  - companion gravity aligns to that surface normal
  - player gravity also aligns to that same surface
- This shared gravity shift is the core moment-to-moment gameplay loop.

## Progression Structure
- The player starts from a central cube hub with four enterable sides.
- Each side acts as a portal to a different puzzle room/level.
- Looking through a cube side should show an unstable object associated with that room.
- Entering that side transports the player to the room containing that object.
- The room is locked until the local puzzle is solved and the object is stabilized.
- After stabilization, exit/unlock flow returns the player to hub progression.

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
- Camera orientation should remain stable during shared gravity realignments.
- Optimize expensive visuals/portals when off-screen to preserve frame rate.

## Design Guardrails
- Prioritize readability of puzzle intent over visual noise.
- Companion behavior must feel reliable: nearest-surface targeting should be predictable.
- Gravity transitions should feel intentional and teachable, not random.
- Progression gating must be clear: no puzzle completion, no room exit.