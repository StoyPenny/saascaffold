const WP_API = import.meta.env.WORDPRESS_API_URL || 'http://wordpress/graphql';

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

export async function getPosts(): Promise<WPPost[]> {
  const query = `
    query GetPosts {
      posts(first: 12) {
        nodes {
          databaseId
          slug
          title
          excerpt
          content
          date
          featuredImage {
            node {
              sourceUrl
              altText
            }
          }
        }
      }
    }
  `;

  try {
    const res = await fetch(WP_API, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query }),
    });
    if (!res.ok) return [];
    
    const { data } = await res.json();
    if (!data?.posts?.nodes) return [];

    return data.posts.nodes.map((node: any) => ({
      id: node.databaseId,
      slug: node.slug,
      title: { rendered: node.title || '' },
      excerpt: { rendered: node.excerpt || '' },
      content: { rendered: node.content || '' },
      date: node.date,
      _embedded: node.featuredImage?.node ? {
        'wp:featuredmedia': [{
          source_url: node.featuredImage.node.sourceUrl,
          alt_text: node.featuredImage.node.altText || ''
        }]
      } : undefined
    }));
  } catch {
    // WordPress unavailable (e.g. first boot, CI). Return empty so builds don't fail.
    return [];
  }
}

export async function getPost(slug: string): Promise<WPPost | null> {
  const query = `
    query GetPostBySlug($slug: ID!) {
      post(id: $slug, idType: SLUG) {
        databaseId
        slug
        title
        excerpt
        content
        date
        featuredImage {
          node {
            sourceUrl
            altText
          }
        }
      }
    }
  `;

  try {
    const res = await fetch(WP_API, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        query,
        variables: { slug }
      }),
    });
    if (!res.ok) return null;

    const { data } = await res.json();
    const node = data?.post;
    if (!node) return null;

    return {
      id: node.databaseId,
      slug: node.slug,
      title: { rendered: node.title || '' },
      excerpt: { rendered: node.excerpt || '' },
      content: { rendered: node.content || '' },
      date: node.date,
      _embedded: node.featuredImage?.node ? {
        'wp:featuredmedia': [{
          source_url: node.featuredImage.node.sourceUrl,
          alt_text: node.featuredImage.node.altText || ''
        }]
      } : undefined
    };
  } catch {
    return null;
  }
}
