# res://Scripts/UI/MainMenu.gd
extends Control

func _on_play_button_pressed():
	print("Play button pressed!") 
	
	var game_scene_path = "res://Scenes/Gameplay/game.tscn" 
	
	# Call change_scene_to_file ONLY ONCE and store the result
	var error_code = get_tree().change_scene_to_file(game_scene_path) 
	
	# Check the result of THAT call
	if error_code != OK:
		# Use printerr for errors, it prints to the standard error stream
		printerr("Error changing scene to: ", game_scene_path, " Code: ", error_code) 
		# You could potentially add more user feedback here if needed
