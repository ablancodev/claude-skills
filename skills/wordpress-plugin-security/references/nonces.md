# Nonces — every flavor

A nonce proves the request was initiated by the user on your site, not forged from elsewhere. Required for every state-changing action.

## Lifetime

WordPress nonces live ~24 hours (two `nonce_life` "ticks" of 12h). They are not single-use — a nonce verifies "this request came from a recent page rendered for this user for this action".

## Generation + verification matrix

### Admin form (POST to `admin-post.php` or a settings page)

```php
// Form
wp_nonce_field( 'my_action_name' );

// Handler
check_admin_referer( 'my_action_name' );
// Dies with 403 on failure. Includes the referer check.
```

### Admin GET link with action

```php
$url = wp_nonce_url(
    admin_url( 'admin.php?page=my-plugin&action=delete&id=42' ),
    'my_delete_42'
);

// Handler
check_admin_referer( 'my_delete_42' );
```

### AJAX (logged-in)

```php
// Localize
wp_localize_script( 'my-script', 'MyPlugin', array(
    'ajaxUrl' => admin_url( 'admin-ajax.php' ),
    'nonce'   => wp_create_nonce( 'my_ajax_action' ),
) );

// JS
fetch( MyPlugin.ajaxUrl, {
    method: 'POST',
    body: new URLSearchParams({
        action: 'my_plugin_thing',
        _ajax_nonce: MyPlugin.nonce,
        // ...
    }),
});

// Handler
check_ajax_referer( 'my_ajax_action' ); // dies on failure
// or
if ( ! check_ajax_referer( 'my_ajax_action', '_ajax_nonce', false ) ) {
    wp_send_json_error( array( 'message' => 'bad nonce' ), 403 );
}
```

### REST API

Cookie-authenticated REST requests automatically get the `X-WP-Nonce` header from `wpApiSettings.nonce` (or `wp.apiFetch`). On the server, you do **not** call `check_ajax_referer` — REST infrastructure handles it. You only need:

```php
'permission_callback' => function () { return current_user_can( 'edit_posts' ); }
```

If you call the REST API from outside the WP cookie session (e.g. machine-to-machine), use Application Passwords or OAuth — not the cookie nonce.

### Manual verification

```php
if ( ! isset( $_REQUEST['_wpnonce'] )
     || ! wp_verify_nonce( $_REQUEST['_wpnonce'], 'my_action' ) ) {
    wp_die( 'Invalid nonce', 403 );
}
```

`wp_verify_nonce` returns:
- `1` — valid, generated 0–12h ago
- `2` — valid, generated 12–24h ago
- `false` — invalid

Treat `2` as valid but consider re-issuing the form.

## Common mistakes

- **Nonce without capability check.** A nonce stops CSRF but not privilege escalation. Always pair with `current_user_can`.
- **Capability without nonce.** The admin user can be tricked into clicking a link or submitting a form. CSRF will succeed.
- **Reusing the same nonce action everywhere.** Use an action name specific to the operation (`my_plugin_delete_post_42`, not `my_plugin_nonce`). It scopes the nonce.
- **Putting the nonce in the URL on a destructive action.** Nonces in URLs leak via `Referer` and browser history. Prefer POST + nonce in the body for destructive actions.
- **Checking the nonce after starting work.** Always verify before any side effect — including read queries that depend on user input.
- **Forgetting `wp_unslash()` on `$_REQUEST['_wpnonce']`** — usually fine because nonces are alphanumeric, but use it for consistency.

## Logged-out forms

Nonces tied to user `0` are weaker (predictable across sessions of the same anonymous user). For genuinely public forms (login, password reset, public comment), WordPress core uses its own mechanisms. If you need a public form with anti-CSRF, combine a nonce with a session-bound token (cookie or transient) and a `Referer` check.
