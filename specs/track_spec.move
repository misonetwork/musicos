module musicos::track_spec;

#[spec_only]
use prover::prover::{requires, ensures};
use musicos::track::{Self, Track};

#[spec(prove, ignore_abort)]
fun assign_transitions_to_assigned(self: &mut Track, release_uid: &UID) {
    requires(self.is_unassigned_state());
    track::assign(self, release_uid);
    ensures(self.is_assigned_state());
}

#[spec(prove, ignore_abort)]
fun assign_aborts_when_assigned(self: &mut Track, release_uid: &UID) {
    requires(self.is_assigned_state());
    track::assign(self, release_uid);
    ensures(false);
}
