# Claim Front-Run Gas Griefing

## Description

The `claimSnowman` function allows anyone to submit a claim on behalf of a receiver who has signed the message and approved the airdrop contract. This enables gasless claiming via relayers. However, because the claim parameters (receiver, proof, signature) are public when a user submits their own transaction, an attacker can observe the pending claim in the mempool and front-run it.

The attacker's transaction executes first: the receiver's Snow is transferred to the contract and the receiver receives their Snowmen. The receiver's original transaction then reverts because their Snow balance is now zero, causing the user to lose the gas spent on the failed transaction.

```solidity
// SnowmanAirdrop.sol - claimSnowman is permissionless; anyone can call with valid (receiver, proof, v, r, s)
@>    function claimSnowman(address receiver, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
        external
        nonReentrant
    {
        // ... no check that msg.sender == receiver
        i_snow.safeTransferFrom(receiver, address(this), amount);
        i_snowman.mintSnowman(receiver, amount);
    }
```

## Risk

**Likelihood (low)**:

* Claim transactions are submitted to the public mempool where anyone can observe them
* Attacker can copy (receiver, merkleProof, v, r, s) and submit with higher gas price
* No economic cost to attacker beyond gas; they may profit from MEV or simply grief

**Impact (low)**:

* Receiver loses gas fees on the reverted transaction
* Receiver still receives their Snowmen (attacker's tx succeeds)
* No direct fund loss; only gas waste

**Severity (low)**:

## Proof of Concept

1. Alice has 100 Snow, approves the airdrop contract, signs `SnowmanClaim(alice, 100)`, and submits `claimSnowman(alice, proof, v, r, s)` to the mempool.
2. Bob observes Alice's pending tx and front-runs with the same parameters and higher gas price.
3. Bob's tx executes first: Alice's 100 Snow → airdrop contract, Alice receives 100 Snowmen.
4. Alice's tx executes: `i_snow.balanceOf(alice) == 0` → reverts at line 93 with `SA__ZeroAmount()`.
5. Alice pays gas for a reverted tx; Bob pays gas for the successful claim.

```solidity
// Attacker front-runs with same calldata
vm.prank(attacker);
airdrop.claimSnowman(alice, merkleProof, v, r, s); // succeeds

// Victim's tx now reverts
vm.prank(alice);
vm.expectRevert(SnowmanAirdrop.SA__ZeroAmount.selector);
airdrop.claimSnowman(alice, merkleProof, v, r, s); // reverts - balance 0
```

## Recommended Mitigation

* **Document the behavior**: Clarify that anyone can submit claims on behalf of signers. Recommend users use a relayer or private mempool (e.g., Flashbots Protect) if they want to avoid gas griefing.
* **Relayer pattern**: Users sign off-chain; a trusted relayer submits the tx. User never submits their own tx, so there is nothing to front-run.
* **Private mempool**: Submit via Flashbots Protect or similar to reduce mempool visibility.
