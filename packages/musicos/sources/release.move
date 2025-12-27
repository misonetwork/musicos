// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::release;

use interest_bps::bps::{Self, BPS};
use musicos::disc::Disc;
use musicos::track_identifier::TrackIdentifier;
use musicos::track_sequence::TrackSequence;
use std::string::String;
use std::type_name::{TypeName, with_defining_ids};
use sui::balance::Balance;
use sui::clock::Clock;
use sui::derived_object::claim;
use sui::dynamic_field as df;
use sui::event::emit;
use sui::random::Random;
use sui::vec_map::{Self, VecMap};

public struct Release has key {
    id: UID,
    kind: ReleaseKind,
    state: ReleaseState,
    title: String,
    subtitle: Option<String>,
    duration: u64,
    discs: vector<Disc>,
    track_sequence: TrackSequence,
    track_splits: VecMap<TrackIdentifier, BPS>,
}

public struct ReleaseAdminCap has key, store {
    id: UID,
    release_id: ID,
}

//=== Enums ===
public enum ReleaseKind has copy, drop, store {
    Album,
    EP,
    Single,
}

public enum ReleaseState has copy, drop, store {
    Created(u64),
    Published(u64),
}
