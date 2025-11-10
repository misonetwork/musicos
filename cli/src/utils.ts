export function hash(bytes: Uint8Array): string {
  const hasher = new Bun.CryptoHasher("blake2b256");
  hasher.update(bytes);
  return hasher.digest().toString("hex");
}
