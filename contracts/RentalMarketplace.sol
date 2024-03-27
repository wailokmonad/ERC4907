// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ERC4907.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract RentalMarketplace is ReentrancyGuard {

    struct RentalOffer {
        address payable owner;   // Owner of the NFT
        uint256 price;           // Price for renting the NFT
        uint64 duration;         // Duration of the rental in seconds
    }

    mapping(ERC4907 => mapping(uint256 => RentalOffer)) public rentalOffers;

    event RentalOfferCreated(ERC4907 indexed nftContract, uint256 indexed tokenId, address indexed owner, uint256 price, uint64 duration);
    event RentalOfferCancelled(ERC4907 indexed nftContract, uint256 indexed tokenId);
    event Rented(ERC4907 indexed nftContract, uint256 indexed tokenId, address indexed renter, uint256 pricePaid, uint64 duration);

    constructor() { }


    function createRentalOffer(ERC4907 nftContract, uint256 tokenId, uint256 price, uint64 duration) external {

        require(nftContract.ownerOf(tokenId) == msg.sender, "Only the owner can create a rental offer");
        require(price > 0, "Price must be greater than zero");
        require(duration > 0, "Duration must be greater than zero");

        rentalOffers[nftContract][tokenId] = RentalOffer({
            owner: payable(msg.sender),
            price: price,
            duration: duration
        });

        emit RentalOfferCreated(nftContract, tokenId, msg.sender, price, duration);
    }


    function cancelRentalOffer(ERC4907 nftContract, uint256 tokenId) external {
        RentalOffer memory offer = rentalOffers[nftContract][tokenId];
        require(offer.owner == msg.sender, "Only the owner can cancel the rental offer");

        delete rentalOffers[nftContract][tokenId];

        emit RentalOfferCancelled(nftContract, tokenId);
    }


    function rent(ERC4907 nftContract, uint256 tokenId) external nonReentrant payable {
        RentalOffer memory offer = rentalOffers[nftContract][tokenId];
        require(offer.owner != address(0), "This token is not for rent");
        require(offer.owner == nftContract.ownerOf(tokenId), "Ownership for this token has changed, need to create a new offer");
        require(msg.value >= offer.price, "Insufficient payment");

        delete rentalOffers[nftContract][tokenId];

        (bool sent,) = offer.owner.call{value: offer.price}("");
        require(sent, "Failed to send Ether");

        nftContract.setUser(tokenId, msg.sender, uint64(block.timestamp + offer.duration));
        
        emit Rented(nftContract, tokenId, msg.sender, offer.price, offer.duration);
    }

}