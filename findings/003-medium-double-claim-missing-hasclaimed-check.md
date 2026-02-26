# Double Claim Allowed When User Re-acquires Snow

## Description

The `claimSnowman` function is intended to allow each eligible address to claim once. The contract maintains `s_hasClaimedSnowman` to track claimed addresses, but this mapping is only written to—it is never read during the claim flow. As a result, there is no check that prevents an address from claiming again after it has already claimed.

After a successful claim, the user's Snow balance becomes zero because all tokens are transferred to the contract. The only protection against a second claim is the balance check at line 91. If the user later re-acquires the exact amount of Snow from the Merkle snapshot (via `earnSnow`, purchase, or transfer), they can pass all checks and claim again: balance > 0, valid signature for `(receiver, amount)`, and valid Merkle proof for the same leaf.

```solidity
// @> Root cause: s_hasClaimedSnowman is set but never checked before allowing claim
        s_hasClaimedSnowman[receiver] = true;
```

The mapping exists and is exposed via `getClaimStatus`, but `claimSnowman` never reverts when `s_hasClaimedSnowman[receiver]` is already true.

## Risk

**Likelihood (medium)**:

* Snow can be re-acquired through `earnSnow()` (1 Snow per week per user), transfers, or other sources.
* A user who claimed once can obtain the same amount again and reuse the same Merkle proof with a new signature.
* No special privileges or complex setup are required; the attacker is the legitimate claimant.

**Impact (medium)**:

* User receives more Snowman NFTs than intended (double or multiple claims).
* Unbounded minting of Snowman NFTs beyond the airdrop allocation.
* Dilution of NFT value and unfair distribution relative to other claimants.

**Severity (medium)**:

## Proof of Concept

1. Alice has 100 Snow and is in the Merkle tree with leaf `(alice, 100)`.
2. Alice claims successfully: transfers 100 Snow to the contract, receives 100 Snowman NFTs. `s_hasClaimedSnowman[alice] = true` is set.
3. Alice later earns or receives 100 Snow again (e.g. via `earnSnow`, OTC, or DEX).
4. Alice signs a new message `SnowmanClaim(alice, 100)` and calls `claimSnowman` again with the same Merkle proof.
5. All checks pass: balance > 0, valid signature, valid Merkle proof. There is no `require(!s_hasClaimedSnowman[receiver])`.
6. Alice receives another 100 Snowman NFTs and transfers another 100 Snow to the contract.
7. This can repeat each time Alice re-acquires 100 Snow.

```solidity
// Scenario: user claims, re-acquires Snow, claims again
// 1. First claim: alice has 100 Snow, claims, gets 100 Snowman, balance -> 0
// 2. alice earns/receives 100 Snow again
// 3. Second claim: balance check passes, signature valid, merkle valid, no hasClaimed check
// 4. alice gets another 100 Snowman
vm.startPrank(alice);
snowmanAirdrop.claimSnowman(alice, proof, v, r, s); // first claim
// ... alice re-acquires 100 Snow ...
snowmanAirdrop.claimSnowman(alice, proof, v2, r2, s2); // second claim - succeeds
assertEq(snowman.balanceOf(alice), 200); // double allocation
vm.stopPrank();
```

## Recommended Mitigation

Add a check at the start of `claimSnowman` to revert if the receiver has already claimed.

```diff
    function claimSnowman(address receiver, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
        external
        nonReentrant
    {

        if (receiver == address(0)) {
            revert SA__ZeroAddress();
        }
+       if (s_hasClaimedSnowman[receiver]) {
+           revert SA__AlreadyClaimed();
+       }
        if (i_snow.balanceOf(receiver) == 0) {
            revert SA__ZeroAmount();
        }
```

Add the new error:

```diff
    error SA__InvalidProof();
    error SA__InvalidSignature();
    error SA__ZeroAddress();
    error SA__ZeroAmount();
+   error SA__AlreadyClaimed();
```
