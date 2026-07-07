# tfx Documentation

Project documentation is written in English by default. `README.ja.md` is the Japanese README.

## User-Facing Documents

| Document | Purpose |
| --- | --- |
| [`README.md`](../README.md) | User-facing overview, features, shortcuts, launch commands, and build commands. |
| [`README.ja.md`](../README.ja.md) | Japanese user-facing overview. Keep this aligned with `README.md`. |
| [`docs/configuration.md`](configuration.md) | User-editable configuration file location, supported keys, examples, and error handling. |
| [`docs/configuration.ja.md`](configuration.ja.md) | Japanese version of the configuration guide. Keep this aligned with `docs/configuration.md`. |
| [`docs/color-theme-samples.ja.md`](color-theme-samples.ja.md) | Japanese color theme sample collection for `config.toml`, including dark, light, classical, and modern palettes. |
| [`CHANGELOG.md`](../CHANGELOG.md) | Release history and version changes. |

## Engineering Documents

| Document | Purpose |
| --- | --- |
| [`docs/detailed-design.md`](detailed-design.md) | Current architecture, state model, file operations, persistence, limitations, and test focus. |
| [`docs/code-organization.md`](code-organization.md) | Source layout, naming rules, and placement rules for Swift files. |
| [`docs/file-manager-implementation-plan.md`](file-manager-implementation-plan.md) | Implementation history and phase status for the file manager feature set. |
| [`docs/pane-layout-refactor-plan.md`](pane-layout-refactor-plan.md) | Planned pane-layout behavior and phased refactor plan for non-resizing pane toggles and temporary file-list split resizing. |
| [`docs/development-roadmap.md`](development-roadmap.md) | Planned future work, prioritized in recommended execution order. |
| [`docs/contributing.md`](contributing.md) | Local build and test commands, CI expectations, code-style conventions, and release-process notes. |

## Maintenance Rules

- Update `README.md` and `README.ja.md` together when user-facing behavior changes.
- Update `docs/configuration.md` and `docs/configuration.ja.md` when user-editable configuration keys, file locations, defaults, or validation rules change.
- Update `docs/detailed-design.md` when the current architecture or behavior changes.
- Update `docs/file-manager-implementation-plan.md` when a planned phase changes status.
- Update `docs/pane-layout-refactor-plan.md` while the pane-layout refactor is being planned or implemented.
- Update `docs/development-roadmap.md` when future work is completed, removed, or reprioritized.
- Update `docs/contributing.md` when build, test, CI, or release procedures change.
- Update `CHANGELOG.md` for version changes and notable user-facing changes.
- Keep top-level README project-structure sections focused on source and support layout; keep detailed documentation references here.
