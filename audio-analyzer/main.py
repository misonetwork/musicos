import numpy as np
import soundfile as sf
import librosa
from pathlib import Path
from pydantic import BaseModel, ConfigDict
from typing import Optional

AUDIO_FILE_PATH = Path("/Users/bl/Documents/GitHub/musicos/test-data/test.wav")


class AudioFileStatistics(BaseModel):
    spectral_centroid: float | None = None


class AudioFile(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)
    data: np.ndarray
    data_downmixed: np.ndarray | None = None
    channels: int
    sample_rate: int
    samples: int
    statistics: AudioFileStatistics


def read_audio_file(path: Path) -> AudioFile:
    data, sr = sf.read(path, always_2d=True)
    n_samples, n_channels = data.shape
    audio_file = AudioFile(
        data=data,
        channels=n_channels,
        sample_rate=sr,
        samples=n_samples,
        statistics=AudioFileStatistics(),
    )
    return audio_file


def downmix_audio_file(audio_file: AudioFile):
    if audio_file.channels == 1:
        mono = audio_file.data[:, 0]
    else:
        L = audio_file.data[:, 0]
        R = audio_file.data[:, 1]
        mono = 0.5 * (L + R)

    audio_file.data_downmixed = np.clip(mono, -1.0, 1.0)
    return


def calculate_spectral_centroid(
    audio_file: AudioFile, frame_size: int = 2048, hop_size: int = 512
):
    """
    Calculate spectral centroid using librosa.

    Returns:
        centroids_arr: Array of centroid values for each frame (in Hz)
        mean_centroid_hz: Mean spectral centroid across all frames (in Hz)
    """
    if audio_file.data_downmixed is None:
        raise ValueError("Audio file must be downmixed first.")

    # librosa.feature.spectral_centroid expects 1D array
    y = audio_file.data_downmixed.astype(np.float32)

    # Calculate spectral centroid
    # n_fft is the frame size, hop_length is the hop size
    centroids = librosa.feature.spectral_centroid(
        y=y, sr=audio_file.sample_rate, n_fft=frame_size, hop_length=hop_size
    )

    # librosa returns shape (1, n_frames), so we flatten to 1D
    centroids_arr = centroids[0].astype(np.float32)

    if len(centroids_arr) == 0:
        return np.zeros(0, dtype=np.float32), 0.0

    mean_centroid_hz = float(centroids_arr.mean())

    audio_file.statistics.spectral_centroid = mean_centroid_hz

    return


def main():
    audio_file = read_audio_file(AUDIO_FILE_PATH)
    print(f"Loaded audio file: {AUDIO_FILE_PATH}")
    print(f"Channels: {audio_file.channels}")
    print(f"Sample Rate: {audio_file.sample_rate}")
    print(f"Samples: {audio_file.samples}")

    print("Downmixing audio file...")
    downmix_audio_file(audio_file)
    if isinstance(audio_file.data_downmixed, np.ndarray):
        print("Downmixed audio data!")
    else:
        raise ValueError("Downmixed audio data not found.")

    print("Calculating spectral centroid...")
    calculate_spectral_centroid(audio_file)
    print(f"Spectral Centroid: {audio_file.statistics.spectral_centroid} Hz")


if __name__ == "__main__":
    main()
