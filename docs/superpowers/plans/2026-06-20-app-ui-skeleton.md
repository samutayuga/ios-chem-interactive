# ChemInteractive — SwiftUI App UI Skeleton Implementation Plan (Plan 2 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the native SwiftUI iPhone app on top of the existing `ChemCore` package — a hand-authored Xcode project, an `@Observable` model wrapping the tested reducer, the theme, tray, drag/drop + tap-select, drop zones, transition-metal picker, and explanation modal — with the three result diagrams **stubbed** so the full phase machine runs end-to-end.

**Architecture:** A single SwiftUI app target `ChemInteractive` (iOS 17, portrait iPhone) that references `ChemCore` as a **local Swift package** and adds **no** chemistry logic. The app is a thin declarative shell: views read `model.state` and dispatch `CanvasAction`s into `ChemCore.canvasReducer`. New app-side code is limited to presentation: an `@Observable` model, a `Transferable` drag payload that resolves back to `ChemCore.ZoneState`, the theme, pure formatting/bond-hint helpers, and SwiftUI views. The three diagrams are placeholder views that surface `ChemCore`-computed stoichiometry / electron counts so `.crossoverComplete → complete` and `.reset` are exercisable. Plan 3 replaces the placeholders with animated `Canvas` diagrams.

**Tech Stack:** Swift 5 language mode, SwiftUI, Observation (`@Observable`), `Transferable`/`.draggable`/`.dropDestination` (iOS 17), XCTest, `xcodebuild`. Local Swift package dependency `ChemCore` (built in Plan 1). No third-party dependencies. No XcodeGen/Tuist — the `project.pbxproj` is hand-authored.

## Global Constraints

- **Deployment target:** iOS 17.0, portrait iPhone only. `@Observable` requires iOS 17.
- **`SWIFT_VERSION = 5.0`** (Swift 5 language mode) for both app and test targets, to avoid Swift 6 strict-concurrency friction in views. `ChemCore`'s public value types are already `Sendable`.
- **No chemistry logic in the app.** All domain/state transitions go through `ChemCore` (`canvasReducer`, `bondingType`, `calcStoich`, `metallicElectronCount`, `iupacFirst`, `gcd`, `ZoneState(element:)`, `ZoneState(polyatomic:)`). New app code is presentation only.
- **`ChemCore` is consumed as-is.** Do not modify the package. If a convenience accessor proves necessary, add it test-first inside `ChemCore` (out of scope for this plan unless forced).
- **Project generation is hand-authored.** No XcodeGen/Tuist/Xcode-GUI generators. The `.xcodeproj` uses Xcode 16 `objectVersion = 70` file-system-synchronized groups so source files are auto-discovered from the folder (no per-file references to maintain).
- **Theme values are exact**, ported verbatim from the reference (`~/Developer/codews/chem-interactive/src/index.css` and `utils/elementColor.ts`): bg `#1a0a2e`, cation `#00ff88`, anion `#ff4080`, accent `#7040ff`, surface `#2a1a4e`, muted `#4a3a6e`, text `#e0d0ff`.
- **Reference app** for layout/behavior fidelity: `~/Developer/codews/chem-interactive/src` (`canvas/IonicCanvas.tsx`, `tray/`, `zones/`, `bridge/`).
- **Verification model:** domain/state logic is already covered by `ChemCore`'s 61 XCTests — do **not** duplicate it. App-side **pure** helpers (model resolution, theme parsing, bond hints, formatting) are unit-tested in a `ChemInteractiveTests` target. SwiftUI **views** are verified by `xcodebuild` compilation (per task) and a simulator **boot + manual smoke** at the final gate.
- Commit after every task. Commit prefixes: `feat:`, `fix:`, `chore:` (no scopes).
- The simulator name used in commands is **iPhone 17**; if unavailable, substitute any booted iPhone simulator from `xcrun simctl list devices available`.

## File Structure

```
ios-chem-interactive/
├── ChemCore/                                  # existing package (Plan 1) — unchanged
├── ChemInteractive.xcodeproj/
│   ├── project.pbxproj                         # hand-authored (Task 1)
│   └── xcshareddata/xcschemes/ChemInteractive.xcscheme
├── ChemInteractive/                            # app target (file-system-synchronized)
│   ├── ChemInteractiveApp.swift                # @main; injects CanvasModel
│   ├── State/CanvasModel.swift                 # @Observable wrapper + TokenTransfer (Task 2)
│   ├── Theme/Theme.swift                        # colors + bondHint (Task 3)
│   ├── Theme/IonFormat.swift                    # pure formatting helpers (Task 4)
│   ├── Views/ChemCanvasView.swift               # root layout (Task 11)
│   ├── Views/Tray/ElementTokenView.swift        # (Task 5)
│   ├── Views/Tray/PolyatomicTokenView.swift     # (Task 5)
│   ├── Views/Tray/ElementTrayView.swift         # (Task 6)
│   ├── Views/Zones/DropZoneView.swift           # (Task 7)
│   ├── Views/Zones/TransitionMetalPickerView.swift  # (Task 8)
│   ├── Views/Bridge/ExplanationModalView.swift  # (Task 9)
│   ├── Views/Bridge/DiagramPlaceholders.swift   # Plan 2 stubs (Task 10)
│   ├── Views/Bridge/BridgeView.swift            # phase router (Task 10)
│   └── Assets.xcassets/                          # AppIcon, AccentColor (Task 1)
└── ChemInteractiveTests/                        # unit tests for pure helpers
    ├── CanvasModelTests.swift                   # (Task 2)
    ├── ThemeTests.swift                         # (Task 3)
    └── IonFormatTests.swift                     # (Task 4)
```

**ChemCore public API consumed by this plan (verbatim signatures, for reference):**
- `CanvasState(canvasPhase:bondingType:slotA:slotB:)`, `CanvasState.initial`, fields `canvasPhase: CanvasPhase`, `bondingType: BondingType?`, `slotA/slotB: ZoneState?`.
- `enum CanvasAction { case dropElement(slot: Slot, zone: ZoneState); case pickTMCharge(slot: Slot, charge: Int); case dismissExplanation; case replaceElement(slot: Slot); case crossoverComplete; case reset }`.
- `func canvasReducer(_ state: CanvasState, _ action: CanvasAction) -> CanvasState`.
- `enum CanvasPhase { selecting, slotAFilled, explaining, animatingCrossover, showingCovalent, showingMetallic, complete }`.
- `enum Slot { a, b; var other: Slot }`.
- `enum ZoneStatus { neutral, deducing, ionized }`.
- `struct ZoneState` fields `symbol, elementClass: ElementClass, isPolyatomic, isTransition, valenceElectrons, oxidationStates: [Int], derivedCharge: Int?, wrongCount, status: ZoneStatus`; inits `ZoneState(element: Element)`, `ZoneState(polyatomic: PolyatomicIon)`.
- `enum BondingType: String { ionic="Ionic", covalent="Covalent", metallic="Metallic" }`, `func bondingType(aClass:bClass:aPolyatomic:bPolyatomic:) -> BondingType`.
- `enum ElementClass: String { metal="Metal", nonMetal="NonMetal", metalloid="Metalloid" }`.
- `enum Category: String { ... nobleGas="NobleGas" ... }`.
- `struct Element` fields incl. `symbol, name, atomicNumber, massNumber, group, period, block: Block, category: Category, elementClass: ElementClass, oxidationStates, electronConfiguration: String`.
- `struct PolyatomicIon { symbol, name, charge: Int, formula }`, `PolyatomicIon.polyatomicIons` (6 ions).
- `struct PeriodicTable { let elements: [Element]; static func load() throws -> PeriodicTable; func bySymbol(_:); func byAtomicNumber(_:) }`.
- `func calcStoich(veA:veB:) -> (nA: Int, nB: Int, bondOrder: Int)`, `func metallicElectronCount(veA:veB:poolSize:) -> Int`, `func iupacFirst(_:_:) -> Bool`, `func gcd(_:_:) -> Int`.

---

### Task 1: Hand-author the Xcode project (app + test targets) wired to ChemCore — build/test/boot gate

**Files:**
- Create: `ChemInteractive.xcodeproj/project.pbxproj`
- Create: `ChemInteractive.xcodeproj/xcshareddata/xcschemes/ChemInteractive.xcscheme`
- Create: `ChemInteractive/ChemInteractiveApp.swift`
- Create: `ChemInteractive/Assets.xcassets/Contents.json`
- Create: `ChemInteractive/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `ChemInteractive/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `ChemInteractiveTests/SmokeTests.swift`

**Interfaces:**
- Consumes: the local `ChemCore` package at relative path `ChemCore`.
- Produces: a buildable scheme `ChemInteractive`; an app that boots to a placeholder screen; a `ChemInteractiveTests` target that links `ChemCore` + `@testable import ChemInteractive` and runs in the simulator. This is the **critical gate** — verify before adding any views.

- [ ] **Step 1: Create the app entry `ChemInteractive/ChemInteractiveApp.swift`** (minimal, replaced in Task 11)

```swift
import SwiftUI

@main
struct ChemInteractiveApp: App {
    var body: some Scene {
        WindowGroup {
            Text("ChemInteractive")
                .font(.largeTitle)
        }
    }
}
```

- [ ] **Step 2: Create `ChemInteractive/Assets.xcassets/Contents.json`**

```json
{
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 3: Create `ChemInteractive/Assets.xcassets/AppIcon.appiconset/Contents.json`**

```json
{
  "images" : [
    { "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 4: Create `ChemInteractive/Assets.xcassets/AccentColor.colorset/Contents.json`**

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "1.000", "green" : "0.251", "red" : "0.439" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 5: Create `ChemInteractive.xcodeproj/project.pbxproj`**

This uses `objectVersion = 70` (Xcode 16) file-system-synchronized root groups, so source files are auto-discovered from the `ChemInteractive/` and `ChemInteractiveTests/` folders — there are no per-file references to maintain. The object IDs are arbitrary 24-char hex constants, unique within the file.

```
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 70;
	objects = {

/* Begin PBXBuildFile section */
		AA0000000000000000001B /* ChemCore in Frameworks */ = {isa = PBXBuildFile; productRef = AA0000000000000000001A /* ChemCore */; };
		AA0000000000000000001F /* ChemCore in Frameworks */ = {isa = PBXBuildFile; productRef = AA0000000000000000001E /* ChemCore */; };
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		AA0000000000000000001D /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = AA00000000000000000001 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = AA00000000000000000004;
			remoteInfo = ChemInteractive;
		};
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
		AA00000000000000000006 /* ChemInteractive.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ChemInteractive.app; sourceTree = BUILT_PRODUCTS_DIR; };
		AA00000000000000000007 /* ChemInteractiveTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = ChemInteractiveTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		AA00000000000000000008 /* ChemInteractive */ = {isa = PBXFileSystemSynchronizedRootGroup; explicitFileTypes = {}; explicitFolders = (); path = ChemInteractive; sourceTree = "<group>"; };
		AA00000000000000000009 /* ChemInteractiveTests */ = {isa = PBXFileSystemSynchronizedRootGroup; explicitFileTypes = {}; explicitFolders = (); path = ChemInteractiveTests; sourceTree = "<group>"; };
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
		AA0000000000000000000B /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				AA0000000000000000001B /* ChemCore in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		AA0000000000000000000E /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				AA0000000000000000001F /* ChemCore in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		AA00000000000000000002 /* mainGroup */ = {
			isa = PBXGroup;
			children = (
				AA00000000000000000008 /* ChemInteractive */,
				AA00000000000000000009 /* ChemInteractiveTests */,
				AA00000000000000000003 /* Products */,
			);
			sourceTree = "<group>";
		};
		AA00000000000000000003 /* Products */ = {
			isa = PBXGroup;
			children = (
				AA00000000000000000006 /* ChemInteractive.app */,
				AA00000000000000000007 /* ChemInteractiveTests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		AA00000000000000000004 /* ChemInteractive */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = AA00000000000000000010 /* Build configuration list for PBXNativeTarget "ChemInteractive" */;
			buildPhases = (
				AA0000000000000000000A /* Sources */,
				AA0000000000000000000B /* Frameworks */,
				AA0000000000000000000C /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				AA00000000000000000008 /* ChemInteractive */,
			);
			name = ChemInteractive;
			packageProductDependencies = (
				AA0000000000000000001A /* ChemCore */,
			);
			productName = ChemInteractive;
			productReference = AA00000000000000000006 /* ChemInteractive.app */;
			productType = "com.apple.product-type.application";
		};
		AA00000000000000000005 /* ChemInteractiveTests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = AA00000000000000000013 /* Build configuration list for PBXNativeTarget "ChemInteractiveTests" */;
			buildPhases = (
				AA0000000000000000000D /* Sources */,
				AA0000000000000000000E /* Frameworks */,
				AA0000000000000000000F /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				AA0000000000000000001C /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				AA00000000000000000009 /* ChemInteractiveTests */,
			);
			name = ChemInteractiveTests;
			packageProductDependencies = (
				AA0000000000000000001E /* ChemCore */,
			);
			productName = ChemInteractiveTests;
			productReference = AA00000000000000000007 /* ChemInteractiveTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		AA00000000000000000001 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
				TargetAttributes = {
					AA00000000000000000004 = { CreatedOnToolsVersion = 16.0; };
					AA00000000000000000005 = { CreatedOnToolsVersion = 16.0; TestTargetID = AA00000000000000000004; };
				};
			};
			buildConfigurationList = AA00000000000000000016 /* Build configuration list for PBXProject "ChemInteractive" */;
			compatibilityVersion = "Xcode 15.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = ( en, Base, );
			mainGroup = AA00000000000000000002;
			packageReferences = (
				AA00000000000000000019 /* XCLocalSwiftPackageReference "ChemCore" */,
			);
			productRefGroup = AA00000000000000000003 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				AA00000000000000000004 /* ChemInteractive */,
				AA00000000000000000005 /* ChemInteractiveTests */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		AA0000000000000000000C /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		AA0000000000000000000F /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		AA0000000000000000000A /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		AA0000000000000000000D /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		AA0000000000000000001C /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = AA00000000000000000004 /* ChemInteractive */;
			targetProxy = AA0000000000000000001D /* PBXContainerItemProxy */;
		};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		AA00000000000000000017 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_NO_COMMON_BLOCKS = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		AA00000000000000000018 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_NO_COMMON_BLOCKS = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_VERSION = 5.0;
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		AA00000000000000000011 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.cheminteractive.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_ENABLE_TESTABILITY = YES;
				TARGETED_DEVICE_FAMILY = 1;
			};
			name = Debug;
		};
		AA00000000000000000012 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.cheminteractive.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_ENABLE_TESTABILITY = YES;
				TARGETED_DEVICE_FAMILY = 1;
			};
			name = Release;
		};
		AA00000000000000000014 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.cheminteractive.app.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				TARGETED_DEVICE_FAMILY = 1;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/ChemInteractive.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/ChemInteractive";
			};
			name = Debug;
		};
		AA00000000000000000015 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.cheminteractive.app.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				TARGETED_DEVICE_FAMILY = 1;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/ChemInteractive.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/ChemInteractive";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		AA00000000000000000010 /* Build configuration list for PBXNativeTarget "ChemInteractive" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AA00000000000000000011 /* Debug */,
				AA00000000000000000012 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		AA00000000000000000013 /* Build configuration list for PBXNativeTarget "ChemInteractiveTests" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AA00000000000000000014 /* Debug */,
				AA00000000000000000015 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		AA00000000000000000016 /* Build configuration list for PBXProject "ChemInteractive" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AA00000000000000000017 /* Debug */,
				AA00000000000000000018 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

/* Begin XCLocalSwiftPackageReference section */
		AA00000000000000000019 /* XCLocalSwiftPackageReference "ChemCore" */ = {
			isa = XCLocalSwiftPackageReference;
			relativePath = ChemCore;
		};
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		AA0000000000000000001A /* ChemCore */ = {
			isa = XCSwiftPackageProductDependency;
			package = AA00000000000000000019 /* XCLocalSwiftPackageReference "ChemCore" */;
			productName = ChemCore;
		};
		AA0000000000000000001E /* ChemCore */ = {
			isa = XCSwiftPackageProductDependency;
			package = AA00000000000000000019 /* XCLocalSwiftPackageReference "ChemCore" */;
			productName = ChemCore;
		};
/* End XCSwiftPackageProductDependency section */
	};
	rootObject = AA00000000000000000001 /* Project object */;
}
```

- [ ] **Step 6: Create the shared scheme `ChemInteractive.xcodeproj/xcshareddata/xcschemes/ChemInteractive.xcscheme`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1600" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "AA00000000000000000004"
               BuildableName = "ChemInteractive.app"
               BlueprintName = "ChemInteractive"
               ReferencedContainer = "container:ChemInteractive.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "AA00000000000000000005"
               BuildableName = "ChemInteractiveTests.xctest"
               BlueprintName = "ChemInteractiveTests"
               ReferencedContainer = "container:ChemInteractive.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "AA00000000000000000004"
            BuildableName = "ChemInteractive.app"
            BlueprintName = "ChemInteractive"
            ReferencedContainer = "container:ChemInteractive.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "AA00000000000000000004"
            BuildableName = "ChemInteractive.app"
            BlueprintName = "ChemInteractive"
            ReferencedContainer = "container:ChemInteractive.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug"></AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"></ArchiveAction>
</Scheme>
```

- [ ] **Step 7: Create the smoke test `ChemInteractiveTests/SmokeTests.swift`**

```swift
import XCTest
import ChemCore
@testable import ChemInteractive

final class SmokeTests: XCTestCase {
    func test_chemCoreIsLinked() throws {
        // ChemCore is reachable from the test target and its bundled data loads.
        let pt = try PeriodicTable.load()
        XCTAssertEqual(pt.elements.count, 118)
    }
}
```

- [ ] **Step 8: Verify the project lists correctly**

Run: `xcodebuild -list -project ChemInteractive.xcodeproj 2>&1 | tail -20`
Expected: lists targets `ChemInteractive`, `ChemInteractiveTests` and scheme `ChemInteractive`.
If this errors with a parse/integrity failure, the `project.pbxproj` has a typo — re-check the object IDs and section closers against Step 5 before proceeding.

- [ ] **Step 9: Build the app (compile gate, no boot)**

Run: `xcodebuild build -scheme ChemInteractive -destination 'generic/platform=iOS Simulator' 2>&1 | tail -25`
Expected: `BUILD SUCCEEDED`. Resolves the `ChemCore` local package and compiles the placeholder app.

- [ ] **Step 10: Run tests in the simulator (boot + test gate)**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30`
Expected: `TEST SUCCEEDED`; `test_chemCoreIsLinked` passes (proves the app target links ChemCore, the test target hosts the app, and bundled element data loads in the simulator).

- [ ] **Step 11: Commit**

```bash
printf 'xcuserdata/\n*.xcuserstate\nDerivedData/\n' > ChemInteractive.xcodeproj/.gitignore
git add ChemInteractive.xcodeproj ChemInteractive ChemInteractiveTests
git commit -m "chore: hand-author ChemInteractive xcode project linking ChemCore"
```

---

### Task 2: CanvasModel — `@Observable` wrapper, drag payload, zone resolution

**Files:**
- Create: `ChemInteractive/State/CanvasModel.swift`
- Test: `ChemInteractiveTests/CanvasModelTests.swift`

**Interfaces:**
- Consumes: `ChemCore` (`PeriodicTable`, `Element`, `PolyatomicIon`, `ZoneState`, `CanvasState`, `CanvasAction`, `canvasReducer`, `Slot`).
- Produces:
  - `struct TokenTransfer: Codable, Transferable, Equatable { let symbol: String; let isPolyatomic: Bool }` with a JSON `transferRepresentation`.
  - `@Observable final class CanvasModel` with: `private(set) var state: CanvasState`; `let elements: [Element]`; `let polyatomicIons: [PolyatomicIon]`; `private(set) var selectedToken: TokenTransfer?`; `init()`; `func send(_:)`; `func zoneState(for: TokenTransfer) -> ZoneState?`; `func select(_:)`; `func clearSelection()`; `func place(_ token: TokenTransfer, in slot: Slot)`.

- [ ] **Step 1: Write the failing test `ChemInteractiveTests/CanvasModelTests.swift`**

```swift
import XCTest
import ChemCore
@testable import ChemInteractive

final class CanvasModelTests: XCTestCase {
    func test_loadsAllElementsAndIons() {
        let model = CanvasModel()
        XCTAssertEqual(model.elements.count, 118)
        XCTAssertEqual(model.polyatomicIons.count, 6)
        XCTAssertEqual(model.state, .initial)
    }

    func test_resolvesElementToken() throws {
        let model = CanvasModel()
        let zone = try XCTUnwrap(model.zoneState(for: TokenTransfer(symbol: "Na", isPolyatomic: false)))
        XCTAssertEqual(zone.symbol, "Na")
        XCTAssertEqual(zone.elementClass, .metal)
        XCTAssertFalse(zone.isPolyatomic)
    }

    func test_resolvesPolyatomicToken() throws {
        let model = CanvasModel()
        let zone = try XCTUnwrap(model.zoneState(for: TokenTransfer(symbol: "OH", isPolyatomic: true)))
        XCTAssertEqual(zone.symbol, "OH")
        XCTAssertTrue(zone.isPolyatomic)
        XCTAssertEqual(zone.oxidationStates, [-1])
    }

    func test_unknownTokenResolvesNil() {
        let model = CanvasModel()
        XCTAssertNil(model.zoneState(for: TokenTransfer(symbol: "Xx", isPolyatomic: false)))
    }

    func test_placeDrivesReducer() {
        let model = CanvasModel()
        model.place(TokenTransfer(symbol: "Na", isPolyatomic: false), in: .a)
        XCTAssertEqual(model.state.canvasPhase, .slotAFilled)
        XCTAssertEqual(model.state.slotA?.symbol, "Na")
    }

    func test_naClGoesIonicAndExplains() {
        let model = CanvasModel()
        model.place(TokenTransfer(symbol: "Na", isPolyatomic: false), in: .a)
        model.place(TokenTransfer(symbol: "Cl", isPolyatomic: false), in: .b)
        XCTAssertEqual(model.state.bondingType, .ionic)
        XCTAssertEqual(model.state.canvasPhase, .explaining)
    }

    func test_selectionToggles() {
        let model = CanvasModel()
        let na = TokenTransfer(symbol: "Na", isPolyatomic: false)
        model.select(na)
        XCTAssertEqual(model.selectedToken, na)
        model.clearSelection()
        XCTAssertNil(model.selectedToken)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ChemInteractiveTests/CanvasModelTests 2>&1 | tail -20`
Expected: FAIL — `CanvasModel` / `TokenTransfer` not found (compile error).

- [ ] **Step 3: Create `ChemInteractive/State/CanvasModel.swift`**

```swift
import Foundation
import Observation
import CoreTransferable
import ChemCore

/// The drag/tap payload. Carries only what is needed to rebuild a `ZoneState`
/// from the model — `ZoneState` construction stays in ChemCore.
struct TokenTransfer: Codable, Transferable, Equatable {
    let symbol: String
    let isPolyatomic: Bool

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

@Observable
final class CanvasModel {
    private(set) var state: CanvasState = .initial
    let elements: [Element]
    let polyatomicIons: [PolyatomicIon] = PolyatomicIon.polyatomicIons
    private(set) var selectedToken: TokenTransfer?

    init() {
        // Bundled resource; a load failure is a developer error, not a user path.
        let pt = try! PeriodicTable.load()
        self.elements = pt.elements
    }

    func send(_ action: CanvasAction) {
        state = canvasReducer(state, action)
    }

    /// Rebuilds the ChemCore `ZoneState` for a dragged/tapped token, or nil if unknown.
    func zoneState(for token: TokenTransfer) -> ZoneState? {
        if token.isPolyatomic {
            guard let ion = polyatomicIons.first(where: { $0.symbol == token.symbol }) else { return nil }
            return ZoneState(polyatomic: ion)
        }
        guard let element = elements.first(where: { $0.symbol == token.symbol }) else { return nil }
        return ZoneState(element: element)
    }

    /// Resolves a token to a zone and dispatches a drop into `slot`; clears any pending selection.
    func place(_ token: TokenTransfer, in slot: Slot) {
        guard let zone = zoneState(for: token) else { return }
        send(.dropElement(slot: slot, zone: zone))
        clearSelection()
    }

    func select(_ token: TokenTransfer) {
        selectedToken = (selectedToken == token) ? nil : token
    }

    func clearSelection() {
        selectedToken = nil
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ChemInteractiveTests/CanvasModelTests 2>&1 | tail -20`
Expected: `TEST SUCCEEDED` (all 7 tests pass).

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/State/CanvasModel.swift ChemInteractiveTests/CanvasModelTests.swift
git commit -m "feat: add observable CanvasModel and drag token payload"
```

---

### Task 3: Theme — exact colors, category/class/orbital palettes, bond hints

**Files:**
- Create: `ChemInteractive/Theme/Theme.swift`
- Test: `ChemInteractiveTests/ThemeTests.swift`

**Interfaces:**
- Consumes: `ChemCore` (`ElementClass`, `Category`).
- Produces:
  - `extension Color { init(hex: UInt32) }` (0xRRGGBB, opaque).
  - `enum Theme` with static `Color` constants: `bg, cation, anion, accent, surface, muted, text`.
  - `func categoryColor(_:) -> Color`, `func elementClassColor(_:) -> Color`, `func orbitalColor(_ subshell: Character) -> Color`.
  - `enum BondHintKind { case ionic, covalent, metallic, none }` with `var tint: Color?`.
  - `func bondHint(firstClass: ElementClass, firstIsPolyatomic: Bool, tokenClass: ElementClass, tokenCategory: ChemCore.Category) -> BondHintKind`.

- [ ] **Step 1: Write the failing test `ChemInteractiveTests/ThemeTests.swift`**

```swift
import XCTest
import SwiftUI
import ChemCore
@testable import ChemInteractive

final class ThemeTests: XCTestCase {
    private func rgb(_ color: Color) -> (r: Int, g: Int, b: Int) {
        let c = UIColor(color).cgColor
        let comps = c.components ?? [0, 0, 0, 1]
        return (Int((comps[0] * 255).rounded()), Int((comps[1] * 255).rounded()), Int((comps[2] * 255).rounded()))
    }

    func test_hexInit() {
        XCTAssertEqual(rgb(Color(hex: 0x1a0a2e)).r, 0x1a)
        XCTAssertEqual(rgb(Color(hex: 0x1a0a2e)).g, 0x0a)
        XCTAssertEqual(rgb(Color(hex: 0x1a0a2e)).b, 0x2e)
    }

    func test_brandColors() {
        XCTAssertEqual(rgb(Theme.cation), (0x00, 0xff, 0x88))
        XCTAssertEqual(rgb(Theme.anion), (0xff, 0x40, 0x80))
        XCTAssertEqual(rgb(Theme.accent), (0x70, 0x40, 0xff))
    }

    func test_categoryAndClassColors() {
        XCTAssertEqual(rgb(categoryColor(.nobleGas)), (0xc8, 0xaa, 0xff))   // lavender
        XCTAssertEqual(rgb(categoryColor(.transitionMetal)), (0xe8, 0xb8, 0x4b))
        XCTAssertEqual(rgb(elementClassColor(.metal)), (0xff, 0xa0, 0x40))
        XCTAssertEqual(rgb(elementClassColor(.nonMetal)), (0x50, 0xd8, 0xf0))
    }

    func test_bondHints() {
        // Noble gas token is always disabled regardless of placed element.
        XCTAssertEqual(bondHint(firstClass: .metal, firstIsPolyatomic: false, tokenClass: .nonMetal, tokenCategory: .nobleGas), .none)
        // Polyatomic placed → everything ionic.
        XCTAssertEqual(bondHint(firstClass: .nonMetal, firstIsPolyatomic: true, tokenClass: .nonMetal, tokenCategory: .halogen), .ionic)
        // Metal + metal → metallic.
        XCTAssertEqual(bondHint(firstClass: .metal, firstIsPolyatomic: false, tokenClass: .metal, tokenCategory: .alkaliMetal), .metallic)
        // Nonmetal + nonmetal → covalent.
        XCTAssertEqual(bondHint(firstClass: .nonMetal, firstIsPolyatomic: false, tokenClass: .nonMetal, tokenCategory: .reactiveNonmetal), .covalent)
        // Metalloid pairs → covalent.
        XCTAssertEqual(bondHint(firstClass: .metalloid, firstIsPolyatomic: false, tokenClass: .nonMetal, tokenCategory: .reactiveNonmetal), .covalent)
        // Metal + nonmetal → ionic.
        XCTAssertEqual(bondHint(firstClass: .metal, firstIsPolyatomic: false, tokenClass: .nonMetal, tokenCategory: .halogen), .ionic)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ChemInteractiveTests/ThemeTests 2>&1 | tail -20`
Expected: FAIL — `Theme` / `categoryColor` / `bondHint` not found.

- [ ] **Step 3: Create `ChemInteractive/Theme/Theme.swift`**

```swift
import SwiftUI
import ChemCore

extension Color {
    /// Opaque color from a 0xRRGGBB literal, in sRGB.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: 1
        )
    }
}

enum Theme {
    static let bg      = Color(hex: 0x1a0a2e)
    static let cation  = Color(hex: 0x00ff88)
    static let anion   = Color(hex: 0xff4080)
    static let accent  = Color(hex: 0x7040ff)
    static let surface = Color(hex: 0x2a1a4e)
    static let muted   = Color(hex: 0x4a3a6e)
    static let text    = Color(hex: 0xe0d0ff)
}

/// Wikipedia-style category palette, calibrated for the dark bg (from elementColor.ts).
func categoryColor(_ category: ChemCore.Category) -> Color {
    switch category {
    case .alkaliMetal:         return Color(hex: 0xff8080)
    case .alkalineEarthMetal:  return Color(hex: 0xffd280)
    case .transitionMetal:     return Color(hex: 0xe8b84b)
    case .postTransitionMetal: return Color(hex: 0x7ec8e8)
    case .metalloid:           return Color(hex: 0xa8d8a8)
    case .reactiveNonmetal:    return Color(hex: 0x80d8e8)
    case .halogen:             return Color(hex: 0xc8e830)
    case .nobleGas:            return Color(hex: 0xc8aaff)
    case .lanthanide, .actinide: return Color(hex: 0xe0d0ff)
    }
}

/// Class color used for the symbol glyph + token border (from elementColor.ts).
func elementClassColor(_ cls: ElementClass) -> Color {
    switch cls {
    case .metal:     return Color(hex: 0xffa040)
    case .nonMetal:  return Color(hex: 0x50d8f0)
    case .metalloid: return Color(hex: 0xa8d8a8)
    }
}

/// Orbital subshell colors for electron-configuration display (from ElementToken.tsx).
func orbitalColor(_ subshell: Character) -> Color {
    switch subshell {
    case "s": return Color(hex: 0x80cfff)
    case "p": return Color(hex: 0x88ff99)
    case "d": return Color(hex: 0xffc060)
    case "f": return Color(hex: 0xff90d0)
    default:  return .white
    }
}

enum BondHintKind {
    case ionic, covalent, metallic, none

    /// Tint applied behind a tray token; nil for `.none` (disabled).
    var tint: Color? {
        switch self {
        case .ionic:    return Color(hex: 0x3b82f6).opacity(0.35)  // blue-500
        case .covalent: return Color(hex: 0x22c55e).opacity(0.35)  // green-500
        case .metallic: return Color(hex: 0xf97316).opacity(0.35)  // orange-500
        case .none:     return nil
        }
    }
}

/// Prospective bond type of `token` against the already-placed `first` element.
/// Ported from ElementTray.tsx `bondHint`.
func bondHint(firstClass: ElementClass, firstIsPolyatomic: Bool,
              tokenClass: ElementClass, tokenCategory: ChemCore.Category) -> BondHintKind {
    if tokenCategory == .nobleGas { return .none }
    if firstIsPolyatomic { return .ionic }
    if firstClass == .metal && tokenClass == .metal { return .metallic }
    if firstClass == .nonMetal && tokenClass == .nonMetal { return .covalent }
    if (firstClass == .metalloid || firstClass == .nonMetal)
        && (tokenClass == .metalloid || tokenClass == .nonMetal) { return .covalent }
    return .ionic
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ChemInteractiveTests/ThemeTests 2>&1 | tail -20`
Expected: `TEST SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/Theme/Theme.swift ChemInteractiveTests/ThemeTests.swift
git commit -m "feat: add theme palette and bond-hint helper"
```

---

### Task 4: IonFormat — superscripts, ion labels, ionic formula, explanation copy

**Files:**
- Create: `ChemInteractive/Theme/IonFormat.swift`
- Test: `ChemInteractiveTests/IonFormatTests.swift`

**Interfaces:**
- Consumes: `ChemCore` (`ZoneState`, `gcd`).
- Produces (all pure):
  - `func superscript(_ n: Int) -> String` (1→"¹" … 7→"⁷", else decimal).
  - `func subscriptGlyphs(_ n: Int) -> String` (Unicode subscript digits ₀–₉).
  - `func formatIon(symbol: String, charge: Int) -> String` (e.g. `"Na⁺"`, `"Mg²⁺"`, `"O²⁻"`).
  - `func electronsNeeded(_ valenceElectrons: Int) -> Int` (`ve == 1 ? 1 : 8 - ve`).
  - `func ionicFormula(cationSymbol: String, cationCharge: Int, anionSymbol: String, anionCharge: Int, anionIsPolyatomic: Bool) -> String` (gcd-reduced subscripts; parenthesises polyatomic anion when its subscript > 1).
  - `func chargeExplanation(_ zone: ZoneState) -> String` (per ExplanationModal.tsx `chargeExplanation`).

- [ ] **Step 1: Write the failing test `ChemInteractiveTests/IonFormatTests.swift`**

```swift
import XCTest
import ChemCore
@testable import ChemInteractive

final class IonFormatTests: XCTestCase {
    func test_superscript() {
        XCTAssertEqual(superscript(1), "¹")
        XCTAssertEqual(superscript(3), "³")
        XCTAssertEqual(superscript(9), "9")
    }

    func test_subscriptGlyphs() {
        XCTAssertEqual(subscriptGlyphs(2), "₂")
        XCTAssertEqual(subscriptGlyphs(10), "₁₀")
    }

    func test_formatIon() {
        XCTAssertEqual(formatIon(symbol: "Na", charge: 1), "Na⁺")
        XCTAssertEqual(formatIon(symbol: "Mg", charge: 2), "Mg²⁺")
        XCTAssertEqual(formatIon(symbol: "Cl", charge: -1), "Cl⁻")
        XCTAssertEqual(formatIon(symbol: "O", charge: -2), "O²⁻")
    }

    func test_electronsNeeded() {
        XCTAssertEqual(electronsNeeded(1), 1)   // H
        XCTAssertEqual(electronsNeeded(6), 2)   // O
        XCTAssertEqual(electronsNeeded(7), 1)   // F/Cl
    }

    func test_ionicFormula() {
        // NaCl: 1+/1- → NaCl
        XCTAssertEqual(ionicFormula(cationSymbol: "Na", cationCharge: 1, anionSymbol: "Cl", anionCharge: -1, anionIsPolyatomic: false), "NaCl")
        // MgCl2: 2+/1- → MgCl₂
        XCTAssertEqual(ionicFormula(cationSymbol: "Mg", cationCharge: 2, anionSymbol: "Cl", anionCharge: -1, anionIsPolyatomic: false), "MgCl₂")
        // Al2O3: 3+/2- → Al₂O₃
        XCTAssertEqual(ionicFormula(cationSymbol: "Al", cationCharge: 3, anionSymbol: "O", anionCharge: -2, anionIsPolyatomic: false), "Al₂O₃")
        // Ca(OH)2: 2+/1- polyatomic → Ca(OH)₂
        XCTAssertEqual(ionicFormula(cationSymbol: "Ca", cationCharge: 2, anionSymbol: "OH", anionCharge: -1, anionIsPolyatomic: true), "Ca(OH)₂")
        // Na with polyatomic subscript 1 → no parens: NaOH
        XCTAssertEqual(ionicFormula(cationSymbol: "Na", cationCharge: 1, anionSymbol: "OH", anionCharge: -1, anionIsPolyatomic: true), "NaOH")
    }

    func test_chargeExplanation_metal() {
        let na = ZoneState(symbol: "Na", elementClass: .metal, isPolyatomic: false, isTransition: false,
                           valenceElectrons: 1, oxidationStates: [1], derivedCharge: 1, status: .ionized)
        XCTAssertEqual(chargeExplanation(na), "Na has 1 valence electron → loses 1e⁻ → Na⁺")
    }

    func test_chargeExplanation_nonmetal() {
        let o = ZoneState(symbol: "O", elementClass: .nonMetal, isPolyatomic: false, isTransition: false,
                          valenceElectrons: 6, oxidationStates: [-2], derivedCharge: -2, status: .ionized)
        XCTAssertEqual(chargeExplanation(o), "O has 6 valence electrons → gains 2e⁻ → O²⁻")
    }

    func test_chargeExplanation_polyatomic() {
        let oh = ZoneState(symbol: "OH", elementClass: .nonMetal, isPolyatomic: true, isTransition: false,
                           valenceElectrons: 0, oxidationStates: [-1], derivedCharge: -1, status: .ionized)
        XCTAssertEqual(chargeExplanation(oh), "OH is a polyatomic ion with a fixed charge of -1")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ChemInteractiveTests/IonFormatTests 2>&1 | tail -20`
Expected: FAIL — `superscript` / `formatIon` / `ionicFormula` / `chargeExplanation` not found.

- [ ] **Step 3: Create `ChemInteractive/Theme/IonFormat.swift`**

```swift
import Foundation
import ChemCore

private let superscriptMap: [Int: String] = [
    1: "¹", 2: "²", 3: "³", 4: "⁴", 5: "⁵", 6: "⁶", 7: "⁷",
]

/// Superscript glyph for 1...7, else the decimal string.
func superscript(_ n: Int) -> String {
    superscriptMap[n] ?? String(n)
}

private let subscriptDigits: [Character: Character] = [
    "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
    "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
]

/// Unicode subscript rendering of a non-negative integer.
func subscriptGlyphs(_ n: Int) -> String {
    String(String(n).map { subscriptDigits[$0] ?? $0 })
}

/// Ion label, e.g. "Na⁺", "Mg²⁺", "Cl⁻", "O²⁻".
func formatIon(symbol: String, charge: Int) -> String {
    let abs = Swift.abs(charge)
    let sign = charge > 0 ? "⁺" : "⁻"
    let sup = abs == 1 ? sign : "\(superscript(abs))\(sign)"
    return "\(symbol)\(sup)"
}

/// Electrons a nonmetal needs to complete its octet (duet for H).
func electronsNeeded(_ valenceElectrons: Int) -> Int {
    valenceElectrons == 1 ? 1 : 8 - valenceElectrons
}

/// gcd-reduced ionic formula. Charges are passed as signed values; magnitudes drive subscripts.
func ionicFormula(cationSymbol: String, cationCharge: Int,
                  anionSymbol: String, anionCharge: Int,
                  anionIsPolyatomic: Bool) -> String {
    let cC = Swift.abs(cationCharge)
    let aC = Swift.abs(anionCharge)
    let g = gcd(cC, aC)
    let cSub = aC / g   // cross over: anion charge → cation subscript
    let aSub = cC / g
    let cationPart = cSub == 1 ? cationSymbol : "\(cationSymbol)\(subscriptGlyphs(cSub))"
    let anionPart: String
    if anionIsPolyatomic && aSub > 1 {
        anionPart = "(\(anionSymbol))\(subscriptGlyphs(aSub))"
    } else {
        anionPart = aSub == 1 ? anionSymbol : "\(anionSymbol)\(subscriptGlyphs(aSub))"
    }
    return "\(cationPart)\(anionPart)"
}

/// Per-ion charge-derivation copy shown in the explanation modal.
func chargeExplanation(_ zone: ZoneState) -> String {
    if zone.isPolyatomic {
        let c = zone.derivedCharge ?? 0
        return "\(zone.symbol) is a polyatomic ion with a fixed charge of \(c > 0 ? "+" : "")\(c)"
    }
    let ve = zone.valenceElectrons
    let plural = ve != 1 ? "s" : ""
    if zone.elementClass == .metal || zone.elementClass == .metalloid {
        let c = zone.derivedCharge ?? 0
        return "\(zone.symbol) has \(ve) valence electron\(plural) → loses \(c)e⁻ → \(formatIon(symbol: zone.symbol, charge: c))"
    }
    let c = Swift.abs(zone.derivedCharge ?? 0)
    return "\(zone.symbol) has \(ve) valence electron\(plural) → gains \(c)e⁻ → \(formatIon(symbol: zone.symbol, charge: -c))"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ChemInteractiveTests/IonFormatTests 2>&1 | tail -20`
Expected: `TEST SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/Theme/IonFormat.swift ChemInteractiveTests/IonFormatTests.swift
git commit -m "feat: add ion formatting and explanation helpers"
```

---

### Task 5: Tray token views — ElementTokenView + PolyatomicTokenView

**Files:**
- Create: `ChemInteractive/Views/Tray/ElementTokenView.swift`
- Create: `ChemInteractive/Views/Tray/PolyatomicTokenView.swift`

**Interfaces:**
- Consumes: `CanvasModel`, `TokenTransfer`, `Theme`, `categoryColor`, `elementClassColor`, `bondHint`, `BondHintKind`; `ChemCore` (`Element`, `PolyatomicIon`).
- Produces:
  - `struct ElementTokenView: View` — props `element: Element`, `hint: BondHintKind?`, `disabled: Bool`; reads `CanvasModel` from the environment. Draggable `TokenTransfer`, tap toggles selection, shows mass/atomic numbers + symbol, applies hint tint + selection ring.
  - `struct PolyatomicTokenView: View` — props `ion: PolyatomicIon`, `disabled: Bool`; draggable + tap-select; shows `ion.formula`.

This task is verified by compilation only (`xcodebuild build`); behavior is exercised at the final boot/smoke gate.

- [ ] **Step 1: Create `ChemInteractive/Views/Tray/ElementTokenView.swift`**

```swift
import SwiftUI
import ChemCore

struct ElementTokenView: View {
    let element: Element
    var hint: BondHintKind?
    var disabled: Bool = false

    @Environment(CanvasModel.self) private var model

    private var token: TokenTransfer { TokenTransfer(symbol: element.symbol, isPolyatomic: false) }
    private var isInactive: Bool { disabled || hint == BondHintKind.none }
    private var isSelected: Bool { model.selectedToken == token }
    private var glyphColor: Color { elementClassColor(element.elementClass) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(element.massNumber)").font(.system(size: 7))
                    Text("\(element.atomicNumber)").font(.system(size: 7))
                }
                .foregroundStyle(Theme.text.opacity(0.65))
                Text(element.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(glyphColor)
            }
        }
        .frame(width: 38, height: 38)
        .background((hint?.tint) ?? Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(glyphColor.opacity(0.4), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(isSelected ? 0.8 : 0), lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .opacity(isInactive ? 0.2 : (model.selectedToken != nil && !isSelected ? 0.5 : 1))
        .draggable(token) { dragPreview }
        .onTapGesture { if !isInactive { model.select(token) } }
        .disabled(isInactive)
        .allowsHitTesting(!isInactive)
    }

    private var dragPreview: some View {
        Text(element.symbol)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(glyphColor)
            .padding(8)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
```

- [ ] **Step 2: Create `ChemInteractive/Views/Tray/PolyatomicTokenView.swift`**

```swift
import SwiftUI
import ChemCore

struct PolyatomicTokenView: View {
    let ion: PolyatomicIon
    var disabled: Bool = false

    @Environment(CanvasModel.self) private var model

    private var token: TokenTransfer { TokenTransfer(symbol: ion.symbol, isPolyatomic: true) }
    private var isSelected: Bool { model.selectedToken == token }

    var body: some View {
        Text(ion.formula)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(height: 64)
            .padding(.horizontal, 12)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.anion.opacity(0.4), lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(isSelected ? 0.8 : 0), lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(disabled ? 0.2 : (model.selectedToken != nil && !isSelected ? 0.5 : 1))
            .draggable(token) {
                Text(ion.formula).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .padding(8).background(Theme.surface).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .onTapGesture { if !disabled { model.select(token) } }
            .disabled(disabled)
            .allowsHitTesting(!disabled)
    }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild build -scheme ChemInteractive -destination 'generic/platform=iOS Simulator' 2>&1 | tail -15`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add ChemInteractive/Views/Tray/ElementTokenView.swift ChemInteractive/Views/Tray/PolyatomicTokenView.swift
git commit -m "feat: add draggable tray token views"
```

---

### Task 6: ElementTrayView — tabbed periodic grid with bond-hint tints

**Files:**
- Create: `ChemInteractive/Views/Tray/ElementTrayView.swift`

**Interfaces:**
- Consumes: `CanvasModel`, `ElementTokenView`, `PolyatomicTokenView`, `Theme`, `bondHint`, `BondHintKind`; `ChemCore` (`Element`, `CanvasPhase`, `ElementClass`, `Category`).
- Produces: `struct ElementTrayView: View` — an 18-column main grid (periods as rows), f-block rows below, "Elements" / "Polyatomic Ions" tabs, a bonding legend after the first drop, and per-token hint tints computed against the single filled slot. Horizontally scrollable. Dragging disabled during `.animatingCrossover`.

Verified by compilation; behavior exercised at the final gate.

- [ ] **Step 1: Create `ChemInteractive/Views/Tray/ElementTrayView.swift`**

```swift
import SwiftUI
import ChemCore

struct ElementTrayView: View {
    @Environment(CanvasModel.self) private var model
    @State private var tab: Tab = .elements

    private enum Tab { case elements, polyatomic }

    private var draggingDisabled: Bool { model.state.canvasPhase == .animatingCrossover }

    // The single filled slot, when exactly one is filled (drives hint tints + legend).
    private var firstSlot: ZoneState? {
        let a = model.state.slotA, b = model.state.slotB
        if a != nil && b != nil { return nil }
        return a ?? b
    }

    private func isFBlock(_ z: Int) -> Bool { (57...71).contains(z) || (89...103).contains(z) }
    private var mainElements: [Element] { model.elements.filter { !isFBlock($0.atomicNumber) } }
    private var lanthanides: [Element] { model.elements.filter { (57...71).contains($0.atomicNumber) }.sorted { $0.atomicNumber < $1.atomicNumber } }
    private var actinides: [Element] { model.elements.filter { (89...103).contains($0.atomicNumber) }.sorted { $0.atomicNumber < $1.atomicNumber } }

    private func hint(for el: Element) -> BondHintKind? {
        guard let first = firstSlot else { return nil }
        return bondHint(firstClass: first.elementClass, firstIsPolyatomic: first.isPolyatomic,
                        tokenClass: el.elementClass, tokenCategory: el.category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ScrollView([.horizontal, .vertical]) {
                if tab == .elements { elementsGrid } else { polyatomicGrid }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface.opacity(0.5))
    }

    private var header: some View {
        HStack(spacing: 8) {
            tabButton("Elements", .elements)
            tabButton("Polyatomic Ions", .polyatomic)
            if firstSlot != nil { legend }
            Spacer()
        }
    }

    private func tabButton(_ title: String, _ value: Tab) -> some View {
        Button(title) { tab = value }
            .font(.system(size: 11))
            .padding(.horizontal, 12).padding(.vertical, 4)
            .foregroundStyle(tab == value ? Theme.accent : Theme.muted)
            .overlay(Capsule().stroke(tab == value ? Theme.accent : Theme.muted.opacity(0.4), lineWidth: 1))
            .background(tab == value ? Theme.accent.opacity(0.2) : .clear, in: Capsule())
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendDot(Color(hex: 0x3b82f6), "Ionic")
            legendDot(Color(hex: 0x22c55e), "Covalent")
            legendDot(Color(hex: 0xf97316), "Metallic")
        }
        .font(.system(size: 9))
        .foregroundStyle(.white.opacity(0.5))
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) { Circle().fill(color.opacity(0.8)).frame(width: 8, height: 8); Text(label) }
    }

    private var elementsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 18 columns × 7 periods. Empty cells where no element occupies (group, period).
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                ForEach(1...7, id: \.self) { period in
                    GridRow {
                        ForEach(1...18, id: \.self) { group in
                            if let el = mainElements.first(where: { $0.group == group && $0.period == period }) {
                                ElementTokenView(element: el, hint: hint(for: el), disabled: draggingDisabled)
                            } else {
                                Color.clear.frame(width: 38, height: 38)
                            }
                        }
                    }
                }
            }
            Divider().overlay(.white.opacity(0.1))
            fBlockRow(lanthanides, label: "6f")
            fBlockRow(actinides, label: "7f")
        }
    }

    private func fBlockRow(_ els: [Element], label: String) -> some View {
        HStack(spacing: 2) {
            Text(label).font(.system(size: 8)).foregroundStyle(.white.opacity(0.3)).frame(width: 16, alignment: .trailing)
            ForEach(els, id: \.atomicNumber) { el in
                ElementTokenView(element: el, hint: hint(for: el), disabled: draggingDisabled)
            }
        }
    }

    private var polyatomicGrid: some View {
        HStack(spacing: 8) {
            ForEach(model.polyatomicIons, id: \.symbol) { ion in
                PolyatomicTokenView(ion: ion, disabled: draggingDisabled)
            }
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -scheme ChemInteractive -destination 'generic/platform=iOS Simulator' 2>&1 | tail -15`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/Tray/ElementTrayView.swift
git commit -m "feat: add periodic tray view with bond-hint tints"
```

---

### Task 7: DropZoneView — drop destination, ionized display, clear button

**Files:**
- Create: `ChemInteractive/Views/Zones/DropZoneView.swift`

**Interfaces:**
- Consumes: `CanvasModel`, `TokenTransfer`, `Theme`, `formatIon`; `ChemCore` (`Slot`, `ZoneState`, `ZoneStatus`, `CanvasPhase`).
- Produces: `struct DropZoneView: View` — props `slot: Slot`. Accepts a `TokenTransfer` drop (via `model.place`), highlights on drop-over, shows the element symbol (neutral) or the ion label (ionized), a pending-selection prompt when empty, and a `×` clear button that dispatches `.replaceElement`. Drops are disabled during `.explaining` / `.animatingCrossover`. Tapping with a pending selection places it.

- [ ] **Step 1: Create `ChemInteractive/Views/Zones/DropZoneView.swift`**

```swift
import SwiftUI
import ChemCore

struct DropZoneView: View {
    let slot: Slot
    @Environment(CanvasModel.self) private var model
    @State private var isTargeted = false

    private var zone: ZoneState? { slot == .a ? model.state.slotA : model.state.slotB }
    private var phase: CanvasPhase { model.state.canvasPhase }
    private var dropDisabled: Bool { phase == .animatingCrossover || phase == .explaining }
    private var showReplace: Bool { zone != nil && phase != .animatingCrossover }
    private var accent: Color { slot == .a ? Theme.cation : Theme.anion }
    private var hasPendingSelection: Bool { model.selectedToken != nil && !dropDisabled }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 12)
                .stroke(accent.opacity(isTargeted || hasPendingSelection ? 1 : 0.4), lineWidth: 2)
                .background(content.padding(8))
                .frame(maxWidth: .infinity, minHeight: 96)

            if showReplace {
                Button {
                    model.send(.replaceElement(slot: slot))
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 20, height: 20)
                        .background(.white.opacity(0.1), in: Circle())
                }
                .padding(8)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if let token = model.selectedToken, !dropDisabled { model.place(token, in: slot) }
        }
        .dropDestination(for: TokenTransfer.self) { items, _ in
            guard !dropDisabled, let token = items.first else { return false }
            model.place(token, in: slot)
            return true
        } isTargeted: { isTargeted = $0 }
    }

    @ViewBuilder private var content: some View {
        if let zone {
            if zone.status == .ionized, let charge = zone.derivedCharge {
                Text(formatIon(symbol: zone.symbol, charge: charge))
                    .font(.system(size: 30, weight: .bold)).foregroundStyle(accent)
            } else {
                Text(zone.symbol)
                    .font(.system(size: 24, weight: .bold)).foregroundStyle(accent)
            }
        } else {
            Text(hasPendingSelection ? "Tap to place \(model.selectedToken!.symbol)" : "Drop here")
                .font(.system(size: 13)).foregroundStyle(accent.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -scheme ChemInteractive -destination 'generic/platform=iOS Simulator' 2>&1 | tail -15`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/Zones/DropZoneView.swift
git commit -m "feat: add drop zone view with drag-drop and clear"
```

---

### Task 8: TransitionMetalPickerView — charge picker for DEDUCING slots

**Files:**
- Create: `ChemInteractive/Views/Zones/TransitionMetalPickerView.swift`

**Interfaces:**
- Consumes: `superscript`, `Theme`; `ChemCore` (`ZoneState`).
- Produces: `struct TransitionMetalPickerView: View` — props `zone: ZoneState`, `onPick: (Int) -> Void`. Renders a button per positive oxidation state, labelled `"<symbol><superscript>+"`; tapping calls `onPick(charge)`.

- [ ] **Step 1: Create `ChemInteractive/Views/Zones/TransitionMetalPickerView.swift`**

```swift
import SwiftUI
import ChemCore

struct TransitionMetalPickerView: View {
    let zone: ZoneState
    let onPick: (Int) -> Void

    private var positiveStates: [Int] { zone.oxidationStates.filter { $0 > 0 } }

    var body: some View {
        VStack(spacing: 12) {
            Text("Transition metal — pick its charge:")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: 0xfde047))
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                ForEach(positiveStates, id: \.self) { charge in
                    Button {
                        onPick(charge)
                    } label: {
                        Text("\(zone.symbol)\(superscript(charge))+")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: 0xfde047))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: 0xeab308).opacity(0.6), lineWidth: 1))
                    }
                }
            }
        }
        .padding(12)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -scheme ChemInteractive -destination 'generic/platform=iOS Simulator' 2>&1 | tail -15`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/Zones/TransitionMetalPickerView.swift
git commit -m "feat: add transition-metal charge picker view"
```

---

### Task 9: ExplanationModalView — bond explanation with TM picker + Apply

**Files:**
- Create: `ChemInteractive/Views/Bridge/ExplanationModalView.swift`

**Interfaces:**
- Consumes: `CanvasModel`, `TransitionMetalPickerView`, `chargeExplanation`, `electronsNeeded`, `ionicFormula`, `Theme`; `ChemCore` (`ZoneState`, `ZoneStatus`, `BondingType`, `Slot`).
- Produces: `struct ExplanationModalView: View` — full-screen overlay shown during `.explaining`. For Ionic it shows a per-slot panel (TM picker when `.deducing`, else `chargeExplanation`) plus a crossover summary; for Covalent/Metallic it shows the sharing/electron-sea summary. The "Apply →" button dispatches `.dismissExplanation`, disabled for Ionic while either slot is `.deducing`.

- [ ] **Step 1: Create `ChemInteractive/Views/Bridge/ExplanationModalView.swift`**

```swift
import SwiftUI
import ChemCore

struct ExplanationModalView: View {
    @Environment(CanvasModel.self) private var model

    private var slotA: ZoneState? { model.state.slotA }
    private var slotB: ZoneState? { model.state.slotB }
    private var bonding: BondingType? { model.state.bondingType }

    // Cation/anion ordering — prefer derivedCharge, else Metal/Metalloid is the cation.
    private func ionicPair(_ a: ZoneState, _ b: ZoneState) -> (cation: ZoneState, anion: ZoneState) {
        if let ca = a.derivedCharge, let cb = b.derivedCharge, ca != 0 || cb != 0 {
            return ca > 0 ? (a, b) : (b, a)
        }
        let aCation = a.elementClass == .metal || a.elementClass == .metalloid
        return aCation ? (a, b) : (b, a)
    }

    private var applyEnabled: Bool {
        guard bonding == .ionic else { return true }
        return slotA?.status != .deducing && slotB?.status != .deducing
    }

    var body: some View {
        if model.state.canvasPhase == .explaining, let a = slotA, let b = slotB, let bonding {
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 16) {
                    Text(label(bonding))
                        .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)

                    if bonding == .ionic {
                        VStack(spacing: 8) {
                            slotPanel(a, slot: .a)
                            slotPanel(b, slot: .b)
                        }
                    }

                    Divider().overlay(Theme.muted.opacity(0.2))
                    summary(bonding, a, b).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Button {
                        model.send(.dismissExplanation)
                    } label: {
                        Text("Apply →").font(.system(size: 14, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .foregroundStyle(applyEnabled ? Theme.accent : .white.opacity(0.3))
                    .background((applyEnabled ? Theme.accent.opacity(0.3) : .white.opacity(0.05)), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(applyEnabled ? Theme.accent : .white.opacity(0.1), lineWidth: 1))
                    .disabled(!applyEnabled)
                }
                .padding(20)
                .frame(maxWidth: 420)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.muted.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 12)
            }
        }
    }

    private func label(_ b: BondingType) -> String {
        switch b { case .ionic: "Ionic Bonding"; case .covalent: "Covalent Bonding"; case .metallic: "Metallic Bonding" }
    }

    @ViewBuilder private func slotPanel(_ zone: ZoneState, slot: Slot) -> some View {
        Group {
            if zone.status == .deducing {
                TransitionMetalPickerView(zone: zone) { charge in model.send(.pickTMCharge(slot: slot, charge: charge)) }
            } else if zone.status == .neutral {
                Text("\(zone.symbol) — charge to be determined").font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
            } else {
                Text(chargeExplanation(zone)).font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private func summary(_ bonding: BondingType, _ a: ZoneState, _ b: ZoneState) -> some View {
        switch bonding {
        case .ionic:
            let pair = ionicPair(a, b)
            if pair.cation.status == .ionized, pair.anion.status == .ionized,
               let cc = pair.cation.derivedCharge, let ac = pair.anion.derivedCharge {
                Text("Crossover method: each charge becomes the other ion's subscript → ")
                    + Text(ionicFormula(cationSymbol: pair.cation.symbol, cationCharge: cc,
                                        anionSymbol: pair.anion.symbol, anionCharge: ac,
                                        anionIsPolyatomic: pair.anion.isPolyatomic))
                        .fontWeight(.bold).foregroundColor(.white)
            } else {
                EmptyView()
            }
        case .covalent:
            let aN = electronsNeeded(a.valenceElectrons), bN = electronsNeeded(b.valenceElectrons)
            Text("\(a.symbol) needs \(aN) more electron\(aN != 1 ? "s" : "") and \(b.symbol) needs \(bN) electron\(bN != 1 ? "s" : "") — they share electrons to complete their octets.")
        case .metallic:
            if a.symbol == b.symbol {
                Text("Each \(a.symbol) atom contributes \(a.valenceElectrons) valence electron\(a.valenceElectrons != 1 ? "s" : "") to a delocalised electron sea. The positive metal ions are held in a lattice by electrostatic attraction to the sea of electrons.")
            } else {
                Text("Each \(a.symbol) atom contributes \(a.valenceElectrons) electron\(a.valenceElectrons != 1 ? "s" : "") and each \(b.symbol) atom contributes \(b.valenceElectrons) electron\(b.valenceElectrons != 1 ? "s" : ""). The positive metal ions are held in a lattice by electrostatic attraction to the sea of electrons.")
            }
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -scheme ChemInteractive -destination 'generic/platform=iOS Simulator' 2>&1 | tail -15`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/Bridge/ExplanationModalView.swift
git commit -m "feat: add bond explanation modal view"
```

---

### Task 10: DiagramPlaceholders + BridgeView router

**Files:**
- Create: `ChemInteractive/Views/Bridge/DiagramPlaceholders.swift`
- Create: `ChemInteractive/Views/Bridge/BridgeView.swift`

**Interfaces:**
- Consumes: `CanvasModel`, `ExplanationModalView`, `ionicFormula`, `Theme`; `ChemCore` (`ZoneState`, `CanvasPhase`, `BondingType`, `calcStoich`, `metallicElectronCount`, `iupacFirst`).
- Produces:
  - `struct IonicCompletePlaceholder/CovalentPlaceholder/MetallicPlaceholder: View` — labelled boxes naming the bond type and showing the `ChemCore`-computed formula / stoichiometry / electron count, each with a Reset button (dispatches `.reset`).
  - `struct BridgeView: View` — switches on `state.canvasPhase`: shows the `⇌` glyph and the `ExplanationModalView` overlay during `.explaining`; an animating-crossover placeholder that auto-fires `.crossoverComplete`; and the three result placeholders for `.complete` (ionic) / `.showingCovalent` / `.showingMetallic`. Plan 3 replaces the placeholders.

- [ ] **Step 1: Create `ChemInteractive/Views/Bridge/DiagramPlaceholders.swift`**

```swift
import SwiftUI
import ChemCore

/// Cation/anion ordering shared by the placeholders.
private func ionicPair(_ a: ZoneState, _ b: ZoneState) -> (cation: ZoneState, anion: ZoneState) {
    if let ca = a.derivedCharge, let cb = b.derivedCharge, ca != 0 || cb != 0 {
        return ca > 0 ? (a, b) : (b, a)
    }
    let aCation = a.elementClass == .metal || a.elementClass == .metalloid
    return aCation ? (a, b) : (b, a)
}

private struct ResetButton: View {
    let action: () -> Void
    var body: some View {
        Button("Reset", action: action)
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .overlay(Capsule().stroke(Theme.muted.opacity(0.6), lineWidth: 1))
    }
}

struct IonicCompletePlaceholder: View {
    let slotA: ZoneState
    let slotB: ZoneState
    let onReset: () -> Void

    var body: some View {
        let pair = ionicPair(slotA, slotB)
        VStack(spacing: 12) {
            Text("Ionic compound").font(.system(size: 11)).foregroundStyle(Theme.muted)
            if let cc = pair.cation.derivedCharge, let ac = pair.anion.derivedCharge {
                Text(ionicFormula(cationSymbol: pair.cation.symbol, cationCharge: cc,
                                  anionSymbol: pair.anion.symbol, anionCharge: ac,
                                  anionIsPolyatomic: pair.anion.isPolyatomic))
                    .font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
            }
            Text("[ Lewis transfer diagram — Plan 3 ]").font(.system(size: 10)).foregroundStyle(Theme.muted.opacity(0.7))
            ResetButton(action: onReset)
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.muted.opacity(0.4), lineWidth: 1))
    }
}

struct CovalentPlaceholder: View {
    let slotA: ZoneState
    let slotB: ZoneState
    let onReset: () -> Void

    var body: some View {
        // Reuse ChemCore stoichiometry; order symbols by IUPAC convention.
        let aFirst = iupacFirst(slotA.symbol, slotB.symbol)
        let first = aFirst ? slotA : slotB
        let second = aFirst ? slotB : slotA
        let s = calcStoich(veA: first.valenceElectrons, veB: second.valenceElectrons)
        VStack(spacing: 12) {
            Text("Covalent molecule").font(.system(size: 11)).foregroundStyle(Theme.muted)
            Text("\(first.symbol)\(s.nA > 1 ? subscriptGlyphs(s.nA) : "")\(second.symbol)\(s.nB > 1 ? subscriptGlyphs(s.nB) : "")")
                .font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
            Text("bond order \(s.bondOrder)").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            Text("[ Lewis structure — Plan 3 ]").font(.system(size: 10)).foregroundStyle(Theme.muted.opacity(0.7))
            ResetButton(action: onReset)
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.muted.opacity(0.4), lineWidth: 1))
    }
}

struct MetallicPlaceholder: View {
    let slotA: ZoneState
    let slotB: ZoneState
    let onReset: () -> Void

    var body: some View {
        let electrons = metallicElectronCount(veA: slotA.valenceElectrons, veB: slotB.valenceElectrons)
        VStack(spacing: 12) {
            Text("Metallic lattice").font(.system(size: 11)).foregroundStyle(Theme.muted)
            Text(slotA.symbol == slotB.symbol ? slotA.symbol : "\(slotA.symbol)–\(slotB.symbol)")
                .font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
            Text("\(electrons) delocalised electrons").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            Text("[ Electron-sea animation — Plan 3 ]").font(.system(size: 10)).foregroundStyle(Theme.muted.opacity(0.7))
            ResetButton(action: onReset)
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.muted.opacity(0.4), lineWidth: 1))
    }
}
```

- [ ] **Step 2: Create `ChemInteractive/Views/Bridge/BridgeView.swift`**

```swift
import SwiftUI
import ChemCore

struct BridgeView: View {
    @Environment(CanvasModel.self) private var model

    private var state: CanvasState { model.state }

    var body: some View {
        VStack(spacing: 16) {
            Text("⇌").font(.system(size: 28)).foregroundStyle(Theme.accent.opacity(0.6))

            switch state.canvasPhase {
            case .animatingCrossover:
                // Plan 2 stub: immediately advance the phase machine. Plan 3 animates here.
                ProgressView()
                    .tint(Theme.accent)
                    .onAppear { model.send(.crossoverComplete) }

            case .complete:
                if let a = state.slotA, let b = state.slotB {
                    IonicCompletePlaceholder(slotA: a, slotB: b) { model.send(.reset) }
                }

            case .showingCovalent:
                if let a = state.slotA, let b = state.slotB {
                    CovalentPlaceholder(slotA: a, slotB: b) { model.send(.reset) }
                }

            case .showingMetallic:
                if let a = state.slotA, let b = state.slotB {
                    MetallicPlaceholder(slotA: a, slotB: b) { model.send(.reset) }
                }

            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild build -scheme ChemInteractive -destination 'generic/platform=iOS Simulator' 2>&1 | tail -15`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add ChemInteractive/Views/Bridge/DiagramPlaceholders.swift ChemInteractive/Views/Bridge/BridgeView.swift
git commit -m "feat: add bridge router and result diagram placeholders"
```

---

### Task 11: ChemCanvasView root layout + wire the app — final boot/smoke gate

**Files:**
- Create: `ChemInteractive/Views/ChemCanvasView.swift`
- Modify: `ChemInteractive/ChemInteractiveApp.swift`

**Interfaces:**
- Consumes: `CanvasModel`, `ElementTrayView`, `DropZoneView`, `BridgeView`, `ExplanationModalView`, `Theme`; `ChemCore` (`Slot`).
- Produces: `struct ChemCanvasView: View` — tray on top (~45% height), workspace below (Slot A | Bridge | Slot B), the explanation modal overlaid full-screen. `ChemInteractiveApp` injects a `CanvasModel` into the environment.

- [ ] **Step 1: Create `ChemInteractive/Views/ChemCanvasView.swift`**

```swift
import SwiftUI
import ChemCore

struct ChemCanvasView: View {
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ElementTrayView()
                    .frame(height: geo.size.height * 0.45)

                ScrollView {
                    HStack(alignment: .top, spacing: 8) {
                        DropZoneView(slot: .a).frame(maxWidth: .infinity)
                        BridgeView().frame(maxWidth: .infinity)
                        DropZoneView(slot: .b).frame(maxWidth: .infinity)
                    }
                    .padding(12)
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .overlay { ExplanationModalView() }
    }
}
```

- [ ] **Step 2: Replace `ChemInteractive/ChemInteractiveApp.swift`**

```swift
import SwiftUI

@main
struct ChemInteractiveApp: App {
    @State private var model = CanvasModel()

    var body: some Scene {
        WindowGroup {
            ChemCanvasView()
                .environment(model)
                .preferredColorScheme(.dark)
        }
    }
}
```

- [ ] **Step 3: Build, then boot the app in the simulator (final gate)**

Run:
```bash
xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -15
xcrun simctl boot "iPhone 17" 2>/dev/null; sleep 1
APP=$(find ~/Library/Developer/Xcode/DerivedData -name ChemInteractive.app -path '*Debug-iphonesimulator*' | head -1)
xcrun simctl install "iPhone 17" "$APP"
xcrun simctl launch "iPhone 17" com.cheminteractive.app
```
Expected: `BUILD SUCCEEDED`; the app installs and launches without crashing (the launch command prints a PID).

- [ ] **Step 4: Run the full test suite once more (regression gate)**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -15`
Expected: `TEST SUCCEEDED` — all `ChemInteractiveTests` (Smoke, CanvasModel, Theme, IonFormat) pass.

- [ ] **Step 5: Manual smoke (document the result in the commit body)**

In the booted simulator, verify each path:
1. Drag **Na** to Slot A, then **Cl** to Slot B → Ionic explanation modal appears → tap **Apply →** → crossover spinner → ionic placeholder shows **NaCl** → **Reset** clears both slots.
2. Drag **Fe** to Slot A, **Cl** to Slot B → Ionic modal shows the **transition-metal picker**; Apply is disabled until a charge is picked; pick a charge → Apply enabled → completes.
3. Tray bond-hint tints appear after the first drop; **noble gas** tokens are faded/disabled.
4. Drop **O** + **O** → Covalent placeholder (bond order). Drop **Na** + **Mg** → Metallic placeholder (delocalised electron count).
5. With both slots filled, dropping a third token resets the other slot and restarts.
6. Tap-to-select parity: tap a token (white ring), then tap a drop zone → token places.

- [ ] **Step 6: Commit**

```bash
git add ChemInteractive/Views/ChemCanvasView.swift ChemInteractive/ChemInteractiveApp.swift
git commit -m "feat: wire root canvas layout and app entry point"
```

---

## Self-Review

**Spec coverage** (against `2026-06-20-chem-interactive-app-ui-design.md`):
- §3 project layout / hand-authored pbxproj / local ChemCore package / iOS 17 portrait → Task 1. ✅
- §4 `@Observable` model wrapping `canvasReducer`, exposing elements + ions, building `ZoneState` via ChemCore inits → Task 2. ✅
- §5 root layout → Task 11; tray (18-col grid, f-block, tabs, hint tints, legend, noble-gas disable) → Tasks 3 (hint) + 6; tokens (`.draggable` + tap-select, tooltip surface) → Task 5; drop zones (`.dropDestination`, clear via `.replaceElement`) → Task 7; TM picker (`.pickTMCharge`) → Task 8; explanation modal (per-bond copy, Apply blocked while DEDUCING) → Task 9; bridge router with placeholders exercising `.crossoverComplete`/`.complete`/`.reset` → Task 10. ✅
- §5 theme (exact colors, 8 categories, bond-hint tints, orbital colors) → Task 3. ✅
- §6 Plan 3 (animated diagrams) → explicitly stubbed (Task 10), out of scope. ✅
- §7 verification (no duplicate domain tests; build/boot gate; manual smoke) → Tasks 1 & 11; pure helpers unit-tested → Tasks 2–4. ✅

**Placeholder scan:** every step contains complete file content or exact commands; the only "placeholders" are the intentional Plan-2 diagram **stub views** (Task 10), which the spec mandates. No TBD/TODO/"add error handling".

**Type consistency:** `TokenTransfer(symbol:isPolyatomic:)`, `BondHintKind` (with `.none`/`.tint`), `bondHint(firstClass:firstIsPolyatomic:tokenClass:tokenCategory:)`, `ionicFormula(cationSymbol:cationCharge:anionSymbol:anionCharge:anionIsPolyatomic:)`, `chargeExplanation(_:)`, `model.place(_:in:)`, `model.send(_:)`, `model.zoneState(for:)` are defined once (Tasks 2–4) and used with identical signatures in Tasks 5–11. ChemCore symbols match the verbatim API block. The `BondHintKind.none` case is referenced as `BondHintKind.none` where Swift could confuse it with `Optional.none` (Task 5).

**Note on the pbxproj (Task 1):** hand-authored project files are the known-fiddly risk (spec §8). The file-system-synchronized-group approach removes per-file references (the usual breakage source). Task 1's Steps 8–10 gate the project before any view is added — if `xcodebuild -list` or `build` fails, fix the pbxproj there, not later.
</content>
</invoke>
