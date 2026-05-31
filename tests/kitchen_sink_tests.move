#[test_only]
module musicos::kitchen_sink_tests;

use partyos::credit;
use musicos::disc;
use musicos::genre;
use musicos::musical_key;
use musicos::recording;
use musicos::recording_party_role;
use musicos::release;
use musicos::release_kind;
use musicos::release_party_role;
use musicos::stem;
use musicos::test_helpers::{Self, CompositionShare, RecordingShare, V};
use musicos::time_signature;
use musicos::track;
use std::unit_test::destroy;

// === Helpers ===

/// Creates 10 distinct recording party roles for a credit.
fun make_10_roles(): vector<recording_party_role::RecordingPartyRole> {
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
    ]
}

// === Tests ===

/// Kitchen sink test: creates a recording with ALL fields at maximum bounds.
/// - 150 credits (MAX_CREDITS), each with 10 roles (MAX_ROLES_PER_CREDIT)
/// - 20 primary artists (MAX_PRIMARY_ARTISTS)
/// - 50 featured artists (MAX_FEATURED_ARTISTS)
/// - 3 secondary genres (MAX_SECONDARY_GENRES)
/// - 100 stems (MAX_STEMS), each with 1 contributor
/// - title_version at 100 bytes (MAX_TITLE_VERSION_LENGTH)
/// - subtitle at 200 bytes (MAX_SUBTITLE_LENGTH)
/// - language, lyrics, musical_key, time_signature, tempo_bpm all set
/// - Successfully publishes
#[test]
fun test_recording_kitchen_sink() {
    let ctx = &mut tx_context::dummy();

    // Create recording
    let comp_id = test_helpers::fake_id(ctx);
    let genre_id = test_helpers::fake_id(ctx);
    let (mut rec, cap) = recording::new_for_testing<RecordingShare>(
        b"Kitchen Sink Recording".to_string(),
        comp_id,
        5000,
        genre_id,
        true,  // is_explicit
        false, // is_instrumental (need lyrics)
        test_helpers::audio(),
        test_helpers::cover_art(),
        ctx,
    );

    // Create 150 parties (stored in a vector for reuse)
    let mut parties = vector[];
    let mut party_caps = vector[];
    150u64.do!(|_| {
        let (party, party_cap) = test_helpers::individual(ctx);
        parties.push_back(party);
        party_caps.push_back(party_cap);
    });

    // Add 150 credits, each with 10 distinct roles (MAX_CREDITS x MAX_ROLES_PER_CREDIT)
    150u64.do!(|i| {
        let cred = credit::new(b"Artist".to_string(), make_10_roles());
        rec.add_credit(&cap, &parties[i], cred);
    });

    // Designate first 20 as primary artists (MAX_PRIMARY_ARTISTS)
    20u64.do!(|i| {
        rec.add_primary_artist(&cap, &parties[i]);
    });

    // Designate next 50 as featured artists (MAX_FEATURED_ARTISTS)
    50u64.do!(|i| {
        rec.add_featured_artist(&cap, &parties[20 + i]);
    });

    // Add 3 secondary genres (MAX_SECONDARY_GENRES)
    let g0 = genre::new_for_testing(b"GENRE_A".to_string(), ctx);
    rec.add_secondary_genre(&cap, &g0);
    let g1 = genre::new_for_testing(b"GENRE_B".to_string(), ctx);
    rec.add_secondary_genre(&cap, &g1);
    let g2 = genre::new_for_testing(b"GENRE_C".to_string(), ctx);
    rec.add_secondary_genre(&cap, &g2);

    // Add 100 stems (MAX_STEMS), each with 1 contributor from credited parties
    100u64.do!(|i| {
        let mut s = stem::new(test_helpers::audio(), b"Stem".to_string());
        s.add_contributor(&parties[i]);
        rec.add_stem(&cap, s);
    });

    // Set all optional fields at max bounds
    rec.set_title_version(&cap, test_helpers::long_string(100)); // MAX_TITLE_VERSION_LENGTH
    rec.set_subtitle(&cap, test_helpers::long_string(200));       // MAX_SUBTITLE_LENGTH
    rec.set_language(&cap, b"en".to_string());
    rec.set_lyrics(&cap, test_helpers::walrus());
    rec.set_musical_key(&cap, musical_key::new(
        musical_key::new_note_c(),
        musical_key::new_accidental_natural(),
        musical_key::new_mode_major(),
    ));
    rec.set_time_signature(&cap, time_signature::new(4, 4));
    rec.set_tempo_bpm(&cap, 120);

    // Publish - proves all max bounds are achievable together
    let clock = sui::clock::create_for_testing(ctx);
    rec.publish(&cap, &clock, ctx);

    // Cleanup
    clock.destroy_for_testing();
    destroy(cap);
    destroy(g0);
    destroy(g1);
    destroy(g2);
    parties.destroy!(|p| destroy(p));
    party_caps.destroy!(|c| destroy(c));
}

/// Kitchen sink test: creates a release with ALL fields at maximum bounds.
/// - 20 discs (MAX_DISCS) with 255 total tracks (MAX_TRACKS)
///   - 15 discs x 13 tracks = 195, 5 discs x 12 tracks = 60, total = 255
/// - Track splits sum to exactly 10000 BPS (55 x 40 + 200 x 39 = 10000)
/// - 50 credits (MAX_CREDITS), each with exactly 1 role (CREDIT_ROLE_COUNT)
/// - Title at 300 bytes (MAX_TITLE_LENGTH)
/// - Description at 500 bytes (MAX_DESCRIPTION_LENGTH)
/// - Successfully publishes
#[test]
fun test_release_kitchen_sink() {
    let ctx = &mut tx_context::dummy();

    // Build 255 tracks distributed across 20 discs.
    // Split math: 55 x 40 BPS + 200 x 39 BPS = 2200 + 7800 = 10000 BPS (100%)
    // Disc math: 15 discs x 13 tracks + 5 discs x 12 tracks = 195 + 60 = 255
    // Tracks are created with a dummy release_id; release::new_for_testing patches them.
    let dummy_release_id = test_helpers::fake_id(ctx);
    let mut discs = vector[];
    let mut global_idx: u64 = 0;

    // First 15 discs with 13 tracks each
    let mut d: u64 = 0;
    while (d < 15) {
        let mut disc_tracks = vector[];
        let mut t: u64 = 0;
        while (t < 13) {
            let split_bps = if (global_idx < 55) 40 else 39;
            disc_tracks.push_back(track::new_for_testing<CompositionShare, RecordingShare, V>(
                test_helpers::fake_id(ctx),
                test_helpers::fake_id(ctx),
                dummy_release_id,
                b"Track".to_string(),
                180000,
                test_helpers::cover_art(),
                split_bps,
                5000,
            ));
            global_idx = global_idx + 1;
            t = t + 1;
        };
        discs.push_back(disc::new(disc_tracks, option::none()));
        d = d + 1;
    };

    // Last 5 discs with 12 tracks each
    d = 0;
    while (d < 5) {
        let mut disc_tracks = vector[];
        let mut t: u64 = 0;
        while (t < 12) {
            let split_bps = if (global_idx < 55) 40 else 39;
            disc_tracks.push_back(track::new_for_testing<CompositionShare, RecordingShare, V>(
                test_helpers::fake_id(ctx),
                test_helpers::fake_id(ctx),
                dummy_release_id,
                b"Track".to_string(),
                180000,
                test_helpers::cover_art(),
                split_bps,
                5000,
            ));
            global_idx = global_idx + 1;
            t = t + 1;
        };
        discs.push_back(disc::new(disc_tracks, option::none()));
        d = d + 1;
    };

    // Create release with max title and description.
    // new_for_testing patches all tracks to point to the real release ID.
    let (mut rel, rel_cap) = release::new_for_testing(
        release_kind::new_album_kind(),
        test_helpers::long_string(300), // MAX_TITLE_LENGTH
        test_helpers::long_string(500), // MAX_DESCRIPTION_LENGTH
        test_helpers::cover_art(),
        discs,
        ctx,
    );

    // Add 50 credits (MAX_CREDITS), each with exactly 1 role (CREDIT_ROLE_COUNT).
    // First credit must be Primary (required for publish).
    let mut parties = vector[];
    let mut party_caps = vector[];

    let (party0, party_cap0) = test_helpers::individual(ctx);
    rel.add_credit(
        &rel_cap,
        &party0,
        credit::new(
            b"Primary Artist".to_string(),
            vector[release_party_role::new_primary_role()],
        ),
    );
    parties.push_back(party0);
    party_caps.push_back(party_cap0);

    // Remaining 49 credits as Featured
    49u64.do!(|_| {
        let (party, party_cap) = test_helpers::individual(ctx);
        rel.add_credit(
            &rel_cap,
            &party,
            credit::new(
                b"Featured".to_string(),
                vector[release_party_role::new_featured_role()],
            ),
        );
        parties.push_back(party);
        party_caps.push_back(party_cap);
    });

    // Publish - proves all max bounds are achievable together
    let clock = sui::clock::create_for_testing(ctx);
    rel.publish(&rel_cap, &clock, ctx);

    // Cleanup
    clock.destroy_for_testing();
    destroy(rel_cap);
    parties.destroy!(|p| destroy(p));
    party_caps.destroy!(|c| destroy(c));
}
