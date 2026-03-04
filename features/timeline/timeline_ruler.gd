class_name TimelineRuler
extends Control

## Graduation horizontale du panneau timeline NLE.
## Dessine les ticks et les labels temporels (style ruler de NLE).

## Échelle en pixels par seconde.
var timeline_scale: float = 100.0:
	set(value):
		timeline_scale = value
		queue_redraw()

## Décalage horizontal du scroll (en pixels).
var scroll_offset_x: float = 0.0:
	set(value):
		scroll_offset_x = value
		queue_redraw()

const RULER_HEIGHT := 24
const COLOR_BG := Color(0.10, 0.10, 0.12, 1.0)
const COLOR_TICK_MINOR := Color(1.0, 1.0, 1.0, 0.2)
const COLOR_TICK_MAJOR := Color(1.0, 1.0, 1.0, 0.5)
const COLOR_LABEL := Color(1.0, 1.0, 1.0, 0.6)
const TICK_MINOR_HEIGHT := 6
const TICK_MAJOR_HEIGHT := 14
const LABEL_FONT_SIZE := 10


func _ready() -> void:
	custom_minimum_size.y = RULER_HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y

	# Fond du ruler.
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)

	var minor_interval: float = SnapHelper.get_tick_interval(timeline_scale)
	var major_interval: float = SnapHelper.get_major_tick_interval(timeline_scale)

	if minor_interval <= 0.0:
		return

	var t_start: float = SnapHelper.pixel_to_time(scroll_offset_x, timeline_scale)
	var t_end: float = SnapHelper.pixel_to_time(scroll_offset_x + w, timeline_scale)
	var first_tick: float = floorf(t_start / minor_interval) * minor_interval

	var t: float = first_tick
	while t <= t_end + minor_interval:
		var px: float = SnapHelper.time_to_pixel(t, timeline_scale) - scroll_offset_x
		var is_major := _is_major_tick(t, major_interval)

		if is_major:
			draw_line(Vector2(px, h - TICK_MAJOR_HEIGHT), Vector2(px, h), COLOR_TICK_MAJOR, 1.0)
			var label: String = SnapHelper.format_time(t, timeline_scale)
			draw_string(
				ThemeDB.fallback_font,
				Vector2(px + 3, LABEL_FONT_SIZE + 2),
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				LABEL_FONT_SIZE,
				COLOR_LABEL,
			)
		else:
			draw_line(Vector2(px, h - TICK_MINOR_HEIGHT), Vector2(px, h), COLOR_TICK_MINOR, 1.0)

		t += minor_interval

	# Ligne de base en bas du ruler.
	draw_line(Vector2(0, h - 1), Vector2(w, h - 1), Color(1.0, 1.0, 1.0, 0.15), 1.0)


func _is_major_tick(t: float, major_interval: float) -> bool:
	if major_interval <= 0.0:
		return false
	var remainder := fmod(absf(t), major_interval)
	return remainder < 0.001 or (major_interval - remainder) < 0.001
