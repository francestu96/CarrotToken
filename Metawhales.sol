// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

interface NFTRarity {
    function walletOfOwner(address _owner) external view returns (uint256[] memory);
    function isRarity1(uint256 tokenid) external view returns (bool);
    function isRarity2(uint256 tokenid) external view returns (bool);
    function isRarity3(uint256 tokenid) external view returns (bool);
    function balanceOf(address owner) external view returns (uint256);
}

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

contract METAWHALES is IBEP20 {
    uint8 public marketingFee = 4;
    uint8 public teamFee = 2;
    uint8 public buyback_burnFee = 4;
    uint8 public holdersFees = 3;
    uint8 public totalFee = buyback_burnFee + marketingFee + teamFee + holdersFees;
    uint256 public totalHoldersFeesAmount = 0;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    
    address private _NFT;
    address private _owner;
    uint256 private _maxWalletToken;

    address public marketingFeeReceiver;
    address public teamFeeReceiver;
    address public buyback_burnFeeReceiver;

    IUniswapV2Router02 private immutable _router;
    address private immutable _pair;

    mapping (address => uint256) _balances;
    mapping (address => mapping (address => uint256)) _allowances;

    mapping (address => bool) isFeeExempt;
    mapping (address => bool) isMaxWalletExempt;

    bool private _launched;
    uint256 private _launchedAt;
    uint256 private _deadBlocks;

    uint256 private _feeDenominator   = 100;
    uint256 private _sellMultiplier = 120;
    uint256 private _buyMultiplier = 100;
    uint256 private _transferMultiplier = 100;

    bool public swapEnabled = true;
    uint256 public swapThreshold = _totalSupply / 1000;
    uint256 public swapTransactionThreshold = _totalSupply * 5 / 10000;

    bool private inSwap;
    modifier swapping() { 
        inSwap = true; 
        _; 
        inSwap = false; 
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    constructor(address NFT_address) {
        _name = "Metawhales";
        _symbol = "MWHALE";
        _totalSupply = 1 * 10**7 * 10**decimals();
        _launched = false;

        // MAINNET: 0x10ED43C718714eb63d5aA57B78B54704E256024E
        _router = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
        _pair = IUniswapV2Factory(_router.factory()).createPair(address(this), _router.WETH());
        _maxWalletToken = _totalSupply * 10 / 250;
        _NFT = NFT_address;

        marketingFeeReceiver = _owner;
        teamFeeReceiver = _owner;
        buyback_burnFeeReceiver = _owner; 

        _owner = msg.sender;
        _balances[_owner] = _totalSupply;
        emit Transfer(address(0), _owner, _totalSupply);
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
        if(account == address(this) || account == _pair || account == address(0)){
            return _balances[account];
        }

        uint accountPerm = _balances[account] * 1000 / _totalSupply;
        return _balances[account] + (totalHoldersFeesAmount * accountPerm / 1000);
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if(_allowances[sender][msg.sender] != type(uint256).max){
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender] - (amount);
        }
        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(balanceOf(sender) >= amount, "BEP20: transfer amount exceeds balance");

        if(inSwap)
            return _basicTransfer(sender, recipient, amount);

        if(sender != _owner && recipient != _owner){
            require(_launched,"Trading not open yet");
        }

        if (sender != _owner && recipient != _owner  && recipient != address(this) && sender != address(this)){
            if(recipient != _pair)
                require((amount + balanceOf(recipient)) <= _maxWalletToken || isMaxWalletExempt[recipient],"Max wallet holding reached");
        }

        // Swap
        if(sender != _pair && !inSwap && swapEnabled && amount > swapTransactionThreshold && _balances[address(this)] >= swapThreshold) {
            swapBack();
        }

        // Actual transfer
        _balances[sender] = _balances[sender] - amount;

        if(_balances[sender] < amount){
            unchecked{
                _balances[sender] = balanceOf(sender) - amount;
                totalHoldersFeesAmount -= amount - _balances[sender];
            }
        }
        else{
            unchecked{
                _balances[sender] -= amount;
            }
        }
        
        uint256 amountReceived = (isFeeExempt[sender] || isFeeExempt[recipient]) ? amount : takeFee(sender, amount, recipient);
        _balances[recipient] += amountReceived;

        emit Transfer(sender, recipient, amountReceived);
        return true;
    }

    function _basicTransfer(address from, address to, uint256 amount) private returns (bool){
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
        return true;
    }

    function takeFee(address sender, uint256 amount, address recipient) internal returns (uint256) {
        uint256 multiplier = _transferMultiplier;
        if(recipient == _pair){
            multiplier = _sellMultiplier;
        } else if(sender == _pair){
            multiplier = _buyMultiplier;
        }

        uint256 feeAmount = amount * totalFee * _transferMultiplier / (_feeDenominator * 100);

        if(sender == _pair && (_launchedAt + _deadBlocks) > block.number){
            feeAmount = amount * 99 / 100;
        }

        if(_buyMultiplier == 100 && _sellMultiplier == 120 && recipient == _pair && NFTRarity(_NFT).balanceOf(sender) != 0) {
            uint256 rarity = getRarity(sender);
            if(rarity == 1)
                feeAmount = amount * 6 / 100;
            else if(rarity == 2) 
                feeAmount = amount * 8 / 100;
            else 
                feeAmount = amount * 10 / 100;
        }

        if(_buyMultiplier == 100 && _sellMultiplier == 120 && sender == _pair && NFTRarity(_NFT).balanceOf(recipient) != 0) {
            uint256 rarity = getRarity(recipient);
            if(rarity == 1)
                feeAmount = amount * 4 / 100;
            else if(rarity == 2)
                feeAmount = amount * 6 / 100;
            else 
                feeAmount = amount * 8 / 100;
        } 

        uint256 holdersFeeValue = amount * holdersFees / 100;
        totalHoldersFeesAmount += holdersFeeValue;

        _balances[address(this)] += feeAmount;
        emit Transfer(sender, address(this), feeAmount);
        return amount - feeAmount;
    }

    function getRarity(address owner) public view returns (uint256 Rarity) {
        uint256 Rarity1;
        uint256 Rarity2;
        uint256 Rarity3;

        uint256[] memory inventory = NFTRarity(_NFT).walletOfOwner(owner);

        for (uint256 i=0; i < inventory.length; ++i) {
            if (NFTRarity(_NFT).isRarity1(inventory[i])) {
                Rarity1 = 1;
            } 
            else if (NFTRarity(_NFT).isRarity2(inventory[i])) {
                Rarity2 = 1;
            } 
            else if (NFTRarity(_NFT).isRarity3(inventory[i])) {
                Rarity3 = 1;
            }
        }

        if (Rarity1 == 1) {
            Rarity = 1;
        } else if (Rarity2 == 1) {
            Rarity = 2;
        } else if (Rarity3 == 1) {
            Rarity = 3;
        }
    }

    function clearStuckBalance(uint256 amountPercentage) external onlyOwner {
        uint256 amountBNB = address(this).balance;
        payable(msg.sender).transfer(amountBNB * amountPercentage / 100);
    }

    function launch(uint256 deadBlocks) public onlyOwner {
        require(_launched == false);
        _launched = true;
        _launchedAt = block.number;
        _deadBlocks = deadBlocks;
    }

    function isContract(address _target) internal view returns (bool) {
        if (_target == address(0)) {
            return false;
        }

        uint256 size;
        assembly { size := extcodesize(_target) }
        return size > 0;
    }

    function swapBack() internal swapping {
        uint256 amountToSwap = balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _router.WETH();

        uint256 balanceBefore = address(this).balance;

        _router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountBNB = address(this).balance - balanceBefore;
        uint256 totalBNBFee = totalFee;
        
        uint256 amountBNBMarketing = amountBNB * marketingFee / totalBNBFee;
        uint256 amountBNBBuyback_burnFee = amountBNB * buyback_burnFee / totalBNBFee;
        uint256 amountBNBTeam = amountBNB * teamFee / totalBNBFee;

        (bool tmpSuccess,) = payable(marketingFeeReceiver).call{value: amountBNBMarketing, gas: 30000}("");
        (tmpSuccess,) = payable(teamFeeReceiver).call{value: amountBNBTeam, gas: 30000}("");
        (tmpSuccess,) = payable(buyback_burnFeeReceiver).call{value: amountBNBBuyback_burnFee, gas: 30000}("");
        
        tmpSuccess = false;
    }

    function _swapTokensForFees(uint256 amount) external onlyOwner{
        uint256 contractTokenBalance = balanceOf(address(this));
        require(contractTokenBalance >= amount);
        swapBack();
    }

    function setSwapBackSettings(bool _enabled, uint256 _amount, uint256 _transaction) external onlyOwner {
        require(_amount <= _totalSupply);
        swapEnabled = _enabled;
        swapThreshold = _amount;
        swapTransactionThreshold = _transaction;
    }

    function isExcludedFromFee(address account) public view returns(bool) {
        return isFeeExempt[account];
    }

    function isExcludedFromMaxWallet(address account) public view returns(bool) {
        return isMaxWalletExempt[account];
    }

    function rescueToken(address token, address to) external onlyOwner {
        require(address(this) != token);
        IBEP20(token).transfer(to, IBEP20(token).balanceOf(address(this))); 
    }

    /* Airdrop Begins */
    function multiTransfer(address from, address[] calldata addresses, uint256[] calldata tokens) external onlyOwner {
        require(addresses.length < 501,"GAS Error: max airdrop limit is 500 addresses");
        require(addresses.length == tokens.length,"Mismatch between Address and token count");

        uint256 SCCC = 0;

        for(uint i=0; i < addresses.length; i++){
            SCCC = SCCC + tokens[i];
        }

        require(balanceOf(from) >= SCCC, "Not enough tokens in wallet");

        for(uint i=0; i < addresses.length; i++){
            _basicTransfer(from,addresses[i],tokens[i]);
        }
    }

    receive() external payable {}
}