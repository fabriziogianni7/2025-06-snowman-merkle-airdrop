# Abnormous fee when buying any amount of Snow tokens

## Description

* The `buySnow` function charges users ETH or WETH to mint Snow tokens. The intended behavior is to collect a fee—either a flat fee per transaction or a percentage of the purchase amount.

* The fee is incorrectly calculated as `s_buyFee * amount`. This multiplies the base fee by the amount of tokens, causing the required payment to scale quadratically with the purchase size. With `_buyFee = 5` (deploy script), `s_buyFee = 5e18`. Buying 1e18 Snow (1 token) requires `5e18 * 1e18 = 5e36` wei (~5e18 ETH). Buying 10 tokens requires 50 ETH. The formula makes any meaningful purchase economically impossible.

```solidity
// src/Snow.sol
s_buyFee = _buyFee * PRECISION; // _buyFee in deploy script is 5, so s_buyFee = 5e18
// ...
function buySnow(uint256 amount) external payable canFarmSnow {
    if (msg.value == (s_buyFee * amount)) {  // @> wrong: multiplies fee by amount
        _mint(msg.sender, amount);
    } else {
        i_weth.safeTransferFrom(msg.sender, address(this), (s_buyFee * amount));  // @> same wrong formula
        _mint(msg.sender, amount);
    }
}
```

## Risk

**Likelihood (high)**:

* The bug is present in every `buySnow` call; no special conditions are required
* Users attempting to buy Snow will either fail (insufficient funds) or pay an absurd amount
* The deploy script uses `FEE = 5`, so `s_buyFee = 5e18`; any non-trivial purchase is blocked by economics

**Impact (high)**:

* `buySnow` is effectively unusable for realistic amounts
* Users who do pay will be massively overcharged (orders of magnitude above any reasonable fee)
* Protocol revenue model for Snow purchases is broken

**Severity (high)**:

## Proof of Concept

* With `_buyFee = 5`, `s_buyFee = 5e18`. To buy 1 Snow token (1e18 base units), the required payment is `5e36` wei (~5e18 ETH)—economically impossible. To buy 10 base units (10 wei of Snow), the user pays 50 ETH to receive a negligible amount. The formula `s_buyFee * amount` treats the fee as a per-unit price multiplied by quantity, which is inconsistent with a flat fee or percentage fee design implied by the constructor and deploy script.

```solidity
// Required payment = s_buyFee * amount = 5e18 * 1e18 = 5e36 wei
// 5e36 wei = 5 * 10^18 ETH — economically impossible

// To buy 10 base units (10 wei of Snow):
// Required payment = 5e18 * 10 = 50e18 wei = 50 ETH
// User pays 50 ETH to receive 10 / 1e18 ≈ 0 tokens (negligible amount)
```

## Recommended Mitigation

**Option A — Flat fee per transaction** (if the intended design is a fixed fee regardless of amount):

```diff
  function buySnow(uint256 amount) external payable canFarmSnow {
-     if (msg.value == (s_buyFee * amount)) {
+     if (msg.value == s_buyFee) {
          _mint(msg.sender, amount);
      } else {
-         i_weth.safeTransferFrom(msg.sender, address(this), (s_buyFee * amount));
+         i_weth.safeTransferFrom(msg.sender, address(this), s_buyFee);
          _mint(msg.sender, amount);
      }
```

Note: For a flat fee, `s_buyFee` should represent the fee in wei. The constructor may need adjustment if `_buyFee = 5` is meant to represent 0.05 ETH or similar (e.g. `s_buyFee = _buyFee * 1e16` for 0.05 ETH).

**Option B — Percentage fee** (if `_buyFee = 5` means 5%):

```diff
  function buySnow(uint256 amount) external payable canFarmSnow {
+     uint256 requiredFee = (amount * s_buyFee) / (100 * PRECISION);
+     if (msg.value == requiredFee) {
          _mint(msg.sender, amount);
      } else {
-         i_weth.safeTransferFrom(msg.sender, address(this), (s_buyFee * amount));
+         i_weth.safeTransferFrom(msg.sender, address(this), requiredFee);
          _mint(msg.sender, amount);
      }
```

For a percentage model, the constructor `s_buyFee = _buyFee * PRECISION` is appropriate (5 → 5e18, so 5% = 5/100). The fix is to divide by `100 * PRECISION` when computing the fee from the amount.
