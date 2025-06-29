// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EventTicket} from "./EventTicket.sol";

contract Marketplace {
    // mapping ()

    struct Listing {
        address collectionAddress;
        uint256 tokenId;
        address seller;
        uint256 amount;
    }

    error Marketplace__NotOwner();
    error Marketplace__NotApproved();

    function listTicket(
        address collectionAddress,
        uint256 tokenId,
        uint256 amount
    ) public {
        EventTicket collection = EventTicket(collectionAddress);
        if (msg.sender != collection.ownerOf(tokenId))
            revert Marketplace__NotOwner();
        if (
            collection.getApproved(tokenId) != address(this) &&
            collection.isApprovedForAll(msg.sender, address(this)) != true
        ) revert Marketplace__NotApproved();
        //checks
    }

    function approveMarketplaceForToken(
        uint256 tokenId,
        address collectionAddress
    ) public {
        EventTicket collection = EventTicket(collectionAddress);
        if (msg.sender != collection.ownerOf(tokenId))
            revert Marketplace__NotOwner();
        collection.approve(address(this), tokenId);
    }

    function approveMarketplaceForAll(address collectionAddress) public {
        EventTicket collection = EventTicket(collectionAddress);
        collection.setApprovalForAll(address(this), true);
    }
}
