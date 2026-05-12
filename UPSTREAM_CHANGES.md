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
