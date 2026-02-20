class_name SnapHelper
extends RefCounted

## Utilitaire de magnétisme pour la timeline et les slots.
## Convertit entre temps (secondes) et pixels, et fournit des fonctions de snap.


## Convertit un temps en secondes vers une position en pixels.
static func time_to_pixel(time_s: float, scale: float) -> float:
	return time_s * scale


## Convertit une position pixel vers un temps en secondes.
static func pixel_to_time(pixel_x: float, scale: float) -> float:
	if scale <= 0.0:
		return 0.0
	return pixel_x / scale


## Retourne l'intervalle de graduation adaptatif selon le niveau de zoom (scale = px/s).
## Plus le zoom est élevé, plus les subdivisions sont fines.
static func get_tick_interval(scale: float) -> float:
	if scale >= 500.0:
		return 0.01   # 10ms
	elif scale >= 200.0:
		return 0.05   # 50ms
	elif scale >= 100.0:
		return 0.1    # 100ms
	elif scale >= 50.0:
		return 0.25   # 250ms
	elif scale >= 20.0:
		return 0.5    # 500ms
	elif scale >= 10.0:
		return 1.0    # 1s
	elif scale >= 5.0:
		return 2.0    # 2s
	else:
		return 5.0    # 5s


## Retourne l'intervalle de graduation majeure (labels affichés).
static func get_major_tick_interval(scale: float) -> float:
	if scale >= 500.0:
		return 0.1
	elif scale >= 200.0:
		return 0.5
	elif scale >= 100.0:
		return 1.0
	elif scale >= 50.0:
		return 1.0
	elif scale >= 20.0:
		return 5.0
	elif scale >= 10.0:
		return 10.0
	else:
		return 30.0


## Snappe un temps sur la graduation la plus proche si dans le seuil.
## threshold_px : seuil en pixels écran (défaut 20 px, cf. spec §3.3).
## Retourne le temps snappé, ou le temps original si hors seuil.
static func snap_time(time_s: float, scale: float, threshold_px: float = 20.0) -> float:
	var tick := get_tick_interval(scale)
	if tick <= 0.0:
		return time_s
	var nearest := roundf(time_s / tick) * tick
	var dist_px := absf(time_s - nearest) * scale
	if dist_px <= threshold_px:
		return nearest
	return time_s


## Formate un temps en secondes pour affichage (adaptatif : "0.0s", "1.50s", "0.010s").
static func format_time(time_s: float, scale: float) -> String:
	if scale >= 500.0:
		return "%.3fs" % time_s
	elif scale >= 100.0:
		return "%.2fs" % time_s
	elif scale >= 20.0:
		return "%.1fs" % time_s
	else:
		return "%.0fs" % time_s
