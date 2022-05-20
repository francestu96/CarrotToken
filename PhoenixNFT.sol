contract PhoenixNFT is ERC721, ERC721Enumerable, Ownable, ERC2981PerTokenRoyalties, ERC721Pausable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;

    uint256 public MAX_NFT = 1000;
    uint256 public MAX_BY_MINT = 20;
	uint256 public PRICE = 7 * 10**16;
    uint256 private contractRoyalties = 500;

    event NonFungibleTokenRecovery(address indexed token, uint256 tokenId);
    event TokenRecovery(address indexed token, uint256 amount);
	
    string public baseTokenURI;
    address private _owner;
    string private _rarities = ["common", "rare", "epic", "legendary"];
    private mapping(uint256 => string) _rarity;

    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }
	
    event CreatePhoenixNFT(uint256 indexed id);
	
    constructor(string memory baseURI) ERC721("Phoenix", "PhoenixNFT") {
        setBaseURI(baseURI);
        pause(true);
        _owner = msg.sender;
    }
	
    modifier saleIsOpen {
        require(_totalSupply() <= MAX_NFT, "Sale end");
        if (_msgSender() != owner()) {
            require(!paused(), "Pausable: paused");
        }
        _;
    }
	
    function _totalSupply() internal view returns (uint) {
        return _tokenIdTracker.current();
    }
	
    function totalMint() public view returns (uint256) {
        return _totalSupply();
    }

    function mint(uint256 _count) public payable saleIsOpen {
        uint256 total = _totalSupply();
        require(total + _count <= MAX_NFT, "Max limit");
        require(total <= MAX_NFT, "Sale end");
        require(_count <= MAX_BY_MINT, "Exceeds number");
        require(msg.value >= price(_count), "Value below price");
        for (uint256 i = 0; i < _count; i++) {
            _mintAnElement(msg.sender);
        }
    }
	
    function _mintAnElement(address _to) private {
        uint id = _totalSupply();
        _tokenIdTracker.increment();
        _safeMint(_to, id);
        _setTokenRoyalty(id, owner(), contractRoyalties);
        emit CreatePhoenixNFT(id);
    }

    function Mintforowners(address _to, uint256 _count) external onlyOwner saleIsOpen{
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

        IBEP20(_token).safeTransfer(address(msg.sender), balance);

        emit TokenRecovery(_token, balance);
    }
	
    function price(uint256 _count) public view returns (uint256) {
        return PRICE.mul(_count);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

	function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function walletOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }
	
    function pause(bool val) public onlyOwner {
        if (val == true) {
            _pause();
            return;
        }
        _unpause();
    }
	
	function withdraw(uint256 amount) public onlyOwner {
		uint256 balance = address(this).balance;
        require(balance >= amount);
        _widthdraw(owner(), amount);
    }

    function withdrawAll() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0);
        _widthdraw(owner(), address(this).balance);
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable, ERC2981PerTokenRoyalties) returns (bool) {
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

    function setRarity(uint256[] calldata tokenIds, string rarity) external onlyOwner {
        require(tokenIds.length < 501,"GAS Error: max limit is 500 addresses");

        for (uint256 i; i < tokenIds.length; ++i) {
            _rarity[tokenIds[i]] = status;
        }
    }

    function add_Rarity1(uint256[] calldata tokenids, bool status) external onlyOwner {
        require(tokenids.length < 501,"GAS Error: max limit is 500 addresses");
        for (uint256 i; i < tokenids.length; ++i) {
            Rarity1[tokenids[i]] = status;
        }
    }

    function add_Rarity2(uint256[] calldata tokenids, bool status) external onlyOwner {
        require(tokenids.length < 501,"GAS Error: max limit is 500 addresses");
        for (uint256 i; i < tokenids.length; ++i) {
            Rarity2[tokenids[i]] = status;
        }
    }

    function add_Rarity3(uint256[] calldata tokenids, bool status) external onlyOwner {
        require(tokenids.length < 501,"GAS Error: max limit is 500 addresses");
        for (uint256 i; i < tokenids.length; ++i) {
            Rarity3[tokenids[i]] = status;
        }
    }

    function isRarity1(uint256 tokenid) external view returns (bool) {
        return Rarity1[tokenid];
    }

    function isRarity2(uint256 tokenid) external view returns (bool) {
        return Rarity2[tokenid];
    }

    function isRarity3(uint256 tokenid) external view returns (bool) {
        return Rarity3[tokenid];
    } 
}