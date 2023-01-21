// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

interface IModule {
    function setGovernance(address to) external;

    function setKeeper(address to) external;
}

/**
 * Error
 * M0: Paused
 * M1: Cannot execute tx due to confirmation number is not enough
 * M2: Not owner
 * M3: Tx does not exist
 * M4: Tx already executed
 * M5: Tx already confirmed
 * M6: Tx failed
 * M7: Tx not confirmed
 */

contract MultiSigWallet {
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public numConfirmationsRequired = 2;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
        address transferedKeeper;
        address transferedGovernance;
        address invoker;
    }

    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    Transaction[] public transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "M2");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "M3");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "M4");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "M5");
        _;
    }

    constructor(address[] memory _owners) {
        isOwner[_owners[0]] = true;
        owners.push(_owners[0]);
        isOwner[_owners[1]] = true;
        owners.push(_owners[1]);
        isOwner[_owners[2]] = true;
        owners.push(_owners[2]);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data,
        address _transferedKeeper,
        address _transferedGovernance,
        address _invoker
    ) public onlyOwner {
        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0,
                transferedKeeper: _transferedKeeper,
                transferedGovernance: _transferedGovernance,
                invoker: _invoker
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex) public onlyOwner {
        _executeTransaction(_txIndex);
    }

    function invokerExecuteTransaction(uint256 _txIndex) public {
        require(msg.sender == transactions[_txIndex].invoker, "M0");
        _executeTransaction(_txIndex);
    }

    //TODO: decide where to get VaultStorage address from
    address constant addressStorage = 0xa6D7b99c05038ad2CC39F695CF6D2A06DdAD799a;

    function _executeTransaction(uint256 _txIndex) internal txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(transaction.numConfirmations >= numConfirmationsRequired, "M1");

        transaction.executed = true;

        if (transaction.transferedGovernance != address(0))
            IModule(addressStorage).setGovernance(transaction.transferedGovernance);
        if (transaction.transferedKeeper != address(0)) IModule(addressStorage).setKeeper(transaction.transferedKeeper);

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "M6");

        if (transaction.transferedGovernance != address(0))
            IModule(transaction.transferedGovernance).setGovernance(address(this));
        if (transaction.transferedKeeper != address(0)) IModule(transaction.transferedKeeper).setKeeper(address(this));

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "M7");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 _txIndex)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations,
            address transferedKeeper,
            address transferedGovernance,
            address invoker
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations,
            transaction.transferedKeeper,
            transaction.transferedGovernance,
            transaction.invoker
        );
    }
}
