# Escaping by output context

The rule: **match the escaping function to where the data ends up**, not to where it came from.

## HTML body

```php
echo esc_html( $value );
```

For known-safe limited HTML (post content with allowed tags):

```php
echo wp_kses_post( $value );
```

For custom allowlists:

```php
echo wp_kses( $value, array(
    'a'      => array( 'href' => true, 'title' => true ),
    'strong' => array(),
    'em'     => array(),
) );
```

## HTML attribute

```php
<div class="<?php echo esc_attr( $class ); ?>"
     data-value="<?php echo esc_attr( $value ); ?>">
```

Numbers and identifiers still need it — anything that ends up between quotes.

## URL

In `href` / `src` / form `action`:

```php
<a href="<?php echo esc_url( $url ); ?>">
```

For storing or redirecting:

```php
$clean = esc_url_raw( $url );
wp_safe_redirect( $clean );
```

`wp_safe_redirect` additionally restricts the host to allowed list.

## Inline JavaScript

Never interpolate PHP into `<script>` blindly. Prefer JSON:

```php
<script>
const config = <?php echo wp_json_encode( $config ); ?>;
</script>
```

If you must inline a string inside JS quotes:

```php
<script>
const name = '<?php echo esc_js( $name ); ?>';
</script>
```

Better: pass via `wp_localize_script` or `wp_add_inline_script` which JSON-encodes for you.

## Textarea

```php
<textarea><?php echo esc_textarea( $value ); ?></textarea>
```

## SVG / arbitrary XML

Don't render user-supplied SVG without sanitization — SVG can contain script. Either store as a file and serve via `<img>` (browsers don't execute script in `<img>`-loaded SVG), or strip with `wp_kses` against a tight SVG allowlist.

## Filenames in `Content-Disposition`

```php
header( 'Content-Disposition: attachment; filename="' . sanitize_file_name( $name ) . '"' );
```

## Database (output side)

There is no "escape for SQL" function in WordPress — use `$wpdb->prepare()` to parameterize. Do not try to escape values for SQL yourself.

## Common mistakes

- **Double escaping**: `esc_html( esc_html( $x ) )` produces visible `&amp;` entities. Escape exactly once at output.
- **Sanitize at output**: `echo sanitize_text_field( $x )` — sanitization is for storage, not for HTML safety. Use `esc_html`.
- **Trusting "internal" data**: data from `wp_options`, post meta, or the database is still untrusted at the point of output — it came from input somewhere. Escape it.
- **`esc_html` on URL**: produces `https:&#x2F;&#x2F;example.com` — wrong escaper.
- **`esc_url` on an `href` for a `mailto:`**: works, but `esc_url` strips unknown protocols by default. Use `esc_url( $email, array( 'mailto' ) )` if needed.

## Translation + escaping in one call

| Function | Equivalent of |
|---|---|
| `esc_html__( $text, $domain )` | `esc_html( __( ... ) )` |
| `esc_html_e( $text, $domain )` | `echo esc_html( __( ... ) )` |
| `esc_attr__( $text, $domain )` | `esc_attr( __( ... ) )` |
| `esc_attr_e( $text, $domain )` | `echo esc_attr( __( ... ) )` |

Always use these — they keep translation and escaping atomic and impossible to forget one or the other.
