// Copyright (c) Unconfirmed Labs, LLC
// SPDX-License-Identifier: Apache-2.0

/// Represents an individual audio stem within a recording.
/// Stems are isolated audio tracks (e.g., vocals, drums, bass) that
/// together compose the full recording master.
module musicos::stem;

use musicos::audio::Audio;
use std::string::String;
use sui::vec_set;

//=== Structs ===

public struct Stem has drop, store {
    audio: Audio,
    description: String,
    contributors: vector<ID>,
}

//=== Public Functions ===

public fun new(audio: Audio, description: String, contributors: vector<ID>): Stem {
    // Create a Stem. Use VecSet construction to ensure each contributor ID is unique.
    Stem {
        audio,
        description,
        contributors: vec_set::from_keys(contributors).into_keys(),
    }
}

//=== Public View Functions ===

public fun audio(self: &Stem): &Audio {
    &self.audio
}

public fun description(self: &Stem): &String {
    &self.description
}

public fun contributors(self: &Stem): &vector<ID> {
    &self.contributors
}
