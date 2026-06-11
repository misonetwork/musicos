// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Exhaustive checks of the three role-enum modules. These are pure data —
/// constructors, display names, predicates, levels — but in an immutable
/// package every string and predicate here is frozen forever, so each variant
/// is verified once.
#[test_only]
module musicos::party_role_tests;

use musicos::composition_party_role as cpr;
use musicos::recording_party_role as rpr;
use musicos::release_party_role as relpr;
use std::unit_test::assert_eq;

// === Composition roles ===

#[test]
fun composition_roles_names_and_predicates() {
    let r = cpr::new_adapter_role();
    assert!(r.is_adapter_role());
    assert_eq!(r.name(), b"Adapter".to_string());

    let r = cpr::new_arranger_role();
    assert!(r.is_arranger_role());
    assert_eq!(r.name(), b"Arranger".to_string());

    let r = cpr::new_composer_role();
    assert!(r.is_composer_role());
    assert!(!r.is_lyricist_role());
    assert_eq!(r.name(), b"Composer".to_string());

    let r = cpr::new_lyricist_role();
    assert!(r.is_lyricist_role());
    assert_eq!(r.name(), b"Lyricist".to_string());

    let r = cpr::new_songwriter_role();
    assert!(r.is_songwriter_role());
    assert_eq!(r.name(), b"Songwriter".to_string());

    let r = cpr::new_translator_role();
    assert!(r.is_translator_role());
    assert_eq!(r.name(), b"Translator".to_string());
}

// === Release roles ===

#[test]
fun release_roles_names_and_predicates() {
    let r = relpr::new_primary_role();
    assert!(r.is_primary_role());
    assert!(!r.is_featured_role());
    assert_eq!(r.name(), b"Primary".to_string());

    let r = relpr::new_featured_role();
    assert!(r.is_featured_role());
    assert!(!r.is_primary_role());
    assert_eq!(r.name(), b"Featured".to_string());
}

// === Recording roles ===

#[test]
fun recording_roles_names_predicates_and_levels() {
    let lead = option::some(rpr::new_lead_role_level());

    let r = rpr::new_actor_role(lead);
    assert!(r.is_actor_role());
    assert_eq!(r.name(), b"Actor".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_arranger_role(lead);
    assert!(r.is_arranger_role());
    assert_eq!(r.name(), b"Arranger".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_artists_and_repertoire_role();
    assert!(r.is_artists_and_repertoire_role());
    assert_eq!(r.name(), b"Artists & Repertoire".to_string());
    assert!(r.level().is_none());

    let r = rpr::new_choir_role(lead);
    assert!(r.is_choir_role());
    assert_eq!(r.name(), b"Choir".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_choir_master_role(lead);
    assert!(r.is_choir_master_role());
    assert!(!r.is_choir_role());
    assert_eq!(r.name(), b"Choir Master".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_conductor_role(lead);
    assert!(r.is_conductor_role());
    assert_eq!(r.name(), b"Conductor".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_contractor_role(lead);
    assert!(r.is_contractor_role());
    assert_eq!(r.name(), b"Contractor".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_copyist_role();
    assert!(r.is_copyist_role());
    assert_eq!(r.name(), b"Copyist".to_string());
    assert!(r.level().is_none());

    let r = rpr::new_editor_role(lead);
    assert!(r.is_editor_role());
    assert_eq!(r.name(), b"Editor".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_ensemble_role(lead);
    assert!(r.is_ensemble_role());
    assert_eq!(r.name(), b"Ensemble".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_instrumentalist_role(b"Guitar".to_string(), lead);
    assert!(r.is_instrumentalist_role());
    assert_eq!(r.name(), b"Instrumentalist".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_mastering_engineer_role(lead);
    assert!(r.is_mastering_engineer_role());
    assert!(!r.is_mixing_engineer_role());
    assert_eq!(r.name(), b"Mastering Engineer".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_mixing_engineer_role(lead);
    assert!(r.is_mixing_engineer_role());
    assert_eq!(r.name(), b"Mixing Engineer".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_music_director_role(lead);
    assert!(r.is_music_director_role());
    assert_eq!(r.name(), b"Music Director".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_music_supervisor_role(lead);
    assert!(r.is_music_supervisor_role());
    assert_eq!(r.name(), b"Music Supervisor".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_narrator_role(lead);
    assert!(r.is_narrator_role());
    assert_eq!(r.name(), b"Narrator".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_orchestra_role(lead);
    assert!(r.is_orchestra_role());
    assert!(!r.is_orchestrator_role());
    assert_eq!(r.name(), b"Orchestra".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_orchestrator_role(lead);
    assert!(r.is_orchestrator_role());
    assert_eq!(r.name(), b"Orchestrator".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_producer_role(lead);
    assert!(r.is_producer_role());
    assert_eq!(r.name(), b"Producer".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_programmer_role(lead);
    assert!(r.is_programmer_role());
    assert_eq!(r.name(), b"Programmer".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_recording_engineer_role(lead);
    assert!(r.is_recording_engineer_role());
    assert!(!r.is_remixing_engineer_role());
    assert_eq!(r.name(), b"Recording Engineer".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_remixing_engineer_role(lead);
    assert!(r.is_remixing_engineer_role());
    assert_eq!(r.name(), b"Remixing Engineer".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_sound_designer_role(lead);
    assert!(r.is_sound_designer_role());
    assert_eq!(r.name(), b"Sound Designer".to_string());
    assert!(r.level().is_some());

    let r = rpr::new_vocalist_role(option::none());
    assert!(r.is_vocalist_role());
    assert_eq!(r.name(), b"Vocalist".to_string());
    assert!(r.level().is_none());
}

#[test]
fun recording_role_levels_predicates() {
    assert!(rpr::new_additional_role_level().is_additional_role_level());
    assert!(rpr::new_assistant_role_level().is_assistant_role_level());
    assert!(rpr::new_associate_role_level().is_associate_role_level());
    assert!(rpr::new_backing_role_level().is_backing_role_level());
    assert!(rpr::new_executive_role_level().is_executive_role_level());
    assert!(rpr::new_featured_role_level().is_featured_role_level());
    assert!(rpr::new_lead_role_level().is_lead_role_level());
    assert!(rpr::new_primary_role_level().is_primary_role_level());
    assert!(rpr::new_principal_role_level().is_principal_role_level());

    // Cross-checks: a level matches only its own predicate.
    assert!(!rpr::new_lead_role_level().is_primary_role_level());
    assert!(!rpr::new_featured_role_level().is_backing_role_level());

    // A level travels through a role and comes back out.
    let r = rpr::new_vocalist_role(option::some(rpr::new_backing_role_level()));
    assert!(r.level().borrow().is_backing_role_level());
}

/// Every composition-role predicate returns false for a foreign variant.
#[test]
fun composition_role_predicates_reject_other_variants() {
    let probe = cpr::new_adapter_role();
    assert!(!probe.is_arranger_role());
    assert!(!probe.is_composer_role());
    assert!(!probe.is_lyricist_role());
    assert!(!probe.is_songwriter_role());
    assert!(!probe.is_translator_role());
    assert!(!cpr::new_arranger_role().is_adapter_role());
}

/// Every recording-role predicate returns false for a foreign variant.
#[test]
fun recording_role_predicates_reject_other_variants() {
    let probe = rpr::new_vocalist_role(option::none());
    assert!(!probe.is_actor_role());
    assert!(!probe.is_arranger_role());
    assert!(!probe.is_artists_and_repertoire_role());
    assert!(!probe.is_choir_role());
    assert!(!probe.is_choir_master_role());
    assert!(!probe.is_conductor_role());
    assert!(!probe.is_contractor_role());
    assert!(!probe.is_copyist_role());
    assert!(!probe.is_editor_role());
    assert!(!probe.is_ensemble_role());
    assert!(!probe.is_instrumentalist_role());
    assert!(!probe.is_mastering_engineer_role());
    assert!(!probe.is_mixing_engineer_role());
    assert!(!probe.is_music_director_role());
    assert!(!probe.is_music_supervisor_role());
    assert!(!probe.is_narrator_role());
    assert!(!probe.is_orchestra_role());
    assert!(!probe.is_orchestrator_role());
    assert!(!probe.is_producer_role());
    assert!(!probe.is_programmer_role());
    assert!(!probe.is_recording_engineer_role());
    assert!(!probe.is_remixing_engineer_role());
    assert!(!probe.is_sound_designer_role());
    assert!(!rpr::new_actor_role(option::none()).is_vocalist_role());
}

/// Every level predicate returns false for a foreign variant.
#[test]
fun recording_role_level_predicates_reject_other_variants() {
    let probe = rpr::new_lead_role_level();
    assert!(!probe.is_additional_role_level());
    assert!(!probe.is_assistant_role_level());
    assert!(!probe.is_associate_role_level());
    assert!(!probe.is_backing_role_level());
    assert!(!probe.is_executive_role_level());
    assert!(!probe.is_featured_role_level());
    assert!(!probe.is_primary_role_level());
    assert!(!probe.is_principal_role_level());
    assert!(!rpr::new_primary_role_level().is_lead_role_level());
}

// === Exactly-one-variant properties (full predicate × variant matrix) ===

fun all_composition_roles(): vector<cpr::CompositionPartyRole> {
    vector[
        cpr::new_adapter_role(),
        cpr::new_arranger_role(),
        cpr::new_composer_role(),
        cpr::new_lyricist_role(),
        cpr::new_songwriter_role(),
        cpr::new_translator_role(),
    ]
}

#[test]
fun each_composition_predicate_matches_exactly_one_variant() {
    let all = all_composition_roles();
    let mut counts = vector[0u64, 0, 0, 0, 0, 0];
    all.do_ref!(|r| {
        if (r.is_adapter_role()) { *(&mut counts[0]) = counts[0] + 1 };
        if (r.is_arranger_role()) { *(&mut counts[1]) = counts[1] + 1 };
        if (r.is_composer_role()) { *(&mut counts[2]) = counts[2] + 1 };
        if (r.is_lyricist_role()) { *(&mut counts[3]) = counts[3] + 1 };
        if (r.is_songwriter_role()) { *(&mut counts[4]) = counts[4] + 1 };
        if (r.is_translator_role()) { *(&mut counts[5]) = counts[5] + 1 };
    });
    counts.do_ref!(|c| assert_eq!(*c, 1));
}

fun all_recording_roles(): vector<rpr::RecordingPartyRole> {
    let l = option::none();
    vector[
        rpr::new_actor_role(l),
        rpr::new_arranger_role(l),
        rpr::new_artists_and_repertoire_role(),
        rpr::new_choir_role(l),
        rpr::new_choir_master_role(l),
        rpr::new_conductor_role(l),
        rpr::new_contractor_role(l),
        rpr::new_copyist_role(),
        rpr::new_editor_role(l),
        rpr::new_ensemble_role(l),
        rpr::new_instrumentalist_role(b"Guitar".to_string(), l),
        rpr::new_mastering_engineer_role(l),
        rpr::new_mixing_engineer_role(l),
        rpr::new_music_director_role(l),
        rpr::new_music_supervisor_role(l),
        rpr::new_narrator_role(l),
        rpr::new_orchestra_role(l),
        rpr::new_orchestrator_role(l),
        rpr::new_producer_role(l),
        rpr::new_programmer_role(l),
        rpr::new_recording_engineer_role(l),
        rpr::new_remixing_engineer_role(l),
        rpr::new_sound_designer_role(l),
        rpr::new_vocalist_role(l),
    ]
}

#[test]
fun each_recording_predicate_matches_exactly_one_variant() {
    let all = all_recording_roles();
    let mut counts = vector[];
    24u64.do!(|_| counts.push_back(0u64));
    all.do_ref!(|r| {
        if (r.is_actor_role()) { *(&mut counts[0]) = counts[0] + 1 };
        if (r.is_arranger_role()) { *(&mut counts[1]) = counts[1] + 1 };
        if (r.is_artists_and_repertoire_role()) { *(&mut counts[2]) = counts[2] + 1 };
        if (r.is_choir_role()) { *(&mut counts[3]) = counts[3] + 1 };
        if (r.is_choir_master_role()) { *(&mut counts[4]) = counts[4] + 1 };
        if (r.is_conductor_role()) { *(&mut counts[5]) = counts[5] + 1 };
        if (r.is_contractor_role()) { *(&mut counts[6]) = counts[6] + 1 };
        if (r.is_copyist_role()) { *(&mut counts[7]) = counts[7] + 1 };
        if (r.is_editor_role()) { *(&mut counts[8]) = counts[8] + 1 };
        if (r.is_ensemble_role()) { *(&mut counts[9]) = counts[9] + 1 };
        if (r.is_instrumentalist_role()) { *(&mut counts[10]) = counts[10] + 1 };
        if (r.is_mastering_engineer_role()) { *(&mut counts[11]) = counts[11] + 1 };
        if (r.is_mixing_engineer_role()) { *(&mut counts[12]) = counts[12] + 1 };
        if (r.is_music_director_role()) { *(&mut counts[13]) = counts[13] + 1 };
        if (r.is_music_supervisor_role()) { *(&mut counts[14]) = counts[14] + 1 };
        if (r.is_narrator_role()) { *(&mut counts[15]) = counts[15] + 1 };
        if (r.is_orchestra_role()) { *(&mut counts[16]) = counts[16] + 1 };
        if (r.is_orchestrator_role()) { *(&mut counts[17]) = counts[17] + 1 };
        if (r.is_producer_role()) { *(&mut counts[18]) = counts[18] + 1 };
        if (r.is_programmer_role()) { *(&mut counts[19]) = counts[19] + 1 };
        if (r.is_recording_engineer_role()) { *(&mut counts[20]) = counts[20] + 1 };
        if (r.is_remixing_engineer_role()) { *(&mut counts[21]) = counts[21] + 1 };
        if (r.is_sound_designer_role()) { *(&mut counts[22]) = counts[22] + 1 };
        if (r.is_vocalist_role()) { *(&mut counts[23]) = counts[23] + 1 };
    });
    counts.do_ref!(|c| assert_eq!(*c, 1));
    // name() and level() are total over all variants.
    all.do_ref!(|r| {
        assert!(!r.name().is_empty());
        let _ = r.level();
    });
}

fun all_levels(): vector<rpr::RecordingPartyRoleLevel> {
    vector[
        rpr::new_additional_role_level(),
        rpr::new_assistant_role_level(),
        rpr::new_associate_role_level(),
        rpr::new_backing_role_level(),
        rpr::new_executive_role_level(),
        rpr::new_featured_role_level(),
        rpr::new_lead_role_level(),
        rpr::new_primary_role_level(),
        rpr::new_principal_role_level(),
    ]
}

#[test]
fun each_level_predicate_matches_exactly_one_variant() {
    let all = all_levels();
    let mut counts = vector[];
    9u64.do!(|_| counts.push_back(0u64));
    all.do_ref!(|l| {
        if (l.is_additional_role_level()) { *(&mut counts[0]) = counts[0] + 1 };
        if (l.is_assistant_role_level()) { *(&mut counts[1]) = counts[1] + 1 };
        if (l.is_associate_role_level()) { *(&mut counts[2]) = counts[2] + 1 };
        if (l.is_backing_role_level()) { *(&mut counts[3]) = counts[3] + 1 };
        if (l.is_executive_role_level()) { *(&mut counts[4]) = counts[4] + 1 };
        if (l.is_featured_role_level()) { *(&mut counts[5]) = counts[5] + 1 };
        if (l.is_lead_role_level()) { *(&mut counts[6]) = counts[6] + 1 };
        if (l.is_primary_role_level()) { *(&mut counts[7]) = counts[7] + 1 };
        if (l.is_principal_role_level()) { *(&mut counts[8]) = counts[8] + 1 };
    });
    counts.do_ref!(|c| assert_eq!(*c, 1));
}
