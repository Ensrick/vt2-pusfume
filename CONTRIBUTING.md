# Contributing to Pusfume

Pusfume changes synchronized VT2 career data and can crash every connected peer when registration, assets, or loadouts diverge. Treat every change as production code even while the mod is experimental.

## Required workflow

1. Search the issue tracker before starting work.
2. Open an issue with reproducible behavior, scope, and acceptance criteria when no issue exists.
3. Create a focused branch named `fix/<issue>-<topic>`, `feat/<issue>-<topic>`, `docs/<issue>-<topic>`, or `chore/<issue>-<topic>`.
4. Keep commits reviewable and imperative. Do not mix unrelated refactors, assets, and behavior changes.
5. Run `tools/Test-PusfumeSource.ps1` and an SDK build before requesting review when runtime files change.
6. Open a pull request that links the issue, explains risks, and records exact verification results.
7. Resolve review conversations and pass CI before merging. Do not push directly to `main`.

## Engineering standards

- Prefer a game-owned, source-verified API over guessed runtime behavior.
- Fail safely before profile confirmation; never rely on VT2 crashification as validation.
- Keep network-visible career, item, talent, and package registration deterministic across peers.
- Preserve compatibility with the supported mod set. Document hook ordering and test known overlapping hooks.
- Add a preflight diagnostic for every failure mode that can invalidate spawn or synchronization.
- Keep Lua changes small, readable, and free of hidden global mutation unless the engine API requires it.
- Update documentation and the live-test checklist when behavior or support boundaries change.

## Verification

Runtime pull requests must include:

- Source preflight output.
- SDK build result.
- Mod list and realm used for the in-game test.
- Relevant Pusfume log lines, redacted of account, machine, and network identifiers.
- Host and client results when synchronized data changes.

Do not attach complete console logs or crash dumps to public issues. They can contain Steam IDs, machine IDs, local paths, hardware details, and network information.

## Asset provenance

- Commit only assets the contributor created or is authorized to redistribute.
- Record creator, source, license/permission, and whether the asset incorporates extracted VT2 content.
- Use Git LFS for model and source-texture files covered by `.gitattributes`.
- Do not commit temporary extraction directories, game bundles, crash dumps, or unmodified extracted game assets.
- Keep source art separate from compiled runtime output.
- A raw FBX is not a VT2 runtime unit. A 3D integration is incomplete until its `.bsi`, `.unit`, materials, package entries, and deformation tests pass.

## Release discipline

- Keep the Lua version and Workshop configuration version identical.
- Build from a clean, reviewed commit.
- Publish only after local smoke testing.
- Use a concise Workshop change note that identifies user-facing behavior and compatibility requirements.
- Record the commit and Workshop item ID in the pull request.
