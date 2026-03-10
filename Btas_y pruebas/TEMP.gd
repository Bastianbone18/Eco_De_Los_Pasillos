extends Node

func _ready():
	print("SaveManager:", SaveManager)
	var data = SaveManager.load_all()
	print(data)
