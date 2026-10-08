extends Control

# Pixel-art star chart backdrop, deterministic so route visuals never jump.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var width := 2050.0
	var height := 540.0
	draw_rect(Rect2(0, 0, width, height), Color("#07152c"))
	for x in range(0, 2051, 48):
		draw_line(Vector2(x, 0), Vector2(x, height), Color(0.12, 0.36, 0.55, 0.18), 1.0)
	for y in range(0, 541, 48):
		draw_line(Vector2(0, y), Vector2(width, y), Color(0.12, 0.36, 0.55, 0.18), 1.0)
	# Distant planet: layered integer-step circles for a retro mechanical skyline.
	var center := Vector2(1550, 470)
	for radius in range(430, 340, -12):
		draw_circle(center, float(radius), Color("#102d53") if radius % 24 == 10 else Color("#103e70"))
	draw_arc(center, 432, PI * 1.1, PI * 1.96, 90, Color("#20b4ed"), 5)
	draw_arc(center, 441, PI * 1.12, PI * 1.9, 90, Color("#1f5f9c"), 10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261008
	for i in range(220):
		var p := Vector2(rng.randi_range(0, 2048), rng.randi_range(0, 540))
		var size := 2 if i % 7 == 0 else 1
		draw_rect(Rect2(p, Vector2(size, size)), Color("#54c9f4") if i % 4 == 0 else Color("#446c9a"))
	for i in range(48):
		var p := Vector2(rng.randi_range(0, 2048), rng.randi_range(0, 540))
		var size := float(rng.randi_range(4, 14))
		draw_rect(Rect2(p, Vector2(size, size)), Color("#1b2f48"))
		draw_rect(Rect2(p + Vector2(2, 2), Vector2(size * 0.6, size * 0.3)), Color("#344e69"))
	# Mechanical side silhouettes framing the holographic area.
	for i in range(7):
		var x := float(i * 50)
		draw_rect(Rect2(x, 478 - (i % 3) * 14, 42, 64), Color("#25344a"))
		draw_rect(Rect2(x + 6, 492 - (i % 3) * 14, 8, 4), Color("#ed8d2e"))
	for i in range(7):
		var x := float(1700 + i * 50)
		draw_rect(Rect2(x, 480 - (i % 3) * 20, 44, 64), Color("#26374e"))
		draw_rect(Rect2(x + 8, 490 - (i % 3) * 20, 12, 5), Color("#15bcf1"))
