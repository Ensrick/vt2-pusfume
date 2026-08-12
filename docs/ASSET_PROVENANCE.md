# Asset Provenance

## Pusfume selector preview

| Field | Value |
| --- | --- |
| Runtime path | `pusfume/textures/pusfume/pusfume_model_preview.png` |
| Creator | Janfon / `notfuegonasus` |
| Handoff date | 2026-07-15 |
| Source file | `pusfume-preview-textured.png` from the local Pusfume model handoff |
| SHA-256 | `BBB4AD54F40389F8B1B679291813314432A33FE02E6D1691542640BCCC239506` |
| Permission | Supplied by the creator for the collaborative Pusfume mod repository and Workshop prototype |
| Derived content | Rendered from Janfon's Pusfume model, which combines adapted VT2 Skaven visual assets with original skin base-color and eye work |
| Distribution scope | Transformed UI render only; raw extracted VT2 textures are not committed |

The image remains the source-safe fallback preview. The private native build now replaces it at runtime with a live-confirmed compiled Pusfume unit.

## Private native placeholder

| Field | Value |
| --- | --- |
| Creator | Janfon / `notfuegonasus` with adapted VT2 Skaven source assets |
| Handoff date | 2026-07-15 |
| Repository status | Private/untracked under `.build/pusfume_handoff` |
| Original work | Pusfume skin base color and eyes; integration and atlas reconstruction by the project |
| Derived content | Placeholder mesh, armature, most textures, and game child material binding derive from installed VT2 content |
| Current distribution | Friends-only Workshop development item `3764954245` |
| Public-release status | Not approved; provenance and redistribution review required |

ManifestID `2405082174877027150` is the first live-confirmed native baseline.
It visibly deforms, renders the reconstructed atlas, plays idle/walk, and does
not retain the donor green emissive effect. This technical success does not
change the asset's publication restrictions.
