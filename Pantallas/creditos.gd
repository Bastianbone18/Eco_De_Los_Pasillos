extends Control





func _on_tiktok_pressed():
	OS.shell_open("https://www.tiktok.com/@bastianbone18")


func _on_ig_pressed():
	OS.shell_open("https://www.instagram.com/juanchoprietom/")


func _on_art_pressed():
	OS.shell_open("https://www.artstation.com/bastianbone18")


func _on_volver_pressed():
	get_tree().change_scene_to_file("res://Pantallas/opciones.tscn")
