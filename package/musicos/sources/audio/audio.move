module musicos::audio;

//=== Structs ===

public struct Audio has copy, drop, store {
    blob_id: u256,
    bit_depth: u8,
    channels: u8,
    duration: u64,
    sample_rate: u32,
}

//=== Public Functions ===

public fun new(blob_id: u256, bit_depth: u8, channels: u8, duration: u64, sample_rate: u32): Audio {
    Audio {
        blob_id,
        bit_depth,
        channels,
        duration,
        sample_rate,
    }
}

public fun blob_id(self: &Audio): u256 {
    self.blob_id
}

public fun bit_depth(self: &Audio): u8 {
    self.bit_depth
}

public fun channels(self: &Audio): u8 {
    self.channels
}

public fun duration(self: &Audio): u64 {
    self.duration
}

public fun sample_rate(self: &Audio): u32 {
    self.sample_rate
}
