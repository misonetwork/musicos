// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module musicos::cover_art_tests;

use musicos::cover_art;
use ori::walrus_data;
use std::unit_test::{assert_eq, destroy};

// Error code from ori::walrus_data.
const ENotBlob: u64 = 0;

#[test]
fun new_with_still_blob() {
    let art = cover_art::new(walrus_data::new_blob(1), option::none());
    assert_eq!(art.still().blob_id(), 1);
    assert!(art.animated().is_none());
    destroy(art);
}

#[test]
fun new_with_animated_blob() {
    let art = cover_art::new(
        walrus_data::new_blob(1),
        option::some(walrus_data::new_blob(2)),
    );
    assert_eq!(art.animated().borrow().blob_id(), 2);
    destroy(art);
}

#[test]
fun new_with_encrypted_still_blob() {
    // Encrypted blobs are still blobs; cover art accepts them.
    let art = cover_art::new(
        walrus_data::new_encrypted_blob(3, b"sealed-dek"),
        option::none(),
    );
    assert!(art.still().is_encrypted());
    destroy(art);
}

#[test, expected_failure(abort_code = ENotBlob, location = ori::walrus_data)]
fun new_with_quilt_patch_still_aborts() {
    let art = cover_art::new(
        walrus_data::new_quilt_patch(1, 1, 0, 1),
        option::none(),
    );
    destroy(art);
}

#[test, expected_failure(abort_code = ENotBlob, location = ori::walrus_data)]
fun new_with_quilt_patch_animated_aborts() {
    let art = cover_art::new(
        walrus_data::new_blob(1),
        option::some(walrus_data::new_quilt_patch(1, 1, 0, 1)),
    );
    destroy(art);
}
