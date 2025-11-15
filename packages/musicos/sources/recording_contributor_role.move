module musicos::recording_contributor_role;

use std::string::String;

//=== Enums ===

public enum RecordingContributorRole has copy, drop, store {
    Arranger(String, Option<RecordingContributorLevel>),
    ArtistsAndRepertoire(String),
    Contractor(String, Option<RecordingContributorLevel>),
    Copyist(String),
    Instrumentalist(String, String, Option<RecordingContributorLevel>),
    MasteringEngineer(String, Option<RecordingContributorLevel>),
    MixingEngineer(String, Option<RecordingContributorLevel>),
    MusicDirector(String, Option<RecordingContributorLevel>),
    MusicSupervisor(String, Option<RecordingContributorLevel>),
    Orchestrator(String, Option<RecordingContributorLevel>),
    Performer(String, Option<RecordingContributorLevel>),
    Producer(String, Option<RecordingContributorLevel>),
    RecordingEngineer(String, Option<RecordingContributorLevel>),
    SoundDesigner(String, Option<RecordingContributorLevel>),
    Vocalist(String, Option<RecordingContributorLevel>),
}

public enum RecordingContributorLevel has copy, drop, store {
    Additional,
    Assistant,
    Associate,
    Backing,
    Executive,
    Lead,
    Principal,
}

//=== Public Functions ===

public fun new_role_arranger(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Arranger(b"Arranger".to_string(), level)
}

public fun new_role_artists_and_repertoire(): RecordingContributorRole {
    RecordingContributorRole::ArtistsAndRepertoire(b"Artists & Repertoire".to_string())
}

public fun new_role_contractor(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Contractor(b"Contractor".to_string(), level)
}

public fun new_role_copyist(): RecordingContributorRole {
    RecordingContributorRole::Copyist(b"Copyist".to_string())
}

public fun new_role_instrumentalist(
    instrument: String,
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::Instrumentalist(b"Instrumentalist".to_string(), instrument, level)
}

public fun new_role_mastering_engineer(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::MasteringEngineer(b"Mastering Engineer".to_string(), level)
}

public fun new_role_mixing_engineer(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::MixingEngineer(b"Mixing Engineer".to_string(), level)
}

public fun new_role_music_director(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::MusicDirector(b"Music Director".to_string(), level)
}

public fun new_role_music_supervisor(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::MusicSupervisor(b"Music Supervisor".to_string(), level)
}

public fun new_role_orchestrator(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::Orchestrator(b"Orchestrator".to_string(), level)
}

public fun new_role_producer(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Producer(b"Producer".to_string(), level)
}

public fun new_role_recording_engineer(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::RecordingEngineer(b"Recording Engineer".to_string(), level)
}

public fun new_role_sound_designer(
    level: Option<RecordingContributorLevel>,
): RecordingContributorRole {
    RecordingContributorRole::SoundDesigner(b"Sound Designer".to_string(), level)
}

public fun new_role_vocalist(level: Option<RecordingContributorLevel>): RecordingContributorRole {
    RecordingContributorRole::Vocalist(b"Vocalist".to_string(), level)
}

//=== Public View Functions ===

public fun level(self: &RecordingContributorRole): Option<RecordingContributorLevel> {
    match (self) {
        RecordingContributorRole::Arranger(_, level) => *level,
        RecordingContributorRole::ArtistsAndRepertoire(_) => option::none(),
        RecordingContributorRole::Contractor(_, level) => *level,
        RecordingContributorRole::Copyist(_) => option::none(),
        RecordingContributorRole::Instrumentalist(_, _, level) => *level,
        RecordingContributorRole::MasteringEngineer(_, level) => *level,
        RecordingContributorRole::MixingEngineer(_, level) => *level,
        RecordingContributorRole::MusicDirector(_, level) => *level,
        RecordingContributorRole::MusicSupervisor(_, level) => *level,
        RecordingContributorRole::Orchestrator(_, level) => *level,
        RecordingContributorRole::Performer(_, level) => *level,
        RecordingContributorRole::Producer(_, level) => *level,
        RecordingContributorRole::RecordingEngineer(_, level) => *level,
        RecordingContributorRole::SoundDesigner(_, level) => *level,
        RecordingContributorRole::Vocalist(_, level) => *level,
    }
}

public fun name(self: &RecordingContributorRole): String {
    match (self) {
        RecordingContributorRole::Arranger(name, _) => *name,
        RecordingContributorRole::ArtistsAndRepertoire(name) => *name,
        RecordingContributorRole::Contractor(name, _) => *name,
        RecordingContributorRole::Copyist(name) => *name,
        RecordingContributorRole::Instrumentalist(name, _, _) => *name,
        RecordingContributorRole::MasteringEngineer(name, _) => *name,
        RecordingContributorRole::MixingEngineer(name, _) => *name,
        RecordingContributorRole::MusicDirector(name, _) => *name,
        RecordingContributorRole::MusicSupervisor(name, _) => *name,
        RecordingContributorRole::Orchestrator(name, _) => *name,
        RecordingContributorRole::Performer(name, _) => *name,
        RecordingContributorRole::Producer(name, _) => *name,
        RecordingContributorRole::RecordingEngineer(name, _) => *name,
        RecordingContributorRole::SoundDesigner(name, _) => *name,
        RecordingContributorRole::Vocalist(name, _) => *name,
    }
}
