#!/usr/bin/env python3
# encoding: utf-8
"""WebSocket SSH proxy — stanlley-locke/vpn_script"""
import select
import socket
import sys
import threading
import time

IP = "0.0.0.0"
try:
    PORT = int(sys.argv[1])
except (IndexError, ValueError):
    PORT = 10015

PASS = ""
BUFLEN = 8196 * 8
TIMEOUT = 60
MSG = "POWERED BY stanlley-locke"
COR = '<font color="#30e528">'
FTAG = "</font>"
DEFAULT_HOST = "127.0.0.1:22"
RESPONSE = (
    "HTTP/1.1 101 "
    + COR
    + MSG
    + FTAG
    + "\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: foo\r\n\r\n"
)


class Server(threading.Thread):
    def __init__(self, host, port):
        super().__init__(daemon=True)
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.threads_lock = threading.Lock()

    def run(self):
        self.soc = socket.socket(socket.AF_INET)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        self.soc.bind((self.host, self.port))
        self.soc.listen(128)
        self.running = True
        try:
            while self.running:
                try:
                    client, _addr = self.soc.accept()
                    client.setblocking(True)
                except socket.timeout:
                    continue
                conn = ConnectionHandler(client, self)
                conn.start()
                self.add_conn(conn)
        finally:
            self.running = False
            self.soc.close()

    def add_conn(self, conn):
        with self.threads_lock:
            if self.running:
                self.threads.append(conn)

    def remove_conn(self, conn):
        with self.threads_lock:
            if conn in self.threads:
                self.threads.remove(conn)

    def close(self):
        self.running = False
        with self.threads_lock:
            threads = list(self.threads)
        for conn in threads:
            conn.close()


class ConnectionHandler(threading.Thread):
    def __init__(self, soc_client, server):
        super().__init__(daemon=True)
        self.client_closed = False
        self.target_closed = True
        self.client = soc_client
        self.client_buffer = b""
        self.server = server
        self.target = None
        self.method = "CONNECT"

    def close(self):
        if not self.client_closed:
            try:
                self.client.shutdown(socket.SHUT_RDWR)
                self.client.close()
            except OSError:
                pass
            self.client_closed = True
        if self.target and not self.target_closed:
            try:
                self.target.shutdown(socket.SHUT_RDWR)
                self.target.close()
            except OSError:
                pass
            self.target_closed = True

    def run(self):
        try:
            self.client_buffer = self.client.recv(BUFLEN)
            if not self.client_buffer:
                return
            buffer = self.client_buffer.decode("latin-1", errors="ignore")
            host_port = self.find_header(buffer, "X-Real-Host") or DEFAULT_HOST

            if self.find_header(buffer, "X-Split"):
                self.client.recv(BUFLEN)

            passwd = self.find_header(buffer, "X-Pass")
            if PASS and passwd != PASS:
                self.client.send(b"HTTP/1.1 400 WrongPass!\r\n\r\n")
                return
            self.method_connect(host_port)
        except Exception:
            pass
        finally:
            self.close()
            self.server.remove_conn(self)

    def find_header(self, head, header):
        aux = head.find(header + ": ")
        if aux == -1:
            return ""
        aux = head.find(":", aux)
        head = head[aux + 2 :]
        aux = head.find("\r\n")
        if aux == -1:
            return ""
        return head[:aux]

    def connect_target(self, host):
        if ":" in host:
            host, port_s = host.rsplit(":", 1)
            port = int(port_s)
        else:
            port = 443 if self.method == "CONNECT" else 22
        address = socket.getaddrinfo(host, port)[0][4]
        self.target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.target_closed = False
        self.target.connect(address)

    def method_connect(self, path):
        self.connect_target(path)
        self.client.sendall(RESPONSE.encode("latin-1"))
        self.client_buffer = b""
        self.do_connect()

    def do_connect(self):
        socs = [self.client, self.target]
        idle = 0
        while True:
            readable, _, errored = select.select(socs, [], socs, 3)
            if errored:
                break
            if not readable:
                idle += 1
                if idle >= TIMEOUT:
                    break
                continue
            idle = 0
            for sock in readable:
                try:
                    data = sock.recv(BUFLEN)
                except OSError:
                    return
                if not data:
                    return
                other = self.target if sock is self.client else self.client
                try:
                    other.sendall(data)
                except OSError:
                    return


def main(host=IP, port=PORT):
    print("\033[0;34m━" * 8, "\033[1;32m SSH WebSocket Proxy", "\033[0;34m━" * 8, "\n")
    print("\033[1;33mIP:\033[1;32m", host)
    print("\033[1;33mPORT:\033[1;32m", port, "\n")
    server = Server(host, port)
    server.start()
    try:
        while True:
            time.sleep(2)
    except KeyboardInterrupt:
        print("\nStopping...")
        server.close()


if __name__ == "__main__":
    main()
