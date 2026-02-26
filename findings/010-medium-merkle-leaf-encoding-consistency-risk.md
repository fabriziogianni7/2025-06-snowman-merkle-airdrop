# Merkle Leaf Encoding Consistency Risk Between Contract and Script

## Description

The Merkle leaf used for claim verification is computed in two different places with different encoding approaches. In `SnowmanAirdrop.claimSnowman`, the leaf is built as `keccak256(bytes.concat(keccak256(abi.encode(receiver, amount))))`. In `SnowMerkle.s.sol`, leaves are built as `keccak256(bytes.concat(keccak256(ltrim64(abi.encode(data)))))` where `data` is a `bytes32[]` of `(address, amount)`. Both aim to produce the same 64-byte preimage before double-hashing, but they use distinct encoding paths: one uses `abi.encode(address, uint256)` (tuple), the other uses `ltrim64(abi.encode(bytes32[]))` (dynamic array with offset/length stripped). If the script's input schema (field order, types, or encoding) ever changes, or if the contract is updated without updating the script (or vice versa), the leaves will diverge and all valid claims will fail with `SA__InvalidProof()`.

```solidity
// SnowmanAirdrop.sol - tuple encoding
bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(receiver, amount))));
```

```solidity
// SnowMerkle.s.sol - bytes32[] + ltrim64
// @> Different encoding path; must stay in sync with contract
leafs[i] = keccak256(bytes.concat(keccak256(ltrim64(abi.encode(data)))));
```

## Risk

**Likelihood (medium)**:

* Two separate implementations must remain consistent across deployments and script changes.
* Input JSON schema (types, field order) in `input.json` must match what the contract expects.
* No automated test or invariant verifies that both encodings produce identical leaves for the same (receiver, amount).

**Impact (high)**:

* If encodings diverge, every claim reverts with `SA__InvalidProof()`.
* Airdrop becomes unusable; no user can claim Snowman NFTs.
* Root cause is subtle and may be missed during debugging.

**Severity (medium)**:

## Proof of Concept

1. Developer modifies `SnowMerkle.s.sol` to support an additional field (e.g. `deadline`) in the leaf.
2. Script regenerates Merkle tree with new leaf format.
3. Contract still uses `abi.encode(receiver, amount)`; leaf format is unchanged.
4. All generated proofs fail verification; claims revert.

Alternatively, if `input.json` uses a different field order (e.g. amount before address) or the Murky `ltrim64` behavior is misunderstood, leaves will not match.

```solidity
// Contract expects: keccak256(abi.encode(receiver, amount))
// Script produces: keccak256(ltrim64(abi.encode([bytes32(addr), bytes32(amount)])))
// These must produce identical 64-byte preimages; no test enforces this
```

## Recommended Mitigation

**Option 1: Single source of truth** — Move leaf construction into a shared library or helper used by both the contract and the script (e.g. a Solidity library that the script imports and calls via `vm.run()` or forge script).

**Option 2: Add invariant test** — Add a Foundry test that, for sample (receiver, amount) pairs, computes the leaf using the same logic as the contract and verifies it matches the leaf produced by the script's encoding.

```solidity
function test_merkleLeafEncodingMatchesScript() public {
    address receiver = address(0x123);
    uint256 amount = 100;
    bytes32 contractLeaf = keccak256(bytes.concat(keccak256(abi.encode(receiver, amount))));
    // Run script encoding and assert contractLeaf == scriptLeaf
}
```

**Option 3: Document and lock** — Document the exact leaf format (field order, types, double-hash) and add a comment in both files referencing each other. Consider a CI check that regenerates the tree and asserts the root matches a known value.
