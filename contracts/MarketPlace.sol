//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract MarketPlace {
    event AssestSaleCreated(
        address indexed seller,
        uint256 indexed id,
        uint256 indexed pricePerToken
    );

    event AssestSold(
        address indexed buyer,
        address indexed seller,
        uint256 indexed id,
        uint256 amountPaid,
        uint256 totalSold,
        address _contract
    );

    address owner;
    IERC1155 token1155;
    IERC721 token721;
    IERC20 token20;
    // only a single user can sell a single id token in ERC1155
    mapping(address => mapping(uint256 => SaleAssest)) private saleAssest;
    struct SaleAssest {
        address seller;
        uint256 numberToSell;
        uint256 pricePerToken;
        address acceptableERC20;
        bool isERC721;
    }

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "ERC721Token: Only owner can mint.");
        _;
    }
    modifier nonZeroToken(uint256 _numberToSell) {
        require(
            _numberToSell > 0,
            "MarketPlace: Number of token to sell or buy should be greater than zero."
        );
        _;
    }
    modifier salesExist(address _contract, uint256 _tokenId) {
        require(
            saleAssest[_contract][_tokenId].numberToSell > 0,
            "MarketPlace: Token is not registered for sales."
        );
        _;
    }

    function saleForERC1155(
        address ERC1155Contract,
        uint256 _tokenId,
        uint256 _numberToSell,
        uint256 _price,
        address _acceptableERC20
    ) external nonZeroToken(_numberToSell) {
        require(
            _acceptableERC20 != address(0),
            "MarketPlace: Acceptable ERC20 contract address is invalid."
        );
        token1155 = IERC1155(ERC1155Contract);
        require(
            token1155.balanceOf(msg.sender, _tokenId) >= _numberToSell,
            "MarketPlace: Seller do not have enough token amount to sale."
        );
        _saleCreation(
            ERC1155Contract,
            _tokenId,
            _numberToSell,
            _price,
            _acceptableERC20,
            false
        );
    }

    function saleForERC721(
        address ERC721Contract,
        uint256 _tokenId,
        uint256 _price,
        address _acceptableERC20
    ) external {
        require(
            _acceptableERC20 != address(0),
            "MarketPlace: Acceptable ERC20 contract address is invalid."
        );
        token721 = IERC721(ERC721Contract);

        require(
            token721.ownerOf(_tokenId) == msg.sender,
            "MarketPlace: Seller does not own this NFT."
        );
        _saleCreation(
            ERC721Contract,
            _tokenId,
            1,
            _price,
            _acceptableERC20,
            true
        );
    }

    function pricePerTokenId(
        address _contract,
        uint256 tokenId
    ) external view salesExist(_contract, tokenId) returns (uint256) {
        return saleAssest[_contract][tokenId].pricePerToken;
    }

    function buyERC721Assest(
        address _contract,
        uint256 _tokenId
    ) external payable {
        SaleAssest memory tokenSale = saleAssest[_contract][_tokenId];
        require(
            tokenSale.numberToSell > 0,
            "MarketPlace: Token is not registered for sales."
        );
        require(
            tokenSale.isERC721 == true,
            "MarketPlace: Contract address is not ERC721 token."
        );
        token721 = IERC721(_contract);
        uint256 contractCommision = (55 * tokenSale.pricePerToken) / (10000);
        if (tokenSale.acceptableERC20 != address(0)) {
            token20 = IERC20(tokenSale.acceptableERC20);

            token20.transferFrom(
                msg.sender,
                address(this),
                tokenSale.pricePerToken
            );
            token20.transfer(
                tokenSale.seller,
                tokenSale.pricePerToken - contractCommision
            );
        } else {
            // msg.value check
            payable(tokenSale.seller).transfer(
                tokenSale.pricePerToken - contractCommision
            );
        }
        token721.safeTransferFrom(tokenSale.seller, msg.sender, _tokenId);
        emit AssestSold(
            msg.sender,
            tokenSale.seller,
            _tokenId,
            tokenSale.pricePerToken,
            1,
            _contract
        );
        delete saleAssest[_contract][_tokenId];
    }

    function buyERC1155Assest(
        address _contract,
        uint256 _tokenId,
        uint256 tokenToBuy
    ) external payable nonZeroToken(tokenToBuy) {
        SaleAssest memory tokenSale = saleAssest[_contract][_tokenId];
        require(
            tokenSale.numberToSell > 0,
            "MarketPlace: Token is not registered for sales."
        );
        require(
            tokenSale.isERC721 == false,
            "MarketPlace: Contract address is not ERC1155 token."
        );
        require(
            tokenToBuy <= tokenSale.numberToSell,
            "MarketPlace: Cannot buy more than token listed to sale."
        );
        token1155 = IERC1155(_contract);
        uint256 totalPayRequired = tokenSale.pricePerToken * tokenToBuy;
        uint256 contractCommision = (55 * totalPayRequired) / (10000);
        if (tokenSale.acceptableERC20 != address(0)) {
            token20 = IERC20(tokenSale.acceptableERC20);

            token20.transferFrom(msg.sender, address(this), totalPayRequired);
            token20.transfer(
                tokenSale.seller,
                totalPayRequired - contractCommision
            );
        } else {
            // msg.value check
            payable(tokenSale.seller).transfer(
                totalPayRequired - contractCommision
            );
        }
        token1155.safeTransferFrom(
            tokenSale.seller,
            msg.sender,
            _tokenId,
            tokenToBuy,
            ""
        );
        emit AssestSold(
            msg.sender,
            tokenSale.seller,
            _tokenId,
            totalPayRequired,
            tokenToBuy,
            _contract
        );
        if (tokenSale.numberToSell == tokenToBuy) {
            delete saleAssest[_contract][_tokenId];
        } else {
            saleAssest[_contract][_tokenId].numberToSell =
                tokenSale.numberToSell -
                tokenToBuy;
        }
    }

    // function withdraw() external onlyOwner {}

    function _saleCreation(
        address _contract,
        uint256 _tokenId,
        uint256 _numberToSell,
        uint256 _price,
        address _acceptableERC20,
        bool flag
    ) internal {
        saleAssest[_contract][_tokenId] = SaleAssest(
            msg.sender,
            _numberToSell,
            _price,
            _acceptableERC20,
            flag
        );
        emit AssestSaleCreated(msg.sender, _tokenId, _price);
    }
}
