module musicos::facilitator;

use musicos::protocol::Protocol;
use sui::balance::Balance;
use sui::coin::Coin;
use sui::vec_set::{Self, VecSet};

public struct Facilitator<phantom Identity: key> has key {
    id: UID,
    history: VecSet<ID>,
}

const EItemIdInHistory: u64 = 0;

public fun authorize<Identity: key>(
    self: &mut Facilitator<Identity>,
    identity: &Identity,
    protocol: &Protocol,
) {
    // Purge the history if it exceeds the window size.
    if (self.history.length() >= protocol.facilitator_history_window_size() as u64) {
        self.history.into_keys();
    };
    let identity_id = object::id(identity);
    // Assert the item ID is not in the history.
    assert!(!self.history.contains(&identity_id), EItemIdInHistory);
    // Insert the item ID into the history.
    self.history.insert(identity_id);
}

public(package) fun pay_commission<Currency>(
    balance: &mut Balance<Currency>,
    protocol: &Protocol,
    ctx: &TxContext,
) {
    // Calculate the commission to pay to the facilitator.
    let commission_value = protocol.facilitator_commission_rate().calc(balance.value());
    // Split the commission from the balance and transfer it to the facilitator's address balance.
    balance.split(commission_value).send_funds(ctx.sender());
}
