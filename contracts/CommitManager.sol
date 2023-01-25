// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract CommitManagerContract is Ownable {

  // global history of commits
  Commit[] commits;
  // global counter for uniquely identifying commits
  uint256 totalCommits;

  // "Commit" struct
  struct Commit {
    uint256 id; // the totalCommits proxy (for now)
    address commitFrom;
    address commitTo;
    uint256 createdAt;
    uint256 validThrough;
    uint256 judgeDeadline; // validThrough + 24 hours
    uint256 stakeAmount; // only ETH supported (for now)
    string message;
    string ipfsHash;
    bool commitProved;
    bool commitJudged;
    bool isApproved;
  }

  constructor() {
    totalCommits = 0;
    console.log("CommitManagerContract contract deployed");
  }

  // (1) create -> (2) prove -> (3) judge

  // create a commit
  function createCommit(string memory _message, address commitTo, uint256 validThrough) external payable {
    require(commitTo != msg.sender, "Cannot commit to yourself");
    require(msg.value >= 0, "Stake amount must be positive");
    require(validThrough > block.timestamp, "The commitment can't be for the past");

    Commit memory newCommit = Commit(totalCommits, msg.sender, commitTo, block.timestamp, validThrough, validThrough + (86400 * 1000), msg.value, _message, "", false, false, false);
    commits.push(newCommit);
    totalCommits += 1;

    console.log("\n%s has commited with message: %s", msg.sender, _message);
  }

  // prove a commit
  function proveCommit(uint256 commitId, string memory _ipfsHash) external {
    Commit storage commit = commits[commitId];

    require(commit.commitFrom == msg.sender, "You are not the creator of this commit");
    require(commit.commitProved == false, "This commit has already been proved");
    require(commit.validThrough > block.timestamp, "This commit has expired");

    commit.commitProved = true;
    commit.ipfsHash = _ipfsHash;
  }

  // judge a commit
  function judgeTheCommit(uint256 commitId, bool _isApproved) external { 
    Commit storage commit = commits[commitId];

    require(commit.commitTo == msg.sender, "You are not the judge of this commit");
    require(commit.judgeDeadline > block.timestamp, "The judge deadline has expired");
    require(commit.commitJudged == false, "Commit has already been judged");
    require(bytes(commit.ipfsHash).length != 0, "Proof must be submitted before you can judge");
    
    commit.commitJudged = true;
    commit.isApproved = _isApproved;

    if (_isApproved) {
      payable(commit.commitFrom).transfer(commit.stakeAmount);
    }
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
