// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Genre extension for Miso.
///
/// Genre is a classification, not protocol-verifiable state, so it lives in an
/// extension rather than the core `Recording`. This package owns two halves:
///
/// 1. A **curated vocabulary** — `Genre` objects created by a `GenreRegistryCap`
///    holder (Miso), derived by canonical name so the vocabulary stays
///    deduplicated and canonical (no "hip-hop" vs "Hip Hop" forks).
/// 2. **Self-classification** — a recording's admin selects a primary genre and
///    optional secondary genres (the model artists know from DSP uploads). The
///    selection attaches to the recording via its `&mut UID` (the sanctioned
///    extension escape hatch), gated by the `RecordingAdminCap`.
///
/// A curated/attributed assignment layer (e.g. Miso editorial, for genre-based
/// rewards) can be added later as a coexisting source without changing the
/// `Genre` objects or this self-assignment path.
module genre::genre;

use miso::recording::{Recording, RecordingAdminCap};
use std::string::{Self, String};
use sui::derived_object::{Self, claim};
use sui::dynamic_field as df;
use sui::event::emit;

// === Structs ===

/// One-time witness for the genre package.
public struct GENRE has drop {}

/// Shared registry that parents the derived `Genre` objects.
public struct GenreRegistry has key {
    id: UID,
}

/// Capability authorizing creation of new genres. Held by the vocabulary curator.
public struct GenreRegistryCap has key, store {
    id: UID,
}

/// A genre in the canonical vocabulary. Immutable (frozen) once created.
/// Derived from the registry by `GenreKey(name)`, so a given name maps to a
/// single, deterministic object id.
public struct Genre has key {
    id: UID,
    /// Canonical genre name (e.g. "HIP_HOP").
    name: String,
}

// === Derivation / dynamic-field keys ===

/// Derivation key for a `Genre`, keyed by its canonical name.
public struct GenreKey(String) has copy, drop, store;

/// Dynamic-field key for a recording's genre assignment.
public struct GenreAssignmentKey() has copy, drop, store;

/// A recording's genre selection: one primary genre plus optional secondaries.
public struct GenreAssignment has store {
    primary: ID,
    /// Epoch the primary genre was last set. The primary cannot change again
    /// until `MIN_PRIMARY_GENRE_EPOCHS` later (anti-churn for reward integrity).
    primary_set_epoch: u64,
    secondary: vector<ID>,
}

// === Events ===

/// Emitted when a genre is added to the vocabulary.
public struct GenreCreatedEvent has copy, drop {
    genre_id: ID,
    name: String,
}

/// Emitted when a recording's primary genre is set or changed.
public struct PrimaryGenreSetEvent has copy, drop {
    recording_id: ID,
    genre_id: ID,
    /// Epoch this was set; the primary is locked until `set_epoch + MIN_PRIMARY_GENRE_EPOCHS`.
    set_epoch: u64,
}

/// Emitted when a secondary genre is added to a recording.
public struct SecondaryGenreAddedEvent has copy, drop {
    recording_id: ID,
    genre_id: ID,
}

/// Emitted when a secondary genre is removed from a recording.
public struct SecondaryGenreRemovedEvent has copy, drop {
    recording_id: ID,
    genre_id: ID,
}

// === Constants ===

/// Maximum length of a genre name in bytes.
const MAX_NAME_LENGTH: u64 = 64;
/// Maximum number of secondary genres per recording.
const MAX_SECONDARY_GENRES: u64 = 5;
/// Minimum number of epochs between primary-genre changes (~30 days on Sui).
/// Throttles genre-churn so a self-declared primary stays stable enough to be
/// reward-eligible. The first set is free; only changes are gated.
const MIN_PRIMARY_GENRE_EPOCHS: u64 = 30;

// === Errors ===

// Validation errors (20-29)
/// Genre name must not be empty.
const EEmptyName: u64 = 20;
/// Genre name exceeds the maximum length.
const ENameTooLong: u64 = 21;
/// Genre name contains a character other than `A`-`Z` or `_`.
const EInvalidNameChar: u64 = 22;

// State errors (30-39)
/// A primary genre must be set before adding secondary genres.
const ENoPrimaryGenre: u64 = 30;
/// The primary genre is still within its minimum-hold period and cannot change yet.
const EPrimaryGenreLocked: u64 = 31;

// Conflict errors (40-49)
/// The genre is already the primary genre.
const ESecondaryIsPrimary: u64 = 40;
/// The genre is already a secondary genre.
const EGenreAlreadySecondary: u64 = 41;
/// Recording has the maximum number of secondary genres.
const EMaxSecondaryGenres: u64 = 42;
/// The genre is not a secondary genre on this recording.
const EGenreNotSecondary: u64 = 43;

// === Init ===

fun init(_otw: GENRE, ctx: &mut TxContext) {
    transfer::share_object(GenreRegistry { id: object::new(ctx) });
    transfer::public_transfer(GenreRegistryCap { id: object::new(ctx) }, ctx.sender());
}

// === Vocabulary (curated) ===

/// Creates a new genre in the canonical vocabulary. Cap-gated: only the
/// registry curator can extend the vocabulary. Derived by canonical name, so
/// creating the same name twice aborts (dedup is automatic). The `Genre` is
/// frozen — immutable and globally readable by reference.
public fun new(
    _: &GenreRegistryCap,
    registry: &mut GenreRegistry,
    name: String,
) {
    assert!(!name.is_empty(), EEmptyName);
    assert!(name.length() <= MAX_NAME_LENGTH, ENameTooLong);
    // Canonical form: uppercase `A`-`Z` and `_` only (e.g. "HIP_HOP"). Keeps the
    // vocabulary uniform so name-derived dedup is meaningful.
    assert!(
        name.as_bytes().all!(|c| (*c >= 0x41 && *c <= 0x5A) || *c == 0x5F),
        EInvalidNameChar,
    );

    // Copy the name for the object field/event before the original is moved
    // into the derivation key.
    let name_copy = string::utf8(*name.as_bytes());
    let genre = Genre {
        id: claim(&mut registry.id, GenreKey(name)),
        name: name_copy,
    };

    emit(GenreCreatedEvent { genre_id: genre.id(), name: *genre.name() });
    transfer::freeze_object(genre);
}

/// Derives the object id a `Genre` with the given name would have, without
/// creating it. Lets clients resolve/check a genre id offline.
public fun derive_genre_id(self: &GenreRegistry, name: String): ID {
    derived_object::derive_address(self.id.to_inner(), GenreKey(name)).to_id()
}

// === Assignment (recording self-classification) ===

/// Sets (or replaces) the recording's primary genre. Gated by the recording's
/// admin capability — self-classification by the rightsholder.
///
/// The first set is free; changing an existing primary requires at least
/// `MIN_PRIMARY_GENRE_EPOCHS` to have passed since it was last set.
public fun set_primary_genre<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    genre: &Genre,
    ctx: &TxContext,
) {
    let recording_id = self.id();
    let genre_id = genre.id();
    let epoch = ctx.epoch();
    let uid = self.uid_mut(cap);

    if (df::exists_(uid, GenreAssignmentKey())) {
        let assignment: &mut GenreAssignment = df::borrow_mut(uid, GenreAssignmentKey());
        assert!(epoch >= assignment.primary_set_epoch + MIN_PRIMARY_GENRE_EPOCHS, EPrimaryGenreLocked);
        assignment.primary = genre_id;
        assignment.primary_set_epoch = epoch;
    } else {
        df::add(
            uid,
            GenreAssignmentKey(),
            GenreAssignment { primary: genre_id, primary_set_epoch: epoch, secondary: vector[] },
        );
    };

    emit(PrimaryGenreSetEvent { recording_id, genre_id, set_epoch: epoch });
}

/// Adds a secondary genre to the recording. Requires a primary genre first.
/// Rejects duplicates and a secondary equal to the primary.
public fun add_secondary_genre<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    genre: &Genre,
) {
    let recording_id = self.id();
    let genre_id = genre.id();
    let uid = self.uid_mut(cap);

    assert!(df::exists_(uid, GenreAssignmentKey()), ENoPrimaryGenre);
    let assignment: &mut GenreAssignment = df::borrow_mut(uid, GenreAssignmentKey());
    assert!(genre_id != assignment.primary, ESecondaryIsPrimary);
    assert!(!assignment.secondary.contains(&genre_id), EGenreAlreadySecondary);
    assert!(assignment.secondary.length() < MAX_SECONDARY_GENRES, EMaxSecondaryGenres);
    assignment.secondary.push_back(genre_id);

    emit(SecondaryGenreAddedEvent { recording_id, genre_id });
}

/// Removes a secondary genre from the recording.
public fun remove_secondary_genre<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    genre: &Genre,
) {
    let recording_id = self.id();
    let genre_id = genre.id();
    let uid = self.uid_mut(cap);

    assert!(df::exists_(uid, GenreAssignmentKey()), ENoPrimaryGenre);
    let assignment: &mut GenreAssignment = df::borrow_mut(uid, GenreAssignmentKey());
    let (found, idx) = assignment.secondary.index_of(&genre_id);
    assert!(found, EGenreNotSecondary);
    assignment.secondary.remove(idx);

    emit(SecondaryGenreRemovedEvent { recording_id, genre_id });
}

// === Genre views ===

/// Returns the genre's object id.
public fun id(self: &Genre): ID {
    self.id.to_inner()
}

/// Returns the genre's canonical name.
public fun name(self: &Genre): &String {
    &self.name
}

// === Assignment views ===

/// Returns whether the recording has a genre assignment.
public fun has_genre<RecordingShare, CompositionShare>(self: &Recording<RecordingShare, CompositionShare>): bool {
    df::exists_(self.uid(), GenreAssignmentKey())
}

/// Returns the recording's primary genre id, if set.
public fun primary_genre<RecordingShare, CompositionShare>(self: &Recording<RecordingShare, CompositionShare>): Option<ID> {
    let uid = self.uid();
    if (df::exists_(uid, GenreAssignmentKey())) {
        option::some(df::borrow<GenreAssignmentKey, GenreAssignment>(uid, GenreAssignmentKey()).primary)
    } else {
        option::none()
    }
}

/// Returns the recording's secondary genre ids (empty if none).
public fun secondary_genres<RecordingShare, CompositionShare>(self: &Recording<RecordingShare, CompositionShare>): vector<ID> {
    let uid = self.uid();
    if (df::exists_(uid, GenreAssignmentKey())) {
        df::borrow<GenreAssignmentKey, GenreAssignment>(uid, GenreAssignmentKey()).secondary
    } else {
        vector[]
    }
}

// === Test Only ===

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(GENRE {}, ctx)
}
