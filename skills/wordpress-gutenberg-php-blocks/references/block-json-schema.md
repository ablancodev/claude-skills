# `block.json` — essential field reference

Schema: `https://schemas.wp.org/trunk/block.json`

## Required

| Field | Type | Notes |
|---|---|---|
| `apiVersion` | int | Use `3` for WP 6.3+. Required for `autoRegister`. |
| `name` | string | `namespace/slug` (lowercase, dashes). |
| `title` | string | Translatable. |
| `category` | string | `text`, `media`, `design`, `widgets`, `theme`, `embed` or a custom one. |

## Highly recommended

| Field | Type | Notes |
|---|---|---|
| `description` | string | Translatable. |
| `textdomain` | string | Required for i18n of `block.json` strings. |
| `icon` | string \| object | Dashicon name or SVG. |
| `keywords` | string[] | Editor search terms. |

## Attributes

```json
"attributes": {
  "title": {
    "label": "Title",
    "type": "string",
    "default": "Hello"
  },
  "count":    { "label": "Count",  "type": "integer", "default": 5, "minimum": 1, "maximum": 50 },
  "size":     { "label": "Size",   "type": "string",  "enum": ["sm","md","lg"], "default": "md" },
  "enabled":  { "label": "Enabled","type": "boolean", "default": true }
}
```

For PHP-only auto-controls, only these attribute shapes produce UI:
- `string`
- `string` + `enum`
- `integer`, `number`
- `boolean`

`label` (new convention in WP 7.0) is the auto-control label.

Beyond auto-controls, you may declare attributes of `type: array | object` for use in server output — they just won't render a built-in control.

## Supports

```json
"supports": {
  "autoRegister": true,
  "html": false,
  "align": ["wide", "full"],
  "color": { "background": true, "text": true, "link": true },
  "spacing": { "margin": true, "padding": true, "blockGap": true },
  "typography": { "fontSize": true, "lineHeight": true },
  "anchor": true,
  "customClassName": true
}
```

`autoRegister: true` (WP 7.0) is the trigger for PHP-only Inspector generation.

`html: false` is a sensible default for dynamic blocks — disables the "Edit as HTML" mode which doesn't apply to server-rendered output.

## Rendering

Use exactly one of:

```json
"render": "file:./render.php"
```

…or pass `render_callback` in `register_block_type()`. Never both.

## Assets (when you do add JS or CSS)

```json
"editorScript":  "file:./build/index.js",
"editorStyle":   "file:./build/index.css",
"style":         "file:./build/style.css",
"viewScript":    "file:./build/view.js"
```

`viewScript` runs on the frontend; only enqueue when the block is present on the page (core handles this automatically).

## Context

```json
"providesContext": { "myPlugin/postType": "postType" },
"usesContext":     ["postId", "postType"]
```

Useful for nested/parent-child blocks and Block Bindings.

## Registration

```php
register_block_type( __DIR__ . '/blocks/my-block' );
```

If the path contains `block.json`, core reads everything from it.
