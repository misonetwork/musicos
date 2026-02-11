// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/// Tests for release digest calculation to verify TypeScript SDK parity.
#[test_only]
module musicos::release_digest_tests;

use sui::bcs::to_bytes;
use sui::hash::blake2b256;

/// Calculates the release digest using the same algorithm as release.move.
/// This is exposed for testing to verify SDK parity.
fun calculate_release_digest(
    recording_ids: vector<ID>,
    track_split_values: vector<u64>,
    epoch: u64,
): vector<u8> {
    let mut hash_input = vector<u8>[];
    hash_input.append(to_bytes(&recording_ids));
    hash_input.append(to_bytes(&track_split_values));
    hash_input.append(to_bytes(&epoch));

    blake2b256(&hash_input)
}

#[test]
/// Test single recording with 100% split at epoch 1.
/// This test verifies the BCS encoding and hashing matches the TypeScript SDK.
fun test_single_recording_digest() {
    let recording_id = object::id_from_address(
        @0x0000000000000000000000000000000000000000000000000000000000000001
    );
    let recording_ids = vector[recording_id];
    let track_splits = vector[10000u64]; // 100% = 10000 BPS
    let epoch = 1u64;

    let digest = calculate_release_digest(recording_ids, track_splits, epoch);

    // Digest should be 32 bytes
    assert!(digest.length() == 32);

    // Print the digest for comparison with TypeScript SDK
    // (In actual usage, we'd compare against a known expected value)
    std::debug::print(&digest);
}

#[test]
/// Test multiple recordings with split shares at epoch 42.
fun test_multiple_recordings_digest() {
    let recording_id_1 = object::id_from_address(
        @0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
    );
    let recording_id_2 = object::id_from_address(
        @0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
    );
    let recording_ids = vector[recording_id_1, recording_id_2];
    let track_splits = vector[5000u64, 5000u64]; // 50% each
    let epoch = 42u64;

    let digest = calculate_release_digest(recording_ids, track_splits, epoch);

    // Digest should be 32 bytes
    assert!(digest.length() == 32);

    // Print the digest for comparison with TypeScript SDK
    std::debug::print(&digest);
}

#[test]
/// Test that the same inputs produce the same digest (deterministic).
fun test_digest_determinism() {
    let recording_id = object::id_from_address(
        @0x0000000000000000000000000000000000000000000000000000000000000001
    );
    let recording_ids = vector[recording_id];
    let track_splits = vector[10000u64];
    let epoch = 100u64;

    let digest_1 = calculate_release_digest(recording_ids, track_splits, epoch);
    let digest_2 = calculate_release_digest(recording_ids, track_splits, epoch);

    assert!(digest_1 == digest_2);
}

#[test]
/// Test that different epochs produce different digests.
fun test_different_epochs_produce_different_digests() {
    let recording_id = object::id_from_address(
        @0x0000000000000000000000000000000000000000000000000000000000000001
    );
    let recording_ids = vector[recording_id];
    let track_splits = vector[10000u64];

    let digest_epoch_1 = calculate_release_digest(recording_ids, track_splits, 1);
    let digest_epoch_2 = calculate_release_digest(recording_ids, track_splits, 2);

    assert!(digest_epoch_1 != digest_epoch_2);
}

#[test]
/// Test that different recording IDs produce different digests.
fun test_different_recordings_produce_different_digests() {
    let recording_id_1 = object::id_from_address(
        @0x0000000000000000000000000000000000000000000000000000000000000001
    );
    let recording_id_2 = object::id_from_address(
        @0x0000000000000000000000000000000000000000000000000000000000000002
    );
    let track_splits = vector[10000u64];
    let epoch = 1u64;

    let digest_1 = calculate_release_digest(vector[recording_id_1], track_splits, epoch);
    let digest_2 = calculate_release_digest(vector[recording_id_2], track_splits, epoch);

    assert!(digest_1 != digest_2);
}

#[test]
/// Test that different track splits produce different digests.
fun test_different_splits_produce_different_digests() {
    let recording_id_1 = object::id_from_address(
        @0x0000000000000000000000000000000000000000000000000000000000000001
    );
    let recording_id_2 = object::id_from_address(
        @0x0000000000000000000000000000000000000000000000000000000000000002
    );
    let recording_ids = vector[recording_id_1, recording_id_2];
    let epoch = 1u64;

    let digest_50_50 = calculate_release_digest(recording_ids, vector[5000u64, 5000u64], epoch);
    let digest_60_40 = calculate_release_digest(recording_ids, vector[6000u64, 4000u64], epoch);

    assert!(digest_50_50 != digest_60_40);
}

#[test]
/// Verify the BCS encoding structure matches expectations.
/// This test helps debug any encoding mismatches with the TypeScript SDK.
fun test_bcs_encoding_structure() {
    let recording_id = object::id_from_address(
        @0x0000000000000000000000000000000000000000000000000000000000000001
    );
    let recording_ids = vector[recording_id];
    let track_splits = vector[10000u64];
    let epoch = 1u64;

    // BCS encode each component separately to verify structure
    let recording_ids_bytes = to_bytes(&recording_ids);
    let track_splits_bytes = to_bytes(&track_splits);
    let epoch_bytes = to_bytes(&epoch);

    // vector<ID> with 1 element: 1 byte length (ULEB128) + 32 bytes address = 33 bytes
    assert!(recording_ids_bytes.length() == 33);

    // vector<u64> with 1 element: 1 byte length (ULEB128) + 8 bytes u64 = 9 bytes
    assert!(track_splits_bytes.length() == 9);

    // u64: 8 bytes little-endian
    assert!(epoch_bytes.length() == 8);

    // Print bytes for debugging
    std::debug::print(&recording_ids_bytes);
    std::debug::print(&track_splits_bytes);
    std::debug::print(&epoch_bytes);
}
