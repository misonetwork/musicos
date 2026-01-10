module musicos::cover_art;

public struct CoverArt has copy, drop, store {
    static: u256,
    animated: Option<u256>,
}

public fun new(static: u256, animated: Option<u256>): CoverArt {
    CoverArt {
        static,
        animated,
    }
}

public fun static(self: &CoverArt): u256 {
    self.static
}

public fun animated(self: &CoverArt): Option<u256> {
    self.animated
}
