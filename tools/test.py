#!/usr/bin/env python3
"""Run Godot invariants, then a real WebSocket server with four independent clients."""
import os
import subprocess
import socket
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get('GODOT_BIN', 'godot')

def run(*args):
    result = subprocess.run([GODOT, '--headless', '--path', str(ROOT), *args], capture_output=True, text=True, timeout=30)
    if result.returncode or 'SCRIPT ERROR' in result.stdout + result.stderr or 'ERROR:' in result.stdout + result.stderr:
        raise RuntimeError(result.stdout + result.stderr)
    print(result.stdout.strip(), flush=True)

if __name__ == '__main__':
    run('--editor', '--import', '--quit')
    for i in range(1, 7):
        run('--script', f'tests/milestone_{i}.gd')
    run('--script', 'tests/regressions.gd')
    run('--script', 'tests/controls.gd')
    run('--script', 'tests/ui_boundaries.gd')
    if '--network' in os.sys.argv:
        code_file = Path('/tmp/grave_network_room.txt')
        code_file.unlink(missing_ok=True)
        # Independent ephemeral port: tests never join the user's development server.
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            port = sock.getsockname()[1]
        server_log = tempfile.TemporaryFile(mode='w+')
        server = subprocess.Popen([GODOT, '--headless', '--path', str(ROOT), '--', '--server'], env={**os.environ, 'GRAVE_PORT': str(port)}, stdout=server_log, stderr=subprocess.STDOUT)
        clients = []
        try:
            for _ in range(100):
                try:
                    with socket.create_connection(('127.0.0.1', port), timeout=.1): break
                except OSError:
                    time.sleep(.05)
            else: raise RuntimeError('Dedicated test server failed to start')
            for i in range(4):
                cmd = [GODOT, '--headless', '--path', str(ROOT), '--script', 'tests/network_client.gd', '--', f'--test-profile=network_test_{i}', f'--test-server=ws://127.0.0.1:{port}']
                if i == 0: cmd.append('--host-test')
                clients.append(subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True))
            for client in clients:
                output, _ = client.communicate(timeout=25)
                print(output.strip(), flush=True)
                if client.returncode or 'ERROR:' in output or 'SCRIPT ERROR' in output or 'NETWORK CLIENT PASS' not in output:
                    raise RuntimeError('Network client failed')
        finally:
            for client in clients:
                if client.poll() is None: client.kill()
            code_file.unlink(missing_ok=True)
            server.terminate()
            server.wait(timeout=10)
            server_log.seek(0)
            output = server_log.read()
            server_log.close()
            if 'SCRIPT ERROR' in output or 'ERROR:' in output: raise RuntimeError(output)
    print('ALL CHECKS PASSED', flush=True)
