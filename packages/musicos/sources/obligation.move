module musicos::obligation;

use interest_bps::bps::BPS;
use std::u64::min;
use sui::clock::Clock;
use sui::balance::Balance;

//=== Structs ===

public struct Obligation has copy, drop, store {
    kind: ObligationKind,
    state: ObligationState,
    recipient: address,
}

//=== Enums ===

public enum ObligationKind has copy, drop, store {
    Percentage { rate: BPS },
    TimeBound { start_ts: u64, end_ts: u64, rate: BPS },
    ValueBound { balance_value: u64, rate: BPS },
}

public enum ObligationState has copy, drop, store {
    Active,
    Settled(u64),
}

//=== Errors ===

const EInvalidTimeBound: u64 = 0;
const ENotSettledState: u64 = 1;

//=== Package Functions ===

// Returns a boolean that indicates whether settlement is complete.
public(package) fun settle<Currency>(self: &mut Obligation, principal_value: u64, balance: &mut Balance<Currency>, clock: &Clock): (u64, bool) {
    let mut obligation_value = 0;
    let mut is_settled = false;

    match (&mut self.kind) {
        ObligationKind::Percentage { rate } => {
            obligation_value = (*rate).calc(principal_value);
        },
        ObligationKind::TimeBound { start_ts, end_ts, rate } => {
            let now = clock.timestamp_ms();
            // Only calculate the value if the obligation is within its time bounds.
            if (now >= *start_ts && now <= *end_ts) {
                obligation_value = (*rate).calc(principal_value);
            };
            // If the obligation is past its time bounds, mark it as settled.
            if (now > *end_ts) {
                is_settled = true;
            };
        },
        ObligationKind::ValueBound { balance_value, rate } => {
            // Calculate the obligation value as the minumum of the obligation value and the balance value.
            obligation_value = min((*rate).calc(principal_value), *balance_value);
            // Subtract the value from the balance value.
            *balance_value = *balance_value - obligation_value;
            // If the balance value is 0, mark it as settled.
            if (*balance_value == 0) {
                is_settled = true;
            };
        },
    };

    // Transfer the obligation value to the recipient if it's greater than 0.
    if (obligation_value > 0) {
        balance.split(obligation_value).send_funds(self.recipient);
    };

    // Mark the obligation as settled if it's complete.
    if (is_settled) {
        self.state = ObligationState::Settled(clock.timestamp_ms());
    };

    (obligation_value, is_settled)
}

public(package) fun calculate(self: &Obligation, principal: u64): u64 {
    match (self.kind) {
        ObligationKind::Percentage { rate } => { rate.calc(principal) },
        ObligationKind::TimeBound { rate, .. } => { rate.calc(principal) },
        ObligationKind::ValueBound { rate, balance_value } => { min(rate.calc(principal), balance_value) },
    };
}

public(package) fun destroy(self: Obligation) {
    let Obligation { ... } = self;
}

//=== Package View Functions ===

public(package) fun rate(self: &Obligation): &BPS {
    match (&self.kind) {
        ObligationKind::Percentage { rate } => rate,
        ObligationKind::TimeBound { rate, .. } => rate,
        ObligationKind::ValueBound { rate, .. } => rate,
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
        ObligationState::Settled => true,
        _ => false,
    }
}
