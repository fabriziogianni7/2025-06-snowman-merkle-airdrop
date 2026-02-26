# earnSnow: Mints 1 Wei Instead of 1 Token — Earn Feature Non-Functional

## Description

The `earnSnow` function is designed to let users earn Snow tokens for free once per week. The intended behavior is to mint 1 Snow token per successful call. However, `_mint(msg.sender, 1)` mints 1 wei (the smallest unit) instead of 1 token.

Snow inherits from OpenZeppelin's ERC20, which uses 18 decimals by default. One token in human terms equals `1e18` in raw units. Minting `1` yields `1e-18` tokens—effectively zero and unusable for any meaningful purpose (claiming airdrops, transfers, etc.).

```solidity
// Snow.sol - mints 1 wei instead of 1 token
function earnSnow() external canFarmSnow {
    if (s_earnTimer != 0 && block.timestamp < (s_earnTimer + 1 weeks)) {
        revert S__Timer();
    }
    _mint(msg.sender, 1);  // @> should be 1e18 for 1 token
    s_earnTimer = block.timestamp;
}
```

## Risk

**Likelihood (high)**:

* The bug affects every `earnSnow` call; no special conditions required.
* Users who rely on the free-earn path receive a negligible amount.

**Impact (medium)**:

* The "earn Snow for free once per week" feature is effectively non-functional.
* Users receive 1e-18 tokens instead of 1 token—human value is essentially zero.
* Recipients who were expected to earn Snow to participate in the airdrop cannot obtain a meaningful balance.

**Severity (medium)**:

## Proof of Concept

With 18 decimals, 1 wei = 1e-18 tokens:

```solidity
// User calls earnSnow() after cooldown
snow.earnSnow();

// balanceOf(user) = 1 (raw units)
// Human value = 1 / 1e18 = 0.000000000000000001 tokens
// Useless for claiming or any practical use
```

## Recommended Mitigation

Mint 1 token (1e18 base units) to align with ERC20 decimals:

```diff
  function earnSnow() external canFarmSnow {
      if (s_earnTimer != 0 && block.timestamp < (s_earnTimer + 1 weeks)) {
          revert S__Timer();
      }
-     _mint(msg.sender, 1);
+     _mint(msg.sender, 1e18);  // 1 token
      s_earnTimer = block.timestamp;
  }
```

Alternatively, use the existing `PRECISION` constant for consistency:

```solidity
_mint(msg.sender, PRECISION);  // PRECISION = 10**18
```
