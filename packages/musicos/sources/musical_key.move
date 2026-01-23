// Copyright (c) Studio Mirai, LLC
// Copyright (c) Unconfirmed Labs, LLC
// Copyright (c) Alex Clapworthy
// SPDX-License-Identifier: Apache-2.0

/// Represents the musical key of a composition or recording.
/// A key consists of a note letter (A-G), an optional accidental (sharp/flat),
/// and a mode (major/minor). For example: C Major, F# Minor, Bb Major.
module musicos::musical_key;

/// A musical key combining a root note, accidental, and mode.
/// Examples: MusicalKey(C, Natural, Major) = C Major
///           MusicalKey(F, Sharp, Minor) = F# Minor
public struct MusicalKey(Note, Accidental, Mode) has copy, drop, store;

/// The seven natural note letters in Western music.
public enum Note has copy, drop, store {
    C,
    D,
    E,
    F,
    G,
    A,
    B,
}

/// Pitch modifiers that raise or lower a note by a half step.
public enum Accidental has copy, drop, store {
    Natural,
    Sharp,
    Flat,
}

/// The two primary modes in Western tonal music.
public enum Mode has copy, drop, store {
    /// Major mode, typically perceived as bright or happy.
    Major,
    /// Minor mode, typically perceived as dark or sad.
    Minor,
}

//=== Public View Functions ===

/// Returns the root note letter of this key.
public fun note(self: &MusicalKey): Note { self.0 }

/// Returns the accidental modifier of this key.
public fun accidental(self: &MusicalKey): Accidental { self.1 }

/// Returns the mode (major or minor) of this key.
public fun mode(self: &MusicalKey): Mode { self.2 }
