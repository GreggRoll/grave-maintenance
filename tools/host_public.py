#!/usr/bin/env python3
"""Run a temporary public co-op endpoint on macOS and update GitHub Pages."""
import argparse
import hashlib
import os
import re
import shutil
import socket
import subprocess
import tarfile
import time
import urllib.request
from pathlib import Path
from publish_pages import publish

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / '.runtime'
HOST_CACHE = Path.home() / 'Library/Caches/GraveMaintenance/PublicHosting'
SERVER_JOB = 'com.gravemaintenance.server'
TUNNEL_JOB = 'com.gravemaintenance.tunnel'

def running(label):
    return subprocess.run(['launchctl','list',label],capture_output=True).returncode == 0

def submit(label, log, args):
    subprocess.run(['launchctl','submit','-l',label,'-o',str(log),'-e',str(log),'--',*args],check=True)
    subprocess.run(['launchctl','kickstart',f'gui/{os.getuid()}/{label}'],check=True)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action',choices=['start','stop'])
    args = parser.parse_args()
    if args.action == 'stop':
        for label in [TUNNEL_JOB,SERVER_JOB]:
            if running(label): subprocess.run(['launchctl','remove',label],check=True)
        print('Public co-op hosting stopped. GitHub Pages remains available for solo play.')
        return
    RUNTIME.mkdir(exist_ok=True)
    HOST_CACHE.mkdir(parents=True,exist_ok=True)
    binary = RUNTIME / 'bin/cloudflared'
    if not binary.exists():
        arch = 'arm64' if os.uname().machine == 'arm64' else 'amd64'
        # Official release digest from GitHub; validate before executing the download.
        import json
        release = json.loads(subprocess.run(['gh','api','repos/cloudflare/cloudflared/releases/latest'],check=True,capture_output=True,text=True).stdout)
        asset = next(a for a in release['assets'] if a['name'] == f'cloudflared-darwin-{arch}.tgz')
        archive = RUNTIME / 'cloudflared.tgz'
        urllib.request.urlretrieve(asset['browser_download_url'],archive)
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        if asset.get('digest') != 'sha256:' + digest: raise RuntimeError('Cloudflared download digest mismatch.')
        binary.parent.mkdir(exist_ok=True)
        with tarfile.open(archive) as contents: contents.extractall(binary.parent,filter='data')
    godot = os.environ.get('GODOT_BIN') or shutil.which('godot')
    if not godot:
        for candidate in [HOST_CACHE / 'Godot.app/Contents/MacOS/Godot',Path('/Applications/Godot.app/Contents/MacOS/Godot'),Path('/tmp/grave-godot/Godot.app/Contents/MacOS/Godot'),Path.home() / 'Library/Caches/GraveMaintenance/Godot.app/Contents/MacOS/Godot']:
            if candidate.exists(): godot = str(candidate); break
    if not godot:
        subprocess.run(['sh','tools/setup_godot.sh'],cwd=ROOT,check=True)
        godot = str(Path.home() / 'Library/Caches/GraveMaintenance/Godot.app/Contents/MacOS/Godot')
    # Run the jobs outside Desktop so macOS background folder access does not stall them.
    # Preserve the complete signed Godot app bundle when relocating it.
    source = Path(godot)
    if source.parent.name == 'MacOS' and source.parent.parent.name == 'Contents':
        cached_app = HOST_CACHE / 'Godot.app'
        if not cached_app.exists(): subprocess.run(['cp','-R',str(source.parent.parent.parent),str(cached_app)],check=True)
        godot = str(cached_app / 'Contents/MacOS/Godot')
    cached_tunnel = HOST_CACHE / 'cloudflared'
    if not cached_tunnel.exists(): shutil.copy2(binary,cached_tunnel)
    pack = HOST_CACHE / 'server.pck'
    if not pack.exists() or pack.read_bytes() != (ROOT / 'build/web/index.pck').read_bytes():
        shutil.copy2(ROOT / 'build/web/index.pck',pack)
        if running(SERVER_JOB):
            subprocess.run(['launchctl','remove',SERVER_JOB],check=True)
            # launchctl removes the job before its old process has released the port.
            # Do not mistake that retiring process for the replacement server.
            for _ in range(40):
                try:
                    with socket.create_connection(('127.0.0.1',9080),timeout=.5): pass
                except OSError: break
                time.sleep(.25)
            else: raise RuntimeError('Previous game server did not release port 9080.')
    try:
        with socket.create_connection(('127.0.0.1',9080),timeout=.5): pass
    except OSError:
        if running(SERVER_JOB): subprocess.run(['launchctl','remove',SERVER_JOB],check=True)
        submit(SERVER_JOB,HOST_CACHE / 'server.log',[godot,'--headless','--main-pack',str(pack),'--','--server'])
    for _ in range(40):
        try:
            with socket.create_connection(('127.0.0.1',9080),timeout=.5): break
        except OSError: time.sleep(.25)
    else: raise RuntimeError(f'Game server failed to start. See {HOST_CACHE / "server.log"}')
    tunnel_log = HOST_CACHE / 'tunnel.log'
    if not running(TUNNEL_JOB):
        tunnel_log.write_text('')
        submit(TUNNEL_JOB,tunnel_log,[str(cached_tunnel),'tunnel','--no-autoupdate','--protocol','http2','--url','http://127.0.0.1:9080'])
    for _ in range(120):
        text = tunnel_log.read_text() if tunnel_log.exists() else ''
        addresses = re.findall(r'https://[a-z0-9-]+\.trycloudflare\.com',text)
        if addresses and 'Registered tunnel connection' in text[text.rfind(addresses[-1]):]: break
        time.sleep(.5)
    else: raise RuntimeError(f'Tunnel failed to connect. See {tunnel_log}')
    endpoint = addresses[-1].replace('https://','wss://',1)
    (RUNTIME / 'public-endpoint.txt').write_text(endpoint + '\n')
    publish(endpoint)
    print('Co-op is live while this Mac stays awake. Stop: python3 tools/host_public.py stop')

if __name__ == '__main__': main()
