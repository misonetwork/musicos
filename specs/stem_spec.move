module musicos::stem_spec;

#[spec_only]
use prover::prover::{requires, ensures, clone};
use musicos::stem::{Self, Stem};
use musicos::audio::Audio;
use partyos::party::Party;

/// add_contributor increases contributor count by 1.
#[spec(prove, ignore_abort)]
fun add_contributor_increments_count(self: &mut Stem, contributor: &Party) {
    let old_len = clone!(self.contributors()).length();
    stem::add_contributor(self, contributor);
    ensures(self.contributors().length() == old_len + 1);
}

/// add_contributor aborts when contributor already exists.
#[spec(prove, ignore_abort)]
fun add_contributor_aborts_duplicate(self: &mut Stem, contributor: &Party) {
    requires(self.contributors().contains(&contributor.id()));
    stem::add_contributor(self, contributor);
    ensures(false);
}

/// add_contributor aborts when max contributors (10) reached.
#[spec(prove, ignore_abort)]
fun add_contributor_aborts_at_max(self: &mut Stem, contributor: &Party) {
    requires(self.contributors().length() >= 10);
    stem::add_contributor(self, contributor);
    ensures(false);
}

/// remove_contributor aborts when index out of bounds.
#[spec(prove, ignore_abort)]
fun remove_contributor_aborts_out_of_bounds(self: &mut Stem, idx: u64) {
    requires(idx >= self.contributors().length());
    stem::remove_contributor(self, idx);
    ensures(false);
}
