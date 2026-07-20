#!/usr/bin/env python3
from __future__ import annotations

import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROJECT = "HomeHub"
BUNDLE_ID = "com.homehub.app"


def uid() -> str:
    return uuid.uuid4().hex[:24].upper()


swift_files = sorted((ROOT / PROJECT).rglob("*.swift"))
file_refs = {path: uid() for path in swift_files}
build_files = {path: uid() for path in swift_files}

project_uid = uid()
target_uid = uid()
sources_phase = uid()
resources_phase = uid()
frameworks_phase = uid()
product_ref = uid()
main_group = uid()
products_group = uid()
app_group = uid()
project_config_list = uid()
target_config_list = uid()
debug_config = uid()
release_config = uid()
target_debug = uid()
target_release = uid()
info_ref = uid()
assets_ref = uid()
assets_build = uid()

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

lines.extend(
    [
        f'\t\t{info_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = {PROJECT}/Info.plist; sourceTree = SOURCE_ROOT; }};',
        f'\t\t{assets_ref} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = {PROJECT}/Assets.xcassets; sourceTree = SOURCE_ROOT; }};',
        f'\t\t{product_ref} /* {PROJECT}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {PROJECT}.app; sourceTree = BUILT_PRODUCTS_DIR; }};',
    ]
)

for path, ref in build_files.items():
    lines.append(
        f'\t\t{ref} /* {path.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[path]} /* {path.name} */; }};'
    )
lines.append(
    f'\t\t{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_ref} /* Assets.xcassets */; }};'
)

swift_ref_list = ", ".join(f"{file_refs[p]} /* {p.name} */" for p in swift_files)
build_ref_list = ", ".join(f"{build_files[p]} /* {p.name} in Sources */" for p in swift_files)

lines.extend(
    [
        f'\t\t{products_group} /* Products */ = {{isa = PBXGroup; children = ({product_ref} /* {PROJECT}.app */); name = Products; sourceTree = "<group>"; }};',
        f'\t\t{app_group} /* {PROJECT} */ = {{isa = PBXGroup; children = ({swift_ref_list}, {info_ref} /* Info.plist */, {assets_ref} /* Assets.xcassets */); name = {PROJECT}; sourceTree = "<group>"; }};',
        f'\t\t{main_group} = {{isa = PBXGroup; children = ({app_group} /* {PROJECT} */, {products_group} /* Products */); sourceTree = "<group>"; }};',
        f'\t\t{frameworks_phase} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};',
        f'\t\t{sources_phase} /* Sources */ = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({build_ref_list}); runOnlyForDeploymentPostprocessing = 0; }};',
        f'\t\t{resources_phase} /* Resources */ = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({assets_build} /* Assets.xcassets in Resources */); runOnlyForDeploymentPostprocessing = 0; }};',
        f'\t\t{target_uid} /* {PROJECT} */ = {{isa = PBXNativeTarget; buildConfigurationList = {target_config_list}; buildPhases = ({sources_phase} /* Sources */, {frameworks_phase} /* Frameworks */, {resources_phase} /* Resources */); buildRules = (); dependencies = (); name = {PROJECT}; productName = {PROJECT}; productReference = {product_ref}; productType = "com.apple.product-type.application"; }};',
        f'\t\t{project_uid} /* Project object */ = {{isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = 1; LastUpgradeCheck = 1600;}}; buildConfigurationList = {project_config_list}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main_group}; productRefGroup = {products_group}; projectDirPath = ""; projectRoot = ""; targets = ({target_uid}); }};',
        f'\t\t{debug_config} /* Debug */ = {{isa = XCBuildConfiguration; buildSettings = {{IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 2; }}; name = Debug; }};',
        f'\t\t{release_config} /* Release */ = {{isa = XCBuildConfiguration; buildSettings = {{IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 2; }}; name = Release; }};',
        f'\t\t{target_debug} /* Debug */ = {{isa = XCBuildConfiguration; buildSettings = {{ALWAYS_SEARCH_USER_PATHS = NO; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = {PROJECT}/Info.plist; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks"); MARKETING_VERSION = 1.0; PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}; PRODUCT_NAME = "$(TARGET_NAME)"; SDKROOT = iphoneos; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SWIFT_EMIT_LOC_STRINGS = YES; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; }}; name = Debug; }};',
        f'\t\t{target_release} /* Release */ = {{isa = XCBuildConfiguration; buildSettings = {{ALWAYS_SEARCH_USER_PATHS = NO; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = {PROJECT}/Info.plist; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks"); MARKETING_VERSION = 1.0; PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}; PRODUCT_NAME = "$(TARGET_NAME)"; SDKROOT = iphoneos; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SWIFT_EMIT_LOC_STRINGS = YES; }}; name = Release; }};',
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
