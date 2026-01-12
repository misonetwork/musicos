module musicos::plugin;

use musicos::admin::AdminCap;
use musicos::protocol::Protocol;
use sui::derived_object::claim;

//=== Structs ===

public struct Plugin<phantom TargetWitness: drop, phantom PluginWitness: drop> has key {
    id: UID,
    state: PluginState,
}

public struct PluginCap<phantom TargetWitness: drop, phantom PluginWitness: drop>() has drop;

public struct PluginKey<
    phantom TargetWitness: drop,
    phantom PluginWitness: drop,
>() has copy, drop, store;

//=== Enums ===

public enum PluginState has copy, drop, store {
    Enabled,
    Disabled,
}

//=== Errors ===

/// Plugin is not in Enabled state.
const ENotEnabledState: u64 = 3;
/// Plugin is not in Disabled state.
const ENotDisabledState: u64 = 4;

//=== Public Functions ===

public fun new<TargetWitness: drop, PluginWitness: drop>(_: &AdminCap, protocol: &mut Protocol) {
    let plugin = Plugin<TargetWitness, PluginWitness> {
        id: claim(protocol.uid_mut(), PluginKey<TargetWitness, PluginWitness>()),
        state: PluginState::Enabled,
    };

    transfer::share_object(plugin);
}

public fun destroy<TargetWitness: drop, PluginWitness: drop>(
    self: Plugin<TargetWitness, PluginWitness>,
    _: &AdminCap,
) {
    match (self.state) {
        PluginState::Disabled => {
            let Plugin { id, .. } = self;
            id.delete();
        },
        _ => abort ENotDisabledState,
    }
}

public fun enable<TargetWitness: drop, PluginWitness: drop>(
    self: &mut Plugin<TargetWitness, PluginWitness>,
    _: &AdminCap,
) {
    match (self.state) {
        PluginState::Disabled => {
            self.state = PluginState::Enabled;
        },
        _ => abort ENotDisabledState,
    }
}

public fun disable<TargetWitness: drop, PluginWitness: drop>(
    self: &mut Plugin<TargetWitness, PluginWitness>,
    _: &AdminCap,
) {
    match (self.state) {
        PluginState::Enabled => {
            self.state = PluginState::Disabled;
        },
        _ => abort ENotEnabledState,
    }
}

public fun request_cap<TargetWitness: drop, PluginWitness: drop>(
    plugin: &Plugin<TargetWitness, PluginWitness>,
    _: PluginWitness,
): PluginCap<TargetWitness, PluginWitness> {
    match (plugin.state) {
        PluginState::Enabled => {
            PluginCap<TargetWitness, PluginWitness>()
        },
        _ => abort ENotEnabledState,
    }
}

//=== Public View Functions ===

public fun id<TargetWitness: drop, PluginWitness: drop>(
    self: &Plugin<TargetWitness, PluginWitness>,
): ID {
    self.id.to_inner()
}
