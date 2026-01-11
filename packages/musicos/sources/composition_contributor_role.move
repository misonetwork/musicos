// Copyright (c) Sona Labs, Inc.
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
    /// Created the musical composition (melody, harmony, structure).
    Composer,
    /// Wrote the lyrics/words for the composition.
    Lyricist,
    /// Contributed to both the music and lyrics.
    Songwriter,
}

//=== Public Functions ===

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

//=== Public View Functions ===

/// Returns the human-readable name of the role.
public fun name(self: &CompositionContributorRole): String {
    match (self) {
        CompositionContributorRole::Composer => "Composer",
        CompositionContributorRole::Lyricist => "Lyricist",
        CompositionContributorRole::Songwriter => "Songwriter",
    }
}
