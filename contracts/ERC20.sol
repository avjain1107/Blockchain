//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Token is ERC20 {
    address private owner;
    constructor() ERC20("MyToken","MTK"){
        _mint(msg.sender,100000);
        owner = msg.sender;
    }
    modifier onlyOwner(){
  require(msg.sender ==owner,"ERC721Token: Only owner can mint.");
  _;
}
    function mint(address to, uint256 amount)external onlyOwner{
        _mint(to,amount);
    }
}
