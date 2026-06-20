const WP_API = import.meta.env.WORDPRESS_API_URL || 'http://wordpress/wp-json/wp/v2';

export interface WPPost {
  id: number;
  slug: string;
  title: { rendered: string };
  excerpt: { rendered: string };
  content: { rendered: string };
  date: string;
  _embedded?: {
    'wp:featuredmedia'?: Array<{ source_url: string; alt_text: string }>;
  };
}

export interface WPPage {
  id: number;
  slug: string;
  title: { rendered: string };
  content: { rendered: string };
}

export async function getPosts(): Promise<WPPost[]> {
  try {
    const res = await fetch(`${WP_API}/posts?_embed&per_page=12`);
    if (!res.ok) return [];
    return res.json();
  } catch {
    // WordPress unavailable (e.g. first boot, CI). Return empty so builds don't fail.
    return [];
  }
}

export async function getPost(slug: string): Promise<WPPost | null> {
  try {
    const res = await fetch(`${WP_API}/posts?slug=${slug}&_embed`);
    if (!res.ok) return null;
    const posts: WPPost[] = await res.json();
    return posts[0] ?? null;
  } catch {
    return null;
  }
}

export async function getPages(): Promise<WPPage[]> {
  try {
    const res = await fetch(`${WP_API}/pages?per_page=100`);
    if (!res.ok) return [];
    return res.json();
  } catch {
    return [];
  }
}

export async function getPage(slug: string): Promise<WPPage | null> {
  try {
    const res = await fetch(`${WP_API}/pages?slug=${slug}`);
    if (!res.ok) return null;
    const pages: WPPage[] = await res.json();
    return pages[0] ?? null;
  } catch {
    return null;
  }
}
