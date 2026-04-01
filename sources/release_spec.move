module musicos::release_spec;

#[spec_only]
use prover::prover::{requires, ensures, clone};
use musicos::release::{Self, Release, ReleaseAdminCap};
use musicos::release_party_role::ReleasePartyRole;
use partyos::credit::Credit;
use partyos::party::Party;

// === State machine ===

#[spec(prove, ignore_abort)]
fun add_credit_aborts_when_published(
    self: &mut Release, cap: &ReleaseAdminCap,
    party: &Party, credit: Credit<ReleasePartyRole>,
) {
    requires(self.is_published_state());
    requires(self.id() == cap.release_id());
    release::add_credit(self, cap, party, credit);
    ensures(false);
}

// === Authorization ===

#[spec(prove, ignore_abort)]
fun authorize_aborts_wrong_cap(self: &Release, cap: &ReleaseAdminCap) {
    requires(self.id() != cap.release_id());
    release::authorize(self, cap);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun authorize_succeeds(self: &Release, cap: &ReleaseAdminCap) {
    requires(self.id() == cap.release_id());
    release::authorize(self, cap);
}

// === Credit invariants ===

#[spec(prove, ignore_abort)]
fun add_credit_increments_count(
    self: &mut Release, cap: &ReleaseAdminCap,
    party: &Party, credit: Credit<ReleasePartyRole>,
) {
    requires(self.id() == cap.release_id());
    requires(self.is_initialized_state());
    let old_len = clone!(self.credits()).length();
    release::add_credit(self, cap, party, credit);
    ensures(self.credits().length() == old_len + 1);
}

#[spec(prove, ignore_abort)]
fun add_credit_aborts_duplicate(
    self: &mut Release, cap: &ReleaseAdminCap,
    party: &Party, credit: Credit<ReleasePartyRole>,
) {
    requires(self.id() == cap.release_id());
    requires(self.is_initialized_state());
    requires(self.credits().contains(&party.id()));
    release::add_credit(self, cap, party, credit);
    ensures(false);
}

// === Credit role count (release requires exactly 1 role) ===

/// add_credit aborts when credit has zero roles.
#[spec(prove, ignore_abort)]
fun add_credit_aborts_zero_roles(
    self: &mut Release, cap: &ReleaseAdminCap,
    party: &Party, credit: Credit<ReleasePartyRole>,
) {
    requires(self.id() == cap.release_id());
    requires(self.is_initialized_state());
    requires(credit.roles().length() == 0);
    release::add_credit(self, cap, party, credit);
    ensures(false);
}

/// add_credit aborts when credit has more than 1 role.
#[spec(prove, ignore_abort)]
fun add_credit_aborts_multiple_roles(
    self: &mut Release, cap: &ReleaseAdminCap,
    party: &Party, credit: Credit<ReleasePartyRole>,
) {
    requires(self.id() == cap.release_id());
    requires(self.is_initialized_state());
    requires(credit.roles().length() > 1);
    release::add_credit(self, cap, party, credit);
    ensures(false);
}

/// add_credit aborts when max credits (50) reached.
#[spec(prove, ignore_abort)]
fun add_credit_aborts_max_credits(
    self: &mut Release, cap: &ReleaseAdminCap,
    party: &Party, credit: Credit<ReleasePartyRole>,
) {
    requires(self.id() == cap.release_id());
    requires(self.is_initialized_state());
    requires(self.credits().length() >= 50);
    release::add_credit(self, cap, party, credit);
    ensures(false);
}
