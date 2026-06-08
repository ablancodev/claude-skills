# Connectors — admin-side configuration

## Where

*WP Admin → Settings → Connectors*. Lives in core as of WP 7.0.

## Provider plugins (official)

Core ships the Connectors UI, but the actual provider integrations are separate plugins maintained by the WordPress AI team:

- **AI Provider for OpenAI**
- **AI Provider for Anthropic**
- **AI Provider for Google**

Admin installs the providers they want, pastes API keys into the Connectors screen, and the AI Client can route through whichever model is requested (or fallback list).

## What plugin code does NOT do

- Store API keys (the Connectors API handles credentials).
- Handle auth (no `Authorization: Bearer ...` headers in plugin code).
- Pick a specific provider (let core pick from your `using_model_preference()` list).
- Implement retries/rate limit handling (the AI Client does this).

## Model preferences

`->using_model_preference( $a, $b, $c )` is an **ordered list of hints**. Core picks the first model whose provider is configured.

- If none of the listed models is available, core may fall back to a default suitable model.
- If you pass no preference, core picks the first suitable configured model.
- Always pass at least two preferences so a single provider outage doesn't break the feature.

## Capability availability vs. provider availability

`is_supported_for_text_generation()` returns `true` only when there is at least one configured model that supports text generation. Use it before showing AI UI — never assume a feature is available.

## Cost / observability hooks

- `GenerativeAiResult::getTokenUsage()` returns input/output/thinking tokens — log these for cost monitoring.
- `GenerativeAiResult::getProviderMetadata()` / `getModelMetadata()` — capture provider + model for audit trails.
- Filter `wp_ai_client_prevent_prompt` for kill-switches, role gating, per-feature budgets.
