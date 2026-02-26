# Immutable Merkle Root Prevents Updates and Fixes

## Description

The Merkle root used to validate airdrop claims is stored as an immutable variable and set only in the constructor. There is no function to update the root after deployment. The root is intended to represent a snapshot of eligible recipients and their allocations at a specific point in time.

An immutable root causes two critical issues: (1) new users who acquire Snow after the snapshot cannot be added to the tree and thus cannot claim, and (2) if the root or tree generation contains errors (typos, wrong amounts, missing addresses), there is no way to correct it without redeploying the entire contract.

```solidity
// @> Root cause: i_merkleRoot is immutable; set once in constructor, never updatable
bytes32 private immutable i_merkleRoot; // Merkle root used to validate airdrop claims
// ...
constructor(bytes32 _merkleRoot, address _snow, address _snowman) EIP712("Snowman Airdrop", "1") {
    // ...
    i_merkleRoot = _merkleRoot;  // @> Only assignment; no setter exists
    // ...
}
```

## Risk

**Likelihood (high)**:

* The root is fixed at deployment; any mistake in the off-chain tree generation is permanent.
* Users who earn or receive Snow after the snapshot block are excluded from the tree and can never claim.
* Operational errors (wrong block, bug in script, data export issues) require full redeployment to fix.

**Impact (high)**:

* Legitimate recipients permanently excluded from the airdrop.
* No recovery path for incorrect allocations without redeploying and migrating state.
* Protocol must redeploy to support additional batches or corrections, increasing cost and complexity.

**Severity (high)**:

## Proof of Concept

1. Protocol deploys `SnowmanAirdrop` with root computed from a snapshot at block N.
2. User Alice earns Snow via `earnSnow()` after block N (or buys Snow later). Alice is not in the Merkle tree.
3. Alice cannot claim: there is no leaf for her address; no valid proof exists.
4. There is no `setMerkleRoot` or similar function; the root cannot be updated to include Alice.
5. Alternatively, the tree generation script has a bug and omits 100 valid recipients. Those recipients cannot claim. The only fix is redeploying the contract with a corrected root.

```solidity
// Scenario: new user cannot be added
// Root was set at deployment; tree contains only users with Snow at snapshot time
// User earns Snow later - no leaf exists, no proof possible
bytes32 root = snowmanAirdrop.getMerkleRoot();
// No setMerkleRoot() or updateRoot() - root is immutable
// New recipients are permanently excluded
```

## Recommended Mitigation

Replace the immutable root with a mutable storage variable and add an access-controlled setter. Use a timelock or multi-sig for root updates to reduce centralization risk.

```diff
- bytes32 private immutable i_merkleRoot; // Merkle root used to validate airdrop claims
+ bytes32 private s_merkleRoot; // Merkle root used to validate airdrop claims

  constructor(bytes32 _merkleRoot, address _snow, address _snowman) EIP712("Snowman Airdrop", "1") {
      // ...
-     i_merkleRoot = _merkleRoot;
+     s_merkleRoot = _merkleRoot;
      // ...
  }

+ function setMerkleRoot(bytes32 _newRoot) external onlyOwner {
+     s_merkleRoot = _newRoot;
+     emit MerkleRootUpdated(_newRoot);
+ }

  function claimSnowman(...) {
      // ...
-     if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
+     if (!MerkleProof.verify(merkleProof, s_merkleRoot, leaf)) {
          revert SA__InvalidProof();
      }
  }

  function getMerkleRoot() external view returns (bytes32) {
-     return i_merkleRoot;
+     return s_merkleRoot;
  }
```

Consider emitting an event on root update and documenting the snapshot block or criteria for each root to avoid confusion.
