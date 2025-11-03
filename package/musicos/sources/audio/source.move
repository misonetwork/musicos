module musicos::source;

use musicos::audio::Audio;
use musicos::bit_rate::BitRate;
use musicos::codec::Codec;

//=== Structs ===

public struct Source has drop, store {
    kind: SourceKind,
    audio: Audio,
    codec: Codec,
    bit_rate: BitRate,
}

//=== Enums ===

public enum SourceKind has copy, drop, store {
    Encode,
    Transcode,
}

//=== Constants ===

const ENotEncode: u64 = 0;
const ENotTranscode: u64 = 1;

//=== Public Functions ===

public fun new(kind: SourceKind, audio: Audio, codec: Codec, bit_rate: BitRate): Source {
    // Assert the Codec is compatible with the Source kind.
    match (kind) {
        SourceKind::Encode => codec.assert_is_encode_compatible(),
        SourceKind::Transcode => codec.assert_is_transcode_compatible(),
    };

    Source {
        kind,
        audio,
        codec,
        bit_rate,
    }
}

//=== Public View Functions ===

public fun audio(self: &Source): &Audio {
    &self.audio
}

public fun codec(self: &Source): &Codec {
    &self.codec
}

public fun bit_rate(self: &Source): &BitRate {
    &self.bit_rate
}

public fun is_encode(self: &Source): bool {
    match (self.kind) {
        SourceKind::Encode => true,
        _ => false,
    }
}

public fun is_transcode(self: &Source): bool {
    match (self.kind) {
        SourceKind::Transcode => true,
        _ => false,
    }
}

//=== Assert Functions ===

public fun assert_is_encode(self: &Source) {
    assert!(self.is_encode(), ENotEncode);
}

public fun assert_is_transcode(self: &Source) {
    assert!(self.is_transcode(), ENotTranscode);
}
