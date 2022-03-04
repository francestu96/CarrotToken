// SPDX-License-Identifier: MIT
pragma solidity = 0.8.12;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

interface IBEP20 {
    function totalSupply() view external returns (uint256);
    function balanceOf(address account) view external returns (uint256);
    function allowance(address owner, address spender) view external returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Test is IBEP20 {
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint256 private _minBnbToAddBuyback;

    IUniswapV2Router02 private immutable _uniswapV2Router;
    address private immutable _uniswapV2Pair;

    bool private _inSwapAndLiquify;
    bool private _inSwapTokenForETH;
    address private _owner;
    uint8 private _buyBackFees = 10;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event SwappedTokens(uint amountSwapped);

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }
    modifier lockSwapTokenForETH {
        _inSwapTokenForETH = true;
        _;
        _inSwapTokenForETH = false;

    }

    constructor() {
        _name = "Test";
        _symbol = "TST";
        _totalSupply = 10**9 * 10**decimals();
        _minBnbToAddBuyback = 1 * 10**15;    

        _owner = msg.sender;
        _balances[_owner] = _totalSupply;
        emit Transfer(address(0), _owner, _totalSupply);

        // MAINNET: 0x10ED43C718714eb63d5aA57B78B54704E256024E
        _uniswapV2Router = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
        _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
    }


    function transfer(address to, uint256 amount) public override returns (bool) {
        _transferFeesCheck(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        // uint256 currentAllowance = allowance(from, msg.sender);
        // if (currentAllowance != type(uint256).max) {
        //     require(currentAllowance >= amount, "BEP20: insufficient allowance");
        //     unchecked {
        //         _approve(from, msg.sender, currentAllowance - amount);
        //     }
        // }
    
        _transferFeesCheck(from, to, amount);
        return true;
    }


    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
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


    function _transferFeesCheck(address from, address to, uint256 amount) private {
        if (!_inSwapTokenForETH && from != _owner){ // && from != _uniswapV2Pair){           
            uint buyBackValue = amount * _buyBackFees / 100;

            _transfer(from, address(this), buyBackValue);
            emit Transfer(from, address(this), buyBackValue);

            _transfer(from, to, amount - buyBackValue);
            emit Transfer(from, to, amount - buyBackValue);

            _swapTokensForEth(buyBackValue);   
        }
        else{
            _transfer(from, to, amount);
            emit Transfer(from, to, amount);
        }
    }

    function getPoolBnb() public view returns (uint256){
        return IBEP20(_uniswapV2Router.WETH()).balanceOf(_uniswapV2Pair);
    }

    function _swapTokensForEth(uint256 tokenAmount) public lockSwapTokenForETH {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _uniswapV2Router.WETH();

        _approve(address(this), address(_uniswapV2Router), tokenAmount);

        _uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);
    }

    function swapEthForTokens(uint256 tokenAmount) public {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _uniswapV2Router.WETH();

        _approve(msg.sender, address(_uniswapV2Router), tokenAmount + 100000000);

        _uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: tokenAmount}(0, path, msg.sender, block.timestamp);
    }

    // function _buyBack() private lockTheSwap {
    //     uint256 newBalance;
    //     address[] memory path = new address[](2);
    //     path[0] = address(this);
    //     path[1] = _uniswapV2Router.WETH();

    //     uint256 initialBalance = address(this).balance;

    //     _approve(address(this), address(_uniswapV2Router), initialBalance);
    //     _uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens(0, path, address(this), block.timestamp);

    //     unchecked{
    //         newBalance = address(this).balance - initialBalance;
    //     }

    //     _approve(address(this), address(0), newBalance);
    //     _transfer(address(this), address(0), newBalance);
    //     _totalSupply -= newBalance;

    //     emit BuyBack(newBalance);
    // }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "BEP20: transfer from the zero address");
        require(balanceOf(from) >= amount, "BEP20: transfer amount exceeds balance");

        unchecked{
            _balances[from] -= amount;
        }

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