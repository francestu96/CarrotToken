// SPDX-License-Identifier: MIT
pragma solidity = 0.8.12;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

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

contract Shrimp is IBEP20 {
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint256 private _minTokensToAddLiquidity;
    uint256 private _minBnbToBuyback;

    IUniswapV2Router02 private immutable _uniswapV2Router;
    address private immutable _uniswapV2Pair;

    bool private _inSwapAndLiquify;
    bool private _inSwapTokenForETH;
    address private _owner;
    uint256 public totalHoldersFeesAmount = 0;
    uint256 public totalBuyBackFeesAmount = 0;
    uint256 public totalLiquidityFeesAmount = 0;
    uint8 private _holdersFees = 3;
    uint8 private _buyBackFees = 3;
    uint8 private _liquidityFees = 2;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }
    modifier lockSwapTokenForETH {
        _inSwapTokenForETH = true;
        _;
        _inSwapTokenForETH = false;

    }
    modifier lockTheSwap {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;

    }

    constructor() {
        _name = "Shrimp";
        _symbol = "SRP";
        _totalSupply = 10**9 * 10**decimals();
        _minTokensToAddLiquidity = 5**6 * 10**decimals();
        _minBnbToBuyback = 1 * 10**15;    

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
        uint256 currentAllowance = allowance(from, msg.sender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "BEP20: insufficient allowance");
            unchecked {
                _approve(from, msg.sender, currentAllowance - amount);
            }
        }
    
        _transferFeesCheck(from, to, amount);
        return true;
    }

    function approvePrivateSale(address privateSale) public onlyOwner returns (bool) {
        _approve(msg.sender, privateSale, type(uint256).max);
        return true;
    }

    function setMinBnbToBuyback(uint256 value) public onlyOwner {
        _minBnbToBuyback = value;
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
        if(account == address(this) || account == _uniswapV2Pair || account == address(0)){
            return _balances[account];
        }

        uint accountPerm = _balances[account] * 1000 / _totalSupply;
        return _balances[account] + (totalHoldersFeesAmount * accountPerm / 1000);
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function _transferFeesCheck(address from, address to, uint256 amount) private {
        uint256 holdersFeeValue = 0;
        uint256 buyBackValue = 0;
        uint256 liquidityFeeValue = 0;

        if (!(_inSwapAndLiquify || _inSwapTokenForETH) && from != _owner){       
            unchecked{
                holdersFeeValue = amount * _holdersFees / 100;
                buyBackValue = amount * _buyBackFees / 100;
                liquidityFeeValue = amount * _liquidityFees / 100;
                totalHoldersFeesAmount += holdersFeeValue;
                totalBuyBackFeesAmount += buyBackValue;
                totalLiquidityFeesAmount += liquidityFeeValue;
            }    
            
            // BUG: why cannot be from equals to uniswap pair? Check it out:
            // https://dashboard.tenderly.co/tx/bsc-testnet/0x47f9495843ba7305cc2b9d76f3ff5da4f12eee215ac184ef583738840197294a
            // https://dashboard.tenderly.co/tx/bsc-testnet/0xe92bdfcd1ddab59d909e47d40f25c200e5c90801e6297aff75720f6df5d37aa4
            if (from != _uniswapV2Pair) {
                if(totalLiquidityFeesAmount >= _minTokensToAddLiquidity){
                    if(_swapAndLiquify(totalLiquidityFeesAmount))
                        totalLiquidityFeesAmount = 0;
                }

                if(IBEP20(_uniswapV2Router.WETH()).balanceOf(_uniswapV2Pair) < _minBnbToBuyback)
                    _buyBackAndBurn();

                if(_swapTokensForEth(totalBuyBackFeesAmount))
                    totalBuyBackFeesAmount = 0;
            }   

            _transfer(from, address(this), holdersFeeValue + buyBackValue + liquidityFeeValue);
            _transfer(from, to, amount - holdersFeeValue - buyBackValue - liquidityFeeValue);
            emit Transfer(from, to, amount - holdersFeeValue - buyBackValue - liquidityFeeValue);
        }
        else{
            _transfer(from, to, amount);
            emit Transfer(from, to, amount);
        }
    }

    function _swapAndLiquify(uint256 tokenAmount) private lockTheSwap returns(bool){
        uint256 half;
        uint256 otherHalf;
        uint256 newBalance;

        unchecked{
            half = tokenAmount / 2;
            otherHalf = tokenAmount - half;
        }

        uint256 initialBalance = address(this).balance;
        if (_swapTokensForEth(half)){
            unchecked{
                newBalance = address(this).balance - initialBalance;
            }

            return _addLiquidity(otherHalf, newBalance);
        }

        return false;
    }

    function _swapTokensForEth(uint256 tokenAmount) private lockSwapTokenForETH returns(bool){
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _uniswapV2Router.WETH();

        _approve(address(this), address(_uniswapV2Router), tokenAmount);

        try _uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp){
            return true;
        }
        catch {
            return false;
        }
    }

    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) private returns(bool){
        _approve(address(this), address(_uniswapV2Router), tokenAmount);

        try _uniswapV2Router.addLiquidityETH{value: ethAmount}(address(this), tokenAmount, 0, 0, _owner, block.timestamp){
            return true;
        }
        catch {
            return false;
        }
    }

    function _buyBackAndBurn() private lockTheSwap returns(bool){
        uint256 newBalance;
        address[] memory path = new address[](2);
        path[0] = _uniswapV2Router.WETH();
        path[1] = address(this);

        uint256 initialBalance = balanceOf(address(0));

        try _uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: address(this).balance}(0, path, address(0), block.timestamp){
            unchecked{
                newBalance = balanceOf(address(0)) - initialBalance;
                _totalSupply -= newBalance;
            }

            return true;
        }
        catch {
            return false;
        }
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "BEP20: transfer from the zero address");
        require(balanceOf(from) >= amount, "BEP20: transfer amount exceeds balance");

        if(_balances[from] < amount){
            unchecked{
                _balances[from] = balanceOf(from) - amount;
                totalHoldersFeesAmount -= amount - _balances[from];
            }
        }
        else{
            unchecked{
                _balances[from] -= amount;
            }
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