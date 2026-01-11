// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents an isolated audio track (stem) from a recording.
/// Stems are individual audio components like vocals, drums, bass, etc.
/// that can be mixed together to create the final recording.
module musicos::stem;

use musicos::audio::Audio;
use std::string::String;

//=== Structs ===

/// An isolated audio track from a recording with a description.
/// Examples: vocal stem, drum stem, bass stem, synth stem.
public struct Stem has drop, store {
    /// The audio data for this stem.
    audio: Audio,
    /// Human-readable description of the stem's contents (e.g., "Lead Vocals").
    description: String,
}

//=== Public Functions ===

/// Creates a new stem with the given audio and description.
public fun new(audio: Audio, description: String): Stem {
    Stem {
        audio,
        description,
    }
}

//=== Public View Functions ===

/// Returns a reference to the stem's audio data.
public fun audio(self: &Stem): &Audio {
    &self.audio
}

/// Returns a reference to the stem's description.
public fun description(self: &Stem): &String {
    &self.description
}
