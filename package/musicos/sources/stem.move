module musicos::stem;

use musicos::audio::Audio;
use std::string::String;

public struct Stem has copy, drop, store {
    audio: Audio,
    description: Option<String>,
}
