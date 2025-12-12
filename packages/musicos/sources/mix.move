// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::mix;

use musicos::audio::Audio;
use musicos::mix_variant::MixVariant;
use musicos::stem::Stem;

//=== Structs ===

public struct Mix has drop, store {
    variant: MixVariant,
    audio: Audio,
}

//=== Public Functions ===

// Create a new Mix with a Source.
public fun new(audio: Audio, variant: MixVariant): Mix {
    Mix {
        variant,
        audio,
    }
}

//=== Public View Functions ===

public fun variant(self: &Mix): &MixVariant {
    &self.variant
}

public fun audio(self: &Mix): &Audio {
    &self.audio
}
