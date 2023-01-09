// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract CommitManager {

  // global history of commits
  Commit[] commits;
  // global counter for uniquely identifying commits
  uint256 totalCommits;

  // events
  event NewCommit(address indexed from, address indexed to, uint256 validThrough, uint256 stakeAmount, string commitMessage);
  event ProofSubmitted(address indexed from, address indexed to, string ipfsUrl);

  // "Commit" struct
  struct Commit {
    uint256 id; // the totalCommits proxy (for now)
    address commitFrom;
    address commitTo;
    uint64 createdAt;
    uint64 validThrough;
    uint64 judgeDeadline; // validThrough + 24 hours
    uint256 stakeAmount; // only ETH supported (for now)
    string message;
    string ipfsHash;
    bool commitJudged;
    bool isApproved;
  }

  constructor() {
    totalCommits = 0;
    console.log("CommitManager contract deployed");
  }

  // (1) create -> (2) prove -> (3) judge

  // create a commit
  function createCommit(string memory _message, address commitTo, uint256 validThrough) external payable {
    require(commitTo != msg.sender, "Cannot commit to yourself");

    Commit memory newCommit = Commit(totalCommits, msg.sender, commitTo, block.timestamp ,validThrough, validThrough + 24 hours, msg.value, _message, "", false);
    commits.push(newCommit);
    totalCommits += 1;

    console.log("\n%s has commited with message: %s", msg.sender, _message);
  }

  // prove a commit
  function proveCommit(uint256 commitId, string memory _ipfsHash) external {
    Commit storage commit = commits[commitId];

    require(commit.commitFrom == msg.sender, "You are not the creator of this commit");
    require(commit.commitJudged == false, "This commit has already been proved");
    require(commit.validThrough > block.timestamp, "This commit has expired");

    commit.ipfsHash = _ipfsHash;
  }

  // judge a commit
  function judgeCommit(uint256 commitId, bool commitJudged, bool isApproved) external { 
    Commit storage commit = commits[commitId];

    require(commit.commitTo == msg.sender, "You are not the judge of this commit");
    require(commit.judgeDeadline > block.timestamp, "The judge deadline has expired");
    require(commit.commitJudged == false, "Commit has already been judged");
    require(bytes(commit.ipfsHash).length != 0, "Proof must be submitted before you can judge");
    
    commit.commitJudged = commitJudged;
    commit.isApproved = isApproved;

    if (isApproved) {
      payable(commit.commitFrom).transfer(commit.stakeAmount);
    }
    else {
      payable(commit.commitTo).transfer(commit.stakeAmount);
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
