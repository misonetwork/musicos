import { sealClient, walrusClient } from "./clients";
import { z } from "zod";
import { bcs, fromHex, toHex } from "@mysten/bcs";
import { ONE_MB } from "./constants";
import { cleanEnv, str, num } from "envalid";
import pMap from "p-map";
import { SessionKey } from "@mysten/seal";
import { suiClient } from "./clients";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";

type Blob = {
  contents: Uint8Array;
  identifier: string;
  tags?: Record<string, string>;
};

type EncryptedChunk = {
  index: number;
  encryptedObject: Uint8Array;
  digest: string;
};

const env = cleanEnv(process.env, {
  ACL_PACKAGE_ID: str(),
  SEAL_CONCURRENCY: num(),
  SEAL_PACKAGE_ID: str(),
  SUI_MNEMONIC: str(),
});

const keypair = Ed25519Keypair.deriveKeypair(env.SUI_MNEMONIC);
console.log(`SUI Address: ${keypair.getPublicKey().toSuiAddress()}`);

export const FlacPacketSchema = z.object({
  pts_time: z.string(),
  duration_time: z.string(),
  size: z.coerce.number(),
  pos: z.coerce.number(),
});

export type FlacPacket = z.infer<typeof FlacPacketSchema>;

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

type FlacChunk = {
  bytes: Uint8Array;
  digest: string;
  start_pos: number;
  end_pos: number;
};

export function chunkFlacBytes(
  bytes: Uint8Array,
  packets: FlacPacket[],
  targetBytes: number
): FlacChunk[] {
  if (packets.length === 0) {
    throw new Error("No packets provided");
  }

  const out: FlacChunk[] = [];
  let start = 0;
  let acc = 0;
  let chunkStartPos = packets[0]!.pos;
  let lastPacket = packets[0]!;

  packets.forEach((p, index) => {
    const would = acc + p.size;
    if (acc > 0 && would > targetBytes) {
      const chunkBytes = bytes.subarray(start, p.pos);
      const hasher = new Bun.CryptoHasher("blake2b256");
      hasher.update(chunkBytes);
      const digest = hasher.digest().toString("hex");

      out.push({
        bytes: chunkBytes,
        digest,
        start_pos: chunkStartPos,
        end_pos: lastPacket.pos + lastPacket.size,
      });

      start = p.pos;
      acc = 0;
      chunkStartPos = p.pos;
    }
    acc += p.size;
    lastPacket = p;
  });

  // Push the final chunk
  const chunkBytes = bytes.subarray(start);
  const hasher = new Bun.CryptoHasher("blake2b256");
  hasher.update(chunkBytes);
  const digest = hasher.digest().toString("hex");

  out.push({
    bytes: chunkBytes,
    digest,
    start_pos: chunkStartPos,
    end_pos: lastPacket.pos + lastPacket.size,
  });

  return out;
}

export async function getFlacPackets(
  audioFilePath: string
): Promise<FlacPacket[]> {
  const proc = Bun.spawn(
    [
      "ffprobe",
      "-v",
      "error",
      "-select_streams",
      "a:0",
      "-show_packets",
      "-show_entries",
      "packet=pos,size,pts_time,duration_time",
      "-of",
      "json",
      audioFilePath,
    ],
    { stdout: "pipe" }
  );

  const stdout = await new Response(proc.stdout).text();
  await proc.exited;

  const json = JSON.parse(stdout);
  const packets = json.packets as any[];

  return packets
    .filter((p) => p.pos !== undefined && p.size !== undefined)
    .map((p) =>
      FlacPacketSchema.parse({
        pos: Number(p.pos),
        size: Number(p.size),
        pts_time: String(p.pts_time ?? "0"),
        duration_time: String(p.duration_time ?? "0"),
      })
    )
    .sort((a, b) => a.pos - b.pos);
}

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
  await proc.exited;
  const pcmArrayBuffer = await new Response(proc.stdout).arrayBuffer();
  return pcmArrayBuffer;
}

async function main(audioFilePath: string) {
  console.log(`Reading audio file: ${audioFilePath}`);
  const audioFile = Bun.file(audioFilePath);

  if (!audioFile.exists()) {
    throw new Error(`${audioFilePath} does not exist`);
  }

  console.log("Extracting FLAC metadata...");
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

  console.log("Extracting FLAC stream metadata...");
  const stream = metadata.streams[0];
  const bitDepth = stream?.bits_per_raw_sample;
  if (!bitDepth) throw new Error("Bit depth not found.");
  const channels = stream?.channels;
  if (!channels) throw new Error("Channels not found.");
  const sampleRateStr = stream?.sample_rate;
  if (!sampleRateStr) throw new Error("Sample rate not found.");
  const sampleRate = parseInt(sampleRateStr);

  console.log("Decoding FLAC to PCM...");
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

  const flacPackets = await getFlacPackets(audioFilePath);
  const flacBytes = new Uint8Array(await audioFile.arrayBuffer());
  console.log("Splitting source into 1MB chunks...");
  const flacChunks = chunkFlacBytes(flacBytes, flacPackets, ONE_MB);
  console.log(`Chunk Count: ${flacChunks.length}`);

  console.log("Encrypting chunks with Seal...");
  const id = bcs.u64().serialize(0).toHex();
  const encryptedChunks: EncryptedChunk[] = await pMap(
    flacChunks,
    async (flacChunk, index) => {
      console.log(
        `Chunk ${index}: Range ${flacChunk.start_pos}-${flacChunk.end_pos} (${flacChunk.bytes.length} bytes)`
      );
      const encryptedObject = await sealClient.encrypt({
        data: flacChunk.bytes,
        threshold: 1,
        packageId: env.ACL_PACKAGE_ID,
        id,
      });
      // Compute the digest of the encrypted chunk.
      const hasher = new Bun.CryptoHasher("blake2b256");
      hasher.update(encryptedObject.encryptedObject);
      const digest = hasher.digest();
      console.log(`Digest: ${digest.toString("hex")}`);
      return {
        index,
        encryptedObject: encryptedObject.encryptedObject,
        digest: digest.toString("hex"),
      };
    },
    { concurrency: env.SEAL_CONCURRENCY }
  );
  encryptedChunks.sort((a, b) => a.index - b.index);
  console.log(`Encrypted ${encryptedChunks.length} chunks!`);

  const sessionKey = await SessionKey.create({
    address: keypair.getPublicKey().toSuiAddress(),
    packageId: env.ACL_PACKAGE_ID,
    ttlMin: 1,
    suiClient,
  });
  const message = sessionKey.getPersonalMessage();
  const { signature } = await keypair.signPersonalMessage(message);
  sessionKey.setPersonalMessageSignature(signature);

  const blobs: Blob[] = [];

  for (const encryptedChunk of encryptedChunks) {
    // Test decryption!
    const tx = new Transaction();
    tx.moveCall({
      target: `${env.ACL_PACKAGE_ID}::policies::seal_approve`,
      arguments: [
        tx.pure.vector("u8", fromHex(id)),
        tx.object(SUI_CLOCK_OBJECT_ID),
      ],
    });
    const txBytes = await tx.build({
      client: suiClient,
      onlyTransactionKind: true,
    });
    const decryptedBytes = await sealClient.decrypt({
      data: encryptedChunk.encryptedObject,
      sessionKey,
      txBytes,
    });
    console.log(
      `Decrypted chunk ${encryptedChunk.index}: ${decryptedBytes.length} bytes`
    );
    const blob = {
      contents: encryptedChunk.encryptedObject,
      identifier: encryptedChunk.index.toString(),
      tags: {
        "content-type": "audio/flac",
      },
    };
    blobs.push(blob);
  }

  console.log("Decryption test successful!");
  console.log("Encoding Walrus quilt...");
  const quilt = await walrusClient.walrus.encodeQuilt({ blobs: blobs });
  const quiltBlob = await walrusClient.walrus.encodeBlob(quilt.quilt);
  console.log(`Encoded Walrus Quilt ID: ${quiltBlob.blobId}`);

  const result = await walrusClient.walrus.writeBlob({
    blob: quilt.quilt,
    deletable: true,
    epochs: 1,
    signer: keypair,
  });
  console.log(`Uploaded Walrus Blob ID: ${result.blobId}`);
}

await main("/Users/brianli/Documents/GitHub/musicos/cli/input.flac");

function assertIsFlac(bytes: Uint8Array) {
  if (
    bytes.length < 4 ||
    bytes[0] !== 0x66 ||
    bytes[1] !== 0x4c ||
    bytes[2] !== 0x61 ||
    bytes[3] !== 0x43
  ) {
    throw new Error("Not a FLAC stream: missing 'fLaC' marker.");
  }
}
