module musicos::track_info;

use interest_bps::bps::BPS;

// (index, split)
public struct TrackInfo(u8, Option<BPS>) has drop, store;

public(package) fun new(track_index: u8): TrackInfo {
    TrackInfo(track_index, option::none())
}

public fun index(self: &TrackInfo): u8 {
    self.0
}

public fun split(self: &TrackInfo): BPS {
    *self.1.borrow()
}
