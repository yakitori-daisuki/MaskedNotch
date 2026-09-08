#!/usr/bin/env python3
"""Deterministic, dependency-free generator. Checked-in .xcodeproj is directly usable."""
from pathlib import Path
import hashlib

root = Path(__file__).resolve().parent.parent
def uid(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def q(s): return '"' + s.replace('"', '\\"') + '"'
objects = []
def obj(key, body):
    objects.append(f'{uid(key)} = {{ {body} }};')
    return uid(key)

sources = sorted(str(p.relative_to(root)) for p in (root/'Sources').rglob('*.swift'))
refs, builds = [], []
for p in sources:
    refs.append(obj(p, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(p)}; sourceTree = SOURCE_ROOT;'))
    builds.append(obj(p+'-build', f'isa = PBXBuildFile; fileRef = {uid(p)};'))
test_sources = sorted(str(p.relative_to(root)) for p in (root/'Tests').rglob('*.swift'))
test_builds = []
for p in test_sources:
    refs.append(obj(p, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(p)}; sourceTree = SOURCE_ROOT;'))
for p in test_sources + [s for s in sources if '/MaskedNotchCore/' in s or s.endswith(('/BandPanel.swift', '/LayeredBandStack.swift', '/RefreshProbe.swift', '/Diagnostics.swift', '/VariantRefresh.swift', '/BlinkPulse.swift'))]:
    test_builds.append(obj(p+'-testbuild', f'isa = PBXBuildFile; fileRef = {uid(p)};'))
test_product = obj('testproduct', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = MaskedNotchTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
test_phase = obj('testsources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(test_builds)},); runOnlyForDeploymentPostprocessing = 0;')
license_path = 'Vendor/SkyLightWindow/LICENSE'
license_ref = obj('license', f'isa = PBXFileReference; lastKnownFileType = text; path = {q(license_path)}; sourceTree = SOURCE_ROOT;')
license_build = obj('license-build', f'isa = PBXBuildFile; fileRef = {license_ref};')
extra_resources = []
localized_refs = []
for language in ['en', 'ja']:
    path = f'Resources/{language}.lproj/Localizable.strings'
    localized_refs.append(obj(path, f'isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = {language}; path = {q(path)}; sourceTree = SOURCE_ROOT;'))
strings_group = obj('localized-strings', f'isa = PBXVariantGroup; children = ({",".join(localized_refs)},); name = Localizable.strings; sourceTree = "<group>";')
refs.append(strings_group)
extra_resources.append(obj('localized-strings-build', f'isa = PBXBuildFile; fileRef = {strings_group};'))
icon_path = 'Resources/IconArtwork/AppIcon.icon'
icon_ref = obj(icon_path, f'isa = PBXFileReference; lastKnownFileType = folder.icon; path = {q(icon_path)}; sourceTree = SOURCE_ROOT;')
refs.append(icon_ref)
extra_resources.append(obj(icon_path+'-resource', f'isa = PBXBuildFile; fileRef = {icon_ref};'))
for p in ['THIRD_PARTY_NOTICES.md', 'Resources/MaskedNotch-LICENSE.txt']:
    ref_id = obj(p, f'isa = PBXFileReference; lastKnownFileType = text; path = {q(p)}; sourceTree = SOURCE_ROOT;')
    refs.append(ref_id)
    extra_resources.append(obj(p+'-resource', f'isa = PBXBuildFile; fileRef = {ref_id};'))
product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = MaskedNotch.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products', f'isa = PBXGroup; children = ({product},{test_product},); name = Products; sourceTree = "<group>";')
group = obj('group', f'isa = PBXGroup; children = ({",".join(refs+[license_ref, products])},); sourceTree = "<group>";')
source_phase = obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)},); runOnlyForDeploymentPostprocessing = 0;')
resource_phase = obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join([license_build]+extra_resources)},); runOnlyForDeploymentPostprocessing = 0;')
framework_phase = obj('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
for scope in ['project','target','test']:
    configs=[]
    for config in ['Debug','Release']:
        common = 'MACOSX_DEPLOYMENT_TARGET = 26.0; SDKROOT = macosx; SWIFT_VERSION = 5.0; CLANG_ENABLE_MODULES = YES; '
        if scope == 'target':
            common += 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; '
            common += 'PRODUCT_NAME = MaskedNotch; PRODUCT_BUNDLE_IDENTIFIER = local.MaskedNotch; INFOPLIST_FILE = Resources/Info.plist; CODE_SIGN_STYLE = Manual; CODE_SIGN_IDENTITY = "-"; ENABLE_HARDENED_RUNTIME = YES; ENABLE_APP_SANDBOX = NO; '
        if scope == 'test':
            common += 'PRODUCT_NAME = MaskedNotchTests; PRODUCT_BUNDLE_IDENTIFIER = local.MaskedNotch.Tests; GENERATE_INFOPLIST_FILE = YES; CODE_SIGN_STYLE = Manual; CODE_SIGN_IDENTITY = "-"; SWIFT_EMIT_LOC_STRINGS = NO; '
        common += 'SWIFT_OPTIMIZATION_LEVEL = "-Onone"; DEBUG_INFORMATION_FORMAT = dwarf; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; ENABLE_TESTABILITY = YES;' if config == 'Debug' else 'SWIFT_OPTIMIZATION_LEVEL = "-O"; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'
        if scope == 'target' and config == 'Release':
            common += ' CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO;'
        configs.append(obj(scope+config, f'isa = XCBuildConfiguration; buildSettings = {{ {common} }}; name = {config};'))
    obj(scope+'configs', f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {uid("targetconfigs")}; buildPhases = ({source_phase},{framework_phase},{resource_phase},); buildRules = (); dependencies = (); name = MaskedNotch; productName = MaskedNotch; productReference = {product}; productType = "com.apple.product-type.application";')
test_target = obj('testtarget', f'isa = PBXNativeTarget; buildConfigurationList = {uid("testconfigs")}; buildPhases = ({test_phase},); buildRules = (); dependencies = (); name = MaskedNotchTests; productName = MaskedNotchTests; productReference = {test_product}; productType = "com.apple.product-type.bundle.unit-test";')
project = obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2650; }}; buildConfigurationList = {uid("projectconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,ja,Base,); mainGroup = {group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},{test_target},);')
out=root/'MaskedNotch.xcodeproj';out.mkdir(exist_ok=True)
(out/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {project}; }}\n')
scheme=out/'xcshareddata/xcschemes';scheme.mkdir(parents=True,exist_ok=True)
ref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="MaskedNotch.app" BlueprintName="MaskedNotch" ReferencedContainer="container:MaskedNotch.xcodeproj"/>'
testref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{test_target}" BuildableName="MaskedNotchTests.xctest" BlueprintName="MaskedNotchTests" ReferencedContainer="container:MaskedNotch.xcodeproj"/>'
(scheme/'MaskedNotch.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2650" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{testref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="NO"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
