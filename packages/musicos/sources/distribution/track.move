module musicos::track;

use musicos::bps::BPS;
use musicos::recording::{Recording, RecordingAdminCap};
use musicos::utils::calculate_duration;

public struct Track has drop, store {
    composition_id: ID,
    composition_commission_rate: BPS,
    recording_id: ID,
    duration: u64,
}

public fun new(cap: &RecordingAdminCap, recording: &Recording): Track {
    recording.authorize(cap);
    Track {
        composition_id: recording.composition_id(),
        composition_commission_rate: recording.composition_commission_rate(),
        recording_id: recording.id(),
        duration: calculate_duration(
            recording.primary_mix().audio().pcm().samples(),
            recording.primary_mix().audio().pcm().sample_rate(),
        ),
    }
}

public fun composition_id(self: &Track): ID {
    self.composition_id
}

public fun composition_commission_rate(self: &Track): BPS {
    self.composition_commission_rate
}

public fun recording_id(self: &Track): ID {
    self.recording_id
}

public fun duration(self: &Track): u64 {
    self.duration
}
