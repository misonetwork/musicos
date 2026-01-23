// Copyright (c) Studio Mirai, LLC
// Copyright (c) Unconfirmed Labs, LLC
// Copyright (c) Alex Clapworthy
// SPDX-License-Identifier: Apache-2.0

/// Defines the roles that contributors can hold on a recording.
/// Recordings are audio performances of compositions, and these roles
/// represent the various production and performance contributions.
///
/// Most roles support an optional level (Lead, Assistant, etc.) to
/// indicate the contributor's seniority or prominence on the recording.
module musicos::recording_contributor_role;

use std::string::String;

//=== Enums ===

/// Represents a contributor's role on a recording.
/// Most roles include an optional level to indicate seniority.
public enum RecordingContributorRole has copy, drop, store {
    /// Performed voice acting or spoken word performance.
    Actor(Option<RecordingContributorLevel>),
    /// Arranged the musical parts for the recording.
    Arranger(Option<RecordingContributorLevel>),
    /// A&R representative who discovered or developed the artist.
    ArtistsAndRepertoire,
    /// Performed as part of a choir.
    Choir(Option<RecordingContributorLevel>),
    /// Directed the choir performance.
    ChoirMaster(Option<RecordingContributorLevel>),
    /// Conducted the orchestra or ensemble.
    Conductor(Option<RecordingContributorLevel>),
    /// Hired and managed session musicians.
    Contractor(Option<RecordingContributorLevel>),
    /// Prepared written music parts for performers.
    Copyist,
    /// Edited and compiled audio takes.
    Editor(Option<RecordingContributorLevel>),
    /// Performed as part of a musical ensemble.
    Ensemble(Option<RecordingContributorLevel>),
    /// Played an instrument on the recording. Includes instrument name.
    Instrumentalist(String, Option<RecordingContributorLevel>),
    /// Mastered the final audio for distribution.
    MasteringEngineer(Option<RecordingContributorLevel>),
    /// Mixed the multitrack recording into stereo/surround.
    MixingEngineer(Option<RecordingContributorLevel>),
    /// Directed the musical performance.
    MusicDirector(Option<RecordingContributorLevel>),
    /// Oversaw music selection and licensing.
    MusicSupervisor(Option<RecordingContributorLevel>),
    /// Narrated spoken content.
    Narrator(Option<RecordingContributorLevel>),
    /// Performed as part of an orchestra.
    Orchestra(Option<RecordingContributorLevel>),
    /// Created orchestral arrangements.
    Orchestrator(Option<RecordingContributorLevel>),
    /// Oversaw the creative and technical aspects of the recording.
    Producer(Option<RecordingContributorLevel>),
    /// Programmed beats, synths, or electronic elements.
    Programmer(Option<RecordingContributorLevel>),
    /// Operated recording equipment during sessions.
    RecordingEngineer(Option<RecordingContributorLevel>),
    /// Created a remix of the recording.
    RemixingEngineer(Option<RecordingContributorLevel>),
    /// Created sound effects or sonic textures.
    SoundDesigner(Option<RecordingContributorLevel>),
    /// Provided vocals on the recording.
    Vocalist(Option<RecordingContributorLevel>),
}

/// Indicates the seniority or prominence level of a contributor.
public enum RecordingContributorLevel has copy, drop, store {
    /// Additional/supplementary contributor.
    Additional,
    /// Assistant to the primary contributor.
    Assistant,
    /// Associate-level contributor.
    Associate,
    /// Backing/support role (e.g., backing vocals).
    Backing,
    /// Executive-level oversight role.
    Executive,
    /// Featured prominently on the recording.
    Featured,
    /// Lead/primary contributor in this role.
    Lead,
    /// Primary artist on the recording.
    Primary,
    /// Principal contributor with primary responsibility.
    Principal,
}

//=== Public Functions ===

/// Creates a new Actor role with optional level.
public fun new_actor_role(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Actor(level)
}

/// Creates a new Arranger role with optional level.
public fun new_arranger_role(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Arranger(level)
}

/// Creates a new Artists & Repertoire role.
public fun new_artists_and_repertoire_role(): RecordingContributorRole {
    RecordingContributorRole::ArtistsAndRepertoire
}

/// Creates a new Choir role with optional level.
public fun new_choir_role(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Choir(level)
}

/// Creates a new Choir Master role with optional level.
public fun new_choir_master_role(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::ChoirMaster(level)
}

/// Creates a new Conductor role with optional level.
public fun new_conductor_role(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Conductor(level)
}

/// Creates a new Contractor role with optional level.
public fun new_contractor_role(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Contractor(level)
}

/// Creates a new Copyist role.
public fun new_copyist_role(): RecordingContributorRole {
    RecordingContributorRole::Copyist
}

/// Creates a new Editor role with optional level.
public fun new_editor_role(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Editor(level)
}

/// Creates a new Ensemble role with optional level.
public fun new_ensemble_role(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Ensemble(level)
}

/// Creates a new Instrumentalist role with instrument name and optional level.
public fun new_instrumentalist_role(
    instrument: String,
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::Instrumentalist(instrument, level)
}

/// Creates a new Mastering Engineer role with optional level.
public fun new_mastering_engineer_role(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::MasteringEngineer(level)
}

/// Creates a new Mixing Engineer role with optional level.
public fun new_mixing_engineer_role(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::MixingEngineer(level)
}

/// Creates a new Music Director role with optional level.
public fun new_music_director_role(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::MusicDirector(level)
}

/// Creates a new Music Supervisor role with optional level.
public fun new_music_supervisor_role(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::MusicSupervisor(level)
}

/// Creates a new Narrator role with optional level.
public fun new_narrator_role(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Narrator(level)
}

/// Creates a new Orchestra role with optional level.
public fun new_orchestra_role(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Orchestra(level)
}

/// Creates a new Orchestrator role with optional level.
public fun new_orchestrator_role(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::Orchestrator(level)
}

/// Creates a new Producer role with optional level.
public fun new_producer_role(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Producer(level)
}

/// Creates a new Programmer role with optional level.
public fun new_programmer_role(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Programmer(level)
}

/// Creates a new Recording Engineer role with optional level.
public fun new_recording_engineer_role(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::RecordingEngineer(level)
}

/// Creates a new Remixing Engineer role with optional level.
public fun new_remixing_engineer_role(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::RemixingEngineer(level)
}

/// Creates a new Sound Designer role with optional level.
public fun new_sound_designer_role(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::SoundDesigner(level)
}

/// Creates a new Vocalist role with optional level.
public fun new_vocalist_role(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Vocalist(level)
}

/// Creates an Additional level.
public fun new_additional_level(): RecordingContributorLevel {
    RecordingContributorLevel::Additional
}

/// Creates an Assistant level.
public fun new_assistant_level(): RecordingContributorLevel {
    RecordingContributorLevel::Assistant
}

/// Creates an Associate level.
public fun new_associate_level(): RecordingContributorLevel {
    RecordingContributorLevel::Associate
}

/// Creates a Backing level.
public fun new_backing_level(): RecordingContributorLevel {
    RecordingContributorLevel::Backing
}

/// Creates an Executive level.
public fun new_executive_level(): RecordingContributorLevel {
    RecordingContributorLevel::Executive
}

/// Creates a Featured level.
public fun new_featured_level(): RecordingContributorLevel {
    RecordingContributorLevel::Featured
}

/// Creates a Lead level.
public fun new_lead_level(): RecordingContributorLevel {
    RecordingContributorLevel::Lead
}

/// Creates a Principal level.
public fun new_principal_level(): RecordingContributorLevel {
    RecordingContributorLevel::Principal
}

//=== Public View Functions ===

/// Returns the optional level associated with this role.
public fun level(self: &RecordingContributorRole): Option<RecordingContributorLevel> {
    match (self) {
        RecordingContributorRole::Actor(level) => *level,
        RecordingContributorRole::Arranger(level) => *level,
        RecordingContributorRole::ArtistsAndRepertoire => option::none(),
        RecordingContributorRole::Choir(level) => *level,
        RecordingContributorRole::ChoirMaster(level) => *level,
        RecordingContributorRole::Conductor(level) => *level,
        RecordingContributorRole::Contractor(level) => *level,
        RecordingContributorRole::Copyist => option::none(),
        RecordingContributorRole::Editor(level) => *level,
        RecordingContributorRole::Ensemble(level) => *level,
        RecordingContributorRole::Instrumentalist(_, level) => *level,
        RecordingContributorRole::MasteringEngineer(level) => *level,
        RecordingContributorRole::MixingEngineer(level) => *level,
        RecordingContributorRole::MusicDirector(level) => *level,
        RecordingContributorRole::MusicSupervisor(level) => *level,
        RecordingContributorRole::Narrator(level) => *level,
        RecordingContributorRole::Orchestra(level) => *level,
        RecordingContributorRole::Orchestrator(level) => *level,
        RecordingContributorRole::Producer(level) => *level,
        RecordingContributorRole::Programmer(level) => *level,
        RecordingContributorRole::RecordingEngineer(level) => *level,
        RecordingContributorRole::RemixingEngineer(level) => *level,
        RecordingContributorRole::SoundDesigner(level) => *level,
        RecordingContributorRole::Vocalist(level) => *level,
    }
}

/// Returns the human-readable name of the role.
public fun name(self: &RecordingContributorRole): String {
    match (self) {
        RecordingContributorRole::Actor(_) => "Actor",
        RecordingContributorRole::Arranger(_) => "Arranger",
        RecordingContributorRole::ArtistsAndRepertoire => "Artists & Repertoire",
        RecordingContributorRole::Choir(_) => "Choir",
        RecordingContributorRole::ChoirMaster(_) => "Choir Master",
        RecordingContributorRole::Conductor(_) => "Conductor",
        RecordingContributorRole::Contractor(_) => "Contractor",
        RecordingContributorRole::Copyist => "Copyist",
        RecordingContributorRole::Editor(_) => "Editor",
        RecordingContributorRole::Ensemble(_) => "Ensemble",
        RecordingContributorRole::Instrumentalist(..) => "Instrumentalist",
        RecordingContributorRole::MasteringEngineer(_) => "Mastering Engineer",
        RecordingContributorRole::MixingEngineer(_) => "Mixing Engineer",
        RecordingContributorRole::MusicDirector(_) => "Music Director",
        RecordingContributorRole::MusicSupervisor(_) => "Music Supervisor",
        RecordingContributorRole::Narrator(_) => "Narrator",
        RecordingContributorRole::Orchestra(_) => "Orchestra",
        RecordingContributorRole::Orchestrator(_) => "Orchestrator",
        RecordingContributorRole::Producer(_) => "Producer",
        RecordingContributorRole::Programmer(_) => "Programmer",
        RecordingContributorRole::RecordingEngineer(_) => "Recording Engineer",
        RecordingContributorRole::RemixingEngineer(_) => "Remixing Engineer",
        RecordingContributorRole::SoundDesigner(_) => "Sound Designer",
        RecordingContributorRole::Vocalist(_) => "Vocalist",
    }
}

//=== Role Check Functions ===

/// Returns true if this is an Actor role.
public fun is_actor_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::Actor(_) => true,
        _ => false,
    }
}

/// Returns true if this is an Arranger role.
public fun is_arranger_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::Arranger(_) => true,
        _ => false,
    }
}

/// Returns true if this is an Artists & Repertoire role.
public fun is_artists_and_repertoire_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::ArtistsAndRepertoire => true,
        _ => false,
    }
}

/// Returns true if this is a Choir role.
public fun is_choir_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::Choir(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Choir Master role.
public fun is_choir_master_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::ChoirMaster(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Conductor role.
public fun is_conductor_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::Conductor(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Contractor role.
public fun is_contractor_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::Contractor(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Copyist role.
public fun is_copyist_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::Copyist => true,
        _ => false,
    }
}

/// Returns true if this is an Editor role.
public fun is_editor_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::Editor(_) => true,
        _ => false,
    }
}

/// Returns true if this is an Ensemble role.
public fun is_ensemble_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::Ensemble(_) => true,
        _ => false,
    }
}

/// Returns true if this is an Instrumentalist role.
public fun is_instrumentalist_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::Instrumentalist(..) => true,
        _ => false,
    }
}

/// Returns true if this is a Mastering Engineer role.
public fun is_mastering_engineer_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::MasteringEngineer(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Mixing Engineer role.
public fun is_mixing_engineer_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::MixingEngineer(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Music Director role.
public fun is_music_director_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::MusicDirector(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Music Supervisor role.
public fun is_music_supervisor_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::MusicSupervisor(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Narrator role.
public fun is_narrator_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::Narrator(_) => true,
        _ => false,
    }
}

/// Returns true if this is an Orchestra role.
public fun is_orchestra_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::Orchestra(_) => true,
        _ => false,
    }
}

/// Returns true if this is an Orchestrator role.
public fun is_orchestrator_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::Orchestrator(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Producer role.
public fun is_producer_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::Producer(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Programmer role.
public fun is_programmer_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::Programmer(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Recording Engineer role.
public fun is_recording_engineer_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::RecordingEngineer(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Remixing Engineer role.
public fun is_remixing_engineer_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::RemixingEngineer(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Sound Designer role.
public fun is_sound_designer_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::SoundDesigner(_) => true,
        _ => false,
    }
}

/// Returns true if this is a Vocalist role.
public fun is_vocalist_role(self: &RecordingContributorRole): bool {
    match (self) {
        RecordingContributorRole::Vocalist(_) => true,
        _ => false,
    }
}

//=== Level Check Functions ===

/// Returns true if this is an Additional level.
public fun is_additional_level(self: &RecordingContributorLevel): bool {
    match (self) {
        RecordingContributorLevel::Additional => true,
        _ => false,
    }
}

/// Returns true if this is an Assistant level.
public fun is_assistant_level(self: &RecordingContributorLevel): bool {
    match (self) {
        RecordingContributorLevel::Assistant => true,
        _ => false,
    }
}

/// Returns true if this is an Associate level.
public fun is_associate_level(self: &RecordingContributorLevel): bool {
    match (self) {
        RecordingContributorLevel::Associate => true,
        _ => false,
    }
}

/// Returns true if this is a Backing level.
public fun is_backing_level(self: &RecordingContributorLevel): bool {
    match (self) {
        RecordingContributorLevel::Backing => true,
        _ => false,
    }
}

/// Returns true if this is an Executive level.
public fun is_executive_level(self: &RecordingContributorLevel): bool {
    match (self) {
        RecordingContributorLevel::Executive => true,
        _ => false,
    }
}

/// Returns true if this is a Featured level.
public fun is_featured_level(self: &RecordingContributorLevel): bool {
    match (self) {
        RecordingContributorLevel::Featured => true,
        _ => false,
    }
}

/// Returns true if this is a Lead level.
public fun is_lead_level(self: &RecordingContributorLevel): bool {
    match (self) {
        RecordingContributorLevel::Lead => true,
        _ => false,
    }
}

/// Returns true if this is a Primary level.
public fun is_primary_level(self: &RecordingContributorLevel): bool {
    match (self) {
        RecordingContributorLevel::Primary => true,
        _ => false,
    }
}

/// Returns true if this is a Principal level.
public fun is_principal_level(self: &RecordingContributorLevel): bool {
    match (self) {
        RecordingContributorLevel::Principal => true,
        _ => false,
    }
}