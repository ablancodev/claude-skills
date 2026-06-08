---
name: wordpress-plugin-security
description: Use when writing or reviewing PHP code for a WordPress plugin or theme — every form handler, AJAX callback, REST endpoint, shortcode, block render, ability execute_callback, or anything that reads `$_GET`/`$_POST`/`$_REQUEST`, writes to the database, or echoes data. Encodes the WordPress core security model: capability checks (`current_user_can`), nonces (`wp_create_nonce` / `check_admin_referer` / `wp_verify_nonce` / `check_ajax_referer`), sanitization on input (`sanitize_text_field`, `sanitize_email`, `sanitize_key`, `wp_kses`, etc.), escaping on output (`esc_html`, `esc_attr`, `esc_url`, `esc_js`, `wp_kses_post`), SQL preparation (`$wpdb->prepare`), file handling (`wp_handle_upload`, `validate_file`), REST `permission_callback`, secrets/`.env` handling, and the canonical "capability → nonce → sanitize → work → escape" pattern. Trigger when the user mentions: nonces, sanitization, escaping, capability checks, CSRF, XSS, SQL injection, WordPress security review, hardening a plugin, or any user-input handling in WP.
---

# WordPress plugin & theme security

The WordPress core security model is small and uncompromising. Every request that mutates state or echoes user-controlled data must pass through this pattern:

```
1. capability check    — is this user allowed?
2. nonce check         — did the request really come from our form?
3. sanitize input      — clean before storing/using
4. perform the action  — query, save, side effect
5. escape on output    — escape at the point of rendering, in the right context
```

Skip any of the five and you have a vulnerability. The skill below is the codification of that pattern and its idioms.

## When to use this skill

Load this skill **proactively** whenever you are writing or reviewing:

- Anything that reads from `$_GET`, `$_POST`, `$_REQUEST`, `$_FILES`, `$_COOKIE`, `$_SERVER`.
- A REST endpoint, AJAX handler, admin form, settings page.
- A Gutenberg block `render_callback` / `render.php`.
- An Abilities API `execute_callback`.
- A shortcode that takes attributes.
- A SQL query (`$wpdb->query`, `$wpdb->get_results`, etc.).
- A file upload handler.
- Code that calls an external API with a secret key.

Load **before** writing the code, not after.

## Hard rules

1. **Capability check first.** Never trust that an authenticated user is authorized. Use `current_user_can( 'specific_capability' )` — not `is_admin()` (which only tells you the page is an admin screen, not the user's role).
2. **Nonce on every state-changing request.** Forms: `wp_nonce_field()` + `check_admin_referer()`. AJAX: `wp_create_nonce()` + `check_ajax_referer()`. REST: rely on cookie auth + `permission_callback` (REST nonces are handled by core).
3. **Sanitize at the boundary.** The moment data enters PHP, sanitize it with the function that matches the type. Treat every superglobal as hostile.
4. **Escape at the moment of output, in the context of the output.** HTML body → `esc_html`. Attribute → `esc_attr`. URL → `esc_url` (or `esc_url_raw` for storage). Inline JS → `esc_js` or, better, `wp_json_encode`. Rich HTML → `wp_kses_post` (or a stricter `wp_kses` with your allowlist).
5. **Never trust sanitization to handle output.** Sanitize for storage, escape for display. They are different operations with different functions.
6. **`$wpdb->prepare()` for every dynamic SQL value.** Use `%s`, `%d`, `%f`, `%i` (identifiers, WP 6.2+). Never string-concatenate values into a query.
7. **REST endpoints require `permission_callback`.** Never return `'permission_callback' => '__return_true'` for write endpoints. Public read endpoints must still consider rate limiting / abuse.
8. **Files: never trust `$_FILES`.** Use `wp_handle_upload()` with a MIME allowlist, validate extensions with `wp_check_filetype_and_ext()`, and store via `wp_upload_dir()`.
9. **Secrets do not live in code.** API keys in `wp-config.php` constants or in the Connectors/options API with `autoload=false`. Never commit secrets. Never echo them. Mask them in admin UI.
10. **Output errors generically; log details internally.** A user-facing error must not reveal stack traces, SQL, file paths, or which user exists. Use `error_log()` or a logging plugin for details.
11. **The same data → multiple escapers.** A URL inside an HTML attribute: `esc_url`. The visible label next to it: `esc_html`. The script that opens it: `esc_js`/`wp_json_encode`. Same data, three different output contexts.
12. **Capability + nonce together — never one without the other.** A capability check without a nonce = the right user can be CSRF'd into a destructive action. A nonce without a capability check = any logged-in user can forge a valid request for an action that should be admin-only.

## The canonical handler

```php
add_action( 'admin_post_my_plugin_save_settings', 'my_plugin_save_settings' );

function my_plugin_save_settings() {
    // 1. Capability
    if ( ! current_user_can( 'manage_options' ) ) {
        wp_die( esc_html__( 'You do not have permission to do this.', 'my-plugin' ), 403 );
    }

    // 2. Nonce
    check_admin_referer( 'my_plugin_save_settings_nonce' );

    // 3. Sanitize input
    $api_key  = isset( $_POST['api_key'] )  ? sanitize_text_field( wp_unslash( $_POST['api_key'] ) )  : '';
    $endpoint = isset( $_POST['endpoint'] ) ? esc_url_raw( wp_unslash( $_POST['endpoint'] ) )         : '';
    $emails   = isset( $_POST['emails'] )   ? array_filter( array_map( 'sanitize_email',
                    array_map( 'wp_unslash', (array) $_POST['emails'] ) ) ) : array();

    // 4. Do the work
    update_option( 'my_plugin_api_key',  $api_key, false );
    update_option( 'my_plugin_endpoint', $endpoint, false );
    update_option( 'my_plugin_emails',   $emails, false );

    // 5. Redirect (output escaping happens on the next page render)
    wp_safe_redirect( add_query_arg( 'updated', '1', wp_get_referer() ) );
    exit;
}
```

The matching form:

```php
<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
    <input type="hidden" name="action" value="my_plugin_save_settings">
    <?php wp_nonce_field( 'my_plugin_save_settings_nonce' ); ?>

    <input type="text" name="api_key"
           value="<?php echo esc_attr( get_option( 'my_plugin_api_key', '' ) ); ?>">

    <input type="url" name="endpoint"
           value="<?php echo esc_url( get_option( 'my_plugin_endpoint', '' ) ); ?>">

    <?php submit_button(); ?>
</form>
```

## REST endpoint pattern

```php
add_action( 'rest_api_init', function () {
    register_rest_route( 'my-plugin/v1', '/notes', array(
        'methods'             => 'POST',
        'callback'            => 'my_plugin_create_note',
        'permission_callback' => function () {
            return current_user_can( 'edit_posts' );
        },
        'args' => array(
            'title' => array(
                'type'              => 'string',
                'required'          => true,
                'sanitize_callback' => 'sanitize_text_field',
                'validate_callback' => function ( $v ) { return is_string( $v ) && strlen( $v ) <= 255; },
            ),
            'body' => array(
                'type'              => 'string',
                'sanitize_callback' => 'wp_kses_post',
            ),
        ),
    ) );
} );

function my_plugin_create_note( WP_REST_Request $request ) {
    $title = $request->get_param( 'title' );
    $body  = $request->get_param( 'body' );

    $id = wp_insert_post( array(
        'post_type'    => 'mp_note',
        'post_status'  => 'publish',
        'post_title'   => $title,
        'post_content' => $body,
    ), true );

    if ( is_wp_error( $id ) ) {
        return $id;
    }
    return rest_ensure_response( array( 'id' => $id ) );
}
```

The framework runs `sanitize_callback` before your handler — you can rely on the values being clean once inside the handler.

## AJAX pattern

```php
add_action( 'wp_ajax_my_plugin_action', 'my_plugin_ajax' );

function my_plugin_ajax() {
    if ( ! current_user_can( 'edit_posts' ) ) {
        wp_send_json_error( array( 'message' => 'forbidden' ), 403 );
    }
    check_ajax_referer( 'my_plugin_ajax_nonce', '_ajax_nonce' );

    $term = isset( $_POST['term'] ) ? sanitize_text_field( wp_unslash( $_POST['term'] ) ) : '';

    // ... do work ...

    wp_send_json_success( array( 'results' => $results ) );
}
```

Pass the nonce to JS via `wp_localize_script` or `wp_add_inline_script` with `wp_create_nonce( 'my_plugin_ajax_nonce' )`.

## SQL: never concatenate

**Bad:**

```php
$wpdb->query( "SELECT * FROM {$wpdb->posts} WHERE post_author = $user_id" ); // SQLi
```

**Good:**

```php
$wpdb->get_results( $wpdb->prepare(
    "SELECT * FROM {$wpdb->posts} WHERE post_author = %d AND post_status = %s",
    $user_id, 'publish'
) );
```

For identifiers (table/column names) where prepare doesn't apply directly, use `%i` (WP 6.2+):

```php
$wpdb->prepare( "SELECT %i FROM {$wpdb->posts} WHERE ID = %d", $column, $id );
```

If you cannot use `%i`, validate the identifier against an allowlist before interpolation.

## Sanitize → Escape map

| Input type | Sanitize on entry | Escape on output |
|---|---|---|
| Plain text | `sanitize_text_field` | `esc_html` |
| Text with line breaks | `sanitize_textarea_field` | `esc_textarea` (in `<textarea>`) / `esc_html` + `nl2br` |
| Email | `sanitize_email` | `esc_attr` (in `href="mailto:"`) |
| URL (display) | `esc_url_raw` | `esc_url` |
| Slug / key | `sanitize_key` / `sanitize_title` | `esc_attr` |
| Integer | `(int)` or `absint` | `esc_html` (rarely needed) |
| HTML (limited, like post content) | `wp_kses_post` | `wp_kses_post` (idempotent) |
| HTML (custom allowlist) | `wp_kses( $html, $allowed )` | same |
| File name | `sanitize_file_name` | `esc_attr` |
| Hex color | `sanitize_hex_color` | `esc_attr` |
| Filename for download | `sanitize_file_name` | `esc_attr` |
| JSON to inline JS | (n/a) | `wp_json_encode` |

Always `wp_unslash()` superglobals before sanitizing — WordPress slashes them on entry.

## Files

```php
require_once ABSPATH . 'wp-admin/includes/file.php';
require_once ABSPATH . 'wp-admin/includes/image.php';

$overrides = array(
    'test_form' => false,
    'mimes'     => array(
        'jpg|jpeg' => 'image/jpeg',
        'png'      => 'image/png',
        'webp'     => 'image/webp',
    ),
);

$uploaded = wp_handle_upload( $_FILES['my_file'], $overrides );

if ( isset( $uploaded['error'] ) ) {
    wp_die( esc_html( $uploaded['error'] ) );
}
```

`wp_handle_upload` runs `wp_check_filetype_and_ext` internally with your `mimes` allowlist, moves the file into the uploads dir, and returns sanitized path/URL.

## Secrets

```php
// wp-config.php (not committed, or stored in env)
define( 'MY_PLUGIN_API_KEY', getenv( 'MY_PLUGIN_API_KEY' ) ?: '' );

// Plugin code
$key = defined( 'MY_PLUGIN_API_KEY' ) ? MY_PLUGIN_API_KEY : get_option( 'my_plugin_api_key', '' );
```

For WP 7.0 AI: do **not** roll your own — the Connectors API stores provider credentials.

## Error handling

```php
try {
    // ...
} catch ( Throwable $e ) {
    error_log( '[my-plugin] ' . $e->getMessage() . "\n" . $e->getTraceAsString() );
    return new WP_Error( 'my_plugin_error', __( 'Something went wrong. Please try again.', 'my-plugin' ) );
}
```

Never echo `$e->getMessage()` directly to a user — it can leak file paths, SQL fragments, or sensitive data.

## Quick audit checklist (paste-able)

For every handler in a PR review, verify each box:

- [ ] Capability check with a specific capability (not `is_admin`).
- [ ] Nonce verified with `check_admin_referer` / `check_ajax_referer`, or REST `permission_callback`.
- [ ] All `$_GET`/`$_POST`/`$_REQUEST` access goes through `wp_unslash()` + a sanitizer.
- [ ] No string concatenation in SQL — `$wpdb->prepare` everywhere.
- [ ] Every echo / interpolation uses the right `esc_*` for its context.
- [ ] No secrets in code; sensitive options stored with `autoload=false`.
- [ ] No PII / stack traces in user-facing errors.
- [ ] File uploads use `wp_handle_upload` with a MIME allowlist.
- [ ] Translatable strings use `__()` / `esc_html__()` with a textdomain.
- [ ] `register_rest_route` has a real `permission_callback`.
- [ ] `current_user_can()` uses a built-in capability or one registered via `add_cap()`.

## See also (load on demand)

- `references/escaping-contexts.md` — every output context with the right escaping function
- `references/nonces.md` — admin, AJAX, REST, URLs, lifetime, common mistakes
- `references/sql.md` — `$wpdb->prepare`, `%i`, `IN()`, dynamic ORDER BY safely
- `references/rest-api.md` — REST argument schemas, sanitize_callback vs validate_callback, auth modes

## Companion skills

- **wordpress-7-ai-abilities** — security is non-negotiable for AI endpoints; load both together.
- **wordpress-gutenberg-php-blocks** — block render output must escape, even when the data came from "trusted" sources.
