# collectFee: No Funds Check and Raw transfer Instead of safeTransfer

## Description

The `collectFee` function has two best-practice issues:

1. **No funds check**: It does not verify that there are funds to collect before performing transfers. When both WETH balance and ETH balance are zero, the collector can still call `collectFee`, which executes `i_weth.transfer(s_collector, 0)` and `payable(s_collector).call{value: 0}("")`. Both succeed (ERC20 transfer of 0 and ETH send of 0 are valid), but the caller pays gas for a no-op.

2. **Raw transfer instead of safeTransfer**: The contract uses `i_weth.transfer()` instead of `SafeERC20.safeTransfer()`. The contract already imports SafeERC20 and uses `safeTransferFrom` in `buySnow`; using raw `transfer` here is inconsistent and can fail with non-standard ERC20s (e.g. tokens that don't return a boolean). WETH is standard, but the pattern is unsafe if the token were ever changed.

```solidity
// Snow.sol - no check before transfer, raw transfer
function collectFee() external onlyCollector {
    uint256 collection = i_weth.balanceOf(address(this));
    i_weth.transfer(s_collector, collection);  // should use safeTransfer
    (bool collected,) = payable(s_collector).call{value: address(this).balance}("");
    require(collected, "Fee collection failed!!!");
}
```

## Risk

**Likelihood (low)**:

* Collector must call when there are no fees; typically they would only call when expecting funds.
* Automated keepers or scripts might call periodically regardless of balance.

**Impact (low)**:

* Wasted gas on no-op when nothing to collect.
* Best-practice violation: withdrawal functions should validate that there is something to withdraw before performing external calls.
* Raw `transfer` can behave incorrectly with non-standard ERC20s; `safeTransfer` is the recommended pattern.

**Severity (low)**:

## Proof of Concept

1. No users have bought Snow with WETH; no one has sent ETH to the contract.
2. Collector calls `collectFee()`.
3. `collection = 0`, `address(this).balance = 0`.
4. `i_weth.transfer(s_collector, 0)` succeeds.
5. `payable(s_collector).call{value: 0}("")` succeeds.
6. Collector pays gas for no meaningful state change.

## Recommended Mitigation

1. Add an early revert when there is nothing to collect.
2. Use `safeTransfer` instead of raw `transfer` for consistency and safety with non-standard ERC20s.

```diff
  function collectFee() external onlyCollector {
      uint256 collection = i_weth.balanceOf(address(this));
+     if (collection == 0 && address(this).balance == 0) {
+         revert S__ZeroValue(); // or a dedicated error
+     }
-     i_weth.transfer(s_collector, collection);
+     i_weth.safeTransfer(s_collector, collection);
      (bool collected,) = payable(s_collector).call{value: address(this).balance}("");
      require(collected, "Fee collection failed!!!");
  }
```
