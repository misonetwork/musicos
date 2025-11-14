module musicos::track_request;

use musicos::release::Release;
use musicos::track::Track;
use sui::transfer::Receiving;

public struct TrackRequest has key {
    id: UID,
    track: Track,
}

public fun new_and_transfer(release: &Release, track: Track, ctx: &mut TxContext) {
    let request = TrackRequest {
        id: object::new(ctx),
        track,
    };
    transfer::transfer(request, release.id().to_address());
}

public(package) fun receive_and_destroy(
    parent: &mut UID,
    request_to_receive: Receiving<TrackRequest>,
): Track {
    let request = transfer::receive(parent, request_to_receive);
    let TrackRequest { id, track } = request;
    id.delete();
    track
}
