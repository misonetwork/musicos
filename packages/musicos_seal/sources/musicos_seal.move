module musicos_seal::policies;

use sui::bcs;
use sui::clock::Clock;

entry fun seal_approve(id: vector<u8>, clock: &Clock) {
    let mut prepared = bcs::new(id);
    let unlock_ts = prepared.peel_u64();
    assert!(clock.timestamp_ms() > unlock_ts, 1000);
    assert!(prepared.into_remainder_bytes().length() == 0, 1001);
}
