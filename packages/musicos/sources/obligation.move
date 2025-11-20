module musicos::obligation;

use interest_bps::bps::BPS;
use sui::clock::Clock;

public struct Obligation has drop, store {
    kind: ObligationKind,
}

public enum ObligationKind has copy, drop, store {
    Percentage { rate: BPS },
    TimeBound { start_ts: u64, end_ts: u64, rate: BPS },
    ValueBound { balance u64, rate: BPS },
}

const EInvalidTimeBound: u64 = 0;

public fun calculate(self: &Obligation, principal: u64, clock: &Clock): u64 {
    match (&mut self.kind) {
        ObligationKind::Percentage { rate } => rate.calc(principal),
        ObligationKind::TimeBound { start_ts, end_ts, rate } => {
            let now = clock.timestamp_ms();
            if (now < start_ts || now > end_ts) 0 else rate.calc(principal)
        },
        ObligationKind::ValueBound { balance, rate } => {},
    }
}
