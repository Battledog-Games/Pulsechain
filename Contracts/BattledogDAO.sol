// SPDX-License-Identifier: MIT license

// @title BattledogDAO by OxSorcerers for Pulsedoges.fun
// https://twitter.com/0xSorcerers | https://github.com/Dark-Viper | https://t.me/Oxsorcerer | https://t.me/battousainakamoto | https://t.me/darcViper

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Interface for the IFarmer contract
interface IPulseHarvester {
    // Struct for rewards claim
    struct Claim {
        uint256 eraAtBlock;
        uint256 dropSent;
        uint256 rewardsOwed;
    }
    function claimRewards(address) external returns (Claim[] memory);
}

// interface IBattledog {
//     struct Player {
//         string name;
//         uint256 id;
//         uint256 level;
//         uint256 attack;
//         uint256 defence;
//         uint256 fights;
//         uint256 wins;
//         uint256 payout;
//         uint256 activate;
//         uint256 history;
//     }

//     function getPlayers() external view returns (Player[] memory);
//     function getPlayerOwners(address _user) external returns (Player[] memory);
// }


//     // Timer for the voting
//     uint256 public votingTimer;

//     // Map to store the tokenId and its timestamp
//     mapping (uint256 => uint256) public tokenTimestamp;

//     // Global YAY and NAY votes
//     uint256 public YAYVotes;
//     uint256 public NAYVotes;

//     // Result of the vote
//     string public VotePassed;

//     // Proof of Game function
//     function  ProofOfGame(bytes32 vote, uint256 tokenId) public onlyOwner {
//         require(vote == bytes32("YES") || vote == bytes32("NO"), "Invalid.");
//         require(tokenTimestamp[tokenId] == 0, "Duplicate");
//         require(block.timestamp >= votingTimer, "Not Required.");

//         Player memory nft = players[tokenId];

//         uint256 totalVotes = nft.level + nft.fights + nft.wins + nft.hatch + nft.history + (nft.attack / 100) + (nft.defence / 100);
        
//         if (vote == bytes32("YES")) {
//             YAYVotes += totalVotes;
//         } else {
//             NAYVotes += totalVotes;
//         }
        
//         tokenTimestamp[tokenId] = block.timestamp;
//     }

//     // Function to reset the voting process
//     function resetVoting() public onlyOwner {
//         YAYVotes = 0;
//         NAYVotes = 0;
//         VotePassed = "";
//         uint256 total = totalSupply();
//         for (uint256 i = 0; i < total; i++) {
//             tokenTimestamp[i] = 0;
//         }
//         votingTimer = 0;
//     }

//     // Function to start the voting process
//     function startVoting(uint256 _votingTimer) public onlyOwner {
//         votingTimer = block.timestamp + _votingTimer;
//         resetVoting();
//     }

//     // Function to end the voting process and determine the result
//     function endVoting() public onlyOwner {
//         require(block.timestamp >= votingTimer, "Not Ended.");
//         if (YAYVotes > NAYVotes) {
//         VotePassed = "PASSED";
//         } else {
//         VotePassed = "NOT PASSED";
//         }
//     } 

contract BattledogDAO is Ownable, ReentrancyGuard {        
    constructor(address _harvester, address _newGuard) {
        harvester = _harvester;
        guard = _newGuard;
    }

    using ABDKMath64x64 for uint256;    
    using SafeERC20 for IERC20;  
    using Strings for uint256;

    modifier onlyGuard() {
        require(msg.sender == guard, "Not authorized.");
        _;
    }

    // Timer for the voting
    uint256 public votingTimer;
    uint256 public totalVotes;
    uint256 public registeredVoters;
    address public harvester;
    address public guard;
    bool public state;

    // YAY and NAY votes by participant
    mapping(address => bool) public votes;
    // Map of registered voters
    mapping(address => bool) public votersRegistered;
    // Array of addresses that have voted in the current voting cycle
    address[] public dropVoters;

    // Global YAY and NAY votes
    uint256 public Yay;
    uint256 public Nay;

    // Result of the vote
    bool public VotePassed;

    // Function to reset the voting process
    function resetVoting() external onlyOwner {
        Yay = 0;
        Nay = 0;
        VotePassed = false;
        for (uint256 i = 0; i < dropVoters.length; i++) {
            delete votersRegistered[dropVoters[i]];
        }
        delete dropVoters;
        votingTimer = 0;
    }

    // Proof of Farming Voting
    function ProofOfFarm(uint256 voteId) public nonReentrant {
        require(!state, "Vote is already paused.");
        require(voteId == 0 || voteId == 1, "Invalid Vote");
        require(votersRegistered[msg.sender] == false, "Voter has already voted");
        votersRegistered[msg.sender] = true;

    // Get the dropSent owned by the msg.sender
    IPulseHarvester.Claim[] memory claimers = IPulseHarvester(harvester).claimRewards(msg.sender);    
        uint256 vote = 0;
        for (uint256 i = 0; i < claimers.length; i++) {
            vote += claimers[i].dropSent / 100 ether;
        }

        if (voteId == 1) {
            Yay += vote;           
        } else {
            Nay += vote;
        }

        totalVotes += vote;
        ++registeredVoters;
        dropVoters.push(msg.sender);
    }

    // Function to start the voting process
    function startVoting(uint256 _votingTimer) external onlyOwner {
        votingTimer = block.timestamp + _votingTimer;
        open();
    }

    // Function to end the voting process and determine the result
    function endVoting() external onlyOwner {
        require(!state, "Vote is already paused.");
        require(block.timestamp >= votingTimer, "Not Ended.");
        if (Yay > Nay) {
        VotePassed = true;
        } else {
        VotePassed = false;
        }
        close();
    } 

    function close() public onlyGuard {
        require(msg.sender == owner(), "Only Deployer.");
        require(!state, "Vote is already paused.");
        state = true;
    }

    function open() public onlyGuard {
        require(msg.sender == owner(), "Only Deployer.");
        require(state, "Vote is not paused.");
        state = false;
    }

    function setGuard (address _newGuard) external onlyGuard {
        guard = _newGuard;
    }
}
