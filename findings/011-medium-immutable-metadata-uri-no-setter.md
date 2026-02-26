# Immutable Metadata URI Prevents Updates and Fixes

## Description

The Snowman NFT metadata image URI (`s_SnowmanSvgUri`) is set only in the constructor and has no setter function. The contract inherits `Ownable`, but the owner cannot update the URI after deployment. All token metadata (returned by `tokenURI`) uses this single URI for the image field; every minted Snowman NFT displays the same image.

If the URI is wrong at deployment (typo, wrong file, bug in the deployment script), contains malformed or inappropriate content, or needs to be updated for any reason, there is no way to correct it without redeploying the entire contract.

```solidity
// @> Root cause: s_SnowmanSvgUri is set once in constructor, never updatable
string private s_SnowmanSvgUri;
// ...
constructor(string memory _SnowmanSvgUri) ERC721("Snowman Airdrop", "SNOWMAN") Ownable(msg.sender) {
    s_TokenCounter = 0;
    s_SnowmanSvgUri = _SnowmanSvgUri;  // @> Only assignment; no setter exists
}
```

## Risk

**Likelihood (medium)**:

* Deployment scripts can pass wrong file paths, typos, or buggy encoding (e.g. `svgToImageURI` in `DeploySnowman.s.sol`).
* Projects often need to update artwork or fix metadata after launch.
* No validation of the URI at deployment; malformed or empty strings are accepted.

**Impact (medium)**:

* All minted NFTs permanently display wrong or broken metadata.
* For an airdrop where the NFT is the reward, broken metadata significantly degrades user experience and value.
* No recovery path without full contract redeployment and migration.

**Severity (medium)**:

## Proof of Concept

1. Protocol deploys `Snowman` with URI from `./img/snowman.svg` via `DeploySnowman.s.sol`.
2. The deployment script has a bug (wrong path, encoding error) or the SVG file contains incorrect content.
3. All tokens minted point to the wrong/broken image in their metadata.
4. There is no `setSnowmanSvgUri` or similar function; the owner cannot fix the metadata.
5. The only fix is redeploying the contract and migrating all state.

```solidity
// Scenario: wrong content at deploy
// DeploySnowman reads ./img/snowman.svg and passes to constructor
// If file is wrong or script has bug, wrong data is permanently stored
Snowman snowman = new Snowman(svgToImageURI(snowmanSvg));
// No setter - owner cannot update s_SnowmanSvgUri
// All tokenURI() calls return metadata with broken/wrong image
```

## Recommended Mitigation

Add an owner-controlled setter with validation and an event for monitoring.

```diff
  string private s_SnowmanSvgUri;

+ error SM__InvalidUri();
+ event SnowmanSvgUriUpdated(string newUri);

  constructor(string memory _SnowmanSvgUri) ERC721("Snowman Airdrop", "SNOWMAN") Ownable(msg.sender) {
      s_TokenCounter = 0;
      s_SnowmanSvgUri = _SnowmanSvgUri;
  }

+ function setSnowmanSvgUri(string memory _newUri) external onlyOwner {
+     if (bytes(_newUri).length == 0) revert SM__InvalidUri();
+     s_SnowmanSvgUri = _newUri;
+     emit SnowmanSvgUriUpdated(_newUri);
+ }
```

Consider a timelock for URI updates to give users visibility before changes take effect.
