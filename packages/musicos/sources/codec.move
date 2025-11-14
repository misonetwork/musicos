module musicos::codec;

use musicos::bit_rate::BitRate;
use std::string::String;

public enum Codec has copy, drop, store {
    AAC(BitRate),
    FLAC,
}

//=== Constants ===

const ENotEncodeCompatible: u64 = 0;
const ENotTranscodeCompatible: u64 = 1;
const ENoBitRate: u64 = 2;
const ENotLossless: u64 = 3;
const ENotLossy: u64 = 4;

//=== Public Functions ===

public fun new_aac(bit_rate: BitRate): Codec {
    Codec::AAC(bit_rate)
}

public fun new_flac(): Codec {
    Codec::FLAC
}

//=== Public View Functions ===

public fun bit_rate(self: &Codec): &BitRate {
    match (self) {
        Codec::AAC(bit_rate) => bit_rate,
        Codec::FLAC => abort ENoBitRate,
    }
}

public fun is_encode_compatible(self: &Codec): bool {
    match (self) {
        Codec::AAC(_) => false,
        Codec::FLAC => true,
    }
}

public fun is_transcode_compatible(self: &Codec): bool {
    match (self) {
        Codec::AAC(_) => true,
        Codec::FLAC => false,
    }
}

public fun is_lossless(self: &Codec): bool {
    match (self) {
        Codec::AAC(_) => false,
        Codec::FLAC => true,
    }
}

public fun is_lossy(self: &Codec): bool {
    match (self) {
        Codec::AAC(_) => true,
        Codec::FLAC => false,
    }
}

public fun assert_is_encode_compatible(self: &Codec) {
    assert!(self.is_encode_compatible(), ENotEncodeCompatible);
}

public fun assert_is_transcode_compatible(self: &Codec) {
    assert!(self.is_transcode_compatible(), ENotTranscodeCompatible);
}

public fun assert_is_lossless(self: &Codec) {
    assert!(self.is_lossless(), ENotLossless);
}

public fun assert_is_lossy(self: &Codec) {
    assert!(self.is_lossy(), ENotLossy);
}
