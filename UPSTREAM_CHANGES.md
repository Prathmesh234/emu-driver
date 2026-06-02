# Emu-Driver Upstream Divergence and Fork Operations

Single source of truth for the `emu-driver` fork's upstream relationship,
local-only divergences, sync workflow, and merge cautions.

Fork location from the Emu repo root:

```text
frontend/coworker-mode/emu-driver/
```

Upstream source:

```text
https://github.com/trycua/cua/tree/main/libs/cua-driver
```

---

## Format

```markdown
### N. <Change Title>
**File(s):** Path(s) to modified files
**Status:** LOCAL ONLY | CANDIDATE FOR UPSTREAM | MERGED UPSTREAM
**Priority:** Critical | High | Medium | Low
**Rationale:** Why this change is needed in Emu's context

**Code/Commit:**
- Commit hash (when committed)
- Brief description of change

**Upstream Equivalent:**
- Issue/PR link (if applicable)
- Status of upstream discussion
```

---

## Fork Remotes

Use two remotes in the nested `emu-driver` repo:

| Remote | Purpose |
| --- | --- |
| `origin` | Emu fork, expected to push/fetch `Prathmesh234/emu-driver` |
| `upstream` | Original `trycua/cua`, fetch-only tracking |

Expected remote shape:

```bash
cd frontend/coworker-mode/emu-driver
git remote -v
# origin    https://github.com/Prathmesh234/emu-driver.git (fetch)
# origin    https://github.com/Prathmesh234/emu-driver.git (push)
# upstream  https://github.com/trycua/cua.git (fetch)
```

If `origin` is still temporary or points at upstream, fix it with:

```bash
git remote set-url origin https://github.com/Prathmesh234/emu-driver.git
```

---

## Upstream Sync Workflow

### Check for upstream changes

```bash
cd frontend/coworker-mode/emu-driver
git fetch upstream main --depth=1
git log --oneline HEAD..upstream/main | head -20
```

### Cherry-pick a targeted upstream fix

Prefer this for small bug fixes because it minimizes conflicts:

```bash
git log upstream/main --oneline --all | grep -Ei 'swift|focus|crash|driver' | head -10
git cherry-pick <commit-hash>
```

If conflicts touch branding, daemon paths, TCC identity, install paths, or build
scripts, keep the Emu runtime values documented below.

### Rebase for a major upstream update

Use a sync branch rather than rebasing `main` directly:

```bash
git checkout -b sync/upstream-<short-name>
git rebase upstream/main
# Resolve conflicts manually; keep Emu runtime identity.
git checkout main
git merge sync/upstream-<short-name>
```

After either cherry-pick or rebase:

```bash
swift build -c debug --product emu-cua-driver
scripts/build-app.sh debug
./.build/EmuCuaDriver.app/Contents/MacOS/emu-cua-driver --version
./.build/EmuCuaDriver.app/Contents/MacOS/emu-cua-driver list-tools | grep '^list_apps:'
git push origin main
```

`swift test` should be run when the local Swift toolchain has XCTest available.
In the current local environment it fails before tests run with
`no such module 'XCTest'`.

---

## Push / Release Workflow Notes

The fork is expected to live at:

```text
https://github.com/Prathmesh234/emu-driver
```

Before pushing meaningful fork changes:

1. Review `git status --short` and avoid committing unrelated local changes.
2. Confirm `UPSTREAM_CHANGES.md` documents any new Emu-specific divergence.
3. Run the branding smoke checks from this file.
4. Push with `git push origin main` or open a PR from a topic branch if the repo workflow changes.

Commit messages for fork-only changes should make the intent clear, for example:

```text
driver: brand runtime surfaces for Emu (EMU-SPECIFIC)
```

Use `CANDIDATE FOR UPSTREAM` only when a change is generic enough to propose
back to `trycua/cua`; otherwise mark it `LOCAL ONLY` or `EMU-SPECIFIC`.

---

## Moving the Emu Parent Branch to a New Repo

If this Emu branch is later pushed to a new parent repository, remember that
`frontend/coworker-mode/emu-driver` is still a separate nested driver repo /
submodule-style dependency. The new Emu parent repo stores only the driver path,
URL metadata, and exact driver commit pointer; it does not automatically include
uncommitted driver file changes.

Before moving the Emu branch:

```bash
cd /Applications/Emu
git status --short
git submodule status
git submodule foreach 'git status --short'
```

The safe state is:

1. Emu root changes are committed or intentionally carried.
2. `frontend/coworker-mode/emu-driver` changes are committed inside the nested driver repo.
3. The nested `emu-driver` commit is pushed to its remote.
4. The Emu parent repo has committed the updated driver pointer.

When pushing the Emu branch to a new repo:

```bash
cd /Applications/Emu
git remote add new-origin https://github.com/<owner>/<new-emu-repo>.git
git push new-origin HEAD:main
```

Then test a fresh clone with submodules:

```bash
cd /tmp
git clone --recurse-submodules https://github.com/<owner>/<new-emu-repo>.git
cd <new-emu-repo>
git submodule status
```

### Parent-repo move gotchas

| Gotcha | Why it matters |
| --- | --- |
| Driver commit not pushed | Fresh clones fail because the parent points at a driver commit that only exists locally. |
| `.gitmodules` missing or stale | Git sees a submodule pointer but does not know where to fetch the driver from. |
| Private driver remote | Public parent repos or CI cannot fetch a private `emu-driver` dependency without credentials. |
| CI does not checkout submodules | Builds fail because `frontend/coworker-mode/emu-driver` is empty or stale. |
| Path assumptions | Scripts/docs that assume `/Applications/Emu` may need updates if the new repo uses a different local path. |

If the driver remote URL changes as part of the move, update the parent repo:

```bash
git submodule set-url frontend/coworker-mode/emu-driver https://github.com/<owner>/emu-driver.git
git add .gitmodules frontend/coworker-mode/emu-driver
git commit -m "Update emu-driver submodule URL"
git submodule sync --recursive
git submodule update --init --recursive
```

The key rule is: move/push the Emu parent repo and the `emu-driver` repo
deliberately. The parent should always point to a driver commit that exists on
the configured driver remote.

---

## Log

### 1. Binary and Permission Branding
**File(s):** Package.swift, App/CuaDriver/Info.plist, scripts/*.sh, scripts/build/build-release-notarized.sh, Sources/CuaDriverCLI/*.swift, Sources/CuaDriverServer/*.swift, Sources/CuaDriverCore/Permissions/*.swift, Sources/CuaDriverCore/Config/ConfigStore.swift, Sources/CuaDriverCore/Telemetry/TelemetryClient.swift, Sources/CuaDriverCore/Recording/*.swift
**Status:** LOCAL ONLY
**Priority:** High
**Rationale:** Emu resolves and bundles a separate `emu-cua-driver` binary. The app bundle, CLI, daemon socket, TCC bundle id, permission prompts, and installer outputs must use Emu naming so they do not collide with upstream `cua-driver` installs and so permission prompts say "Emu" for user trust.

**Code/Commit:**
- Completed locally: renamed executable product to `emu-cua-driver` while keeping Swift target/module names (`CuaDriverCore`, `CuaDriverServer`, `CuaDriverCLI`) stable to reduce upstream merge conflicts.
- Completed locally: renamed app/runtime surfaces to `EmuCuaDriver.app`, bundle id `com.emu.cuadriver`, and daemon cache/socket paths under `emu-cua-driver`.
- Completed locally: updated user-visible permission, CLI/server, config/logging, telemetry, and recording strings from `CuaDriver` / `cua-driver` / upstream identities to Emu-specific names.
- Commit hash: pending.

**Upstream Equivalent:**
- None — this is Emu-specific UX

---

## Upstream Pull Caution Checklist

When pulling, rebasing, or cherry-picking from upstream `trycua/cua`, treat the
Phase 1 driver branding changes as local-only fork boundaries. Upstream will
continue to use `cua-driver`, `CuaDriver.app`, and `com.trycua.driver`; Emu must
keep the runtime/user-facing surfaces below on the Emu names to avoid binary,
daemon, TCC, and packaging collisions.

### Keep Swift target/module names stable

Do not rename these unless there is a deliberate, coordinated refactor:

- `CuaDriverCore`
- `CuaDriverServer`
- `CuaDriverCLI`
- `App/CuaDriver/`

Keeping these upstream names is intentional. It reduces merge conflicts because
most upstream source files still import or reference these modules/paths.

### Preserve Emu runtime names

If upstream changes touch any of these files, re-check that the Emu values stay
in place after conflict resolution:

| Surface | Keep Emu value |
| --- | --- |
| Swift executable product | `emu-cua-driver` |
| CLI command name | `emu-cua-driver` |
| App bundle name | `EmuCuaDriver.app` |
| Bundle identifier | `com.emu.cuadriver` |
| Bundle executable | `emu-cua-driver` |
| MCP server name | `emu-cua-driver` |
| Daemon cache directory | `~/Library/Caches/emu-cua-driver` |
| Daemon socket/pid/lock files | `emu-cua-driver.sock`, `emu-cua-driver.pid`, `emu-cua-driver.lock` |
| Local binary symlink | `~/.local/bin/emu-cua-driver` |
| Install target | `/Applications/EmuCuaDriver.app` |
| User config fallback | `~/Library/Application Support/EmuCuaDriver` |
| Telemetry/user data directory | `~/.emu-cua-driver` |

### High-conflict files to review manually

These files are expected to conflict or silently regress branding during upstream
syncs. Review them line-by-line instead of accepting either side wholesale:

- `Package.swift`
- `App/CuaDriver/Info.plist`
- `Sources/CuaDriverCLI/CuaDriverCommand.swift`
- `Sources/CuaDriverCLI/ServeCommand.swift`
- `Sources/CuaDriverCLI/CallCommand.swift`
- `Sources/CuaDriverCLI/DiagnoseCommand.swift`
- `Sources/CuaDriverCLI/RecordingCommand.swift`
- `Sources/CuaDriverServer/CuaDriverMCPServer.swift`
- `Sources/CuaDriverServer/DaemonProtocol.swift`
- `Sources/CuaDriverCore/Config/ConfigStore.swift`
- `Sources/CuaDriverCore/Permissions/PermissionsGate.swift`
- `Sources/CuaDriverCore/Telemetry/TelemetryClient.swift`
- `scripts/build-app.sh`
- `scripts/install-local.sh`
- `scripts/install.sh`
- `scripts/uninstall.sh`
- `scripts/test.sh`
- `scripts/build/build-release-notarized.sh`

### Do not reintroduce upstream daemon paths

The daemon paths are not just cosmetic. If `DaemonPaths` goes back to upstream
names, `emu-cua-driver call ...` can accidentally connect to a running upstream
`cua-driver serve` daemon. Always keep the Emu cache directory and
`emu-cua-driver.sock` / `.pid` / `.lock` filenames.

### Do not reintroduce upstream TCC identity

The bundle identifier must stay `com.emu.cuadriver`. Reverting to
`com.trycua.driver` would mix Emu's Accessibility and Screen Recording prompts
with upstream driver permissions, making local testing and support ambiguous.

### Re-run branding smoke checks after every upstream sync

From `frontend/coworker-mode/emu-driver`:

```bash
swift build -c debug --product emu-cua-driver
scripts/build-app.sh debug
./.build/EmuCuaDriver.app/Contents/MacOS/emu-cua-driver --version
./.build/EmuCuaDriver.app/Contents/MacOS/emu-cua-driver list-tools | grep '^list_apps:'
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' .build/EmuCuaDriver.app/Contents/Info.plist
```

Expected plist identifier:

```text
com.emu.cuadriver
```

Optional MCP identity smoke:

```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"smoke","version":"1.0"}}}\n' \
  | ./.build/EmuCuaDriver.app/Contents/MacOS/emu-cua-driver mcp
```

Expected response includes:

```json
"serverInfo":{"name":"emu-cua-driver"
```

### Useful post-sync grep audit

Run this after resolving conflicts. Matches in comments or upstream skill docs
may be acceptable, but matches in build, install, daemon, TCC, or command paths
should be reviewed carefully:

```bash
rg 'CuaDriver\.app|/Applications/CuaDriver|Contents/MacOS/cua-driver|--product cua-driver|com\.trycua\.driver|~/.cua-driver|cua-driver\.(sock|pid|lock)|Not running inside the cua-driver'
```

---

### 2. Swift App Focus Fixes
**File(s):** Sources/CuaDriverCore/Input/FocusWithoutRaise.swift (planned)
**Status:** CANDIDATE FOR UPSTREAM
**Priority:** High
**Rationale:** Some Swift apps (Apple Calendar, Mail) have delayed window state updates on click. Emu needs reliable backgrounded interaction.

**Code/Commit:**
- TBD (when implemented)
- Expected changes: retry logic, timing adjustments

**Upstream Equivalent:**
- Potential upstream issue (monitor trycua/cua for similar reports)

---

### 3. Element Index Cache Persistence
**File(s):** Sources/CuaDriverServer/ElementCache.swift (planned)
**Status:** EMU-SPECIFIC
**Priority:** Medium
**Rationale:** Emu's session-scoped MCP client maintains element coherence across multiple action calls. Different from cua-driver's per-daemon approach.

**Code/Commit:**
- TBD (when session architecture is implemented)

**Upstream Equivalent:**
- Not applicable (Emu's session model is distinct)

---

### 4. Binary Entitlements (Signing)
**File(s):** .entitlements (when building for notarization)
**Status:** LOCAL ONLY
**Priority:** Medium (deferred to public release — Phase 2)
**Rationale:** Emu's notarized binary may need different entitlements than generic cua-driver

**Code/Commit:**
- TBD (Phase 2: first public DMG release)

**Upstream Equivalent:**
- cua-driver uses ad-hoc signing today; not an upstream concern yet

---

### 5. Upstream Sync to v0.1.6
**File(s):** Many — full driver tree
**Status:** SYNCED FROM UPSTREAM
**Priority:** N/A (sync record)
**Rationale:** Periodic catch-up with `trycua/cua` `libs/cua-driver/` subtree. Pulled 8 substantive commits and the corresponding version bumps so the fork now tracks upstream `v0.1.6` while keeping Emu branding, the Emu-only `TypeTextCharsTool`, and the `UPSTREAM_CHANGES.md` playbook.

**How this sync was performed:** Histories between fork and upstream are disjoint (the fork was bootstrapped from a `libs/cua-driver/` subtree split that flattened paths to repo root, so `git merge-base` returns empty). Plain `git pull upstream main` would re-introduce all of `libs/`. Instead, each commit was applied via `git format-patch <sha> -1 --stdout | sed 's@libs/cua-driver/@@g' | git am --3way`, preserving upstream authorship/messages. The fork main branch was pushed after every applied commit so each step is independently reviewable.

**Commits applied (in order, 1–13):**

| Ord | Upstream SHA | Fork SHA | Type | Summary |
| --- | --- | --- | --- | --- |
| 1 | `4ee4fa61` | `736a2ee5` | NO-OP | #1418 doc gen — already present via fork commit `659c0d97` ("cursor changes" silently imported upstream content) |
| 2 | `ff0a6478` | `5085610c` | NO-OP | #1422 Chrome PID-with-trailing-text fix — byte-identical to upstream-after-#1422 |
| 3 | `dbec648f` | `375bcb35` | NO-OP | v0.1.1 version bump — fork already at v0.1.2 |
| 4 | `e69d1cbc` | `e7a403ac` | NO-OP | #1424 Claude Code compat — already present; only ad-hoc fix was de-duplicating an `install.sh` help block |
| 5 | `91724df9` | `d7e0b538` | NO-OP | v0.1.2 version bump — fork already at v0.1.2 |
| 6 | `8a551a8f` | `cd1427a4` | APPLY  | #1437 NSMenu key equivalents + overlay z-order + focus-steal fixes. Clean cherry-pick, +1032/-68 |
| 7 | `b329c315` | `765d578f` | APPLY  | v0.1.3 bump; `.bumpversion.cfg` Emu `tag_name`/`message` lines preserved |
| 8 | `ab409de7` | `ca50cc9b` | APPLY  | #1438 v2 test harness (`Tests/integration/harness/`, conftest, new fixtures). Removed three stale Emu copies of tests upstream had since rewritten (`test_pixel_click_delivery.py`, `test_double_click_delivery.py`, `test_blender_background.py`). One real conflict in `Tests/integration/driver_client.py` (upstream introduced multi-path binary resolution `.app` → release → debug) — adopted upstream structure, rebranded all paths to `EmuCuaDriver.app` / `emu-cua-driver` |
| 9 | `d422294b` | `fffed629` | APPLY  | v0.1.4 bump |
| 10 | `5b3915f2` | `664c0ff8` | APPLY  | #1452 surface system overlay windows in `list_windows` / `get_window_state`. Clean cherry-pick, +14/-3 |
| 11 | `534304f5` | `ef1e7198` | APPLY  | v0.1.5 bump |
| 12 | `3c069f16` | `0fe33113` | APPLY  | #1477 background-click side-effects detector. Adds `WindowChangeDetector`, wires it into `ClickTool` AX + pixel paths, extends `SystemFocusStealPreventer` wildcard activation handling, adds `test_click_opens_new_window.py`. Clean cherry-pick despite `ClickTool.swift` size, +524/-4 |
| 13 | `31bc4f86` | `81256c3c` | APPLY  | v0.1.6 bump |

**Notes / follow-ups:**
- Three test files previously listed as "fork-only" in pre-sync inventory (`test_pixel_click_delivery.py`, `test_double_click_delivery.py`, `test_blender_background.py`) were identified as stale byte-identical copies of upstream's pre-#1438 versions, not Emu-authored. They were removed by the #1438 cherry-pick.
- New harness files imported in #1438 (`Tests/integration/conftest.py`, `Tests/integration/harness/monitor.py`) and the #1477 test (`Tests/integration/test_click_opens_new_window.py`) still mention `cua-driver` in docstrings and a substring window-name check (`"cua-driver" in str(name).lower()` — functional because `"cua-driver"` is a substring of `"emu-cua-driver"`). These are cosmetic and tracked separately for a follow-up cleanup pass.
- The `FocusMonitorApp` test sentinel still uses bundle id `com.trycua.FocusMonitorApp` (pre-existing fork state — every older fork test references the same value). Test-helper rebranding is out of scope for this sync.
- Post-sync smoke checks all green: `swift build -c debug --product emu-cua-driver` succeeds, `--version` reports `0.1.6`, `list-tools` still wires `type_text_chars` (Emu-only), `scripts/build-app.sh debug` produces `EmuCuaDriver.app` with `CFBundleIdentifier = com.emu.cuadriver`, and the audit grep from the section above finds zero leaks to upstream `cua-driver` / `CuaDriver.app` / `com.trycua.driver` runtime surfaces.

**Upstream Equivalent:**
- Upstream tip at sync time: `trycua/cua` `main` @ `31bc4f86` (v0.1.6).

---

### Sync #2 — v0.1.6 → v0.2.7 (24 commits)

**File(s):** Repository-wide; affects `Sources/CuaDriverCLI/{CuaDriverCommand,ServeCommand,CleanupCommand,DiagnoseCommand}.swift`, `Sources/CuaDriverCLI/Docs/CLIDocExtractor.swift`, `Sources/CuaDriverServer/CuaDriverMCPServer.swift`, `scripts/install.sh`, `scripts/install.ps1`, `scripts/uninstall.sh`, `scripts/build/build-release-notarized.sh`, plus the new files `Sources/CuaDriverCLI/BundleHelpers.swift`, `Sources/CuaDriverCLI/DoctorCommand.swift`, `scripts/_install-rust.sh`, `scripts/_uninstall-rust.sh`.
**Status:** SYNCED FROM UPSTREAM
**Priority:** N/A (sync record)
**Rationale:** Catch-up with `trycua/cua` `libs/cua-driver/` from upstream `v0.1.6` (commit `31bc4f86`) through `v0.2.7` (commit `f8d27d61`). Brings in the SCK macOS 26.4 recovery, MCP→daemon auto-delegation for correct TCC context, a new `doctor` diagnostics command, the `--experimental-rust` opt-in flag (Windows/Linux backend via the Rust port), the focus-handle leak fix, Phase 1+2 install/uninstall script convergence, and assorted bug fixes (#1480 etc., bundle-id app-name resolution, install.ps1 auto-PATH). Emu branding (binary `emu-cua-driver`, bundle `EmuCuaDriver.app`, id `com.emu.cuadriver`, paths under `~/Library/Caches/emu-cua-driver/`, `/Applications/EmuCuaDriver.app`) and the cursor customizations (`AgentCursor.swift`, `AgentCursorView.swift`, `AgentCursorOverlayWindow.swift` — shape, color, glow) are preserved end-to-end. Swift target/module names (`CuaDriverCore`, `CuaDriverServer`, `CuaDriverCLI`) are intentionally left on the upstream identifiers to minimize merge conflicts on future syncs.

**How this sync was performed:** Same disjoint-history pattern as Sync #1. Each commit applied via `git format-patch <sha> -1 --stdout -- libs/cua-driver/ | git am -p3 --3way` (the `-p3` strips the `a/libs/cua-driver/` prefix; `--3way` uses blob IDs from the patch when context lines don't match). After each application, a sentinel-shielded perl rebrand pass (`rebrand.sh`) substituted any newly-added upstream strings — `cua-driver→emu-cua-driver`, `CuaDriver.app→EmuCuaDriver.app`, `com.trycua.{driver,cuadriver}→com.emu.cuadriver`, `Application Support/Cua Driver→Application Support/EmuCuaDriver` — without double-prefixing existing Emu strings (sentinels `\x00ESCD\x00` etc. shield them before substitution). The pass deliberately matches strings only with suffixes (`.app`, `"`, `-`) or word boundaries that don't catch Swift module/type identifiers. After every cherry-pick the commit was amended with the rebrand result so each fork commit is independently reviewable.

**Commits applied (in order, 1–24):**

| Ord | Upstream SHA | Fork SHA | Type | Summary |
| --- | --- | --- | --- | --- |
| 1  | `e8e62910` | `b7872d0a` | APPLY  | #1478 SCK streaming-start failure recovery for macOS 26.4 |
| 2  | `41c6afdf` | `74eb5456` | APPLY+ | #1479 auto-delegate `mcp` to daemon for correct TCC context. Heavy branding rework in `ServeCommand.swift`, `CLIDocExtractor.swift`, `CuaDriverCommand.swift`, `CuaDriverMCPServer.swift`. Introduces new file `Sources/CuaDriverCLI/BundleHelpers.swift` (`isExecutableInsideCuaDriverApp()` rebranded to check `/EmuCuaDriver.app/Contents/MacOS/`) |
| 3  | `91c14b13` | `19fae82d` | APPLY+ | #1490 fixes for #1480 #1482-#1486 #1489. Conflict on CleanupCommand: fork had previously renamed it to commandName "doctor"; upstream introduced a separate new `DoctorCommand.swift` for real diagnostics. Resolution: reverted CleanupCommand → commandName "cleanup" and accepted upstream's new `DoctorCommand.swift` verbatim (one rebranded doc-comment) |
| 4  | `81baebe8` | `1757a72e` | APPLY  | v0.1.7 bump |
| 5  | `b9907ec6` | `73105987` | APPLY  | v0.1.8 bump |
| 6  | `a68f8155` | `16926b90` | APPLY+ | #1494 `CUA_DRIVER_PREBUILT_BINARY` for notarization. Conflict in `scripts/build/build-release-notarized.sh` (kept Emu `BINARY_NAME=emu-cua-driver` + `APP_BUNDLE=EmuCuaDriver.app` while taking the new prebuilt-binary feature) |
| 7  | `041916da` | `ccea16ee` | APPLY  | v0.1.9 bump |
| 8  | `bb680218` | `104dc13b` | APPLY  | #1511 Windows + Linux support via `cua-driver-rs` (Rust port). For our fork only the `install.sh` delta inside `libs/cua-driver/` applied — the Rust port itself is not vendored. Adds the `--experimental-rust` delegation path (dead code in our fork) |
| 9  | `200b36ab` | `104fea25` | APPLY  | #1517 bake version into `install.sh` after each release (CI workflow) |
| 10 | `3b5c372d` | `864b1b57` | APPLY  | #1492 fix #1481 app-name resolution — bundle id + locale fallbacks |
| 11 | `453cf203` | `9cd3fda6` | APPLY  | #1538 `--experimental-rust` flag plumbed all the way through `install.sh` |
| 12 | `ae8fe9ad` | `d85f9c0d` | APPLY  | #1521 kill focus-handle leak class via 4-layer scope binding. Clean cherry-pick despite touching 6 files |
| 13 | `d3f3b932` | `079bdb52` | APPLY  | v0.2.0 bump (`.bumpversion.cfg` 3-way merge — Emu `tag_name`/`message` preserved) |
| 14 | `d7e89b3f` | `8b0ef166` | APPLY  | bake 0.2.0 into `install.sh` |
| 15 | `fe8a570f` | `7e8e3116` | APPLY+ | #1556 install converge to one canonical `.sh`+`.ps1` entry point per platform. One conflict (header comment about Rust delegation target) resolved by accepting upstream + rebrand |
| 16 | `7f46cdca` | `101fcc62` | APPLY+ | #1557 install Phase 2 — single canonical `install.sh`, Rust logic colocated as the private helper `scripts/_install-rust.sh`. Five conflicts resolved by accepting upstream side (the Phase-2 colocated layout) and letting the rebrand pass restore Emu paths |
| 17 | `49c8e2da` | `8bf607d1` | APPLY+ | #1559 upstream renames its Rust port's bundle to `com.trycua.cuadriver` + `/Applications/CuaDriver.app` (in-place Swift takeover semantics). For our fork this is dead code (Rust port not vendored) — accepted upstream side everywhere; rebrand pass produced `com.emu.cuadriver` + `EmuCuaDriver.app` consistently |
| 18 | `571c3ac1` | `c948ff3e` | APPLY+ | #1558 uninstall mirror-convergence — single canonical `uninstall.{sh,ps1}` with `_uninstall-rust.sh` helper. Two conflicts resolved by accepting upstream + manual fixup of `Application Support/Cua Driver` → `Application Support/EmuCuaDriver` (the literal-space variant that the rebrand regex initially didn't match — rebrand.sh subsequently extended to cover it) |
| 19 | `96b27596` | `a7ec1d08` | APPLY  | bake 0.2.4 into `_install-rust.sh` + `install.ps1` |
| 20 | `62655a13` | `4c28fd0e` | APPLY+ | #1566 Rust port Phase 2 panel + structural fixes. Only `_install-rust.sh` lands in our fork (one comment-only conflict on bundle-stub path, accepted upstream) |
| 21 | `764bb192` | `abfb5261` | APPLY  | bake 0.2.5 |
| 22 | `0f834c61` | `c76b4b0e` | APPLY  | bake 0.2.6 |
| 23 | `1f9a6a95` | `32d89f21` | APPLY+ | #1576 `install.ps1` auto-add bin dir to User PATH. Two interleaved conflicts (new `Add-UserPathEntry` function + restructured `if ($onPath) ... elseif ($NoPathUpdate) ...` block) resolved by accepting upstream + rebrand |
| 24 | `f8d27d61` | `79713319` | APPLY  | bake 0.2.7 |

**Notes / follow-ups:**
- The three customized cursor files (`Sources/CuaDriverServer/AgentCursor/AgentCursor.swift`, `AgentCursorView.swift`, `AgentCursorOverlayWindow.swift`) were not in the upstream change set for v0.1.6→v0.2.7, so they passed through every cherry-pick untouched — shape, color, glow preserved.
- `.bumpversion.cfg` is at `0.2.0` (the last upstream `bumpversion` commit in this window). The 0.2.4/0.2.5/0.2.6/0.2.7 picks were "bake version sentinel into install scripts" commits and only updated the Rust-port baked-version sentinels (`CUA_DRIVER_RS_BAKED_VERSION` in `_install-rust.sh`, `$Script:CuaDriverRsBakedVersion` in `install.ps1`). Swift `install.sh`'s `CUA_DRIVER_BAKED_VERSION` stays at `"0.2.0"` — same as upstream.
- The Rust-port install code path (`_install-rust.sh`, `_uninstall-rust.sh`, the `--experimental-rust` flag in `install.sh`/`install.ps1`) is dead code in our fork (we don't vendor `cua-driver-rs`). It's left in place and rebranded for parity with upstream's argv shape, so future Emu-internal Rust experiments can drop a real `emu-cua-driver-rs/` next to the fork without re-deriving the installer plumbing.
- Pre-sync pre-existing branding leaks (not introduced by this sync, left for later): `Sources/CuaDriverCore/Permissions/PermissionsGate.swift:301` literal `Text("All set. CuaDriver is ready to use.")`, and `Sources/CuaDriverServer/ClaudeCodeComputerUseCompatTools.swift:37` literal `"CuaDriver remains window-scoped..."`.
- Swift target/module/type names (`CuaDriverCore`, `CuaDriverServer`, `CuaDriverCLI`, `CuaDriverCommand`, `CuaDriverMCPServer`) intentionally stay on upstream identifiers per the established min-conflict invariant. The `rebrand.sh` regex only matches strings carrying suffixes (`.app`, `"`, `-`) or word boundaries that don't catch Swift identifiers.

**Upstream Equivalent:**
- Upstream tip at sync time: `trycua/cua` `main` @ `f8d27d61` (v0.2.7).

---

### Sync #3 — v0.2.7 → upstream `02fdd98a` (1 substantive Swift commit)

**File(s):** `Sources/CuaDriverCore/Input/SkyLightEventPost.swift`
**Status:** SYNCED FROM UPSTREAM
**Priority:** N/A (sync record)
**Rationale:** Catch-up scan of `trycua/cua` `main` from `f8d27d61` (v0.2.7) through `02fdd98a`. In this window ~121 commits touched `libs/cua-driver/`, but for the surface our fork actually vendors (the Swift driver) there was exactly **one** substantive change worth pulling: the macOS 14 (Sonoma) SkyLight crash guard. Everything else was the `cua-driver-rs` (Rust port) and its version-bake/`install` plumbing — dead code in this fork (we do not vendor the Rust port) — plus the #1674 directory reorg, which we deliberately did **not** adopt (see note below).

**How this sync was performed:** Same disjoint-history pattern as Syncs #1–#2. Upstream restructured the tree in #1674 (`53e6736f`), moving the Swift driver from `libs/cua-driver/` to `libs/cua-driver/swift/`. The one Swift fix was therefore applied with `git format-patch <sha> -1 --stdout -- libs/cua-driver/swift/ | git am -p4 --3way` (`-p4` strips the new `a/libs/cua-driver/swift/` prefix; previous syncs used `-p3` against the pre-reorg layout). The patch touched no branding or cursor strings, so no rebrand pass was required. Authorship/message preserved.

**Commits applied:**

| Ord | Upstream SHA | Fork SHA | Type | Summary |
| --- | --- | --- | --- | --- |
| 1 | `6c31427c` | `fff915f6` | APPLY | #1782 guard `SLSEventAuthenticationMessage messageWithEventRecord:pid:version:` with `messageClass.responds(to:)`. The factory selector only exists on macOS 15 (Sequoia); on macOS 14 `NSSelectorFromString` still interns it, so `objc_msgSend` dispatched an unimplemented selector and aborted the daemon on `hotkey`/`press_key`/`scroll`. Returns `nil` to skip the auth envelope and fall through to plain `SLEventPostToPid`. Clean cherry-pick, +11/-2 |

**Notes / follow-ups:**
- **#1674 directory reorg deliberately NOT adopted.** Upstream collapsed `libs/cua-driver-rs/` and `libs/cua-driver/` into `libs/cua-driver/{rust,swift}/`. This fork is intentionally flattened to repo root; adopting the `swift/` nesting would break `Package.swift`, the `scripts/build-app.sh` output path, and the parent repo's `package.json` `extraResources` pointer (`frontend/coworker-mode/emu-driver/.build/release/emu-cua-driver`) for no runtime benefit. Future Swift-touching upstream patches must be applied with `-p4` (strip `libs/cua-driver/swift/`) instead of the old `-p3`.
- The cursor customization files (`Sources/CuaDriverCore/Cursor/AgentCursor.swift`, `AgentCursorView.swift`, `AgentCursorOverlayWindow.swift`, `AgentCursorRenderer.swift`) were not in this change set — shape, color, glow preserved untouched.
- Emu branding (`emu-cua-driver`, `EmuCuaDriver.app`, `com.emu.cuadriver`, daemon paths) and the Emu-only `TypeTextCharsTool` are untouched by this sync.
- **Build smoke checks were NOT run for this sync** — it was performed in a Linux environment without a Swift/macOS toolchain. The branding/`swift build`/`build-app.sh`/plist-identity smoke checks in the "Re-run branding smoke checks" section above must be run on macOS before release.

**Upstream Equivalent:**
- Upstream tip at sync time: `trycua/cua` `main` @ `02fdd98a`.

---


## Merge Conflict Patterns

### Pattern 1: Permission Strings
**When syncing upstream, keep Emu's variant:**

```
<<<<<<< HEAD (Emu)
"Emu requires Accessibility permission"
=======
"cua-driver requires Accessibility permission"  // upstream
>>>>>>> upstream/main
```

**Resolution:** Keep HEAD (Emu variant)

---

### Pattern 2: Error Messages
**Any user-facing text mentioning the app name:**

```
<<<<<<< HEAD (Emu)
"Emu detected Chromium AX tree is sparse"
=======
"cua-driver detected Chromium AX tree is sparse"  // upstream
>>>>>>> upstream/main
```

**Resolution:** Keep HEAD (Emu variant)

---

## Next Steps (For Implementers)

1. **Before merging from upstream**, review this file.
2. **After local customizations**, add or update a divergence entry above.
3. **Before pushing to the fork**, ensure divergences and validation notes are current.
4. **On upstream bump**, re-check the caution checklist and grep audit.

---

## Resources

- **Upstream:** https://github.com/trycua/cua/tree/main/libs/cua-driver
- **This fork:** frontend/coworker-mode/emu-driver/
