@tool
extends EditorPlugin

func _enter_tree() -> void:
	print("You have successfully installed OAuth2 Server! Make an OAuthCallbackListener node in order to get started.")

func _exit_tree() -> void:
	print("You have successfully uninstalled OAuth2 Server. Don't forget to remove and OAuthCallbackListener nodes that might be remaining.")
