# Error Code Standardization Skill

This document describes the error code numbering system used in MusicOS. Use this guide when adding new error codes or fixing existing ones to maintain consistency across the codebase.

## Error Code Ranges

| Range | Category | When to Use |
|-------|----------|-------------|
| **0** | Authorization | Permission failures, capability mismatches, unauthorized access |
| **1-9** | State Machine | Invalid state transitions, wrong lifecycle state |
| **10-19** | Bounds/Limits | Index out of bounds, maximum limits exceeded, minimum requirements not met |
| **20-29** | Validation | Invalid input values, format errors, configuration problems |
| **30-39** | Existence/Conflict | Duplicate entries, missing required entities, type mismatches |

## How to Assign Error Codes

### Step 1: Identify the Error Category

Ask yourself: What kind of problem does this error represent?

- **Authorization (0)**: Is this about permissions or capabilities?
  - Examples: Wrong admin cap, unregistered authority type, missing permission

- **State Machine (1-9)**: Is this about lifecycle states?
  - Examples: Can't publish from Created state, operation requires Published state
  - Use consistent codes: 1=Initialized, 2=Created, 3=Active, 4=Published, 5=Paused, 6=Deprecating, 7=Deprecated, 8=Already deprecated, 9=Delay not elapsed

- **Bounds/Limits (10-19)**: Is this about counts, indexes, or limits?
  - Examples: Too many items, index out of range, below minimum count
  - Use 10 for "max exceeded", 11-13 for specific index bounds

- **Validation (20-29)**: Is this about invalid input or configuration?
  - Examples: Invalid format, unsupported value, doesn't sum correctly
  - Use 20 for "required but missing/invalid", 21-29 for specific validation failures

- **Existence/Conflict (30-39)**: Is this about duplicates or type requirements?
  - Examples: Already exists, not the right type, conflict with existing data

### Step 2: Check Existing Codes in the Category

Look at what codes are already used in the range. Prefer:
1. Reusing an existing code if the error is semantically identical
2. Using the next available code if it's a new type of error
3. Leaving gaps for future related errors

### Step 3: Apply Consistent Naming

Error constants should follow the pattern:
- `E` prefix (required)
- Descriptive name in PascalCase
- Examples: `EUnauthorized`, `ENotCreatedState`, `EMaxDiscsReached`, `EInvalidTrackSplitsSum`

## Current Error Code Assignments

### Authorization (0)
```
0 = EUnauthorized, EInvalidAudioCreationAuthority
```

### State Machine (1-9)
```
1 = ENotInitializedState
2 = ENotCreatedState
3 = ENotActiveState, ENotEnabledState
4 = ENotPublishedState, ENotDisabledState
5 = ENotPausedState
6 = ENotDeprecatingState
7 = ENotDeprecatedState
8 = EAlreadyDeprecatedState
9 = EDeprecationDelayNotElapsed
```

### Bounds/Limits (10-19)
```
10 = EMaxDiscsReached, EMaxTracksExceeded, EMaxStemsExceeded,
     EMaxSequenceLengthExceeded, EExceedsMaxRoles
11 = EMinRolesNotMet, EDiscIndexOutOfBounds
12 = EContributorRoleIndexOutOfBounds, ETrackIndexOutOfBounds
13 = ESequenceIndexOutOfBounds
```

### Validation (20-29)
```
20 = ENoDiscs, ENoContributors, EInvalidTrackSplitsLength,
     EUnsupportedBitDepth, EOverflow, EInvalidDecimals
21 = EInvalidTrackSplitsSum, EUnsupportedChannels, EUnderflow, EInvalidSymbol
22 = ENoRevenueToDistribute, EUnsupportedSampleRate, EDivideByZero, ENotZeroSupply
```

### Existence/Conflict (30-39)
```
30 = EDuplicateContributor, EContributorRoleAlreadyExists
31 = ENotIndividualKind
32 = ENotGroupKind
```

## Examples

### Adding a New Error

Scenario: You need an error for "track already exists in disc"

1. **Category**: This is about duplicates → Existence/Conflict (30-39)
2. **Check existing**: 30 is used for duplicates, 31-32 for type checks
3. **Assign**: Use `30` since it matches the "already exists" pattern
4. **Name**: `ETrackAlreadyExists`

Result:
```move
const ETrackAlreadyExists: u64 = 30;
```

### Fixing Duplicate Codes

Scenario: Two errors in the same file both use code `1`

1. Identify what each error represents
2. Categorize each according to the ranges
3. Reassign one (or both) to the correct category
4. Ensure the new codes don't conflict within the same module

### Adding State Errors for New States

If adding a new state to a module (e.g., "Pending"):
1. Add it to the state machine range (1-9)
2. Find an unused code in the sequence
3. Keep related states together numerically

## Quick Reference Checklist

When reviewing error codes:

- [ ] All error codes have the `E` prefix
- [ ] Code 0 is reserved for authorization errors only
- [ ] State machine errors are in range 1-9
- [ ] Bounds/limit errors are in range 10-19
- [ ] Validation errors are in range 20-29
- [ ] Existence/conflict errors are in range 30-39
- [ ] No duplicate codes within the same module
- [ ] Semantically similar errors use the same code across modules
