---
name: wordpress-gutenberg-php-blocks
description: Use when creating, reviewing, or migrating Gutenberg blocks **without React or a build step** — pure PHP using `block.json` + `render.php` + `register_block_type()`, including the WordPress 7.0 PHP-only block registration with `supports.autoRegister = true` that auto-generates Inspector controls from `attributes`. Covers dynamic block rendering, `render_callback` vs `render` file, `block.json` schema, server-side rendering via the `ServerSideRender` component, attribute types (string/number/integer/boolean/enum) and when each renders an auto control, Block Bindings, when PHP-only is appropriate vs. when you still need JS, and migration patterns from JS-based blocks. Trigger when the user mentions: Gutenberg block, dynamic block, `block.json`, `render.php`, `register_block_type`, no-React block, PHP-only block, server-side render, `autoRegister`, or wants to expose plugin data as a Gutenberg block without a build pipeline.
---

# Gutenberg blocks in pure PHP (WordPress 7.0+)

WordPress 7.0 added **PHP-only block registration**: register a block from PHP, declare its attributes, write a `render_callback`, and the editor automatically generates Inspector panel controls. Zero JavaScript, zero `npm`, zero build step.

This is the right tool for server-driven, low-interactivity blocks: latest posts, third-party API integrations, dashboards, AI-generated content, anything where the editor preview just needs to reflect server output.

It is the wrong tool for highly interactive blocks (rich text editing, drag-and-drop, custom canvas), block patterns that need bespoke sidebar UI, or blocks that mutate inner blocks. For those, you still need a JS `edit` component.

## When to use this skill

Load this skill when you are about to:

- Create a new Gutenberg block for a plugin or theme without setting up a build pipeline.
- Migrate an existing JS-built dynamic block to PHP-only.
- Review a block that has a `render.php` or `render_callback`.
- Expose data from a plugin (or an Abilities API result, or an AI Client call) as a block.

If the block displays AI output, also load **wordpress-7-ai-abilities**.
If the block accepts user input or writes data, also load **wordpress-plugin-security**.

## Hard rules

1. **`block.json` is mandatory.** It is the single source of truth for the block, ships metadata to the editor, and gates i18n / asset enqueueing.
2. **Choose one rendering mechanism — never both.** Either `render_callback` (closure/function passed to `register_block_type`) **or** the `"render"` key in `block.json` pointing at a PHP file. Not both.
3. **Set `"apiVersion": 3`** in `block.json` for any new block (matches WP 6.3+ iframed editor; required for WP 7.0 auto-controls).
4. **For PHP-only blocks with auto-controls, set `supports.autoRegister = true`.** Without it, the editor will not generate the Inspector UI from your attributes.
5. **Attribute types that auto-generate controls:** `string`, `number`, `integer`, `boolean`, and `string` with `enum`. Anything else (arrays, objects, rich text) is not auto-rendered — you need a JS edit component for that.
6. **`escape every attribute on output`** — `esc_html`, `esc_attr`, `esc_url`, `wp_kses_post` etc. Attributes are user-controlled input, regardless of how they got set. (See **wordpress-plugin-security**.)
7. **Use `get_block_wrapper_attributes()`** to render the outer `<div>` so block supports (className, custom colors, spacing, layout) work without you reimplementing them.
8. **Localize via `'textdomain'`** in `block.json` and the standard translation functions in `render_callback`.
9. **Do not echo from `render_callback`** — return the HTML string. Echoing breaks editor preview round-trips.
10. **Editor previews PHP blocks via `ServerSideRender`** — every attribute change fires a REST call to your `render_callback`. Keep it cheap; cache expensive work with transients.

## Canonical pattern — PHP-only block (WP 7.0)

The shape from the official "PHP-only block registration" announcement.

```php
<?php
function gutenberg_register_php_only_blocks() {
    register_block_type(
        'my-plugin/example',
        array(
            'title'      => __( 'My Example Block', 'myplugin' ),
            'attributes' => array(
                'title'   => array(
                    'label'   => __( 'Title', 'myplugin' ),
                    'type'    => 'string',
                    'default' => 'Hello World',
                ),
                'count'   => array(
                    'label'   => __( 'Count', 'myplugin' ),
                    'type'    => 'integer',
                    'default' => 5,
                ),
                'enabled' => array(
                    'label'   => __( 'Enabled?', 'myplugin' ),
                    'type'    => 'boolean',
                    'default' => true,
                ),
                'size'    => array(
                    'label'   => __( 'Size', 'myplugin' ),
                    'type'    => 'string',
                    'enum'    => array( 'small', 'medium', 'large' ),
                    'default' => 'medium',
                ),
            ),
            'render_callback' => function ( $attributes ) {
                return sprintf(
                    '<p %s>%s: %d items (%s)</p>',
                    get_block_wrapper_attributes(),
                    esc_html( $attributes['title'] ),
                    (int) $attributes['count'],
                    esc_html( $attributes['size'] )
                );
            },
            'supports' => array(
                'autoRegister' => true,
            ),
        )
    );
}
add_action( 'init', 'gutenberg_register_php_only_blocks' );
```

What you get **for free** from `autoRegister => true`:

| Attribute declaration | Auto control |
|---|---|
| `'type' => 'string'` | Text input |
| `'type' => 'string'` + `'enum'` | Select |
| `'type' => 'integer'` or `'number'` | Number input |
| `'type' => 'boolean'` | Toggle |

`label` is shown as the control label. `default` populates initial values.

## Canonical pattern — `block.json` + `render.php`

The more conventional layout, recommended when the block is non-trivial. Works in WP 6.1+ and is fully compatible with the 7.0 auto-controls (just add `supports.autoRegister`).

**Directory:**

```
my-plugin/
└── blocks/
    └── latest-events/
        ├── block.json
        └── render.php
```

**`block.json`:**

```json
{
  "$schema": "https://schemas.wp.org/trunk/block.json",
  "apiVersion": 3,
  "name": "my-plugin/latest-events",
  "title": "Latest Events",
  "category": "widgets",
  "description": "Shows the N most recent events from the Events CPT.",
  "textdomain": "my-plugin",
  "attributes": {
    "count":  { "label": "Count",          "type": "integer", "default": 5, "minimum": 1, "maximum": 50 },
    "layout": { "label": "Layout",         "type": "string",  "enum": ["list", "grid"], "default": "list" },
    "showDate":{ "label": "Show date",     "type": "boolean", "default": true }
  },
  "supports": {
    "autoRegister": true,
    "html": false,
    "align": ["wide", "full"]
  },
  "render": "file:./render.php"
}
```

**`render.php`:**

```php
<?php
/**
 * @var array  $attributes Validated against block.json attributes.
 * @var string $content    Inner blocks rendered HTML (empty for leaf blocks).
 * @var WP_Block $block    Block instance.
 */

$count    = (int) ( $attributes['count'] ?? 5 );
$layout   = $attributes['layout'] ?? 'list';
$show_date = ! empty( $attributes['showDate'] );

$events = get_posts( array(
    'post_type'      => 'event',
    'posts_per_page' => $count,
    'post_status'    => 'publish',
) );

if ( empty( $events ) ) {
    return '<p ' . get_block_wrapper_attributes() . '>'
         . esc_html__( 'No events found.', 'my-plugin' )
         . '</p>';
}

ob_start();
?>
<ul <?php echo get_block_wrapper_attributes( array( 'class' => 'events-' . esc_attr( $layout ) ) ); ?>>
    <?php foreach ( $events as $event ) : ?>
        <li>
            <a href="<?php echo esc_url( get_permalink( $event ) ); ?>">
                <?php echo esc_html( get_the_title( $event ) ); ?>
            </a>
            <?php if ( $show_date ) : ?>
                <time datetime="<?php echo esc_attr( get_the_date( 'c', $event ) ); ?>">
                    <?php echo esc_html( get_the_date( '', $event ) ); ?>
                </time>
            <?php endif; ?>
        </li>
    <?php endforeach; ?>
</ul>
<?php
return ob_get_clean();
```

**Registering the block:**

```php
add_action( 'init', function () {
    register_block_type( __DIR__ . '/blocks/latest-events' );
} );
```

`register_block_type()` with a directory path reads `block.json` automatically.

## When PHP-only is NOT enough

Switch to a JS edit component if any of these apply:

- The attribute is a list of items the user adds/removes/reorders.
- The block needs inner blocks (`<InnerBlocks />`).
- You need a richer control: media picker, color picker beyond block supports, post selector, anything not in the auto-control table.
- The block has live, interactive behavior in the editor (drag, resize, rich text).
- The block needs a custom Toolbar.

For those, keep `render.php` (server-side rendering) and add a `src/edit.js` / `block.json#editorScript`. The hybrid is supported and common.

## Editor preview model

PHP-only blocks render in the editor through `ServerSideRender`. Cycle:

```
User changes attribute in Inspector
    → editor fires REST POST /wp/v2/block-renderer/<block-name>
    → core calls your render_callback / render.php
    → returned HTML replaces the preview
```

Implications:

- Every change = one REST round-trip. Debounce-heavy UI feels sluggish — keep `render_callback` fast.
- Expensive calls (HTTP, AI, slow DB) **must** be cached. Use a transient keyed on the relevant attributes:

```php
$key   = 'mp_latest_events_' . md5( wp_json_encode( $attributes ) );
$html  = get_transient( $key );
if ( false === $html ) {
    $html = build_html( $attributes );
    set_transient( $key, $html, MINUTE_IN_SECONDS * 5 );
}
return $html;
```

- The editor preview runs with the editing user's capabilities — never display admin-only data without a capability check.

## Block Bindings (WP 6.5+, expanded in 7.0)

Bind a core block attribute (e.g. paragraph `content`) to a dynamic source registered in PHP. Useful for surfacing meta, options, or AI output **without writing a custom block**:

```php
register_block_bindings_source( 'my-plugin/post-meta', array(
    'label'              => __( 'Post Meta', 'my-plugin' ),
    'get_value_callback' => function ( $source_args, $block ) {
        return get_post_meta( $block->context['postId'], $source_args['key'] ?? '', true );
    },
    'uses_context'       => array( 'postId' ),
) );
```

Then in the editor, an author binds a Paragraph block's `content` attribute to `my-plugin/post-meta` with `{ key: 'subtitle' }`. No custom block needed.

## Decision tree

```
Block needs to render server data + has only simple controls (text/number/select/toggle)?
    → PHP-only with supports.autoRegister = true. Done.

Block needs richer UI / inner blocks / interactivity?
    → block.json with both render.php AND editorScript (hybrid)

Just need to inject a single dynamic value into an existing core block?
    → Block Bindings — register a source, no custom block at all
```

## Anti-patterns to flag

- `echo` inside `render_callback` → return the string.
- Forgetting `get_block_wrapper_attributes()` → block supports (className, colors, spacing) silently break.
- Unescaped attribute interpolation → XSS. `esc_html` / `esc_attr` / `esc_url` / `wp_kses_post` every time.
- `supports.autoRegister` missing on a PHP-only block → no Inspector controls.
- Expensive uncached work in `render_callback` → editor lags on every keystroke.
- Both `render_callback` and `render` set → conflicting renderers.
- Registering via `register_block_type` with a string name but no `block.json` → loses i18n, asset handling, schema. Always ship a `block.json`.
- Using an `array`/`object` attribute on a PHP-only block expecting an auto-control → not supported, drop to hybrid.

## See also (load on demand)

- `references/block-json-schema.md` — every `block.json` field with WP 7.0 additions
- `references/server-side-render.md` — caching, REST endpoint, debug tips
- `references/block-bindings.md` — registering and consuming bindings sources

## Companion skills

- **wordpress-7-ai-abilities** — when the block renders AI output, prefer wrapping the call in an ability so it is observable and gated.
- **wordpress-plugin-security** — required reading.
