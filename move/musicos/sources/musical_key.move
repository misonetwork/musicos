// Copyright (c) Unconfirmed Labs, LLC
// SPDX-License-Identifier: Apache-2.0

/// Represents the musical key of a composition or recording.
/// A key consists of a note letter (A-G), an optional accidental (sharp/flat),
/// and a mode (major/minor). For example: C Major, F# Minor, Bb Major.
module musicos::musical_key;

use std::string::String;

// === Structs ===

/// A musical key combining a root note, accidental, and mode.
/// Examples: MusicalKey(C, Natural, Major) = C Major
///           MusicalKey(F, Sharp, Minor) = F# Minor
public struct MusicalKey(Note, Accidental, Mode) has copy, drop, store;

// === Enums ===

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

// === Errors ===

// Validation errors (20-29)
/// Note string must be one of: c, d, e, f, g, a, b.
const EInvalidNote: u64 = 20;
/// Accidental string must be one of: natural, sharp, flat.
const EInvalidAccidental: u64 = 21;
/// Mode string must be one of: major, minor.
const EInvalidMode: u64 = 22;

// === Public Functions ===

/// Creates a new musical key from typed components.
public fun new(note: Note, accidental: Accidental, mode: Mode): MusicalKey {
    MusicalKey(note, accidental, mode)
}

/// Creates a new musical key from string representations.
/// Accepts lowercase note letters ("c"-"b"), accidental names ("natural",
/// "sharp", "flat"), and mode names ("major", "minor").
public fun new_from_strings(
    note_string: String,
    accidental_string: String,
    mode_string: String,
): MusicalKey {
    let mut note = option::none<Note>();
    let mut accidental = option::none<Accidental>();
    let mut mode = option::none<Mode>();

    if (note_string == "c") {
        note.fill(Note::C);
    } else if (note_string == "d") {
        note.fill(Note::D);
    } else if (note_string == "e") {
        note.fill(Note::E);
    } else if (note_string == "f") {
        note.fill(Note::F);
    } else if (note_string == "g") {
        note.fill(Note::G);
    } else if (note_string == "a") {
        note.fill(Note::A);
    } else if (note_string == "b") {
        note.fill(Note::B);
    } else {
        abort EInvalidNote
    };

    if (accidental_string == "sharp") {
        accidental.fill(Accidental::Sharp);
    } else if (accidental_string == "flat") {
        accidental.fill(Accidental::Flat);
    } else if (accidental_string == "natural") {
        accidental.fill(Accidental::Natural);
    } else {
        abort EInvalidAccidental
    };

    if (mode_string == "major") {
        mode.fill(Mode::Major);
    } else if (mode_string == "minor") {
        mode.fill(Mode::Minor);
    } else {
        abort EInvalidMode
    };

    MusicalKey(note.destroy_some(), accidental.destroy_some(), mode.destroy_some())
}

/// Creates a C note.
public fun new_note_c(): Note {
    Note::C
}

/// Creates a D note.
public fun new_note_d(): Note {
    Note::D
}

/// Creates an E note.
public fun new_note_e(): Note {
    Note::E
}

/// Creates an F note.
public fun new_note_f(): Note {
    Note::F
}

/// Creates a G note.
public fun new_note_g(): Note {
    Note::G
}

/// Creates an A note.
public fun new_note_a(): Note {
    Note::A
}

/// Creates a B note.
public fun new_note_b(): Note {
    Note::B
}

/// Creates a Natural accidental.
public fun new_accidental_natural(): Accidental {
    Accidental::Natural
}

/// Creates a Sharp accidental.
public fun new_accidental_sharp(): Accidental {
    Accidental::Sharp
}

/// Creates a Flat accidental.
public fun new_accidental_flat(): Accidental {
    Accidental::Flat
}

/// Creates a Major mode.
public fun new_mode_major(): Mode {
    Mode::Major
}

/// Creates a Minor mode.
public fun new_mode_minor(): Mode {
    Mode::Minor
}

// === Public View Functions ===

/// Returns the root note letter of this key.
public fun note(self: &MusicalKey): Note { self.0 }

/// Returns the accidental modifier of this key.
public fun accidental(self: &MusicalKey): Accidental { self.1 }

/// Returns the mode (major or minor) of this key.
public fun mode(self: &MusicalKey): Mode { self.2 }
