@tool
extends Node3D

# The subject of shred_subviewport.tscn -- the twin of shred_minimal.tscn that
# shreds a live render instead of a loose PNG. This is the only script the
# scene adds, so the wiring notes live here; a .tscn cannot carry comments.
#
# What the scene demonstrates, and the four settings that make it work:
#
#   SourceViewport (SubViewport)
#     own_world_3d = true          its children are rendered by its camera and
#                                  by nothing else. With the default false
#                                  they would join the outer World3D and the
#                                  scene camera would show the cube next to
#                                  the shredded copy of it. TeleportShred
#                                  keeps false instead and isolates by cull
#                                  mask, because the enemy has to stay lit by
#                                  the room he is standing in.
#     transparent_bg = true        the shader discards where the capture's
#                                  alpha is zero, so anything but transparency
#                                  gives a shredded rectangle of background.
#     render_target_update_mode    UPDATE_ALWAYS (4). A SubViewport outside a
#                                  SubViewportContainer is never "visible", so
#                                  the default would render one frame or none.
#     size = 640x360               16:9, matching the quad and the shader's
#                                  frame_aspect. A mismatch stretches the
#                                  capture across the quad.
#
#   ShredQuad's ShaderMaterial
#     src_tex = ViewportTexture whose viewport_path points at SourceViewport,
#     and both the texture and the material are resource_local_to_scene so
#     that path is resolved against this scene when it is instantiated. It is
#     a material_override rather than QuadMesh.material because the override
#     is a node property, which is what the local-to-scene pass walks.
#
# Everything else -- the frame table, the timeline, the scan direction -- is
# shred_minimal.gd unchanged.
#
# @tool because the scene previews in the editor viewport: shred_minimal.gd
# keeps itself in _process there, and a non-tool spinner would leave the
# capture frozen while the shred animated over a still cube.

## Degrees per second about each local axis.
@export var spin_degrees_per_second := Vector3(14.0, 34.0, 0.0)


func _process(delta: float) -> void:
	rotation += spin_degrees_per_second * delta * (PI / 180.0)
