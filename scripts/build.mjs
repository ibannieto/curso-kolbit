#!/usr/bin/env node
// Construye la presentación estática en ./dist
//  - Copia reveal.js (dist + plugins) y las fuentes desde node_modules
//  - Copia slides/*.md, CSS y assets
//  - Inyecta en index.html una <section> por cada módulo Markdown (orden alfabético)
// Sin dependencias externas: solo Node >= 24.
import { cp, mkdir, readdir, readFile, rm, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { execSync } from 'node:child_process';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
const out = path.resolve(root, process.env.OUT_DIR ?? 'dist');
const nm = path.join(root, 'node_modules');

const FONTS = [
  ['@fontsource/atkinson-hyperlegible-next', ['latin-400-normal', 'latin-400-italic', 'latin-700-normal']],
  ['@fontsource/jetbrains-mono', ['latin-400-normal', 'latin-700-normal']],
];

function gitInfo() {
  try {
    const sha = execSync('git rev-parse --short HEAD', { cwd: root, stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
    return { sha };
  } catch {
    return { sha: process.env.GIT_SHA ?? 'unknown' };
  }
}

async function main() {
  if (!existsSync(path.join(nm, 'reveal.js'))) {
    console.error('✖ Falta node_modules. Ejecuta: npm ci');
    process.exit(1);
  }

  await rm(out, { recursive: true, force: true });
  await mkdir(path.join(out, 'vendor/fonts'), { recursive: true });

  // reveal.js
  const revealDist = path.join(nm, 'reveal.js/dist');
  await cp(revealDist, path.join(out, 'vendor/reveal'), {
    recursive: true,
    filter: (src) => !src.endsWith('.d.ts') && !src.endsWith('.mjs') && !src.includes(`${path.sep}utils`),
  });

  // Fuentes
  for (const [pkg, variants] of FONTS) {
    const name = pkg.split('/')[1];
    for (const v of variants) {
      const file = `${name}-${v}.woff2`;
      await cp(path.join(nm, pkg, 'files', file), path.join(out, 'vendor/fonts', file));
    }
  }

  // Slides, CSS y assets
  const slidesDir = path.join(root, 'slides');
  const modules = (await readdir(slidesDir)).filter((f) => /^\d\d-.+\.md$/.test(f)).sort();
  await mkdir(path.join(out, 'slides'), { recursive: true });
  for (const m of modules) await cp(path.join(slidesDir, m), path.join(out, 'slides', m));
  await cp(path.join(slidesDir, 'css'), path.join(out, 'css'), { recursive: true });
  await cp(path.join(root, 'assets'), path.join(out, 'assets'), {
    recursive: true,
    filter: (src) => !src.endsWith('.md'),
  });

  // index.html con los módulos inyectados
  const sections = modules
    .map(
      (m) =>
        `        <section data-markdown="slides/${m}" data-separator="^\\r?\\n---\\r?\\n$" data-separator-notes="^Note:" data-charset="utf-8"></section>`,
    )
    .join('\n');
  const tpl = await readFile(path.join(slidesDir, 'index.html'), 'utf8');
  await writeFile(path.join(out, 'index.html'), tpl.replace('        <!-- @@MODULES@@ -->', sections));

  // Endpoints auxiliares para Kubernetes / smoke tests
  const { sha } = gitInfo();
  await writeFile(path.join(out, 'healthz'), 'ok\n');
  await writeFile(
    path.join(out, 'version.json'),
    JSON.stringify({ name: 'curso-kolbit', version: process.env.VERSION ?? sha, sha, builtAt: new Date().toISOString() }, null, 2) + '\n',
  );

  console.log(`✔ Presentación generada en ${path.relative(root, out)}/ (${modules.length} módulos)`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
