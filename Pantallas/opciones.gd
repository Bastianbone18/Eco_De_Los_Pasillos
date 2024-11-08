extends Control





func _on_creditos_pressed():
	get_tree().change_scene_to_file("res://Pantallas/creditos.tscn")


func _on_back_pressed():
	get_tree().change_scene_to_file("res://Pantallas/menu.tscn")
