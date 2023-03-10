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
    address[] commitTo;
    uint256 createdAt;
    uint256 startsAt;
    uint256 endsAt;
    uint256 judgeDeadline; // endsAt + 24 hours
    uint256 stakeAmount; // native token
    string message;
    string ipfsHash;
    string filename;
    bool commitProved;
    bool commitJudged;
    bool isApproved;
    bool isSolo;
  }

  // "NewCommit" event
  event NewCommit(
    uint256 id,
    address indexed commitFrom,
    address[] indexed commitTo,
    uint256 createdAt,
    uint256 startsAt,
    uint256 endsAt,
    uint256 judgeDeadline, 
    uint256 stakeAmount,
    string message,
    string ipfsHash,
    string filename,
    bool commitProved,
    bool commitJudged,
    bool isApproved,
    bool isSolo
  );

  // "NewProve" event
  event NewProve(
    uint256 commitId,
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

  // a Getter for the Commit array
  function getAllCommits() public view returns (Commit[] memory) {
    return commits;
  }

  // a Getter for the totalCommits integer
  function getTotalCommits() public view returns (uint256) {
    return totalCommits;
  }

  // (1) CREATE -> (2) PROVE -> (3) JUDGE

  // (1) CREATE
  function createCommit(string memory _message, address[] memory commitTo, uint256 startsAt, uint256 endsAt, bool isSolo) external payable {
    // checks
    require(msg.value >= 0, "Stake amount must be positive");
    require(endsAt > block.timestamp, "The commitment can't be in the past");
    for (uint256 i = 0; i < commitTo.length; i++) {
      require(commitTo[i] != msg.sender, "Cannot attest yourself");
    }

    // create
    Commit memory newCommit = Commit(
      totalCommits, msg.sender, commitTo, block.timestamp, startsAt, endsAt, endsAt + (86400 * 1000),
      msg.value, _message, "", "", false, false, false, isSolo
    );

    // update
    commits.push(newCommit);
    totalCommits += 1;
  }

  // (2) PROVE
  function proveCommit(uint256 commitId) external {
    Commit storage commit = commits[commitId];

    require(commit.commitFrom == msg.sender, "You are not the creator of this commit");
    require(commit.commitProved == false, "This commit has already been proved");
    require(commit.endsAt > block.timestamp, "This commit has expired");

    commit.commitProved = true;

    emit NewProve(commitId, block.timestamp);
  }

  // (3) JUDGE
  function judgeCommit(uint256 commitId, bool _isApproved) external { 
    Commit storage commit = commits[commitId];

    // TODO: require(!Address.contains(msg.sender, commitTo) "You are not the judge of this commit");
    require(commit.judgeDeadline > block.timestamp, "The judge deadline has expired");
    require(commit.commitJudged == false, "Commit has already been judged");
    require(bytes(commit.ipfsHash).length != 0, "Proof must be submitted before you can judge");
    
    commit.commitJudged = true;
    commit.isApproved = _isApproved;

    if (_isApproved) {
      payable(commit.commitFrom).transfer(commit.stakeAmount);
    }

    emit NewJudge(commitId, _isApproved, block.timestamp);
  }

}
