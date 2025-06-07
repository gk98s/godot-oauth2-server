# Godot OAuth2 Server

[![Godot Version](https://img.shields.io/badge/Godot-4.4%2B-blueviolet.svg?style=flat-square)](https://godotengine.org)

A simple Godot addon to run a local HTTPS server, designed specifically to capture OAuth 2.0 authorization codes and states from a redirect callback on `localhost`. This is useful for desktop applications implementing OAuth flows (like Authorization Code with PKCE) where the redirect URI is `https://127.0.0.1:{port}/{path}`.

This addon allows you to configure the listening port and paths to your SSL/TLS certificate and key directly in the Godot Editor Inspector when you add the `OAuthCallbackListener` node to your scene.

---

## ✨ Features

*   **Local HTTPS Server**: Starts an HTTPS server on `127.0.0.1` (localhost).
*   **Configurable via Inspector**: Set the port and paths to your TLS key/certificate using exported variables when the node is added to your scene.
*   **OAuth Callback Handling**: Parses `code` and `state` parameters from the redirect URL (default path: `/auth/callback`).
*   **Signal-Based**: Emits a signal `oauth_code_received(code, state)` upon successful capture.
*   **Self-Signed Certificate**: Designed for use with self-signed SSL certificates for local development.
*   **Simple Integration**: Add the node to your scene, configure, and connect signals.

---

## 🔧 Installation

1.  **Download**:
    *   Clone this repository or download the `addons/local_https_oauth_listener` folder.
    *   Alternatively, if published on the Godot Asset Library, install it from there.
2.  **Place in Project**:
    *   Copy the `local_https_oauth_listener` folder into your Godot project's `addons/` directory.
3.  **Enable Plugin**:
    *   Go to `Project > Project Settings > Plugins` tab.
    *   Find "Local HTTPS OAuth Listener" in the list and set its status to **Enable**.

---

## 🔑 Prerequisites: SSL Certificate and Key

This addon requires a self-signed SSL certificate (`.crt`) and a private key (`.key`) to run an HTTPS server on `localhost`.

### Generating Your Certificate and Key

1.  **Install OpenSSL**: If you don't have it, [install OpenSSL](https://www.openssl.org/source/) (it's often pre-installed on Linux/macOS; Windows users might need to install it manually or use WSL).
2.  **Run the Command**: Open your terminal or command prompt and execute the following command. This will create `localhost.key` and `localhost.crt` in your current directory.

    ```bash
    openssl req -x509 -newkey rsa:2048 -keyout localhost.key -out localhost.crt -sha256 -days 365 -nodes -subj "/CN=localhost"
    ```
    *   `-nodes`: Ensures the private key is not encrypted with a passphrase (Godot's `CryptoKey.load` doesn't support passphrase-protected keys directly).
    *   `/CN=localhost`: Sets the "Common Name" of the certificate to `localhost`.

3.  **Place Files in Your Godot Project**:
    *   Move the generated `localhost.key` and `localhost.crt` files into your Godot project. A common practice is to create a dedicated folder, e.g., `res://certs/`. The default paths expected by the addon are `res://localhost.key` and `res://localhost.crt`.

### Browser Warning (Important!)

When your application redirects to `https://127.0.0.1:{PORT}/...`, your web browser will display a security warning (e.g., "Your connection is not private," "NET::ERR_CERT_AUTHORITY_INVALID"). **This is expected behavior** because the certificate is self-signed and not issued by a trusted Certificate Authority (CA).

You (and your users during testing) will need to:
1.  Click on "Advanced" (or similar, depending on the browser).
2.  Choose to "Proceed to 127.0.0.1 (unsafe)" (or similar).

This allows the browser to complete the redirect to your local Godot-powered HTTPS server.

---

## 🚀 How to Use

The addon provides an `OAuthCallbackListener` node (`OAuthCallbackListener.gd`).

1.  **Add the Node to Your Scene**:
    *   Open the scene where you want to manage the OAuth callback (e.g., your main menu or a dedicated login scene).
    *   Instance the `OAuthCallbackListener.gd` script as a node in your scene. You can do this by:
        *   Dragging `OAuthCallbackListener.gd` from the FileSystem dock onto your scene tree.
        *   Or, right-click on a parent node in your scene tree, choose "Add Child Node", search for `Node` (or your preferred base type), add it, and then attach the `OAuthCallbackListener.gd` script to this new node.
    *   Let's assume you name this node `MyOAuthListener` in your scene.

2.  **Configure the Listener in the Inspector**:
    *   Select the `MyOAuthListener` node in your scene tree.
    *   In the Godot **Inspector** panel, you will find the following exported properties to configure:
        *   **Port**: Set this to the port number your OAuth provider is configured to redirect to (e.g., `40542`).
        *   **Tls Key Path**: Set the path to your SSL/TLS private key file (e.g., `res://localhost.key` or `res://certs/localhost.key`).
        *   **Tls Cert Path**: Set the path to your SSL/TLS certificate file (e.g., `res://localhost.crt` or `res://certs/localhost.crt`).

    ![image](https://github.com/user-attachments/assets/5fb62578-f781-4150-911a-41f52a96e494)


    **Note on Callback Path**: The listener is currently hardcoded to handle requests to the path `/auth/callback` (e.g., `https://127.0.0.1:40542/auth/callback`). If your OAuth provider redirects to a different path (e.g., `/mycallback`), you will need to modify the line `if path_and_query.begins_with("/auth/callback?")` inside the `handle_http_request` function in `OAuthCallbackListener.gd`.

3.  **Connect to the Signal and Start the Server**:
    In a script attached to a parent node of `MyOAuthListener` (or any node that can access it):

    ```gdscript
    # Assuming MyOAuthListener is a child node of the node this script is attached to
    @onready var oauth_listener: OAuthCallbackListener = $MyOAuthListener 
    # Or, if it's elsewhere:
    # @onready var oauth_listener: OAuthCallbackListener = get_node("/root/YourMainScene/Path/To/MyOAuthListener")

    func _ready():
        # Properties (port, key_path, cert_path) should be set on oauth_listener
        # via the Inspector before running.

        if oauth_listener.start_server():
            print("OAuth Callback Listener started successfully.")
            # Connect the signal either in the editor (Node panel > Signals)
            # or by code:
            oauth_listener.oauth_code_received.connect(_on_oauth_code_received)
        else:
            printerr("Failed to start OAuth Callback Listener!")

    func _on_oauth_code_received(code: String, state: String):
        print("Authorization Code Received: ", code)
        if not state.is_empty():
            print("State Received: ", state)
        
        # TODO:
        # 1. Verify the 'state' if you used one in your authorization request.
        # 2. Exchange the 'code' for an access token with your OAuth provider.
        # 3. You might want to stop the listener if it's no longer needed:
        #    oauth_listener.stop_server()

    # Don't forget to stop the server when your application quits or the listener is no longer needed.
    func _notification(what: int):
        if what == MainLoop.NOTIFICATION_WM_CLOSE_REQUEST: # Or app exit
             if oauth_listener and oauth_listener.server and oauth_listener.server.is_listening():
                 oauth_listener.stop_server()


    # Call this when you initiate your OAuth flow (e.g., opening the browser)
    func initiate_oauth_login():
        # Make sure the listener is running before directing the user to the auth URL
        if not (oauth_listener.server and oauth_listener.server.is_listening()):
            if not oauth_listener.start_server(): # This will use the port/paths set in Inspector
                printerr("Could not start OAuth listener for login.")
                return
            # Ensure signal is connected if it wasn't via the editor
            if not oauth_listener.is_connected("oauth_code_received", Callable(self, "_on_oauth_code_received")):
                 oauth_listener.oauth_code_received.connect(_on_oauth_code_received)

        # Construct your authorization_url using the port configured on the listener node
        var redirect_uri = "https://%s:%s/auth/callback" % [oauth_listener.HOST, oauth_listener.port]
        var authorization_url = "YOUR_OAUTH_PROVIDER_AUTHORIZATION_URL_HERE" 
        # This URL should include:
        # - client_id
        # - redirect_uri (e.g., the 'redirect_uri' variable above)
        # - response_type=code
        # - scope
        # - code_challenge (for PKCE)
        # - code_challenge_method=S256 (for PKCE)
        # - state (optional but recommended)
        print("Opening auth URL: %s" % authorization_url) # For debugging
        OS.shell_open(authorization_url)
    ```
    You can also connect the `oauth_code_received` signal directly in the Godot Editor:
    1. Select your `MyOAuthListener` node.
    2. Go to the **Node** panel (usually next to the Inspector).
    3. Select the `oauth_code_received` signal.
    4. Click "Connect..." and choose the node and method that will handle the received code and state.

---

## 💡 Example: Conceptual OAuth Flow Integration

1.  **Generate PKCE**: Create a `code_verifier` and `code_challenge`.
2.  **Build Authorization URL**: Construct the URL for your OAuth provider, ensuring the `redirect_uri` matches what your instance of `OAuthCallbackListener` (e.g., `MyOAuthListener`) is configured for (host, port from Inspector, and `/auth/callback` path by default).
    *   Example `redirect_uri` construction: `var redirect_uri = "https://%s:%s/auth/callback" % [my_oauth_listener_node.HOST, my_oauth_listener_node.port]`
3.  **Start Listener & Open URL**:
    ```gdscript
    # In your OAuth manager script
    # @onready var my_oauth_listener_node: OAuthCallbackListener = $Path/To/MyOAuthListener

    func start_my_oauth_flow():
        # ... (generate code_verifier, code_challenge, state) ...
        var listener_port = my_oauth_listener_node.port # Get configured port from the node
        var redirect_uri = "https://127.0.0.1:%s/auth/callback" % listener_port
        # ... (construct authorization_url using this redirect_uri) ...

        if my_oauth_listener_node.start_server(): # Uses properties set in Inspector on this node
            # Ensure signal is connected (if not done in editor)
            if not my_oauth_listener_node.is_connected("oauth_code_received", Callable(self, "_on_oauth_code_received")):
                my_oauth_listener_node.oauth_code_received.connect(_on_oauth_code_received)
            OS.shell_open(authorization_url)
        else:
            printerr("Cannot start OAuth listener. Aborting login.")
    ```
4.  **User Authenticates**: The user logs in via the browser.
5.  **Redirect & Code Capture**: The browser redirects. Your `MyOAuthListener` node captures the `code` and `state`.
6.  **`_on_oauth_code_received` Triggered**: Your connected method receives the `code` and `state`.
7.  **Token Exchange**:
    *   Verify the received `state`.
    *   Make a POST request from Godot (e.g., using `HTTPRequest` node) to your OAuth provider's token endpoint, including the `grant_type=authorization_code`, `code`, `redirect_uri` (matching the one used in step 2), `client_id`, and `code_verifier`.
    *   Receive and store the access/refresh tokens.

---

## ⚙️ Configuration Summary

*   **Via Inspector (for the `OAuthCallbackListener` node instance in your scene)**:
    *   `Port`: The TCP port for the local HTTPS server (e.g., `40542`).
    *   `Tls Key Path`: Filesystem path to your private key (e.g., `res://localhost.key`).
    *   `Tls Cert Path`: Filesystem path to your certificate (e.g., `res://localhost.crt`).
*   **In Script (`OAuthCallbackListener.gd`)**:
    *   `HOST`: Typically `"127.0.0.1"`.
    *   **Callback Path**: The actual URL path segment (e.g., `/auth/callback`) is checked within the `handle_http_request` function. If your provider uses a different path, modify the line: `if path_and_query.begins_with("/auth/callback?")`.

---

## 🚦 Troubleshooting

*   **"Failed to start server" / "Address already in use"**: Another application (or a previous instance of your Godot app) might be using the specified `Port` (configured in the Inspector on your listener node). Try a different port (and update your OAuth provider config and Inspector setting) or find and stop the other application.
*   **Browser shows "Unable to connect" or similar (not a certificate warning)**:
    *   Ensure the `OAuthCallbackListener` server was successfully started in Godot. Check console logs.
    *   Verify the `Port` in the Inspector on your listener node is correct.
    *   Verify your OS firewall isn't blocking Godot from listening on the port.
*   **"Could not extract OAuth code"**:
    *   Double-check that the `Port` configured on your listener node matches your OAuth redirect URI.
    *   Verify the expected path in `handle_http_request` (default: `/auth/callback?`) matches the actual path used in your redirect URI.
    *   Ensure your OAuth provider is actually sending `code` (and optionally `state`) as query parameters.
*   **SSL/TLS Errors in Godot Console (e.g., "Failed to load TLS private key")**:
    *   Ensure `Tls Key Path` and `Tls Cert Path` in the Inspector on your listener node are correct and point to valid files.
    *   Verify the key/certificate files are not corrupted and were generated correctly.
    *   Ensure the private key (`.key` file) was generated *without* a passphrase (using the `-nodes` option in OpenSSL).

---

## 🛡️ Security Note

*   The self-signed certificate approach is **for local development and demonstration only**. It provides HTTPS for the `localhost` redirect but does not offer the full security of a certificate issued by a trusted CA.
*   **Never commit your `localhost.key` (private key) to a public repository if this addon were part of a larger, non-demo project where that key might be used for other purposes.** For this standalone addon intended for local OAuth demos, instruct users to generate their own as outlined.
*   Always use the `state` parameter in your OAuth flow to protect against CSRF attacks.
*   Always use PKCE (Proof Key for Code Exchange) for public clients like desktop applications.

---

## ❤️ Contributing

Contributions are welcome! If you have improvements or bug fixes, feel free to open an issue or submit a pull request.

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
