# buySnow: msg.value Not Validated When Using WETH Path — Accidental ETH Loss

## Description

The `buySnow` function has two payment paths: ETH (when `msg.value == s_buyFee * amount`) and WETH (else branch). When `msg.value > 0` but not equal to the required fee, the flow goes to the else branch and uses `safeTransferFrom` for WETH. If the user has WETH and allowance, the transaction succeeds: they pay WETH and also send ETH. The ETH stays in the contract and is eventually collected by the fee collector. The user loses the accidentally sent ETH with no way to recover it.

The contract does not require `msg.value == 0` when using the WETH path, so users (or integrators forwarding `msg.value`) can accidentally overpay with ETH.

```solidity
// Snow.sol - no validation of msg.value in WETH path
function buySnow(uint256 amount) external payable canFarmSnow {
    if (msg.value == (s_buyFee * amount)) {
        _mint(msg.sender, amount);
    } else {
        // @> msg.value not checked; user can send ETH by mistake and lose it
        i_weth.safeTransferFrom(msg.sender, address(this), (s_buyFee * amount));
        _mint(msg.sender, amount);
    }
    // ...
}
```

## Risk

**Likelihood (medium)**:

* Integrators or contracts that forward `msg.value` may send ETH when calling `buySnow` with the WETH path.
* Users interacting via wallets that default to sending ETH can accidentally include ETH in the transaction.

**Impact (medium)**:

* Accidental ETH is sent to the contract and collected by the fee collector.
* User has no way to recover the lost ETH.

**Severity (medium)**:

## Proof of Concept

1. User intends to buy 1 Snow with WETH; they have approved the contract.
2. User's wallet or a relayer includes `msg.value = 0.1 ether` in the transaction (e.g. for gas or by mistake).
3. `msg.value (0.1e18) != s_buyFee * amount` (e.g. 5e18), so the else branch runs.
4. `safeTransferFrom` succeeds (user has WETH).
5. User receives Snow but loses the 0.1 ETH, which goes to the collector on the next `collectFee()`.

## Recommended Mitigation

Revert when `msg.value` is non-zero but does not match the ETH path requirement:

```diff
  function buySnow(uint256 amount) external payable canFarmSnow {
      if (msg.value == (s_buyFee * amount)) {
          _mint(msg.sender, amount);
      } else {
+         if (msg.value != 0) revert S__ZeroValue(); // or custom error: "Use WETH path with no ETH"
          i_weth.safeTransferFrom(msg.sender, address(this), (s_buyFee * amount));
          _mint(msg.sender, amount);
      }
      // ...
  }
```
