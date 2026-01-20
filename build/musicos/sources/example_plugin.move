// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/// Example plugin demonstrating the plugin authorization pattern.
///
/// ## How it works:
///
/// 1. Admin registers the plugin for a composition/recording/release:
///    ```
///    example_plugin::register_for_composition(&mut composition, &cap);
///    ```
///
/// 2. Plugin can now access the object's UID using its witness:
///    ```
///    let uid = composition.uid_mut_authorized(example_plugin::witness());
///    // Plugin can now read/write dynamic fields on the composition
///    ```
///
/// 3. Admin can unregister the plugin:
///    ```
///    example_plugin::unregister_for_composition(&mut composition, &cap);
///    ```
module musicos::example_plugin;

use musicos::composition::{Composition, CompositionAdminCap};
use musicos::plugin;
use musicos::recording::{Recording, RecordingAdminCap};
use musicos::release::{Release, ReleaseAdminCap};

//=== Structs ===

/// Witness type for this plugin. Only this module can create instances.
public struct ExamplePlugin has drop {}

//=== Public Functions ===

/// Returns a witness for authorized UID access.
/// Only callable by this module's other functions or tests.
public(package) fun witness(): ExamplePlugin {
    ExamplePlugin {}
}

// --- Registration ---

/// Registers this plugin for a composition.
public fun register_for_composition<CS>(
    composition: &mut Composition<CS>,
    cap: &CompositionAdminCap<CS>,
) {
    plugin::authorize<ExamplePlugin>(composition.uid_mut(cap));
}

/// Registers this plugin for a recording.
public fun register_for_recording<RS>(
    recording: &mut Recording<RS>,
    cap: &RecordingAdminCap<RS>,
) {
    plugin::authorize<ExamplePlugin>(recording.uid_mut(cap));
}

/// Registers this plugin for a release.
public fun register_for_release(release: &mut Release, cap: &ReleaseAdminCap) {
    plugin::authorize<ExamplePlugin>(release.uid_mut(cap));
}

// --- Unregistration ---

/// Unregisters this plugin from a composition.
public fun unregister_for_composition<CS>(
    composition: &mut Composition<CS>,
    cap: &CompositionAdminCap<CS>,
) {
    plugin::revoke<ExamplePlugin>(composition.uid_mut(cap));
}

/// Unregisters this plugin from a recording.
public fun unregister_for_recording<RS>(
    recording: &mut Recording<RS>,
    cap: &RecordingAdminCap<RS>,
) {
    plugin::revoke<ExamplePlugin>(recording.uid_mut(cap));
}

/// Unregisters this plugin from a release.
public fun unregister_for_release(release: &mut Release, cap: &ReleaseAdminCap) {
    plugin::revoke<ExamplePlugin>(release.uid_mut(cap));
}

// --- Plugin Operations ---
//
// These would be the actual plugin functionality that uses uid_mut_authorized.
// For example, a reward pool plugin might have:
//
// public fun deposit<CS, C>(
//     composition: &mut Composition<CS>,
//     coin: Coin<C>,
// ) {
//     let uid = composition.uid_mut_authorized(witness());
//     // Add coin to balance stored in dynamic field
// }
