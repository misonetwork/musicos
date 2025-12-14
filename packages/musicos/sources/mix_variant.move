// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::mix_variant;

use std::string::String;

//=== Enums ===

public enum MixVariant has copy, drop, store {
    Original,
    Instrumental,
    Acapella,
    RadioEdit,
    Extended,
    Remix,
    Demo,
    Acoustic,
    Live,
    Other(String),
}

//=== Public Functions ===

public fun new_original(): MixVariant {
    MixVariant::Original
}

public fun new_instrumental(): MixVariant {
    MixVariant::Instrumental
}

public fun new_acapella(): MixVariant {
    MixVariant::Acapella
}

public fun new_radio_edit(): MixVariant {
    MixVariant::RadioEdit
}

public fun new_extended(): MixVariant {
    MixVariant::Extended
}

public fun new_remix(): MixVariant {
    MixVariant::Remix
}

public fun new_demo(): MixVariant {
    MixVariant::Demo
}

public fun new_acoustic(): MixVariant {
    MixVariant::Acoustic
}

public fun new_live(): MixVariant {
    MixVariant::Live
}

public fun new_other(name: String): MixVariant {
    MixVariant::Other(name)
}

//=== Public View Functions ===

public fun name(self: &MixVariant): String {
    match (self) {
        MixVariant::Original => b"Original".to_string(),
        MixVariant::Instrumental => b"Instrumental".to_string(),
        MixVariant::Acapella => b"Acapella".to_string(),
        MixVariant::RadioEdit => b"RadioEdit".to_string(),
        MixVariant::Extended => b"Extended".to_string(),
        MixVariant::Remix => b"Remix".to_string(),
        MixVariant::Demo => b"Demo".to_string(),
        MixVariant::Acoustic => b"Acoustic".to_string(),
        MixVariant::Live => b"Live".to_string(),
        MixVariant::Other(name) => *name,
    }
}

public fun is_original(self: &MixVariant): bool {
    match (self) {
        MixVariant::Original => true,
        _ => false,
    }
}
