module musicos::deal_spec;

#[spec_only]
use prover::prover::{requires, ensures};
use musicos::deal;
use musicos::composition::Composition;
use musicos::recording::{Recording, RecordingAdminCap};
use musicos::cover_art::CoverArt;

#[spec(prove, ignore_abort)]
fun new_aborts_on_composition_id_mismatch<CS, RS>(
    cap: &RecordingAdminCap<RS>,
    composition: &Composition<CS>, recording: &Recording<RS>,
    release_id: ID, split: u64,
    title: Option<std::string::String>, art: Option<CoverArt>,
    ctx: &mut TxContext,
) {
    requires(composition.id() != recording.composition_id());
    let d = deal::new<CS, RS>(cap, composition, recording, release_id, split, title, art, ctx);
    ensures(false);
    prover::prover::drop(d);
}

#[spec(prove, ignore_abort)]
fun new_preserves_ids<CS, RS>(
    cap: &RecordingAdminCap<RS>,
    composition: &Composition<CS>, recording: &Recording<RS>,
    release_id: ID, split: u64,
    title: Option<std::string::String>, art: Option<CoverArt>,
    ctx: &mut TxContext,
) {
    requires(composition.id() == recording.composition_id());
    let d = deal::new<CS, RS>(cap, composition, recording, release_id, split, title, art, ctx);
    ensures(d.composition_id() == composition.id());
    ensures(d.recording_id() == recording.id());
    ensures(d.release_id() == release_id);
    prover::prover::drop(d);
}
