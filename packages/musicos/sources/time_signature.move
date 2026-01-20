// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/// Represents the time signature of a composition or recording.
/// A time signature specifies the rhythmic structure: how many beats
/// per measure and which note value gets one beat.
module musicos::time_signature;

/// A time signature expressed as beats per measure over beat unit.
/// Examples: TimeSignature(4, 4) = 4/4 (four quarter notes per measure)
///           TimeSignature(6, 8) = 6/8 (six eighth notes per measure)
///           TimeSignature(3, 4) = 3/4 (three quarter notes per measure)
public struct TimeSignature(
    /// Number of beats in each measure.
    u8,
    /// Note value that receives one beat (4 = quarter, 8 = eighth, etc.).
    u8,
) has copy, drop, store;

//=== Public Functions ===

/// Creates a new time signature with the specified beats per measure and beat unit.
public fun new(beats_per_measure: u8, beat_unit: u8): TimeSignature {
    TimeSignature(beats_per_measure, beat_unit)
}

//=== Public View Functions ===

/// Returns the number of beats per measure.
public fun beats_per_measure(self: &TimeSignature): u8 { self.0 }

/// Returns the beat unit (note value that gets one beat).
public fun beat_unit(self: &TimeSignature): u8 { self.1 }
