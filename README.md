# simtime

Control the wall-clock an iOS Simulator app sees.

AI agents should not wait 7 days to test a 7-day trial. `simtime` lets you
freeze, jump, speed up, or reset the clock inside an app running in the iOS
Simulator - without rebuilding the app, without restarting the simulator,
without touching app source.

```sh
simtime freeze --udid <UDID> --bundle com.example.app "2026-01-01T10:00:00Z"
simtime travel --udid <UDID> --bundle com.example.app "+8d"
simtime scale  --udid <UDID> --bundle com.example.app 60
simtime reset  --udid <UDID> --bundle com.example.app
simtime        --udid <UDID> --bundle com.example.app          # status
```

## How it works

`simtime` ships two pieces:

- **`simtime` CLI** (Swift, host-side). Reads/writes a small JSON state file
  at `/private/tmp/simtime-<udid>-<bundleID>.json`.
- **`libsimtime.dylib` runtime** (Obj-C, runs inside the sim). Injected via
  `DYLD_INSERT_LIBRARIES`, interposes `gettimeofday`, `clock_gettime`,
  `time()`, `CFAbsoluteTimeGetCurrent`. Foundation's `NSDate` and Swift's
  `Date` route through these C entry points, so all the Swift/Obj-C
  date-of-day APIs are covered.

The state file is the same path inside the sim's filesystem and on the host
(`/private/tmp` is shared). The dylib re-reads it on every clock call,
gated by an mtime check, so changes from the CLI take effect immediately
without restarting the app.

`CLOCK_MONOTONIC` and `mach_absolute_time` are deliberately NOT mocked -
freezing them would freeze UIKit's animation and timer subsystems too, and
the app would look dead. `scale` does not currently scale monotonic clocks
either; we revisit if a real use case appears.

## What gets mocked

| API | Hooked | Notes |
|---|---|---|
| `gettimeofday` | ✅ | |
| `clock_gettime(CLOCK_REALTIME)` | ✅ | |
| `clock_gettime(CLOCK_MONOTONIC)` | ❌ | by design - would freeze UIKit |
| `time()` | ✅ | |
| `CFAbsoluteTimeGetCurrent` | ✅ | catches `+[NSDate date]`, `Date.now` |
| `mach_absolute_time` | ❌ | by design - would freeze UIKit |
| Swift `Clock` protocols | - | use `CFAbsoluteTime` underneath, so covered |
| Server-side time | ❌ | client-side only; mock your backend separately |

## Install

### Homebrew (recommended, Apple Silicon)

```sh
brew install mobai-app/tap/simtime
```

This installs the `simtime` binary and the runtime dylib into the Cellar
and wires `SIMTIME_DYLIB` automatically, so `simtime inject` finds the
runtime without any extra setup.

### From a release tarball

Grab the latest `simtime-vX.Y.Z-macos-arm64.tar.gz` from
[Releases](https://github.com/MobAI-App/simtime/releases), extract it, and
point `SIMTIME_DYLIB` at the bundled `libsimtime.dylib`:

```sh
tar -xzf simtime-v0.1.0-macos-arm64.tar.gz
cd simtime-v0.1.0-macos-arm64
export SIMTIME_DYLIB="$PWD/libsimtime.dylib"
./simtime --help
```

### From source

```sh
git clone https://github.com/MobAI-App/simtime
cd simtime

# build the CLI (Swift)
swift build -c release

# build the runtime dylib (iPhone Simulator SDK)
cd Runtime && make && cd ..
```

This leaves `./.build/release/simtime` and `./Runtime/libsimtime.dylib`.
The CLI looks for the dylib at `./Runtime/libsimtime.dylib` (relative to
PWD) by default, or wherever `SIMTIME_DYLIB` / `--dylib` points.

## Usage

The dylib has to be injected at app launch - `DYLD_INSERT_LIBRARIES` only
takes effect on a fresh process. Two paths:

### Option 1: `simtime inject` (one-shot)

```sh
simtime inject --udid <UDID> --bundle com.example.app
```

This terminates the running app, copies the dylib to a sim-visible path,
and relaunches with `SIMCTL_CHILD_DYLD_INSERT_LIBRARIES` set.

### Option 2: launch the app yourself

```sh
SIMCTL_CHILD_DYLD_INSERT_LIBRARIES=/path/to/libsimtime.dylib \
SIMCTL_CHILD_SIMTIME_UDID=<UDID> \
SIMCTL_CHILD_SIMTIME_BUNDLE=com.example.app \
xcrun simctl launch <UDID> com.example.app
```

Once the runtime is loaded, the `simtime freeze / travel / scale / reset`
commands take effect immediately - no app restart needed.

## Example: collapsing a 7-day trial

```sh
UDID=<your-sim-udid>
APP=com.example.app

simtime inject --udid $UDID --bundle $APP

# User taps "Start trial" → app records start date
# Now jump 8 days forward
simtime travel --udid $UDID --bundle $APP "+8d"

# App's next "is trial active?" check sees the future
# Trial-expired screen renders
```

## Limitations (v0)

- iOS Simulator only. Real-device support is not planned (Apple doesn't
  give us DYLD_INSERT_LIBRARIES there without jailbreak).
- App must be relaunched once to load the dylib. After that, time changes
  apply live without restart.
- Monotonic clocks not affected - by design (see above).
- Hooks live in process memory; killing the app reverts to real time on
  the next launch unless you re-inject.
- Server-side time is not mocked - only client-side reads.

## Status

v0: working end-to-end on iOS Simulator 26.4 (arm64 + x86_64).
Tested with `freeze`, `travel`, `scale`, `reset`, persistent state, live updates.

## License

Apache License 2.0. See `LICENSE`.
