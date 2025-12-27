// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::recording_contributor_role;

use std::string::String;

//=== Enums ===

public enum RecordingContributorRole has copy, drop, store {
    Arranger(Option<RecordingContributorLevel>),
    ArtistsAndRepertoire,
    Contractor(Option<RecordingContributorLevel>),
    Copyist,
    Instrumentalist(String, Option<RecordingContributorLevel>),
    MasteringEngineer(Option<RecordingContributorLevel>),
    MixingEngineer(Option<RecordingContributorLevel>),
    MusicDirector(Option<RecordingContributorLevel>),
    MusicSupervisor(Option<RecordingContributorLevel>),
    Orchestrator(Option<RecordingContributorLevel>),
    Performer(Option<RecordingContributorLevel>),
    Producer(Option<RecordingContributorLevel>),
    RecordingEngineer(Option<RecordingContributorLevel>),
    SoundDesigner(Option<RecordingContributorLevel>),
    Vocalist(Option<RecordingContributorLevel>),
}

public enum RecordingContributorLevel has copy, drop, store {
    Additional,
    Assistant,
    Associate,
    Backing,
    Executive,
    Featured,
    Lead,
    Principal,
}

//=== Public Functions ===

public fun new_arranger_role(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Arranger(level)
}

public fun new_artists_and_repertoire_role(): RecordingContributorRole {
    RecordingContributorRole::ArtistsAndRepertoire
}

public fun new_contractor_role(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Contractor(level)
}

public fun new_copyist_role(): RecordingContributorRole {
    RecordingContributorRole::Copyist
}

public fun new_instrumentalist_role(
    instrument: String,
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::Instrumentalist(instrument, level)
}

public fun new_mastering_engineer_role(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::MasteringEngineer(level)
}

public fun new_mixing_engineer_role(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::MixingEngineer(level)
}

public fun new_music_director_role(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::MusicDirector(level)
}

public fun new_music_supervisor_role(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::MusicSupervisor(level)
}

public fun new_orchestrator_role(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::Orchestrator(level)
}

public fun new_producer_role(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Producer(level)
}

public fun new_recording_engineer_role(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::RecordingEngineer(level)
}

public fun new_sound_designer_role(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::SoundDesigner(level)
}

public fun new_vocalist_role(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Vocalist(level)
}

public fun new_additional_level(): RecordingContributorLevel {
    RecordingContributorLevel::Additional
}

public fun new_assistant_level(): RecordingContributorLevel {
    RecordingContributorLevel::Assistant
}

public fun new_associate_level(): RecordingContributorLevel {
    RecordingContributorLevel::Associate
}

public fun new_backing_level(): RecordingContributorLevel {
    RecordingContributorLevel::Backing
}

public fun new_executive_level(): RecordingContributorLevel {
    RecordingContributorLevel::Executive
}

public fun new_featured_level(): RecordingContributorLevel {
    RecordingContributorLevel::Featured
}

public fun new_lead_level(): RecordingContributorLevel {
    RecordingContributorLevel::Lead
}

public fun new_principal_level(): RecordingContributorLevel {
    RecordingContributorLevel::Principal
}

//=== Public View Functions ===

public fun level(self: &RecordingContributorRole): Option<RecordingContributorLevel> {
    match (self) {
        RecordingContributorRole::Arranger(level) => *level,
        RecordingContributorRole::ArtistsAndRepertoire => option::none(),
        RecordingContributorRole::Contractor(level) => *level,
        RecordingContributorRole::Copyist => option::none(),
        RecordingContributorRole::Instrumentalist(_, level) => *level,
        RecordingContributorRole::MasteringEngineer(level) => *level,
        RecordingContributorRole::MixingEngineer(level) => *level,
        RecordingContributorRole::MusicDirector(level) => *level,
        RecordingContributorRole::MusicSupervisor(level) => *level,
        RecordingContributorRole::Orchestrator(level) => *level,
        RecordingContributorRole::Performer(level) => *level,
        RecordingContributorRole::Producer(level) => *level,
        RecordingContributorRole::RecordingEngineer(level) => *level,
        RecordingContributorRole::SoundDesigner(level) => *level,
        RecordingContributorRole::Vocalist(level) => *level,
    }
}

public fun name(self: &RecordingContributorRole): String {
    match (self) {
        RecordingContributorRole::Arranger(_) => b"Arranger".to_string(),
        RecordingContributorRole::ArtistsAndRepertoire => b"Artists & Repertoire".to_string(),
        RecordingContributorRole::Contractor(_) => b"Contractor".to_string(),
        RecordingContributorRole::Copyist => b"Copyist".to_string(),
        RecordingContributorRole::Instrumentalist(..) => b"Instrumentalist".to_string(),
        RecordingContributorRole::MasteringEngineer(_) => b"Mastering Engineer".to_string(),
        RecordingContributorRole::MixingEngineer(_) => b"Mixing Engineer".to_string(),
        RecordingContributorRole::MusicDirector(_) => b"Music Director".to_string(),
        RecordingContributorRole::MusicSupervisor(_) => b"Music Supervisor".to_string(),
        RecordingContributorRole::Orchestrator(_) => b"Orchestrator".to_string(),
        RecordingContributorRole::Performer(_) => b"Performer".to_string(),
        RecordingContributorRole::Producer(_) => b"Producer".to_string(),
        RecordingContributorRole::RecordingEngineer(_) => b"Recording Engineer".to_string(),
        RecordingContributorRole::SoundDesigner(_) => b"Sound Designer".to_string(),
        RecordingContributorRole::Vocalist(_) => b"Vocalist".to_string(),
    }
}
