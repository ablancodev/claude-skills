# Editor preview, caching, and the `ServerSideRender` cycle

## How the preview works

For dynamic blocks (PHP `render_callback` / `render.php`), the editor uses the `ServerSideRender` React component (shipped in core). It POSTs the current attributes to `/wp-json/wp/v2/block-renderer/<block-name>` and replaces the preview with the response.

Every attribute change → one REST call → one PHP render. Editor responsiveness depends entirely on how fast your render is.

## Performance budget

Target: **< 100 ms** for a render call. Above ~300 ms the editor feels laggy when typing in Inspector text fields.

## Caching expensive work

```php
'render_callback' => function ( $attributes ) {
    $key  = 'mp_my_block_' . md5( wp_json_encode( $attributes ) );
    $html = get_transient( $key );

    if ( false === $html ) {
        $html = build_expensive_html( $attributes );
        set_transient( $key, $html, MINUTE_IN_SECONDS * 5 );
    }
    return $html;
}
```

- Hash only the attributes that affect output.
- For AI calls and external API hits, cache for at least minutes; bust the cache on relevant `save_post` or admin actions.
- Never cache user-specific data without including the user ID in the key.

## Skipping the preview render

If a block is expensive and its preview is not informative, you can skip the live preview by setting `supports.previewRender = false` (WP 7.0+) — the editor shows a static placeholder using `example` from `block.json` instead.

## Debugging

- `Network` tab → POST `/block-renderer/<name>` shows the exact payload + response.
- Add `WP_DEBUG_LOG` and `error_log()` inside `render_callback`.
- The block name in REST is dot-separated: `my-plugin/example` → `/block-renderer/my-plugin/example`.
- Editor previews use the editing user's permissions — restricted data may render differently from the frontend.

## Frontend vs editor differences

In `render_callback` you can detect editor context:

```php
if ( defined( 'REST_REQUEST' ) && REST_REQUEST ) {
    // Running inside the editor preview
}
```

But prefer to keep the same output in both contexts; divergence confuses authors.
