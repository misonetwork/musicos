module musicos::time_signature_spec;

#[spec_only]
use prover::prover::{requires, ensures};
use musicos::time_signature;

#[spec(prove)]
fun new_spec(beats_per_measure: u8, beat_unit: u8): time_signature::TimeSignature {
    requires(beats_per_measure > 0);
    requires(beat_unit > 0);
    let result = time_signature::new(beats_per_measure, beat_unit);
    ensures(result.beats_per_measure() == beats_per_measure);
    ensures(result.beat_unit() == beat_unit);
    result
}

#[spec(prove, ignore_abort)]
fun new_aborts_zero_beats_spec(beat_unit: u8) {
    requires(beat_unit > 0);
    let _result = time_signature::new(0, beat_unit);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun new_aborts_zero_beat_unit_spec(beats_per_measure: u8) {
    requires(beats_per_measure > 0);
    let _result = time_signature::new(beats_per_measure, 0);
    ensures(false);
}
