// Copyright (c) Unconfirmed Labs, LLC
// SPDX-License-Identifier: Apache-2.0

/// Represents an individual audio stem within a recording.
/// Stems are isolated audio tracks (e.g., vocals, drums, bass) that
/// together compose the full recording master.
module musicos::stem;

use musicos::audio::Audio;
use musicos::party::Party;
use std::string::String;

//=== Structs ===

public struct Stem has drop, store {
    audio: Audio,
    description: String,
    contributors: vector<ID>,
}

//=== Constants ===

const MAX_CONTRIBUTORS: u64 = 10;

//=== Errors ===

const EMaxContributorsReached: u64 = 0;
const EContributorExists: u64 = 1;
const EContributorNotFound: u64 = 2;

//=== Public Functions ===

public fun new(audio: Audio, description: String): Stem {
    Stem {
        audio,
        description,
        contributors: vector[],
    }
}

public fun add_contributor(self: &mut Stem, contributor: &Party) {
    assert!(self.contributors.length() < MAX_CONTRIBUTORS, EMaxContributorsReached);
    let contributor_id = contributor.id();
    assert!(!self.contributors.contains(&contributor_id), EContributorExists);
    self.contributors.push_back(contributor_id);
}

public fun remove_contributor(self: &mut Stem, contributor_idx: u64) {
    assert!(contributor_idx < self.contributors.length(), EContributorNotFound);
    self.contributors.swap_remove(contributor_idx);
}

//=== Public View Functions ===

public fun audio(self: &Stem): &Audio {
    &self.audio
}

public fun description(self: &Stem): &String {
    &self.description
}

public fun contributors(self: &Stem): &vector<ID> {
    &self.contributors
}
