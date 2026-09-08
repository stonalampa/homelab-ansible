import http.server
import socket
import threading


class HealthHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(204 if self.path == "/health" else 404)
        self.end_headers()

    def log_message(self, format, *args):
        return


def serve_tcp():
    with socket.socket() as server:
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(("127.0.0.1", 19091))
        server.listen()
        while True:
            connection, _ = server.accept()
            connection.close()


threading.Thread(target=serve_tcp, daemon=True).start()
http.server.ThreadingHTTPServer(("127.0.0.1", 18081), HealthHandler).serve_forever()
