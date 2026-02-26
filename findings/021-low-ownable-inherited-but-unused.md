# Ownable Inherited But Never Used

## Description

The `Snow` contract inherits `Ownable` and sets the deployer as owner in the constructor, but no function uses the `onlyOwner` modifier. The owner has no privileges: they cannot change fees, pause, or perform any admin action. The inheritance adds deployment cost and suggests admin capabilities that do not exist. Alternatively, the owner role could be used for critical functions (e.g. fee changes, emergency pause) instead of or in addition to the collector.

```solidity
// Snow.sol - Ownable inherited, no onlyOwner functions
contract Snow is ERC20, Ownable {
    // ...
    constructor(...) ERC20("Snow", "S") Ownable(msg.sender) {
        // owner set, but never used
    }
    // No function with onlyOwner modifier
}
```

## Risk

**Likelihood (N/A)**:

* Dead code; no runtime effect.

**Impact (low)**:

* Unused inheritance increases bytecode size and deployment cost.
* Misleading: owner appears to have a role but has none.
* Missed opportunity: owner could manage `s_buyFee`, pause, or other admin functions.

**Severity (low)**:

## Recommended Mitigation

Either use the owner role for intended admin functions (e.g. fee setter, pause) or remove the inheritance if no admin role is needed:

```diff
- import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
- contract Snow is ERC20, Ownable {
+ contract Snow is ERC20 {
-     constructor(...) ERC20("Snow", "S") Ownable(msg.sender) {
+     constructor(...) ERC20("Snow", "S") {
```

Or add owner-only functions (e.g. `setBuyFee`, `pause`) if admin control is intended.
