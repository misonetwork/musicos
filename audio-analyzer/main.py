import numpy as np
import librosa
from pathlib import Path
from pydantic import BaseModel, ConfigDict
from typing import List

AUDIO_FILE_PATH = Path("/Users/bl/Documents/GitHub/musicos/test-data/test.wav")

BPS_MULTIPLIER = 10000


def load_audio(path: str):
    """
    Loads audio as either:
      - shape (1, n_samples) for mono
      - shape (2, n_samples) for stereo

    Rejects files with more than 2 channels.
    """
    # mono=False → keep original channel count
    # sr=None   → preserve original sample rate
    y, sr = librosa.load(path, sr=None, mono=False)

    # librosa returns:
    #   (n_samples,) for mono
    #   (n_channels, n_samples) for multi-channel
    if y.ndim == 1:
        # force shape (1, n_samples) for consistency
        y = y[np.newaxis, :]
    else:
        # If >2 channels, reject for V1
        if y.shape[0] > 2:
            raise ValueError(
                f"V1 only supports mono/stereo. File has {y.shape[0]} channels."
            )

    return y, sr


def to_bps(value: float) -> int:
    """Convert a float value to basis points (BPS)."""
    return int(round(value * BPS_MULTIPLIER))


def calculate_channel_energies(audio_data: np.ndarray) -> List[int]:
    """
    Calculate the energy (sum of squares) per channel as basis points.
    Energy values are normalized so they sum to 10000 BPS (100%).

    Args:
        audio_data: Shape (n_channels, n_samples)

    Returns:
        List of BPS values, one per channel, summing to 10000
    """
    n_channels = audio_data.shape[0]
    energies = []

    for i in range(n_channels):
        # Energy = sum of squares
        channel_energy = np.sum(audio_data[i, :] ** 2)
        energies.append(channel_energy)

    # Normalize so energies sum to 10000 BPS (100%)
    total_energy = sum(energies)
    if total_energy > 0:
        normalized = [to_bps(e / total_energy) for e in energies]
        # Ensure they sum to exactly 10000 due to rounding
        diff = BPS_MULTIPLIER - sum(normalized)
        if diff != 0:
            normalized[0] += diff
    else:
        # If no energy, distribute evenly
        normalized = [BPS_MULTIPLIER // n_channels] * n_channels
        normalized[0] += BPS_MULTIPLIER - sum(normalized)

    return normalized


def calculate_mean_rms_dbfs(audio_data: np.ndarray) -> int:
    """
    Calculate the overall mean RMS across all channels in dBFS.
    dBFS = 20 × log₁₀(rms / 1.0)
    Stored as: dBFS × 100 (so -20.5 dB = -2050)

    Args:
        audio_data: Shape (n_channels, n_samples)

    Returns:
        dBFS × 100 as integer
    """
    # Calculate RMS across all samples in all channels
    rms = np.sqrt(np.mean(audio_data**2))

    if rms <= 0:
        return -14000  # -140 dB (essentially silence)

    # dBFS = 20 * log10(rms / 1.0)
    dbfs = 20 * np.log10(rms)
    return int(round(dbfs * 100))


def calculate_peak_dbfs(audio_data: np.ndarray) -> int:
    """
    Calculate the peak (maximum absolute) amplitude across all channels in dBFS.
    dBFS = 20 × log₁₀(peak / 1.0)
    Stored as: dBFS × 100

    Args:
        audio_data: Shape (n_channels, n_samples)

    Returns:
        dBFS × 100 as integer
    """
    peak = np.max(np.abs(audio_data))

    if peak <= 0:
        return -14000  # -140 dB (essentially silence)

    # dBFS = 20 * log10(peak / 1.0)
    dbfs = 20 * np.log10(peak)
    return int(round(dbfs * 100))


def calculate_dynamic_range(audio_data: np.ndarray, window_size: int = 2048) -> int:
    """
    Calculate the dynamic range in dB, stored in BPS.
    Uses windowed RMS to find the loudest and quietest segments.

    Dynamic Range (dB) = 20 × log₁₀(max_RMS / min_RMS)
    Stored as: dB × 100 in BPS (so 60 dB = 6000 BPS, 0.01 dB resolution)

    Args:
        audio_data: Shape (n_channels, n_samples)
        window_size: Size of window for local RMS calculation

    Returns:
        BPS value representing dynamic range in dB × 100
    """
    n_channels, n_samples = audio_data.shape

    # Calculate RMS for each window across all channels
    window_rms_values = []

    for start in range(0, n_samples - window_size + 1, window_size // 2):
        end = start + window_size
        window_data = audio_data[:, start:end]
        window_rms = np.sqrt(np.mean(window_data**2))
        if (
            window_rms > 1e-10
        ):  # Only consider non-silent windows (threshold to avoid log issues)
            window_rms_values.append(window_rms)

    if len(window_rms_values) < 2:
        return 0  # No dynamic range if too few windows

    max_rms = np.max(window_rms_values)
    min_rms = np.min(window_rms_values)

    if min_rms <= 0 or max_rms <= 0:
        return 0  # Avoid log of zero

    # Dynamic range in dB: 20 * log10(max/min)
    dynamic_range_db = 20 * np.log10(max_rms / min_rms)

    # Store as dB × 100 (so 60.5 dB = 6050 BPS)
    return int(round(dynamic_range_db * 100))


def calculate_spectral_centroid_hz(audio_data: np.ndarray, sample_rate: int) -> int:
    """
    Calculate the spectral centroid (center of mass of the spectrum) in Hz.
    Uses librosa.feature.spectral_centroid.

    Args:
        audio_data: Shape (n_channels, n_samples)
        sample_rate: Sample rate in Hz

    Returns:
        Spectral centroid in Hz as u16
    """
    # Mix to mono by averaging channels
    mono_audio = np.mean(audio_data, axis=0)

    # Calculate spectral centroid
    centroid = librosa.feature.spectral_centroid(y=mono_audio, sr=sample_rate)

    # Take the mean across time frames
    mean_centroid = np.mean(centroid)

    return int(round(mean_centroid))


def calculate_spectral_flatness(audio_data: np.ndarray) -> int:
    """
    Calculate spectral flatness (measure of how noise-like vs tone-like) in BPS.
    Uses librosa.feature.spectral_flatness.

    Args:
        audio_data: Shape (n_channels, n_samples)

    Returns:
        Spectral flatness in BPS (0-10000, where 10000 = perfectly flat/white noise)
    """
    # Mix to mono by averaging channels
    mono_audio = np.mean(audio_data, axis=0)

    # Calculate spectral flatness (returns values between 0 and 1)
    flatness = librosa.feature.spectral_flatness(y=mono_audio)

    # Take the mean across time frames
    mean_flatness = np.mean(flatness)

    # Convert to BPS (0-10000)
    return to_bps(mean_flatness)


def calculate_tempo_bpm(audio_data: np.ndarray, sample_rate: int) -> int:
    """
    Calculate the tempo in beats per minute.
    Uses librosa.feature.tempo.

    Args:
        audio_data: Shape (n_channels, n_samples)
        sample_rate: Sample rate in Hz

    Returns:
        Tempo in BPM as u16
    """
    # Mix to mono by averaging channels
    mono_audio = np.mean(audio_data, axis=0)

    # Calculate tempo (returns an array, typically with one value)
    tempo = librosa.feature.tempo(y=mono_audio, sr=sample_rate)

    # Extract the first tempo value
    return int(round(tempo[0]))


class AudioStatistics(BaseModel):
    """Audio statistics matching the Move AudioStatistics struct."""

    model_config = ConfigDict(frozen=True)

    # Stored as BPS values
    channel_energies: List[int]  # Sum to 10000 BPS (100%)
    mean_rms_dbfs: int  # dBFS × 100 (e.g., -20.5 dB = -2050)
    peak_dbfs: int  # dBFS × 100
    dynamic_range_db: int  # dB × 100
    spectral_centroid_hz: int  # u16
    spectral_flatness: int  # BPS
    tempo_bpm: int  # u16


def calculate_audio_statistics(
    audio_data: np.ndarray, sample_rate: int
) -> AudioStatistics:
    """
    Calculate all audio statistics for the given audio data.

    Args:
        audio_data: Shape (n_channels, n_samples), values in [-1, 1]
        sample_rate: Sample rate in Hz

    Returns:
        AudioStatistics object with all metrics
    """
    channel_energies = calculate_channel_energies(audio_data)
    mean_rms_dbfs = calculate_mean_rms_dbfs(audio_data)
    peak_dbfs = calculate_peak_dbfs(audio_data)
    dynamic_range_db = calculate_dynamic_range(audio_data)
    spectral_centroid_hz = calculate_spectral_centroid_hz(audio_data, sample_rate)
    spectral_flatness = calculate_spectral_flatness(audio_data)
    tempo_bpm = calculate_tempo_bpm(audio_data, sample_rate)

    return AudioStatistics(
        channel_energies=channel_energies,
        mean_rms_dbfs=mean_rms_dbfs,
        peak_dbfs=peak_dbfs,
        dynamic_range_db=dynamic_range_db,
        spectral_centroid_hz=spectral_centroid_hz,
        spectral_flatness=spectral_flatness,
        tempo_bpm=tempo_bpm,
    )


def main():
    audio_data, sample_rate = load_audio(AUDIO_FILE_PATH)
    print(f"Sample rate: {sample_rate} Hz")
    print(f"Audio shape: {audio_data.shape} (channels, samples)")
    print(f"Duration: {audio_data.shape[1] / sample_rate:.2f} seconds")
    print()

    # Calculate audio statistics
    stats = calculate_audio_statistics(audio_data, sample_rate)

    print("=== Audio Statistics (Raw BPS/Integer Values) ===")
    print(f"Channel Energies: {stats.channel_energies}")
    print(f"  → Sum: {sum(stats.channel_energies)} BPS (should be 10000)")
    print(f"Mean RMS (dBFS × 100): {stats.mean_rms_dbfs}")
    print(f"Peak (dBFS × 100): {stats.peak_dbfs}")
    print(f"Dynamic Range (dB × 100): {stats.dynamic_range_db}")
    print(f"Spectral Centroid (Hz): {stats.spectral_centroid_hz}")
    print(f"Spectral Flatness (BPS): {stats.spectral_flatness}")
    print(f"Tempo (BPM): {stats.tempo_bpm}")
    print()

    # Print human-readable versions
    print("=== Human-Readable Values ===")
    print(f"Channel Energies: {[f'{e / 100:.2f}%' for e in stats.channel_energies]}")
    print(f"Mean RMS: {stats.mean_rms_dbfs / 100:.2f} dBFS")
    print(f"Peak: {stats.peak_dbfs / 100:.2f} dBFS")
    print(f"Dynamic Range: {stats.dynamic_range_db / 100:.2f} dB")
    print(f"Spectral Centroid: {stats.spectral_centroid_hz} Hz")
    print(f"Spectral Flatness: {stats.spectral_flatness / 100:.2f}%")
    print(f"Tempo: {stats.tempo_bpm} BPM")

    return stats


if __name__ == "__main__":
    main()
