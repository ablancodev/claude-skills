---
name: wordpress-7-ai-abilities
description: Use when writing or reviewing PHP code that integrates with the WordPress 7.0 ("Armstrong") AI Client or the Abilities API. Covers `wp_ai_client_prompt()` and the fluent `WP_AI_Client_Prompt_Builder` (text/image/audio/video generation, structured JSON output, multimodal, model preferences, temperature, system instructions, REST integration, `wp_ai_client_prevent_prompt` filter), and the Abilities API (`wp_register_ability`, `wp_register_ability_category`, `wp_get_ability`, `wp_abilities_api_init`, `WP_Ability`, input/output JSON Schema, `permission_callback`, ability annotations, custom ability classes). Trigger when the user mentions: WordPress AI, AI Client, Abilities API, `wp_register_ability`, `wp_ai_client_prompt`, Connectors screen, OpenAI/Anthropic/Google provider plugins, MCP-style abilities in WordPress, exposing plugin features to AI, or building AI-assisted features in a WP 7.0+ plugin or theme.
---

# WordPress 7.0 AI Client + Abilities API

WordPress 7.0 ("Armstrong", May 2026) introduced two complementary core APIs:

1. **AI Client** — provider-agnostic SDK to call LLMs from PHP. Site admin configures providers in *Settings → Connectors*; plugins ask for a capability, core picks a model.
2. **Abilities API** — declarative registry of "things plugins can do", with JSON Schema for inputs/outputs. Exposable to AI agents, REST, MCP, the Abilities Explorer admin screen, and the Block Bindings system.

These two are the way to ship AI-enabled features in WP 7.0+. Do **not** bundle a third-party HTTP client to talk to OpenAI/Anthropic/Google directly — use the AI Client so admins can swap providers.

## When to use this skill

Load this skill when you are about to:

- Add an AI feature to a WordPress plugin or theme (text generation, summarization, alt-text, image gen, classification, embeddings).
- Expose a plugin capability so AI agents (or other plugins) can discover and call it: registering an ability.
- Build a REST endpoint, block, or admin tool that calls an AI provider through Core.
- Review a plugin that already uses these APIs, or that should be migrated off a direct cURL/Guzzle call to an LLM.

For block development without React, load **wordpress-gutenberg-php-blocks**.
For nonces/sanitization/escaping/capabilities, load **wordpress-plugin-security**.

## Hard rules

1. **Never call OpenAI/Anthropic/Google APIs directly** from a WP 7.0+ plugin. Always go through `wp_ai_client_prompt()`. Reasons: shared rate limiting, shared credentials, admin control, provider swapping, future MCP integration.
2. **Always check `is_supported_for_*()` before rendering UI** that depends on a capability. The check is deterministic, free, and lets you hide buttons when no configured provider supports the feature.
3. **Every generator method returns `WP_Error` on failure.** Always branch on `is_wp_error()` — never assume success.
4. **Gate prompt execution with a capability and a nonce/REST permission_callback.** Free-text LLM access from an unprivileged user is a vulnerability vector. Combine with `wp_ai_client_prevent_prompt` for global policy.
5. **For structured output, pass a JSON Schema** to `as_json_response($schema)`. Do not regex/parse free text from the model.
6. **Pin a model preference list — not a single model.** The first one available wins; the others are fallbacks. Example: `['claude-sonnet-4-6', 'gemini-3.1-pro-preview', 'gpt-5.4']`.
7. **Register every distinct plugin operation as an ability** (`wp_register_ability`). One ability = one verb. Bias toward many small abilities with tight JSON Schemas rather than one mega-ability.
8. **Always supply an `output_schema`.** It is required for `wp_register_ability` and it is what AI agents read to know what they'll get back.
9. **Always supply a `permission_callback`** on every ability. `__return_true` is acceptable for genuinely public read-only abilities; for everything else, use `current_user_can(...)`.
10. **Mark destructive/idempotent annotations** in `meta.annotations` so agents (and the Abilities Explorer) can warn before running them.
11. **For REST exposure, return `rest_ensure_response($result)`** on the `GenerativeAiResult` object — it serializes itself with token usage and provider metadata.
12. **Do not expose the raw prompt builder to JavaScript clients.** Build per-feature REST endpoints with their own capability checks. The generic `wp-ai-client` JS package is admin-only.

## AI Client — canonical patterns

### Text generation

```php
$text = wp_ai_client_prompt( 'Write a haiku about WordPress.' )
    ->generate_text();

if ( is_wp_error( $text ) ) {
    return $text;
}
echo wp_kses_post( $text );
```

### Structured JSON output

```php
$schema = array(
    'type'  => 'array',
    'items' => array(
        'type'       => 'object',
        'properties' => array(
            'plugin_name' => array( 'type' => 'string' ),
            'category'    => array( 'type' => 'string' ),
        ),
        'required' => array( 'plugin_name', 'category' ),
    ),
);

$json = wp_ai_client_prompt( 'List 5 popular WordPress plugins with their primary category.' )
    ->as_json_response( $schema )
    ->generate_text();
```

### Full configuration

```php
$text = wp_ai_client_prompt( 'Summarize the benefits of caching in WordPress.' )
    ->using_temperature( 0.7 )
    ->using_system_instruction( 'You are a WordPress developer writing documentation.' )
    ->using_max_tokens( 8000 )
    ->using_model_preference(
        'claude-sonnet-4-6',
        'gemini-3.1-pro-preview',
        'gpt-5.4'
    )
    ->generate_text();
```

### Image generation

```php
use WordPress\AiClient\Files\DTO\File;

$image_file = wp_ai_client_prompt( 'A futuristic WordPress logo in neon style' )
    ->generate_image();

if ( is_wp_error( $image_file ) ) {
    return $image_file;
}

echo '<img src="' . esc_url( $image_file->getDataUri() ) . '" alt="">';
```

### Multimodal output

```php
use WordPress\AiClient\Messages\Enums\ModalityEnum;

$result = wp_ai_client_prompt( 'Recipe for chocolate cake with photos per step.' )
    ->as_output_modalities( ModalityEnum::text(), ModalityEnum::image() )
    ->generate_result();

foreach ( $result->toMessage()->getParts() as $part ) {
    if ( $part->isText() ) {
        echo wp_kses_post( $part->getText() );
    } elseif ( $part->isFile() && $part->getFile()->isImage() ) {
        echo '<img src="' . esc_url( $part->getFile()->getDataUri() ) . '">';
    }
}
```

### Feature detection

```php
$builder = wp_ai_client_prompt( 'test' )->using_temperature( 0.7 );

if ( ! $builder->is_supported_for_text_generation() ) {
    return; // Hide UI, no providers available
}
```

Available checks: `is_supported_for_text_generation`, `..._image_generation`, `..._text_to_speech_conversion`, `..._speech_generation`, `..._video_generation`.

### REST endpoint

```php
function my_plugin_ai_summarize( WP_REST_Request $request ) {
    $result = wp_ai_client_prompt( $request->get_param( 'text' ) )
        ->using_system_instruction( 'Summarize in 3 bullet points.' )
        ->generate_text_result();

    if ( is_wp_error( $result ) ) {
        return $result;
    }
    return rest_ensure_response( $result ); // serializes with token usage + metadata
}
```

### Global policy filter

```php
add_filter(
    'wp_ai_client_prevent_prompt',
    function ( bool $prevent, WP_AI_Client_Prompt_Builder $builder ): bool {
        if ( ! current_user_can( 'manage_options' ) ) {
            return true; // Block non-admins entirely
        }
        return $prevent;
    },
    10, 2
);
```

When prevented: no API call fires, `is_supported_*()` returns `false`, `generate_*()` returns `WP_Error`.

### Configuration table

| Configuration | Method |
|---|---|
| Prompt text | `with_text()` (or arg to `wp_ai_client_prompt()`) |
| File input | `with_file()` |
| Conversation history | `with_history()` |
| System instruction | `using_system_instruction()` |
| Temperature | `using_temperature()` |
| Max tokens | `using_max_tokens()` |
| Top-p / Top-k | `using_top_p()`, `using_top_k()` |
| Stop sequences | `using_stop_sequences()` |
| Model preference | `using_model_preference(...)` |
| Output modalities | `as_output_modalities(...)` |
| Output file type | `as_output_file_type(...)` |
| JSON response | `as_json_response($schema)` |

Generator endings: `generate_text()`, `generate_texts(N)`, `generate_image()`, `generate_images(N)`, `generate_result()`, `generate_text_result()`, `generate_image_result()`, `convert_text_to_speech_result()`, `generate_speech_result()`, `generate_video_result()`.

`*_result()` variants return a `GenerativeAiResult` with `getTokenUsage()`, `getProviderMetadata()`, `getModelMetadata()`, and is REST-serializable.

## Abilities API — canonical patterns

### Minimal read-only ability

```php
add_action( 'wp_abilities_api_init', 'my_plugin_register_site_info_ability' );
function my_plugin_register_site_info_ability() {
    wp_register_ability( 'my-plugin/get-site-info', array(
        'label'       => __( 'Get Site Information', 'my-plugin' ),
        'description' => __( 'Retrieves basic site data: name, description, URL.', 'my-plugin' ),
        'category'    => 'data-retrieval',
        'output_schema' => array(
            'type' => 'object',
            'properties' => array(
                'name'        => array( 'type' => 'string',  'description' => 'Site name' ),
                'description' => array( 'type' => 'string',  'description' => 'Site tagline' ),
                'url'         => array( 'type' => 'string', 'format' => 'uri' ),
            ),
        ),
        'execute_callback' => function() {
            return array(
                'name'        => get_bloginfo( 'name' ),
                'description' => get_bloginfo( 'description' ),
                'url'         => home_url(),
            );
        },
        'permission_callback' => '__return_true',
        'meta' => array(
            'annotations' => array(
                'readonly'    => true,
                'destructive' => false,
            ),
        ),
    ) );
}
```

### Ability with input validation + WP_Error

```php
add_action( 'wp_abilities_api_init', 'my_plugin_register_update_option_ability' );
function my_plugin_register_update_option_ability() {
    wp_register_ability( 'my-plugin/update-option', array(
        'label'       => __( 'Update WordPress Option', 'my-plugin' ),
        'description' => __( 'Updates option values. Requires manage_options.', 'my-plugin' ),
        'category'    => 'data-modification',
        'input_schema' => array(
            'type' => 'object',
            'properties' => array(
                'option_name'  => array( 'type' => 'string', 'minLength' => 1 ),
                'option_value' => array( 'description' => 'New value' ),
            ),
            'required'             => array( 'option_name', 'option_value' ),
            'additionalProperties' => false,
        ),
        'output_schema' => array(
            'type' => 'object',
            'properties' => array(
                'success'        => array( 'type' => 'boolean' ),
                'previous_value' => array(),
            ),
        ),
        'execute_callback' => function( $input ) {
            $previous = get_option( $input['option_name'] );
            $ok       = update_option( $input['option_name'], $input['option_value'] );
            return array( 'success' => $ok, 'previous_value' => $previous );
        },
        'permission_callback' => function() {
            return current_user_can( 'manage_options' );
        },
        'meta' => array(
            'annotations' => array(
                'destructive' => false,
                'idempotent'  => true,
            ),
        ),
    ) );
}
```

Returning `new WP_Error( 'code', 'message' )` from `execute_callback` short-circuits and propagates correctly.

### Custom ability class (for logging / instrumentation)

```php
class My_Plugin_Post_Validator_Ability extends WP_Ability {
    protected function do_execute( $input = null ) {
        error_log( sprintf( 'Executing %s', $this->get_name() ) );
        $result = parent::do_execute( $input );
        if ( is_wp_error( $result ) ) {
            error_log( sprintf( 'Failed: %s', $result->get_error_message() ) );
        }
        return $result;
    }
}
// Then pass 'ability_class' => 'My_Plugin_Post_Validator_Ability' in the args.
```

### Calling an ability

```php
$ability = wp_get_ability( 'my-plugin/update-option' );
if ( $ability ) {
    $input  = array( 'option_name' => 'blogname', 'option_value' => 'New Name' );

    // Optional pre-flight permission check
    if ( true !== $ability->check_permissions( $input ) ) {
        return new WP_Error( 'forbidden', 'No permission' );
    }

    $result = $ability->execute( $input );
    if ( is_wp_error( $result ) ) {
        return $result;
    }
}
```

### Required ability shape (cheat sheet)

| Key | Required | Notes |
|---|---|---|
| `label` | yes | Human-readable, translatable |
| `description` | yes | AI agents read this — be thorough |
| `category` | yes | Slug; register first with `wp_register_ability_category()` |
| `execute_callback` | yes | Receives `$input` (validated), returns array or `WP_Error` |
| `output_schema` | yes | JSON Schema describing the return shape |
| `input_schema` | no | Required if the ability takes input — recommended |
| `permission_callback` | yes-in-practice | `__return_true` only for truly public read ops |
| `meta.annotations` | recommended | `readonly`, `destructive`, `idempotent` |
| `ability_class` | no | Subclass `WP_Ability` for custom behavior |

## Decision flow

```
Need to call an LLM from PHP?
  └── wp_ai_client_prompt()->[configure]->generate_*()

Need to expose a plugin operation to AI / REST / MCP?
  └── wp_register_ability() inside wp_abilities_api_init

Both? (typical AI feature)
  └── Register an ability whose execute_callback uses wp_ai_client_prompt()
      so the operation has a stable schema AND uses a configurable provider.
```

The combo (ability that internally calls the AI Client) is the sweet spot: it gives admins a single place to disable the feature, gives AI agents a typed entry point, and gives you provider-agnostic execution.

## Anti-patterns to flag

- Bundling `openai-php/client`, Guzzle calls to `api.openai.com`, hard-coded API keys → migrate to `wp_ai_client_prompt()`.
- Calling `generate_text()` and parsing the result with regex/`json_decode` → use `as_json_response($schema)`.
- Hard-pinned single model (`->using_model_preference('gpt-5.4')`) → pass a fallback list.
- Ability with `'permission_callback' => '__return_true'` on a write/destructive op → use `current_user_can(...)`.
- Mega-ability that does five things based on a `mode` parameter → split into five abilities.
- Missing `output_schema` or vague description → agents will not pick the ability correctly.
- Exposing the prompt builder to logged-out users via REST → add capability gating and the `wp_ai_client_prevent_prompt` filter.
- Catching no `WP_Error` from a `generate_*()` call → every one of them can fail.

## See also (load on demand)

- `references/ai-client-cheatsheet.md` — every builder method with one-line description
- `references/abilities-recipes.md` — read-only, write, destructive, async, and ability-wrapping-LLM patterns
- `references/connectors.md` — Connectors screen, the three official provider plugins, credential model

## Companion skills

- **wordpress-gutenberg-php-blocks** — when surfacing AI results in a block.
- **wordpress-plugin-security** — required reading before shipping any AI feature.
