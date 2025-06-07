class_name OAuthCallbackListener extends Node

signal oauth_code_received(code: String, state: String)

const HOST: String = "127.0.0.1"
@export var port: int = 40542

@export var tls_key_path: String = "res://localhost.key"
@export var tls_cert_path: String = "res://localhost.crt"

var server: TCPServer
var TLS_key: CryptoKey
var TLS_cert: X509Certificate

var server_options: TLSOptions

var active_connections: Array[StreamPeerTLS] = []

func _ready() -> void:
	TLS_key = CryptoKey.new()
	var key_err: Error = TLS_key.load(tls_key_path)
	if key_err != OK:
		printerr("Failed to load TLS private key: %s." % key_err)
		return
	
	TLS_cert = X509Certificate.new()
	var cert_err: Error = TLS_cert.load(tls_cert_path)
	if cert_err != OK:
		printerr("Failed to load TLS private cert: %s." % cert_err)
		return
	
	print("TLS key and cert loaded successfully.")
	
	server_options = TLSOptions.server(TLS_key, TLS_cert)

func start_server() -> bool:
	if server != null and server.is_listening():
		printerr("Server is already running")
		return true
	
	server = TCPServer.new()
	var listen_err: Error = server.listen(port, HOST)
	if listen_err != OK:
		printerr("Failed to start HTTPCallbackListener: %s." % listen_err)
		server = null
		return false
	
	print("HTTPSCallbackListener started on https://%s:%s/auth/callback." % [HOST, port])
	set_process(true)
	return true

func stop_server() -> void:
	if server != null:
		server.stop()
		server = null
		print("HTTPSCallbackListener stopped.")
	for stream: StreamPeerTLS in active_connections:
		if stream != null:
			stream.disconnect_from_stream()
		active_connections.clear()
		set_process(false) 

func _process(_delta: float) -> void:
	if server == null or not server.is_listening():
		return
	
	if server.is_connection_available():
		var tcp_connection: StreamPeerTCP = server.take_connection()
		
		if tcp_connection != null:
			print("Incoming TCP connection from: %s:%s." % [tcp_connection.get_connected_host(), tcp_connection.get_connected_port()])
			var tls_stream: StreamPeerTLS = StreamPeerTLS.new()
			var err: Error = tls_stream.accept_stream(tcp_connection, server_options)
			
			if err != OK:
				printerr("TLS accept_stream failed: %s." % err)
				tcp_connection.disconnect_from_host()
				return
			
			print("TLS Stream accepted. Waiting for handshake...")
			active_connections.append(tls_stream)
	
	var i: int = active_connections.size() - 1
	
	while i >= 0:
		var stream: StreamPeerTLS = active_connections[i]
		
		if stream == null:
			active_connections.remove_at(i)
			i -= 1
			continue
		
		stream.poll()
		
		match stream.get_status():
			StreamPeerTLS.STATUS_HANDSHAKING:
				pass
			StreamPeerTLS.STATUS_CONNECTED:
				if stream.get_available_bytes() > 0:
					print("TLS Handshake complete. Reading request...")
					handle_http_request(stream)
					active_connections.remove_at(i)
			StreamPeerTLS.STATUS_ERROR:
				printerr("TLS Error during connection.")
				stream.disconnect_from_stream()
				active_connections.remove_at(i)
			StreamPeerTLS.STATUS_ERROR_HOSTNAME_MISMATCH:
				printerr("TLS Hostname Mismatch (should not occur on server).")
				stream.disconnect_from_stream()
				active_connections.remove_at(i)
			StreamPeerTLS.STATUS_DISCONNECTED:
				print("TLS Stream disconnected by peer or self before full request.")
				stream.disconnect_from_stream()
				active_connections.remove_at(i)
			_:
				printerr("TLS Unknown or unhandled status: %s." % stream.get_status())
				stream.disconnect_from_stream()
				active_connections.remove_at(i)
		
		i -= 1

func handle_http_request(tls_stream: StreamPeerTLS) -> void:
	var request_data: String = ""
	var start_time: int = Time.get_ticks_msec()
	
	while tls_stream.get_status() == StreamPeerTLS.STATUS_CONNECTED and tls_stream.get_available_bytes() == 0 and (Time.get_ticks_msec() - start_time < 500):
		tls_stream.poll()
		OS.delay_msec(10)
	
	if tls_stream.get_available_bytes() > 0:
		request_data = tls_stream.get_utf8_string(tls_stream.get_available_bytes())
		#print("Received request:\n%s" % request_data) -- FOR DEBUGGING
	else:
		printerr("No data received after handshake or connection lost.")
		tls_stream.disconnect_from_stream()
		return
	
	var code: String = ""
	var state: String = ""
	
	var lines: PackedStringArray = request_data.split("\n")
	if lines.size() > 0:
		var request_line: String = lines[0]
		var parts: PackedStringArray = request_line.split(" ")
		
		if parts.size() >= 2 and parts[0].to_upper() == "GET":
			var path_and_query: String = parts[1]
			if path_and_query.begins_with("/auth/callback?"):
				var query_string: String = path_and_query.substr(path_and_query.find("?") + 1)
				var query_params: PackedStringArray = query_string.split("&")
				
				for param: String in query_params:
					var kv: PackedStringArray = param.split("=")
					if kv.size() == 2:
						if kv[0] == "code":
							code = kv[1].uri_decode()
						elif kv[0] == "state":
							state = kv[1].uri_decode()
	
	var response_body: String = """
	<html>
		<head><title>OAuth Login</title></head>
		<body>
			<h1>Authorization Successful!</h1>
			<p>You can close this window and return to the application.</p>
			<script>window.close();</script>
		</body>
	</html>
	"""
	
	var http_response: String = "HTTP/1.1 200 OK\r\n"
	http_response += "Content-Type: text/html; charset=utf-8\r\n"
	http_response += "Content-Length: " + str(response_body.to_utf8_buffer().size()) + "\r\n"
	http_response += "Connection: close\r\n"
	http_response += "\r\n"
	http_response += response_body
	
	tls_stream.put_data(http_response.to_utf8_buffer())
	
	OS.delay_msec(100)
	tls_stream.disconnect_from_stream()
	print("TLS Stream disconnected after handling.")
	
	if not code.is_empty():
		emit_signal(&"oauth_code_received", code, state)
	else:
		printerr("Could not extract OAuth code from the request.")

func _exit_tree():
	stop_server()
