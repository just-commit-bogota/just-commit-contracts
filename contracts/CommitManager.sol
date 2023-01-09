// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract CommitManager {

  // variables
  Commit[] commits;
  uint256 totalCommits;

  // events
  event NewCommit(address indexed from, address indexed to, uint256 expiryTimestamp, uint256 stakeAmount, string commitMessage);
  event Claimed(address indexed from, uint256 amount);

  // "Commit" struct
  struct Commit {
    uint256 id; // the totalCommits proxy (for now)
    address commitFrom;
    address commitTo;
    uint256 expiryTimestamp;
    uint256 stakeAmount; // currently only ETH supported
    string message;
    string proofIpfsHash;
    bool commitJudged; // change all commitApproved instances
  }
  constructor() {
    totalCommits = 0;
    console.log("CommitManager contract deployed");
  }

  // functions (create -> prove -> judge, claim)

  // create a commit
  function createCommit(string memory _message, address commitTo, uint256 expiryTimestamp) external payable {
    require(msg.sender != commitTo, "Cannot commit to yourself");

    Commit memory newCommit = Commit(totalCommits, msg.sender, commitTo, expiryTimestamp, msg.value, _message, "", false);
    commits.push(newCommit);
    totalCommits += 1;

    console.log("\n%s has commited with message: %s", msg.sender, _message);
  }

  // prove a commit
  function proveCommit(uint256 commitId, string memory _proofIpfsHash) external {
    Commit storage commit = commits[commitId];
    require(commit.commitFrom == msg.sender, "You are not the creator of this commit");
    require(commit.commitApproved == false, "This commit has already been proved");
    require(commit.expiryTimestamp > block.timestamp, "This commit has expired");

    commit.proofIpfsHash = _proofIpfsHash;
  }

  // judge a commit
  function judgeCommit(uint256 commitId, bool commitApproved) external { 
    Commit storage commit = commits[commitId];
    require(commit.commitTo == msg.sender, "You are not the recipient of this commit");
    require(commit.expiryTimestamp > block.timestamp, "Commit has expired");
    require(commit.commitApproved == false, "Commit has already been judged");
    require(bytes(commit.proofIpfsHash).length != 0, "Proof must be submitted before you can judge");
    
    commit.commitApproved = commitApproved;
    if (commitApproved) {
      // send the stake amount to the commitFrom
      payable(commit.commitFrom).transfer(commit.stakeAmount);
    }
  }

  // claim an expired commit
  function claimExpiredCommit(uint256 commitId) external {
    Commit storage commit = commits[commitId];
    require(commit.commitTo == msg.sender, "You are not the commitTo of this commit");
    require(commit.commitApproved == false, "Commit has already been judged");
    require(commit.expiryTimestamp < block.timestamp, "Commit has not expired yet");

    // send the stake amount to the commitTo
    payable(commit.commitTo).transfer(commit.stakeAmount);
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
