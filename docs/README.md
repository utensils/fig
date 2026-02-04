# Fig Documentation Site

This directory contains the documentation site for Fig, built with [Astro Starlight](https://starlight.astro.build/).

## Development

### Prerequisites

- Node.js 22 or later
- npm

### Running Locally

```bash
cd docs
npm install
npm run dev
```

The site will be available at `http://localhost:4321/fig/`.

### Building for Production

```bash
npm run build
```

The static site will be generated in `docs/dist/`.

### Project Structure

```
docs/
├── astro.config.mjs          # Astro + Starlight configuration
├── src/
│   ├── content/docs/          # Documentation pages (MDX)
│   │   ├── index.mdx          # Landing page
│   │   ├── getting-started.mdx
│   │   ├── navigation.mdx
│   │   ├── projects/          # Project management docs
│   │   ├── configuration/     # Configuration editing docs
│   │   └── reference/         # Reference pages
│   ├── pages/                 # Custom Astro pages
│   └── styles/
│       └── custom.css         # Fig brand theme overrides
└── public/                    # Static assets
```
