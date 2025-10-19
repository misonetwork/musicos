module musicos::track;

use musicos::recording::{Recording, RecordingAdminCap};

//=== Structs ===

public struct Track has copy, drop, store {
    composition_id: ID,
    recording_id: ID,
    duration: u64,
}

//=== Public Functions ===

public fun new(recording: &Recording, cap: &RecordingAdminCap): Track {
    recording.authorize(cap);
    Track {
        composition_id: recording.composition_id(),
        recording_id: object::id(recording),
        duration: recording.primary_mix().audio().duration(),
    }
}

public fun composition_id(self: &Track): ID {
    self.composition_id
}

public fun recording_id(self: &Track): ID {
    self.recording_id
}

public fun duration(self: &Track): u64 {
    self.duration
}
