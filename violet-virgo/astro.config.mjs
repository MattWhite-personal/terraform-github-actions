// @ts-check
import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';
import rehypePrettyCode from "rehype-pretty-code";

// https://astro.build/config
export default defineConfig({
	site: 'https://matthewjwhite.co.uk',
	integrations: [mdx(), sitemap()],
	markdown: {
		//syntaxHighlight: 'prism',
		shikiConfig: {
			wrap: true,
			theme: 'github-dark-dimmed',
		}
		//syntaxHighlight: false,
    	//rehypePlugins: [[rehypePrettyCode, { theme: "github-light" }]],
	},
});
