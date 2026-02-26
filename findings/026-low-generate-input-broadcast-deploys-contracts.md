# GenerateInput With --broadcast Deploys Snow and Snowman Unintentionally

## Description

`GenerateInput.run()` calls `Helper.run()`, which uses `DeploySnowmanAirdrop.deploySnowmanAirdrop()`. That function invokes `DeploySnow.run()` and `DeploySnowman.run()`, both of which use `vm.startBroadcast()` and `vm.stopBroadcast()`.

When `GenerateInput` is run with `--broadcast` (e.g. `forge script script/GenerateInput.s.sol --broadcast`), the broadcast context is active. The nested `DeploySnow` and `DeploySnowman` scripts will broadcast their deployments, so Snow and Snowman are deployed on-chain. The user's intent is only to generate `input.json`; the deployments are unnecessary and wasteful.

```solidity
// DeploySnow.run() - broadcasts
function run() external returns (Snow) {
    vm.startBroadcast();
    weth = new MockWETH();
    snow = new Snow(address(weth), FEE, collector);
    // ...
    vm.stopBroadcast();
    return snow;
}

// DeploySnowman.run() - broadcasts
function run() external returns (Snowman) {
    string memory snowmanSvg = vm.readFile("./img/snowman.svg");
    vm.startBroadcast();
    Snowman snowman = new Snowman(svgToImageURI(snowmanSvg));
    vm.stopBroadcast();
    return snowman;
}
```

## Risk

**Likelihood (low)**:

* Users must explicitly pass `--broadcast`; simulation by default does not broadcast.
* If someone runs `GenerateInput` with broadcast (e.g. by habit or from a deployment script), they may not expect deployments.

**Impact (low)**:

* Unnecessary gas spent on Snow and Snowman deployments.
* Potential confusion: deployments occur without the intended Merkle root (Helper's airdrop uses a hardcoded root).

**Severity (low)**:

## Recommended Mitigation

Ensure `GenerateInput` and `Helper` run in a non-broadcast context when used for input generation. Options:

1. **Separate broadcast-free helper**: Create a `HelperSimulation` or internal variant that does not call `DeploySnow.run()`/`DeploySnowman.run()` with broadcast. Use `DeploySnowmanAirdrop.deploySnowmanAirdrop()` which does not call `vm.startBroadcast()` — but that still calls `DeploySnow.run()` and `DeploySnowman.run()`, which do broadcast. So the fix is to either:
   - Have `DeploySnow` and `DeploySnowman` expose a `deployWithoutBroadcast()` variant used by Helper, or
   - Have Helper call constructors directly (e.g. `new Snow(...)`, `new Snowman(...)`) instead of going through deploy scripts.

2. **Document**: Add a clear README note that `GenerateInput` must not be run with `--broadcast` when only generating input.
