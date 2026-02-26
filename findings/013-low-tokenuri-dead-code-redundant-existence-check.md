# tokenURI Dead Code: Unreachable Existence Check

## Description

The `tokenURI` function checks token existence with `if (ownerOf(tokenId) == address(0))` and reverts with a custom error. This condition is unreachable. OpenZeppelin's `ownerOf` internally calls `_requireOwned(tokenId)`, which reverts with `ERC721NonexistentToken` when the token does not exist. `ownerOf` never returns `address(0)`—it either reverts or returns the owner. The `if` block and the custom error `ERC721Metadata__URI_QueryFor_NonExistentToken` are dead code.

The base ERC721 `tokenURI` uses `_requireOwned(tokenId)` directly for the existence check. Overrides should follow the same pattern for consistency and to avoid redundant logic.

```solidity
// @> Root cause: ownerOf reverts on non-existent token, never returns address(0)
function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    if (ownerOf(tokenId) == address(0)) {  // @> Dead code: condition never true
        revert ERC721Metadata__URI_QueryFor_NonExistentToken(); 
    }
    // ...
}
```

```solidity
// ERC721.sol: ownerOf delegates to _requireOwned, which reverts instead of returning 0
function ownerOf(uint256 tokenId) public view virtual returns (address) {
    return _requireOwned(tokenId);  // reverts if token doesn't exist
}
function _requireOwned(uint256 tokenId) internal view returns (address) {
    address owner = _ownerOf(tokenId);
    if (owner == address(0)) {
        revert ERC721NonexistentToken(tokenId);
    }
    return owner;
}
```

## Risk

**Likelihood (N/A)**:

* Dead code has no runtime effect; the check is logically redundant.

**Impact (low)**:

* Unused code increases maintenance burden and can confuse auditors.
* Custom error `ERC721Metadata__URI_QueryFor_NonExistentToken` is never used.
* Inconsistent with base ERC721 pattern; future OZ changes could make behavior diverge.

**Severity (low)**:

## Proof of Concept

1. Call `tokenURI(999)` on a contract with no token 999.
2. `ownerOf(999)` is invoked; it calls `_requireOwned(999)`.
3. `_requireOwned` sees `_ownerOf(999) == address(0)` and reverts with `ERC721NonexistentToken(999)`.
4. Execution never reaches the `if` block; the custom revert is unreachable.

```solidity
// tokenURI(999) for non-existent token:
// 1. ownerOf(999) -> _requireOwned(999) -> revert ERC721NonexistentToken(999)
// 2. The "if (ownerOf(tokenId) == address(0))" branch is never executed
```

## Recommended Mitigation

Replace the dead check with `_requireOwned(tokenId)` to align with the base ERC721 implementation:

```diff
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
-     if (ownerOf(tokenId) == address(0)) {
-         revert ERC721Metadata__URI_QueryFor_NonExistentToken(); 
-     }
+     _requireOwned(tokenId);
      string memory imageURI = s_SnowmanSvgUri;
      // ...
  }
```

Consider removing the unused `ERC721Metadata__URI_QueryFor_NonExistentToken` error.
