#!/usr/bin/env node
// Cuenta diapositivas por módulo y estima la duración de la parte expositiva.
// Ayuda a mantener la presentación ajustada a las 37 h del curso.
import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';

const MIN_PER_SLIDE = Number(process.env.MIN_PER_SLIDE ?? 2.5);
const dir = path.resolve(import.meta.dirname, '../slides');
const files = (await readdir(dir)).filter((f) => /^\d\d-.+\.md$/.test(f)).sort();

let total = 0;
let labs = 0;
console.log('Módulo'.padEnd(34), 'Slides', ' Labs', ' Teoría (h)');
for (const f of files) {
  const src = await readFile(path.join(dir, f), 'utf8');
  const slides = src.split(/^\r?\n?---\r?\n/m).length;
  const l = (src.match(/class="lab"/g) ?? []).length;
  total += slides;
  labs += l;
  console.log(f.padEnd(34), String(slides).padStart(6), String(l).padStart(5), ((slides * MIN_PER_SLIDE) / 60).toFixed(1).padStart(11));
}
console.log('-'.repeat(60));
console.log('TOTAL'.padEnd(34), String(total).padStart(6), String(labs).padStart(5), ((total * MIN_PER_SLIDE) / 60).toFixed(1).padStart(11));
console.log(`\n(estimación a ${MIN_PER_SLIDE} min/slide; el resto de las 37 h es práctica guiada en labs/)`);
