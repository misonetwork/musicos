// Copyright (c) Unconfirmed Labs, LLC
// SPDX-License-Identifier: Apache-2.0

/// Defines the roles that parties can hold on a recording.
/// Recordings are audio performances of compositions, and these roles
/// represent the various production and performance contributions.
///
/// Most roles support an optional level (Lead, Assistant, etc.) to
/// indicate the party's seniority or prominence on the recording.
module musicos::recording_party_role;

use std::string::String;

//=== Enums ===

/// Represents a party's role on a recording.
/// Most roles include an optional level to indicate seniority.
public enum RecordingPartyRole has copy, drop, store {
    /// Performed voice acting or spoken word performance.
    Actor(Option<RecordingPartyRoleLevel>),
    /// Arranged the musical parts for the recording.
    Arranger(Option<RecordingPartyRoleLevel>),
    /// A&R representative who discovered or developed the artist.
    ArtistsAndRepertoire,
    /// Performed as part of a choir.
    Choir(Option<RecordingPartyRoleLevel>),
    /// Directed the choir performance.
    ChoirMaster(Option<RecordingPartyRoleLevel>),
    /// Conducted the orchestra or ensemble.
    Conductor(Option<RecordingPartyRoleLevel>),
    /// Hired and managed session musicians.
    Contractor(Option<RecordingPartyRoleLevel>),
    /// Prepared written music parts for performers.
    Copyist,
    /// Edited and compiled audio takes.
    Editor(Option<RecordingPartyRoleLevel>),
    /// Performed as part of a musical ensemble.
    Ensemble(Option<RecordingPartyRoleLevel>),
    /// Played an instrument on the recording. Includes instrument name.
    Instrumentalist(String, Option<RecordingPartyRoleLevel>),
    /// Mastered the final audio for distribution.
    MasteringEngineer(Option<RecordingPartyRoleLevel>),
    /// Mixed the multitrack recording into stereo/surround.
    MixingEngineer(Option<RecordingPartyRoleLevel>),
    /// Directed the musical performance.
    MusicDirector(Option<RecordingPartyRoleLevel>),
    /// Oversaw music selection and licensing.
    MusicSupervisor(Option<RecordingPartyRoleLevel>),
    /// Narrated spoken content.
    Narrator(Option<RecordingPartyRoleLevel>),
    /// Performed as part of an orchestra.
    Orchestra(Option<RecordingPartyRoleLevel>),
    /// Created orchestral arrangements.
    Orchestrator(Option<RecordingPartyRoleLevel>),
    /// Oversaw the creative and technical aspects of the recording.
    Producer(Option<RecordingPartyRoleLevel>),
    /// Programmed beats, synths, or electronic elements.
    Programmer(Option<RecordingPartyRoleLevel>),
    /// Operated recording equipment during sessions.
    RecordingEngineer(Option<RecordingPartyRoleLevel>),
    /// Created a remix of the recording.
    RemixingEngineer(Option<RecordingPartyRoleLevel>),
    /// Created sound effects or sonic textures.
    SoundDesigner(Option<RecordingPartyRoleLevel>),
    /// Provided vocals on the recording.
    Vocalist(Option<RecordingPartyRoleLevel>),
}

/// Indicates the seniority or prominence level of a party.
public enum RecordingPartyRoleLevel has copy, drop, store {
    /// Additional/supplementary party.
    Additional,
    /// Assistant to the primary party.
    Assistant,
    /// Associate-level party.
    Associate,
    /// Backing/support role (e.g., backing vocals).
    Backing,
    /// Executive-level oversight role.
    Executive,
    /// Featured prominently on the recording.
    Featured,
    /// Lead/primary party in this role.
    Lead,
    /// Primary artist on the recording.
    Primary,
    /// Principal party with primary responsibility.
    Principal,
}

//=== Public Functions ===

/// Creates a new Actor role with optional level.
public fun new_actor_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::Actor(level)
}

/// Creates a new Arranger role with optional level.
public fun new_arranger_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::Arranger(level)
}

/// Creates a new Artists & Repertoire role.
public fun new_artists_and_repertoire_role(): RecordingPartyRole {
    RecordingPartyRole::ArtistsAndRepertoire
}

/// Creates a new Choir role with optional level.
public fun new_choir_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::Choir(level)
}

/// Creates a new Choir Master role with optional level.
public fun new_choir_master_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::ChoirMaster(level)
}

/// Creates a new Conductor role with optional level.
public fun new_conductor_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::Conductor(level)
}

/// Creates a new Contractor role with optional level.
public fun new_contractor_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::Contractor(level)
}

/// Creates a new Copyist role.
public fun new_copyist_role(): RecordingPartyRole {
    RecordingPartyRole::Copyist
}

/// Creates a new Editor role with optional level.
public fun new_editor_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::Editor(level)
}

/// Creates a new Ensemble role with optional level.
public fun new_ensemble_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::Ensemble(level)
}

/// Creates a new Instrumentalist role with instrument name and optional level.
public fun new_instrumentalist_role(
    instrument: String,
    level: Option<RecordingPartyRoleLevel>,
): RecordingPartyRole {
    RecordingPartyRole::Instrumentalist(instrument, level)
}

/// Creates a new Mastering Engineer role with optional level.
public fun new_mastering_engineer_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::MasteringEngineer(level)
}

/// Creates a new Mixing Engineer role with optional level.
public fun new_mixing_engineer_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::MixingEngineer(level)
}

/// Creates a new Music Director role with optional level.
public fun new_music_director_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::MusicDirector(level)
}

/// Creates a new Music Supervisor role with optional level.
public fun new_music_supervisor_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::MusicSupervisor(level)
}

/// Creates a new Narrator role with optional level.
public fun new_narrator_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::Narrator(level)
}

/// Creates a new Orchestra role with optional level.
public fun new_orchestra_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::Orchestra(level)
}

/// Creates a new Orchestrator role with optional level.
public fun new_orchestrator_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::Orchestrator(level)
}

/// Creates a new Producer role with optional level.
public fun new_producer_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::Producer(level)
}

/// Creates a new Programmer role with optional level.
public fun new_programmer_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::Programmer(level)
}

/// Creates a new Recording Engineer role with optional level.
public fun new_recording_engineer_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::RecordingEngineer(level)
}

/// Creates a new Remixing Engineer role with optional level.
public fun new_remixing_engineer_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::RemixingEngineer(level)
}

/// Creates a new Sound Designer role with optional level.
public fun new_sound_designer_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::SoundDesigner(level)
}

/// Creates a new Vocalist role with optional level.
public fun new_vocalist_role(level: Option<RecordingPartyRoleLevel>): RecordingPartyRole {
    RecordingPartyRole::Vocalist(level)
}

/// Creates an Additional level.
public fun new_additional_role_level(): RecordingPartyRoleLevel {
    RecordingPartyRoleLevel::Additional
}

/// Creates an Assistant level.
public fun new_assistant_role_level(): RecordingPartyRoleLevel {
    RecordingPartyRoleLevel::Assistant
}

/// Creates an Associate level.
public fun new_associate_role_level(): RecordingPartyRoleLevel {
    RecordingPartyRoleLevel::Associate
}

/// Creates a Backing level.
public fun new_backing_role_level(): RecordingPartyRoleLevel {
    RecordingPartyRoleLevel::Backing
}

/// Creates an Executive level.
public fun new_executive_role_level(): RecordingPartyRoleLevel {
    RecordingPartyRoleLevel::Executive
}

/// Creates a Featured level.
public fun new_featured_role_level(): RecordingPartyRoleLevel {
    RecordingPartyRoleLevel::Featured
}

/// Creates a Lead level.
public fun new_lead_role_level(): RecordingPartyRoleLevel {
    RecordingPartyRoleLevel::Lead
}

/// Creates a Primary level.
public fun new_primary_role_level(): RecordingPartyRoleLevel {
    RecordingPartyRoleLevel::Primary
}

/// Creates a Principal level.
public fun new_principal_role_level(): RecordingPartyRoleLevel {
    RecordingPartyRoleLevel::Principal
}

//=== Public View Functions ===

/// Returns the optional level associated with this role.
public fun level(self: &RecordingPartyRole): Option<RecordingPartyRoleLevel> {
    match (self) {
        RecordingPartyRole::Actor(level) => *level,
        RecordingPartyRole::Arranger(level) => *level,
        RecordingPartyRole::ArtistsAndRepertoire => option::none(),
        RecordingPartyRole::Choir(level) => *level,
        RecordingPartyRole::ChoirMaster(level) => *level,
        RecordingPartyRole::Conductor(level) => *level,
        RecordingPartyRole::Contractor(level) => *level,
        RecordingPartyRole::Copyist => option::none(),
        RecordingPartyRole::Editor(level) => *level,
        RecordingPartyRole::Ensemble(level) => *level,
        RecordingPartyRole::Instrumentalist(_, level) => *level,
        RecordingPartyRole::MasteringEngineer(level) => *level,
        RecordingPartyRole::MixingEngineer(level) => *level,
        RecordingPartyRole::MusicDirector(level) => *level,
        RecordingPartyRole::MusicSupervisor(level) => *level,
        RecordingPartyRole::Narrator(level) => *level,
        RecordingPartyRole::Orchestra(level) => *level,
        RecordingPartyRole::Orchestrator(level) => *level,
        RecordingPartyRole::Producer(level) => *level,
        RecordingPartyRole::Programmer(level) => *level,
        RecordingPartyRole::RecordingEngineer(level) => *level,
        RecordingPartyRole::RemixingEngineer(level) => *level,
        RecordingPartyRole::SoundDesigner(level) => *level,
        RecordingPartyRole::Vocalist(level) => *level,
    }
}

/// Returns the human-readable name of the role.
public fun name(self: &RecordingPartyRole): String {
    match (self) {
        RecordingPartyRole::Actor(_) => "Actor",
        RecordingPartyRole::Arranger(_) => "Arranger",
        RecordingPartyRole::ArtistsAndRepertoire => "Artists & Repertoire",
        RecordingPartyRole::Choir(_) => "Choir",
        RecordingPartyRole::ChoirMaster(_) => "Choir Master",
        RecordingPartyRole::Conductor(_) => "Conductor",
        RecordingPartyRole::Contractor(_) => "Contractor",
        RecordingPartyRole::Copyist => "Copyist",
        RecordingPartyRole::Editor(_) => "Editor",
        RecordingPartyRole::Ensemble(_) => "Ensemble",
        RecordingPartyRole::Instrumentalist(..) => "Instrumentalist",
        RecordingPartyRole::MasteringEngineer(_) => "Mastering Engineer",
        RecordingPartyRole::MixingEngineer(_) => "Mixing Engineer",
        RecordingPartyRole::MusicDirector(_) => "Music Director",
        RecordingPartyRole::MusicSupervisor(_) => "Music Supervisor",
        RecordingPartyRole::Narrator(_) => "Narrator",
        RecordingPartyRole::Orchestra(_) => "Orchestra",
        RecordingPartyRole::Orchestrator(_) => "Orchestrator",
        RecordingPartyRole::Producer(_) => "Producer",
        RecordingPartyRole::Programmer(_) => "Programmer",
        RecordingPartyRole::RecordingEngineer(_) => "Recording Engineer",
        RecordingPartyRole::RemixingEngineer(_) => "Remixing Engineer",
        RecordingPartyRole::SoundDesigner(_) => "Sound Designer",
        RecordingPartyRole::Vocalist(_) => "Vocalist",
    }
}

//=== Role Check Functions ===

/// Returns true if this is an Actor role.
public fun is_actor_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::Actor(_) => true,
        _ => false,
    }
}

/// Returns true if this is an Arranger role.
public fun is_arranger_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::Arranger(_) => true,
        _ => false,
    }
}

/// Returns true if this is an Artists & Repertoire role.
public fun is_artists_and_repertoire_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::ArtistsAndRepertoire => true,
        _ => false,
    }
}

/// Returns true if this is a Choir role.
public fun is_choir_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::Choir(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Choir Master role.
public fun is_choir_master_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::ChoirMaster(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Conductor role.
public fun is_conductor_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::Conductor(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Contractor role.
public fun is_contractor_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::Contractor(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Copyist role.
public fun is_copyist_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::Copyist => true,
        _ => false,
    }
}

/// Returns true if this is an Editor role.
public fun is_editor_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::Editor(_) => true,
        _ => false,
    }
}

/// Returns true if this is an Ensemble role.
public fun is_ensemble_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::Ensemble(_) => true,
        _ => false,
    }
}

/// Returns true if this is an Instrumentalist role.
public fun is_instrumentalist_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::Instrumentalist(..) => true,
        _ => false,
    }
}

/// Returns true if this is a Mastering Engineer role.
public fun is_mastering_engineer_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::MasteringEngineer(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Mixing Engineer role.
public fun is_mixing_engineer_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::MixingEngineer(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Music Director role.
public fun is_music_director_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::MusicDirector(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Music Supervisor role.
public fun is_music_supervisor_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::MusicSupervisor(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Narrator role.
public fun is_narrator_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::Narrator(_) => true,
        _ => false,
    }
}

/// Returns true if this is an Orchestra role.
public fun is_orchestra_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::Orchestra(_) => true,
        _ => false,
    }
}

/// Returns true if this is an Orchestrator role.
public fun is_orchestrator_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::Orchestrator(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Producer role.
public fun is_producer_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::Producer(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Programmer role.
public fun is_programmer_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::Programmer(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Recording Engineer role.
public fun is_recording_engineer_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::RecordingEngineer(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Remixing Engineer role.
public fun is_remixing_engineer_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::RemixingEngineer(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Sound Designer role.
public fun is_sound_designer_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::SoundDesigner(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Vocalist role.
public fun is_vocalist_role(self: &RecordingPartyRole): bool {
    match (self) {
        RecordingPartyRole::Vocalist(_) => true,
        _ => false,
    }
}

//=== Level Check Functions ===

/// Returns true if this is an Additional level.
public fun is_additional_role_level(self: &RecordingPartyRoleLevel): bool {
    match (self) {
        RecordingPartyRoleLevel::Additional => true,
        _ => false,
    }
}

/// Returns true if this is an Assistant level.
public fun is_assistant_role_level(self: &RecordingPartyRoleLevel): bool {
    match (self) {
        RecordingPartyRoleLevel::Assistant => true,
        _ => false,
    }
}

/// Returns true if this is an Associate level.
public fun is_associate_role_level(self: &RecordingPartyRoleLevel): bool {
    match (self) {
        RecordingPartyRoleLevel::Associate => true,
        _ => false,
    }
}

/// Returns true if this is a Backing level.
public fun is_backing_role_level(self: &RecordingPartyRoleLevel): bool {
    match (self) {
        RecordingPartyRoleLevel::Backing => true,
        _ => false,
    }
}

/// Returns true if this is an Executive level.
public fun is_executive_role_level(self: &RecordingPartyRoleLevel): bool {
    match (self) {
        RecordingPartyRoleLevel::Executive => true,
        _ => false,
    }
}

/// Returns true if this is a Featured level.
public fun is_featured_role_level(self: &RecordingPartyRoleLevel): bool {
    match (self) {
        RecordingPartyRoleLevel::Featured => true,
        _ => false,
    }
}

/// Returns true if this is a Lead level.
public fun is_lead_role_level(self: &RecordingPartyRoleLevel): bool {
    match (self) {
        RecordingPartyRoleLevel::Lead => true,
        _ => false,
    }
}

/// Returns true if this is a Primary level.
public fun is_primary_role_level(self: &RecordingPartyRoleLevel): bool {
    match (self) {
        RecordingPartyRoleLevel::Primary => true,
        _ => false,
    }
}

/// Returns true if this is a Principal level.
public fun is_principal_role_level(self: &RecordingPartyRoleLevel): bool {
    match (self) {
        RecordingPartyRoleLevel::Principal => true,
        _ => false,
    }
}
