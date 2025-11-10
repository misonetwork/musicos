module musicos::acl;

use musicos::audio::Audio;
use musicos::composition::Composition;
use musicos::recording::Recording;
use musicos::release::Release;
use std::string::String;
use sui::bcs;
use sui::dynamic_field as df;
use sui::vec_set::VecSet;

public struct DecryptionKey has key, store {
    id: UID,
}

// [audio_quilt_id][chunk_idx]
entry fun seal_approve(id: vector<u8>, decryption_key: &DecryptionKey) {
    let mut prepared = bcs::new(id);
    let audio_cid = prepared.peel_vec_u8().to_string();
}
