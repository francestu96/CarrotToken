// SPDX-License-Identifier: MIT
pragma solidity = 0.8.12;

interface IShrimp {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract ShrimpPrivateSale {
    uint constant private _min = 10**14; 
    uint constant private _max = 10**18; 
    uint constant private _totalMax = 25 * 10**18;
    address private _owner; 
    address[] private _senders;
    uint private _totalReceived = 0;

    IShrimp private _shrimp; 
    mapping(address => uint256) private _amounts;
    event ValueReceived(address user, uint amount);

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    constructor(address shrimpAddress) {
        _owner = msg.sender;
        _shrimp = IShrimp(shrimpAddress);
    }

    function distributeShrimps() public onlyOwner {
        // 1 000 000 000 000 jager = 1 SRP wei
        // 0.000001 BNB = 1 SRP wei
        for(uint i = 0; i < _senders.length; i++){
            _shrimp.transferFrom(_owner, _senders[i], _amounts[_senders[i]] / (10**12));
        }
    }

    function closePrivateSale() public onlyOwner {
        selfdestruct(payable(_owner));
    }

    receive() external payable {
        require(msg.value >= _min && msg.value <= _max, "Amount is not in the accepted range");
        require(_totalReceived + msg.value <= _totalMax, "Amount exceed the maximum accepted value");

        _totalReceived += msg.value;
        if(_amounts[msg.sender] == 0){
            _senders.push(msg.sender);
            _amounts[msg.sender] = msg.value;
        }
        else{
            _amounts[msg.sender] += msg.value;
        }

        emit ValueReceived(msg.sender, msg.value);
    }
}