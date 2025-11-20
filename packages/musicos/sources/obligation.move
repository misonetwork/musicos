module musicos::obligation;

use interest_bps::bps::BPS;
use std::u64::min;
use sui::clock::Clock;

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
    ValueBound { balance: u64, rate: BPS },
}

public enum ObligationState has copy, drop, store {
    Active,
    Settled(u64),
}

//=== Errors ===

const EInvalidTimeBound: u64 = 0;
const ENotSettledState: u64 = 1;

//=== Package Functions ===

public(package) fun calculate(self: &mut Obligation, principal: u64, clock: &Clock): u64 {
    // Initialize obligation value to 0.
    let mut value = 0;
    // Calculate obligation value based on state and kind, and overwrite if needed.
    match (self.state) {
        ObligationState::Active => {
            match (&mut self.kind) {
                ObligationKind::Percentage { rate } => (*rate).calc(principal),
                ObligationKind::TimeBound { start_ts, end_ts, rate } => {
                    let now = clock.timestamp_ms();
                    if (now >= *start_ts && now <= *end_ts) { value = (*rate).calc(principal) };
                    if (now > *end_ts) {
                        self.state = ObligationState::Settled(clock.timestamp_ms())
                    };
                },
                ObligationKind::ValueBound { balance, rate } => {
                    value = min(value, *balance);
                    *balance = *balance - value;
                    if (*balance == 0) {
                        self.state = ObligationState::Settled(clock.timestamp_ms())
                    };
                },
            }
        },
        ObligationState::Settled => { 0 },
    };

    value
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
