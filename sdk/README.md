# @musicos/sdk

Typed helpers and transaction builders for MusicOS on Sui.

**Install**

```bash
npm install @musicos/sdk @mysten/sui
```

`@mysten/sui` is a peer dependency, per Sui SDK best practices.

**Usage**

```ts
import { SuiClient } from "@mysten/sui/client";
import { musicos } from "@musicos/sdk";

const client = new SuiClient({ network: "testnet" }).$extend(musicos());

const release = await client.musicos.getRelease("0x...");
```

**Transactions**

```ts
const tx = client.musicos.tx.createParty({
  kind: "Individual",
  name: "Alice",
  adminAddress: "0x...",
  musicOsPackageId: "0x...",
});
```

**Composable transaction thunks**

```ts
import { Transaction } from "@mysten/sui/transactions";

const tx = new Transaction();
tx.add(client.musicos.call.createParty({ /* ... */ }));
// tx.add(otherSdk.call.someOperation(...));
```

**GraphQL helpers**

Some read helpers (e.g. `getGenres`, `getReleaseRegistry`) require a GraphQL client and are exported
as standalone functions from `./queries.ts`.

**Note on object JSON**

Core read helpers use `include: { json: true }` for convenience. For transport-stable parsing, consider
BCS decoding using generated types.
