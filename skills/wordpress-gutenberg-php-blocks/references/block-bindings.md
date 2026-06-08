# Block Bindings — dynamic values without a custom block

Block Bindings let an author bind a **core block attribute** (e.g. Paragraph `content`, Image `url`, Button `text`) to a value computed in PHP. Often the right answer when you'd otherwise build a tiny custom block.

## Registering a source

```php
add_action( 'init', function () {
    register_block_bindings_source( 'my-plugin/post-meta', array(
        'label'              => __( 'Post Meta', 'my-plugin' ),
        'get_value_callback' => function ( $source_args, $block, $attribute_name ) {
            $key = $source_args['key'] ?? '';
            if ( ! $key || empty( $block->context['postId'] ) ) {
                return '';
            }
            return get_post_meta( $block->context['postId'], $key, true );
        },
        'uses_context' => array( 'postId' ),
    ) );
} );
```

## Using the binding in markup

```html
<!-- wp:paragraph {"metadata":{"bindings":{"content":{"source":"my-plugin/post-meta","args":{"key":"subtitle"}}}}} -->
<p>placeholder</p>
<!-- /wp:paragraph -->
```

The placeholder text is what the user sees in the editor; on render, `get_value_callback` supplies the real value.

## Binding to AI output

Wrap a `wp_ai_client_prompt()` call:

```php
register_block_bindings_source( 'my-plugin/ai-summary', array(
    'label'              => __( 'AI Summary', 'my-plugin' ),
    'get_value_callback' => function ( $source_args, $block ) {
        $post_id = $block->context['postId'] ?? 0;
        if ( ! $post_id ) { return ''; }

        $key   = 'mp_ai_summary_' . $post_id;
        $cached = get_transient( $key );
        if ( false !== $cached ) { return $cached; }

        $post = get_post( $post_id );
        $text = wp_ai_client_prompt( wp_strip_all_tags( $post->post_content ) )
            ->using_system_instruction( 'Summarize in one sentence.' )
            ->generate_text();

        if ( is_wp_error( $text ) ) { return ''; }

        set_transient( $key, $text, HOUR_IN_SECONDS );
        return $text;
    },
    'uses_context' => array( 'postId' ),
) );
```

Bust the transient on `save_post` for the relevant post.

## When to prefer bindings over a custom block

- The value is a single string/number that fits a core block attribute.
- The author chooses *where* to put it inside their content.
- You don't need bespoke Inspector UI beyond what the core block already offers.

If you need multiple coordinated outputs, Inspector controls beyond the host block's, or a non-text rendering shape, build a PHP-only block instead.
