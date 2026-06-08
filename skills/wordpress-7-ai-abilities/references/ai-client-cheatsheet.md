# AI Client builder — full cheat sheet

Entry point: `wp_ai_client_prompt( string $text = null ): WP_AI_Client_Prompt_Builder`

## Input configuration

| Method | Purpose |
|---|---|
| `with_text( $text )` | Append/replace user text |
| `with_file( $file )` | Attach a file (image, audio, video, document) |
| `with_history( $messages )` | Provide prior conversation turns |

## Sampling / generation parameters

| Method | Purpose |
|---|---|
| `using_system_instruction( $text )` | System prompt |
| `using_temperature( $float )` | 0.0 deterministic → 1.0+ creative |
| `using_max_tokens( $int )` | Hard cap on response length |
| `using_top_p( $float )` | Nucleus sampling |
| `using_top_k( $int )` | Top-K sampling |
| `using_stop_sequences( $array )` | Stop at first match |
| `using_model_preference( $a, $b, ... )` | Ordered fallback list of model IDs |

## Output shaping

| Method | Purpose |
|---|---|
| `as_output_modalities( ModalityEnum::text(), ModalityEnum::image(), ... )` | Multimodal output |
| `as_output_file_type( FileTypeEnum::inline() )` | Inline data URI vs file |
| `as_output_media_orientation( MediaOrientationEnum::from('landscape') )` | Hint for image gen |
| `as_json_response( $jsonSchema )` | Force structured output matching schema |

## Generator methods

Each returns either the value or `WP_Error`:

| Method | Returns |
|---|---|
| `generate_text()` | `string` |
| `generate_texts( $n )` | `string[]` |
| `generate_image()` | `File` |
| `generate_images( $n )` | `File[]` |
| `generate_result()` | `GenerativeAiResult` (multimodal) |
| `generate_text_result()` | `GenerativeAiResult` |
| `generate_image_result()` | `GenerativeAiResult` |
| `convert_text_to_speech_result()` | `GenerativeAiResult` |
| `generate_speech_result()` | `GenerativeAiResult` |
| `generate_video_result()` | `GenerativeAiResult` |

`GenerativeAiResult` exposes:

- `toMessage()->getParts()` — iterate text/file parts
- `getTokenUsage()` — input / output / thinking tokens
- `getProviderMetadata()`
- `getModelMetadata()`
- REST-serializable via `rest_ensure_response()`

`File` exposes `getDataUri()`, `isImage()`, plus type/MIME accessors.

## Feature detection (free, no API call)

| Method | Returns true if … |
|---|---|
| `is_supported_for_text_generation()` | A configured model can generate text |
| `is_supported_for_image_generation()` | …generate images |
| `is_supported_for_text_to_speech_conversion()` | …TTS |
| `is_supported_for_speech_generation()` | …open-ended speech |
| `is_supported_for_video_generation()` | …video |

## Global gates

Filter: `wp_ai_client_prevent_prompt( bool $prevent, WP_AI_Client_Prompt_Builder $builder ): bool`

When `$prevent === true`: API call is skipped, support checks return `false`, generators return `WP_Error`.

## Architecture note

`WP_AI_Client_Prompt_Builder` is a WP convention wrapper (snake_case, `WP_Error`, hooks) over `wordpress/php-ai-client` (camelCase, exceptions). Use the wrapper from plugin/theme code; only reach into the SDK when you need exception handling.
