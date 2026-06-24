// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module composition_ops::composition_ops_tests;

use composition_ops::composition_ops;

const PROTOCOL_MAX_ROYALTY_BPS: u16 = 2000;

#[test]
fun new_config_accepts_zero() {
    let cfg = composition_ops::new_config(0);
    assert!(cfg.max_royalty_bps() == 0);
}

#[test]
fun new_config_accepts_mid_range() {
    let cfg = composition_ops::new_config(1234);
    assert!(cfg.max_royalty_bps() == 1234);
}

#[test]
fun new_config_accepts_protocol_max() {
    let cfg = composition_ops::new_config(PROTOCOL_MAX_ROYALTY_BPS);
    assert!(cfg.max_royalty_bps() == PROTOCOL_MAX_ROYALTY_BPS);
}

#[test]
#[expected_failure(abort_code = composition_ops::ECeilingAboveProtocolMax)]
fun new_config_rejects_above_protocol_max() {
    let _cfg = composition_ops::new_config(PROTOCOL_MAX_ROYALTY_BPS + 1);
}

#[test]
#[expected_failure(abort_code = composition_ops::ECeilingAboveProtocolMax)]
fun new_config_rejects_far_above_protocol_max() {
    let _cfg = composition_ops::new_config(10_000);
}
