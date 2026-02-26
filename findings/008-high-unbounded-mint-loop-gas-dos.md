# Unbounded Mint Loop Causes Gas DoS for Large Claim Amounts

## Description

The `claimSnowman` flow converts 1 Snow token into 1 Snowman NFT. When a user claims, `SnowmanAirdrop` calls `i_snowman.mintSnowman(receiver, amount)` where `amount` equals the user's Snow balance. The `mintSnowman` function in `Snowman.sol` iterates in an unbounded loop, performing one ERC721 `_safeMint` per iteration. Each mint involves storage writes, event emission, and potentially an `onERC721Received` callback. With ~50k–100k+ gas per mint and a block gas limit of ~30M, users with roughly 300+ Snow tokens will exceed the block gas limit and their claim transaction will revert. They permanently lose the ability to claim their allocation.

```solidity
// @> Root cause: unbounded loop over amount
function mintSnowman(address receiver, uint256 amount) external {
    for (uint256 i = 0; i < amount; i++) {  // @> amount can exceed gas limit
        _safeMint(receiver, s_TokenCounter);
        emit SnowmanMinted(receiver, s_TokenCounter);
        s_TokenCounter++;
    }
}
```

## Risk

**Likelihood (high)**:

* Users acquire Snow via `buySnow(amount)` with arbitrary amounts, or via transfers from others.
* Merkle tree and snapshot can include large allocations for whales or early participants.
* No cap on Snow balance or claim amount; large holders are expected in normal operation.

**Impact (high)**:

* Users with large Snow balances cannot claim; transaction reverts with out-of-gas.
* Snow is already transferred to the contract before mint; on revert the full tx rolls back, but the user remains permanently unable to claim.
* Loss of airdrop entitlement for high-value participants.

**Severity (high)**:

## Proof of Concept

1. Alice has 500 Snow (e.g. bought via `buySnow` or received via transfer).
2. Alice calls `claimSnowman` with valid Merkle proof and signature.
3. Snow is transferred from Alice to the airdrop contract.
4. `mintSnowman(alice, 500)` is invoked. The loop runs 500 iterations.
5. Each `_safeMint` costs ~50k–100k+ gas. Total gas exceeds block limit (~30M).
6. Transaction reverts with out-of-gas. Alice cannot claim.

```solidity
// Scenario: 500 Snow -> 500 mints -> OOG
// ~50k gas per _safeMint -> 500 * 50k = 25M gas (approaching block limit)
// 600+ mints would exceed 30M block gas limit
i_snowman.mintSnowman(alice, 500); // reverts OOG
```

## Recommended Mitigation

**Option 1: Use ERC1155** — Replace ERC721 Snowman with ERC1155. Use `_mintBatch` to mint multiple tokens in a single, gas-efficient operation.

```diff
- import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
+ import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

- for (uint256 i = 0; i < amount; i++) {
-     _safeMint(receiver, s_TokenCounter);
-     emit SnowmanMinted(receiver, s_TokenCounter);
-     s_TokenCounter++;
- }
+ uint256[] memory ids = new uint256[](amount);
+ uint256[] memory amounts = new uint256[](amount);
+ for (uint256 i = 0; i < amount; i++) {
+     ids[i] = s_TokenCounter++;
+     amounts[i] = 1;
+ }
+ _mintBatch(receiver, ids, amounts, "");
```

**Option 2: Batched minting** — Allow partial claims. Add a `claimAmount` parameter and cap per transaction. Users with large allocations claim in multiple transactions.

```diff
- function claimSnowman(address receiver, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
+ function claimSnowman(address receiver, uint256 claimAmount, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
      external
      nonReentrant
  {
+     uint256 constant MAX_MINT_PER_TX = 100;
+     require(claimAmount <= MAX_MINT_PER_TX, "SA__ExceedsBatchLimit");
      // ... verify user has at least claimAmount, update claimed tracking
-     i_snowman.mintSnowman(receiver, amount);
+     i_snowman.mintSnowman(receiver, claimAmount);
  }
```

Track `claimedSoFar[receiver]` and allow multiple claims until the full Merkle allocation is exhausted.
