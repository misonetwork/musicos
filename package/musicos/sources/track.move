module musicos::track;

use musicos::recording::{Recording, RecordingAdminCap};

public struct Track has drop, store {
    composition_id: ID,
    recording_id: ID,
    duration: u64,
}

public fun new(cap: &RecordingAdminCap, recording: &Recording): Track {
    recording.authorize(cap);
    Track {
        composition_id: recording.composition_id(),
        duration: recording.primary_mix().audio().duration(),
        recording_id: recording.id(),
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
