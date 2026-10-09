#!/usr/bin/env python3
from __future__ import annotations

import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROJECT = "HomeHub"
BUNDLE_ID = "com.jstnhbbs.app"
DEVELOPMENT_TEAM = "25TTL3SG99"
# The version shown to people (0.1 for the first TestFlight build) and the build number, which must go
# up with every upload to App Store Connect. Both targets read these, and both Info.plists point at
# them, so this is the only place to change.
MARKETING_VERSION = "0.1"
BUILD_NUMBER = "1"
EXTENSION = "HomeHubLiveActivity"
EXTENSION_BUNDLE_ID = f"{BUNDLE_ID}.liveactivity"
# Compiled into both the app and the extension.
SHARED_WITH_EXTENSION = ("HomeHub/Utilities/SleepActivityAttributes.swift",)
APP_ICON_NAME = "Beacon"
ALTERNATE_APP_ICON_NAMES = (
    "BeaconOcean",
    "BeaconClay",
    "BeaconPlum",
    "BeaconSlate",
    "BeaconRosewood",
    "BeaconTeal",
    "BeaconIndigo",
    "BeaconRose",
    "BeaconOchre",
)
ICON_COMPOSER_NAMES = (APP_ICON_NAME, *ALTERNATE_APP_ICON_NAMES)


def uid(key: str) -> str:
    # The same name always gets the same ID, so regenerating the project leaves the file unchanged
    # (a random ID per run rewrote every line) and an Xcode scheme saved in xcshareddata keeps
    # pointing at the right target instead of silently breaking archives.
    return uuid.uuid5(uuid.NAMESPACE_URL, f"homehub-xcode-project:{key}").hex[:24].upper()


swift_files = sorted((ROOT / PROJECT).rglob("*.swift"))
file_refs = {path: uid(f"file_ref:{path}") for path in swift_files}
build_files = {path: uid(f"build_file:{path}") for path in swift_files}

extension_swift_files = sorted((ROOT / EXTENSION).glob("*.swift"))
extension_refs = {path: uid(f"extension_ref:{path}") for path in extension_swift_files}
extension_own_builds = {path: uid(f"extension_own_build:{path}") for path in extension_swift_files}
shared_paths = [ROOT / name for name in SHARED_WITH_EXTENSION]
extension_shared_builds = {path: uid(f"extension_shared_build:{path}") for path in shared_paths}
ext_target_uid = uid("ext_target_uid")
ext_sources_phase = uid("ext_sources_phase")
ext_frameworks_phase = uid("ext_frameworks_phase")
ext_resources_phase = uid("ext_resources_phase")
ext_product_ref = uid("ext_product_ref")
ext_group = uid("ext_group")
ext_info_ref = uid("ext_info_ref")
ext_config_list = uid("ext_config_list")
ext_debug = uid("ext_debug")
ext_release = uid("ext_release")
embed_phase = uid("embed_phase")
embed_build = uid("embed_build")
ext_proxy = uid("ext_proxy")
ext_dependency = uid("ext_dependency")

project_uid = uid("project_uid")
target_uid = uid("target_uid")
sources_phase = uid("sources_phase")
resources_phase = uid("resources_phase")
frameworks_phase = uid("frameworks_phase")
product_ref = uid("product_ref")
main_group = uid("main_group")
products_group = uid("products_group")
app_group = uid("app_group")
project_config_list = uid("project_config_list")
target_config_list = uid("target_config_list")
debug_config = uid("debug_config")
release_config = uid("release_config")
target_debug = uid("target_debug")
target_release = uid("target_release")
info_ref = uid("info_ref")
entitlements_ref = uid("entitlements_ref")
assets_ref = uid("assets_ref")
assets_build = uid("assets_build")
privacy_manifest_ref = uid("privacy_manifest_ref")
privacy_manifest_build = uid("privacy_manifest_build")
icon_refs = {name: uid(f"icon_ref:{name}") for name in ICON_COMPOSER_NAMES}
icon_builds = {name: uid(f"icon_build:{name}") for name in ICON_COMPOSER_NAMES}

lines = [
    "// !$*UTF8*$!",
    "{",
    "\tarchiveVersion = 1;",
    "\tclasses = {};",
    "\tobjectVersion = 56;",
    "\tobjects = {",
]

for path, ref in file_refs.items():
    lines.append(
        f'\t\t{ref} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = {path.name}; path = {path.relative_to(ROOT).as_posix()}; sourceTree = SOURCE_ROOT; }};'
    )

for path, ref in extension_refs.items():
    lines.append(
        f'\t\t{ref} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = {path.name}; path = {path.relative_to(ROOT).as_posix()}; sourceTree = SOURCE_ROOT; }};'
    )
lines.extend(
    [
        f'\t\t{ext_info_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = {EXTENSION}/Info.plist; sourceTree = SOURCE_ROOT; }};',
        f'\t\t{ext_product_ref} /* {EXTENSION}.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = {EXTENSION}.appex; sourceTree = BUILT_PRODUCTS_DIR; }};',
        f'\t\t{info_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = {PROJECT}/Info.plist; sourceTree = SOURCE_ROOT; }};',
        f'\t\t{entitlements_ref} /* {PROJECT}.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = {PROJECT}/{PROJECT}.entitlements; sourceTree = SOURCE_ROOT; }};',
        f'\t\t{assets_ref} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = {PROJECT}/Assets.xcassets; sourceTree = SOURCE_ROOT; }};',
        f'\t\t{privacy_manifest_ref} /* PrivacyInfo.xcprivacy */ = {{isa = PBXFileReference; lastKnownFileType = text.xml; path = {PROJECT}/PrivacyInfo.xcprivacy; sourceTree = SOURCE_ROOT; }};',
        f'\t\t{product_ref} /* {PROJECT}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {PROJECT}.app; sourceTree = BUILT_PRODUCTS_DIR; }};',
    ]
)
for name in ICON_COMPOSER_NAMES:
    lines.append(
        f'\t\t{icon_refs[name]} /* {name}.icon */ = {{isa = PBXFileReference; lastKnownFileType = folder.iconcomposer.icon; path = {name}.icon; sourceTree = SOURCE_ROOT; }};'
    )

for path, ref in build_files.items():
    lines.append(
        f'\t\t{ref} /* {path.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[path]} /* {path.name} */; }};'
    )
for path, ref in extension_own_builds.items():
    lines.append(
        f'\t\t{ref} /* {path.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {extension_refs[path]} /* {path.name} */; }};'
    )
for path, ref in extension_shared_builds.items():
    lines.append(
        f'\t\t{ref} /* {path.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[path]} /* {path.name} */; }};'
    )
lines.append(
    f'\t\t{embed_build} /* {EXTENSION}.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {ext_product_ref} /* {EXTENSION}.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};'
)
lines.append(
    f'\t\t{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_ref} /* Assets.xcassets */; }};'
)
lines.append(
    f'\t\t{privacy_manifest_build} /* PrivacyInfo.xcprivacy in Resources */ = {{isa = PBXBuildFile; fileRef = {privacy_manifest_ref} /* PrivacyInfo.xcprivacy */; }};'
)
for name in ICON_COMPOSER_NAMES:
    lines.append(
        f'\t\t{icon_builds[name]} /* {name}.icon in Resources */ = {{isa = PBXBuildFile; fileRef = {icon_refs[name]} /* {name}.icon */; }};'
    )

swift_ref_list = ", ".join(f"{file_refs[p]} /* {p.name} */" for p in swift_files)
build_ref_list = ", ".join(f"{build_files[p]} /* {p.name} in Sources */" for p in swift_files)
icon_ref_list = ", ".join(
    f"{icon_refs[name]} /* {name}.icon */" for name in ICON_COMPOSER_NAMES
)
icon_build_list = ", ".join(
    f"{icon_builds[name]} /* {name}.icon in Resources */" for name in ICON_COMPOSER_NAMES
)
alternate_icon_names = ", ".join(ALTERNATE_APP_ICON_NAMES)
ext_swift_ref_list = ", ".join(f"{extension_refs[p]} /* {p.name} */" for p in extension_swift_files)
ext_build_ref_list = ", ".join(
    [f"{extension_own_builds[p]} /* {p.name} in Sources */" for p in extension_swift_files]
    + [f"{extension_shared_builds[p]} /* {p.name} in Sources */" for p in shared_paths]
)

lines.extend(
    [
        f'\t\t{products_group} /* Products */ = {{isa = PBXGroup; children = ({product_ref} /* {PROJECT}.app */, {ext_product_ref} /* {EXTENSION}.appex */); name = Products; sourceTree = "<group>"; }};',
        f'\t\t{app_group} /* {PROJECT} */ = {{isa = PBXGroup; children = ({swift_ref_list}, {info_ref} /* Info.plist */, {entitlements_ref} /* {PROJECT}.entitlements */, {assets_ref} /* Assets.xcassets */, {privacy_manifest_ref} /* PrivacyInfo.xcprivacy */); name = {PROJECT}; sourceTree = "<group>"; }};',
        f'\t\t{ext_group} /* {EXTENSION} */ = {{isa = PBXGroup; children = ({ext_swift_ref_list}, {ext_info_ref} /* Info.plist */); name = {EXTENSION}; sourceTree = "<group>"; }};',
        f'\t\t{main_group} = {{isa = PBXGroup; children = ({app_group} /* {PROJECT} */, {ext_group} /* {EXTENSION} */, {icon_ref_list}, {products_group} /* Products */); sourceTree = "<group>"; }};',
        f'\t\t{frameworks_phase} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};',
        f'\t\t{sources_phase} /* Sources */ = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({build_ref_list}); runOnlyForDeploymentPostprocessing = 0; }};',
        f'\t\t{resources_phase} /* Resources */ = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({assets_build} /* Assets.xcassets in Resources */, {privacy_manifest_build} /* PrivacyInfo.xcprivacy in Resources */, {icon_build_list}); runOnlyForDeploymentPostprocessing = 0; }};',
        f'\t\t{ext_frameworks_phase} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};',
        f'\t\t{ext_sources_phase} /* Sources */ = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({ext_build_ref_list}); runOnlyForDeploymentPostprocessing = 0; }};',
        f'\t\t{ext_resources_phase} /* Resources */ = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};',
        f'\t\t{embed_phase} /* Embed Foundation Extensions */ = {{isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = ({embed_build} /* {EXTENSION}.appex in Embed Foundation Extensions */); name = "Embed Foundation Extensions"; runOnlyForDeploymentPostprocessing = 0; }};',
        f'\t\t{ext_proxy} /* PBXContainerItemProxy */ = {{isa = PBXContainerItemProxy; containerPortal = {project_uid} /* Project object */; proxyType = 1; remoteGlobalIDString = {ext_target_uid}; remoteInfo = {EXTENSION}; }};',
        f'\t\t{ext_dependency} /* PBXTargetDependency */ = {{isa = PBXTargetDependency; target = {ext_target_uid} /* {EXTENSION} */; targetProxy = {ext_proxy} /* PBXContainerItemProxy */; }};',
        f'\t\t{ext_target_uid} /* {EXTENSION} */ = {{isa = PBXNativeTarget; buildConfigurationList = {ext_config_list}; buildPhases = ({ext_sources_phase} /* Sources */, {ext_frameworks_phase} /* Frameworks */, {ext_resources_phase} /* Resources */); buildRules = (); dependencies = (); name = {EXTENSION}; productName = {EXTENSION}; productReference = {ext_product_ref}; productType = "com.apple.product-type.app-extension"; }};',
        f'\t\t{target_uid} /* {PROJECT} */ = {{isa = PBXNativeTarget; buildConfigurationList = {target_config_list}; buildPhases = ({sources_phase} /* Sources */, {frameworks_phase} /* Frameworks */, {resources_phase} /* Resources */, {embed_phase} /* Embed Foundation Extensions */); buildRules = (); dependencies = ({ext_dependency} /* PBXTargetDependency */); name = {PROJECT}; productName = {PROJECT}; productReference = {product_ref}; productType = "com.apple.product-type.application"; }};',
        f'\t\t{project_uid} /* Project object */ = {{isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = 1; LastUpgradeCheck = 1600;}}; buildConfigurationList = {project_config_list}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main_group}; productRefGroup = {products_group}; projectDirPath = ""; projectRoot = ""; targets = ({target_uid}, {ext_target_uid}); }};',
        f'\t\t{debug_config} /* Debug */ = {{isa = XCBuildConfiguration; buildSettings = {{COPY_PHASE_STRIP = NO; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = "1,2"; }}; name = Debug; }};',
        f'\t\t{release_config} /* Release */ = {{isa = XCBuildConfiguration; buildSettings = {{COPY_PHASE_STRIP = NO; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = "1,2"; }}; name = Release; }};',
        f'\t\t{target_debug} /* Debug */ = {{isa = XCBuildConfiguration; buildSettings = {{ALWAYS_SEARCH_USER_PATHS = NO; ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = ({alternate_icon_names}); ASSETCATALOG_COMPILER_APPICON_NAME = {APP_ICON_NAME}; CODE_SIGN_ENTITLEMENTS = {PROJECT}/{PROJECT}.entitlements; CODE_SIGN_IDENTITY = "Apple Development"; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = {BUILD_NUMBER}; DEVELOPMENT_TEAM = {DEVELOPMENT_TEAM}; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = {PROJECT}/Info.plist; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks"); MARKETING_VERSION = {MARKETING_VERSION}; PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}; PRODUCT_NAME = "$(TARGET_NAME)"; SDKROOT = iphoneos; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SWIFT_EMIT_LOC_STRINGS = YES; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; }}; name = Debug; }};',
        f'\t\t{target_release} /* Release */ = {{isa = XCBuildConfiguration; buildSettings = {{ALWAYS_SEARCH_USER_PATHS = NO; ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = ({alternate_icon_names}); ASSETCATALOG_COMPILER_APPICON_NAME = {APP_ICON_NAME}; CODE_SIGN_ENTITLEMENTS = {PROJECT}/{PROJECT}.entitlements; CODE_SIGN_IDENTITY = "Apple Development"; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = {BUILD_NUMBER}; DEVELOPMENT_TEAM = {DEVELOPMENT_TEAM}; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = {PROJECT}/Info.plist; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks"); MARKETING_VERSION = {MARKETING_VERSION}; PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}; PRODUCT_NAME = "$(TARGET_NAME)"; SDKROOT = iphoneos; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SWIFT_EMIT_LOC_STRINGS = YES; }}; name = Release; }};',
        f'\t\t{ext_debug} /* Debug */ = {{isa = XCBuildConfiguration; buildSettings = {{ALWAYS_SEARCH_USER_PATHS = NO; APPLICATION_EXTENSION_API_ONLY = YES; CODE_SIGN_IDENTITY = "Apple Development"; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = {BUILD_NUMBER}; DEVELOPMENT_TEAM = {DEVELOPMENT_TEAM}; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = {EXTENSION}/Info.plist; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"); MARKETING_VERSION = {MARKETING_VERSION}; PRODUCT_BUNDLE_IDENTIFIER = {EXTENSION_BUNDLE_ID}; PRODUCT_NAME = "$(TARGET_NAME)"; SDKROOT = iphoneos; SKIP_INSTALL = YES; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SWIFT_EMIT_LOC_STRINGS = YES; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; }}; name = Debug; }};',
        f'\t\t{ext_release} /* Release */ = {{isa = XCBuildConfiguration; buildSettings = {{ALWAYS_SEARCH_USER_PATHS = NO; APPLICATION_EXTENSION_API_ONLY = YES; CODE_SIGN_IDENTITY = "Apple Development"; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = {BUILD_NUMBER}; DEVELOPMENT_TEAM = {DEVELOPMENT_TEAM}; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = {EXTENSION}/Info.plist; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"); MARKETING_VERSION = {MARKETING_VERSION}; PRODUCT_BUNDLE_IDENTIFIER = {EXTENSION_BUNDLE_ID}; PRODUCT_NAME = "$(TARGET_NAME)"; SDKROOT = iphoneos; SKIP_INSTALL = YES; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SWIFT_EMIT_LOC_STRINGS = YES; }}; name = Release; }};',
        f'\t\t{ext_config_list} = {{isa = XCConfigurationList; buildConfigurations = ({ext_debug} /* Debug */, {ext_release} /* Release */); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};',
        f'\t\t{project_config_list} = {{isa = XCConfigurationList; buildConfigurations = ({debug_config} /* Debug */, {release_config} /* Release */); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};',
        f'\t\t{target_config_list} = {{isa = XCConfigurationList; buildConfigurations = ({target_debug} /* Debug */, {target_release} /* Release */); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};',
        "\t};",
        f"\trootObject = {project_uid} /* Project object */;",
        "}",
    ]
)

out = ROOT / f"{PROJECT}.xcodeproj" / "project.pbxproj"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text("\n".join(lines) + "\n")
print(f"Wrote {out}")
for name in ICON_COMPOSER_NAMES:
    icon_composer = ROOT / f"{name}.icon"
    if not icon_composer.exists():
        print(f"Warning: missing {icon_composer}")
