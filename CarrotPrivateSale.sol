// SPDX-License-Identifier: MIT
pragma solidity = 0.8.12;

interface ICarrot {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract CarrotPrivateSale {
    uint constant private _min = 10**14; 
    uint constant private _max = 10**18; 
    uint constant private _totalMax = 25 * 10**18;
    address private _owner; 
    uint public totalReceived = 0;
    address[] public senders;

    ICarrot private _carrot; 
    mapping(address => uint256) public amounts;
    event ValueReceived(address user, uint amount);

    constructor(address carrotAddress) {
        _owner = msg.sender;
        _carrot = ICarrot(carrotAddress);
    }

    function transferCarrot() public {
        require(msg.sender == _owner, "Ownable: caller is not the owner!");

        // 1 * 10**18 BNB = 0.0001 * 10**2 CRT
        for(uint i = 0; i < senders.length; i++){
            _carrot.transferFrom(_owner, senders[i], amounts[senders[i]] / (10**14));
        }
    }

    function withdraw() public {
        require(msg.sender == _owner, "Ownable: caller is not the owner!");

        bool sent = payable(_owner).send(address(this).balance);
        require(sent, "Failed to send Ether");
    }

    receive() external payable {
        require(msg.value >= _min && msg.value <= _max, "Amount is not in the accepted range");
        require(totalReceived + msg.value <= _totalMax, "Amount exceed the maximum accepted value");

        totalReceived += msg.value;
        if(amounts[msg.sender] == 0){
            senders.push(msg.sender);
            amounts[msg.sender] = msg.value;
        }
        else{
            amounts[msg.sender] += msg.value;
        }

        emit ValueReceived(msg.sender, msg.value);
    }
}