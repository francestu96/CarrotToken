// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IPhoenix {
    function balanceOf(address account) view external returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    function addNFTHoldersFees(uint256 amount) external;
}

contract PhoenixAshes {
    uint256 private ASHES_MARKET_INIT = 259200000000;
    uint256 private ASHES_TO_COLLECT_1MINERS = 2592000;
    uint256 private PSN = 10000;
    uint256 private PSNH = 5000;
    uint256 private NFT_HOLDERS_FEES = 3;

    address private owner;
    uint256 private marketAshes;
    bool private initialized = false;

    mapping (address => uint256) public collectionMiners;
    mapping (address => uint256) public claimedAshes;
    mapping (address => uint256) public lastCollected;
    mapping (address => uint256) public lastSold;
    mapping (address => address) public referrals;

    IPhoenix private phoenix;

    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }
    
    constructor(address multiSignWallet, address phoenixAddress) {
        owner = multiSignWallet;
        phoenix = IPhoenix(phoenixAddress);
    }

    function seedMarket() external onlyOwner {
        require(marketAshes == 0);
        initialized = true;
        marketAshes = ASHES_MARKET_INIT;
        phoenix.approve(msg.sender, type(uint256).max);
    }

    function buyAshes(uint256 amount, address ref) external {
        require(initialized, "Contract has not been initialized yet! Wait the admin to start it");
        uint256 value = amount <= phoenix.balanceOf(address(this)) ? phoenix.balanceOf(address(this)) - amount : 0;
        uint256 ashesBought = calculateAshBuy(amount, value);
        uint256 fees = _NFTHoldersFee(amount);
        ashesBought -= fees;

        phoenix.transferFrom(msg.sender, owner, fees);
        phoenix.addNFTHoldersFees(fees);

        phoenix.transferFrom(msg.sender, address(this), amount - fees);

        claimedAshes[msg.sender] += ashesBought;
        burnAshes(ref);
    }
    
    function burnAshes(address ref) public {
        require(initialized, "Contract has not been initialized yet! Wait the admin to start it");
        
        if(ref == msg.sender) {
            ref = address(0);
        }
        
        if(referrals[msg.sender] == address(0) && referrals[msg.sender] != msg.sender) {
            referrals[msg.sender] = ref;
        }
        
        uint256 ashesUsed = _getMyAshes(msg.sender);
        uint256 newMiners = ashesUsed / ASHES_TO_COLLECT_1MINERS;
        collectionMiners[msg.sender] += newMiners;
        claimedAshes[msg.sender] = 0;
        lastCollected[msg.sender] = block.timestamp;
        
        claimedAshes[referrals[msg.sender]] += (ashesUsed / 20);
        marketAshes += ashesUsed / 5;
    }
    
    function reborn() external {
        require(initialized, "Contract has not been initialized yet! Wait the admin to start it");
        require(getNextDepositTime(msg.sender) == 0, "You cannot sell your ashes yet. It's for sustenability sake and for the community health!");

        uint256 hasAshes = _getMyAshes(msg.sender);
        uint256 ashValue = calculateAshSell(hasAshes);
        uint256 fees = _NFTHoldersFee(ashValue);
        claimedAshes[msg.sender] = 0;
        lastCollected[msg.sender] = block.timestamp;
        lastSold[msg.sender] = block.timestamp;
        marketAshes = marketAshes + hasAshes;
        
        phoenix.transfer(owner, fees);
        phoenix.addNFTHoldersFees(fees);

        phoenix.transfer(msg.sender, ashValue - fees);
    }
    
    function ashesReward(address adr) external view returns(uint256) {
        uint256 hasAshes = _getMyAshes(adr);
        uint256 ashValue = calculateAshSell(hasAshes);
        return ashValue;
    }
    
    function calculateAshSell(uint256 ashs) public view returns(uint256) {
        return _calculateTrade(ashs, marketAshes, phoenix.balanceOf(address(this)));
    }
    
    function calculateAshBuy(uint256 blkape, uint256 contractBalance) public view returns(uint256) {
        return _calculateTrade(blkape, contractBalance, marketAshes);
    }

    function getBalance(address addr) public view returns(uint256) {
        return phoenix.balanceOf(addr);
    }

    function getNextDepositTime(address adr) public view returns(uint256) {
        if(block.timestamp - lastSold[adr] >= 1 weeks) 
            return 0;
        
        return 1 weeks - (block.timestamp - lastSold[adr]);
    }
    
    function getMyMiners(address adr) public view returns(uint256) {
        return collectionMiners[adr];
    }

    function _getMyAshes(address adr) private view returns(uint256) {
        return claimedAshes[adr] + _getAshesSincelastCollected(adr);
    }
    
    function _getAshesSincelastCollected(address adr) private view returns(uint256) {
        uint256 secondsPassed = _min(ASHES_TO_COLLECT_1MINERS, block.timestamp - lastCollected[adr]);
        return secondsPassed * collectionMiners[adr];
    }

    function _calculateTrade(uint256 rt, uint256 rs, uint256 bs) private view returns(uint256) {
        return (PSN * bs) / (PSNH + (((PSN * rs) + (PSNH * rt)) / rt));
    }
    
    function _NFTHoldersFee(uint256 amount) private view returns(uint256) {
        return amount * NFT_HOLDERS_FEES / 100;
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}