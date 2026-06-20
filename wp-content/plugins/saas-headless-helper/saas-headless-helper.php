<?php
/**
 * Plugin Name: SaaSCaffold Headless Helper
 * Description: Basic/essential WordPress optimizations for headless sites. Includes CORS headers, frontend redirects, custom preview routes, SVG support, and performance cleanups.
 * Version: 1.0.0
 * Author: SaaSCaffold
 * License: GPL2
 */

// Exit if accessed directly.
if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

/**
 * Main Plugin Class
 */
class Saas_Headless_Helper {

    public function __construct() {
        // Register settings on admin init
        add_action( 'admin_init', array( $this, 'register_settings' ) );
        add_action( 'admin_menu', array( $this, 'add_settings_page' ) );

        // Redirection logic
        add_action( 'template_redirect', array( $this, 'redirect_to_frontend' ), 99 );

        // CORS headers
        add_action( 'init', array( $this, 'setup_cors_headers' ) );

        // SVG Support
        add_filter( 'upload_mimes', array( $this, 'allow_svg_uploads' ) );
        add_filter( 'wp_handle_upload_prefilter', array( $this, 'check_svg_upload' ) );

        // Custom Preview Links
        add_filter( 'preview_post_link', array( $this, 'customize_preview_link' ), 10, 2 );

        // XML-RPC
        add_filter( 'xmlrpc_enabled', '__return_false' );

        // Clean WP Head / Speed Up
        add_action( 'init', array( $this, 'clean_wp_head' ) );

        // Deploy webhook triggers
        add_action( 'transition_post_status', array( $this, 'trigger_deploy_webhook' ), 10, 3 );
    }

    /**
     * Add settings page in WP Admin -> Settings -> Headless Helper
     */
    public function add_settings_page() {
        add_options_page(
            'Headless Helper Settings',
            'Headless Settings',
            'manage_options',
            'saas-headless-helper',
            array( $this, 'render_settings_page' )
        );
    }

    /**
     * Register plugin settings
     */
    public function register_settings() {
        register_setting( 'saas_headless_settings', 'saas_headless_frontend_url' );
        register_setting( 'saas_headless_settings', 'saas_headless_redirect_frontend' );
        register_setting( 'saas_headless_settings', 'saas_headless_preview_secret' );
        register_setting( 'saas_headless_settings', 'saas_headless_enable_cors' );
        register_setting( 'saas_headless_settings', 'saas_headless_allow_svg' );
        register_setting( 'saas_headless_settings', 'saas_headless_clean_wp_head' );
        register_setting( 'saas_headless_settings', 'saas_headless_deploy_webhook' );
    }

    /**
     * Render the admin settings form
     */
    public function render_settings_page() {
        if ( ! current_user_can( 'manage_options' ) ) {
            return;
        }

        $frontend_url = get_option( 'saas_headless_frontend_url', 'http://localhost:4321' );
        $redirect_frontend = get_option( 'saas_headless_redirect_frontend', '1' );
        $preview_secret = get_option( 'saas_headless_preview_secret', 'saas-preview-secret-key-123' );
        $enable_cors = get_option( 'saas_headless_enable_cors', '1' );
        $allow_svg = get_option( 'saas_headless_allow_svg', '1' );
        $clean_wp_head = get_option( 'saas_headless_clean_wp_head', '1' );
        $deploy_webhook = get_option( 'saas_headless_deploy_webhook', '' );
        ?>
        <div class="wrap">
            <h1>SaaSCaffold Headless Helper</h1>
            <p>Optimize your WordPress CMS for use with a headless frontend like Astro.</p>
            
            <form method="post" action="options.php">
                <?php settings_fields( 'saas_headless_settings' ); ?>
                
                <table class="form-table">
                    <!-- Frontend URL -->
                    <tr valign="top">
                        <th scope="row">Astro Frontend URL</th>
                        <td>
                            <input type="url" name="saas_headless_frontend_url" value="<?php echo esc_url( $frontend_url ); ?>" class="regular-text" placeholder="http://localhost:4321" />
                            <p class="description">Where your headless Astro site is running (e.g. <code>http://localhost:4321</code> for local development, or <code>https://yoursite.com</code> in production).</p>
                        </td>
                    </tr>

                    <!-- Deploy Webhook URL -->
                    <tr valign="top">
                        <th scope="row">Deploy Webhook URL</th>
                        <td>
                            <input type="url" name="saas_headless_deploy_webhook" value="<?php echo esc_url( $deploy_webhook ); ?>" class="regular-text" placeholder="https://api.digitalocean.com/v1/apps/.../deploy" />
                            <p class="description">URL to trigger a rebuild of your Astro site (e.g. your DigitalOcean App Platform, Vercel, or Netlify deploy hook). Fires a non-blocking POST request whenever a post is published, updated, or deleted.</p>
                        </td>
                    </tr>

                    <!-- Redirect Frontend -->
                    <tr valign="top">
                        <th scope="row">Redirect Theme Visitors</th>
                        <td>
                            <label>
                                <input type="checkbox" name="saas_headless_redirect_frontend" value="1" <?php checked( $redirect_frontend, '1' ); ?> />
                                Redirect visitors from WordPress templates to the Astro Frontend
                            </label>
                            <p class="description">When checked, any visitors landing on public WordPress routes (homepage, pages, posts) will be redirected to the corresponding page on your Astro site. Logged-in admin and API routes (GraphQL/REST) are not affected.</p>
                        </td>
                    </tr>

                    <!-- Preview Secret Key -->
                    <tr valign="top">
                        <th scope="row">Preview Secret Key</th>
                        <td>
                            <input type="text" name="saas_headless_preview_secret" value="<?php echo esc_attr( $preview_secret ); ?>" class="regular-text" />
                            <p class="description">Secret token to authenticate draft/preview requests from WordPress inside Astro. Make sure this matches the <code>WORDPRESS_PREVIEW_SECRET</code> env variable in your Astro app.</p>
                        </td>
                    </tr>

                    <!-- Enable CORS -->
                    <tr valign="top">
                        <th scope="row">CORS Headers</th>
                        <td>
                            <label>
                                <input type="checkbox" name="saas_headless_enable_cors" value="1" <?php checked( $enable_cors, '1' ); ?> />
                                Enable Access-Control-Allow-Origin (CORS) header
                            </label>
                            <p class="description">Allows your Astro site to fetch media and API responses from this WordPress site directly in client-side scripts if needed.</p>
                        </td>
                    </tr>

                    <!-- Allow SVG -->
                    <tr valign="top">
                        <th scope="row">Enable SVG Uploads</th>
                        <td>
                            <label>
                                <input type="checkbox" name="saas_headless_allow_svg" value="1" <?php checked( $allow_svg, '1' ); ?> />
                                Allow users to upload SVG files to the Media Library
                            </label>
                            <p class="description">SVG is disabled by default in WordPress. Enabling it allows uploading logos and vector graphics for your headless frontend.</p>
                        </td>
                    </tr>

                    <!-- Clean WP Head -->
                    <tr valign="top">
                        <th scope="row">Clean WordPress Head</th>
                        <td>
                            <label>
                                <input type="checkbox" name="saas_headless_clean_wp_head" value="1" <?php checked( $clean_wp_head, '1' ); ?> />
                                Remove default headers, emojis, generator meta, and assets
                            </label>
                            <p class="description">Reduces query count and removes frontend assets since the WordPress theme is not being rendered.</p>
                        </td>
                    </tr>
                </table>
                
                <?php submit_button(); ?>
            </form>
        </div>
        <?php
    }

    /**
     * Redirect public facing requests to the frontend
     */
    public function redirect_to_frontend() {
        if ( '1' !== get_option( 'saas_headless_redirect_frontend', '1' ) ) {
            return;
        }

        // Do not redirect if admin, REST API, GraphQL, WP login, or custom wp-cron/ajax requests
        if ( is_admin() || 
             is_user_logged_in() || 
             ( defined( 'REST_REQUEST' ) && REST_REQUEST ) ||
             ( defined( 'XMLRPC_REQUEST' ) && XMLRPC_REQUEST ) ||
             strpos( $_SERVER['REQUEST_URI'], '/wp-json' ) !== false ||
             strpos( $_SERVER['REQUEST_URI'], '/graphql' ) !== false ||
             $GLOBALS['pagenow'] === 'wp-login.php' ) {
            return;
        }

        $frontend_url = rtrim( get_option( 'saas_headless_frontend_url', 'http://localhost:4321' ), '/' );
        $path = $_SERVER['REQUEST_URI'];

        // Build redirect target
        $target_url = $frontend_url . $path;

        wp_redirect( $target_url, 301 );
        exit;
    }

    /**
     * Send CORS headers for REST API and GraphQL requests
     */
    public function setup_cors_headers() {
        if ( '1' !== get_option( 'saas_headless_enable_cors', '1' ) ) {
            return;
        }

        // Enable CORS for API endpoints
        $is_rest = ( defined( 'REST_REQUEST' ) && REST_REQUEST ) || strpos( $_SERVER['REQUEST_URI'], '/wp-json' ) !== false;
        $is_graphql = strpos( $_SERVER['REQUEST_URI'], '/graphql' ) !== false;

        if ( $is_rest || $is_graphql ) {
            header( 'Access-Control-Allow-Origin: *' );
            header( 'Access-Control-Allow-Methods: GET, POST, OPTIONS' );
            header( 'Access-Control-Allow-Credentials: true' );
            header( 'Access-Control-Allow-Headers: Authorization, X-WP-Nonce, Content-Type, X-Requested-With' );
            
            // Handle OPTIONS requests gracefully
            if ( 'OPTIONS' === $_SERVER['REQUEST_METHOD'] ) {
                status_header( 200 );
                exit;
            }
        }
    }

    /**
     * Customize WP preview link to target Astro frontend endpoint
     */
    public function customize_preview_link( $link, $post ) {
        $frontend_url = rtrim( get_option( 'saas_headless_frontend_url', 'http://localhost:4321' ), '/' );
        $preview_secret = get_option( 'saas_headless_preview_secret', 'saas-preview-secret-key-123' );

        // If previewing draft or autosave
        $query_args = array(
            'secret' => $preview_secret,
            'id'     => $post->ID,
            'type'   => $post->post_type,
            'status' => $post->post_status,
        );

        // Point to Astro's API preview route
        return add_query_arg( $query_args, $frontend_url . '/api/preview' );
    }

    /**
     * Allow SVG file uploads
     */
    public function allow_svg_uploads( $mimes ) {
        if ( '1' === get_option( 'saas_headless_allow_svg', '1' ) ) {
            $mimes['svg']  = 'image/svg+xml';
            $mimes['svgz'] = 'image/svg+xml';
        }
        return $mimes;
    }

    /**
     * Basic sanitization/verification check for SVG uploads (security)
     */
    public function check_svg_upload( $file ) {
        if ( '1' !== get_option( 'saas_headless_allow_svg', '1' ) ) {
            return $file;
        }

        $ext = pathinfo( $file['name'], PATHINFO_EXTENSION );
        if ( 'svg' === $ext || 'svgz' === $ext ) {
            // Check if file is valid XML and does not contain script tags
            $real_path = $file['tmp_name'];
            if ( file_exists( $real_path ) ) {
                $contents = file_get_contents( $real_path );
                if ( strpos( $contents, '<script' ) !== false || strpos( $contents, 'javascript:' ) !== false ) {
                    $file['error'] = 'Security check: SVGs containing scripts are not allowed for upload.';
                }
            }
        }
        return $file;
    }

    /**
     * Clean default headers, assets, and emoji resources from head
     */
    public function clean_wp_head() {
        if ( '1' !== get_option( 'saas_headless_clean_wp_head', '1' ) ) {
            return;
        }

        // Remove emoji support scripts/styles
        remove_action( 'wp_head', 'print_emoji_detection_script', 7 );
        remove_action( 'admin_print_scripts', 'print_emoji_detection_script' );
        remove_action( 'wp_print_styles', 'print_emoji_styles' );
        remove_action( 'admin_print_styles', 'print_emoji_styles' );
        remove_filter( 'the_content_feed', 'wp_staticize_emoji' );
        remove_filter( 'comment_text_rss', 'wp_staticize_emoji' );
        remove_filter( 'wp_mail', 'wp_staticize_emoji_for_email' );

        // Remove typical feed, RSD, WLW, and generator links
        remove_action( 'wp_head', 'rsd_link' );
        remove_action( 'wp_head', 'wlwmanifest_link' );
        remove_action( 'wp_head', 'wp_generator' );
        remove_action( 'wp_head', 'wp_shortlink_wp_head' );
        remove_action( 'wp_head', 'rest_output_link_wp_head', 10 );
        remove_action( 'wp_head', 'wp_oembed_add_discovery_links', 10 );
    }

    /**
     * Trigger deploy webhook on post transition to/from publish
     */
    public function trigger_deploy_webhook( $new_status, $old_status, $post ) {
        if ( 'publish' === $new_status || 'publish' === $old_status ) {
            // Avoid loops during autosaves/revisions
            if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) {
                return;
            }

            $webhook_url = get_option( 'saas_headless_deploy_webhook', '' );
            if ( ! empty( $webhook_url ) ) {
                wp_remote_post(
                    esc_url_raw( $webhook_url ),
                    array(
                        'blocking' => false, // Async, non-blocking
                        'timeout'  => 5,
                        'body'     => array(
                            'event'   => 'content_update',
                            'post_id' => $post->ID,
                            'status'  => $new_status,
                        ),
                    )
                );
            }
        }
    }
}

// Instantiate.
new Saas_Headless_Helper();
