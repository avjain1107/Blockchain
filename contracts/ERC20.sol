//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import "./interface/IERC20.sol";
import "hardhat/console.sol";

contract ERC20 is IERC20 {
    uint256 private totalToken;
    address public owner;
    string private tokenName;
    string private tokenSymbol;
    mapping(address => uint256) private balance;

    mapping(address => mapping(address => uint256)) private allowed;

    constructor(string memory _tokenName, string memory _tokenSymbol) {
        owner = msg.sender;
        tokenName = _tokenName;
        tokenSymbol = _tokenSymbol;
        _mint(owner, 1000);
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(msg.sender == owner, "Only onwer can mint");
        balance[account] += amount;
        totalToken += amount;
    }

    function name() external view returns (string memory) {
        return tokenName;
    }

    function symbol() external view returns (string memory) {
        return tokenSymbol;
    }

    function decimal() external pure returns (uint8) {
        return 18;
    }

    function totalSupply() external view returns (uint256) {
        return totalToken;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balance[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(amount <= balance[msg.sender],"Not sufficient balance");
        balance[msg.sender] -= amount;
        balance[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(
        address _owner,
        address spender
    ) external view returns (uint256) {
        return allowed[_owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        address _owner = msg.sender;
        require(_owner != address(0), "Invalid owner address");
        require(spender != address(0), "Invalid spender address");
        allowed[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(
            amount <= balance[from],
            "Owner account do not have enough balance"
        );
        require(
            amount <= allowed[from][msg.sender],
            "Spender do not have enough balance approval"
        );
        balance[from] -= amount;
        allowed[from][msg.sender] -= amount;
        balance[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
