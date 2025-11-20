// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::utils;

public(package) fun calculate_duration(samples: u64, sample_rate: u32): u64 {
    ((samples as u128) / (sample_rate as u128)) as u64
}
