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
    /// The name of the stem.
    name: String,
    /// Human-readable description of the stem (e.g., "Lead Vocals", "Electric Guitar").
    description: Option<String>,
    /// IDs of parties who contributed to this stem.
    contributors: vector<ID>,
}

// === Constants ===

/// Maximum number of contributors allowed per stem.
const MAX_CONTRIBUTORS: u64 = 10;
/// Maximum length of a stem name in bytes.
const MAX_NAME_LENGTH: u64 = 100;
/// Maximum length of a stem description in bytes.
const MAX_DESCRIPTION_LENGTH: u64 = 500;

// === Errors ===

/// Stem already has the maximum number of contributors.
const EMaxContributorsReached: u64 = 0;
/// Contributor is already assigned to this stem.
const EContributorExists: u64 = 1;
/// Contributor index is out of bounds.
const EContributorNotFound: u64 = 2;
/// Name exceeds maximum length.
const EMaxNameLengthExceeded: u64 = 3;
/// Description exceeds maximum length.
const EMaxDescriptionLengthExceeded: u64 = 4;
/// String must not be empty.
const EEmptyString: u64 = 5;

// === Public Functions ===

/// Creates a new stem with the given audio and name.
/// Starts with an empty contributors list.
public fun new(audio: Audio, name: String): Stem {
    assert!(!name.is_empty(), EEmptyString);
    assert!(name.length() <= MAX_NAME_LENGTH, EMaxNameLengthExceeded);

    Stem {
        audio,
        name,
        description: option::none(),
        contributors: vector[],
    }
}

/// Sets the description of the stem.
public fun set_description(self: &mut Stem, description: String) {
    assert!(!description.is_empty(), EEmptyString);
    assert!(description.length() <= MAX_DESCRIPTION_LENGTH, EMaxDescriptionLengthExceeded);
    self.description.fill(description);
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

/// Returns the stem's name.
public fun name(self: &Stem): &String {
    &self.name
}

/// Returns the stem's description.
public fun description(self: &Stem): &Option<String> {
    &self.description
}

/// Returns a reference to the contributor IDs.
public fun contributors(self: &Stem): &vector<ID> {
    &self.contributors
}

/// Creates a stem for testing with a zero-ID contributor (bypasses Party requirement).
#[test_only]
public fun new_for_testing(audio: Audio): Stem {
    Stem {
        audio,
        name: b"Test Stem".to_string(),
        description: option::none(),
        contributors: vector[@0x0.to_id()],
    }
}
