// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::composition_contributor_role;

use std::string::String;

//=== Enums ===

public enum CompositionContributorRole has copy, drop, store {
    Composer,
    Lyricist,
    Songwriter,
}

//=== Public Functions ===

public fun new_composer(): CompositionContributorRole {
    CompositionContributorRole::Composer
}

public fun new_lyricist(): CompositionContributorRole {
    CompositionContributorRole::Lyricist
}

public fun new_songwriter(): CompositionContributorRole {
    CompositionContributorRole::Songwriter
}

//=== Public View Functions ===

public fun name(self: &CompositionContributorRole): String {
    match (self) {
        CompositionContributorRole::Composer => "Composer",
        CompositionContributorRole::Lyricist => "Lyricist",
        CompositionContributorRole::Songwriter => "Songwriter",
    }
}