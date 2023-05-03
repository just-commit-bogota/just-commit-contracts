// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract CommitPortal is Ownable {

  // global counter for uniquely identifying commits
  uint256 totalCommits;

  uint256 private constant SCALING_FACTOR = 1000;

  // global history of commits
  Commit[] commits;

  // Commit struct
  struct Commit {
    uint256 id; // the totalCommits proxy (for now)
    address commitFrom;
    address commitTo;
    address commitJudge;
    uint256 createdAt;
    uint256 endsAt;
    uint256 judgeDeadline; // endsAt + 24 hours
    uint256 phonePickups;
    uint256 stakeAmount; // native token
    string filename;
    bool isCommitProved;
    bool isCommitJudged;
    bool isApproved;
  }

  // "NewCommit" event
  event NewCommit(
    uint256 id,
    address indexed commitFrom,
    address indexed commitTo,
    address indexed commitJudge,
    uint256 createdAt,
    uint256 endsAt,
    uint256 judgeDeadline,
    uint256 phonePickups,
    uint256 stakeAmount,
    string filename,
    bool isCommitProved,
    bool isCommitJudged,
    bool isApproved
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

  // (1) CREATE -> (2) PROVE -> (3) JUDGE

  // (1) CREATE
   function createCommit(address commitTo, address commitJudge, uint256 phonePickups) external payable {
    require(commitTo != msg.sender, "Cannot send to yourself");
    require(commitJudge != msg.sender, "Cannot attest yourself");
    require(msg.value > 0, "Commit amount must be positive");

    uint256 constantMultiplier = 25 * SCALING_FACTOR / 10; // 25% split

    uint256 stakeAmount = msg.value;
    uint256 currentPhonePickups = phonePickups;

    for (uint256 i = 0; i < 4; i++) {
      // Calculate endsAt and judgeDeadline for each commit
      uint256 endsAt = (block.timestamp + (i + 1) * 1 weeks) * 1000;
      uint256 judgeDeadline = (endsAt + 24 hours) * 1000;
      uint256 commitStake = stakeAmount * constantMultiplier / SCALING_FACTOR;

      // Modify phonePickups for each commit using the multipliers array
      currentPhonePickups = currentPhonePickups * (SCALING_FACTOR - constantMultiplier) / SCALING_FACTOR;

      // create
      Commit memory newCommit = Commit(
        totalCommits,
        msg.sender,
        commitTo,
        commitJudge,
        block.timestamp * 1000,
        endsAt,
        judgeDeadline,
        currentPhonePickups,
        commitStake,
        "",
        false,
        false,
        false
      );

      // update
      commits.push(newCommit);
      totalCommits += 1;

      // emit
      emit NewCommit(
        totalCommits,
        msg.sender,
        commitTo,
        commitJudge,
        block.timestamp * 1000,
        endsAt,
        judgeDeadline,
        currentPhonePickups,
        commitStake,
        "",
        false,
        false,
        false
      );
    }

  }

  // (2) PROVE
  function proveCommit(uint256 commitId, string memory _filename) external {
    Commit storage commit = commits[commitId];

    require(commit.commitFrom == msg.sender, "You are not the creator of this commit");
    require(commit.isCommitProved == false, "This commit has already been proved");
    require(commit.endsAt > block.timestamp * 1000, "This commit has expired");

    commit.isCommitProved = true;
    commit.filename = _filename;
    commit.judgeDeadline = (block.timestamp * 1000) + (1 * 24 * 60 * 60 * 1000);

    emit NewProve(commitId, _filename, block.timestamp * 1000);
  }

  // (3) JUDGE
  function judgeCommit(uint256 commitId, bool _isApproved) external { 
    Commit storage commit = commits[commitId];

    require(commit.commitJudge == msg.sender, "You are not the judge of this commit");
    require(commit.judgeDeadline > block.timestamp * 1000, "The judge deadline has expired");
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

    emit NewJudge(commitId, _isApproved, block.timestamp * 1000);
  }
}
