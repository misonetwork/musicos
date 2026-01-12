// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Basis points (BPS) arithmetic for precise percentage calculations.
/// This module provides a type-safe way to represent and calculate percentages
/// with 0.01% precision (1 basis point = 0.01%, 10,000 basis points = 100%).
///
/// Key features:
/// - Overflow and underflow protection on all operations
/// - Support for addition, subtraction, multiplication, and division
/// - Percentage calculation functions with both floor and ceiling rounding
///
/// Used throughout MusicOS for royalty splits, commission rates, and revenue distribution.
module musicos::bps;

// === Structs ===

/// Represents a percentage value in basis points.
/// 1 BPS = 0.01%, maximum value is 10,000 (100%).
public struct BPS(u64) has copy, drop, store;

// === Errors ===

/// Attempted to create or compute a BPS value exceeding 10,000.
const EOverflow: u64 = 20;
/// Attempted to subtract a larger BPS value from a smaller one.
const EUnderflow: u64 = 21;
/// Attempted to divide by zero.
const EDivideByZero: u64 = 22;

// === Public Mutative Functions ===

/// Creates a new BPS value from a raw basis points number.
/// Aborts if the value exceeds 10,000 (100%).
public fun new(bps: u64): BPS {
    BPS(assert_overflow(bps))
}

/// Adds two BPS values together.
/// Aborts if the result exceeds 10,000.
public fun add(bps_x: &BPS, bps_y: &BPS): BPS {
    BPS(assert_overflow(bps_x.0 + bps_y.0))
}

/// Subtracts bps_y from bps_x.
/// Aborts if bps_y is greater than bps_x.
public fun sub(bps_x: &BPS, bps_y: &BPS): BPS {
    assert!(bps_x.0 >= bps_y.0, EUnderflow);
    BPS(bps_x.0 - bps_y.0)
}

/// Multiplies a BPS value by a scalar (raw value, not BPS).
/// Aborts if the result exceeds 10,000.
public fun mul(bps_x: &BPS, scalar: u64): BPS {
    BPS(assert_overflow(bps_x.0 * scalar))
}

/// Divides a BPS value by a scalar (raw value, not BPS), rounding down.
/// Aborts if scalar is zero.
public fun div(bps_x: &BPS, scalar: u64): BPS {
    assert!(scalar != 0, EDivideByZero);
    BPS(bps_x.0 / scalar)
}

/// Divides a BPS value by a scalar (raw value, not BPS), rounding up.
/// Aborts if scalar is zero.
public fun div_up(bps_x: &BPS, scalar: u64): BPS {
    assert!(scalar != 0, EDivideByZero);
    BPS(if (bps_x.0 == 0) 0 else 1 + (bps_x.0 - 1) / scalar)
}

/// Calculates the BPS percentage of a total value, rounding down.
/// For example, calc(BPS(500), 1000) = 50 (5% of 1000).
public fun calc(bps: &BPS, total: u64): u64 {
    let amount = ((bps.0 as u128) * (total as u128)) / (max_value!() as u128);
    amount as u64
}

/// Calculates the BPS percentage of a total value, rounding up.
/// For example, calc_up(BPS(500), 1000) = 50 (5% of 1000, rounded up).
public fun calc_up(bps: &BPS, total: u64): u64 {
    let (x, y, z) = (bps.0 as u128, total as u128, max_value!() as u128);

    let amount = ((x * y) / z) + if ((x * y) % z > 0) 1 else 0;

    amount as u64
}

// === Public View Functions ===

/// Returns the maximum BPS value (10,000 = 100%).
/// 1 bps = 0.01%, 10,000 bps = 100%.
public macro fun max_value(): u64 {
    10_000
}

/// Returns the raw basis points value.
public fun value(bps: &BPS): u64 {
    bps.0
}

// === Private Functions ===

/// Asserts that a value does not exceed the maximum BPS value.
fun assert_overflow(value: u64): u64 {
    assert!(value <= max_value!(), EOverflow);
    value
}
