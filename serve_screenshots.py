#!/usr/bin/env python3
"""Galerie HTML pour visualiser les screenshots E2E dans un navigateur."""

import http.server
import os
import sys
import urllib.parse

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8899

STYLE = """
body { background: #1a1a2e; color: #eee; font-family: system-ui, sans-serif; margin: 0; padding: 16px; }
h1 { color: #6cf; font-size: 1.4em; border-bottom: 1px solid #333; padding-bottom: 8px; }
.nav { display: flex; flex-wrap: wrap; gap: 6px; margin: 12px 0; }
.nav a { color: #6cf; text-decoration: none; padding: 10px 16px; background: #252545;
         border-radius: 6px; font-size: 0.95em; }
.nav a:hover { background: #353565; }
.card { background: #252545; border-radius: 8px; margin: 14px 0; overflow: hidden; }
.card h3 { margin: 0; padding: 10px 14px; background: #1e1e3a; color: #8bf; font-size: 0.95em; }
.card img { width: 100%; display: block; }
.back { color: #999; text-decoration: none; font-size: 0.9em; display: inline-block; margin-bottom: 8px; }
.back:hover { color: #6cf; }
"""


def label_from_filename(name):
    """Transforme '01_01_settings_ouvert.png' en 'settings ouvert'."""
    name = name.replace(".png", "").replace("_", " ")
    parts = name.split(" ", 2)
    if len(parts) >= 3 and parts[0].isdigit() and parts[1].isdigit():
        return parts[2]
    if len(parts) >= 2 and parts[0].isdigit():
        return " ".join(parts[1:])
    return name


def build_page(target):
    """Genere le HTML pour un dossier."""
    entries = sorted(os.listdir(target))
    subdirs = [e for e in entries if os.path.isdir(os.path.join(target, e))]
    images = [e for e in entries if e.lower().endswith(".png")]
    title = target if target != "." else "Screenshots E2E"

    html = f"""<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>{STYLE}</style>
</head><body>
<h1>{title}</h1>
"""
    if target != ".":
        html += '<a class="back" href="/">&larr; Retour</a>\n'

    if subdirs:
        html += '<div class="nav">\n'
        for d in subdirs:
            link = f"{target}/{d}" if target != "." else d
            label = d.replace("_", " ")
            html += f'  <a href="/{link}">{label}</a>\n'
        html += "</div>\n"

    for img in images:
        img_path = f"{target}/{img}" if target != "." else img
        label = label_from_filename(img)
        html += f'<div class="card"><h3>{label}</h3>'
        html += f'<img src="/{img_path}" loading="lazy"></div>\n'

    html += "</body></html>"
    return html


class GalleryHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        path = urllib.parse.unquote(self.path).strip("/")

        # Servir une image PNG
        if path.lower().endswith(".png"):
            if os.path.isfile(path):
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.end_headers()
                with open(path, "rb") as f:
                    self.wfile.write(f.read())
            else:
                self.send_error(404)
            return

        # Galerie HTML
        target = path if path else "."
        if os.path.isdir(target):
            content = build_page(target).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
        else:
            self.send_error(404)

    def log_message(self, fmt, *args):
        pass  # Silencieux


if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", PORT), GalleryHandler)
    print(f"Galerie demarree sur le port {PORT}")
    server.serve_forever()
