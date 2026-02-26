# mintSnowman Missing Access Control Allows Unrestricted NFT Minting

## Description

The airdrop design requires users to burn Snow tokens via `SnowmanAirdrop.claimSnowman` to receive Snowman NFTs. The `Snowman.mintSnowman` function is the sole mint entry point and is intended to be called only by the airdrop contract. However, `mintSnowman` has no access control; it is `external` and callable by any address. An attacker can call `mintSnowman(attacker, amount)` directly and mint unlimited Snowman NFTs without burning any Snow or going through Merkle/signature verification.

```solidity
// @> Root cause: no access control; any address can call
function mintSnowman(address receiver, uint256 amount) external {
    for (uint256 i = 0; i < amount; i++) {
        _safeMint(receiver, s_TokenCounter);
        emit SnowmanMinted(receiver, s_TokenCounter);
        s_TokenCounter++;
    }
}
```

## Risk

**Likelihood (high)**:

* No authentication or authorization is required; a single transaction can mint any amount.
* Attack is trivial to execute; no special conditions or setup needed.

**Impact (high)**:

* Unlimited Snowman NFTs can be minted without burning Snow.
* Airdrop economics and scarcity are broken; legitimate claimers' allocations are diluted.
* Protocol invariant (1 Snow → 1 Snowman via airdrop) is violated.

**Severity (high)**:

## Proof of Concept

1. Attacker calls `Snowman.mintSnowman(attacker, 1000)`.
2. Contract mints 1000 Snowman NFTs to the attacker.
3. No Snow is burned; no Merkle proof or signature is checked.
4. Attacker receives NFTs intended only for airdrop participants.

```solidity
// Attacker mints without going through airdrop
snowman.mintSnowman(attacker, 1000); // succeeds; no Snow burned
```

## Recommended Mitigation

Restrict `mintSnowman` to the SnowmanAirdrop contract only. Use a setter since Snowman is deployed before the airdrop.

```diff
+ address private s_snowmanAirdrop;

  constructor(string memory _SnowmanSvgUri) ERC721("Snowman Airdrop", "SNOWMAN") Ownable(msg.sender) {
      s_SnowmanSvgUri = _SnowmanSvgUri;
  }

+ function setSnowmanAirdrop(address _airdrop) external onlyOwner {
+     s_snowmanAirdrop = _airdrop;
+ }

  function mintSnowman(address receiver, uint256 amount) external {
+     if (msg.sender != s_snowmanAirdrop) revert SM__NotAllowed();
      for (uint256 i = 0; i < amount; i++) {
          _safeMint(receiver, s_TokenCounter);
          emit SnowmanMinted(receiver, s_TokenCounter);
          s_TokenCounter++;
      }
  }
```

Alternatively, use OpenZeppelin's `AccessControl` and grant the `MINTER_ROLE` to the airdrop contract.
