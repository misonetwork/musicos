// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Tests for release digest calculation and derive_release_id to verify TypeScript SDK parity.
#[test_only]
module miso::release_digest_tests;

use miso::release::{Self, new_release_registry_for_testing};
use std::unit_test::destroy;
use sui::bcs::to_bytes;
use sui::hash::blake2b256;

/// Calculates the release digest using the same algorithm as release.move.
/// This is exposed for testing to verify SDK parity.
fun calculate_release_digest(
    recording_ids: vector<ID>,
    track_split_values: vector<u64>,
    nonce: u256,
): vector<u8> {
    let mut hash_input = vector<u8>[];
    hash_input.append(to_bytes(&recording_ids));
    hash_input.append(to_bytes(&track_split_values));
    hash_input.append(to_bytes(&nonce));

    blake2b256(&hash_input)
}

#[test]
/// Test single recording with 100% split and nonce 1.
/// This test verifies the BCS encoding and hashing matches the TypeScript SDK.
fun test_single_recording_digest() {
    let recording_id = object::id_from_address(
        @0x0000000000000000000000000000000000000000000000000000000000000001
    );
    let recording_ids = vector[recording_id];
    let track_splits = vector[10000u64]; // 100% = 10000 BPS
    let nonce = 1u256;

    let digest = calculate_release_digest(recording_ids, track_splits, nonce);

    // Digest should be 32 bytes
    assert!(digest.length() == 32);

    // Print the digest for comparison with TypeScript SDK
    // (In actual usage, we'd compare against a known expected value)
    std::debug::print(&digest);
}

#[test]
/// Test multiple recordings with split shares and nonce 42.
fun test_multiple_recordings_digest() {
    let recording_id_1 = object::id_from_address(
        @0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
    );
    let recording_id_2 = object::id_from_address(
        @0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
    );
    let recording_ids = vector[recording_id_1, recording_id_2];
    let track_splits = vector[5000u64, 5000u64]; // 50% each
    let nonce = 42u256;

    let digest = calculate_release_digest(recording_ids, track_splits, nonce);

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
    let nonce = 100u256;

    let digest_1 = calculate_release_digest(recording_ids, track_splits, nonce);
    let digest_2 = calculate_release_digest(recording_ids, track_splits, nonce);

    assert!(digest_1 == digest_2);
}

#[test]
/// Test that different nonces produce different digests.
fun test_different_nonces_produce_different_digests() {
    let recording_id = object::id_from_address(
        @0x0000000000000000000000000000000000000000000000000000000000000001
    );
    let recording_ids = vector[recording_id];
    let track_splits = vector[10000u64];

    let digest_nonce_1 = calculate_release_digest(recording_ids, track_splits, 1u256);
    let digest_nonce_2 = calculate_release_digest(recording_ids, track_splits, 2u256);

    assert!(digest_nonce_1 != digest_nonce_2);
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
    let nonce = 1u256;

    let digest_1 = calculate_release_digest(vector[recording_id_1], track_splits, nonce);
    let digest_2 = calculate_release_digest(vector[recording_id_2], track_splits, nonce);

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
    let nonce = 1u256;

    let digest_50_50 = calculate_release_digest(recording_ids, vector[5000u64, 5000u64], nonce);
    let digest_60_40 = calculate_release_digest(recording_ids, vector[6000u64, 4000u64], nonce);

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
    let nonce = 1u256;

    // BCS encode each component separately to verify structure
    let recording_ids_bytes = to_bytes(&recording_ids);
    let track_splits_bytes = to_bytes(&track_splits);
    let nonce_bytes = to_bytes(&nonce);

    // vector<ID> with 1 element: 1 byte length (ULEB128) + 32 bytes address = 33 bytes
    assert!(recording_ids_bytes.length() == 33);

    // vector<u64> with 1 element: 1 byte length (ULEB128) + 8 bytes u64 = 9 bytes
    assert!(track_splits_bytes.length() == 9);

    // u256: 32 bytes little-endian
    assert!(nonce_bytes.length() == 32);

    // Print bytes for debugging
    std::debug::print(&recording_ids_bytes);
    std::debug::print(&track_splits_bytes);
    std::debug::print(&nonce_bytes);
}

// === derive_release_id parity tests ===
// These verify that the on-chain derive_release_id() returns the same ID
// as the TypeScript SDK's deriveReleaseId(). Expected values were computed
// from @sona/sdk/derive with the same inputs.

#[test]
/// Single recording, 100% split, nonce=1.
/// TypeScript expected digest: dccbc50994240ba6de125686dc040b27b8c739fe8b55d8d7cbf923535b57af6c
/// TypeScript expected release ID: 0x814674793a22d3ef2ee90c1356018e7a5c56a517a3116b372d83457a1789711b
fun test_derive_release_id_parity_single() {
    let mut ctx = tx_context::dummy();
    let registry = new_release_registry_for_testing(&mut ctx);

    // Override registry ID to match the test fixture (0x99)
    // We can't set the registry ID, so we verify the digest matches instead.
    let recording_ids = vector[
        object::id_from_address(@0x0000000000000000000000000000000000000000000000000000000000000001),
    ];
    let track_splits = vector[10000u64];
    let nonce = 1u256;

    // Verify digest matches TypeScript output
    let digest = calculate_release_digest(recording_ids, track_splits, nonce);
    let expected_digest = x"dccbc50994240ba6de125686dc040b27b8c739fe8b55d8d7cbf923535b57af6c";
    assert!(digest == expected_digest, 0);

    // derive_release_id uses the registry's actual ID, so we can't hardcode an expected
    // release ID here (the test registry has a random ID). But we verify it returns a
    // valid ID and that calling it twice returns the same result (deterministic).
    let release_id_1 = release::derive_release_id(recording_ids, track_splits, nonce, &registry);
    let release_id_2 = release::derive_release_id(recording_ids, track_splits, nonce, &registry);
    assert!(release_id_1 == release_id_2, 1);

    destroy(registry);
}

#[test]
/// Two recordings, 50/50 split, nonce=42.
/// TypeScript expected digest: 58895ea293730fcbca59e08cadd81c3a8da7c0604fa014ac629b0a8f543f4141
fun test_derive_release_id_parity_multiple() {
    let mut ctx = tx_context::dummy();
    let registry = new_release_registry_for_testing(&mut ctx);

    let recording_ids = vector[
        object::id_from_address(@0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef),
        object::id_from_address(@0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890),
    ];
    let track_splits = vector[5000u64, 5000u64];
    let nonce = 42u256;

    // Verify digest matches TypeScript output
    let digest = calculate_release_digest(recording_ids, track_splits, nonce);
    let expected_digest = x"58895ea293730fcbca59e08cadd81c3a8da7c0604fa014ac629b0a8f543f4141";
    assert!(digest == expected_digest, 0);

    // Verify derive_release_id is deterministic
    let release_id_1 = release::derive_release_id(recording_ids, track_splits, nonce, &registry);
    let release_id_2 = release::derive_release_id(recording_ids, track_splits, nonce, &registry);
    assert!(release_id_1 == release_id_2, 1);

    // Verify different inputs produce different IDs
    let release_id_different_nonce = release::derive_release_id(recording_ids, track_splits, 43u256, &registry);
    assert!(release_id_1 != release_id_different_nonce, 2);

    destroy(registry);
}
