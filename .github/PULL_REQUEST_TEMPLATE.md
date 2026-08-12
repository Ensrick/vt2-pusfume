## Summary

Describe the user-visible outcome and implementation approach.

Closes #

## Risk

- Network or registration impact:
- Hook or mod compatibility impact:
- Asset/package impact:
- Rollback plan:

## Verification

- [ ] `tools/Test-PusfumeSource.ps1` passes.
- [ ] `py -3.13 -m unittest discover -s tests -v` passes.
- [ ] VT2 SDK build passes, or this is documentation-only.
- [ ] Tested on Modded Realm in the Adventure Keep, or this is documentation-only.
- [ ] Relevant logs are summarized and identifiers are redacted.
- [ ] Multiplayer synchronization was tested when network-visible data changed.

## Quality

- [ ] The change is linked to an issue with acceptance criteria.
- [ ] Tests or preflight diagnostics cover the failure mode.
- [ ] Documentation and live-test steps are updated.
- [ ] `CHANGELOG.md` is updated, or this change has no release-note impact.
- [ ] New assets include provenance and redistribution permission.
- [ ] No generated bundles, extracted game assets, logs, dumps, or secrets are committed.
