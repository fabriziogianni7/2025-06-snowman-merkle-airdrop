# ECDSA Malleability — Protocol Confirmed Protected

## Description

The `claimSnowman` function in `SnowmanAirdrop` verifies EIP-712 signatures using OpenZeppelin's `ECDSA.tryRecover`. ECDSA signatures are malleable: given a valid signature `(r, s, v)`, an attacker can derive a second valid signature `(r, -s mod n, v')` that recovers to the same address. If a protocol uses signatures as unique identifiers (e.g., for replay protection) or does not reject malleable forms, an attacker could bypass single-use semantics by submitting the malleable variant.

The project uses OpenZeppelin Contracts v5.5.0, whose `ECDSA.tryRecover` rejects malleable signatures by requiring the `s` value to be in the lower half order. Signatures with `s` in the upper half order return `RecoverError.InvalidSignatureS` and are not accepted.

```solidity
// SnowmanAirdrop.sol - uses OZ ECDSA
(address actualSigner,,) = ECDSA.tryRecover(digest, v, r, s);
```

```solidity
// lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol
// @> Rejects s-values in upper half order; malleable signatures return InvalidSignatureS
if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
    return (address(0), RecoverError.InvalidSignatureS, s);
}
```

## Risk

**Likelihood (N/A)**:

* The protocol is not vulnerable; no exploit path exists.

**Impact (N/A)**:

* No impact; malleable signatures are rejected.

**Severity (informational)**:

* Auditors should verify the OpenZeppelin version used rejects malleable signatures. This finding documents that the project uses OZ v5.5.0, which does.

## Proof of Concept

1. Attacker obtains a valid signature `(r, s, v)` for a `SnowmanClaim` message.
2. Attacker computes malleable signature: `s' = n - s`, `v' = 27 + 28 - v`.
3. Attacker calls `claimSnowman(receiver, proof, v', r, s')`.
4. `ECDSA.tryRecover` returns `RecoverError.InvalidSignatureS` because `s'` is in the upper half order.
5. Signature verification fails; `claimSnowman` reverts with `SA__InvalidSignature()`.

```solidity
// Malleable signature rejected by OZ ECDSA
bytes32 s_malleable = bytes32(uint256(0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) + 1);
(address recovered,,) = ECDSA.tryRecover(digest, v, r, s_malleable);
// recovered == address(0); InvalidSignatureS returned
```

## Recommended Mitigation

No mitigation required. The protocol correctly uses OpenZeppelin's `ECDSA.tryRecover`, which rejects malleable signatures. This finding serves as documentation for future audits.

**Recommendation:** When upgrading OpenZeppelin, ensure the version remains ≥ 4.7.3 (or equivalent for v5.x), which introduced malleability rejection.
