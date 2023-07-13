//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @title Market Place Assignment
 * @author Avinash Jain
 */
contract MarketPlace {
    /**
     * @dev emitted when assest sale is created
     * @param seller : token owner
     * @param id : token id to sell
     * @param pricePerToken : price per token given by seller
     */
    event AssestSaleCreated(
        address indexed seller,
        uint256 indexed id,
        uint256 indexed pricePerToken
    );

    /**
     * @dev emitted when someone buy token registered to sale
     * @param buyer : buyer address of token
     * @param seller : seller of token
     * @param id : token id to buy
     * @param amountPaid : amount paid by buyer for token
     * @param totalSold : number of token brought
     * @param _contract : contract address of token
     */
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
    mapping(address => mapping(address => mapping(uint256 => SaleAssest)))
        private saleAssest;
    struct SaleAssest {
        uint256 numberToSell;
        uint256 pricePerToken;
        address acceptableERC20;
        bool isERC721;
    }

    /**
     * @dev set value of owner of contract
     */
    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "MarketPlace: Only contract owner can withdraw."
        );
        _;
    }
    modifier nonZeroToken(uint256 _numberToSell) {
        require(
            _numberToSell > 0,
            "MarketPlace: Number of token to sell or buy should be greater than zero."
        );
        _;
    }

    /**
     * @dev allow token owner to register their ERC1155 token for sale
     * Requirement -
     *         number of token to sell must be greater than zero
     *         number of token register to sale must be less than equal to token owner by seller
     * @param ERC1155Contract : contract address of token
     * @param _tokenId : id of tokens to sale
     * @param _numberToSell : number of ERC1155 token to sell
     * @param _price : price per token
     * @param _acceptableERC20 : acceptable address of ERC20 as payment
     */
    function saleForERC1155(
        address ERC1155Contract,
        uint256 _tokenId,
        uint256 _numberToSell,
        uint256 _price,
        address _acceptableERC20
    ) external nonZeroToken(_numberToSell) {
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

    /**
     * @dev allow token owner to register their ERC721 token to sale
     * Requirement -
     *          Seller must own the token he is registering to sale
     * @param ERC721Contract : contract address of token
     * @param _tokenId : token id to sale
     * @param _price : price of token
     * @param _acceptableERC20 : address of ERC20 token as payment
     */
    function saleForERC721(
        address ERC721Contract,
        uint256 _tokenId,
        uint256 _price,
        address _acceptableERC20
    ) external {
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

    /**
     * @dev return the price of token by its id
     * Requirement -
     *         to check the price of token it must first be registered to sale
     * @param _seller : seller address of token
     * @param _contract : contract address of token
     * @param tokenId : id of token
     * @return uint256 price of token
     */
    function pricePerTokenId(
        address _seller,
        address _contract,
        uint256 tokenId
    ) external view returns (uint256) {
        SaleAssest memory tokenSale = saleAssest[_seller][_contract][tokenId];
        require(
            tokenSale.numberToSell > 0,
            "MarketPlace: Token is not registered for sales."
        );
        return saleAssest[_seller][_contract][tokenId].pricePerToken;
    }

    /**
     * @dev Buyer can buy ERC721 token registered to sale
     * Requirement -
     *          Token to buy must be registered to sale
     *          address must be ERC721 contract
     * @param _seller : seller of ERC721 token
     * @param _contract : contract address of token
     * @param _tokenId : id of token
     * Emit a {AssestSold} event
     */
    function buyERC721Assest(
        address _seller,
        address _contract,
        uint256 _tokenId
    ) external payable {
        SaleAssest memory tokenSale = saleAssest[_seller][_contract][_tokenId];
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
                _seller,
                tokenSale.pricePerToken - contractCommision
            );
        } else {
            _ethTransfer(tokenSale.pricePerToken, contractCommision, _seller);
        }
        token721.safeTransferFrom(_seller, msg.sender, _tokenId);
        emit AssestSold(
            msg.sender,
            _seller,
            _tokenId,
            tokenSale.pricePerToken,
            1,
            _contract
        );
        delete saleAssest[_seller][_contract][_tokenId];
    }

    /**
     * @dev Buyer can buy ERC1155 token registered to sale
     * Requirement -
     *         Token to buy must be greater than zero
     *         Token to buy must be registered to sale
     *         address must be ERC1155 contract
     *         Cannot buy more than token registeted to sale
     * @param _seller : Seller address of token
     * @param _contract : contract address of token
     * @param _tokenId : id of token
     * @param tokenToBuy : no of token to buy
     * Emit a {AssestSold} event
     */
    function buyERC1155Assest(
        address _seller,
        address _contract,
        uint256 _tokenId,
        uint256 tokenToBuy
    ) external payable nonZeroToken(tokenToBuy) {
        SaleAssest memory tokenSale = saleAssest[_seller][_contract][_tokenId];
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
            token20.transfer(_seller, totalPayRequired - contractCommision);
        } else {
            _ethTransfer(totalPayRequired, contractCommision, _seller);
        }
        token1155.safeTransferFrom(
            _seller,
            msg.sender,
            _tokenId,
            tokenToBuy,
            ""
        );
        emit AssestSold(
            msg.sender,
            _seller,
            _tokenId,
            totalPayRequired,
            tokenToBuy,
            _contract
        );
        if (tokenSale.numberToSell == tokenToBuy) {
            delete saleAssest[_seller][_contract][_tokenId];
        } else {
            saleAssest[_seller][_contract][_tokenId].numberToSell =
                tokenSale.numberToSell -
                tokenToBuy;
        }
    }

    /**
     * dev Contract onwer can withdraw commission earned from sales
     * Requirement -
     *         Only owner of contract can withdraw
     */
    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    /**
     * @dev internal function to register sale
     * @param _contract : contract address of token
     * @param _tokenId : id of token
     * @param _numberToSell : number of token to sell
     * @param _price : price per token
     * @param _acceptableERC20 : acceptable ERC20 token as payment
     * @param flag : is ERC721 token
     * Emit a {AssestSaleCreated} event
     */
    function _saleCreation(
        address _contract,
        uint256 _tokenId,
        uint256 _numberToSell,
        uint256 _price,
        address _acceptableERC20,
        bool flag
    ) internal {
        saleAssest[msg.sender][_contract][_tokenId] = SaleAssest(
            _numberToSell,
            _price,
            _acceptableERC20,
            flag
        );
        emit AssestSaleCreated(msg.sender, _tokenId, _price);
    }

    /**
     * @dev internal function to pay for token in eth
     * @param _totalPayRequired : total pay required to buy token
     * @param _contractCommision : commision earned by contract
     * @param _seller : seller of token
     */
    function _ethTransfer(
        uint256 _totalPayRequired,
        uint256 _contractCommision,
        address _seller
    ) internal {
        require(
            msg.value >= _totalPayRequired,
            "MarketPlace: Not enough value to buy assest."
        );
        payable(address(this)).transfer(_contractCommision);
        payable(_seller).transfer(_totalPayRequired - _contractCommision);
    }
}
