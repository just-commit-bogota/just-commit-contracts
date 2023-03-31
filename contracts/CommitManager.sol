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
    address[] commitJudge;
    uint256 createdAt;
    uint256 startsAt;
    uint256 endsAt;
    uint256 judgeDeadline; // endsAt + 24 hours
    uint256 stakeAmount; // native token
    string message;
    string filename;
    bool isCommitProved;
    bool isCommitJudged;
    bool isApproved;
    bool isSolo;
  }

  // "NewCommit" event
  event NewCommit(
    uint256 id,
    address indexed commitFrom,
    address indexed commitTo,
    address[] indexed commitJudge,
    uint256 createdAt,
    uint256 startsAt,
    uint256 endsAt,
    uint256 judgeDeadline, 
    uint256 stakeAmount,
    string message,
    string filename,
    bool isCommitProved,
    bool isCommitJudged,
    bool isApproved,
    bool isSolo
  );

  // "NewProve" event
  event NewProve(
    uint256 commitId,
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

  // a Getter for the Commit array
  function getAllCommits() public view returns (Commit[] memory) {
    return commits;
  }

  // a Getter for the totalCommits integer
  function getTotalCommits() public view returns (uint256) {
    return totalCommits;
  }

  function isAddressInArray(address[] memory array, address element) internal pure returns (bool) {
    for (uint i = 0; i < array.length; i++) {
        if (array[i] == element) {
            return true;
        }
    }
    return false;
  }


  // (1) CREATE -> (2) PROVE -> (3) JUDGE

  // (1) CREATE
  function createCommit(string memory _message, address commitTo, address[] memory commitJudge, uint256 startsAt, uint256 endsAt, bool isSolo) external payable {
    // checks
    require(msg.value >= 0, "Stake amount must be positive");
    require(endsAt <= startsAt + (168 * 3600 * 1000), "The commitment can't be longer than a week");
    require(endsAt > block.timestamp, "The commitment can't be in the past");
    for (uint256 i = 0; i < commitJudge.length; i++) {
      require(commitJudge[i] != msg.sender, "Cannot attest yourself");
    }

    // create
    Commit memory newCommit = Commit(
      totalCommits, msg.sender, commitTo, commitJudge, block.timestamp, startsAt, endsAt, endsAt + (86400 * 1000),
      msg.value, _message, "", false, false, false, isSolo
    );

    // update
    commits.push(newCommit);
    totalCommits += 1;
  }

  // (2) PROVE
  function proveCommit(uint256 commitId, string memory _filename) external {
    Commit storage commit = commits[commitId];

    require(commit.commitFrom == msg.sender, "You are not the creator of this commit");
    require(commit.isCommitProved == false, "This commit has already been proved");
    require(commit.endsAt > block.timestamp, "This commit has expired");

    commit.isCommitProved = true;
    commit.filename = _filename;

    emit NewProve(commitId, _filename, block.timestamp);
  }

  // (3) JUDGE
  function judgeCommit(uint256 commitId, bool _isApproved) external { 
    Commit storage commit = commits[commitId];

    require(isAddressInArray(commit.commitJudge, msg.sender), "You are not the judge of this commit");
    require(commit.judgeDeadline > block.timestamp, "The judge deadline has expired");
    require(commit.isCommitJudged == false, "Commit has already been judged");
    require(bytes(commit.filename).length != 0, "Proof must be submitted before you can judge");
    
    commit.isCommitJudged = true;
    commit.isApproved = _isApproved;

    if (_isApproved) {
      payable(commit.commitFrom).transfer(commit.stakeAmount);
    }
    else {
      payable(commit.commitTo).transfer(commit.stakeAmount);
    }

    emit NewJudge(commitId, _isApproved, block.timestamp);
  }

}
