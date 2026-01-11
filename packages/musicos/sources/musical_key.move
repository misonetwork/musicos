// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents the musical key of a composition or recording.
/// A key consists of a note letter (A-G), an optional accidental (sharp/flat),
/// and a mode (major/minor). For example: C Major, F# Minor, Bb Major.
module musicos::musical_key;

/// A musical key combining a root note, accidental, and mode.
/// Examples: MusicalKey(C, Natural, Major) = C Major
///           MusicalKey(F, Sharp, Minor) = F# Minor
public struct MusicalKey(
    /// The root note letter (A through G).
    NoteLetter,
    /// The accidental modifier (natural, sharp, or flat).
    Accidental,
    /// The mode (major or minor).
    Mode,
) has copy, drop, store;

/// The seven natural note letters in Western music.
public enum NoteLetter has copy, drop, store {
    /// The note C.
    C,
    /// The note D.
    D,
    /// The note E.
    E,
    /// The note F.
    F,
    /// The note G.
    G,
    /// The note A.
    A,
    /// The note B.
    B,
}

/// Pitch modifiers that raise or lower a note by a half step.
public enum Accidental has copy, drop, store {
    /// No modification to the natural pitch.
    Natural,
    /// Raises the pitch by one half step.
    Sharp,
    /// Lowers the pitch by one half step.
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
public fun note_letter(self: &MusicalKey): NoteLetter { self.0 }

/// Returns the accidental modifier of this key.
public fun accidental(self: &MusicalKey): Accidental { self.1 }

/// Returns the mode (major or minor) of this key.
public fun mode(self: &MusicalKey): Mode { self.2 }
