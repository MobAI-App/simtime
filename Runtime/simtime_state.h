#ifndef SIMTIME_STATE_H
#define SIMTIME_STATE_H

#ifdef __cplusplus
extern "C" {
#endif

// Returns the mock wall-clock seconds-since-epoch for a given real seconds
// value. Pass-through (returns input unchanged) when not mocking. Safe to
// call from any thread; cheap on the no-mocking fast path.
double simtime_mock_seconds(double real_seconds);

// Cheap query - true if the dylib is currently mocking. Used by hooks to
// skip the full lookup when not active.
int simtime_active(void);

#ifdef __cplusplus
}
#endif

#endif
