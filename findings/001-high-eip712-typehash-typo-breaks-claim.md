# EIP-712 TypeHash Typo Breaks Claim Functionality

## Description

The `claimSnowman` function requires a valid EIP-712 signature to authorize claims. The digest is built via `getMessageHash`, which uses `MESSAGE_TYPEHASH` in the typed data encoding. Per EIP-712, the type string must exactly match between signer and verifier for signature validation to succeed.

The `MESSAGE_TYPEHASH` contains a typo: `"addres"` instead of the correct Solidity/EIP-712 type `"address"`. Any off-chain signer following the EIP-712 specification will use `"SnowmanClaim(address receiver, uint256 amount)"`, producing a different type hash and thus a different digest. The contract will compute a different digest and `ECDSA.recover` will not return the expected signer, causing all signature checks to fail.

```solidity
// @> Root cause: "addres" is not a valid EIP-712 type; must be "address"
bytes32 private constant MESSAGE_TYPEHASH = keccak256("SnowmanClaim(addres receiver, uint256 amount)");
```

## Risk

**Likelihood (high)**:

* The typo is present in the deployed contract; no runtime condition is required for it to manifest.
* Any standard EIP-712 signer (e.g. ethers.js, viem, wallet signing) uses the correct `"address"` type string.
* The mismatch occurs on every claim attempt.

**Impact (high)**:

* All legitimate claims fail with `SA__InvalidSignature()`.
* Core airdrop functionality is unusable; no user can claim Snowman NFTs.
* Airdrop funds remain locked with no way to distribute them as intended.

**Severity (high)**:

## Proof of Concept

1. Off-chain signer creates a valid EIP-712 signature using `"SnowmanClaim(address receiver, uint256 amount)"`.
2. User calls `claimSnowman(receiver, merkleProof, v, r, s)`.
3. Contract computes `getMessageHash(receiver)` using `MESSAGE_TYPEHASH` with `"addres"`.
4. `keccak256("SnowmanClaim(addres receiver, uint256 amount)") != keccak256("SnowmanClaim(address receiver, uint256 amount)")`.
5. The digest used for verification differs from the one the signer signed.
6. `ECDSA.tryRecover` returns an address that does not match `receiver`.
7. `_isValidSignature` returns false; transaction reverts with `SA__InvalidSignature()`.

```solidity
// Demonstrates the hash mismatch
bytes32 wrongHash = keccak256("SnowmanClaim(addres receiver, uint256 amount)");
bytes32 correctHash = keccak256("SnowmanClaim(address receiver, uint256 amount)");
assert(wrongHash != correctHash); // Hashes differ; signatures will never verify
```

## Recommended Mitigation

Fix the signature for the typehash.

```diff
- bytes32 private constant MESSAGE_TYPEHASH = keccak256("SnowmanClaim(addres receiver, uint256 amount)");
+ bytes32 private constant MESSAGE_TYPEHASH = keccak256("SnowmanClaim(address receiver, uint256 amount)");
```

Ensure the off-chain signer uses the exact same type string: `"SnowmanClaim(address receiver, uint256 amount)"`.
