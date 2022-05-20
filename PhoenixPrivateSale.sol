// SPDX-License-Identifier: MIT
pragma solidity = 0.8.12;

interface IPhoenix {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract PhoenixPrivateSale {
    uint constant private _min = 10**14; 
    uint constant private _max = 10**18; 
    uint constant private _totalMax = 25 * 10**18;
    address private _owner; 
    address[] private _whitelist;
    uint private _totalReceived = 0;

    IPhoenix private _phoenix; 
    mapping(address => uint256) private _amounts;
    event ValueReceived(address user, uint amount);

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    constructor(address phoenixAddress) {
        _owner = msg.sender;
        _phoenix = IPhoenix(phoenixAddress);
    }

    function addToWhitelist(address[] memory addrs) public onlyOwner {
        for(uint i = 0; i < addrs.length; i++)
            _whitelist.push(addrs[i]);
    }

    function distributePhoenixs() public onlyOwner {
        // 1 000 000 000 000 jager = 1 SRP wei
        // 0.000001 BNB = 1 SRP wei
        for(uint i = 0; i < _whitelist.length; i++){
            _phoenix.transferFrom(_owner, _whitelist[i], _amounts[_whitelist[i]] / (10**12));
        }
    }

    function closePrivateSale() public onlyOwner {
        selfdestruct(payable(_owner));
    }

    function getWhitelist() public view onlyOwner returns(address[] memory){
        return _whitelist;
    }

    receive() external payable {
        bool whitelisted = false;
        for(uint i = 0; i < _whitelist.length; i++){
            if(_whitelist[i] == msg.sender){
                whitelisted = true;
                break;
            }
        }
        require(whitelisted, "You are not in White List!");
        require(msg.value >= _min && msg.value <= _max, "Amount is not in the accepted range");
        require(_amounts[msg.sender] + msg.value <= _max, "Amount exceed the maximum accepted value");
        require(_totalReceived + msg.value <= _totalMax, "Amount exceed the maximum Private Sale value");

        _totalReceived += msg.value;
        _amounts[msg.sender] += msg.value;

        emit ValueReceived(msg.sender, msg.value);
    }
}