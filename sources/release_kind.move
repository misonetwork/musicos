module musicos::release_kind;

use std::string::String;

// === Enums ===

public enum ReleaseKind has copy, drop, store {
    Album,
    ExtendedPlay,
    Single,
}

// === Public Functions ===

public fun new_album_kind(): ReleaseKind {
    ReleaseKind::Album
}

public fun new_extended_play_kind(): ReleaseKind {
    ReleaseKind::ExtendedPlay
}

public fun new_single_kind(): ReleaseKind {
    ReleaseKind::Single
}

// === Public View Functions ===

public fun name(self: &ReleaseKind): String {
    match (self) {
        ReleaseKind::Album => "Album",
        ReleaseKind::ExtendedPlay => "Extended Play",
        ReleaseKind::Single => "Single",
    }
}
