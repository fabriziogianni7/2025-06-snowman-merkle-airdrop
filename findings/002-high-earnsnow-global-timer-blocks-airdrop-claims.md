# earnSnow Global Timer Prevents Most Users From Earning Snow and Claiming Airdrop

## Description

The `Snow` token is designed so users can either buy Snow or earn 1 Snow per week for free via `earnSnow()`. The intended behavior is that each user can earn once per week. The `claimSnowman` function in `SnowmanAirdrop` requires `i_snow.balanceOf(receiver) > 0`, so recipients must hold Snow to claim.

The `earnSnow()` function uses a single global `s_earnTimer` to enforce the "once per week" cooldown. When any user calls `earnSnow()`, it updates `s_earnTimer = block.timestamp`. The check `block.timestamp < (s_earnTimer + 1 weeks)` then blocks all other users from earning for the next week. Effectively, only one user globally can earn Snow per week instead of each user earning once per week.

```solidity
// @> Root cause: s_earnTimer is global, not per-user; only one user can earn per week
function earnSnow() external canFarmSnow {
    if (s_earnTimer != 0 && block.timestamp < (s_earnTimer + 1 weeks)) {
        revert S__Timer();
    }
    _mint(msg.sender, 1);
    s_earnTimer = block.timestamp;  // @> Global update blocks everyone else
}
```

## Risk

**Likelihood (high)**:

* The bug is present in the deployed contract; no special conditions are required.
* The first user to call `earnSnow()` each week locks out all other users for that week.
* Over the 12-week `FARMING_DURATION`, at most ~12 users can ever earn Snow via `earnSnow()`.

**Impact (high)**:

* Recipients in the Merkle tree who were expected to earn Snow for free cannot obtain a balance.
* Without Snow balance, they cannot pass `i_snow.balanceOf(receiver) == 0` check and cannot claim their airdrop.
* Core airdrop distribution is broken for the vast majority of intended free earners.

**Severity (high)**:

## Proof of Concept

1. Merkle tree includes 1000 recipients expected to earn 1 Snow each via `earnSnow()`.
2. User A calls `earnSnow()` at week 1; `s_earnTimer` is set.
3. User B tries `earnSnow()` in week 1; reverts with `S__Timer()`.
4. User C, D, ... all revert until week 2.
5. Only one user can earn per week; over 12 weeks, at most 12 users earn Snow.
6. The remaining 988 recipients have 0 Snow and cannot call `claimSnowman`.

```solidity
// Demonstrates the global timer behavior
// User A earns at t=0
vm.prank(userA);
snow.earnSnow();  // succeeds, s_earnTimer = 0

// User B tries 1 second later
vm.prank(userB);
vm.expectRevert(Snow.S__Timer.selector);
snow.earnSnow();  // reverts - blocked by user A's call
```

## Recommended Mitigation

Use per-user tracking instead of a global timer.

```diff
- uint256 private s_earnTimer;
+ mapping(address => uint256) private s_lastEarnTime;

  function earnSnow() external canFarmSnow {
-     if (s_earnTimer != 0 && block.timestamp < (s_earnTimer + 1 weeks)) {
+     if (s_lastEarnTime[msg.sender] != 0 && block.timestamp < (s_lastEarnTime[msg.sender] + 1 weeks)) {
          revert S__Timer();
      }
      _mint(msg.sender, 1);
-     s_earnTimer = block.timestamp;
+     s_lastEarnTime[msg.sender] = block.timestamp;
  }
```

Remove `s_earnTimer = block.timestamp` from `buySnow()` (line 89) as it is unrelated to earning and incorrectly affects the earn cooldown.
