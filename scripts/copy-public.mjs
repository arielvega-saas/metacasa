// Post-build script: copies static assets from public/ to dist/
// (copyPublicDir is disabled because some public/ files have filesystem issues)
import { copyFileSync, existsSync } from 'fs';
import { join } from 'path';

const publicDir = new URL('../public', import.meta.url).pathname;
const distDir   = new URL('../dist',   import.meta.url).pathname;

const files = [
  'manifest.json',
  'robots.txt',
  'favicon.ico',
  'favicon-32.png',
  'icon-192.png',
  'icon-512.png',
  'apple-touch-icon.png',
  'apple-touch-icon-v2.png',
  'privacy.html',
  'terms.html',
  'assistant-ai.html',
];

for (const file of files) {
  const src = join(publicDir, file);
  const dst = join(distDir,   file);
  if (!existsSync(src)) { console.warn(`⚠ skipped ${file} (not found)`); continue; }
  try {
    copyFileSync(src, dst);
    console.log(`✓ copied ${file}`);
  } catch (e) {
    console.warn(`⚠ skipped ${file} (${e.code})`);
  }
}
