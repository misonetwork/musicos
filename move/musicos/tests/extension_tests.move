#[test_only]
module musicos::extension_tests;

use musicos::extension;
use std::unit_test::assert_eq;

// Error codes from extension.move
const EAlreadyRegistered: u64 = 0;
const ENotRegistered: u64 = 1;

/// Test witness type for extension.
public struct TestExt() has drop;

/// Another test witness for testing multiple extensions.
public struct OtherExt() has drop;

/// Test config stored as extension data.
public struct TestConfig has drop, store {
    value: u64,
}

// === Happy Path ===

#[test]
fun test_register_extension() {
    let ctx = &mut tx_context::dummy();
    let mut uid = object::new(ctx);

    extension::register<TestExt, TestConfig>(&mut uid, TestConfig { value: 42 });
    assert!(extension::is_registered<TestExt>(&uid));
    assert!(!extension::is_unregistered<TestExt>(&uid));

    // Cleanup
    extension::unregister<TestExt, TestConfig>(&mut uid);
    uid.delete();
}

#[test]
fun test_unregister_extension() {
    let ctx = &mut tx_context::dummy();
    let mut uid = object::new(ctx);

    extension::register<TestExt, TestConfig>(&mut uid, TestConfig { value: 42 });
    let config = extension::unregister<TestExt, TestConfig>(&mut uid);

    assert_eq!(config.value, 42);
    assert!(extension::is_unregistered<TestExt>(&uid));
    assert!(!extension::is_registered<TestExt>(&uid));

    uid.delete();
}

#[test]
fun test_config_access() {
    let ctx = &mut tx_context::dummy();
    let mut uid = object::new(ctx);

    extension::register<TestExt, TestConfig>(&mut uid, TestConfig { value: 42 });

    // Read config
    let config = extension::config<TestExt, TestConfig>(&uid);
    assert_eq!(config.value, 42);

    // Mutate config
    let config_mut = extension::config_mut<TestExt, TestConfig>(&mut uid);
    config_mut.value = 100;

    // Verify mutation
    let config = extension::config<TestExt, TestConfig>(&uid);
    assert_eq!(config.value, 100);

    // Cleanup
    extension::unregister<TestExt, TestConfig>(&mut uid);
    uid.delete();
}

#[test]
fun test_multiple_extensions() {
    let ctx = &mut tx_context::dummy();
    let mut uid = object::new(ctx);

    extension::register<TestExt, TestConfig>(&mut uid, TestConfig { value: 1 });
    extension::register<OtherExt, TestConfig>(&mut uid, TestConfig { value: 2 });

    assert!(extension::is_registered<TestExt>(&uid));
    assert!(extension::is_registered<OtherExt>(&uid));

    let config1 = extension::config<TestExt, TestConfig>(&uid);
    assert_eq!(config1.value, 1);

    let config2 = extension::config<OtherExt, TestConfig>(&uid);
    assert_eq!(config2.value, 2);

    // Cleanup
    extension::unregister<TestExt, TestConfig>(&mut uid);
    extension::unregister<OtherExt, TestConfig>(&mut uid);
    uid.delete();
}

// === Error Conditions ===

#[test, expected_failure(abort_code = EAlreadyRegistered, location = musicos::extension)]
fun test_register_duplicate() {
    let ctx = &mut tx_context::dummy();
    let mut uid = object::new(ctx);

    extension::register<TestExt, TestConfig>(&mut uid, TestConfig { value: 1 });
    extension::register<TestExt, TestConfig>(&mut uid, TestConfig { value: 2 }); // should fail

    extension::unregister<TestExt, TestConfig>(&mut uid);
    uid.delete();
}

#[test, expected_failure(abort_code = ENotRegistered, location = musicos::extension)]
fun test_unregister_not_registered() {
    let ctx = &mut tx_context::dummy();
    let mut uid = object::new(ctx);

    extension::unregister<TestExt, TestConfig>(&mut uid); // not registered

    uid.delete();
}

#[test, expected_failure(abort_code = ENotRegistered, location = musicos::extension)]
fun test_config_not_registered() {
    let ctx = &mut tx_context::dummy();
    let uid = object::new(ctx);

    extension::config<TestExt, TestConfig>(&uid); // not registered

    uid.delete();
}

#[test, expected_failure(abort_code = ENotRegistered, location = musicos::extension)]
fun test_assert_registered_fails() {
    let ctx = &mut tx_context::dummy();
    let uid = object::new(ctx);

    extension::assert_registered<TestExt>(&uid);

    uid.delete();
}

#[test, expected_failure(abort_code = EAlreadyRegistered, location = musicos::extension)]
fun test_assert_unregistered_fails() {
    let ctx = &mut tx_context::dummy();
    let mut uid = object::new(ctx);

    extension::register<TestExt, TestConfig>(&mut uid, TestConfig { value: 1 });
    extension::assert_unregistered<TestExt>(&uid);

    extension::unregister<TestExt, TestConfig>(&mut uid);
    uid.delete();
}
