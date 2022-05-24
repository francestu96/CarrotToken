// SPDX-License-Identifier: MIT
pragma solidity = 0.8.12;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

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

contract PhoenixNFT is ERC721, ERC721Enumerable, ERC721Royalty, ERC721Pausable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;

    uint256 public MAX_NFT = 1000;
    uint256 public MAX_BY_MINT = 20;
	uint256 public PRICE = 7 * 10**16;
    uint96 private contractRoyalties = 500;
    uint256 private rarityReflectionCounter = 0;

    event NonFungibleTokenRecovery(address indexed token, uint256 tokenId);
    event TokenRecovery(address indexed token, uint256 amount);
	
    string public baseTokenURI;
    address private _owner;
    mapping(uint256 => string) private _rarities;

    modifier onlyOwner {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }
	
    event CreatePhoenixNFT(uint256 indexed id);
	
    constructor(address multiSignWallet, string memory baseURI) ERC721("Phoenix", "PhoenixNFT") {
        setBaseURI(baseURI);
        _pause();
        _owner = multiSignWallet;
    }
	
    modifier saleIsOpen {
        require(_totalSupply() <= MAX_NFT, "Sale end");
        if (_msgSender() != _owner) {
            require(!paused(), "Pausable: paused");
        }
        _;
    }
	
    function totalMint() external view returns (uint256) {
        return _totalSupply();
    }

    function mint(uint8 _count) external payable saleIsOpen {
        uint256 total = _totalSupply();
        require(total + _count <= MAX_NFT, "Max limit");
        require(total <= MAX_NFT, "Sale end");
        require(_count <= MAX_BY_MINT, "Exceeds number");
        require(msg.value >= price(_count), "Value below price");
        for (uint256 i = 0; i < _count; i++) {
            _mintAnElement(msg.sender);
        }
    }
	
    function mintForOwners(address _to, uint256 _count) external onlyOwner saleIsOpen {
       for (uint256 i = 0; i < _count; i++) {
            _mintAnElement(_to);
        }
    }

    function recoverNonFungibleToken(address _token, uint256 _tokenId) external onlyOwner {
        IERC721(_token).transferFrom(address(this), address(msg.sender), _tokenId);

        emit NonFungibleTokenRecovery(_token, _tokenId);
    }
    
    function recoverToken(address _token) external onlyOwner {
        uint256 balance = IBEP20(_token).balanceOf(address(this));
        require(balance != 0, "Operations: Cannot recover zero balance");

        IBEP20(_token).transfer(address(_owner), balance);

        emit TokenRecovery(_token, balance);
    }
	
    function price(uint8 _count) public view returns (uint256) {
        return PRICE * _count;
    }

	function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function getAccountReflection(address addr) external view returns (uint256) {
        uint256 tokenCount = balanceOf(addr);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        string[] memory rarities = new string[](tokenCount);
        uint8 reward = 0;

        for (uint8 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(addr, i);
            rarities[i] = getRarity(tokenIds[i]);

            if(keccak256(abi.encodePacked((rarities[i]))) == keccak256(abi.encodePacked(("legendary"))))
                reward += 40;
            else if(keccak256(abi.encodePacked((rarities[i]))) == keccak256(abi.encodePacked(("epic"))))
                reward += 30;
            else if(keccak256(abi.encodePacked((rarities[i]))) == keccak256(abi.encodePacked(("rare"))))
                reward += 20;
            else
                reward += 10;
        }

        return reward * 1000 / rarityReflectionCounter;
    }
	
    function pause(bool val) external onlyOwner {
        if (val) {
            _pause();
            return;
        }
        _unpause();
    }
	
	function withdraw(uint256 amount) public onlyOwner {
		uint256 balance = address(this).balance;
        require(balance >= amount);
        _widthdraw(_owner, amount);
    }

    function withdrawAll() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0);
        _widthdraw(_owner, address(this).balance);
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable, ERC721Royalty) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
	
	function updatePrice(uint256 newPrice) external onlyOwner {
        PRICE = newPrice;
    }
	
	function updateMintLimit(uint256 newLimit) external onlyOwner {
	    require(MAX_NFT >= newLimit, "Incorrect value");
        MAX_BY_MINT = newLimit;
    }
	
	function updateMaxSupply(uint256 newSupply) external onlyOwner {
	    require(newSupply >= _totalSupply(), "Incorrect value");
        MAX_NFT = newSupply;
    }

    function setRarity(uint256[] calldata tokenIds, string calldata rarity) external onlyOwner {
        require(tokenIds.length < MAX_NFT,"Token ids exceed the maximum amount of NFTs");
        
        bool isRarityValid = false;
        isRarityValid = isRarityValid || (keccak256(abi.encodePacked(rarity)) == keccak256(abi.encodePacked("legendary")));
        isRarityValid = isRarityValid || (keccak256(abi.encodePacked(rarity)) == keccak256(abi.encodePacked("rare")));
        isRarityValid = isRarityValid || (keccak256(abi.encodePacked(rarity)) == keccak256(abi.encodePacked("epic")));
        isRarityValid = isRarityValid || (keccak256(abi.encodePacked(rarity)) == keccak256(abi.encodePacked("common")));
        require(isRarityValid, "Rarity value must be 'common', 'rare', 'epic' or 'legendary'");

        for (uint16 i = 0; i < tokenIds.length; i++){
            _rarities[tokenIds[i]] = rarity;
        }
    }

    function getRarity(uint256 tokenId) public view returns (string memory) {
        return _rarities[tokenId];
    }


    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721Royalty, ERC721) {
        super._burn(tokenId);
    }


    function _totalSupply() private view returns (uint) {
        return _tokenIdTracker.current();
    }

    function _mintAnElement(address _to) private {
        uint id = _totalSupply();
        _tokenIdTracker.increment();
        _safeMint(_to, id);
        _setTokenRoyalty(id, _owner, contractRoyalties);

        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp + block.difficulty + ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (block.timestamp)) + block.gaslimit +  ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (block.timestamp)) + block.number)));
        uint256 rand = seed % 10;
        if(rand < 4){
            rarityReflectionCounter += 10;
            _rarities[id] = "common";
        }
        else if(rand < 7){
            rarityReflectionCounter += 20;
            _rarities[id] = "rare";
        }
        else if(rand < 9){
            rarityReflectionCounter += 30;
            _rarities[id] = "epic";
        }
        else{
            rarityReflectionCounter += 40;
            _rarities[id] = "legendary";
        }

        emit CreatePhoenixNFT(id);
    }

}