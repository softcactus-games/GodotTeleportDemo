class_name ShredMinimalFrame
extends Resource

## How long this drawing is held before the next frame snaps into place.
@export_range(0.008, 0.5, 0.001, "suffix:s") var hold_seconds := 0.066:
	set(value):
		hold_seconds = value
		emit_changed()

## Chance that each whole scan row survives.
@export_range(0.0, 1.0, 0.01) var density := 0.5:
	set(value):
		density = value
		emit_changed()

## Length of surviving rows along the shred direction.
@export_range(0.0, 8.0, 0.05) var stretch := 0.6:
	set(value):
		stretch = value
		emit_changed()

## Random per-row offset along the shred direction.
@export_range(0.0, 0.5, 0.005) var stagger := 0.02:
	set(value):
		stagger = value
		emit_changed()

## Visible fraction inside each scan-row band.
@export_range(0.02, 1.0, 0.01) var line_width := 0.55:
	set(value):
		line_width = value
		emit_changed()

## Bias row survival toward the centre of the texture.
@export_range(0.0, 1.0, 0.01) var concentration := 0.0:
	set(value):
		concentration = value
		emit_changed()

## Pivot of the stretch along the shred direction.
@export_range(-1.0, 1.0, 0.01) var anchor := 0.0:
	set(value):
		anchor = value
		emit_changed()

## Overall opacity after stretch dimming.
@export_range(0.0, 2.0, 0.01) var alpha_gain := 1.0:
	set(value):
		alpha_gain = value
		emit_changed()
