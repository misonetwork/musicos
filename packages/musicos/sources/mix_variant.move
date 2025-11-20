// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::mix_variant;

use std::string::String;

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
    Other,
}

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

public fun is_original(self: &MixVariant): bool {
    match (self) {
        MixVariant::Original(_) => true,
        _ => false,
    }
}


public fun name(self: &MixVariant): String {
    match (self) {
        MixVariant::Original => "Original",
        MixVariant::Instrumental => "Instrumental",
        MixVariant::Acapella => "Acapella",
        MixVariant::RadioEdit => "RadioEdit",
        MixVariant::Extended => "Extended",
        MixVariant::Remix => "Remix",
        MixVariant::Demo => "Demo",
        MixVariant::Acoustic => "Acoustic",
        MixVariant::Live => "Live",
        MixVariant::Other(name) => name,
    }
}