# Abilities API — recipe collection

## 1. Register a category first

Every ability requires a registered category.

```php
add_action( 'wp_abilities_api_init', function () {
    wp_register_ability_category( 'my-plugin-content', array(
        'label'       => __( 'My Plugin: Content', 'my-plugin' ),
        'description' => __( 'Content operations exposed by My Plugin.', 'my-plugin' ),
    ) );
} );
```

## 2. Read-only data retrieval

Annotate `readonly => true`. `permission_callback` can be `__return_true` only if the data is genuinely public; otherwise use a capability.

```php
wp_register_ability( 'my-plugin/list-recent-posts', array(
    'label'    => __( 'List Recent Posts', 'my-plugin' ),
    'description' => __( 'Returns the N most recent published posts.', 'my-plugin' ),
    'category' => 'my-plugin-content',
    'input_schema' => array(
        'type' => 'object',
        'properties' => array(
            'count' => array( 'type' => 'integer', 'minimum' => 1, 'maximum' => 50, 'default' => 5 ),
        ),
    ),
    'output_schema' => array(
        'type' => 'array',
        'items' => array(
            'type' => 'object',
            'properties' => array(
                'id'    => array( 'type' => 'integer' ),
                'title' => array( 'type' => 'string' ),
                'url'   => array( 'type' => 'string', 'format' => 'uri' ),
            ),
        ),
    ),
    'execute_callback' => function ( $input ) {
        $count = $input['count'] ?? 5;
        $posts = get_posts( array( 'numberposts' => $count, 'post_status' => 'publish' ) );
        return array_map( fn( $p ) => array(
            'id'    => $p->ID,
            'title' => $p->post_title,
            'url'   => get_permalink( $p ),
        ), $posts );
    },
    'permission_callback' => '__return_true',
    'meta' => array( 'annotations' => array( 'readonly' => true, 'destructive' => false ) ),
) );
```

## 3. Idempotent write

```php
'meta' => array( 'annotations' => array( 'destructive' => false, 'idempotent' => true ) ),
'permission_callback' => function() { return current_user_can( 'edit_posts' ); },
```

## 4. Destructive operation

Mark `destructive => true` so the Abilities Explorer warns and AI agents request explicit confirmation.

```php
'meta' => array( 'annotations' => array( 'destructive' => true, 'idempotent' => false ) ),
'permission_callback' => function() { return current_user_can( 'delete_posts' ); },
```

## 5. Ability that wraps the AI Client (the sweet spot)

```php
wp_register_ability( 'my-plugin/summarize-post', array(
    'label' => __( 'Summarize Post', 'my-plugin' ),
    'description' => __( 'Returns a 3-bullet summary of a post body using the configured AI provider.', 'my-plugin' ),
    'category' => 'my-plugin-content',
    'input_schema' => array(
        'type' => 'object',
        'properties' => array(
            'post_id' => array( 'type' => 'integer', 'minimum' => 1 ),
        ),
        'required' => array( 'post_id' ),
    ),
    'output_schema' => array(
        'type' => 'object',
        'properties' => array(
            'bullets' => array(
                'type'  => 'array',
                'items' => array( 'type' => 'string' ),
                'minItems' => 1,
                'maxItems' => 5,
            ),
        ),
        'required' => array( 'bullets' ),
    ),
    'execute_callback' => function ( $input ) {
        $post = get_post( $input['post_id'] );
        if ( ! $post ) {
            return new WP_Error( 'not_found', __( 'Post not found.', 'my-plugin' ) );
        }

        $schema = array(
            'type' => 'object',
            'properties' => array(
                'bullets' => array(
                    'type'  => 'array',
                    'items' => array( 'type' => 'string' ),
                ),
            ),
            'required' => array( 'bullets' ),
        );

        $json = wp_ai_client_prompt( wp_strip_all_tags( $post->post_content ) )
            ->using_system_instruction( 'Summarize the post in 3 short bullets.' )
            ->using_temperature( 0.3 )
            ->as_json_response( $schema )
            ->generate_text();

        if ( is_wp_error( $json ) ) {
            return $json;
        }
        return json_decode( $json, true );
    },
    'permission_callback' => function() { return current_user_can( 'edit_posts' ); },
    'meta' => array( 'annotations' => array( 'readonly' => true, 'destructive' => false ) ),
) );
```

This pattern gives you:

- A typed, schema-validated entry point.
- Provider-agnostic execution (Connectors).
- Free admin UI in the Abilities Explorer.
- A REST endpoint via the abilities REST surface.
- Reusable by any AI agent that speaks the Abilities API.

## 6. Calling an ability from your own code

```php
$ability = wp_get_ability( 'my-plugin/summarize-post' );
if ( ! $ability ) { return; }

$result = $ability->execute( array( 'post_id' => 42 ) );
if ( is_wp_error( $result ) ) {
    error_log( $result->get_error_message() );
    return;
}

print_r( $result['bullets'] );
```

## 7. Listing all abilities

```php
foreach ( wp_get_abilities() as $ability ) {
    printf( "%s — %s\n", $ability->get_name(), $ability->get_label() );
}
```
