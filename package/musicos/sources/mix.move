module musicos::mix;

use musicos::audio::Audio;
use musicos::mix_variant::MixVariant;
use musicos::source::Source;
use musicos::stem::Stem;

//=== Structs ===

public struct Mix has copy, drop, store {
    variant: MixVariant,
    encode: Source,
    transcodes: vector<Source>,
    stems: vector<Stem>,
}

//=== Constants ===

const MAX_STEMS: u64 = 32;
const MAX_TRANSCODES: u64 = 10;

//=== Errors ===

const EMaxTranscodesExceeded: u64 = 0;
const EMaxStemsExceeded: u64 = 1;

//=== Public Functions ===

// Create a new Mix with an Encoded Source (lossless).
public fun new(source: Source, variant: MixVariant): Mix {
    source.assert_is_encode();
    Mix {
        variant,
        encode: source,
        transcodes: vector[],
        stems: vector[],
    }
}

// Add a transcoded Source to the Mix (lossless or lossy).
public fun add_transcode(self: &mut Mix, source: Source) {
    source.assert_is_transcode();
    assert!(self.transcodes.length() < MAX_TRANSCODES, EMaxTranscodesExceeded);
    self.transcodes.push_back(source);
}

public fun remove_trancode(self: &mut Mix, source_idx: u64): Source {
    self.sources.remove(source_idx)
}

public fun add_stem(self: &mut Mix, stem: Stem) {
    assert!(self.stems.length() < MAX_STEMS, EMaxStemsExceeded);
    self.stems.push_back(stem);
}

public fun remove_stem(self: &mut Mix, stem_idx: u64): Stem {
    self.stems.remove(stem_idx)
}

//=== Public View Functions ===

public fun variant(self: &Mix): &MixVariant {
    &self.variant
}

public fun encode(self: &Mix): &Source {
    &self.encode
}

public fun transcodes(self: &Mix): &vector<Source> {
    &self.transcodes
}

public fun stems(self: &Mix): &vector<Stem> {
    &self.stems
}
