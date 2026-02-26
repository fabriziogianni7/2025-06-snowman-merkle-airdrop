# buySnow(0): No-Op Allowed, Gas Waste

## Description

The `buySnow` function does not validate that `amount > 0`. A caller can invoke `buySnow(0)`, which mints 0 tokens with 0 payment (or 0 WETH). The transaction succeeds but performs no meaningful state change. The caller pays gas for a no-op.

```solidity
// Snow.sol - amount can be zero
function buySnow(uint256 amount) external payable canFarmSnow {
    if (msg.value == (s_buyFee * amount)) {  // amount=0 -> 0 == 0
        _mint(msg.sender, amount);           // mints 0
    } else {
        i_weth.safeTransferFrom(msg.sender, address(this), (s_buyFee * amount));  // transfers 0
        _mint(msg.sender, amount);
    }
    s_earnTimer = block.timestamp;  // still updates global state
    emit SnowBought(msg.sender, amount);
}
```

## Risk

**Likelihood (low)**:

* Callers would need to explicitly pass 0; unlikely in normal use.

**Impact (low)**:

* Wasted gas on a no-op transaction.
* Best-practice: validate meaningful inputs.

**Severity (low)**:

## Recommended Mitigation

Revert when `amount` is zero:

```diff
  function buySnow(uint256 amount) external payable canFarmSnow {
+     if (amount == 0) revert S__ZeroValue();
      if (msg.value == (s_buyFee * amount)) {
```
