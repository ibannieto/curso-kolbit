#!/usr/bin/env node
// Servidor estático mínimo para desarrollo local (sin dependencias).
// Reconstruye ./dist cuando cambia algo en slides/ o assets/.
//   node scripts/serve.mjs            → http://localhost:8000
//   PORT=9000 node scripts/serve.mjs
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { watch } from 'node:fs';
import { execFile } from 'node:child_process';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
const dist = path.join(root, 'dist');
const port = Number(process.env.PORT ?? 8000);

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.md': 'text/markdown; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.webp': 'image/webp',
  '.woff2': 'font/woff2',
};

createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost');
    let file = path.normalize(path.join(dist, decodeURIComponent(url.pathname)));
    if (!file.startsWith(dist)) throw new Error('forbidden');
    if ((await stat(file)).isDirectory()) file = path.join(file, 'index.html');
    const body = await readFile(file);
    res.writeHead(200, { 'content-type': TYPES[path.extname(file)] ?? 'application/octet-stream', 'cache-control': 'no-store' });
    res.end(body);
  } catch {
    res.writeHead(404).end('not found');
  }
}).listen(port, () => console.log(`▶ Presentación en http://localhost:${port}  (Ctrl+C para salir)`));

let timer;
const rebuild = () => {
  clearTimeout(timer);
  timer = setTimeout(() => {
    execFile(process.execPath, [path.join(root, 'scripts/build.mjs')], (err, stdout, stderr) => {
      process.stdout.write(err ? stderr : `↻ ${stdout}`);
    });
  }, 200);
};
for (const dir of ['slides', 'assets']) watch(path.join(root, dir), { recursive: true }, rebuild);
