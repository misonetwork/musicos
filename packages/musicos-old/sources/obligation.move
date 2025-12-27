// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

/// This module implements an Obligation.
module musicos::obligation;

use interest_bps::bps::BPS;
use std::u64::min;
use std::string::String;
use sui::balance::Balance;
use sui::clock::Clock;

//=== Structs ===

public struct Obligation has drop, store {
    kind: ObligationKind,
    state: ObligationState,
    recipient: address,
}

//=== Enums ===

/// Defines an obligation's payout rule and settlement condition.
///
/// In MusicOS, an `Obligation` is paid from principal *before* forwarding the
/// remainder to rights holders (e.g., advance recoupment).
public enum ObligationKind has copy, drop, store {
    /// Always pays `rate` (BPS) of principal.
    /// `total_paid_value` tracks cumulative paid value.
    Percentage { rate: BPS, total_paid_value: u64 },
    /// Pays `rate` (BPS) of principal only within `[start_ts, end_ts]` (ms).
    /// Settles when `now > end_ts`. Tracks cumulative paid value.
    TimeBound { rate: BPS, total_paid_value: u64, start_ts: u64, end_ts: u64 },
    /// Pays `min(rate(principal), balance_value)` and decrements `balance_value`.
    /// Settles when `balance_value == 0`. Tracks cumulative paid value.
    ValueBound { rate: BPS, total_paid_value: u64, balance_value: u64, },
}

public enum ObligationState has copy, drop, store {
    Active,
    Settled(u64),
}

//=== Errors ===

const EInvalidTimeBound: u64 = 0;
const ENotSettledState: u64 = 1;

//=== Package Functions ===

// TODO: Fix logic.
// Returns a boolean that indicates whether settlement is complete.
public(package) fun settle<Currency>(
    self: &mut Obligation,
    principal_value: u64,
    balance: &mut Balance<Currency>,
    clock: &Clock,
): (u64, bool) {
    let mut payment_value = 0;
    let mut is_settled = false;

    match (&mut self.kind) {
        ObligationKind::Percentage { rate, total_paid_value } => {
            payment_value = (*rate).calc(principal_value);
            // Update the total paid value.
            *total_paid_value = *total_paid_value + payment_value;
        },
        ObligationKind::TimeBound { rate, total_paid_value, start_ts, end_ts } => {
            let now = clock.timestamp_ms();
            // Only calculate the value if the obligation is within its time bounds.
            if (now >= *start_ts && now <= *end_ts) {
                payment_value = (*rate).calc(principal_value);
                // Update the total paid value.
                *total_paid_value = *total_paid_value + payment_value;
            };
            // If the obligation is past its time bounds, mark it as settled.
            if (now > *end_ts) {
                is_settled = true;
            };
        },
        ObligationKind::ValueBound { rate, total_paid_value, balance_value } => {
            // Calculate the obligation value as the minumum of the obligation value and the balance value.
            payment_value = min((*rate).calc(principal_value), *balance_value);
            // Update the total paid value.
            *total_paid_value = *total_paid_value + payment_value;
            // Subtract the value from the balance value.
            *balance_value = *balance_value - payment_value;
            // If the balance value is 0, mark it as settled.
            if (*balance_value == 0) {
                is_settled = true;
            };
        },
    };

    // Transfer the obligation value to the recipient if it's greater than 0.
    if (payment_value > 0) {
        balance.split(payment_value).send_funds(self.recipient);
    };

    // Mark the obligation as settled if it's complete.
    if (is_settled) {
        self.state = ObligationState::Settled(clock.timestamp_ms());
    };

    (payment_value, is_settled)
}

public(package) fun calculate(self: &Obligation, principal: u64): u64 {
    match (self.kind) {
        ObligationKind::Percentage { rate, .. } => { rate.calc(principal) },
        ObligationKind::TimeBound { rate, .. } => { rate.calc(principal) },
        ObligationKind::ValueBound { rate, balance_value, .. } => {
            min(rate.calc(principal), balance_value)
        },
    }
}

//=== Package View Functions ===

public(package) fun rate(self: &Obligation): BPS {
    match (self.kind) {
        ObligationKind::Percentage { rate, .. } => rate,
        ObligationKind::TimeBound { rate, .. } => rate,
        ObligationKind::ValueBound { rate, .. } => rate,
    }
}

public(package) fun kind_name(self: &Obligation): String {
    match (self.kind) {
        ObligationKind::Percentage { .. } => "Percentage",
        ObligationKind::TimeBound { .. } => "TimeBound",
        ObligationKind::ValueBound { .. } => "ValueBound",
    }
}

public(package) fun recipient(self: &Obligation): address {
    self.recipient
}

public(package) fun is_active(self: &Obligation): bool {
    match (&self.state) {
        ObligationState::Active => true,
        _ => false,
    }
}

public(package) fun is_settled(self: &Obligation): bool {
    match (&self.state) {
        ObligationState::Settled(_) => true,
        _ => false,
    }
}
