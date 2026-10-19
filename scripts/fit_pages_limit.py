"""Gzip any web export file that would exceed Cloudflare's 25 MiB asset cap."""

from __future__ import annotations

import gzip
import sys
from pathlib import Path

LIMIT = 25 * 1024 * 1024
TYPES = {
    ".wasm": "application/wasm",
    ".pck": "application/octet-stream",
    ".js": "application/javascript",
    ".html": "text/html; charset=utf-8",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".wasm.br": "application/wasm",
}


def main() -> None:
    root = Path(sys.argv[1])
    rules: list[str] = []
    for path in sorted(root.iterdir()):
        if not path.is_file() or path.name == "_headers":
            continue
        size = path.stat().st_size
        print(f"{path.name}: {size} bytes")
        if size <= LIMIT:
            continue
        compressed = gzip.compress(path.read_bytes(), mtime=0)
        if len(compressed) > LIMIT:
            raise SystemExit(f"{path.name} is {len(compressed)} bytes after gzip, over {LIMIT}")
        path.write_bytes(compressed)
        mime = TYPES.get(path.suffix, "application/octet-stream")
        rules.append(
            f"/{path.name}\n"
            f"  Content-Type: {mime}\n"
            f"  Content-Encoding: gzip\n"
            f"  Cache-Control: public, max-age=0, must-revalidate, no-transform\n"
        )
        print(f"gzipped {path.name} to {len(compressed)} bytes")
    if rules:
        header_text = "\n".join(rules)
        header_text = header_text.replace("/index.wasm", "/engine.wasm")
        (root / "_headers").write_text(header_text, encoding="utf-8")
    html = root / "index.html"
    wasm = root / "index.wasm"
    if not wasm.exists() and (root / "engine.wasm").exists():
        wasm = root / "engine.wasm"
    if wasm.exists() and wasm.read_bytes()[:2] == b"\x1f\x8b":
        wasm.replace(root / "index.wasm.gz")
    pck = root / "engine.pck"
    if pck.exists():
        pck.replace(root / "index.pck")
    gzipped = root / "engine.wasm.gz"
    if gzipped.exists():
        gzipped.replace(root / "index.wasm.gz")
    if html.exists():
        page = html.read_text(encoding="utf-8")
        page = page.replace('"executable":"engine"', '"executable":"index"')
        page = page.replace("engine.pck", "index.pck")
        page = page.replace("engine.wasm", "index.wasm")
        snippet = (
            "<script>window.fetch=function(n){const t=window.fetch.bind(window);"
            "return async function(e,r){const o=typeof e=='string'?e:e&&e.url||'';"
            "if(o.endsWith('.wasm')&&!o.endsWith('.side.wasm')){"
            "const s=await t(o+'.gz',r);if(!s.ok)return s;const a=await s.arrayBuffer();"
            "const i=new Blob([a]).stream().pipeThrough(new DecompressionStream('gzip'));"
            "return new Response(i,{status:200,headers:{'Content-Type':'application/wasm'}})}"
            "return t(e,r)}}();</script>"
        )
        if "DecompressionStream" not in page:
            page = page.replace("</head>", snippet + "</head>", 1)
        html.write_text(page, encoding="utf-8")
    headers = root / "_headers"
    if headers.exists():
        headers.unlink()


if __name__ == "__main__":
    main()
