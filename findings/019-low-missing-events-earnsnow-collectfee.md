# Missing Events in earnSnow and collectFee

## Description

The contract declares `SnowEarned` and `FeeCollected` events but never emits them. `earnSnow()` mints 1 Snow to the caller without emitting `SnowEarned`. `collectFee()` transfers WETH and ETH to the collector without emitting `FeeCollected`. Indexers, off-chain monitors, and users cannot reliably track these actions.

```solidity
// Snow.sol - events declared but never emitted
event SnowEarned(address indexed earner, uint256 indexed amount);
event FeeCollected();

function earnSnow() external canFarmSnow {
    // ...
    _mint(msg.sender, 1);
    // @> SnowEarned not emitted
}

function collectFee() external onlyCollector {
    // ...
    // @> FeeCollected not emitted
}
```

## Risk

**Likelihood (N/A)**:

* Events are simply missing; no exploit required.

**Impact (low)**:

* No off-chain visibility for earn and fee collection.
* Indexers and dashboards cannot track protocol activity.
* Incomplete implementation; declared events suggest intended behavior.

**Severity (low)**:

## Recommended Mitigation

Emit the declared events in the corresponding functions:

```diff
  function earnSnow() external canFarmSnow {
      // ...
      _mint(msg.sender, 1);
      s_earnTimer = block.timestamp;
+     emit SnowEarned(msg.sender, 1);
  }

  function collectFee() external onlyCollector {
      // ...
      require(collected, "Fee collection failed!!!");
+     emit FeeCollected();
  }
```
