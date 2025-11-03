module musicos::codec;

use std::string::String;

public enum Codec has copy, drop, store {
    AAC(String),
    ALAC(String),
    AIFF(String),
    DSD(String),
    FLAC(String),
    MP3(String),
    OPUS(String),
    WAV(String),
}

public fun new_aac(): Codec {
    Codec::AAC(b"AAC".to_string())
}

public fun new_alac(): Codec {
    Codec::ALAC(b"ALAC".to_string())
}

public fun new_aiff(): Codec {
    Codec::AIFF(b"AIFF".to_string())
}

public fun new_dsd(): Codec {
    Codec::DSD(b"DSD".to_string())
}

public fun new_flac(): Codec {
    Codec::FLAC(b"FLAC".to_string())
}

public fun new_mp3(): Codec {
    Codec::MP3(b"MP3".to_string())
}

public fun new_opus(): Codec {
    Codec::OPUS(b"OPUS".to_string())
}

public fun new_wav(): Codec {
    Codec::WAV(b"WAV".to_string())
}

//=== Public View Functions ===

public fun is_encode_compatible(self: &Codec): bool {
    match (self) {
        Codec::AAC(_) => false,
        Codec::ALAC(_) => false,
        Codec::AIFF(_) => true,
        Codec::DSD(_) => false,
        Codec::FLAC(_) => true,
        Codec::MP3(_) => false,
        Codec::OPUS(_) => false,
        Codec::WAV(_) => true,
    }
}

public fun is_transcode_compatible(self: &Codec): bool {
    match (self) {
        Codec::AAC(_) => true,
        Codec::ALAC(_) => false,
        Codec::AIFF(_) => true,
        Codec::DSD(_) => true,
        Codec::FLAC(_) => false,
        Codec::MP3(_) => true,
        Codec::OPUS(_) => true,
        Codec::WAV(_) => false,
    }
}
