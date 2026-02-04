// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	site: 'https://utensils.github.io',
	base: '/fig',
	integrations: [
		starlight({
			title: 'Fig',
			social: [
				{ icon: 'github', label: 'GitHub', href: 'https://github.com/utensils/fig' },
			],
			customCss: ['./src/styles/custom.css'],
			sidebar: [
				{
					label: 'Getting Started',
					items: [
						{ label: 'Installation & Setup', slug: 'getting-started' },
					],
				},
				{
					label: 'Projects',
					items: [
						{ label: 'Project Discovery', slug: 'projects/discovery' },
						{ label: 'Project Explorer', slug: 'projects/explorer' },
						{ label: 'Favorites & Recents', slug: 'projects/favorites' },
						{ label: 'Keyboard Shortcuts', slug: 'navigation' },
					],
				},
				{
					label: 'Configuration',
					items: [
						{ label: 'Settings Editor', slug: 'configuration/settings' },
						{ label: 'MCP Server Management', slug: 'configuration/mcp-servers' },
						{ label: 'Visual Hook Composer', slug: 'configuration/hooks' },
						{ label: 'Effective Config Viewer', slug: 'configuration/effective-config' },
						{ label: 'Config Health Checks', slug: 'configuration/health-checks' },
						{ label: 'CLAUDE.md Editor', slug: 'configuration/claude-md' },
					],
				},
				{
					label: 'Reference',
					items: [
						{ label: 'Configuration Files', slug: 'reference/config-files' },
						{ label: 'Safety Features', slug: 'reference/safety' },
					],
				},
			],
		}),
	],
});
