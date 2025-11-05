module musicos::audio;

use musicos::bit_rate::BitRate;
use musicos::codec::Codec;
use musicos::pcm::Pcm;

//=== Structs ===

public struct Audio has copy, drop, store {
    pcm: Pcm,
    codec: Codec,
}

//=== Public Functions ===

public fun new(pcm: Pcm, codec: Codec): Audio {
    Audio {
        pcm,
        codec,
    }
}

public fun pcm(self: &Audio): &Pcm {
    &self.pcm
}

public fun codec(self: &Audio): &Codec {
    &self.codec
}
