# Relayer Gas Griefing via Approval Revocation

## Description

The `claimSnowman` function supports gasless claiming: a receiver signs off-chain, and a relayer submits the transaction. The relayer pays gas; the receiver's Snow is transferred via `safeTransferFrom(receiver, address(this), amount)`, which requires the receiver to have approved the airdrop contract beforehand.

Because approval and claim are separate transactions, there is a time window between them. A malicious receiver can approve the contract, request a relayer to submit the claim, and then revoke the approval before the relayer's transaction is mined. The relayer's transaction reverts at `transferFrom`, and the relayer loses the gas spent on the failed transaction.

```solidity
// SnowmanAirdrop.sol - transferFrom requires prior approval; no atomic approve+claim
@>        i_snow.safeTransferFrom(receiver, address(this), amount); // send tokens to contract... akin to burning
```

```solidity
// Snow.sol - standard ERC20, no EIP-2612 permit
@>contract Snow is ERC20, Ownable {
```

## Risk

**Likelihood (medium)**:

* Receivers must approve before relayer can claim; approval and claim are separate txs
* Malicious receiver can revoke approval after relayer picks up the claim
* Relayers (protocol-sponsored or third-party) are exposed when offering gasless claims

**Impact (low)**:

* Relayer loses gas on reverted transaction
* No protocol or user fund loss
* Relayer service becomes economically unviable if griefing is frequent

**Severity (low)**:

## Proof of Concept

1. Alice approves airdrop contract for 100 Snow and signs `SnowmanClaim(alice, 100)`.
2. Alice requests a relayer to submit the claim.
3. Relayer broadcasts `claimSnowman(alice, proof, v, r, s)`.
4. Before the tx is mined, Alice calls `snow.approve(airdrop, 0)` to revoke.
5. Relayer's tx executes: `safeTransferFrom(alice, ...)` reverts (insufficient allowance).
6. Relayer pays gas for a failed tx; Alice pays nothing.

```solidity
// Alice approves, then revokes before relayer's tx is mined
snow.approve(address(airdrop), 100);
// ... relayer submits claim ...
snow.approve(address(airdrop), 0); // grief: revoke

// Relayer's tx reverts
vm.prank(relayer);
vm.expectRevert(); // SafeERC20: decreased allowance below zero or transfer failed
airdrop.claimSnowman(alice, merkleProof, v, r, s);
```

## Recommended Mitigation

Implement EIP-2612 `permit` on the Snow token so approval can be set atomically with the claim:

```diff
- contract Snow is ERC20, Ownable {
+ contract Snow is ERC20, Ownable, ERC20Permit {
```

Then support a combined flow where the relayer executes `permit` + `claimSnowman` in a single transaction:

```solidity
// User signs both permit and claim; relayer submits one tx
snow.permit(receiver, airdrop, amount, deadline, v, r, s);
airdrop.claimSnowman(receiver, merkleProof, v2, r2, s2);
```

The approval is set and consumed in the same block, eliminating the revocation window.
