import { walrusClient } from "./clients";

export type FFprobeResult = {
  streams: Array<{
    index: number;
    codec_name: string;
    codec_long_name: string;
    codec_type: "audio" | "video" | "subtitle" | string;
    codec_tag_string: string;
    codec_tag: string;
    sample_fmt?: string; // e.g. "s32"
    sample_rate?: string; // e.g. "48000" (string in ffprobe JSON)
    channels?: number; // e.g. 2
    channel_layout?: string; // e.g. "stereo"
    bits_per_sample?: number;
    bits_per_raw_sample?: string;
    r_frame_rate?: string;
    avg_frame_rate?: string;
    time_base?: string;
    start_pts?: number;
    start_time?: string;
    duration_ts?: number;
    duration?: string;
    extradata_size?: number;
    disposition?: Record<string, number>;
    tags?: Record<string, string>;
  }>;
  format: {
    filename: string;
    nb_streams: number;
    nb_programs: number;
    nb_stream_groups: number;
    format_name: string;
    format_long_name: string;
    start_time?: string;
    duration?: string;
    size?: string;
    bit_rate?: string;
    probe_score?: number;
    tags?: Record<string, string>;
  };
};

async function decodeToPcm(
  audioFilePath: string,
  channels: number,
  sampleRate: number
): Promise<ArrayBuffer> {
  const proc = Bun.spawn([
    "ffmpeg",
    "-v",
    "error",
    "-i",
    audioFilePath,
    "-f",
    "s32le",
    "-acodec",
    "pcm_s32le",
    "-ac",
    channels.toString(),
    "-ar",
    sampleRate.toString(),
    "pipe:1",
  ]);

  const pcmArrayBuffer = await new Response(proc.stdout).arrayBuffer();
  await proc.exited;
  return pcmArrayBuffer;
}

async function createAudio(audioFilePath: string) {
  const audioFile = Bun.file(audioFilePath);

  if (!audioFile.exists()) {
    throw new Error(`${audioFilePath} does not exist`);
  }

  const proc = Bun.spawn([
    "ffprobe",
    "-v",
    "error",
    "-show_format",
    "-show_streams",
    "-print_format",
    "json",
    "input.flac",
  ]);
  const metadataJson = await new Response(proc.stdout).text();
  const metadata = JSON.parse(metadataJson) as FFprobeResult;

  if (metadata.streams.length === 0) {
    throw new Error("No streams found.");
  } else if (metadata.streams.length > 1) {
    throw new Error("Multiple streams not supported.");
  }

  const stream = metadata.streams[0];
  const bitDepth = stream?.bits_per_raw_sample;
  if (!bitDepth) throw new Error("Bit depth not found.");
  const channels = stream?.channels;
  if (!channels) throw new Error("Channels not found.");
  const sampleRateStr = stream?.sample_rate;
  if (!sampleRateStr) throw new Error("Sample rate not found.");
  const sampleRate = parseInt(sampleRateStr);

  const pcm = await decodeToPcm(audioFilePath, channels, sampleRate);
  const hasher = new Bun.CryptoHasher("blake2b256");
  hasher.update(pcm);
  const hash = hasher.digest();

  // We divide by 4 here because we are using signed
  // 32-bit little-endian for PCM decoding.
  if (pcm.byteLength / channels / 4 !== stream.duration_ts) {
    throw new Error("Duration mismatch.");
  }

  console.log(`Bit Depth: ${bitDepth}`);
  console.log(`Channels: ${channels}`);
  console.log(`Sample Rate: ${sampleRate}`);
  console.log(`Samples: ${stream.duration_ts}`);
  console.log(`PCM Hash: ${hash.toString("hex")}`);
}

await createAudio("/Users/brianli/Documents/GitHub/musicos/cli/input.flac");
