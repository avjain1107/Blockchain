//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MultiSig Wallet Assignment
 * @author Avinash Jain
 */
contract MultiSigWallet is Initializable {
    /**
     * @dev emitted when a Approval is revoked by approved owner
     * @param owner : Approved owner who revoke his approval
     * @param txId : Id of transaction whose approval is revoked
     */
    event RevokeApproval(address indexed owner, uint256 indexed txId);
    /**
     * @dev emitted when a transaction is submitted by approved owner
     * @param owner : Approved owner who submit the transaction
     * @param txId : Id of submitted transaction
     */
    event SubmitTransaction(address indexed owner, uint256 indexed txId);
    /**
     * @dev emitted when a transaction is approved by owner
     * @param owner : Owner address who appprove the transaction
     * @param txId : Id of transaction  which gets the approval
     */
    event ApproveTransaction(address indexed owner, uint256 indexed txId);
    /**
     * @dev emitted when a transaction is emitted
     * @param owner : Address of executing user
     * @param txId : Id of transaction which is executed
     * @param to : reciever's address
     * @param value : amount that is transfered
     */
    event ExecuteTransaction(
        address indexed owner,
        uint256 indexed txId,
        address to,
        uint256 value
    );

    mapping(uint256 => Transaction) private transaction;
    mapping(uint256 => mapping(address => bool)) private approval;
    mapping(address => bool) private isOwner;
    uint256[] private readyToExecute;
    uint256 private transactionCount;
    uint256 public confirmationRequired;
    address private owner;
    IERC20 token;

    struct Transaction {
        address payable to;
        uint256 value;
        bool executed;
        uint256 approvalCount;
        bool isTokenTransafer;
    }

    /**
     * @dev sets value of confirmation count and contract owner
     * @param _confirmationRequired : number of confirmation required to execute a transaction
     */
    function initialize(
        uint256 _confirmationRequired,
        address _token
    ) external initializer {
        owner = msg.sender;
        isOwner[msg.sender] = true;
        confirmationRequired = _confirmationRequired;
        transactionCount = 1;
        token = IERC20(_token);
    }

    modifier onlyOwner() {
        require(
            isOwner[msg.sender],
            "MultiSigWallet: Only Approved owners can perform this operation."
        );
        _;
    }

    modifier notOwner(address _address) {
        require(!isOwner[_address], "MultiSigWallet: Already approved owner");
        _;
    }

    modifier notExecuted(uint256 _txId) {
        require(
            transaction[_txId].executed != true,
            "MultiSigWallet: Transaction already executed"
        );
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0), "MultiSigWallet: Invalid address");
        _;
    }

    modifier transactionExist(uint256 _txId) {
        require(
            transaction[_txId].to != address(0),
            "MultiSigWallet: Transaction does not exist"
        );
        _;
    }

    /**
     * @dev allow approved owners to submit transactions
     * Requirements -
     *         Only approved owner can submit a transaction
     *         Reciever's address should not be invalid
     * @param _to : reciever address
     * @param _value : amount to transfer
     * Emit a {SubmitTransaction} event
     */
    function submitTransaction(
        address payable _to,
        uint256 _value,
        bool _isTokenTransfer
    ) external onlyOwner notNull(_to) {
        require(
            _value > 0,
            "MultiSigWallet: Amount to transfer should not be zero."
        );
        uint256 txId = transactionCount++;
        transaction[txId] = Transaction(
            _to,
            _value,
            false,
            1,
            _isTokenTransfer
        );
        approval[txId][msg.sender] = true;
        emit SubmitTransaction(msg.sender, txId);
    }

    /**
     * @dev owners can approve a submited transaction
     * Requirement -
     *         Only approved owners can approve a transaction
     *         Transaction to approve must exist
     *         Transaction to approve must not have executed
     *         Owner must not have approved the same transaction before
     * @param _txId : Id of transaction to approve
     * Emit a {ApproveTransaction} Event
     */
    function approveTransaction(
        uint256 _txId
    ) external onlyOwner transactionExist(_txId) notExecuted(_txId) {
        require(
            approval[_txId][msg.sender] != true,
            "MultiSigWallet: Transaction already approved by owner."
        );
        approval[_txId][msg.sender] = true;
        transaction[_txId].approvalCount += 1;
        if (transaction[_txId].approvalCount == confirmationRequired) {
            readyToExecute.push(_txId);
        }
        emit ApproveTransaction(msg.sender, _txId);
    }

    /**
     * @dev owners can revoke their approval on a transaction
     * Requirements -
     *          Only approved onwer can revoke transaction
     *          Transaction from which approval has to be revoke must exist
     *          Transaction must not have executed
     *          Transaction need to be approved before revoking its approval by the owner
     * @param _txId : Id of transaction to be revoked
     * Emit a {RevokeApproval} event
     */
    function revokeTransaction(
        uint256 _txId
    ) external onlyOwner transactionExist(_txId) notExecuted(_txId) {
        require(
            approval[_txId][msg.sender],
            "MultiSigWallet: Transaction not approved by owner."
        );
        approval[_txId][msg.sender] = false;
        transaction[_txId].approvalCount -= 1;
        if (transaction[_txId].approvalCount == confirmationRequired - 1) {
            _removeFromReadyToApprove(_txId);
        }
        emit RevokeApproval(msg.sender, _txId);
    }

    /**
     * @dev anyone can randomly execute a transaction when it has recieved enough approval
     * Requirement -
     *          Atleast one transaction must be ready to execute
     * Emits a {ExecuteTransaction} event
     */
    function executeTransaction() external payable {
        uint256 size = readyToExecute.length;
        require(
            size > 0,
            "MultiSigWallet: No transaction is yet ready to execute"
        );
        uint256 randomNumber = _generateRandomNumber(size);
        uint256 _txId = readyToExecute[randomNumber];
        address payable _to = transaction[_txId].to;
        uint256 _value = transaction[_txId].value;
        if (transaction[_txId].isTokenTransafer == true) {
            token.transferFrom(msg.sender, _to, _value);
        } else {
            _to.transfer(_value);
        }
        transaction[_txId].executed = true;
        readyToExecute[randomNumber] = readyToExecute[size - 1];
        readyToExecute.pop();
        emit ExecuteTransaction(msg.sender, _txId, _to, _value);
    }

    /**
     * @dev Approved owners can execute all the transaction that are ready to execute
     * Requirement -
     *         Only Approved owners can execute batch Execute transactions
     *         Atleast one transaction should have required approval
     * Emits {ExecuteTransaction} event
     */
    function batchExecuteTransaction() external payable onlyOwner {
        uint256 size = readyToExecute.length;
        require(
            size > 0,
            "MultiSigWallet: No transaction is yet ready to execute"
        );
        for (uint256 i = 0; i < size; i++) {
            uint256 _txId = readyToExecute[i];
            address payable _to = transaction[_txId].to;
            uint256 _value = transaction[_txId].value;
            if (transaction[_txId].isTokenTransafer == true) {
                token.transferFrom(msg.sender, _to, _value);
            } else {
                _to.transfer(_value);
            }
            transaction[_txId].executed = true;
            emit ExecuteTransaction(msg.sender, _txId, _to, _value);
        }
        delete readyToExecute;
    }

    /**
     * @dev Approved owners can add other owner
     * Requirement -
     *         Only Approved owners can add others as owner
     *         User address passed should not be invalid
     *         Address to be added as owner must not already be a owner
     * @param _address : address to be added as owner
     */
    function addOwner(
        address _address
    ) external onlyOwner notNull(_address) notOwner(_address) {
        isOwner[_address] = true;
    }

    /**
     * @dev getter function to get number of approval on a transaction
     * Requirement -
     *         Transaction whose approval is needed must exist
     * @param _txId : Id of transaction whose approval count is needed
     * @return number of approval on a transaction
     */
    function getTransactionApprovalCount(
        uint256 _txId
    ) public view transactionExist(_txId) returns (uint256) {
        return transaction[_txId].approvalCount;
    }

    /**
     * @dev getter function to get number of transaction that are ready to execute
     * @return Transactions ready to execute
     */
    function readyToExecuteTransaction() public view returns (uint256) {
        return readyToExecute.length;
    }

    /**
     * @dev A private function for generating a random number less than passed variable
     * @param _size : size of array (readyToExecute)
     * @return A random number less than the passed size variable
     */
    function _generateRandomNumber(
        uint256 _size
    ) private view returns (uint256) {
        unchecked {
            return (uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp +
                            block.difficulty +
                            (
                                (
                                    uint256(
                                        keccak256(
                                            abi.encodePacked(block.coinbase)
                                        )
                                    )
                                )
                            ) +
                            block.gaslimit +
                            (
                                (
                                    uint256(
                                        keccak256(abi.encodePacked(msg.sender))
                                    )
                                )
                            ) +
                            block.number
                    )
                )
            ) % _size);
        }
    }

    /**
     * @dev Private function to remove transaction from readyToExecute[] after it have executed
     * @param _txId : Transaction Id that need to be removed
     */
    function _removeFromReadyToApprove(uint256 _txId) private {
        uint256 size = readyToExecute.length;
        for (uint256 i = 0; i < size; i++) {
            if (readyToExecute[i] == _txId) {
                readyToExecute[i] = readyToExecute[size - 1];
                readyToExecute.pop();
                break;
            }
        }
    }
}
