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
    uint256 private SKULLS_MARKET_INIT = 259200000000;
    uint256 private SKULLS_TO_COLLECT_1MINERS = 2592000;
    uint256 private PSN = 10000;
    uint256 private PSNH = 5000;
    uint256 private NFT_HOLDERS_FEES = 3;

    address private owner;
    uint256 private marketSkulls;
    bool private initialized = false;

    mapping (address => uint256) public collectionMiners;
    mapping (address => uint256) public claimedSkulls;
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

    function seedMarket() public onlyOwner {
        require(marketSkulls == 0);
        initialized = true;
        marketSkulls = SKULLS_MARKET_INIT;
        phoenix.approve(msg.sender, type(uint256).max);
    }

    function buySkulls(uint256 amount, address ref) public {
        require(initialized, "Contract has not been initialized yet! Wait the admin to start it");
        uint256 value = amount <= phoenix.balanceOf(address(this)) ? phoenix.balanceOf(address(this)) - amount : 0;
        uint256 skullsBought = calculateSkullBuy(amount, value);
        uint256 fees = _NFTHoldersFee(amount);
        skullsBought -= fees;

        phoenix.transferFrom(msg.sender, owner, fees);
        phoenix.addNFTHoldersFees(fees);

        phoenix.transferFrom(msg.sender, address(this), amount - fees);

        claimedSkulls[msg.sender] += skullsBought;
        burySkulls(ref);
    }
    
    function burySkulls(address ref) public {
        require(initialized, "Contract has not been initialized yet! Wait the admin to start it");
        
        if(ref == msg.sender) {
            ref = address(0);
        }
        
        if(referrals[msg.sender] == address(0) && referrals[msg.sender] != msg.sender) {
            referrals[msg.sender] = ref;
        }
        
        uint256 skullsUsed = _getMySkulls(msg.sender);
        uint256 newMiners = skullsUsed / SKULLS_TO_COLLECT_1MINERS;
        collectionMiners[msg.sender] += newMiners;
        claimedSkulls[msg.sender] = 0;
        lastCollected[msg.sender] = block.timestamp;
        
        claimedSkulls[referrals[msg.sender]] += (skullsUsed / 20);
        marketSkulls += skullsUsed / 5;
    }
    
    function sellSkulls() public {
        require(initialized, "Contract has not been initialized yet! Wait the admin to start it");
        require(getNextDepositTime(msg.sender) == 0, "You cannot sell your skulls yet. It's for sustenability sake and for the community health!");

        uint256 hasSkulls = _getMySkulls(msg.sender);
        uint256 skullValue = calculateSkullSell(hasSkulls);
        uint256 fees = _NFTHoldersFee(skullValue);
        claimedSkulls[msg.sender] = 0;
        lastCollected[msg.sender] = block.timestamp;
        lastSold[msg.sender] = block.timestamp;
        marketSkulls = marketSkulls + hasSkulls;
        
        phoenix.transfer(owner, fees);
        phoenix.addNFTHoldersFees(fees);

        phoenix.transfer(msg.sender, skullValue - fees);
    }
    
    function skullRewards(address adr) public view returns(uint256) {
        uint256 hasSkulls = _getMySkulls(adr);
        uint256 skullValue = calculateSkullSell(hasSkulls);
        return skullValue;
    }
    
    function calculateSkullSell(uint256 skulls) public view returns(uint256) {
        return _calculateTrade(skulls, marketSkulls, phoenix.balanceOf(address(this)));
    }
    
    function calculateSkullBuy(uint256 blkape, uint256 contractBalance) public view returns(uint256) {
        return _calculateTrade(blkape, contractBalance, marketSkulls);
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

    function _getMySkulls(address adr) private view returns(uint256) {
        return claimedSkulls[adr] + _getSkullsSincelastCollected(adr);
    }
    
    function _getSkullsSincelastCollected(address adr) private view returns(uint256) {
        uint256 secondsPassed = _min(SKULLS_TO_COLLECT_1MINERS, block.timestamp - lastCollected[adr]);
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