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
import { hash } from "./utils";

const env = cleanEnv(process.env, {
  ACL_PACKAGE_ID: str(),
  SEAL_CONCURRENCY: num(),
  SEAL_PACKAGE_ID: str(),
  SOURCE_FILE: str({ desc: "The path to the source FLAC file." }),
  SUI_MNEMONIC: str(),
});

export type WalrusBlob = {
  contents: Uint8Array;
  identifier: string;
  tags?: Record<string, string>;
};

export type Chunk = {
  bytes: Uint8Array;
  digest: string;
  index: number;
  start_pos: number;
  end_pos: number;
  start_pts: number;
  end_pts: number;
  size: number;
};

export type DecryptedChunk = {
  index: number;
  bytes: Uint8Array;
};

export type EncryptedChunk = {
  bytes: Uint8Array;
  source: Chunk;
};

export const FlacPacketSchema = z.object({
  pts: z.coerce.number(),
  duration: z.coerce.number(),
  pos: z.coerce.number(),
  size: z.coerce.number(),
});
export type FlacPacket = z.infer<typeof FlacPacketSchema>;

const keypair = Ed25519Keypair.deriveKeypair(env.SUI_MNEMONIC);
console.log(`SUI Address: ${keypair.getPublicKey().toSuiAddress()}`);

async function chunkFlacBytes(flacBytes: Uint8Array, packets: FlacPacket[], maxChunkSize: number) {
  if (!packets || packets.length === 0) throw new Error("No packets provided");

  const chunks: Chunk[] = [];
  let chunkStartPos = 0;
  let chunkStartPts = packets[0]!.pts;
  let accumulatedSize = packets[0]!.pos;
  let lastPacket = packets[0]!;
  let chunkIndex = 0;

  for (let i = 0; i < packets.length; i++) {
    const packet = packets[i]!;
    const wouldBeSize = accumulatedSize + packet.size;

    if (accumulatedSize > 0 && wouldBeSize > maxChunkSize) {
      const chunkEndPos = lastPacket.pos + lastPacket.size;
      const chunkBytes = new Uint8Array(flacBytes.buffer.slice(chunkStartPos, chunkEndPos));

      const hasher = new Bun.CryptoHasher("blake2b256");
      hasher.update(chunkBytes);
      const digest = hasher.digest().toString("hex");

      chunks.push({
        bytes: chunkBytes,
        digest,
        index: chunkIndex++,
        start_pos: chunkStartPos,
        end_pos: chunkEndPos,
        start_pts: chunkStartPts,
        end_pts: lastPacket.pts + lastPacket.duration,
        size: chunkBytes.length,
      });

      chunkStartPos = packet.pos;
      chunkStartPts = packet.pts;
      accumulatedSize = 0;
    }

    accumulatedSize += packet.size;
    lastPacket = packet;
  }

  const chunkEndPos = lastPacket.pos + lastPacket.size;
  const chunkBytes = new Uint8Array(flacBytes.buffer.slice(chunkStartPos, chunkEndPos));

  chunks.push({
    bytes: chunkBytes,
    digest: hash(chunkBytes),
    index: chunkIndex,
    start_pos: chunkStartPos,
    end_pos: chunkEndPos,
    start_pts: chunkStartPts,
    end_pts: lastPacket.pts + lastPacket.duration,
    size: chunkBytes.length,
  });

  return chunks;
}

async function getFlacPackets(audioFilePath: string): Promise<FlacPacket[]> {
  const proc = Bun.spawn(
    [
      "ffprobe",
      "-v",
      "error",
      "-select_streams",
      "a:0",
      "-show_packets",
      "-show_entries",
      "packet=pts,duration,pos,size",
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

  const sortedPackets = packets
    .filter((p) => p.pos !== undefined && p.size !== undefined)
    .map((p) => FlacPacketSchema.parse(p))
    .sort((a, b) => a.pos - b.pos);

  return sortedPackets;
}

async function decryptChunks(encryptedChunks: EncryptedChunk[]) {
  const sessionKey = await SessionKey.create({
    address: keypair.getPublicKey().toSuiAddress(),
    packageId: env.ACL_PACKAGE_ID,
    ttlMin: 1,
    suiClient,
  });
  const message = sessionKey.getPersonalMessage();
  const { signature } = await keypair.signPersonalMessage(message);
  sessionKey.setPersonalMessageSignature(signature);

  const allIds: string[] = [];
  const tx = new Transaction();
  encryptedChunks.forEach((encryptedChunk) => {
    const id = bcs.u64().serialize(encryptedChunk.source.index).toHex();
    tx.moveCall({
      target: `${env.ACL_PACKAGE_ID}::policies::seal_approve`,
      arguments: [tx.pure.vector("u8", fromHex(id)), tx.object(SUI_CLOCK_OBJECT_ID)],
    });
    allIds.push(id);
  });
  const txBytes = await tx.build({
    client: suiClient,
    onlyTransactionKind: true,
  });

  await sealClient.fetchKeys({
    ids: allIds,
    txBytes,
    sessionKey,
    threshold: 1,
  });

  const decryptedChunks = await pMap(
    encryptedChunks,
    async (encryptedChunk, index) => {
      const decryptedBytes = await sealClient.decrypt({
        data: encryptedChunk.bytes,
        sessionKey,
        txBytes,
      });
      return {
        index,
        bytes: decryptedBytes,
      };
    },
    { concurrency: env.SEAL_CONCURRENCY }
  );
  decryptedChunks.sort((a, b) => a.index - b.index);

  return decryptedChunks;
}

async function encryptChunks(chunks: Chunk[]): Promise<EncryptedChunk[]> {
  const encryptedChunks: EncryptedChunk[] = await pMap(
    chunks,
    async (chunk) => {
      const id = bcs.u64().serialize(0).toHex();
      const { encryptedObject } = await sealClient.encrypt({
        data: chunk.bytes,
        threshold: 1,
        packageId: env.ACL_PACKAGE_ID,
        id,
      });
      return {
        bytes: encryptedObject,
        source: chunk,
      };
    },
    { concurrency: env.SEAL_CONCURRENCY }
  );
  return encryptedChunks;
}

async function reassembleDecryptedBytes(decryptedChunks: DecryptedChunk[]): Promise<Uint8Array> {
  decryptedChunks.sort((a, b) => a.index - b.index);
  const totalLength = decryptedChunks.reduce((sum, chunk) => sum + chunk.bytes.length, 0);
  const assembled = new Uint8Array(totalLength);
  let offset = 0;
  for (const chunk of decryptedChunks) {
    assembled.set(chunk.bytes, offset);
    offset += chunk.bytes.length;
  }
  return assembled;
}

async function encodeWalrusQuilt(encryptedChunks: EncryptedChunk[]) {
  const blobs: WalrusBlob[] = [];
  encryptedChunks.forEach((encryptedChunk) => {
    blobs.push({
      contents: encryptedChunk.bytes,
      identifier: encryptedChunk.source.index.toString(),
    });
  });
  const quilt = await walrusClient.walrus.encodeQuilt({ blobs: blobs });
  return quilt;
}

async function main() {
  const flacFile = Bun.file(env.SOURCE_FILE);
  if (!flacFile.exists()) throw new Error(`Source file ${env.SOURCE_FILE} does not exist`);
  const flacBytes = new Uint8Array(await flacFile.arrayBuffer());
  const sourceDigest = hash(flacBytes);
  const flacPackets = await getFlacPackets(flacFile.name!);
  const flacChunks = await chunkFlacBytes(flacBytes, flacPackets, ONE_MB);
  const encryptedChunks = await encryptChunks(flacChunks);
  const decryptedChunks = await decryptChunks(encryptedChunks);
  const assembledChunks = await reassembleDecryptedBytes(decryptedChunks);
  const reassembledSourceDigest = hash(assembledChunks);
  if (reassembledSourceDigest !== sourceDigest) throw new Error("Source and reassembled source digest mismatch.");
  const quilt = await encodeWalrusQuilt(encryptedChunks);
  const blob = await walrusClient.walrus.encodeBlob(quilt.quilt);
  console.log(`Encoded Walrus Blob ID: ${blob.blobId}`);
  const result = await walrusClient.walrus.writeBlob({
    blob: quilt.quilt,
    deletable: true,
    epochs: 1,
    signer: keypair,
    attributes: {
      "content-type": "audio/flac",
    },
  });
  console.log(`Uploaded Walrus Blob ID: ${result.blobId}`);
}

await main().catch(console.error);
