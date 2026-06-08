# Foundation Models, Core AI, Evaluations, MLX (WWDC 2026)

## Foundation Models framework

Native Swift API for the on-device models powering Apple Intelligence, plus pluggable providers.

Capabilities:

- **Apple Foundation Models** (on-device) and **Private Cloud Compute** access (apps under 2M first-time downloads).
- **Third-party providers** through the Language Model protocol — including Claude and Gemini.
- **Multimodal**: pass images alongside text for visual reasoning.
- **Tool calls**: built-in Vision tools (OCR, barcode reader) run on-device.
- **Dynamic Profiles**: swap model / tools / instructions mid-session.
- **Structured output** via `@Generable` types — never hand-parse JSON.

### Mandatory patterns

1. **Prompt caching is on by default — keep system prompt and tool defs stable** across calls so the cache hits. Vary only the user-facing tail.
2. **Use `@Generable` Swift types** for structured outputs. The framework constrains decoding to your type.
3. **Wrap provider choice** behind the Language Model protocol so the same call site can switch Apple ↔ Claude ↔ Gemini.
4. **Verify with the Evaluations framework** before shipping — see below.

## Core AI framework

OS-level framework for loading, specializing and running custom models on Apple Silicon.

- Automatic hardware specialization, AOT compilation, fast load.
- Fine-grained inference memory control, zero-copy data paths, stateful execution.
- Scales from compact vision models to large generative models.

Docs: `/documentation/coreai/`. Use Core AI when you ship your own model; use Foundation Models when you want a system-provided LLM.

## Evaluations framework

`/documentation/evaluations` — systematic eval pipeline for prompts and intelligence features.

- Define datasets + graders.
- Integrate into CI to catch regressions.
- Hill-climb prompt variants automatically.

Treat evals as a hard requirement for any user-facing Foundation Models feature.

## MLX (WWDC 2026 updates)

- Metal 4 + GPU Neural Accelerator support.
- **Distributed training over Thunderbolt RDMA** across multiple Macs.
- Improved LLM training / fine-tuning.

Use MLX for research / custom model training; ship the resulting model via Core AI.

## Decision tree

```
Need to call an LLM from a Swift app
└── Want Apple-provided intelligence with system integration?  → Foundation Models
└── Need a third-party LLM (Claude/Gemini)?                    → Foundation Models (Language Model protocol)
└── Shipping your own model weights?                           → Core AI
└── Training / fine-tuning custom model?                       → MLX → export → Core AI
Validating any of the above before release                     → Evaluations framework
```
