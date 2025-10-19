module musicos::mix;

use musicos::audio::Audio;
use musicos::mix_variant::MixVariant;
use musicos::stem::Stem;

//=== Structs ===

public struct Mix has copy, drop, store {
    variant: MixVariant,
    audio: Audio,
    stems: vector<Stem>,
}

//=== Constants ===

const MAX_STEMS: u64 = 32;

//=== Errors ===

const EMaxStemsExceeded: u64 = 0;

//=== Public Functions ===

public fun new(audio: Audio, variant: MixVariant): Mix {
    Mix {
        variant,
        audio,
        stems: vector[],
    }
}

public fun add_stem(self: &mut Mix, stem: Stem) {
    assert!(self.stems.length() < MAX_STEMS, EMaxStemsExceeded);
    self.stems.push_back(stem);
}

public fun remove_stem(self: &mut Mix, stem_idx: u64): Stem {
    self.stems.remove(stem_idx)
}

//=== Public View Functions ===

public fun audio(self: &Mix): &Audio {
    &self.audio
}

public fun variant(self: &Mix): &MixVariant {
    &self.variant
}

public fun stems(self: &Mix): &vector<Stem> {
    &self.stems
}
