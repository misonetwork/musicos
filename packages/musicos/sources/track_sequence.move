module musicos::track_sequence;

use musicos::track_identifier::TrackIdentifier;

//=== Errors ===

const EEmptySequence: u64 = 0;
const EDoesNotExist: u64 = 1;

//=== Structs ===

public struct TrackSequence(vector<TrackIdentifier>) has copy, drop, store;

//=== Package Functions ===

public(package) fun new(keys: vector<TrackIdentifier>): TrackSequence {
    assert!(keys.length() > 0, EEmptySequence);
    TrackSequence(keys)
}

//=== Package View Functions ===

public(package) fun next(self: &TrackSequence, current: &TrackIdentifier): TrackIdentifier {
    let len = self.0.length();
    assert!(len > 0, EEmptySequence);
    let cur = find_index(&self.0, current);
    let next_idx = (cur + 1) % len;
    self.0[next_idx]
}

public(package) fun previous(self: &TrackSequence, current: &TrackIdentifier): TrackIdentifier {
    let len = self.0.length();
    assert!(len > 0, EEmptySequence);

    let cur = find_index(&self.0, current);
    let prev_idx = (cur + len - 1) % len;
    self.0[prev_idx]
}

fun find_index(v: &vector<TrackIdentifier>, key: &TrackIdentifier): u64 {
    let len = v.length();
    let mut i = 0;
    while (i < len) {
        if (key == v[i]) {
            return i
        };
        i = i + 1;
    };
    abort EDoesNotExist
}

public fun length(self: &TrackSequence): u64 {
    self.0.length()
}

public fun inner(self: &TrackSequence): &vector<TrackIdentifier> {
    &self.0
}
