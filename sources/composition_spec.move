module musicos::composition_spec;

#[spec_only]
use prover::prover::{requires, ensures, clone};
use musicos::composition::{Self, Composition, CompositionAdminCap};
use musicos::composition_party_role::CompositionPartyRole;
use musicos::audio::Audio;
use ori::walrus_data::WalrusData;
use partyos::credit::Credit;
use partyos::party::Party;

// === State machine: mutation requires Initialized ===

#[spec(prove, ignore_abort)]
fun add_credit_aborts_when_published<CS>(
    self: &mut Composition<CS>, cap: &CompositionAdminCap<CS>,
    party: &Party, credit: Credit<CompositionPartyRole>,
) {
    requires(self.is_published_state());
    composition::add_credit(self, cap, party, credit);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun set_lyrics_aborts_when_published<CS>(
    self: &mut Composition<CS>, cap: &CompositionAdminCap<CS>, lyrics: WalrusData,
) {
    requires(self.is_published_state());
    composition::set_lyrics(self, cap, lyrics);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun set_demo_aborts_when_published<CS>(
    self: &mut Composition<CS>, cap: &CompositionAdminCap<CS>, audio: Audio,
) {
    requires(self.is_published_state());
    composition::set_demo(self, cap, audio);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun set_chart_aborts_when_published<CS>(
    self: &mut Composition<CS>, cap: &CompositionAdminCap<CS>, chart: WalrusData,
) {
    requires(self.is_published_state());
    composition::set_chart(self, cap, chart);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun set_score_aborts_when_published<CS>(
    self: &mut Composition<CS>, cap: &CompositionAdminCap<CS>, score: WalrusData,
) {
    requires(self.is_published_state());
    composition::set_score(self, cap, score);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun set_split_bps_aborts_when_published<CS>(
    self: &mut Composition<CS>, cap: &CompositionAdminCap<CS>, split_value: u64,
) {
    requires(self.is_published_state());
    composition::set_split_bps(self, cap, split_value);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun add_alternate_title_aborts_when_published<CS>(
    self: &mut Composition<CS>, cap: &CompositionAdminCap<CS>, title: std::string::String,
) {
    requires(self.is_published_state());
    composition::add_alternate_title(self, cap, title);
    ensures(false);
}

// === Credit invariants ===

#[spec(prove, ignore_abort)]
fun add_credit_increments_count<CS>(
    self: &mut Composition<CS>, cap: &CompositionAdminCap<CS>,
    party: &Party, credit: Credit<CompositionPartyRole>,
) {
    requires(self.is_initialized_state());
    let old_len = clone!(self.credits()).length();
    composition::add_credit(self, cap, party, credit);
    ensures(self.credits().length() == old_len + 1);
}

#[spec(prove, ignore_abort)]
fun add_credit_aborts_duplicate_party<CS>(
    self: &mut Composition<CS>, cap: &CompositionAdminCap<CS>,
    party: &Party, credit: Credit<CompositionPartyRole>,
) {
    requires(self.is_initialized_state());
    requires(self.credits().contains(&party.id()));
    composition::add_credit(self, cap, party, credit);
    ensures(false);
}

// === Alternate titles ===

#[spec(prove, ignore_abort)]
fun add_alternate_title_increments_count<CS>(
    self: &mut Composition<CS>, cap: &CompositionAdminCap<CS>, title: std::string::String,
) {
    requires(self.is_initialized_state());
    let old_len = clone!(self.alternate_titles()).length();
    composition::add_alternate_title(self, cap, title);
    ensures(self.alternate_titles().length() == old_len + 1);
}

// === Credit role count bounds ===

/// add_credit aborts when credit has zero roles.
#[spec(prove, ignore_abort)]
fun add_credit_aborts_zero_roles<CS>(
    self: &mut Composition<CS>, cap: &CompositionAdminCap<CS>,
    party: &Party, credit: Credit<CompositionPartyRole>,
) {
    requires(self.is_initialized_state());
    requires(credit.roles().length() == 0);
    composition::add_credit(self, cap, party, credit);
    ensures(false);
}

/// add_credit aborts when credit has more than 5 roles.
#[spec(prove, ignore_abort)]
fun add_credit_aborts_too_many_roles<CS>(
    self: &mut Composition<CS>, cap: &CompositionAdminCap<CS>,
    party: &Party, credit: Credit<CompositionPartyRole>,
) {
    requires(self.is_initialized_state());
    requires(credit.roles().length() > 5);
    composition::add_credit(self, cap, party, credit);
    ensures(false);
}

/// add_credit aborts when max credits (50) reached.
#[spec(prove, ignore_abort)]
fun add_credit_aborts_max_credits<CS>(
    self: &mut Composition<CS>, cap: &CompositionAdminCap<CS>,
    party: &Party, credit: Credit<CompositionPartyRole>,
) {
    requires(self.is_initialized_state());
    requires(self.credits().length() >= 50);
    composition::add_credit(self, cap, party, credit);
    ensures(false);
}

// === Alternate title bounds ===

/// add_alternate_title aborts when max (5) reached.
#[spec(prove, ignore_abort)]
fun add_alternate_title_aborts_at_max<CS>(
    self: &mut Composition<CS>, cap: &CompositionAdminCap<CS>, title: std::string::String,
) {
    requires(self.is_initialized_state());
    requires(self.alternate_titles().length() >= 5);
    composition::add_alternate_title(self, cap, title);
    ensures(false);
}
