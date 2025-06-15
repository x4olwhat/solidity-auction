// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title SimpleAuction
/// @dev A basic auction contract with ownership control and reentrancy protection
/// @notice Only the owner can end the auction prematurely
/// @notice Uses ReentrancyGuard to secure withdrawals against reentrancy attacks.
contract SimpleAuction is Ownable(msg.sender), ReentrancyGuard {

    error AccessDenied();
    error AuctionStateInvalid();
    error InvalidBid();
    error NoBids();
    error WinnerCannotWithdraw();
    error TransferFailed();

    event BidPlaced(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);
    event Withdrawn(address bidder, uint amount);

    bool public isAuctionEnded;

    uint256 public highestBid;
    uint256 public endTime;

    address public winner;
    address public highestBidder;

    string public prize;
    
    mapping(address => uint256) public bids;

    constructor(string memory _prize, uint256 _biddingTimeSeconds){
        prize = _prize;
        endTime = block.timestamp + _biddingTimeSeconds;
    }

    /// @notice Places a bid in the auction
    /// @dev Bids must be higher than the current highest bid before the auction ends
    /// @custom:error AuctionStateInvalid If the auction has ended
    /// @custom:error InvalidBid If the bid is not higher than the current highest bid
    function bid() external payable {
        require(block.timestamp < endTime, AuctionStateInvalid());
        require(msg.value > highestBid, InvalidBid());

        highestBid = msg.value;
        highestBidder = msg.sender;

        bids[msg.sender] += msg.value;

        emit BidPlaced(msg.sender, msg.value);
    }

    /// @notice Ends the acution and declares the winner 
    /// @dev Can only be called by the contract owner
    /// @dev Can only be called after the auction end time
    /// @custom:error AuctionStateInvalid If the auction is either not finished yet or has already been ended
    function endAuction() external onlyOwner{
        require(block.timestamp > endTime, AuctionStateInvalid());
        require(!isAuctionEnded, AuctionStateInvalid());

        winner = highestBidder;
        isAuctionEnded = true;

        emit AuctionEnded(winner, bids[winner]);
    }

    /// @notice Allows non-winner bidders to withdraw their bid amounts
    /// @dev Prevents reentrancy attacks using nonReentrant modifier
    /// @dev Only allowed after the auction has ended
    /// @dev Winning bidder cannot withdraw
    /// @dev Emits a Withdraw event on success
    /// @custom:error AuctionStateInvalid If auction is not ended
    /// @custom:error NoBids If caller has no bids to withdraw
    /// @custom:error AcessDenied If the winner tries the refund fails
    function withdraw() external nonReentrant {
        require(isAuctionEnded, AuctionStateInvalid());
        require(bids[msg.sender] > 0, NoBids());
        require(msg.sender != winner, AccessDenied());

        uint256 refundAmount = bids[msg.sender];

        bids[msg.sender] = 0;

        (bool sent, ) = payable(msg.sender).call{ value: refundAmount}("");
        require(sent, TransferFailed());

        emit Withdrawn(msg.sender, refundAmount);
    }

    /// @notice Allows the winner to claim the prize desctiption
    /// @dev Only callable by the highest bidder after auction ended
    /// @custom:error AcessDenied If caller is not the winner or auction not ended
    function claimPrize() external view returns(string memory){
        require(msg.sender == highestBidder && isAuctionEnded, AccessDenied());
        return(prize);
    }
}
