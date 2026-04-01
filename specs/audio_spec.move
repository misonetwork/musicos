module musicos::audio_spec;

#[spec_only]
use prover::prover::{requires, ensures};
use musicos::audio;

/// Audio channels must be > 0.
#[spec(prove, ignore_abort)]
fun new_aborts_zero_channels<I: drop>(
    channels: u8, bit_depth: u8, sample_rate_hz: u32,
    samples: u64, data: ori::walrus_data::WalrusData, ingester: I,
) {
    requires(channels == 0);
    let _a = audio::new<I>(channels, bit_depth, sample_rate_hz, samples, data, ingester);
    ensures(false);
}

/// Audio bit_depth must be 8, 16, 24, or 32.
#[spec(prove, ignore_abort)]
fun new_aborts_invalid_bit_depth<I: drop>(
    channels: u8, bit_depth: u8, sample_rate_hz: u32,
    samples: u64, data: ori::walrus_data::WalrusData, ingester: I,
) {
    requires(channels > 0);
    requires(bit_depth != 8 && bit_depth != 16 && bit_depth != 24 && bit_depth != 32);
    let _a = audio::new<I>(channels, bit_depth, sample_rate_hz, samples, data, ingester);
    ensures(false);
}

/// Audio sample_rate must be > 0.
#[spec(prove, ignore_abort)]
fun new_aborts_zero_sample_rate<I: drop>(
    channels: u8, bit_depth: u8, samples: u64,
    data: ori::walrus_data::WalrusData, ingester: I,
) {
    requires(channels > 0);
    requires(bit_depth == 8 || bit_depth == 16 || bit_depth == 24 || bit_depth == 32);
    let _a = audio::new<I>(channels, bit_depth, 0, samples, data, ingester);
    ensures(false);
}

/// Audio samples must be > 0.
#[spec(prove, ignore_abort)]
fun new_aborts_zero_samples<I: drop>(
    channels: u8, bit_depth: u8, sample_rate_hz: u32,
    data: ori::walrus_data::WalrusData, ingester: I,
) {
    requires(channels > 0);
    requires(bit_depth == 8 || bit_depth == 16 || bit_depth == 24 || bit_depth == 32);
    requires(sample_rate_hz > 0);
    let _a = audio::new<I>(channels, bit_depth, sample_rate_hz, 0, data, ingester);
    ensures(false);
}

/// Audio samples must be <= MAX_SAMPLES to prevent overflow.
#[spec(prove, ignore_abort)]
fun new_aborts_samples_overflow<I: drop>(
    channels: u8, bit_depth: u8, sample_rate_hz: u32,
    samples: u64, data: ori::walrus_data::WalrusData, ingester: I,
) {
    requires(channels > 0);
    requires(bit_depth == 8 || bit_depth == 16 || bit_depth == 24 || bit_depth == 32);
    requires(sample_rate_hz > 0);
    requires(samples > 18_446_744_073_709_551); // MAX_SAMPLES
    let _a = audio::new<I>(channels, bit_depth, sample_rate_hz, samples, data, ingester);
    ensures(false);
}

/// On success, audio preserves all input values.
#[spec(prove, ignore_abort)]
fun new_preserves_values<I: drop>(
    channels: u8, bit_depth: u8, sample_rate_hz: u32,
    samples: u64, data: ori::walrus_data::WalrusData, ingester: I,
) {
    requires(channels > 0);
    requires(bit_depth == 8 || bit_depth == 16 || bit_depth == 24 || bit_depth == 32);
    requires(sample_rate_hz > 0);
    requires(samples > 0);
    requires(samples <= 18_446_744_073_709_551);
    let a = audio::new<I>(channels, bit_depth, sample_rate_hz, samples, data, ingester);
    ensures(a.channels() == channels);
    ensures(a.bit_depth() == bit_depth);
    ensures(a.sample_rate_hz() == sample_rate_hz);
    ensures(a.samples() == samples);
    let _ = a;
}

