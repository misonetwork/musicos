// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/// Defines the roles that contributors can hold on a composition.
/// Compositions are the written musical works (songs, instrumentals),
/// and these roles represent the creative contributions to that work.
///
/// Available roles:
/// - Composer: Created the music/melody
/// - Lyricist: Wrote the lyrics/words
/// - Songwriter: Contributed to both music and lyrics
module musicos::composition_contributor_role;

use std::string::String;

//=== Enums ===

/// Represents a contributor's role on a composition.
public enum CompositionContributorRole has copy, drop, store {
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

//=== Public Functions ===

/// Creates a new Adapter role.
public fun new_adapter_role(): CompositionContributorRole {
    CompositionContributorRole::Adapter
}

/// Creates a new Arranger role.
public fun new_arranger_role(): CompositionContributorRole {
    CompositionContributorRole::Arranger
}

/// Creates a new Composer role.
public fun new_composer_role(): CompositionContributorRole {
    CompositionContributorRole::Composer
}

/// Creates a new Lyricist role.
public fun new_lyricist_role(): CompositionContributorRole {
    CompositionContributorRole::Lyricist
}

/// Creates a new Songwriter role.
public fun new_songwriter_role(): CompositionContributorRole {
    CompositionContributorRole::Songwriter
}

/// Creates a new Translator role.
public fun new_translator_role(): CompositionContributorRole {
    CompositionContributorRole::Translator
}

//=== Public View Functions ===

/// Returns the human-readable name of the role.
public fun name(self: &CompositionContributorRole): String {
    match (self) {
        CompositionContributorRole::Adapter => "Adapter",
        CompositionContributorRole::Arranger => "Arranger",
        CompositionContributorRole::Composer => "Composer",
        CompositionContributorRole::Lyricist => "Lyricist",
        CompositionContributorRole::Songwriter => "Songwriter",
        CompositionContributorRole::Translator => "Translator",
    }
}

public fun is_adapter_role(self: &CompositionContributorRole): bool {
    match (self) {
        CompositionContributorRole::Adapter => true,
        _ => false,
    }
}

public fun is_arranger_role(self: &CompositionContributorRole): bool {
    match (self) {
        CompositionContributorRole::Arranger => true,
        _ => false,
    }
}

public fun is_composer_role(self: &CompositionContributorRole): bool {
    match (self) {
        CompositionContributorRole::Composer => true,
        _ => false,
    }
}

public fun is_lyricist_role(self: &CompositionContributorRole): bool {
    match (self) {
        CompositionContributorRole::Lyricist => true,
        _ => false,
    }
}

public fun is_songwriter_role(self: &CompositionContributorRole): bool {
    match (self) {
        CompositionContributorRole::Songwriter => true,
        _ => false,
    }
}

public fun is_translator_role(self: &CompositionContributorRole): bool {
    match (self) {
        CompositionContributorRole::Translator => true,
        _ => false,
    }
}