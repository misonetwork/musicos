// Copyright (c) Unconfirmed Labs, LLC
// SPDX-License-Identifier: Apache-2.0

/// Represents an individual audio stem within a recording.
/// Stems are isolated audio tracks (e.g., vocals, drums, bass) that
/// together compose the full recording master.
module musicos::stem;

use musicos::audio::Audio;
use std::string::String;

//=== Structs ===

public struct Stem has drop, store {
    audio: Audio,
    description: String,
}

//=== Public Functions ===

public fun new(audio: Audio, description: String): Stem {
    Stem {
        audio,
        description,
    }
}

//=== Public View Functions ===

public fun audio(self: &Stem): &Audio {
    &self.audio
}

public fun description(self: &Stem): &String {
    &self.description
}
