// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::stem;

use musicos::audio::Audio;
use std::string::String;

public struct Stem has drop, store {
    audio: Audio,
    description: String,
}

public fun new(audio: Audio, description: String): Stem {
    Stem {
        audio,
        description,
    }
}

public fun audio(self: &Stem): &Audio {
    &self.audio
}

public fun description(self: &Stem): &String {
    &self.description
}
