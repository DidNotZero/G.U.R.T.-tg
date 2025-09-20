# AGENTS.md — Guidance for Codex CLI in this repository

> This repository is the G.U.R.T downstream fork of /tg/station for the SPLURT server. Our current north star is the **Human AI Crew Foundations** initiative described in `docs/ai_crew_spec.md`. Treat that spec as the source of truth for the new AI systems, TGUI panels, and supporting services.

---

## 1) Project overview

**Name:** G.U.R.T / SPLURT-tg fork
**Goal:** Maintain the SPLURT flavor of /tg/station while delivering the Human AI Crew features (movement, perception, dialogue gateway, admin tooling) outlined in `docs/ai_crew_spec.md`.
**Primary languages:** DreamMaker DM, TypeScript/TSX (TGUI via Bun/Rspack), Rust (rust-g), Python (tooling), Lua (DreamLuaU helpers).
**Core services/packages:**
* `code/` core DM game logic plus modular overrides in `modular_zubbers/`, `modular_skyrat/`, `modular_zzplurt/`, and `goon/`.
* `tgui/` Bun workspace for Inferno/React-based UIs compiled into `tgui/public/`.
* `tools/build/` Bun+Juke build system orchestrating DM, TGUI, icon cutter, and DreamDaemon launch.
* `lua/`, `bin/`, `rust_g.dll` for embedded subsystems.

**High-level architecture (short):**
* `code/modules/ai/**` → consumes perception signals, navigation data, and spec-driven templates → interacts with DM subsystems (pathfinding, radio, outfits).
* `tgui/packages/**` → bundled via Bun/Rspack → assets served by DreamDaemon for admin consoles and editors.
* Gateway (external, llama.cpp) ←→ BYOND `world.Export()` polling bridge defined in DM (`docs/ai_crew_spec.md` §5.2).

**Non-goals:**
* Do not hand-edit compiled artifacts (`tgstation.dmb`, `tgstation.rsc`, `rust_g.dll`, icon caches).
* Avoid touching upstream automation (`tools/tgs_*`, CI hooks) unless explicitly tasked.
* Leave legacy map files, SQL schema, and security policy docs untouched without approval.

---

## 2) Setup steps (local dev)

> Prefer these exact steps when bootstrapping or fixing the workspace.

**System prerequisites**
* BYOND 516.1659 (matches `dependencies.sh`). Install the client and DreamMaker/DreamDaemon.
* Python 3.9.x with pip for mapmerge, changelog, and helper scripts (`tools/requirements.txt`).
* Node.js 22.11.0 and Bun 1.2.16 (Linux/macOS install manually; Windows build script venders them).

> Note: BYOND tooling is Windows-only; plan to run DreamMaker/DreamDaemon from a Windows host or
> the approved VM image rather than the Linux container used for docs and reviews.

## 4) Repository layout & priorities

> Touch the DM modules and TGUI apps that align with the current spec; ignore generated artifacts.

* `code/` — canonical DM gameplay; new AI controllers live under `code/modules/ai/crew_human/` (create if absent).
* `modular_zubbers/`, `modular_skyrat/`, `modular_zzplurt/`, `goon/` — downstream overrides. Prefer adding AI features here when they are SPLURT-specific.
* `_maps/` — game maps; must run mapmerge scripts after editing.
* `tgui/` — Bun workspace (`packages/` for components, `public/` for build output).
* `docs/ai_crew_spec.md` — foundations spec; update alongside implementation decisions.
* `tools/` — build, CI, mapmerge, hooks; do not modify unless coordinating with maintainers.
* `config/`, `SQL/`, `sound/`, `html/` — runtime assets; avoid changes unless asked.

**Do not modify**
* `tgstation.dmb`, `tgstation.rsc`, `rust_g.dll`, `dreamluau.dll` (generated binaries).
* `node_modules/`, `.venv/`, `bin/`, `bubber_archive/`, `tgui/public/*` output.
* License files, third-party submodules, vendored dependencies.

---

## 5) Coding conventions

> Follow /tg/station style with SPLURT-specific extensions; keep AI Crew code auditable.

* Prefer additive implementations; changing existing code is undesirable unless the spec explicitly requires a targeted edit.

**DreamMaker (DM)**
* Stick to tab indentation, `snake_case` procs/vars, and `/datum`-driven architecture.
* Use `///` doc comments for new procs/datums, especially AI controller entry points and blackboard accessors.
* Register signals instead of polling whenever possible; align key names with the spec’s `bb_keys.dm` table.
* Gate experimental features behind defines (e.g., `#define CREW_AI_FOUNDATION 1`) so they can be toggled during rollout.
* Log via `log_subsystem("ai_crew", ...)` for anything spec-related; avoid `world.log <<`.

**TypeScript (TGUI)**
* Functional components with hooks, typed props via `InfernoFunctionalComponent<Props>`.
* Run `bun run tgui:lint` before committing; keep Biome clean (printWidth 100, semi required).
* Store admin tooling under `tgui/packages/tgui/interfaces/` mirroring the spec names (TemplateEditor, ZoneEditor, CrewConsole).

**Python & tooling**
* Keep helper scripts compatible with Python 3.9; respect existing logging.
* When extending build/test scripts, ensure they work cross-platform (Windows + Linux runners).

**Docs**
* Update `docs/ai_crew_spec.md` when architecture or scope shifts; add ADR-style notes to `docs/` rather than scattering comments in code.
* Keep `docs/project_map.md` current by recording every new or modified code/documentation asset, its purpose, and key relationships to other modules.

## 7) Safety & change control

* Never delete large swaths of upstream DM unless the spec mandates it; prefer additive datums/modules.
* Treat `config/` and `SQL/` as production-facing — do not expose secrets or modify live credentials.
* Avoid `rm -rf` outside the workspace, `sudo`, or commands that touch user data.
* When tweaking tick usage or backpressure logic, test under load locally before shipping.
* Do not execute `tools/build/build.sh` or related build scripts in this environment unless the user
  explicitly requests it (automation is handled on Windows hosts).

## 9) Observability & quality gates

* Maintain the `ai_crew` logging channel described in the spec; keep logs actionable.
* Add unit-style tests (DreamDaemon clean run assertions, Bun component tests) when new logic is introduced.
* Ensure admin tooling surfaces debug info (queued requests, navgraph state) for live supportability.

---

## 11) Tasks this agent is allowed to do

* Implement AI Crew foundations per `docs/ai_crew_spec.md` (controller, blackboard, navigation, speech bridge, admin TGUI panels).
* Refactor or extend DM datums/components to support AI perception, so long as behavior remains compatible with live gameplay.
* Extend TGUI admin tooling, add logging/metrics, and write targeted unit tests.
* Update documentation and ADRs tied to the AI initiative.

**Not allowed without explicit request**
* Rewriting the entire job/department automation pipeline (future scope, not v1).
* Schema changes to SQL, configuration rewrites, or CI pipeline overhauls.
* Touching unrelated gameplay systems (antags, events, balance) during AI work.

---

## 12) Examples the agent can follow

1. **Add AI Crew navigation helpers**
   * Create `code/modules/ai/crew_human/navigator.dm` with path requests using `CanAStarPass()`.
   * Store zone graph state on the AI blackboard and write smoke tests via `./tools/build/build.sh test`.
2. **Implement Template Editor TGUI**
   * Add `tgui/packages/tgui/interfaces/AITemplateEditor.tsx` matching the spec’s fields.
   * Wire it through a DM datum (`/datum/admin_screen/ai_template`) and document usage in `docs/ai_crew_spec.md`.
3. **Wire speech gateway polling**
   * Introduce non-blocking request state to `/datum/ai_controller/crew_human`.
   * Add `ai_crew` log lines for enqueue/poll results and ensure clean-run logs stay green.

---

## 13) Triaging instructions for Codex

When proposing a plan:
1. Summarize the AI Crew goal and the files you will touch (DM, TGUI, docs).
2. List the commands you intend to run (`bun run tgui:lint`, mapmerge, etc.) and skip `build.sh`
   invocations unless the user signs off.
3. Provide diff previews before applying large DM or TS changes.
4. Run the relevant builds/tests and report results inline.
5. Keep commits minimal and reference the spec section you addressed.

---

## 14) Modular editing notes

* Prefer adding SPLURT-specific overrides under `modular_zubbers/` or `modular_zzplurt/` instead of editing upstream `code/` when feasible.
* Keep AI Crew shared logic in `code/modules/ai/crew_human/`; downstream flavor tweaks can live in modular folders.
* When touching goon-derived systems, confirm compatibility with SPLURT’s toolchain.

---

## 15) Versioning and release

* Keep changelog entries under `html/changelogs/*.yml` aligned with gameplay-facing changes; mirror the existing YAML format.
* Release builds: `./tools/build/build.sh` then package `tgstation.dmb`/`tgstation.rsc` for deployment.
* Tag releases only after DreamDaemon clean run, TGUI bundle, and changelog updates are verified.

---

## 16) Contacts & ownership

* **Product owner:** See `docs/ai_crew_spec.md` §0 for the current owner/contact; update that file when the point of contact changes.
* **Maintainers:** Coordinate with G.U.R.T devs in the SPLURT Discord (`#ai-crew` channel) before landing large AI features.
* **Security contact:** Reach out to the SPLURT admin team via their standard escalation channel (Discord ticket).

---

## 17) One-liner reminder for Codex

> “Implement AI Crew foundations safely: follow `docs/ai_crew_spec.md` and keep changes small,.”
