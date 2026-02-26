// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * ░▒▓███████▓▒░▒▓███████▓▒░ ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓██████████████▓▒░ ░▒▓██████▓▒░░▒▓███████▓▒░
 * ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
 * ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
 *  ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓████████▓▒░▒▓█▓▒░░▒▓█▓▒░
 *        ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
 *        ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
 * ░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░ ░▒▓█████████████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
 */
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract Snowman is ERC721, Ownable {
    // >>> ERROR
    error ERC721Metadata__URI_QueryFor_NonExistentToken();
    // note SM__NotAllowed error is never used (noted in 009)
    error SM__NotAllowed();

    // >>> VARIABLES
    uint256 private s_TokenCounter;
    // bug there is no setter here, I think it should be there
    string private s_SnowmanSvgUri;

    // >>> EVENTS
    event SnowmanMinted(address indexed receiver, uint256 indexed numberOfSnowman);

    // >>> CONSTRUCTOR
    constructor(string memory _SnowmanSvgUri) ERC721("Snowman Airdrop", "SNOWMAN") Ownable(msg.sender) {
        s_TokenCounter = 0; // note we don't need to initialize variables to 0, they are 0 by default. we may want to initializee to 1
        s_SnowmanSvgUri = _SnowmanSvgUri;
    }

    // >>> EXTERNAL FUNCTIONS
    // bug missing validation for receiver and amount
    // bug no access control
    function mintSnowman(address receiver, uint256 amount) external {
        // note why don't we use batch mint (ERC1155??) noted
        // bug this approach can likely cause a DOS (unbounded array) noted
        // bug it should only be possible for the snowmanAirdrop to call it noted
        for (uint256 i = 0; i < amount; i++) {
            _safeMint(receiver, s_TokenCounter); //note this could be cached and reused to save a lot of gas

            emit SnowmanMinted(receiver, s_TokenCounter);

            s_TokenCounter++;
        }
    }

    // >>> PUBLIC FUNCTIONS
    // note tokeId is never used, different tokens have the same uri, 
    // maybe we want to use it to get the value? but IDK if this makes sens
    // ah ok this overrides the ERC721Metadata
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        // note 013: dead code, ownerOf reverts on non-existent token, never returns address(0)
        if (ownerOf(tokenId) == address(0)) {
            revert ERC721Metadata__URI_QueryFor_NonExistentToken(); 
        }
        string memory imageURI = s_SnowmanSvgUri; // note probably not worth to cache this here

        // note why value": 100???
        // note not sure if that's the best way to do it
        // note maybe value should be balanceOf(ownerOf(tokenId))
        return string(
            abi.encodePacked(
                _baseURI(),
                Base64.encode(
                    abi.encodePacked(
                        '{"name":"',
                        name(),
                        '", "description":"Snowman for everyone!!!", ',
                        '"attributes": [{"trait_type": "freezing", "value": 100}], "image":"',
                        imageURI,
                        '"}'
                    )
                )
            )
        );
    }

    // >>> INTERNAL FUNCTIONS
    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    // >>> GETTER FUNCTIONS
    function getTokenCounter() external view returns (uint256) {
        return s_TokenCounter;
    }
}
