module musicos::cover_art;

use musicos::data::Data;

public struct CoverArt has copy, drop, store {
    static: Data,
    animated: Option<Data>,
}

public fun new(static: Data, animated: Option<Data>): CoverArt {
    CoverArt {
        static,
        animated,
    }
}

public fun static(self: &CoverArt): &Data {
    &self.static
}

public fun animated(self: &CoverArt): &Option<Data> {
    &self.animated
}
