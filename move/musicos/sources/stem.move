// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/// Represents an individual audio stem within a recording.
/// Stems are isolated audio tracks (e.g., vocals, drums, bass) that
/// together compose the full recording master.
module musicos::stem;

use musicos::audio::Audio;
use musicos::party::Party;
use std::string::String;

// === Structs ===

/// An individual audio stem within a recording (e.g., vocals, drums, bass).
public struct Stem has drop, store {
    /// The audio data for this stem.
    audio: Audio,
    /// Human-readable description of the stem (e.g., "Lead Vocals", "Electric Guitar").
    description: String,
    /// IDs of parties who contributed to this stem.
    contributors: vector<ID>,
}

// === Constants ===

/// Maximum number of contributors allowed per stem.
const MAX_CONTRIBUTORS: u64 = 10;

// === Errors ===

/// Stem already has the maximum number of contributors.
const EMaxContributorsReached: u64 = 0;
/// Contributor is already assigned to this stem.
const EContributorExists: u64 = 1;
/// Contributor index is out of bounds.
const EContributorNotFound: u64 = 2;

// === Public Functions ===

/// Creates a new stem with the given audio and description.
/// Starts with an empty contributors list.
public fun new(audio: Audio, description: String): Stem {
    Stem {
        audio,
        description,
        contributors: vector[],
    }
}

/// Adds a party as a contributor to this stem.
/// Aborts if the stem already has the maximum number of contributors
/// or if the party is already a contributor.
public fun add_contributor(self: &mut Stem, contributor: &Party) {
    assert!(self.contributors.length() < MAX_CONTRIBUTORS, EMaxContributorsReached);
    let contributor_id = contributor.id();
    assert!(!self.contributors.contains(&contributor_id), EContributorExists);
    self.contributors.push_back(contributor_id);
}

/// Removes a contributor from the stem by their index.
/// Aborts if the index is out of bounds.
public fun remove_contributor(self: &mut Stem, contributor_idx: u64) {
    assert!(contributor_idx < self.contributors.length(), EContributorNotFound);
    self.contributors.swap_remove(contributor_idx);
}

// === Public View Functions ===

/// Returns a reference to the stem's audio data.
public fun audio(self: &Stem): &Audio {
    &self.audio
}

/// Returns the stem's description.
public fun description(self: &Stem): &String {
    &self.description
}

/// Returns a reference to the contributor IDs.
public fun contributors(self: &Stem): &vector<ID> {
    &self.contributors
}
