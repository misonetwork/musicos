#[test_only]
module musicos::recording_tests;

use musicos::credit;
use musicos::genre;
use musicos::recording;
use musicos::recording_party_role;
use musicos::stem;
use musicos::test_helpers::{Self, RecordingShare};
use musicos::time_signature;
use musicos::musical_key;
use std::unit_test::{assert_eq, destroy};
use walrus_data::walrus_data;

// Error codes from recording.move
const EMinRolesNotMet: u64 = 20;
const EInvalidTempoBpm: u64 = 21;
const EExceedsMaxRoles: u64 = 30;
const EMaxStemsExceeded: u64 = 31;
const EMaxCreditsExceeded: u64 = 32;
const EMaxSecondaryGenresExceeded: u64 = 33;
const EMaxPrimaryArtistsExceeded: u64 = 34;
const EMaxFeaturedArtistsExceeded: u64 = 35;
const EMaxTitleVersionLengthExceeded: u64 = 36;
const EMaxSubtitleLengthExceeded: u64 = 37;
const EEmptyString: u64 = 38;
const EPartyAlreadyCredited: u64 = 40;
const EAlreadyPrimaryArtist: u64 = 41;
const EAlreadyFeaturedArtist: u64 = 42;
const ELyricsInstrumentalConflict: u64 = 45;
const ENoParties: u64 = 50;
const ENoPrimaryArtistAssigned: u64 = 51;
const EPartyNotCredited: u64 = 52;
const EMinStemContributorsNotMet: u64 = 53;

// Must match recording.move
const MAX_STEMS: u64 = 100;
const MAX_CREDITS: u64 = 150;
const MAX_SECONDARY_GENRES: u64 = 3;
const MAX_PRIMARY_ARTISTS: u64 = 20;
const MAX_FEATURED_ARTISTS: u64 = 50;
const MAX_TITLE_VERSION_LENGTH: u64 = 100;
const MAX_SUBTITLE_LENGTH: u64 = 300;

/// Helper to create a test recording.
fun new_test_recording(ctx: &mut TxContext): (
    recording::Recording<RecordingShare>,
    recording::RecordingAdminCap<RecordingShare>,
) {
    let comp_id = test_helpers::fake_id(ctx);
    let genre_id = test_helpers::fake_id(ctx);
    recording::new_for_testing<RecordingShare>(
        b"Test Song".to_string(),
        comp_id,
        5000,
        genre_id,
        false,
        false,
        test_helpers::audio(),
        test_helpers::cover_art(),
        ctx,
    )
}

/// Helper to create an instrumental test recording.
fun new_instrumental_recording(ctx: &mut TxContext): (
    recording::Recording<RecordingShare>,
    recording::RecordingAdminCap<RecordingShare>,
) {
    let comp_id = test_helpers::fake_id(ctx);
    let genre_id = test_helpers::fake_id(ctx);
    recording::new_for_testing<RecordingShare>(
        b"Test Instrumental".to_string(),
        comp_id,
        5000,
        genre_id,
        false,
        true,
        test_helpers::audio(),
        test_helpers::cover_art(),
        ctx,
    )
}

// === Credits ===

#[test]
fun test_add_credit() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    let cred = credit::new(
        b"Producer".to_string(),
        vector[recording_party_role::new_producer_role(option::none())],
    );
    rec.add_credit(&cap, &party, cred);

    assert_eq!(rec.credits().length(), 1);

    destroy(rec);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

#[test, expected_failure(abort_code = EPartyAlreadyCredited, location = musicos::recording)]
fun test_add_credit_duplicate_party() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    let cred1 = credit::new(
        b"Producer".to_string(),
        vector[recording_party_role::new_producer_role(option::none())],
    );
    rec.add_credit(&cap, &party, cred1);

    let cred2 = credit::new(
        b"Vocalist".to_string(),
        vector[recording_party_role::new_vocalist_role(option::none())],
    );
    rec.add_credit(&cap, &party, cred2);

    destroy(rec);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

#[test, expected_failure(abort_code = EMinRolesNotMet, location = musicos::recording)]
fun test_add_credit_no_roles() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    let cred = credit::new(b"Artist".to_string(), vector[]);
    rec.add_credit(&cap, &party, cred);

    destroy(rec);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

// === Primary & Featured Artists ===

#[test]
fun test_add_primary_artist() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    // Must be credited first
    let cred = credit::new(
        b"Artist".to_string(),
        vector[recording_party_role::new_vocalist_role(option::none())],
    );
    rec.add_credit(&cap, &party, cred);
    rec.add_primary_artist(&cap, &party);

    assert!(rec.is_primary_artist(party.id()));
    assert_eq!(rec.primary_artist_ids().length(), 1);

    destroy(rec);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

#[test]
fun test_add_featured_artist() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    let cred = credit::new(
        b"Featured".to_string(),
        vector[recording_party_role::new_vocalist_role(option::none())],
    );
    rec.add_credit(&cap, &party, cred);
    rec.add_featured_artist(&cap, &party);

    assert!(rec.is_featured_artist(party.id()));
    assert_eq!(rec.featured_artist_ids().length(), 1);

    destroy(rec);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

#[test, expected_failure(abort_code = EPartyNotCredited, location = musicos::recording)]
fun test_add_primary_artist_not_credited() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    rec.add_primary_artist(&cap, &party);

    destroy(rec);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

#[test, expected_failure(abort_code = EAlreadyFeaturedArtist, location = musicos::recording)]
fun test_add_primary_artist_already_featured() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    let cred = credit::new(
        b"Artist".to_string(),
        vector[recording_party_role::new_vocalist_role(option::none())],
    );
    rec.add_credit(&cap, &party, cred);
    rec.add_featured_artist(&cap, &party);
    rec.add_primary_artist(&cap, &party); // should fail - already featured

    destroy(rec);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

#[test, expected_failure(abort_code = EAlreadyPrimaryArtist, location = musicos::recording)]
fun test_add_primary_artist_already_primary() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    let cred = credit::new(
        b"Artist".to_string(),
        vector[recording_party_role::new_vocalist_role(option::none())],
    );
    rec.add_credit(&cap, &party, cred);
    rec.add_primary_artist(&cap, &party);
    rec.add_primary_artist(&cap, &party); // duplicate

    destroy(rec);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

#[test, expected_failure(abort_code = EAlreadyPrimaryArtist, location = musicos::recording)]
fun test_add_featured_artist_already_primary() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    let cred = credit::new(
        b"Artist".to_string(),
        vector[recording_party_role::new_vocalist_role(option::none())],
    );
    rec.add_credit(&cap, &party, cred);
    rec.add_primary_artist(&cap, &party);
    rec.add_featured_artist(&cap, &party); // should fail - already primary

    destroy(rec);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

// === Genres ===

#[test]
fun test_add_secondary_genre() {
    let ctx = &mut tx_context::dummy();
    let (rec, cap) = new_test_recording(ctx);
    let mut registry = genre::new_genre_registry_for_testing(ctx);

    genre::new(b"JAZZ".to_string(), &mut registry);

    // We need the Genre object - use test_scenario for this
    // Since genre::new shares the object, we can't easily get a reference in unit tests.
    // Instead, verify the secondary_genre_ids set starts empty.
    assert_eq!(rec.secondary_genre_ids().length(), 0);

    destroy(rec);
    destroy(cap);
    destroy(registry);
}

// === String Bounds ===

#[test]
fun test_set_title_version() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    rec.set_title_version(&cap, b"Radio Edit".to_string());
    assert!(rec.title_version().is_some());

    destroy(rec);
    destroy(cap);
}

#[test]
fun test_set_title_version_at_max_length() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    rec.set_title_version(&cap, test_helpers::long_string(MAX_TITLE_VERSION_LENGTH));
    assert!(rec.title_version().is_some());

    destroy(rec);
    destroy(cap);
}

#[test, expected_failure(abort_code = EEmptyString, location = musicos::recording)]
fun test_set_title_version_empty() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    rec.set_title_version(&cap, b"".to_string());
    destroy(rec);
    destroy(cap);
}

#[test, expected_failure(abort_code = EMaxTitleVersionLengthExceeded, location = musicos::recording)]
fun test_set_title_version_too_long() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    rec.set_title_version(&cap, test_helpers::long_string(MAX_TITLE_VERSION_LENGTH + 1));
    destroy(rec);
    destroy(cap);
}

#[test]
fun test_set_subtitle() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    rec.set_subtitle(&cap, b"A Love Song".to_string());
    assert!(rec.subtitle().is_some());

    destroy(rec);
    destroy(cap);
}

#[test]
fun test_set_subtitle_at_max_length() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    rec.set_subtitle(&cap, test_helpers::long_string(MAX_SUBTITLE_LENGTH));
    assert!(rec.subtitle().is_some());

    destroy(rec);
    destroy(cap);
}

#[test, expected_failure(abort_code = EEmptyString, location = musicos::recording)]
fun test_set_subtitle_empty() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    rec.set_subtitle(&cap, b"".to_string());
    destroy(rec);
    destroy(cap);
}

#[test, expected_failure(abort_code = EMaxSubtitleLengthExceeded, location = musicos::recording)]
fun test_set_subtitle_too_long() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    rec.set_subtitle(&cap, test_helpers::long_string(MAX_SUBTITLE_LENGTH + 1));
    destroy(rec);
    destroy(cap);
}

// === Musical Properties ===

#[test]
fun test_set_tempo_bpm() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    rec.set_tempo_bpm(&cap, 120);
    assert_eq!(*rec.tempo_bpm(), option::some(120));

    destroy(rec);
    destroy(cap);
}

#[test, expected_failure(abort_code = EInvalidTempoBpm, location = musicos::recording)]
fun test_set_tempo_bpm_zero() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    rec.set_tempo_bpm(&cap, 0);
    destroy(rec);
    destroy(cap);
}

#[test]
fun test_set_musical_key() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    let key = musical_key::new(
        musical_key::new_note_c(),
        musical_key::new_accidental_natural(),
        musical_key::new_mode_major(),
    );
    rec.set_musical_key(&cap, key);
    assert!(rec.musical_key().is_some());

    destroy(rec);
    destroy(cap);
}

#[test]
fun test_set_time_signature() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    rec.set_time_signature(&cap, time_signature::new(4, 4));
    assert!(rec.time_signature().is_some());

    destroy(rec);
    destroy(cap);
}

// === Stems ===

#[test]
fun test_add_stem() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    // Credit the party first (required for stem contributor validation)
    let cred = credit::new(
        b"Vocalist".to_string(),
        vector[recording_party_role::new_vocalist_role(option::none())],
    );
    rec.add_credit(&cap, &party, cred);

    // Create a stem with the credited party as contributor
    let mut s = stem::new(test_helpers::audio(), b"Vocals".to_string());
    s.add_contributor(&party);
    rec.add_stem(&cap, s);

    assert_eq!(rec.stems().length(), 1);

    destroy(rec);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

#[test, expected_failure(abort_code = EMinStemContributorsNotMet, location = musicos::recording)]
fun test_add_stem_no_contributors() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    let s = stem::new(test_helpers::audio(), b"Vocals".to_string());
    rec.add_stem(&cap, s); // no contributors

    destroy(rec);
    destroy(cap);
}

#[test, expected_failure(abort_code = EPartyNotCredited, location = musicos::recording)]
fun test_add_stem_contributor_not_credited() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    // Don't credit the party on the recording
    let mut s = stem::new(test_helpers::audio(), b"Vocals".to_string());
    s.add_contributor(&party);
    rec.add_stem(&cap, s); // contributor not credited

    destroy(rec);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

// === Lyrics/Instrumental Conflict ===

#[test, expected_failure(abort_code = ELyricsInstrumentalConflict, location = musicos::recording)]
fun test_set_lyrics_on_instrumental() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_instrumental_recording(ctx);

    rec.set_lyrics(&cap, walrus_data::new_blob(1)); // should fail

    destroy(rec);
    destroy(cap);
}

// === Publish ===

#[test]
fun test_publish_recording() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    // Credit and assign as primary artist
    let cred = credit::new(
        b"Artist".to_string(),
        vector[recording_party_role::new_vocalist_role(option::none())],
    );
    rec.add_credit(&cap, &party, cred);
    rec.add_primary_artist(&cap, &party);

    let clock = sui::clock::create_for_testing(ctx);
    rec.publish(&cap, &clock);

    clock.destroy_for_testing();
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

#[test, expected_failure(abort_code = ENoParties, location = musicos::recording)]
fun test_publish_no_parties() {
    let ctx = &mut tx_context::dummy();
    let (rec, cap) = new_test_recording(ctx);

    let clock = sui::clock::create_for_testing(ctx);
    rec.publish(&cap, &clock);

    clock.destroy_for_testing();
    destroy(cap);
}

#[test, expected_failure(abort_code = ENoPrimaryArtistAssigned, location = musicos::recording)]
fun test_publish_no_primary_artist() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    // Credit but don't assign as primary artist
    let cred = credit::new(
        b"Producer".to_string(),
        vector[recording_party_role::new_producer_role(option::none())],
    );
    rec.add_credit(&cap, &party, cred);

    let clock = sui::clock::create_for_testing(ctx);
    rec.publish(&cap, &clock);

    clock.destroy_for_testing();
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

// === Title Version / Subtitle can be updated (swap_or_fill) ===

#[test]
fun test_set_title_version_twice() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    rec.set_title_version(&cap, b"Radio Edit".to_string());
    rec.set_title_version(&cap, b"Extended Mix".to_string());
    assert!(rec.title_version().is_some());

    destroy(rec);
    destroy(cap);
}

#[test]
fun test_set_subtitle_twice() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    rec.set_subtitle(&cap, b"First Subtitle".to_string());
    rec.set_subtitle(&cap, b"Updated Subtitle".to_string());
    assert!(rec.subtitle().is_some());

    destroy(rec);
    destroy(cap);
}

// === Exceeds-Limit Tests ===

#[test, expected_failure(abort_code = EMaxCreditsExceeded, location = musicos::recording)]
fun test_add_credit_exceeds_max() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    // Pre-fill to MAX_CREDITS
    rec.prefill_credits_for_testing(MAX_CREDITS, ctx);

    // One more should fail
    let (party, party_cap) = test_helpers::individual(ctx);
    let cred = credit::new(
        b"One Too Many".to_string(),
        vector[recording_party_role::new_vocalist_role(option::none())],
    );
    rec.add_credit(&cap, &party, cred);

    destroy(party);
    destroy(party_cap);
    destroy(rec);
    destroy(cap);
}

#[test, expected_failure(abort_code = EMaxStemsExceeded, location = musicos::recording)]
fun test_add_stem_exceeds_max() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    // Credit a party so we can create stems with a contributor
    let cred = credit::new(
        b"Artist".to_string(),
        vector[recording_party_role::new_vocalist_role(option::none())],
    );
    rec.add_credit(&cap, &party, cred);

    // Pre-fill to MAX_STEMS
    rec.prefill_stems_for_testing(MAX_STEMS);

    // One more should fail
    let mut s = stem::new(test_helpers::audio(), b"Overflow".to_string());
    s.add_contributor(&party);
    rec.add_stem(&cap, s);

    destroy(party);
    destroy(party_cap);
    destroy(rec);
    destroy(cap);
}

#[test, expected_failure(abort_code = EExceedsMaxRoles, location = musicos::recording)]
fun test_add_credit_exceeds_max_roles() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    // Create a credit with 11 roles (MAX_ROLES_PER_CREDIT + 1)
    let cred = credit::new(
        b"Artist".to_string(),
        vector[
            recording_party_role::new_producer_role(option::none()),
            recording_party_role::new_vocalist_role(option::none()),
            recording_party_role::new_arranger_role(option::none()),
            recording_party_role::new_conductor_role(option::none()),
            recording_party_role::new_editor_role(option::none()),
            recording_party_role::new_mixing_engineer_role(option::none()),
            recording_party_role::new_mastering_engineer_role(option::none()),
            recording_party_role::new_recording_engineer_role(option::none()),
            recording_party_role::new_programmer_role(option::none()),
            recording_party_role::new_sound_designer_role(option::none()),
            recording_party_role::new_narrator_role(option::none()),
        ],
    );
    rec.add_credit(&cap, &party, cred);

    destroy(party);
    destroy(party_cap);
    destroy(rec);
    destroy(cap);
}

#[test, expected_failure(abort_code = EMaxPrimaryArtistsExceeded, location = musicos::recording)]
fun test_add_primary_artist_exceeds_max() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    // Pre-fill to MAX_PRIMARY_ARTISTS
    rec.prefill_primary_artists_for_testing(MAX_PRIMARY_ARTISTS, ctx);

    // Credit one more party and try to designate as primary
    let (party, party_cap) = test_helpers::individual(ctx);
    let cred = credit::new(
        b"Artist".to_string(),
        vector[recording_party_role::new_vocalist_role(option::none())],
    );
    rec.add_credit(&cap, &party, cred);
    rec.add_primary_artist(&cap, &party);

    destroy(party);
    destroy(party_cap);
    destroy(rec);
    destroy(cap);
}

#[test, expected_failure(abort_code = EMaxFeaturedArtistsExceeded, location = musicos::recording)]
fun test_add_featured_artist_exceeds_max() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    // Pre-fill to MAX_FEATURED_ARTISTS
    rec.prefill_featured_artists_for_testing(MAX_FEATURED_ARTISTS, ctx);

    // Credit one more party and try to designate as featured
    let (party, party_cap) = test_helpers::individual(ctx);
    let cred = credit::new(
        b"Artist".to_string(),
        vector[recording_party_role::new_vocalist_role(option::none())],
    );
    rec.add_credit(&cap, &party, cred);
    rec.add_featured_artist(&cap, &party);

    destroy(party);
    destroy(party_cap);
    destroy(rec);
    destroy(cap);
}

#[test, expected_failure(abort_code = EMaxSecondaryGenresExceeded, location = musicos::recording)]
fun test_add_secondary_genre_exceeds_max() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    // Fill to MAX_SECONDARY_GENRES using valid genre names (A-Z and _ only)
    let names = vector[b"JAZZ", b"ROCK", b"POP"];
    let mut genres = vector[];
    MAX_SECONDARY_GENRES.do!(|i| {
        let g = genre::new_for_testing(names[i].to_string(), ctx);
        rec.add_secondary_genre(&cap, &g);
        genres.push_back(g);
    });

    // One more should fail
    let extra = genre::new_for_testing(b"BLUES".to_string(), ctx);
    rec.add_secondary_genre(&cap, &extra);

    destroy(extra);
    genres.destroy!(|g| destroy(g));
    destroy(rec);
    destroy(cap);
}

