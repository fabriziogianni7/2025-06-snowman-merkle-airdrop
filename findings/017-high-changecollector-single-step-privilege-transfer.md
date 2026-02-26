# changeCollector: Single-Step Privilege Transfer Can Permanently Lose Fee Collection Rights

## Description

The `changeCollector` function performs an immediate, single-step transfer of the collector role. The current collector calls `changeCollector(_newCollector)` and `s_collector` is updated atomically. There is no confirmation from the new collector, no way to cancel a mistaken transfer, and no recovery if the address is wrong (typo, phishing, or burn address).

The collector role controls all fee collection: WETH and ETH accumulated from `buySnow` are sent to `s_collector` via `collectFee()`. A single mistaken call can permanently redirect all future fees to an unreachable or malicious address.

```solidity
// Snow.sol - single-step transfer, no confirmation
@>    function changeCollector(address _newCollector) external onlyCollector {
        if (_newCollector == address(0)) {
            revert S__ZeroAddress();
        }

        s_collector = _newCollector;

        emit NewCollector(_newCollector);
    }
```

## Risk

**Likelihood (medium)**:

* Collector may typo an address when rotating keys or migrating.
* Phishing or social engineering can trick the collector into calling with an attacker's address.
* No audit trail or confirmation step; one transaction is irreversible.

**Impact (high)**:

* All future fee collection is sent to the wrong address.
* If the address is a burn address or a contract that rejects ETH, fees are permanently locked.
* No built-in recovery; protocol would require an upgrade or redeploy to fix.

**Severity (high)**:

## Proof of Concept

1. Current collector intends to transfer the role to a new multisig at `0x1234...abcd`.
2. Collector mistypes one character: `0x1234...abce` (attacker-controlled or burn).
3. Collector calls `changeCollector(0x1234...abce)`.
4. `s_collector` is updated immediately; no confirmation from the new address.
5. All subsequent `collectFee()` calls send WETH and ETH to the wrong address.
6. Protocol fees are permanently lost or stolen.

```solidity
// Collector mistakenly transfers to wrong address
vm.prank(collector);
snow.changeCollector(attackerAddress);  // typo or phishing

// Fees now go to attacker; no way to revert
vm.prank(collector);
vm.expectRevert();  // collector no longer has role
snow.collectFee();
```

## Recommended Mitigation

### Option 1: Two-Step Transfer (Propose + Accept)

Introduce a pending collector that must be accepted by the new address:

```diff
  contract Snow is ERC20, Ownable {
      address private s_collector;
+     address private s_pendingCollector;

      function changeCollector(address _newCollector) external onlyCollector {
          if (_newCollector == address(0)) {
              revert S__ZeroAddress();
          }
-
-         s_collector = _newCollector;
-
-         emit NewCollector(_newCollector);
+         s_pendingCollector = _newCollector;
+         emit CollectorTransferProposed(_newCollector);
      }
+
+     function acceptCollectorRole() external {
+         if (msg.sender != s_pendingCollector) revert S__NotAllowed();
+         s_collector = s_pendingCollector;
+         delete s_pendingCollector;
+         emit NewCollector(s_collector);
+     }
  }
```

### Option 2: Role-Based Access Control (OpenZeppelin)

Use `AccessControl` with `COLLECTOR_ROLE` so role grants and revokes are explicit and auditable. Admin can grant the new collector and revoke the old one in separate steps (or batch), with a clear audit trail:

```diff
- import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
+ import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

- contract Snow is ERC20, Ownable {
-     address private s_collector;
+ contract Snow is ERC20, AccessControl {
+     bytes32 public constant COLLECTOR_ROLE = keccak256("COLLECTOR_ROLE");

-     modifier onlyCollector() {
-         if (msg.sender != s_collector) revert S__NotAllowed();
-         _;
-     }
+     modifier onlyCollector() {
+         if (!hasRole(COLLECTOR_ROLE, msg.sender)) revert S__NotAllowed();
+         _;
+     }

      constructor(...) {
-         s_collector = _collector;
+         _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
+         _grantRole(COLLECTOR_ROLE, _collector);
      }

-     function changeCollector(address _newCollector) external onlyCollector {
-         if (_newCollector == address(0)) revert S__ZeroAddress();
-         s_collector = _newCollector;
-         emit NewCollector(_newCollector);
-     }
+     // Admin revokes old collector, grants new one; no single-step transfer
+     function setCollector(address _oldCollector, address _newCollector) external onlyRole(DEFAULT_ADMIN_ROLE) {
+         if (_newCollector == address(0)) revert S__ZeroAddress();
+         _revokeRole(COLLECTOR_ROLE, _oldCollector);
+         _grantRole(COLLECTOR_ROLE, _newCollector);
+         emit NewCollector(_newCollector);
+     }
  }
```

Either approach prevents accidental or malicious transfer of funds to a wrong address.
