# buySnow Blocked After Farming Duration — New Users Cannot Acquire Snow

## Description

The README specifies: *"The Snow token can either be earned for free once a week, or bought at anytime, up until during the ::FARMING_DURATION is over."* "Farming" refers to the free weekly earning via `earnSnow()`, not buying. Buying should be allowed at any time, including after the 12-week farming period ends.

`buySnow()` incorrectly uses the `canFarmSnow` modifier, which reverts with `S__SnowFarmingOver` when `block.timestamp >= i_farmingOver`. This restricts buying to the first 12 weeks only. After that, the primary mechanism for acquiring Snow is permanently disabled.

```solidity
// @> Root cause: canFarmSnow blocks buying after 12 weeks; farming = earning, not buying
modifier canFarmSnow() {
    if (block.timestamp >= i_farmingOver) {
        revert S__SnowFarmingOver();
    }
    _;
}

function buySnow(uint256 amount) external payable canFarmSnow {  // @> Modifier should not apply to buying
```

## Risk

**Likelihood (high)**:

* The restriction is hardcoded; no special conditions are required.
* After 12 weeks from deployment, `buySnow` will revert for every caller.
* This occurs deterministically and cannot be avoided.

**Impact (high)**:

* New users cannot acquire Snow through the primary mechanism (`buySnow`) after the farming period.
* The protocol becomes effectively closed to new participants; only existing Snow holders can continue to stake and claim NFTs.
* Fee collection from new buys stops, reducing protocol revenue.
* Adoption and long-term viability are severely limited.

**Severity (high)**:

## Proof of Concept

1. Snow contract is deployed; `i_farmingOver = block.timestamp + 12 weeks`.
2. During weeks 1–12, users can call `buySnow()` successfully.
3. After week 12, `block.timestamp >= i_farmingOver`.
4. Any call to `buySnow()` reverts with `S__SnowFarmingOver`.
5. New users have no way to acquire Snow via the intended buy path; they can only receive it from existing holders via transfers.

```solidity
// Demonstrates buySnow blocked after farming period
vm.warp(block.timestamp + 12 weeks + 1);

vm.expectRevert(Snow.S__SnowFarmingOver.selector);
snow.buySnow{value: FEE}(1);  // reverts — buying is permanently disabled
```

## Recommended Mitigation

Remove the `canFarmSnow` modifier from `buySnow`. Keep it only on `earnSnow`, where the farming time window is intended.

```diff
- function buySnow(uint256 amount) external payable canFarmSnow {
+ function buySnow(uint256 amount) external payable {
```
