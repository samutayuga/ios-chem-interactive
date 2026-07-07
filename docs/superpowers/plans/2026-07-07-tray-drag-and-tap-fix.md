# Tray Drag + Reaction Lab Tap Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make element placement work by drag AND tap in both app modes — draggable grid tiles, plus tap-to-place wired into Reaction Lab.

**Architecture:** Two additive, build-gated view changes. Part A adds `.draggable` to the tray tiles (drop targets already exist in both modes). Part B wires tap-to-select-then-tap-zone into Reaction Lab via the shared tray selection.

**Tech Stack:** Swift 5, SwiftUI (iOS 17: `.draggable`), `xcodebuild`.

## Global Constraints

- **Additive only.** No ChemCore change. Bonding-mode logic unchanged (it merely gains drag on grid tiles). Do not alter `DropZoneView`, `CanvasModel`, or the reaction engine.
- **Reuse existing APIs:** `TokenTransfer` (already `Transferable`, proven by `ElementDetailCard.draggable`); `ReactionLabModel.place(_:inZone:)`; `CanvasModel.selectedToken` / `clearSelection()`; `Theme`.
- **Xcode:** file-system-synchronized folders; edits to existing files need no `.pbxproj` changes.
- **App build gate:** `xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -8` → `BUILD SUCCEEDED`. If that simulator is unavailable, pick one from `xcrun simctl list devices available`. SourceKit "No such module" warnings are IDE noise; `xcodebuild` is authoritative.
- **Full app test gate:** `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -12` → all `ChemInteractiveTests` pass (no regressions; currently 89).
- **Commit convention:** end body with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## File Structure

- `ChemInteractive/Views/Tray/ElementTokenView.swift` — **modify**: add `.draggable` + preview.
- `ChemInteractive/Views/Tray/PolyatomicTokenView.swift` — **modify**: add `.draggable` + preview.
- `ChemInteractive/Views/RootModeView.swift` — **modify**: inject `bondingModel` into `ReactionLabView`.
- `ChemInteractive/Views/ReactionLab/ReactantZoneView.swift` — **modify**: tap-to-place + selection highlight.

Two build-gated tasks: draggable tiles → tap-to-place wiring.

---

### Task 1: Draggable grid tiles

**Files:**
- Modify: `ChemInteractive/Views/Tray/ElementTokenView.swift`
- Modify: `ChemInteractive/Views/Tray/PolyatomicTokenView.swift`

**Interfaces:**
- Consumes: existing `token: TokenTransfer` on both views; `Theme`.
- Produces: grid element/polyatomic tiles are draggable with a symbol preview; drop targets already consume `TokenTransfer`.

- [ ] **Step 1: Verify the app builds first (baseline green)**

Run: `xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 2: Add drag to ElementTokenView**

In `ChemInteractive/Views/Tray/ElementTokenView.swift`, change the active (`else`) branch from:

```swift
        } else {
            styled
                .opacity(model.selectedToken != nil && !isSelected ? 0.5 : 1)
                .onTapGesture { onTap(element) }
        }
```

to:

```swift
        } else {
            styled
                .opacity(model.selectedToken != nil && !isSelected ? 0.5 : 1)
                .onTapGesture { onTap(element) }
                .draggable(token) { dragPreview }
        }
```

and add this computed property to the struct (e.g. above `body`):

```swift
    private var dragPreview: some View {
        Text(element.symbol)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(glyphColor)
            .padding(10)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(glyphColor.opacity(0.6), lineWidth: 1))
    }
```

- [ ] **Step 3: Add drag to PolyatomicTokenView**

In `ChemInteractive/Views/Tray/PolyatomicTokenView.swift`, change the active (`else`) branch from:

```swift
        } else {
            styled
                .opacity(model.selectedToken != nil && !isSelected ? 0.5 : 1)
                .onTapGesture { onTap(ion) }
        }
```

to:

```swift
        } else {
            styled
                .opacity(model.selectedToken != nil && !isSelected ? 0.5 : 1)
                .onTapGesture { onTap(ion) }
                .draggable(token) { dragPreview }
        }
```

and add this computed property to the struct (e.g. above `body`):

```swift
    private var dragPreview: some View {
        Text(ion.formula)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .padding(10)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.anion.opacity(0.6), lineWidth: 1))
    }
```

- [ ] **Step 4: Build the app**

Run: `xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/Views/Tray/ElementTokenView.swift ChemInteractive/Views/Tray/PolyatomicTokenView.swift
git commit -m "feat(app): make periodic tray tiles draggable onto zones"
```

---

### Task 2: Tap-to-place in Reaction Lab

**Files:**
- Modify: `ChemInteractive/Views/RootModeView.swift`
- Modify: `ChemInteractive/Views/ReactionLab/ReactantZoneView.swift`

**Interfaces:**
- Consumes: `CanvasModel.selectedToken` / `clearSelection()` (the shared tray model), `ReactionLabModel.place(_:inZone:)`, `Theme`.
- Produces: tapping a Reaction Lab zone places the currently-selected tray token; the zone highlights when a token is selected.

- [ ] **Step 1: Inject the tray model into ReactionLabView**

In `ChemInteractive/Views/RootModeView.swift`, the `.reactionLab` switch arm currently reads:

```swift
                        case .reactionLab:
                            ReactionLabView().environment(reactionModel)
```

Change it to:

```swift
                        case .reactionLab:
                            ReactionLabView()
                                .environment(reactionModel)
                                .environment(bondingModel)
```

- [ ] **Step 2: Wire tap-to-place + highlight into ReactantZoneView**

In `ChemInteractive/Views/ReactionLab/ReactantZoneView.swift`:

(a) Add the tray environment and an invite flag near the existing properties:

```swift
    @Environment(ReactionLabModel.self) private var model
    @Environment(CanvasModel.self) private var tray
```

and, with the other computed properties:

```swift
    private var inviteTap: Bool { tray.selectedToken != nil }
```

(b) Change the background highlight to also light up on invite. Replace:

```swift
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent.opacity(isTargeted ? 0.16 : 0.06)))
```

with:

```swift
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent.opacity(isTargeted || inviteTap ? 0.16 : 0.06)))
```

(c) Add a tap handler to the zone container. Immediately AFTER the `.dropDestination(...) { ... } isTargeted: { isTargeted = $0 }` modifier (i.e. as the next modifier on the same `VStack`), add:

```swift
        .onTapGesture {
            if let token = tray.selectedToken {
                model.place(token, inZone: zone)
                tray.clearSelection()
            }
        }
```

(The inner `×`, quantity, and transition-metal-picker Buttons keep their own taps; this container tap only fires for taps not consumed by a Button.)

- [ ] **Step 3: Build the app**

Run: `xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Run the full app test suite (no regressions)**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -12`
Expected: all `ChemInteractiveTests` pass (currently 89).

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/Views/RootModeView.swift ChemInteractive/Views/ReactionLab/ReactantZoneView.swift
git commit -m "feat(app): tap-to-place reactants in Reaction Lab"
```

---

## Self-Review Notes (addressed)

- **Spec coverage:** draggable tiles both token views (Task 1); tap-to-place + env injection + highlight (Task 2). Both modes gain drag; Reaction Lab gains tap parity.
- **Placeholder scan:** none.
- **Type consistency:** `token`/`dragPreview`, `tray`/`inviteTap`, `model.place(_:inZone:)`, `clearSelection()` all match existing signatures.
- **Additive:** bonding `DropZoneView` untouched; only the four named files change; no ChemCore change.
- **Build-gated:** no new pure logic; placement correctness covered by existing `ReactionLabModelTests`.
