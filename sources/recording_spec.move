module musicos::recording_spec;

#[spec_only]
use prover::prover::{requires, ensures, clone};
use musicos::recording::{Self, Recording, RecordingAdminCap};
use musicos::recording_party_role::RecordingPartyRole;
use ori::walrus_data::WalrusData;
use partyos::credit::Credit;
use partyos::party::Party;

// === State machine: mutation requires Initialized ===

#[spec(prove, ignore_abort)]
fun add_credit_aborts_when_published<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>,
    party: &Party, credit: Credit<RecordingPartyRole>,
) {
    requires(self.is_published_state());
    recording::add_credit(self, cap, party, credit);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun add_primary_artist_aborts_when_published<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, party: &Party,
) {
    requires(self.is_published_state());
    recording::add_primary_artist(self, cap, party);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun add_featured_artist_aborts_when_published<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, party: &Party,
) {
    requires(self.is_published_state());
    recording::add_featured_artist(self, cap, party);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun set_lyrics_aborts_when_published<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, lyrics: WalrusData,
) {
    requires(self.is_published_state());
    recording::set_lyrics(self, cap, lyrics);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun set_title_version_aborts_when_published<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, v: std::string::String,
) {
    requires(self.is_published_state());
    recording::set_title_version(self, cap, v);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun set_subtitle_aborts_when_published<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, s: std::string::String,
) {
    requires(self.is_published_state());
    recording::set_subtitle(self, cap, s);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun set_language_aborts_when_published<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, code: std::string::String,
) {
    requires(self.is_published_state());
    recording::set_language(self, cap, code);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun set_primary_genre_aborts_when_published<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, genre: &musicos::genre::Genre,
) {
    requires(self.is_published_state());
    recording::set_primary_genre(self, cap, genre);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun add_secondary_genre_aborts_when_published<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, genre: &musicos::genre::Genre,
) {
    requires(self.is_published_state());
    recording::add_secondary_genre(self, cap, genre);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun set_musical_key_aborts_when_published<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>,
    key: musicos::musical_key::MusicalKey,
) {
    requires(self.is_published_state());
    recording::set_musical_key(self, cap, key);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun set_tempo_bpm_aborts_when_published<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, bpm: u16,
) {
    requires(self.is_published_state());
    recording::set_tempo_bpm(self, cap, bpm);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun add_stem_aborts_when_published<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, stem: musicos::stem::Stem,
) {
    requires(self.is_published_state());
    recording::add_stem(self, cap, stem);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun remove_secondary_genre_aborts_when_published<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, genre_id: ID,
) {
    requires(self.is_published_state());
    recording::remove_secondary_genre(self, cap, genre_id);
    ensures(false);
}

// === Credit invariants ===

#[spec(prove, ignore_abort)]
fun add_credit_increments_count<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>,
    party: &Party, credit: Credit<RecordingPartyRole>,
) {
    requires(self.is_initialized_state());
    let old_len = clone!(self.credits()).length();
    recording::add_credit(self, cap, party, credit);
    ensures(self.credits().length() == old_len + 1);
}

#[spec(prove, ignore_abort)]
fun add_credit_aborts_duplicate<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>,
    party: &Party, credit: Credit<RecordingPartyRole>,
) {
    requires(self.is_initialized_state());
    requires(self.credits().contains(&party.id()));
    recording::add_credit(self, cap, party, credit);
    ensures(false);
}

// === Disjoint artist sets ===

#[spec(prove, ignore_abort)]
fun add_primary_artist_aborts_if_featured<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, party: &Party,
) {
    requires(self.is_initialized_state());
    requires(self.credits().contains(&party.id()));
    requires(self.featured_artist_ids().contains(&party.id()));
    recording::add_primary_artist(self, cap, party);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun add_featured_artist_aborts_if_primary<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, party: &Party,
) {
    requires(self.is_initialized_state());
    requires(self.credits().contains(&party.id()));
    requires(self.primary_artist_ids().contains(&party.id()));
    recording::add_featured_artist(self, cap, party);
    ensures(false);
}

// === Artist-credit linkage ===

#[spec(prove, ignore_abort)]
fun add_primary_artist_requires_credit<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, party: &Party,
) {
    requires(self.is_initialized_state());
    requires(!self.credits().contains(&party.id()));
    recording::add_primary_artist(self, cap, party);
    ensures(false);
}

#[spec(prove, ignore_abort)]
fun add_featured_artist_requires_credit<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, party: &Party,
) {
    requires(self.is_initialized_state());
    requires(!self.credits().contains(&party.id()));
    recording::add_featured_artist(self, cap, party);
    ensures(false);
}

// === Instrumental/lyrics conflict ===

#[spec(prove, ignore_abort)]
fun set_lyrics_aborts_when_instrumental<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, lyrics: WalrusData,
) {
    requires(self.is_initialized_state());
    requires(self.is_instrumental());
    recording::set_lyrics(self, cap, lyrics);
    ensures(false);
}

// === Genre exclusivity ===

#[spec(prove, ignore_abort)]
fun add_secondary_genre_aborts_if_primary<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, genre: &musicos::genre::Genre,
) {
    requires(self.is_initialized_state());
    requires(self.primary_genre_id() == genre.id());
    recording::add_secondary_genre(self, cap, genre);
    ensures(false);
}

// === Stem count ===

#[spec(prove, ignore_abort)]
fun add_stem_increments_count<RS>(
    self: &mut Recording<RS>, cap: &RecordingAdminCap<RS>, stem: musicos::stem::Stem,
) {
    requires(self.is_initialized_state());
    let old_len = clone!(self.stems()).length();
    recording::add_stem(self, cap, stem);
    ensures(self.stems().length() == old_len + 1);
}
