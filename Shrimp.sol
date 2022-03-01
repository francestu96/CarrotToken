// SPDX-License-Identifier: MIT
pragma solidity = 0.8.12;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

interface IERC20 {
    function totalSupply() view external returns (uint256);
    function balanceOf(address account) view external returns (uint256);
    function allowance(address owner, address spender) view external returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IPinkAntiBot {
  function setTokenOwner(address owner) external;
  function onPreTransferCheck(address from, address to, uint256 amount) external;
}

contract Shrimp is IERC20 {
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint256 private _minTokensToAddLiquidity;
    uint256 private _minBnbToAddBuyback;

    IPinkAntiBot public pinkAntiBot;
    IUniswapV2Router02 private immutable _uniswapV2Router;
    address private immutable _uniswapV2Pair;
    bool public enableAntiBot;
    bool public feesEnabled;

    bool private _inSwapAndLiquify;
    bool private _inBuyBack;
    address private _charityAddress;
    address private _owner;
    uint256 private _totalHoldersFeesAmount = 0;
    uint8 private _buyBackFees = 1;
    uint8 private _charityFees = 1;
    uint8 private _holdersFees = 3;
    uint8 private _liquidityFees = 3;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);
    event BuyBack(uint256 tokenBurnt);

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }
    modifier lockTheSwap(bool inBuyBack) {
        _inSwapAndLiquify = !inBuyBack;
        _inBuyBack = inBuyBack;
        _;
        _inSwapAndLiquify = inBuyBack;
        _inBuyBack = !inBuyBack;

    }

    constructor() {
        _name = "Shrimp";
        _symbol = "SRP";
        _totalSupply = 10**9 * 10**decimals();
        _minTokensToAddLiquidity = 10**6 * 10**decimals();
        _minBnbToAddBuyback = 10 * 10**18;    
        
        _owner = msg.sender;
        _balances[_owner] = _totalSupply;
        emit Transfer(address(0), _owner, _totalSupply);

        enableAntiBot = true;
        feesEnabled = false;
        
        // MAINNET: 0x8EFDb3b642eb2a20607ffe0A56CFefF6a95Df002
        pinkAntiBot = IPinkAntiBot(0xbb06F5C7689eA93d9DeACCf4aF8546C4Fe0Bf1E5); 
        pinkAntiBot.setTokenOwner(_owner);

        // MAINNET: 0x10ED43C718714eb63d5aA57B78B54704E256024E
        _uniswapV2Router = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
        _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        
        _charityAddress = 0x000000000000000000000000000000000000dEaD;
    }


    function transfer(address to, uint256 amount) public override returns (bool) {
        if (!enableAntiBot) {
            pinkAntiBot.onPreTransferCheck(msg.sender, to, amount);
        }

        _transferFeesCheck(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = allowance(from, msg.sender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(from, msg.sender, currentAllowance - amount);
            }
        }
    
        _transferFeesCheck(from, to, amount);
        return true;
    }

    function approvePrivateSale(address privateSale) public onlyOwner returns (bool) {
        _approve(msg.sender, privateSale, _totalSupply);
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
        if(account == address(this) || account == _uniswapV2Pair){
            return _balances[account];
        }

        uint accountPerm = _balances[account] * 1000 / _totalSupply;
        return _balances[account] + (_totalHoldersFeesAmount * accountPerm / 1000);
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function setFeesEnabled(bool enable) public onlyOwner {
        feesEnabled = enable;
    }

    function setEnableAntiBot(bool enable) external onlyOwner {
        enableAntiBot = enable;
    }


    function _transferFeesCheck(address from, address to, uint256 amount) private {
        if (!_inSwapAndLiquify && !_inBuyBack && from != _owner){
            uint holdersFeeValue = amount * _holdersFees / 100;
            _totalHoldersFeesAmount += holdersFeeValue;
            uint buyBackValue = amount * _buyBackFees / 100;
            uint charityFeeValue = amount * _charityFees / 100;
            uint liquidityFeeValue = amount * _liquidityFees / 100;
            
            uint256 contractTokenBalance = balanceOf(address(this));            
            if (from != _uniswapV2Pair && contractTokenBalance >= _minTokensToAddLiquidity)
                _swapAndLiquify(contractTokenBalance);

            if(IERC20(_uniswapV2Router.WETH()).balanceOf(_uniswapV2Pair) > _minBnbToAddBuyback)
                _buyBack();

            _swapTokensForEth(buyBackValue);            
            _transfer(from, address(this), holdersFeeValue + liquidityFeeValue);
            _transfer(from, _charityAddress, charityFeeValue);
            emit Transfer(from, _charityAddress, charityFeeValue);
            
            _transfer(from, to, amount - holdersFeeValue - buyBackValue - charityFeeValue - liquidityFeeValue);
            emit Transfer(from, to, amount - holdersFeeValue - buyBackValue - charityFeeValue - liquidityFeeValue);
        }
        else{
            _transfer(from, to, amount);
            emit Transfer(from, to, amount);
        }
    }

    function _swapAndLiquify(uint256 tokenAmount) private lockTheSwap(false) {
        uint256 half;
        uint256 otherHalf;
        uint256 newBalance;

        unchecked{
            half = tokenAmount / 2;
            otherHalf = tokenAmount - half;
        }

        uint256 initialBalance = address(this).balance;
        _swapTokensForEth(half);

        unchecked{
            newBalance = address(this).balance - initialBalance;
        }

        _addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function _swapTokensForEth(uint256 tokenAmount) private lockTheSwap(true) {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _uniswapV2Router.WETH();

        _approve(address(this), address(_uniswapV2Router), tokenAmount);

        _uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);
    }

    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(_uniswapV2Router), tokenAmount);

        _uniswapV2Router.addLiquidityETH{value: ethAmount}(address(this), tokenAmount, 0, 0, _owner, block.timestamp);
    }

    function _buyBack() private lockTheSwap(true) {
        uint256 newBalance;
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _uniswapV2Router.WETH();

        uint256 initialBalance = address(this).balance;

        _approve(address(this), address(_uniswapV2Router), initialBalance);
        _uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens(0, path, address(this), block.timestamp);

        unchecked{
            newBalance = address(this).balance - initialBalance;
        }

        _transfer(address(this), 0x000000000000000000000000000000000000dEaD, newBalance);
        _totalSupply -= newBalance;

        emit BuyBack(newBalance);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(balanceOf(from) >= amount, "ERC20: transfer amount exceeds balance");

        if(_balances[from] < amount){
            unchecked{
                _balances[from] = balanceOf(from) - amount;
                _totalHoldersFeesAmount -= amount - _balances[from];
            }
        }
        else{
            unchecked {
                _balances[from] -= amount;
            }
        }

        _balances[to] += amount;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    receive() external payable {}
}