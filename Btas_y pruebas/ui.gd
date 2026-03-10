extends CanvasLayer

func mostrar_dialogo():
	var dialogue_resource: DialogueResource = load("res://Dialogos/Primer_Dialogo.dialogue")
	var balloon_scene = preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")
	var balloon = balloon_scene.instantiate()
	
	# Instanciar el globo dentro del UI (o donde quieras mostrarlo)
	add_child(balloon)

	# Decirle al DialogueManager que use ese balloon
	DialogueManager.dialogue_view = balloon
	
	# Aquí es donde inicias el diálogo (asegúrate que el título sea correcto)
	DialogueManager.dialogue_view.start(dialogue_resource, "start")
