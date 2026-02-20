extends GutTest

## Tests unitaires pour SnapHelper — conversion temps/pixels et magnétisme.


func test_time_to_pixel() -> void:
	assert_eq(SnapHelper.time_to_pixel(0.0, 100.0), 0.0)
	assert_eq(SnapHelper.time_to_pixel(1.0, 100.0), 100.0)
	assert_eq(SnapHelper.time_to_pixel(2.5, 100.0), 250.0)
	assert_eq(SnapHelper.time_to_pixel(1.0, 200.0), 200.0)


func test_pixel_to_time() -> void:
	assert_eq(SnapHelper.pixel_to_time(0.0, 100.0), 0.0)
	assert_eq(SnapHelper.pixel_to_time(100.0, 100.0), 1.0)
	assert_eq(SnapHelper.pixel_to_time(250.0, 100.0), 2.5)
	assert_eq(SnapHelper.pixel_to_time(200.0, 200.0), 1.0)


func test_pixel_to_time_zero_scale() -> void:
	# Scale à zéro → ne doit pas planter, retourne 0.
	assert_eq(SnapHelper.pixel_to_time(100.0, 0.0), 0.0)


func test_roundtrip_time_pixel() -> void:
	var original := 3.14
	var scale := 100.0
	var px := SnapHelper.time_to_pixel(original, scale)
	var back := SnapHelper.pixel_to_time(px, scale)
	assert_almost_eq(back, original, 0.001)


func test_snap_time_snaps_within_threshold() -> void:
	# À scale=100, tick_interval=0.1s. Temps 1.008s est à 0.8px de 1.0s (< 20px).
	var snapped := SnapHelper.snap_time(1.008, 100.0, 20.0)
	assert_almost_eq(snapped, 1.0, 0.01)


func test_snap_time_no_snap_outside_threshold() -> void:
	# À scale=100, tick_interval=0.1s. Temps 1.5s est pile sur un tick.
	# Mais temps 1.35 est à 0.05*100=5px d'un tick de 0.1. Threshold=2 → pas de snap.
	var snapped := SnapHelper.snap_time(1.35, 100.0, 2.0)
	assert_almost_eq(snapped, 1.35, 0.001)


func test_snap_time_snaps_on_exact_tick() -> void:
	var snapped := SnapHelper.snap_time(2.0, 100.0, 20.0)
	assert_almost_eq(snapped, 2.0, 0.001)


func test_get_tick_interval_adapts_to_zoom() -> void:
	# Zoom élevé → intervalles fins.
	assert_true(SnapHelper.get_tick_interval(500.0) <= 0.05)
	# Zoom faible → intervalles larges.
	assert_true(SnapHelper.get_tick_interval(5.0) >= 1.0)


func test_get_major_tick_interval() -> void:
	# Major ticks sont toujours >= minor ticks.
	for scale in [0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 50.0, 100.0, 200.0, 500.0]:
		var minor := SnapHelper.get_tick_interval(scale)
		var major := SnapHelper.get_major_tick_interval(scale)
		assert_true(major >= minor, "Major tick interval should be >= minor at scale %s" % scale)


func test_format_time() -> void:
	# À haute échelle, plus de décimales.
	var label_hi := SnapHelper.format_time(1.234, 500.0)
	assert_true(label_hi.find("1.234") >= 0, "High zoom should show 3 decimals")

	# À basse échelle, moins de décimales.
	var label_lo := SnapHelper.format_time(5.0, 10.0)
	assert_eq(label_lo, "5s")


func test_get_tick_interval_low_scales() -> void:
	# Vérifier que les intervalles de tick sont raisonnables à basses échelles.
	assert_eq(SnapHelper.get_tick_interval(3.0), 5.0, "scale 3.0 → tick 5s")
	assert_eq(SnapHelper.get_tick_interval(1.5), 10.0, "scale 1.5 → tick 10s")
	assert_eq(SnapHelper.get_tick_interval(0.8), 30.0, "scale 0.8 → tick 30s")
	assert_eq(SnapHelper.get_tick_interval(0.3), 60.0, "scale 0.3 → tick 60s")
	assert_eq(SnapHelper.get_tick_interval(0.1), 300.0, "scale 0.1 → tick 300s")


func test_get_major_tick_interval_low_scales() -> void:
	assert_eq(SnapHelper.get_major_tick_interval(3.0), 30.0, "scale 3.0 → major 30s")
	assert_eq(SnapHelper.get_major_tick_interval(1.5), 60.0, "scale 1.5 → major 60s")
	assert_eq(SnapHelper.get_major_tick_interval(0.8), 300.0, "scale 0.8 → major 300s")
	assert_eq(SnapHelper.get_major_tick_interval(0.3), 600.0, "scale 0.3 → major 600s")
	assert_eq(SnapHelper.get_major_tick_interval(0.1), 900.0, "scale 0.1 → major 900s")


func test_format_time_minutes() -> void:
	# Format mm:ss pour scale < 2.0 et >= 0.5
	var label := SnapHelper.format_time(125.0, 1.0)
	assert_eq(label, "2:05", "125s à basse échelle devrait être formaté 2:05")

	var label_zero := SnapHelper.format_time(0.0, 1.0)
	assert_eq(label_zero, "0:00", "0s devrait être formaté 0:00")


func test_format_time_hours() -> void:
	# Format h:mm:ss pour scale < 0.5
	var label := SnapHelper.format_time(3661.0, 0.3)
	assert_eq(label, "1:01:01", "3661s devrait être formaté 1:01:01")

	var label_zero := SnapHelper.format_time(0.0, 0.3)
	assert_eq(label_zero, "0:00:00", "0s devrait être formaté 0:00:00")
