class_name FloatingText
extends RefCounted
## Petit texte 3D qui monte et s'efface (dégâts, "esquivé"...).


static func spawn(parent: Node3D, text: String, color: Color, height: float) -> void:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 64
	label.pixel_size = 0.01
	label.outline_size = 12
	label.modulate = color
	label.text = text
	label.position = Vector3(randf_range(-0.3, 0.3), height, 0)
	parent.add_child(label)
	var tw := label.create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 1.0, 0.8)
	tw.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(label.queue_free)
