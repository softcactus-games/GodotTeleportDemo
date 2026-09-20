@tool
extends Node3D

const SEED_STRIDE := 7.31

@export var animate := true:
	set(value):
		animate = value
		_restart_timeline()

## Frame shown while animation is disabled.
@export var preview_frame := 0:
	set(value):
		preview_frame = _clamp_preview_frame(value)
		if not animate:
			_apply_preview_frame()

@export var direction := Vector2.RIGHT:
	set(value):
		direction = value
		_apply_direction()

## Number of scan rows the image is torn into. Shared by every frame -- the
## shader's row grid is a property of the effect, not of one drawing.
@export_range(1, 256, 1) var line_count := 24:
	set(value):
		line_count = maxi(value, 1)
		_apply_line_count()

@export var frames: Array[ShredMinimalFrame] = []:
	set(value):
		_disconnect_frames()
		frames = value
		_connect_frames()
		preview_frame = _clamp_preview_frame(preview_frame)
		notify_property_list_changed()
		_restart_timeline()

@onready var _shred_quad: MeshInstance3D = $ShredQuad

var _material: ShaderMaterial
var _elapsed := 0.0
var _frame_index := -1
var _applied_signature := PackedFloat32Array()


func _ready() -> void:
	if not _ensure_material():
		push_error("ShredMinimal: ShredQuad has no ShaderMaterial")
		set_process(false)
		return
	_connect_frames()
	_restart_timeline()


# Resolved lazily rather than only in _ready(): editing this script hot-reloads
# it, which rebuilds plain vars without re-running _ready(), and a null
# _material would otherwise silently disable the whole preview until the scene
# was reopened.
func _ensure_material() -> bool:
	if _material != null:
		return true
	if _shred_quad == null:
		_shred_quad = get_node_or_null(^"ShredQuad") as MeshInstance3D
	if _shred_quad == null:
		return false
	_material = _shred_quad.get_active_material(0) as ShaderMaterial
	if _material == null:
		return false
	# The uniforms every frame shares are pushed here rather than only from
	# _ready(), so they survive a script hot-reload that rebuilt _material.
	_apply_direction()
	_apply_line_count()
	return true


func _process(delta: float) -> void:
	if not _ensure_material():
		return
	if not animate:
		# Held preview: the editor viewport only redraws while something is
		# processing, so staying here is what makes an Inspector edit to the
		# previewed frame visible. The signature check keeps that free when
		# nothing actually changed.
		if Engine.is_editor_hint():
			_refresh_preview()
		return
	var total_duration := _total_duration()
	if total_duration <= 0.0:
		_update_processing()
		return
	_elapsed = fmod(_elapsed + delta, total_duration)
	var wanted := _frame_at(_elapsed)
	if wanted >= 0 and wanted != _frame_index:
		_apply_frame(wanted)


func _apply_direction() -> void:
	if _material == null:
		return
	var scan_direction := direction.normalized()
	if scan_direction.is_zero_approx():
		scan_direction = Vector2.RIGHT
	_material.set_shader_parameter(&"scan_dir", scan_direction)


func _apply_line_count() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"row_count", float(line_count))


func _apply_frame(index: int) -> void:
	var frame := frames[index]
	if frame == null:
		return
	_frame_index = index
	_material.set_shader_parameter(&"step_seed", float(index + 1) * SEED_STRIDE)
	_material.set_shader_parameter(&"density", frame.density)
	_material.set_shader_parameter(&"stretch", frame.stretch)
	_material.set_shader_parameter(&"stagger", frame.stagger)
	_material.set_shader_parameter(&"line_width", frame.line_width)
	_material.set_shader_parameter(&"concentration", frame.concentration)
	_material.set_shader_parameter(&"anchor", frame.anchor)
	_material.set_shader_parameter(&"alpha_gain", frame.alpha_gain)
	_applied_signature = _frame_signature(index, frame)


func _frame_signature(index: int, frame: ShredMinimalFrame) -> PackedFloat32Array:
	return PackedFloat32Array([float(index), frame.density, frame.stretch,
			frame.stagger, frame.line_width, frame.concentration, frame.anchor,
			frame.alpha_gain])


# Editor-only: re-push the held frame when its authored values no longer match
# what the material is carrying. This is the path that makes an Inspector edit
# to the previewed frame land on the quad.
func _refresh_preview() -> void:
	var selected := _clamp_preview_frame(preview_frame)
	if selected >= frames.size() or frames[selected] == null:
		return
	if _frame_signature(selected, frames[selected]) == _applied_signature:
		return
	_apply_frame(selected)


func _frame_at(elapsed: float) -> int:
	var remaining := elapsed
	var last_valid := -1
	for index in frames.size():
		var frame := frames[index]
		if frame == null:
			continue
		last_valid = index
		remaining -= maxf(frame.hold_seconds, 0.001)
		if remaining < 0.0:
			return index
	return last_valid


func _total_duration() -> float:
	var duration := 0.0
	for frame in frames:
		if frame != null:
			duration += maxf(frame.hold_seconds, 0.001)
	return duration


func _restart_timeline() -> void:
	_elapsed = 0.0
	_frame_index = -1
	if _material != null:
		if animate:
			var first := _frame_at(0.0)
			if first >= 0:
				_apply_frame(first)
		else:
			_apply_preview_frame()
	_update_processing()


func _apply_preview_frame() -> void:
	if _material == null:
		return
	var selected := _clamp_preview_frame(preview_frame)
	if selected < frames.size() and frames[selected] != null:
		_apply_frame(selected)
		return
	var first := _frame_at(0.0)
	if first >= 0:
		_apply_frame(first)


func _clamp_preview_frame(value: int) -> int:
	return clampi(value, 0, maxi(frames.size() - 1, 0))


func _validate_property(property: Dictionary) -> void:
	if property.name == &"preview_frame":
		property.hint = PROPERTY_HINT_RANGE
		property.hint_string = "0,%d,1" % maxi(frames.size() - 1, 0)


func _update_processing() -> void:
	# In the editor the 3D viewport only redraws when something marks it
	# dirty, and a shader parameter pushed from a Resource.changed callback
	# does not. Staying in _process is what keeps the held preview redrawing,
	# so an Inspector edit to the previewed frame is visible immediately --
	# the same reason the animated loop was always visible here.
	if Engine.is_editor_hint():
		set_process(true)
		return
	set_process(animate and _material != null and _total_duration() > 0.0)


func _connect_frames() -> void:
	for frame in frames:
		if frame != null and not frame.changed.is_connected(_on_frame_changed):
			frame.changed.connect(_on_frame_changed)


func _disconnect_frames() -> void:
	for frame in frames:
		if frame != null and frame.changed.is_connected(_on_frame_changed):
			frame.changed.disconnect(_on_frame_changed)


func _on_frame_changed() -> void:
	if _material != null and _frame_index >= 0 \
			and _frame_index < frames.size() and frames[_frame_index] != null:
		_apply_frame(_frame_index)
	_update_processing()
