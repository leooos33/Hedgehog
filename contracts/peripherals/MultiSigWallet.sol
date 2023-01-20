// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public numConfirmationsRequired = 2;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
        address transferedKeeper;
        address transferedGovernance;
        address executor;
    }

    mapping(uint => mapping(address => bool)) public isConfirmed;

    Transaction[] public transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    constructor(address[] memory _owners) {
        isOwner[0x4530DA167C5a751e48f35b2aa08F44570C03B7dd] = true;
        owners.push(0x4530DA167C5a751e48f35b2aa08F44570C03B7dd);
        isOwner[0x4530DA167C5a751e48f35b2aa08F44570C03B7dd] = true;
        owners.push(0x4530DA167C5a751e48f35b2aa08F44570C03B7dd);
        isOwner[0x4530DA167C5a751e48f35b2aa08F44570C03B7dd] = true;
        owners.push(0x4530DA167C5a751e48f35b2aa08F44570C03B7dd);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(
        address _to,
        uint _value,
        bytes memory _data,
        address _transferedKeeper,
        address _transferedGovernance,
        address _executor,
    ) public onlyOwner {
        uint txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0,
                transferedKeeper: _transferedKeeper,
                transferedGovernance: _transferedGovernance,
                executor: _executor
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    interface IModule {
        function setGovernance(address to) external;
        function setKeeper(address to) external;
    }

    function executeTransaction(
        uint _txIndex
    ) public onlyOwner {
        _executeTransaction(_txIndex);
    }

    function executorExecuteTransaction(
        uint _txIndex
    ) public {
        require(msg.sender == transactions[_txIndex].executor, "C1");
        _executeTransaction(_txIndex);
    }

    function _executeTransaction(
        uint _txIndex
    ) internal txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;
        
        //TODO; decide where to get VaultStorage address from
        if(transaction.transferedGovernance != address(0)) IVaultStorage(addressStorage).setGovernance(transaction.transferedGovernance);
        if(transaction.transferedKeeper != address(0)) IVaultStorage(addressStorage).setKeeper(transaction.transferedKeeper);

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        if(transaction.transferedGovernance != address(0)) IModule(transaction.transferedGovernance).setGovernance(address(this));
        if(transaction.transferedKeeper != address(0)) IModule(transaction.transferedKeeper).setKeeper(address(this));

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    function getTransaction(
        uint _txIndex
    )
        public
        view
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint numConfirmations,
            address transferedKeeper,
            address transferedGovernance
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
            transaction.transferedKeeper
            transaction.transferedGovernance
        );
    }
}
