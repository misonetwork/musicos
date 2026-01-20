module reward_pool_extension::reward_pool_extension;

use musicos::composition::{Composition, CompositionAdminCap};
use musicos::extension;
use musicos::recording::{Recording, RecordingAdminCap};
use reward_pool::reward_pool::{Self, RewardPool};

//=== Structs ===

public struct Witness() has drop;

//=== Public Functions ===

public fun install_on_composition<CS, C>(
    composition: &mut Composition<CS>,
    cap: &CompositionAdminCap<CS>,
): RewardPool<CS, C> {
    let uid_mut = composition.uid_mut(cap);
    extension::authorize<Witness>(uid_mut);
    reward_pool::new<CS, C>(uid_mut)
}

public fun install_on_recording<RS, C>(
    recording: &mut Recording<RS>,
    cap: &RecordingAdminCap<RS>,
): RewardPool<RS, C> {
    let uid_mut = recording.uid_mut(cap);
    extension::authorize<Witness>(uid_mut);
    reward_pool::new<RS, C>(uid_mut)
}
