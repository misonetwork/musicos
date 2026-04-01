module musicos::time_signature_spec;

#[spec_only]
use prover::prover::{requires, ensures, asserts};
use musicos::time_signature;

/// Comprehensive spec for time_signature::new.
/// Proves: aborts iff beats_per_measure == 0 or beat_unit == 0,
/// and on success returns the exact values provided.
#[spec(prove, target = musicos::time_signature::new)]
fun new_spec(beats_per_measure: u8, beat_unit: u8): time_signature::TimeSignature {
    asserts(beats_per_measure > 0);
    asserts(beat_unit > 0);
    let result = time_signature::new(beats_per_measure, beat_unit);
    ensures(result.beats_per_measure() == beats_per_measure);
    ensures(result.beat_unit() == beat_unit);
    result
}
