# tfx Documentation

Project documentation is written in English by default. `README.ja.md` is the Japanese README.

## Documents

| Document | Purpose |
| --- | --- |
| [`README.md`](../README.md) | User-facing overview, features, shortcuts, launch commands, and build commands. |
| [`README.ja.md`](../README.ja.md) | Japanese user-facing overview. Keep this aligned with `README.md`. |
| [`CHANGELOG.md`](../CHANGELOG.md) | Release history and version changes. |
| [`docs/detailed-design.md`](detailed-design.md) | Current architecture, state model, file operations, persistence, limitations, and test focus. |
| [`docs/code-organization.md`](code-organization.md) | Source layout, naming rules, and placement rules for Swift files. |
| [`docs/file-manager-implementation-plan.md`](file-manager-implementation-plan.md) | Implementation history and phase status for the file manager feature set. |
| [`docs/development-roadmap.md`](development-roadmap.md) | Planned future work, especially configuration and extension features. |

## Maintenance Rules

- Update `README.md` and `README.ja.md` together when user-facing behavior changes.
- Update `docs/detailed-design.md` when the current architecture or behavior changes.
- Update `docs/file-manager-implementation-plan.md` when a planned phase changes status.
- Update `docs/development-roadmap.md` when future work is completed, removed, or reprioritized.
- Update `CHANGELOG.md` for version changes and notable user-facing changes.
