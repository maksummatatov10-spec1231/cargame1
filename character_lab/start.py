"""Offline launcher for desktop Python and Pydroid 3. No pip dependencies."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial
from pathlib import Path
import argparse, webbrowser, threading, subprocess

def main():
    p=argparse.ArgumentParser();p.add_argument('--host',default='127.0.0.1');p.add_argument('--port',type=int,default=8765);p.add_argument('--no-browser',action='store_true');a=p.parse_args()
    handler=partial(SimpleHTTPRequestHandler,directory=str(Path(__file__).resolve().parent))
    try:s=ThreadingHTTPServer((a.host,a.port),handler)
    except OSError:s=ThreadingHTTPServer((a.host,0),handler)
    url=f'http://127.0.0.1:{s.server_port}/';print('Откройте на этом устройстве:',url,flush=True)
    print('Не закрывайте Pydroid во время просмотра. Остановка: Stop или Ctrl+C.',flush=True)
    def launch():
        if Path('/system/bin/am').exists():
            try:
                subprocess.run(['/system/bin/am','start','-a','android.intent.action.VIEW','-d',url],timeout=8);return
            except (OSError,subprocess.TimeoutExpired):pass
        webbrowser.open(url)
    if not a.no_browser:threading.Thread(target=launch,daemon=True).start()
    try:s.serve_forever()
    except KeyboardInterrupt:pass
    finally:s.server_close()
if __name__=='__main__':main()
