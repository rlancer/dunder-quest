// Gzip any web export file that would exceed Cloudflare's 25 MiB asset cap.
//
//     bun scripts/fit_pages_limit.ts build/site/play

import { existsSync, readdirSync, readFileSync, renameSync, statSync, unlinkSync, writeFileSync } from "node:fs";
import { extname, join } from "node:path";
import { gzipSync } from "node:zlib";

const LIMIT = 25 * 1024 * 1024;
const TYPES: Record<string, string> = {
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".js": "application/javascript",
  ".html": "text/html; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".wasm.br": "application/wasm",
};

function main(): void {
  const root = process.argv[2];
  const rules: string[] = [];
  for (const name of readdirSync(root).sort()) {
    const path = join(root, name);
    if (!statSync(path).isFile() || name === "_headers") continue;
    const size = statSync(path).size;
    console.log(`${name}: ${size} bytes`);
    if (size <= LIMIT) continue;
    const compressed = gzipSync(readFileSync(path), { level: 9 });
    if (compressed.length > LIMIT) {
      console.error(`${name} is ${compressed.length} bytes after gzip, over ${LIMIT}`);
      process.exit(1);
    }
    writeFileSync(path, compressed);
    const mime = TYPES[extname(name)] ?? "application/octet-stream";
    rules.push(
      `/${name}\n`
      + `  Content-Type: ${mime}\n`
      + "  Content-Encoding: gzip\n"
      + "  Cache-Control: public, max-age=0, must-revalidate, no-transform\n",
    );
    console.log(`gzipped ${name} to ${compressed.length} bytes`);
  }
  if (rules.length) {
    writeFileSync(join(root, "_headers"), rules.join("\n").split("/index.wasm").join("/engine.wasm"), "utf-8");
  }
  const html = join(root, "index.html");
  let wasm = join(root, "index.wasm");
  if (!existsSync(wasm) && existsSync(join(root, "engine.wasm"))) wasm = join(root, "engine.wasm");
  if (existsSync(wasm) && readFileSync(wasm).subarray(0, 2).equals(Buffer.from([0x1f, 0x8b]))) {
    renameSync(wasm, join(root, "index.wasm.gz"));
  }
  const pck = join(root, "engine.pck");
  if (existsSync(pck)) renameSync(pck, join(root, "index.pck"));
  const gzipped = join(root, "engine.wasm.gz");
  if (existsSync(gzipped)) renameSync(gzipped, join(root, "index.wasm.gz"));
  if (existsSync(html)) {
    let page = readFileSync(html, "utf-8");
    page = page.split('"executable":"engine"').join('"executable":"index"');
    page = page.split("engine.pck").join("index.pck");
    page = page.split("engine.wasm").join("index.wasm");
    const snippet = "<script>window.fetch=function(n){const t=window.fetch.bind(window);"
      + "return async function(e,r){const o=typeof e=='string'?e:e&&e.url||'';"
      + "if(o.endsWith('.wasm')&&!o.endsWith('.side.wasm')){"
      + "const s=await t(o+'.gz',r);if(!s.ok)return s;const a=await s.arrayBuffer();"
      + "const i=new Blob([a]).stream().pipeThrough(new DecompressionStream('gzip'));"
      + "return new Response(i,{status:200,headers:{'Content-Type':'application/wasm'}})}"
      + "return t(e,r)}}();</script>";
    if (!page.includes("DecompressionStream")) page = page.replace("</head>", () => snippet + "</head>");
    writeFileSync(html, page, "utf-8");
  }
  const headers = join(root, "_headers");
  if (existsSync(headers)) unlinkSync(headers);
}

main();
