extends Node

@export var oauth_listener: OAuthCallbackListener

func _ready():
	oauth_listener.start_server()


func _on_o_auth_callback_listener_oauth_code_received(code: Variant, state: Variant) -> void:
	print(code, state)
