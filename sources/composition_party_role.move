// Copyright (c) Unconfirmed Labs, LLC
// SPDX-License-Identifier: Apache-2.0

/// Defines the roles that parties can hold on a composition.
/// Compositions are the written musical works (songs, instrumentals),
/// and these roles represent the creative contributions to that work.
///
/// Available roles:
/// - Composer: Created the music/melody
/// - Lyricist: Wrote the lyrics/words
/// - Songwriter: Contributed to both music and lyrics
module musicos::composition_party_role;

use std::string::String;

// === Enums ===

/// Represents a party's role on a composition.
public enum CompositionPartyRole has copy, drop, store {
    /// Adapted the musical composition for a specific instrument or voice.
    Adapter,
    /// Arranged the musical composition.
    Arranger,
    /// Created the musical composition (melody, harmony, structure).
    Composer,
    /// Wrote the lyrics/words for the composition.
    Lyricist,
    /// Contributed to both the music and lyrics.
    Songwriter,
    /// Translated the musical composition into a different language.
    Translator,
}

// === Public Functions ===

/// Creates a new Adapter role.
public fun new_adapter_role(): CompositionPartyRole {
    CompositionPartyRole::Adapter
}

/// Creates a new Arranger role.
public fun new_arranger_role(): CompositionPartyRole {
    CompositionPartyRole::Arranger
}

/// Creates a new Composer role.
public fun new_composer_role(): CompositionPartyRole {
    CompositionPartyRole::Composer
}

/// Creates a new Lyricist role.
public fun new_lyricist_role(): CompositionPartyRole {
    CompositionPartyRole::Lyricist
}

/// Creates a new Songwriter role.
public fun new_songwriter_role(): CompositionPartyRole {
    CompositionPartyRole::Songwriter
}

/// Creates a new Translator role.
public fun new_translator_role(): CompositionPartyRole {
    CompositionPartyRole::Translator
}

// === Public View Functions ===

/// Returns the human-readable name of the role.
public fun name(self: &CompositionPartyRole): String {
    match (self) {
        CompositionPartyRole::Adapter => "Adapter",
        CompositionPartyRole::Arranger => "Arranger",
        CompositionPartyRole::Composer => "Composer",
        CompositionPartyRole::Lyricist => "Lyricist",
        CompositionPartyRole::Songwriter => "Songwriter",
        CompositionPartyRole::Translator => "Translator",
    }
}

/// Returns true if this is an Adapter role.
public fun is_adapter_role(self: &CompositionPartyRole): bool {
    match (self) {
        CompositionPartyRole::Adapter => true,
        _ => false,
    }
}

/// Returns true if this is an Arranger role.
public fun is_arranger_role(self: &CompositionPartyRole): bool {
    match (self) {
        CompositionPartyRole::Arranger => true,
        _ => false,
    }
}

/// Returns true if this is a Composer role.
public fun is_composer_role(self: &CompositionPartyRole): bool {
    match (self) {
        CompositionPartyRole::Composer => true,
        _ => false,
    }
}

/// Returns true if this is a Lyricist role.
public fun is_lyricist_role(self: &CompositionPartyRole): bool {
    match (self) {
        CompositionPartyRole::Lyricist => true,
        _ => false,
    }
}

/// Returns true if this is a Songwriter role.
public fun is_songwriter_role(self: &CompositionPartyRole): bool {
    match (self) {
        CompositionPartyRole::Songwriter => true,
        _ => false,
    }
}

/// Returns true if this is a Translator role.
public fun is_translator_role(self: &CompositionPartyRole): bool {
    match (self) {
        CompositionPartyRole::Translator => true,
        _ => false,
    }
}
