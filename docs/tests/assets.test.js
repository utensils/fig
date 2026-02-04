import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const docsRoot = resolve(__dirname, '..');

describe('docs assets', () => {
  describe('favicon', () => {
    it('favicon.png exists in public/', () => {
      assert.ok(
        existsSync(resolve(docsRoot, 'public/favicon.png')),
        'public/favicon.png should exist'
      );
    });

    it('favicon.png is a valid PNG file', () => {
      const buf = readFileSync(resolve(docsRoot, 'public/favicon.png'));
      const pngMagic = Buffer.from([0x89, 0x50, 0x4e, 0x47]);
      assert.ok(
        buf.subarray(0, 4).equals(pngMagic),
        'favicon.png should have a valid PNG header'
      );
    });

    it('apple-touch-icon.png exists in public/', () => {
      assert.ok(
        existsSync(resolve(docsRoot, 'public/apple-touch-icon.png')),
        'public/apple-touch-icon.png should exist'
      );
    });

    it('old favicon.svg does not exist', () => {
      assert.ok(
        !existsSync(resolve(docsRoot, 'public/favicon.svg')),
        'public/favicon.svg should be removed'
      );
    });
  });

  describe('logo', () => {
    it('fig-logo.png exists in public/', () => {
      assert.ok(
        existsSync(resolve(docsRoot, 'public/fig-logo.png')),
        'public/fig-logo.png should exist'
      );
    });

    it('fig-logo.png exists in src/assets/', () => {
      assert.ok(
        existsSync(resolve(docsRoot, 'src/assets/fig-logo.png')),
        'src/assets/fig-logo.png should exist'
      );
    });

    it('logo files are valid PNGs', () => {
      const pngMagic = Buffer.from([0x89, 0x50, 0x4e, 0x47]);

      const publicLogo = readFileSync(resolve(docsRoot, 'public/fig-logo.png'));
      assert.ok(
        publicLogo.subarray(0, 4).equals(pngMagic),
        'public/fig-logo.png should be a valid PNG'
      );

      const srcLogo = readFileSync(resolve(docsRoot, 'src/assets/fig-logo.png'));
      assert.ok(
        srcLogo.subarray(0, 4).equals(pngMagic),
        'src/assets/fig-logo.png should be a valid PNG'
      );
    });
  });

  describe('astro config', () => {
    it('references favicon.png in starlight config', () => {
      const config = readFileSync(resolve(docsRoot, 'astro.config.mjs'), 'utf-8');
      assert.ok(
        config.includes("favicon: '/favicon.png'"),
        'astro.config.mjs should set favicon to /favicon.png'
      );
    });

    it('references fig-logo.png as the starlight logo', () => {
      const config = readFileSync(resolve(docsRoot, 'astro.config.mjs'), 'utf-8');
      assert.ok(
        config.includes("src: './src/assets/fig-logo.png'"),
        'astro.config.mjs should reference fig-logo.png as the logo source'
      );
    });
  });

  describe('landing page', () => {
    it('references favicon.png in the head', () => {
      const html = readFileSync(resolve(docsRoot, 'src/pages/index.astro'), 'utf-8');
      assert.ok(
        html.includes('href="/fig/favicon.png"'),
        'index.astro should reference /fig/favicon.png'
      );
    });

    it('references apple-touch-icon.png in the head', () => {
      const html = readFileSync(resolve(docsRoot, 'src/pages/index.astro'), 'utf-8');
      assert.ok(
        html.includes('href="/fig/apple-touch-icon.png"'),
        'index.astro should reference /fig/apple-touch-icon.png'
      );
    });

    it('does not reference old favicon.svg', () => {
      const html = readFileSync(resolve(docsRoot, 'src/pages/index.astro'), 'utf-8');
      assert.ok(
        !html.includes('favicon.svg'),
        'index.astro should not reference the old favicon.svg'
      );
    });

    it('references fig-logo.png for the nav and hero images', () => {
      const html = readFileSync(resolve(docsRoot, 'src/pages/index.astro'), 'utf-8');
      const logoRefs = html.match(/fig-logo\.png/g);
      assert.ok(
        logoRefs && logoRefs.length >= 2,
        'index.astro should reference fig-logo.png at least twice (nav + hero)'
      );
    });
  });
});
