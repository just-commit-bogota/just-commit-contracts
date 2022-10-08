// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract CommitManager {
  // global history of commits
  Commit[] commits;
  // global counter for uniquely identifying commits
  uint256 totalCommits;

  // a NewCommit takes in:
  // address from 
  // address to
  // timestamp
  // commitMessage
  // TODO: an IPFS picture
  event NewCommit(address indexed from, address indexed to, uint256 expiryTimestamp, uint256 stakeAmount, string commitMessage);


  event Claimed(address indexed from, uint256 amount);

  // "Commit" struct
  struct Commit {
    uint256 id;
    address commitFrom;
    address commitTo;
    uint256 expiryTimestamp;
    uint256 stakeAmount; // currently only ETH supported
    string message;
    string proofIpfsHash;
    bool commitApproved;
  }

  constructor() {
    totalCommits = 0;
    console.log("CommitManager contract deployed");
  }


  // two mappings: 
  // one mapping which maps an address to the commitments they have been assigned to judge
  // one mapping which maps an address to the commitments they have made
  mapping(address => Commit[]) commitmentsToJudge; 
  mapping(address => Commit[]) commitmentsToClaim; 

  // TODO: _also_ takes in "picture" and "wager"
  function createCommit(string memory _message, address commitTo, uint256 expiryTimestamp, uint256 stakeAmount ) external payable {
    require(msg.value == stakeAmount, "You must send the exact amount of ETH as the stake amount");
    require(commitTo != msg.sender, "Cannot commit to yourself");


    console.log("\n%s has commited with message: %s", msg.sender, _message);
    Commit memory newCommit = Commit(totalCommits, msg.sender, commitTo, expiryTimestamp, stakeAmount, _message, "", false);
    commits.push(newCommit);
    totalCommits += 1;
  }


  // creator of a commitment can send a proof that they have completed the commitment
  // using an ipfs hash 
  function updateCommit(uint256 commitId, string memory _proofIpfsHash) external {
    Commit storage commit = commits[commitId];
    require(commit.commitFrom == msg.sender, "You are not the creator of this commit");
    require(commit.commitApproved == false, "This commit has already been approved");
    require(commit.expiryTimestamp > block.timestamp, "This commit has expired");
    commit.proofIpfsHash = _proofIpfsHash;
  }

  // Recipient of a commit can approve the commit was completed successfully before the expiry date/time
  // once approved the sender of the commit can claim the stake amount (at any time)
  function judgeCommit(uint256 commitId, bool commitApproved) external { 
    Commit storage commit = commits[commitId];
    require(commit.commitTo == msg.sender, "You are not the recipient of this commit");
    require(commit.expiryTimestamp > block.timestamp, "Commit has expired");
    require(commit.commitApproved == false, "Commit has already been judged");

    commit.commitApproved = commitApproved;
    if (commitApproved) {
      // send the stake amount to the commitFrom
      payable(commit.commitFrom).transfer(commit.stakeAmount);
    }
  }

  function claimExpiredCommit(uint256 commitId) external {
    Commit storage commit = commits[commitId];
    require(commit.commitTo == msg.sender, "You are not the commitTo of this commit");
    require(commit.commitApproved == false, "Commit has already been judged");
    require(commit.expiryTimestamp < block.timestamp, "Commit has not expired yet");

    // send the stake amount to the commitFrom
    payable(commit.commitFrom).transfer(commit.stakeAmount);
  }

  // a Getter for the Commit array
  function getAllCommits() public view returns (Commit[] memory) {
    return commits;
  }

  // a Getter for the totalCommits integer
  function getTotalCommits() public view returns (uint256) {
    return totalCommits;
  }

}