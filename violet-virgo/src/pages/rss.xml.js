import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';
import { SITE_TITLE, SITE_DESCRIPTION } from '../consts';
import { getBlogParams } from "../utils/params";

export async function GET(context) {
    const posts = await getCollection('blog');
    return rss({
        title: SITE_TITLE,
        description: SITE_DESCRIPTION,
        site: context.site,
        items: posts.map((post) => {
            const { path } = getBlogParams(post);
            return {
                ...post.data,
                link: `${path}/`,
            };
        })
    });
}
