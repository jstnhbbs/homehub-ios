# Performance and Weather Review

Date: October 13, 2026

## Scope

Signed Debug simulator build, iPhone 17 on iOS 27.0, Xcode 27 on an
Apple Silicon Mac. Existing household data was read but not changed.
These are short diagnostic runs, not Release-device benchmarks.

## Changes

- Weather readout observes NativeWeatherService directly. New readings, errors,
  attribution and permission changes no longer wait for an unrelated AppState update.
- Automatic weather refresh keeps its one-hour reading lifetime and applies a
  fifteen-minute retry delay even when a failed request leaves an old reading.
  Manual refresh still bypasses the delay; cancelled tasks do not impose it.
- Permission changes invalidate in-flight results and clear readings when location
  is no longer authorized, including permission reset back to Not Asked.
- Offline and timeout failures have appropriate messages; a generic WeatherKit
  outage is no longer described as missing WeatherKit configuration. Details
  explain when the last reading is being shown after a failure.
- Profile/family crop preparation downsamples before drawing rather than decoding
  the original full-resolution camera image. Upload resizing uses scale 1, so
  its 1600-pixel limit is not multiplied by a Retina screen's scale.

## Measurements

- Routine-list scroll profile: 35 seconds, 778 CPU samples, 769 ms of sampled
  main-thread activity. No recorded potential hangs above the 250 ms threshold.
  This does not measure individual dropped frames or prove 60/120 fps rendering.
- Memory snapshot after the earlier navigation session: 64.5 MB physical
  footprint, 65.0 MB peak. A separate launch-session snapshot: 47.9 MB, 49.0 MB peak.
- Final build after navigation and editor presentation/dismissal: 49.8 MB,
  57.8 MB peak. Different screen histories make these unsuitable as a speedup
  or memory-reduction claim.
- All three graphs reported 40 unclassified malloc allocations totaling 1280
  leaked bytes. No named app-owned object or ownership cycle was identified.
  This is unresolved diagnostic evidence, not a claim that the app is leak-free.
- The App Launch capture returned no lifecycle/first-frame rows. No trustworthy
  launch-duration result is available from that capture.

## Verification

Simulator build and launch/navigation smoke test passed. Checks passed:
`weather-refresh`, `profile-photo` (real UIKit in Simulator), `image-downsampling`,
`photo-crop`, and `async-lifecycle`.

The simulator has not granted location access. Live WeatherKit responses and
revoking/regranting location while a request is in flight remain physical-device
tests. Photo checks used generated images, not personal photos or uploads.

## Local Capture Artifacts

- CPU trace: `/tmp/tugboat-routines-scroll.trace`
- CPU export: `/tmp/tugboat-scroll-samples.xml`
- Hang export: `/tmp/tugboat-scroll-hangs.xml`
- Launch trace (timing unavailable): `/tmp/tugboat-launch.trace`
- Memory graphs and summaries: `/tmp/tugboat-performance-baseline/`,
  `/tmp/tugboat-performance-launch/`, `/tmp/tugboat-performance-final/`

Temporary artifacts are not committed and may be removed by the OS. Memgraphs
can contain in-memory household data; keep them local.

## Remaining Work

- Profile a Release build on the smaller household iPad: Today, recipe scrolling,
  calendar day/week navigation, and a large photo crop.
- Measure cold and warm first-frame launch timing on device.
- Test live weather offline recovery and location revocation/regranting on device.
- Extend memory testing to sustained recipe/calendar use and repeated photo crops.
- Investigate the unclassified allocations if a longer run shows growth.
