//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721Token is ERC721 {
    address private owner;

    constructor() ERC721("MyToken", "MTK") {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "ERC721: Only owner can mint.");
        _;
    }

    function mint(address to, uint256 id) external onlyOwner {
        _safeMint(to, id);
    }
}
