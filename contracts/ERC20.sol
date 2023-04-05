//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import "./interface/IERC20.sol";

/**
 * @title Implementation of ERC20 token
 * @author Avinash Jain
 */
contract ERC20 is IERC20 {
    uint256 private totalToken;
    address public owner;
    string private tokenName;
    string private tokenSymbol;
    mapping(address => uint256) private balance;

    mapping(address => mapping(address => uint256)) private allowed;

    /**
     * @dev sets value for Token Name and Symbol in constructor
     * both these value cannot be changed after contract construction
     */
    constructor(string memory _tokenName, string memory _tokenSymbol) {
        owner = msg.sender;
        tokenName = _tokenName;
        tokenSymbol = _tokenSymbol;
        _mint(owner, 1000);
    }

    /**
     * @dev allow contract owner to mint desired no of token to given account
     * Requirement : only contract owner can mint token
     * @param account : account where to mint token
     * @param amount : number of token to mint
     */
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    /**
     *@dev allow contract owner to mint desired number of token to given account
     *   internal function equivalent to {mint}
     * @param account : account where to mint token
     * @param amount : number of token to mint
     */
    function _mint(address account, uint256 amount) internal {
        require(msg.sender == owner, "Only onwer can mint");
        balance[account] += amount;
        totalToken += amount;
    }

    /**
     * @dev Returns the name of token
     * @return return Token name in string
     */
    function name() external view returns (string memory) {
        return tokenName;
    }

    /**
     * @dev Returns the symbol of token
     * @return return Token symbol in string
     */
    function symbol() external view returns (string memory) {
        return tokenSymbol;
    }

    /**
     * @dev Returns the decimal of token
     * @return return decimal in integer
     */
    function decimal() external pure returns (uint8) {
        return 18;
    }

    /**
     * @dev see {IERC20 totalSupply}
     */
    function totalSupply() external view returns (uint256) {
        return totalToken;
    }

    /**
     * @dev see {IERC20 balanceOf}
     */
    function balanceOf(address account) external view returns (uint256) {
        return balance[account];
    }

    /**
     * @dev see {IERC20 transfer}
     * requirement - sender's balance to be greater or equal to amount sent
     * Emit a {Tranfer} event
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        require(amount <= balance[msg.sender], "Not sufficient balance");
        balance[msg.sender] -= amount;
        balance[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @dev see {IERC20 allowance}
     */
    function allowance(
        address _owner,
        address spender
    ) external view returns (uint256) {
        return allowed[_owner][spender];
    }

    /**
     * @dev see {IERC20 approve}
     * requirement - spender address must not be zero address
     * Emit a {Approval} event
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        address _owner = msg.sender;
        require(spender != address(0), "Invalid spender address");
        allowed[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
        return true;
    }

    /**
     * @dev see {IERC20 transferFrom}
     *  requirement -
     *     balance of from to be greater or equal to amount send
     *     function caller must have allowance greater than equal to amount from 'from' address
     * Emit a {Transfer} event
     */
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
