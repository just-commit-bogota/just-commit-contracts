// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract CommitPortal is Ownable {

  // global counter for uniquely identifying commits
  uint256 totalCommits;

  // global history of commits
  Commit[] commits;

  // Commit struct
  struct Commit {
    uint256 id; // the totalCommits proxy (for now)
    address commitFrom;
    address commitTo;
    uint256 createdAt;
    uint256 validThrough;
    uint256 judgeDeadline; // validThrough + 24 hours
    uint256 stakeAmount; // native token
    string message;
    string ipfsHash;
    string filename;
    bool commitProved;
    bool commitJudged;
    bool isApproved;
    bool isChallenge;
  }

  // "NewCommit" event
  event NewCommit(
    uint256 id,
    address indexed commitFrom,
    address indexed commitTo,
    uint256 createdAt,
    uint256 validThrough,
    uint256 judgeDeadline, 
    uint256 stakeAmount,
    string message,
    string ipfsHash,
    string filename,
    bool commitProved,
    bool commitJudged,
    bool isApproved,
    bool isChallenge
  );

  // "NewProve" event
  event NewProve(
    uint256 commitId,
    string ipfsHash,
    string filename,
    uint256 provedAt
  );

  // "NewJudge" event
  event NewJudge(
    uint256 commitId,
    bool isApproved,
    uint256 judgedAt
  );

  constructor() {
    totalCommits = 0;
  }

  // utils
  function hasPendingCommits() public view returns (bool) {
    for (uint i = 0; i < commits.length; i++) {
      if (commits[i].commitFrom == msg.sender && 
          !commits[i].commitProved &&
          commits[i].validThrough > block.timestamp) {
        return true;
      }
    }
    return false;
  }

  // (1) CREATE -> (2) PROVE -> (3) JUDGE

  // create a commit
  function createCommit(string memory _message, address commitTo, uint256 validThrough, uint256 commitsToCreate) external payable {
    require(commitTo != msg.sender, "Cannot commit to yourself");
    require(msg.value >= 0, "Stake amount must be positive");
    require(validThrough > block.timestamp, "The commitment can't be in the past");
    require(commitsToCreate >= 1, "You have to create at least 1 commitment");
    require(commitsToCreate == 30 || commitsToCreate == 60, "You can only create 30 or 60 commitments at a time");
    require(!hasPendingCommits(), "You have at least one pending commitment");

    bool isChallenge;

    if (commitsToCreate > 1) {
      isChallenge = true;
      validThrough = block.timestamp + (86400 * 1000); // 24 hours
    } else {
      isChallenge = false;
    }

    for (uint256 i = 0; i < commitsToCreate; i++) {
      Commit memory newCommit = Commit(totalCommits, msg.sender, commitTo, block.timestamp, validThrough, validThrough + ((i+1)*86400), msg.value / commitsToCreate, _message, "", "", false, false, false, isChallenge);
      commits.push(newCommit);
      totalCommits += 1;

      emit NewCommit(totalCommits, msg.sender, commitTo, block.timestamp, validThrough, validThrough + ((i+1)*86400), msg.value / commitsToCreate, _message, "", "", false, false, false, isChallenge);
    }
  }

  // prove a commit
  function proveCommit(uint256 commitId, string memory _ipfsHash, string memory _filename) external {
    Commit storage commit = commits[commitId];

    require(commit.commitFrom == msg.sender, "You are not the creator of this commit");
    require(commit.commitProved == false, "This commit has already been proved");
    require(commit.validThrough > block.timestamp, "This commit has expired");

    commit.commitProved = true;

    commit.ipfsHash = _ipfsHash;
    commit.filename = _filename;

    emit NewProve(commitId, _ipfsHash, _filename, block.timestamp);
  }

  // judge a commit
  function judgeCommit(uint256 commitId, bool _isApproved) external { 
    Commit storage commit = commits[commitId];

    require(commit.commitTo == msg.sender, "You are not the judge of this commit");
    require(commit.judgeDeadline > block.timestamp, "The judge deadline has expired");
    require(commit.commitJudged == false, "Commit has already been judged");
    require(bytes(commit.ipfsHash).length != 0, "Proof must be submitted before you can judge");
    
    commit.commitJudged = true;
    commit.isApproved = _isApproved;

    // contract doesn't handle payment logic for challenge commitments (for now)
    if (_isApproved && !commit.isChallenge) {
      payable(commit.commitFrom).transfer(commit.stakeAmount);
    }

    emit NewJudge(commitId, _isApproved, block.timestamp);
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
