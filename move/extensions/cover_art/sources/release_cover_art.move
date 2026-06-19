// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Release cover art, mapped to the release's disc structure: a release-level
/// cover plus optional per-disc cover art keyed by disc index. Stored as a dynamic
/// field on the release's UID, set/cleared via the release's cap-gated `uid_mut`.
///
/// Disc indices are validated against the release's actual disc count, so disc
/// cover art can only target a disc that exists. Discs are fixed at release
/// creation, so an index that is valid stays valid.
module cover_art::release_cover_art;

use cover_art::cover_art::CoverArt;
use miso::release::{Release, ReleaseAdminCap};
use sui::dynamic_field as df;
use sui::vec_map::{Self, VecMap};

// === Errors ===

/// No cover art record is attached to this release.
const ENoCoverArt: u64 = 1;
/// Disc index is out of bounds for this release's disc count.
const EDiscIndexOutOfBounds: u64 = 2;
/// No cover art is attached for the requested disc.
const ENoDiscCoverArt: u64 = 3;

// === Dynamic field key + value ===

/// Dynamic-field key — one cover art record per release.
public struct CoverArtKey() has copy, drop, store;

/// The release's cover art: a release-level cover and per-disc cover art keyed by
/// disc index (sparse — only discs that have art appear).
public struct ReleaseCoverArt has store {
    cover: Option<CoverArt>,
    disc_cover_art: VecMap<u64, CoverArt>,
}

// === Write API ===

/// Sets (or replaces) the release-level cover.
public fun set_cover(self: &mut Release, cap: &ReleaseAdminCap, art: CoverArt) {
    let ra = borrow_mut_or_init(self.uid_mut(cap));
    ra.cover.swap_or_fill(art);
}

/// Removes the release-level cover, if any.
public fun unset_cover(self: &mut Release, cap: &ReleaseAdminCap) {
    if (has_cover_art(self)) {
        let ra = borrow_mut(self.uid_mut(cap));
        ra.cover = option::none();
    }
}

/// Sets (or replaces) the cover art for a specific disc. The disc index must be
/// within the release's disc count.
public fun set_disc_cover_art(
    self: &mut Release,
    cap: &ReleaseAdminCap,
    disc_index: u64,
    art: CoverArt,
) {
    let disc_count = self.discs().length();
    assert!(disc_index < disc_count, EDiscIndexOutOfBounds);
    let ra = borrow_mut_or_init(self.uid_mut(cap));
    if (ra.disc_cover_art.contains(&disc_index)) {
        let (_, _) = ra.disc_cover_art.remove(&disc_index);
    };
    ra.disc_cover_art.insert(disc_index, art);
}

/// Removes the cover art for a specific disc, if any.
public fun unset_disc_cover_art(self: &mut Release, cap: &ReleaseAdminCap, disc_index: u64) {
    let ra = borrow_mut(self.uid_mut(cap));
    if (ra.disc_cover_art.contains(&disc_index)) {
        let (_, _) = ra.disc_cover_art.remove(&disc_index);
    };
}

// === Public View Functions ===

/// Returns whether a cover art record is attached to this release.
public fun has_cover_art(self: &Release): bool {
    df::exists(self.uid(), CoverArtKey())
}

/// Returns the release-level cover (none if unset). Aborts if no cover art record
/// is attached at all.
public fun cover(self: &Release): &Option<CoverArt> {
    &borrow(self.uid()).cover
}

/// Returns whether the given disc has cover art.
public fun has_disc_cover_art(self: &Release, disc_index: u64): bool {
    has_cover_art(self) && borrow(self.uid()).disc_cover_art.contains(&disc_index)
}

/// Returns the cover art for a specific disc (by value — `CoverArt` is `copy`).
/// Aborts if none is attached.
public fun disc_cover_art(self: &Release, disc_index: u64): CoverArt {
    let ra = borrow(self.uid());
    assert!(ra.disc_cover_art.contains(&disc_index), ENoDiscCoverArt);
    *ra.disc_cover_art.get(&disc_index)
}

// === Private Functions ===

fun borrow(uid: &UID): &ReleaseCoverArt {
    assert!(df::exists(uid, CoverArtKey()), ENoCoverArt);
    df::borrow(uid, CoverArtKey())
}

fun borrow_mut(uid: &mut UID): &mut ReleaseCoverArt {
    assert!(df::exists(uid, CoverArtKey()), ENoCoverArt);
    df::borrow_mut(uid, CoverArtKey())
}

fun borrow_mut_or_init(uid: &mut UID): &mut ReleaseCoverArt {
    if (!df::exists(uid, CoverArtKey())) {
        df::add(
            uid,
            CoverArtKey(),
            ReleaseCoverArt { cover: option::none(), disc_cover_art: vec_map::empty() },
        );
    };
    df::borrow_mut(uid, CoverArtKey())
}
