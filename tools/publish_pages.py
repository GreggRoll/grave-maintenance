#!/usr/bin/env python3
"""Publish an existing browser export and its secure multiplayer address."""
import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
REPO = 'GreggRoll/grave-maintenance'

def run(*args, cwd=ROOT, capture=False):
    return subprocess.run(args, cwd=cwd, check=True, text=True, capture_output=capture)

def publish(server_url):
    address = urlparse(server_url)
    if address.scheme != 'wss' or not address.hostname:
        raise ValueError('The HTTPS game requires a wss:// multiplayer server address.')
    build = ROOT / 'build/web'
    if not (build / 'index.html').exists():
        raise FileNotFoundError('Export the game with tools/export_web.sh first.')
    remote = run('git', 'remote', 'get-url', 'origin', capture=True).stdout.strip()
    with tempfile.TemporaryDirectory(prefix='grave-pages-') as directory:
        stage = Path(directory)
        run('git', 'init', '-b', 'gh-pages', cwd=stage)
        run('git', 'remote', 'add', 'origin', remote, cwd=stage)
        exists = run('git', 'ls-remote', '--heads', 'origin', 'gh-pages', cwd=stage, capture=True).stdout.strip()
        if exists:
            run('git', 'fetch', '--depth=1', 'origin', 'gh-pages', cwd=stage)
            run('git', 'reset', '--hard', 'FETCH_HEAD', cwd=stage)
            run('git', 'rm', '-r', '--ignore-unmatch', '.', cwd=stage)
        for file in build.iterdir():
            if file.is_file() and not file.name.endswith('.import') and not file.name.startswith('.'):
                shutil.copy2(file, stage / file.name)
        (stage / '.nojekyll').touch()
        (stage / 'server.json').write_text(json.dumps({'server_url':server_url}) + '\n')
        run('git', 'add', '.', cwd=stage)
        changed = subprocess.run(['git', 'diff', '--cached', '--quiet'], cwd=stage).returncode
        if changed:
            run('git', 'commit', '-m', 'Publish playable browser build and multiplayer endpoint', cwd=stage)
            run('git', 'push', 'origin', 'gh-pages', cwd=stage)
    pages = subprocess.run(['gh','api',f'repos/{REPO}/pages'],cwd=ROOT,capture_output=True,text=True)
    if pages.returncode:
        run('gh','api','--method','POST',f'repos/{REPO}/pages','-f','source[branch]=gh-pages','-f','source[path]=/')
    print('Play: https://greggroll.github.io/grave-maintenance/', flush=True)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--server-url', required=True)
    publish(parser.parse_args().server_url)
