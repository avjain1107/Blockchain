//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    /**
     * @dev return total amount of token in existence
     *  @return total Supply of token in integer
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev get balance of a account
     * @param account : account address whose balance is required
     * @return account token balance in integer
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev transfer token from sender's account to 'to' address
     * Emit a {Tranfer} event
     * @param to : account address which recieve token
     * @param amount :number of token to transfer
     * @return true or false on process completion
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev return remaining token allowance a spender have from owner
     * zero by default
     * value changes when {approve} or {transferFrom} are called
     * @param owner : give approval to spender to use his token
     * @param spender : have approval to use owner token
     * @return number of token spender is given allowance by token owner in integer
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /**
     * @dev account owner approve spender with some token allowance
     * Emit {Approval} event
     * @param spender : account address who get allowance from msg.sender
     * @param amount : number of token spender get allowance with.
     * @return true or false on completion
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev move amount(no of token) from 'from' address to 'to' address
     * Emits {Transfer} event
     * @param from : address who have given approval to use his token
     * @param to : address which recieve token
     * @param amount : number of token to transfer
     * @return true or false on completion
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev emitted when token are moved from one account to another
     * @param from : sender address
     * @param to : reciever address
     * @param value : token given
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev emitted when a allowance is approved from owner to spender
     * @param owner : token owner
     * @param spender : token spender
     * @param value : allowance given
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}
