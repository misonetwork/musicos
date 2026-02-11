module musicos::deal;

use interest_bps::bps::{Self, BPS};
use musicos::cover_art::CoverArt;
use musicos::recording::{Recording, RecordingAdminCap};
use std::string::String;
use std::type_name::{TypeName, with_defining_ids};
use sui::event::emit;

//=== Structs ===

public struct Deal has key, store {
    id: UID,
    release_id: ID,
    composition_id: ID,
    composition_share_type: TypeName,
    composition_split_bps: BPS,
    recording_id: ID,
    recording_share_type: TypeName,
    recording_duration_ms: u64,
    track_title: String,
    track_split_bps: BPS,
    track_cover_art: CoverArt,
}

public struct DealCreatedEvent has copy, drop {
    deal_id: ID,
    release_id: ID,
    recording_id: ID,
    composition_id: ID,
}

public struct DealDestroyedEvent has copy, drop {
    deal_id: ID,
    release_id: ID,
    recording_id: ID,
    composition_id: ID,
}

//=== Public Functions ===

public fun new<RecordingShare>(
    _: &RecordingAdminCap<RecordingShare>,
    recording: &Recording<RecordingShare>,
    release_id: ID,
    track_split_bps_value: u64,
    track_title: Option<String>,
    track_cover_art: Option<CoverArt>,
    ctx: &mut TxContext,
): Deal {
    let recording_id = recording.id();
    let composition_id = recording.composition_id();

    let deal = Deal {
        id: object::new(ctx),
        release_id,
        composition_id,
        composition_share_type: *recording.composition_share_type(),
        composition_split_bps: recording.composition_split_bps(),
        recording_id,
        recording_share_type: with_defining_ids<RecordingShare>(),
        recording_duration_ms: recording.master().duration_ms(),
        track_title: track_title.destroy_or!(*recording.title()),
        track_split_bps: bps::new(track_split_bps_value),
        track_cover_art: track_cover_art.destroy_with_default(*recording.cover_art()),
    };

    emit(DealCreatedEvent {
        deal_id: deal.id(),
        release_id,
        recording_id: recording.id(),
        composition_id: recording.composition_id(),
    });

    deal
}

public fun destroy(self: Deal) {
    let Deal { id, release_id, recording_id, composition_id, .. } = self;

    emit(DealDestroyedEvent {
        deal_id: id.to_inner(),
        release_id,
        recording_id,
        composition_id,
    });

    id.delete();
}

//=== Public View Functions ===

public fun id(self: &Deal): ID {
    self.id.to_inner()
}

public fun release_id(self: &Deal): ID {
    self.release_id
}

public fun composition_id(self: &Deal): ID {
    self.composition_id
}

public fun composition_share_type(self: &Deal): &TypeName {
    &self.composition_share_type
}

public fun composition_split_bps(self: &Deal): BPS {
    self.composition_split_bps
}

public fun recording_id(self: &Deal): ID {
    self.recording_id
}

public fun recording_share_type(self: &Deal): &TypeName {
    &self.recording_share_type
}

public fun recording_duration_ms(self: &Deal): u64 {
    self.recording_duration_ms
}

public fun track_title(self: &Deal): &String {
    &self.track_title
}

public fun track_split_bps(self: &Deal): BPS {
    self.track_split_bps
}

public fun track_cover_art(self: &Deal): &CoverArt {
    &self.track_cover_art
}
