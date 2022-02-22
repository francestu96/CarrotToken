// SPDX-License-Identifier: MIT
pragma solidity = 0.8.7;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

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

  function onPreTransferCheck(
    address from,
    address to,
    uint256 amount
  ) external;
}

contract Carrot is IERC20 {
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    IPinkAntiBot public pinkAntiBot;
    IUniswapV2Router02 public immutable uniswapV2Router;
    bool public enableAntiBot;
    address private _charityAddress;
    address private _owner;
    uint private _totalHoldersFeesAmount = 0;
    uint private _burnFees = 1;
    uint private _charityFees = 1;
    uint private _holdersFees = 3;
    uint private _liquidityFees = 3;

    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor() {
        _name = "Carrot";
        _symbol = "CRT";
        _totalSupply = 1000000 * 10**decimals();
        
        _owner = msg.sender;
        _balances[_owner] = _totalSupply;
        emit Transfer(address(0), _owner, _totalSupply);

        enableAntiBot = true;
        uniswapV2Router = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3); // MAINNET: 0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F
        pinkAntiBot = IPinkAntiBot(0xbb06F5C7689eA93d9DeACCf4aF8546C4Fe0Bf1E5); // MAINNET: 0x8EFDb3b642eb2a20607ffe0A56CFefF6a95Df002
        pinkAntiBot.setTokenOwner(_owner);
        _charityAddress = 0x000000000000000000000000000000000000dEaD;
    }


    function transfer(address to, uint256 amount) public override returns (bool) {
        if (!enableAntiBot) {
            pinkAntiBot.onPreTransferCheck(msg.sender, to, amount);
        }

        transferWithFees(msg.sender, to, amount);
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

        transferWithFees(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
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
        uint accountPerm = _balances[account] * 1000 / _totalSupply;
        return _balances[account] + (_totalHoldersFeesAmount * accountPerm / 1000);
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function totalHoldersFeesAmount() public view returns (uint) {
        return _totalHoldersFeesAmount;
    }


    function setEnableAntiBot(bool _enable) external {
        require(_owner == msg.sender, "Ownable: caller is not the owner!");
        enableAntiBot = _enable;
    }

    function transferWithFees(address from, address to, uint256 amount) private {
        // uint holdersFeeValue = amount * _holdersFees / 100;
        // _totalHoldersFeesAmount += holdersFeeValue;
        // uint burnFeeValue = amount * _burnFees / 100;
        // _totalSupply -= burnFeeValue;
        // uint charityFeeValue = amount * _charityFees / 100;
        // uint liquidityFeeValue = amount * _liquidityFees / 100;
        
        // swapAndLiquify(liquidityFeeValue);
        // _transfer(from, address(0), holdersFeeValue + burnFeeValue);
        // _transfer(from, _charityAddress, charityFeeValue);
        // _transfer(from, to, amount - holdersFeeValue - burnFeeValue - charityFeeValue - liquidityFeeValue);
        uint256 half = amount / 2;
        // swapAndLiquify(amount - half);
        _transfer(from, to, half);
    }
    
    function swapAndLiquify(uint256 contractTokenBalance) private {
        uint256 half;
        uint256 otherHalf;
        uint256 newBalance;

        unchecked {
            half = contractTokenBalance / 2;
            otherHalf = contractTokenBalance - half;
        }

        uint256 initialBalance = address(this).balance;
        swapTokensForETH(half); 

        unchecked{
            newBalance = address(this).balance - initialBalance;
        }
        addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForETH(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.addLiquidityETH{value: ethAmount}(address(this), tokenAmount, 0, 0, msg.sender, block.timestamp);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(balanceOf(from) >= amount, "ERC20: transfer amount exceeds balance");

        if(_balances[from] < amount){
            unchecked{
                _balances[address(0)] -= _balances[from] - amount;
            }
            _balances[from] = 0;
        }
        else{
            unchecked {
                _balances[from] -= amount;
            }
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}