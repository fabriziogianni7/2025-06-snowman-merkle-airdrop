# Claim Amount Derived From Current Balance Instead of Snapshot

## Description

The `claimSnowman` function derives the claim amount from the user's current Snow balance (`i_snow.balanceOf(receiver)`) rather than from the Merkle tree leaf. The leaf is built as `keccak256(bytes.concat(keccak256(abi.encode(receiver, amount))))`, where `amount` is this current balance. For the Merkle proof to verify, the leaf must match a leaf in the tree, which was constructed from a snapshot of balances at a specific block.

The intended design is that the Merkle tree encodes the snapshot amount each user is entitled to. The claim should verify the proof against that snapshot amount and mint accordingly. Instead, the contract requires the user's current balance to exactly equal the snapshot amount. If the user has more Snow (e.g. earned or received after the snapshot) or less (e.g. transferred some away), the leaf hash changes and the proof fails.

```solidity
// @> Root cause: amount comes from current balance, not from the tree/snapshot
uint256 amount = i_snow.balanceOf(receiver);  // @> Must exactly match snapshot amount

// note but why putting the amount here? if user has slightly more or slightly less of the amount that he had when
// the root was created, he cannot claim again - bug I think the leaf should not encode the amount
bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(receiver, amount))));
if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
    revert SA__InvalidProof();
}
```

## Risk

**Likelihood (high)**:

* Users naturally change their Snow balance over time via `earnSnow()`, transfers, or purchases.
* The snapshot is taken at a fixed block; any balance change after that breaks the claim.
* No special conditions required; normal usage leads to failed claims.

**Impact (high)**:

* Legitimate recipients with more or less Snow than their snapshot amount cannot claim.
* Users who earned additional Snow after the snapshot are excluded despite being eligible.
* Users who transferred some Snow away cannot claim their allocation.

**Severity (high)**:

## Proof of Concept

1. Snapshot at block N: Alice has 50 Snow. Merkle tree includes leaf `(alice, 50)`.
2. Alice earns 1 Snow via `earnSnow()` before claiming. Her balance is now 51.
3. `amount = i_snow.balanceOf(alice) = 51`. Leaf becomes `hash(alice, 51)`.
4. Merkle proof was generated for leaf `hash(alice, 50)`. Proof fails; `SA__InvalidProof()`.
5. Alice cannot claim. Alternatively, if Alice transfers 10 Snow away, her balance is 40. Leaf `hash(alice, 40)` does not match proof for `hash(alice, 50)`. Claim fails.

```solidity
// Scenario: user earned more Snow after snapshot
// Snapshot: alice has 50 Snow, leaf = hash(alice, 50)
// alice earns 1 Snow -> balance = 51
uint256 amount = i_snow.balanceOf(alice); // 51
bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(alice, 51))));
// Proof was for leaf hash(alice, 50) -> verification fails
MerkleProof.verify(proof, root, leaf); // false -> revert
```

## Recommended Mitigation

Accept the snapshot amount as a parameter and use it for the leaf and mint. The user must hold at least that amount at claim time. The signature must also bind to the amount (e.g. include `amount` in the signed message).

```diff
- function claimSnowman(address receiver, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
+ function claimSnowman(address receiver, uint256 amount, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
      external
      nonReentrant
  {
      // ...
-     if (i_snow.balanceOf(receiver) == 0) {
+     if (i_snow.balanceOf(receiver) < amount) {
          revert SA__ZeroAmount();
      }
-     if (!_isValidSignature(receiver, getMessageHash(receiver), v, r, s)) {
+     if (!_isValidSignature(receiver, amount, getMessageHash(receiver, amount), v, r, s)) {
          revert SA__InvalidSignature();
      }
-     uint256 amount = i_snow.balanceOf(receiver);
      bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(receiver, amount))));
      // ...
  }
```

Update `getMessageHash` to accept `amount` as a parameter so the signature binds to the snapshot amount rather than the current balance.
