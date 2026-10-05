#!/usr/bin/env python3
"""Serve the single-threaded Godot export over HTTP, including correct WASM MIME."""
import argparse
import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, '.wasm': 'application/wasm', '.pck': 'application/octet-stream'}
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8080)
    parser.add_argument('--directory', default=str(Path(__file__).resolve().parents[1] / 'build/web'))
    args = parser.parse_args()
    print(f'Play at http://localhost:{args.port} — use this computer’s LAN IP on iPhone', flush=True)
    ThreadingHTTPServer(('0.0.0.0', args.port), functools.partial(Handler, directory=args.directory)).serve_forever()
