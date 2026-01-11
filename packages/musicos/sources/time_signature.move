module musicos::time_signature;

/// Time signature - beats per measure / beat unit
/// TimeSignature(4, 4) = 4/4 (four quarter notes per measure)
/// TimeSignature(6, 8) = 6/8 (six eighth notes per measure)
public struct TimeSignature(u8, u8) has copy, drop, store;

public fun new(beats_per_measure: u8, beat_unit: u8): TimeSignature {
    TimeSignature(beats_per_measure, beat_unit)
}

public fun beats_per_measure(self: &TimeSignature): u8 { self.0 }

public fun beat_unit(self: &TimeSignature): u8 { self.1 }
