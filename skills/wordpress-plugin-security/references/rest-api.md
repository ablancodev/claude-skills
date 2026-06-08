# Securing REST API endpoints

## The mandatory shape

```php
register_rest_route( 'my-plugin/v1', '/things/(?P<id>\d+)', array(
    'methods'             => 'GET',
    'callback'            => 'my_plugin_get_thing',
    'permission_callback' => 'my_plugin_can_read_thing',
    'args' => array(
        'id' => array(
            'required'          => true,
            'type'              => 'integer',
            'sanitize_callback' => 'absint',
            'validate_callback' => function ( $v ) { return $v > 0; },
        ),
    ),
) );
```

## `permission_callback` is not optional

WordPress will warn in `WP_DEBUG` mode if `permission_callback` is missing. **Never** ship `'permission_callback' => '__return_true'` for any write endpoint, and only use it for genuinely public reads.

For write endpoints, the absolute minimum is a capability:

```php
'permission_callback' => function () { return current_user_can( 'edit_posts' ); }
```

For per-object permissions, inspect the request:

```php
'permission_callback' => function ( WP_REST_Request $request ) {
    $id = (int) $request['id'];
    $post = get_post( $id );
    if ( ! $post ) { return new WP_Error( 'not_found', 'Not found', array( 'status' => 404 ) ); }
    return current_user_can( 'edit_post', $id );
},
```

Returning `WP_Error` from `permission_callback` propagates the status code; returning `false` becomes 403.

## `sanitize_callback` vs `validate_callback`

- `sanitize_callback`: transforms the value into a safe shape. Runs **before** `validate_callback` and **before** your handler.
- `validate_callback`: returns `true` for valid, `false` or `WP_Error` for invalid. Runs after sanitization.

Use both: sanitize narrows the input, validate rejects invalid values.

## Schema-driven args

```php
'args' => array(
    'status' => array(
        'type'    => 'string',
        'enum'    => array( 'draft', 'publish' ),
        'default' => 'draft',
    ),
    'tags' => array(
        'type'  => 'array',
        'items' => array( 'type' => 'integer' ),
        'sanitize_callback' => function ( $v ) {
            return array_map( 'absint', (array) $v );
        },
    ),
),
```

The REST framework will reject inputs that don't match the declared type/enum before invoking your handler — leverage it.

## Returning errors

```php
return new WP_Error(
    'my_plugin_invalid',
    __( 'The thing is invalid.', 'my-plugin' ),
    array( 'status' => 400 )
);
```

Always set `status` in the `$data` array — without it, REST returns 500.

## Auth modes

| Mode | When | Header |
|---|---|---|
| Cookie + nonce | Logged-in browser sessions | `X-WP-Nonce` (auto via `wp.apiFetch`) |
| Application Passwords | Server-to-server, mobile apps | `Authorization: Basic ...` |
| OAuth / JWT | Third-party integrations | varies (plugin-provided) |

`is_user_logged_in()` works inside `permission_callback` for cookie/AppPwd auth.

## Rate limiting

REST endpoints have no built-in rate limit. For public endpoints, integrate with a CDN/edge rule, or implement IP-based limiting with transients:

```php
$ip   = $_SERVER['REMOTE_ADDR'];
$key  = 'mp_rl_' . md5( $ip );
$hits = (int) get_transient( $key );
if ( $hits > 60 ) {
    return new WP_Error( 'too_many', 'Rate limited', array( 'status' => 429 ) );
}
set_transient( $key, $hits + 1, MINUTE_IN_SECONDS );
```

This is a coarse floor — for production-grade limiting use a dedicated layer.

## Mistakes to flag

- `__return_true` permission on a write endpoint.
- Missing `permission_callback` entirely (warning in `WP_DEBUG`).
- Reading `$_POST` / `$_GET` inside a REST handler — use `$request->get_param()`.
- Validating in the handler instead of in `args` — duplicates work and loses schema documentation.
- Returning a `WP_Error` without `array( 'status' => N )` → 500.
- Calling `check_ajax_referer` inside REST — REST cookie auth already verifies the nonce.
