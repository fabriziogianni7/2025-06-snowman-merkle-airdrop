# tokenURI JSON Injection Produces Malformed Metadata

## Description

The `tokenURI` function in `Snowman` builds JSON metadata by concatenating strings with `abi.encodePacked`. The dynamic value `imageURI` (from `s_SnowmanSvgUri`) is inserted raw into the JSON string without escaping. If the URI contains JSON-special characters such as `"` (double quote) or `\` (backslash), the resulting string is invalid JSON. Marketplaces, wallets, and other consumers that parse the metadata will fail to parse it or interpret it incorrectly.

```solidity
// @> Root cause: imageURI is concatenated raw with no JSON escaping
return string(
    abi.encodePacked(
        _baseURI(),
        Base64.encode(
            abi.encodePacked(
                '{"name":"',
                name(),
                '", "description":"Snowman for everyone!!!", ',
                '"attributes": [{"trait_type": "freezing", "value": 100}], "image":"',
                imageURI,  // @> Unescaped; breaks JSON if contains " or \
                '"}'
            )
        )
    )
);
```

## Risk

**Likelihood (low–medium)**:

* The deployer passes `s_SnowmanSvgUri` in the constructor. A typo, bug in the deployment script, or malicious deployer can include `"` or `\` in the URI.
* Data URIs (base64) are generally safe, but IPFS/HTTP URLs or file paths can contain backslashes or quotes (e.g. `path\to\image.svg`, URLs with `%22`).
* No validation or sanitization of the URI before it is embedded in JSON.

**Impact (medium)**:

* All NFTs return malformed metadata; consumers cannot parse the JSON.
* Marketplaces and wallets may fail to display the image or show broken metadata.
* Degrades user experience and perceived value of the airdrop NFTs.

**Severity (medium)**:

## Proof of Concept

1. Deployer passes `s_SnowmanSvgUri = 'https://example.com/img"evil.png'` (e.g. typo or malicious).
2. `tokenURI(0)` returns base64-encoded JSON equivalent to:
   ```json
   {"name":"Snowman Airdrop", "description":"Snowman for everyone!!!", "attributes": [{"trait_type": "freezing", "value": 100}], "image":"https://example.com/img"evil.png"}
   ```
3. The `"` after `img` prematurely closes the `image` string; the JSON is invalid.
4. Any JSON parser will fail or misinterpret the structure.

```solidity
// Scenario: deployer passes URI with double quote
Snowman snowman = new Snowman('data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPjwvc3ZnPg=="');
// Or: 'https://cdn.example.com/nft"id=0.svg'
// tokenURI() returns invalid JSON; marketplaces fail to parse
```

## Recommended Mitigation

Escape dynamic values before embedding them in JSON. Add a helper that escapes `"` and `\` (and optionally newlines, tabs, control chars):

```diff
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
      if (ownerOf(tokenId) == address(0)) {
          revert ERC721Metadata__URI_QueryFor_NonExistentToken(); 
      }
      string memory imageURI = s_SnowmanSvgUri;
+     string memory escapedImageURI = _escapeJsonString(imageURI);
      return string(
          abi.encodePacked(
              _baseURI(),
              Base64.encode(
                  abi.encodePacked(
                      '{"name":"',
                      name(),
                      '", "description":"Snowman for everyone!!!", ',
                      '"attributes": [{"trait_type": "freezing", "value": 100}], "image":"',
-                     imageURI,
+                     escapedImageURI,
                      '"}'
                  )
              )
          )
      );
  }

+ function _escapeJsonString(string memory s) internal pure returns (string memory) {
+     bytes memory input = bytes(s);
+     bytes memory output = new bytes(input.length * 2);
+     uint256 j = 0;
+     for (uint256 i = 0; i < input.length; i++) {
+         if (input[i] == '"' || input[i] == '\\') {
+             output[j++] = '\\';
+         }
+         output[j++] = input[i];
+     }
+     bytes memory trimmed = new bytes(j);
+     for (uint256 i = 0; i < j; i++) trimmed[i] = output[i];
+     return string(trimmed);
+ }
```

Alternatively, use a library that produces valid JSON (e.g. OpenZeppelin's `Strings` or a dedicated JSON encoder) instead of manual concatenation.
