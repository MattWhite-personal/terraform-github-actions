// @ts-check
import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';

// https://astro.build/config
export default defineConfig({
	site: 'https://tfttest.matthewjwhite.co.uk',
	integrations: [mdx(), sitemap()],
	markdown: {
		shikiConfig: {
			wrap: true,
			theme: 'github-dark-dimmed',
		}
	},
});
