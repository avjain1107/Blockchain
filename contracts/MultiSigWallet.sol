//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

contract MultiSigWallet {
    event RevokeApproval(address indexed owner, uint256 indexed txId);
    event SubmitTransaction(address indexed owner, uint256 indexed txId);
    event ApproveTransaction(address indexed owner, uint256 indexed txId);
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
    uint256 private transactionCount = 1;
    uint256 public confirmationRequired;
    address private owner;

    struct Transaction {
        address payable to;
        uint256 value;
        bool executed;
        uint256 approvalCount;
    }

    constructor(uint256 _confirmationRequired) {
        owner = msg.sender;
        isOwner[msg.sender] = true;
        confirmationRequired = _confirmationRequired;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Only owners can perform this operation.");
        _;
    }

    modifier notOwner(address _address) {
        require(!isOwner[_address], "already approved owner");
        _;
    }

    modifier notExecuted(uint256 _txId) {
        require(
            transaction[_txId].executed != true,
            "Transaction already executed"
        );
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }

    modifier transactionExist(uint256 _txId) {
        require(
            transaction[_txId].to != address(0),
            "Transaction does not exist"
        );
        _;
    }

    function submitTransaction(
        address payable _to,
        uint256 _value
    ) external onlyOwner notNull(_to) {
        uint256 txId = transactionCount++;
        transaction[txId] = Transaction(_to, _value, false, 1);
        approval[txId][msg.sender] = true;
        emit SubmitTransaction(msg.sender, txId);
        if (transaction[txId].approvalCount == confirmationRequired) {
            readyToExecute.push(txId);
        }
    }

    function approveTransaction(
        uint256 _txId
    ) external onlyOwner transactionExist(_txId) notExecuted(_txId) {
        require(
            approval[_txId][msg.sender] != true,
            "Transaction already approved by owner."
        );
        approval[_txId][msg.sender] = true;
        transaction[_txId].approvalCount += 1;
        if (transaction[_txId].approvalCount == confirmationRequired) {
            readyToExecute.push(_txId);
        }
        emit ApproveTransaction(msg.sender, _txId);
    }

    function revokeTransaction(
        uint256 _txId
    ) external onlyOwner transactionExist(_txId) notExecuted(_txId) {
        require(
            approval[_txId][msg.sender],
            "Transaction not approved by owner."
        );
        approval[_txId][msg.sender] = false;
        transaction[_txId].approvalCount -= 1;
        if (transaction[_txId].approvalCount == confirmationRequired - 1) {
            _removeFromReadyToApprove(_txId);
        }
        emit RevokeApproval(msg.sender, _txId);
    }

    function extecuteTransaction() external payable {
        uint256 size = readyToExecute.length;
        require(size > 0, "No transaction is yet ready to execute");
        uint256 randomNumber = _generateRandomNumber(size);
        uint256 _txId = readyToExecute[randomNumber];
        address payable _to = transaction[_txId].to;
        uint256 _value = transaction[_txId].value;
        _to.transfer(_value);
        transaction[_txId].executed = true;
        readyToExecute[randomNumber] = readyToExecute[size - 1];
        readyToExecute.pop();
        emit ExecuteTransaction(msg.sender, _txId, _to, _value);
    }

    function batchExecuteTransaction() external payable onlyOwner {
        require(
            msg.sender == owner,
            "only contract owner can do Batch execution"
        );
        uint256 size = readyToExecute.length;
        require(size > 0, "No transaction is yet ready to execute");

        do {
            uint256 randomNumber = _generateRandomNumber(size);
            uint256 _txId = readyToExecute[randomNumber];
            address payable _to = transaction[_txId].to;
            uint256 _value = transaction[_txId].value;
            _to.transfer(_value);
            transaction[_txId].executed = true;
            readyToExecute[randomNumber] = readyToExecute[size - 1];
            readyToExecute.pop();
            emit ExecuteTransaction(msg.sender, _txId, _to, _value);
            size -= 1;
        } while (size > 0);
    }

    function addOwner(
        address _address
    ) external onlyOwner notNull(_address) notOwner(_address) {
        isOwner[_address] = true;
    }

    function getTransactionApprovalCount(
        uint256 _txId
    ) public view transactionExist(_txId) returns (uint256) {
        return transaction[_txId].approvalCount;
    }

    function readyToExecuteTransaction() public view returns (uint256) {
        return readyToExecute.length;
    }

    function _generateRandomNumber(
        uint256 _size
    ) private view returns (uint256) {
        uint256 _randomNumber = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp +
                        block.difficulty +
                        (
                            (
                                uint256(
                                    keccak256(abi.encodePacked(block.coinbase))
                                )
                            )
                        ) +
                        block.gaslimit +
                        ((uint256(keccak256(abi.encodePacked(msg.sender))))) +
                        block.number
                )
            )
        ) % _size;
        return _randomNumber;
    }

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
