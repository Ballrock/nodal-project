class_name CompositionBar
extends Control

## Barre segmentée de composition : RIFF (bleu), EMO (bleu clair),
## non résolu (jaune/orange), non alloué (gris), dépassement (rouge).

const COLOR_RIFF := Color(0.29, 0.56, 0.85)       # Bleu classique
const COLOR_EMO := Color(0.49, 0.78, 0.89)        # Bleu clair
const COLOR_UNRESOLVED := Color(0.75, 0.65, 0.3)  # Jaune/orange
const COLOR_UNALLOCATED := Color(0.3, 0.3, 0.35)  # Gris
const COLOR_OVERFLOW := Color(0.8, 0.25, 0.25)    # Rouge
const CORNER_RADIUS := 3

var riff_count: int = 0
var emo_count: int = 0
var unresolved_count: int = 0
var total: int = 0


func update_bar(p_riff: int, p_emo: int, p_unresolved: int, p_total: int) -> void:
	riff_count = p_riff
	emo_count = p_emo
	unresolved_count = p_unresolved
	total = p_total
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return

	var allocated := riff_count + emo_count + unresolved_count

	# Background (unallocated or overflow)
	_draw_rounded_rect(Rect2(0, 0, w, h), COLOR_UNALLOCATED)

	if total <= 0 and allocated <= 0:
		return

	var bar_max := maxi(maxi(total, allocated), 1)
	var x := 0.0

	# RIFF segment
	if riff_count > 0:
		var sw := float(riff_count) / float(bar_max) * w
		_draw_rounded_rect(Rect2(x, 0, sw, h), COLOR_RIFF)
		x += sw

	# EMO segment
	if emo_count > 0:
		var sw := float(emo_count) / float(bar_max) * w
		_draw_rounded_rect(Rect2(x, 0, sw, h), COLOR_EMO)
		x += sw

	# Unresolved segment
	if unresolved_count > 0:
		var sw := float(unresolved_count) / float(bar_max) * w
		_draw_rounded_rect(Rect2(x, 0, sw, h), COLOR_UNRESOLVED)
		x += sw

	# Overflow: red overlay from the total threshold to the end
	if allocated > total and total > 0:
		var threshold_x := float(total) / float(bar_max) * w
		_draw_rounded_rect(Rect2(threshold_x, 0, w - threshold_x, h), COLOR_OVERFLOW)


func _draw_rounded_rect(rect: Rect2, color: Color) -> void:
	if rect.size.x <= 0:
		return
	var points := PackedVector2Array()
	var r := mini(CORNER_RADIUS, int(rect.size.y / 2.0))
	var x1 := rect.position.x
	var y1 := rect.position.y
	var x2 := rect.position.x + rect.size.x
	var y2 := rect.position.y + rect.size.y
	# Simplified: just draw a regular rect for segments,
	# rounded corners on the full bar are handled by clip_children on parent
	draw_rect(rect, color)
