// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::stem;

use musicos::audio::Audio;
use std::string::String;

public struct Stem has drop, store {
    audio: Audio,
    description: Option<String>,
}
