# Godot 4.5.1 Skills for Cursor
- Engine: Godot 4.5.1 (Forward+ Vulkan).
- Shaders: Use `render_mode unshaded` for world objects to get the Antichamber look.
- Post-Processing: Utilize `CompositorEffect` for global outlines.
- Portals: Leverage the new Stencil Buffer support for masking viewport textures.
- Physics: Use `CharacterBody3D` with `move_and_slide()`. Manually handle gravity to allow for 6-axis gravity shifting.
- Coding Style: GDScript 2.0 (static typing, `unique_names`, and `lambda` functions).