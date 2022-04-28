// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

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

contract ApeSkulls {
    // roastedbeef.io: 10% BnB
    // 86 400 000 000
    //        864 000
    
    // rocket-game.io: 10% busdt
    //  86 400 000 000
    //         864 000

    // BNB Miner: 3% BnB
    // 259 200 000 000
    //       2 592 000
    
    // marketSkulls              = 108 000 000 000
    // SKULLS_TO_COLLECT_1MINERS =       1 080 000  = marketSkulls / 10^5
    // PSN                       =          10 000  = SKULLS_TO_COLLECT_1MINERS / 10^2+8
    // PSNH                      =           5 000  = PSN / 2

    uint256 private SKULLS_MARKET_INIT = 259200000000;
    uint256 private SKULLS_TO_COLLECT_1MINERS = 2592000;
    uint256 private PSN = 10000;
    uint256 private PSNH = 5000;
    uint256 private DEV_FEES = 5;

    address private owner;
    uint256 private marketSkulls;
    bool private initialized = false;

    mapping (address => uint256) private collectionMiners;
    mapping (address => uint256) private claimedSkulls;
    mapping (address => uint256) private lastCollected;
    mapping (address => address) private referrals;

    IBEP20 private blackApe;

    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }
    
    constructor(address blackApeAddress) {
        owner = msg.sender;
        blackApe = IBEP20(blackApeAddress);
    }

    function seedMarket() public onlyOwner {
        require(marketSkulls == 0);
        initialized = true;
        marketSkulls = SKULLS_MARKET_INIT;
    }

    function buySkulls(uint256 amount, address ref) public {
        require(initialized, "Contract has not been initialized yet! Wait the admin to start it");
        uint256 skullsBought = calculateSkullBuy(amount, blackApe.balanceOf(address(this)) - amount);
        uint256 fees = _devFee(amount);
        skullsBought = skullsBought - fees;
        blackApe.transfer(owner, fees);
        claimedSkulls[msg.sender] = claimedSkulls[msg.sender] + skullsBought;
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
        
        uint256 skullsUsed = getMySkulls(msg.sender);
        uint256 newMiners = skullsUsed / SKULLS_TO_COLLECT_1MINERS;
        collectionMiners[msg.sender] = collectionMiners[msg.sender] + newMiners;
        claimedSkulls[msg.sender] = 0;
        lastCollected[msg.sender] = block.timestamp;
        
        claimedSkulls[referrals[msg.sender]] = claimedSkulls[referrals[msg.sender]] + (skullsUsed / 10);
        marketSkulls = marketSkulls + (skullsUsed / 5);
    }
    
    function sellSkulls() public {
        require(initialized, "Contract has not been initialized yet! Wait the admin to start it");
        require(getNextDepositTime(msg.sender) == 0, "You cannot sell your skulls yet. It's for sustenability sake and for the community health!");

        uint256 hasSkulls = getMySkulls(msg.sender);
        uint256 skullValue = calculateSkullSell(hasSkulls);
        uint256 fees = _devFee(skullValue);
        claimedSkulls[msg.sender] = 0;
        lastCollected[msg.sender] = block.timestamp;
        marketSkulls = marketSkulls + hasSkulls;
        blackApe.transfer(owner, fees);
        blackApe.transfer(msg.sender, skullValue - fees);
    }
    
    function skullRewards(address adr) public view returns(uint256) {
        uint256 hasSkulls = getMySkulls(adr);
        uint256 skullValue = calculateSkullSell(hasSkulls);
        return skullValue;
    }
    
    function calculateSkullSell(uint256 skulls) public view returns(uint256) {
        return _calculateTrade(skulls, marketSkulls, blackApe.balanceOf(address(this)));
    }
    
    function calculateSkullBuy(uint256 bnb, uint256 contractBalance) public view returns(uint256) {
        return _calculateTrade(bnb, contractBalance, marketSkulls);
    }
    
    function calculateSkullBuySimple(uint256 bnb) public view returns(uint256) {
        return calculateSkullBuy(bnb, blackApe.balanceOf(address(this)));
    }
    
    function getBalance() public view returns(uint256) {
        return blackApe.balanceOf(address(this));
    }

    function getNextDepositTime(address adr) public view returns(uint256) {
        if(block.timestamp - lastCollected[adr] >= 1 weeks) 
            return 0;
        
        return 1 weeks - (block.timestamp - lastCollected[adr]);
    }
    
    function getMyMiners(address adr) public view returns(uint256) {
        return collectionMiners[adr];
    }
    
    function getMySkulls(address adr) public view returns(uint256) {
        return claimedSkulls[adr] + getSkullsSincelastCollected(adr);
    }
    
    function getSkullsSincelastCollected(address adr) public view returns(uint256) {
        uint256 secondsPassed = _min(SKULLS_TO_COLLECT_1MINERS, block.timestamp - lastCollected[adr]);
        return secondsPassed * collectionMiners[adr];
    }

    function _calculateTrade(uint256 rt, uint256 rs, uint256 bs) private view returns(uint256) {
        return (PSN * bs) / (PSNH + (((PSN * rs) + (PSNH * rt)) / rt));
    }
    
    function _devFee(uint256 amount) private view returns(uint256) {
        return amount * DEV_FEES / 100;
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}