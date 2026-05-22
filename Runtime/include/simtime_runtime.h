#ifndef SIMTIME_RUNTIME_H
#define SIMTIME_RUNTIME_H

// Injected via DYLD_INSERT_LIBRARIES into the target app inside an iOS
// Simulator. Reads state from /private/tmp/simtime-<udid>-<bundle>.json on
// every time-API call (with an mtime cache so the cost is sub-microsecond when
// state is unchanged).
//
// Configure on launch via env vars set by the simtime CLI before launching
// the target app:
//
//   SIMTIME_UDID    - sim UDID
//   SIMTIME_BUNDLE  - target bundle ID
//
// Without those env vars the dylib is a no-op (passes through to libc).

#endif
