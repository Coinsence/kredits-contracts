pragma solidity ^0.4.24;

import "@aragon/os/contracts/apps/AragonApp.sol";
import "@aragon/os/contracts/kernel/IKernel.sol";

interface IToken {
  function mintFor(address contributorAccount, uint256 amount, uint256 contributionId) public;
}

contract Contribution is AragonApp {
  bytes32 public constant ADD_CONTRIBUTION_ROLE = keccak256("ADD_CONTRIBUTION_ROLE");
  bytes32 public constant VETO_CONTRIBUTION_ROLE = keccak256("VETO_CONTRIBUTION_ROLE");

  bytes32 public constant KERNEL_APP_ADDR_NAMESPACE = 0xd6f028ca0e8edb4a8c9757ca4fdccab25fa1e0317da1188108f7d2dee14902fb;
  // ensure alphabetic order
  enum Apps { Contribution, Contributor, Proposal, Token }
  bytes32[4] public appIds;

  struct ContributionData {
    address contributor;
    uint256 amount;
    bool claimed;
    bytes32 hashDigest;
    uint8 hashFunction;
    uint8 hashSize;
    string tokenMetadataURL;
    uint claimAfterBlock;
    bool vetoed;
    bool exists;
  }
  string internal name_;
  string internal symbol_;

  mapping(uint256 => address) contributionOwner;
  mapping(address => uint256[]) ownedContributions;

  mapping(uint256 => ContributionData) public contributions;
  uint256 public contributionsCount;

  uint256 public blocksToWait = 0;

  event ContributionAdded(uint256 id, address indexed contributor, uint256 amount);
  event ContributionClaimed(uint256 id, address indexed contributor, uint256 amount);
  event ContributionVetoed(uint256 id, address vetoedByAccount);

  function initialize(bytes32[4] _appIds) public onlyInit {
    appIds = _appIds;
    initialized();
  }

  function getTokenContract() public view returns (address) {
    IKernel k = IKernel(kernel());

    return k.getApp(KERNEL_APP_ADDR_NAMESPACE, appIds[uint8(Apps.Token)]);
  }

  function name() external view returns (string) {
    return name_;
  }

  function symbol() external view returns (string) {
    return symbol_;
  }

  function balanceOf(address owner) public view returns (uint256) {
    require(owner != address(0));
    return ownedContributions[owner].length;
  }

  function ownerOf(uint256 contributionId) public view returns (address) {
    require(exists(contributionId));
    return contributions[contributionId].contributor;
  }

  function tokenOfOwnerByIndex(address contributor, uint256 index) public view returns (uint256) {
    return ownedContributions[contributor][index];
  }

  function tokenMetadata(uint256 contributionId) public view returns (string) {
    return contributions[contributionId].tokenMetadataURL;
  }

  function getContribution(uint256 contributionId) public view returns (uint256 id, address contributor, uint256 amount, bool claimed, bytes32 hashDigest, uint8 hashFunction, uint8 hashSize, uint claimAfterBlock, bool exists, bool vetoed) {
    id = contributionId;
    ContributionData storage c = contributions[id];
    return (
      id,
      c.contributor,
      c.amount, 
      c.claimed, 
      c.hashDigest,
      c.hashFunction,
      c.hashSize,
      c.claimAfterBlock,
      c.exists,
      c.vetoed
    );
  }

  function add(uint256 amount, address contributorAccount, bytes32 hashDigest, uint8 hashFunction, uint8 hashSize) public isInitialized auth(ADD_CONTRIBUTION_ROLE) {
    //require(canPerform(msg.sender, ADD_CONTRIBUTION_ROLE, new uint256[](0)), 'nope');
    uint256 contributionId = contributionsCount + 1;
    ContributionData storage c = contributions[contributionId];
    c.exists = true;
    c.amount = amount;
    c.claimed = false;
    c.contributor = contributorAccount;
    c.hashDigest = hashDigest;
    c.hashFunction = hashFunction;
    c.hashSize = hashSize;
    c.claimAfterBlock = block.number; // + blocksToWait;

    contributionsCount++;

    contributionOwner[contributionId] = contributorAccount;
    ownedContributions[contributorAccount].push(contributionId);
 
    emit ContributionAdded(contributionId, contributorAccount, amount);
  }

  function veto(uint256 contributionId) public isInitialized auth(VETO_CONTRIBUTION_ROLE) {
    ContributionData storage c = contributions[contributionId];
    require(c.exists, 'NOT_FOUND');
    require(!c.claimed, 'ALREADY_CLAIMED');
    c.vetoed = true;

    emit ContributionVetoed(contributionId, msg.sender);
  }

  function claim(uint256 contributionId) public isInitialized {
    ContributionData storage c = contributions[contributionId];
    require(c.exists, 'NOT_FOUND');
    require(!c.claimed, 'ALREADY_CLAIMED');
    require(!c.vetoed, 'VETOED');
    require(block.number > c.claimAfterBlock, 'NOT_CLAIMABLE');

    c.claimed = true;
    address token = getTokenContract();
    IToken(token).mintFor(c.contributor, c.amount, contributionId);
    emit ContributionClaimed(contributionId, c.contributor, c.amount);
  }
  
  function exists(uint256 contributionId) view public returns (bool) {
    return contributions[contributionId].exists;
  }
}
