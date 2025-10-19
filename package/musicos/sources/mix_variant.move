module musicos::mix_variant;

use std::string::String;

public enum MixVariant has copy, drop, store {
    Original(String),
    Instrumental(String),
    Acapella(String),
    RadioEdit(String),
    Extended(String),
    Remix(String),
    Demo(String),
    Acoustic(String),
    Live(String),
    Other(String),
}

public fun new_original(): MixVariant {
    MixVariant::Original(b"Original".to_string())
}

public fun new_instrumental(): MixVariant {
    MixVariant::Instrumental(b"Instrumental".to_string())
}

public fun new_acapella(): MixVariant {
    MixVariant::Acapella(b"Acapella".to_string())
}

public fun new_radio_edit(): MixVariant {
    MixVariant::RadioEdit(b"Radio Edit".to_string())
}

public fun new_extended(): MixVariant {
    MixVariant::Extended(b"Extended".to_string())
}

public fun new_remix(): MixVariant {
    MixVariant::Remix(b"Remix".to_string())
}

public fun new_demo(): MixVariant {
    MixVariant::Demo(b"Demo".to_string())
}

public fun new_acoustic(): MixVariant {
    MixVariant::Acoustic(b"Acoustic".to_string())
}

public fun new_live(): MixVariant {
    MixVariant::Live(b"Live".to_string())
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
