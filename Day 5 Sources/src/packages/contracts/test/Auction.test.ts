import { expect } from "chai"
import { constants, Signer } from "ethers"
import { ethers, run } from "hardhat"
import { poseidonContract } from "circomlibjs"
import { IncrementalMerkleTree, MerkleProof } from "@zk-kit/incremental-merkle-tree"
import { IncrementalBinaryTree, PoseidonT3, Auction, MembershipVerifier, BidVerifier, TestERC20, TestERC721 } from "../build/typechain";
import { BigNumber } from "@ethersproject/bignumber";
import { randomBytes } from "@ethersproject/random";
import { poseidon1 } from "poseidon-lite/poseidon1"
import { poseidon2 } from "poseidon-lite/poseidon2"
import poseidon from "poseidon-lite"
import { groth16 } from "snarkjs"
import { BytesLike, Hexable, zeroPad } from "@ethersproject/bytes"
import { keccak256 } from "@ethersproject/keccak256"
import { time } from "@nomicfoundation/hardhat-network-helpers";

const membershipWasmPath = `${__dirname}/../../circuits/balance_membership_js/balance_membership.wasm`
const membershipZkeyPath = `${__dirname}/../../circuits/membership.zkey`
const bidWasmPath = `${__dirname}/../../circuits/auction_bid_js/auction_bid.wasm`
const bidZkeyPath = `${__dirname}/../../circuits/bid.zkey`

class Identity {
    trapdoor: bigint
    nullifier: bigint
    secret: bigint
    commitment: bigint
    addr: any

    constructor(addr: any) {
        this.trapdoor = BigNumber.from(randomBytes(31)).toBigInt()
        this.nullifier = BigNumber.from(randomBytes(31)).toBigInt()
        this.secret = poseidon2([this.nullifier, this.trapdoor])
        this.commitment = poseidon1([this.secret])
        this.addr = addr
    }
}

function getLeaf(commitment: bigint, data: bigint): bigint {
    return poseidon2([commitment, data]);
}

async function proveMembership(auction: Auction, identity: Identity, tree: IncrementalMerkleTree, nonce: bigint, data: bigint): Promise<[string[], string[]]> {
    const leaf = getLeaf(identity.commitment, data);
    const index = tree?.indexOf(leaf)
    if(index == undefined || index == -1) {
        throw new Error("Couldn't find commitment");
    }
    const merkleProof = tree?.createProof(index);
    if(!merkleProof) {
        throw new Error("Couldn't crete proof");
    }

    const { proof, publicSignals } = await groth16.fullProve(
        {
            identityTrapdoor: identity.trapdoor,
            identityNullifier: identity.nullifier,
            index: index,
            treeSiblings: merkleProof.siblings,
            nonce: nonce,
            roots: tree.root,
            leafData: data,
            receiver: identity.addr.address
        },
        membershipWasmPath,
        membershipZkeyPath
    )

    const packedProof = [
        proof.pi_a[0],
        proof.pi_a[1],
        proof.pi_b[0][1],
        proof.pi_b[0][0],
        proof.pi_b[1][1],
        proof.pi_b[1][0],
        proof.pi_c[0],
        proof.pi_c[1]
    ]

    return [publicSignals, packedProof]

    /*const txn = semaphore.verifyProof(group, roots, signal, publicSignals[0], group, packedProof)

    await expect(txn)
                .to.emit(semaphore, "ProofVerified")
                .withArgs(
                    group,
                    publicSignals[0],
                    group,
                    signal
                )*/
}

async function createNFT(auction: Auction, nft: TestERC721, user: any, tid: bigint) {
    await nft.mint(user.address, tid);
    await nft.connect(user).setApprovalForAll(auction.address, true);
}

async function mintTokens(auction: Auction, token: TestERC20, user: any, amount: bigint) {
    await token.mint(user.address, amount);
    await token.connect(user).approve(auction.address, amount);
}

async function createAuction(auctionId: bigint, auction: Auction, auctions: Map<bigint, IncrementalMerkleTree>, bids: Map<bigint, IncrementalMerkleTree>, owner: any, duration: bigint, tokenId: bigint) {
    const txn = auction.createAuction(auctionId, owner.address, duration, tokenId);
    await expect(txn).to.emit(auction, "AuctionCreated")
    auctions.set(auctionId, new IncrementalMerkleTree(poseidon2, 20, 0, 2))
    bids.set(auctionId, new IncrementalMerkleTree(poseidon2, 20, 0, 2))
}

async function depositFunds(auction: Auction, escrowTree: IncrementalMerkleTree, balances: Map<bigint, bigint>, identity: Identity, amt: bigint) {
    let curBal = balances.get(identity.commitment);
    let index = 0;
    if(curBal) {
        const leaf = getLeaf(identity.commitment, curBal);
        index = escrowTree.indexOf(leaf);
        if(index == -1) {
            throw new Error("Could not find leaf")
        }

        const proof = escrowTree.createProof(index);
        const siblings = proof.siblings.map((v) => v[0])
        const txn = auction.connect(identity.addr)["deposit(uint256,uint256,uint256,uint256[])"](identity.commitment, curBal, amt, siblings);
        await expect(txn).to.emit(auction, "Deposit").withArgs(identity.commitment, curBal, amt, BigInt(index))
    }
    else {
        curBal = BigInt(0);
        index = escrowTree.leaves.length;
        escrowTree.insert(0);
        const txn = auction.connect(identity.addr)["deposit(uint256,uint256)"](identity.commitment, amt)
        await expect(txn).to.emit(auction, "Deposit").withArgs(identity.commitment, curBal, amt, index)
    }
    balances.set(identity.commitment, curBal + amt);
    escrowTree.update(index, getLeaf(identity.commitment, curBal + amt))
}

async function withdrawFunds(auction: Auction, escrowTree: IncrementalMerkleTree, balances: Map<bigint, bigint>, identity: Identity, nonce: bigint, amt: bigint) {
    const curBal = balances.get(identity.commitment);
    if(curBal == undefined) {
        throw new Error("Couldn't find balance");
    }

    const [signals, proof] = await proveMembership(auction, identity, escrowTree, nonce, curBal);

    const leaf = getLeaf(identity.commitment, curBal);
    const index = escrowTree.indexOf(leaf);
    if(index == -1) {
        throw new Error("Could not find leaf")
    }

    const merkleProof = escrowTree.createProof(index);
    const siblings = merkleProof.siblings.map((v) => v[0])
    const txn = auction.withdraw(nonce, curBal, amt, identity.addr.address, identity.commitment, signals[0], siblings, proof)
    await expect(txn).to.emit(auction, "Withdraw").withArgs(identity.commitment, curBal, amt, index)
    balances.set(identity.commitment, curBal - amt);
    escrowTree.update(index, getLeaf(identity.commitment, curBal - amt))
}

async function bid(auction: Auction, auctionId: bigint, auctionMembers: Map<bigint, IncrementalMerkleTree>, auctionBids: Map<bigint, IncrementalMerkleTree>, escrowTree: IncrementalMerkleTree, balances: Map<bigint, bigint>, identity: Identity, nonce: bigint, bid: bigint) {
    const members = auctionMembers.get(auctionId);
    const bids = auctionBids.get(auctionId);
    if(!members || !bids) {
        throw new Error("No members");
    }

    const auctionIndex = members.indexOf(getLeaf(identity.commitment, auctionId));
    if(auctionIndex == -1) {
        throw new Error("couldn't find commitment")
    }
    const auctionProof = members.createProof(auctionIndex);

    const curBal = balances.get(identity.commitment);
    if(curBal == undefined) {
        throw new Error("Couldn't find balance");
    }

    const balLeaf = getLeaf(identity.commitment, curBal);
    const balIndex = escrowTree.indexOf(balLeaf);
    if(balIndex == -1) {
        throw new Error("Could not find leaf")
    }

    const balanceProof = escrowTree.createProof(balIndex);
    const balSiblings = balanceProof.siblings.map((v) => v[0])

    let root = await auction.getMerkleTreeRoot(auctionId);
    let history = await auction.getMerkleTreeHistory(auctionId);
    const { proof, publicSignals } = await groth16.fullProve(
        {
            identityTrapdoor: identity.trapdoor,
            identityNullifier: identity.nullifier,
            auctionIndex: auctionIndex,
            auctionTreeSiblings: auctionProof.siblings,
            balanceTreeSiblings: balanceProof.siblings,
            auctionId: auctionId,
            balance: curBal,
            bid: bid,
            nonce: nonce,
            auctionRoots: history.map((v) => v.toBigInt()),
            balanceRoot: escrowTree.root,
            balanceIndex: balIndex,
        },
        bidWasmPath,
        bidZkeyPath
    )

    const packedProof = [
        proof.pi_a[0],
        proof.pi_a[1],
        proof.pi_b[0][1],
        proof.pi_b[0][0],
        proof.pi_b[1][1],
        proof.pi_b[1][0],
        proof.pi_c[0],
        proof.pi_c[1]
    ]


    const txn = auction.connect(identity.addr).bid(auctionId, nonce, balIndex, publicSignals[0], balLeaf, publicSignals[1], publicSignals[2], balSiblings, history, packedProof)
    await expect(txn).to.emit(auction, "Bid").withArgs(auctionId, publicSignals[0], bids.leaves.length, publicSignals[1])

    bids.insert(BigInt(publicSignals[1]));
    balances.set(identity.commitment, curBal - bid);
    escrowTree.update(balIndex, BigInt(publicSignals[2]))
}

async function reveal(auction: Auction, auctionId: bigint, auctionBids: Map<bigint, IncrementalMerkleTree>, identity: Identity, bid: bigint, nonce: bigint) {
    const bids = auctionBids.get(auctionId);
    if(!bids) {
        throw new Error("Couldn't find bids tree")
    }

    const [signals, proof] = await proveMembership(auction, identity, bids, nonce, bid);

    const txn = auction.reveal(auctionId, nonce, bid, identity.addr.address, identity.commitment, signals[0], proof)
    await expect(txn).to.emit(auction, "Reveal").withArgs(auctionId, signals[0], identity.commitment, bid);
}

async function refund(auction: Auction, auctionId: bigint, escrowTree: IncrementalMerkleTree, balances: Map<bigint, bigint>, auctionBids: Map<bigint, IncrementalMerkleTree>,  identity: Identity, bid: bigint) {
    const bids = auctionBids.get(auctionId);
    if(!bids) {
        throw new Error("Couldn't find bids tree")
    }

    const leaf = getLeaf(identity.commitment, bid);
    const bidIndex = bids.indexOf(leaf);
    if(bidIndex == -1) {
        throw new Error("Could not find leaf")
    }
    const bidProof = bids.createProof(bidIndex);
    const bidSiblings = bidProof.siblings.map((v) => v[0])

    const curBal = balances.get(identity.commitment);
    if(curBal == undefined) {
        throw new Error("Couldn't find balance")
    }
    const balIndex = escrowTree.indexOf(getLeaf(identity.commitment, curBal));
    if(balIndex == -1) {
        throw new Error("Could not find leaf")
    }
    const balProof = escrowTree.createProof(balIndex);
    const balSiblings = balProof.siblings.map((v) => v[0])


    const txn = auction.refund(auctionId, bid, identity.commitment, bidIndex, bidSiblings, curBal, balSiblings)
    await expect(txn).to.emit(auction, "Refund").withArgs(auctionId, identity.commitment, bid);
    bids.update(bidIndex, getLeaf(identity.commitment, BigInt(0)))
    balances.set(identity.commitment, curBal + bid);
    escrowTree.update(balIndex, getLeaf(identity.commitment, curBal + bid))
}

async function distribute(auction: Auction, token: TestERC20, nft: TestERC721, auctionId: bigint, owner: any, winner: Identity, tokenId: bigint, amt: bigint) {
    const oldBal = await token.balanceOf(owner.address)
    const txn = auction.distribute(auctionId);
    await expect(txn).to.emit(auction, "Distribute").withArgs(auctionId, tokenId, winner.addr.address, amt)
    expect(await token.balanceOf(owner.address)).to.equal(oldBal.add(amt))
    expect(await nft.ownerOf(tokenId)).to.equal(winner.addr.address)
}

async function addAuctionMember(auctionId: bigint, identity: Identity, auction: Auction, auctions: Map<bigint, IncrementalMerkleTree>) {
    await auction.addMember(auctionId, identity.commitment)
    auctions.get(auctionId)?.insert(getLeaf(identity.commitment, auctionId));
}

describe("Auction contract", function () {
  let pairing: any,
    membershipVerifier: MembershipVerifier,
    bidVerifier: BidVerifier,
    poseidon: PoseidonT3,
    incrementalBinaryTree: IncrementalBinaryTree,
    auction: Auction,
    token: TestERC20,
    nft: TestERC721,
    auctionMembers: Map<bigint, IncrementalMerkleTree>,
    auctionBids: Map<bigint, IncrementalMerkleTree>,
    identities: Identity[],
    escrowTree: IncrementalMerkleTree,
    escrowBal: Map<bigint, bigint>;

  beforeEach(async () => {
    /*const PairingFactory = await ethers.getContractFactory("Pairing")
    pairing = await PairingFactory.deploy()

    await pairing.deployed()

    console.info(`Pairing library has been deployed to: ${pairing.address}`)*/

    const TestERC20Factory = await ethers.getContractFactory("TestERC20", {})

    token = await TestERC20Factory.deploy("Token", "TKN")
    await token.deployed()

    console.info(`Token contract has been deployed to: ${token.address}`)

    const TestERC721Factory = await ethers.getContractFactory("TestERC721", {})

    nft = await TestERC721Factory.deploy("NFT", "NFT")
    await nft.deployed()

    console.info(`NFT contract has been deployed to: ${nft.address}`)

    const MembershipVerifierFactory = await ethers.getContractFactory("MembershipVerifier", {})

    membershipVerifier = await MembershipVerifierFactory.deploy()
    await membershipVerifier.deployed()

    console.info(`MembershipVerifier contract has been deployed to: ${membershipVerifier.address}`)

    const BidVerifierFactory = await ethers.getContractFactory("BidVerifier", {})

    bidVerifier = await BidVerifierFactory.deploy()
    await bidVerifier.deployed()

    console.info(`BidVerifier contract has been deployed to: ${bidVerifier.address}`)

    const PoseidonFactory = await ethers.getContractFactory("PoseidonT3", {})

    poseidon = await PoseidonFactory.deploy()
    await poseidon.deployed()

    console.info(`Poseidon library has been deployed to: ${poseidon.address}`)

    const IncrementalBinaryTreeFactory = await ethers.getContractFactory("IncrementalBinaryTree", {
        libraries: {
            PoseidonT3: poseidon.address
        }
    })
    incrementalBinaryTree = await IncrementalBinaryTreeFactory.deploy()
    await incrementalBinaryTree.deployed()
    console.info(`IncrementalBinaryTree library has been deployed to: ${incrementalBinaryTree.address}`)

    const AuctionFactory = await ethers.getContractFactory("Auction", {
        libraries: {
            IncrementalBinaryTree: incrementalBinaryTree.address,
            PoseidonT3: poseidon.address
        }
    })

    auction = await AuctionFactory.deploy(token.address, nft.address, membershipVerifier.address, bidVerifier.address)
    await auction.deployed()
    console.info(`Auction contract has been deployed to: ${auction.address}`)


    /*
    * creating members
    */

    auctionBids = new Map<bigint, IncrementalMerkleTree>();
    escrowBal = new Map<bigint, bigint>();
    escrowTree = new IncrementalMerkleTree(poseidon2, 20, 0, 2);
    auctionBids = new Map<bigint, IncrementalMerkleTree>();
    auctionMembers = new Map<bigint, IncrementalMerkleTree>();
    identities = []
    const signers = await ethers.getSigners();
    for (let i = 0; i < 10; i += 1) {
        identities.push(new Identity(signers[i]))
    }
    
  });
  it("Create Auction", async () => {
    const [owner] = await ethers.getSigners();

    const duration: bigint = BigInt(24 * 60 * 60);
    const aid: bigint = BigInt(1);
    const tid: bigint = BigInt(1);
    
    await createNFT(auction, nft, owner, tid)
    await createAuction(aid, auction, auctionMembers, auctionBids, owner, duration, tid);
    await addAuctionMember(aid, identities[0], auction, auctionMembers);
    await addAuctionMember(aid, identities[1], auction, auctionMembers);
    await addAuctionMember(aid, identities[2], auction, auctionMembers);
    /*await createGroup(gid, owner, semaphore, groups)
    await insertMember(gid, identities[0], semaphore, groups);
    await insertMember(gid, identities[1], semaphore, groups);
    await insertMember(gid, identities[2], semaphore, groups);
    let history = await semaphore.getMerkleTreeHistory(gid);

    await prove(semaphore, identities[0], gid, groups, history, BigInt(12));*/
  });

  it("Deposit Funds", async () => {
    await mintTokens(auction, token, identities[0].addr, BigInt(100000000))
    await mintTokens(auction, token, identities[1].addr, BigInt(100000000))
    await mintTokens(auction, token, identities[2].addr, BigInt(100000000))

    await depositFunds(auction, escrowTree, escrowBal, identities[0], BigInt(1000))
    await depositFunds(auction, escrowTree, escrowBal, identities[1], BigInt(100))
    await depositFunds(auction, escrowTree, escrowBal, identities[2], BigInt(10000))
    await depositFunds(auction, escrowTree, escrowBal, identities[2], BigInt(10000))

    expect(await token.balanceOf(identities[0].addr.address)).to.equal(99999000)
    expect(await token.balanceOf(identities[1].addr.address)).to.equal(99999900)
    expect(await token.balanceOf(identities[2].addr.address)).to.equal(99980000)
  });

  it("Withdraw Funds", async () => {
    await mintTokens(auction, token, identities[0].addr, BigInt(100000000))
    await mintTokens(auction, token, identities[1].addr, BigInt(100000000))

    await depositFunds(auction, escrowTree, escrowBal, identities[0], BigInt(1000))
    await depositFunds(auction, escrowTree, escrowBal, identities[1], BigInt(100))

    await withdrawFunds(auction, escrowTree, escrowBal, identities[1], BigInt(0), BigInt(10));
    expect(await token.balanceOf(identities[1].addr.address)).to.equal(99999910)
    await withdrawFunds(auction, escrowTree, escrowBal, identities[1], BigInt(1), BigInt(90));
    expect(await token.balanceOf(identities[1].addr.address)).to.equal(100000000)
  });

  it("Bid", async () => {
    const [owner] = await ethers.getSigners();

    const duration: bigint = BigInt(24 * 60 * 60);
    const aid: bigint = BigInt(1);
    const tid: bigint = BigInt(1);
    
    await createNFT(auction, nft, owner, tid)
    await createAuction(aid, auction, auctionMembers, auctionBids, owner, duration, tid);
    await addAuctionMember(aid, identities[0], auction, auctionMembers);
    await addAuctionMember(aid, identities[1], auction, auctionMembers);
    await addAuctionMember(aid, identities[2], auction, auctionMembers);

    await mintTokens(auction, token, identities[0].addr, BigInt(100000000))
    await mintTokens(auction, token, identities[1].addr, BigInt(100000000))
    await mintTokens(auction, token, identities[2].addr, BigInt(100000000))

    await depositFunds(auction, escrowTree, escrowBal, identities[0], BigInt(1000))
    await depositFunds(auction, escrowTree, escrowBal, identities[1], BigInt(10000000))
    await depositFunds(auction, escrowTree, escrowBal, identities[2], BigInt(10000))
    await depositFunds(auction, escrowTree, escrowBal, identities[2], BigInt(10000))

    const bidTimestamp = await auction.getStartTimestamp(aid);
    await time.increaseTo(bidTimestamp)

    await bid(auction, aid, auctionMembers, auctionBids, escrowTree, escrowBal, identities[0], BigInt(0), BigInt(100));
    await bid(auction, aid, auctionMembers, auctionBids, escrowTree, escrowBal, identities[1], BigInt(1), BigInt(1000));
    await bid(auction, aid, auctionMembers, auctionBids, escrowTree, escrowBal, identities[2], BigInt(2), BigInt(20000));
  })

  it("complete", async () => {
    const [owner] = await ethers.getSigners();

    const duration: bigint = BigInt(24 * 60 * 60);
    const aid: bigint = BigInt(1);
    const tid: bigint = BigInt(1);
    
    await createNFT(auction, nft, owner, tid)
    await createAuction(aid, auction, auctionMembers, auctionBids, owner, duration, tid);
    await addAuctionMember(aid, identities[0], auction, auctionMembers);
    await addAuctionMember(aid, identities[1], auction, auctionMembers);
    await addAuctionMember(aid, identities[2], auction, auctionMembers);

    await mintTokens(auction, token, identities[0].addr, BigInt(100000000))
    await mintTokens(auction, token, identities[1].addr, BigInt(100000000))
    await mintTokens(auction, token, identities[2].addr, BigInt(100000000))

    await depositFunds(auction, escrowTree, escrowBal, identities[0], BigInt(1000))
    await depositFunds(auction, escrowTree, escrowBal, identities[1], BigInt(10000000))
    await depositFunds(auction, escrowTree, escrowBal, identities[2], BigInt(10000))
    await depositFunds(auction, escrowTree, escrowBal, identities[2], BigInt(10000))

    const bidTimestamp = await auction.getStartTimestamp(aid);
    await time.increaseTo(bidTimestamp)

    await bid(auction, aid, auctionMembers, auctionBids, escrowTree, escrowBal, identities[0], BigInt(0), BigInt(100));
    await bid(auction, aid, auctionMembers, auctionBids, escrowTree, escrowBal, identities[1], BigInt(1), BigInt(1000));
    await bid(auction, aid, auctionMembers, auctionBids, escrowTree, escrowBal, identities[2], BigInt(2), BigInt(20000));

    const revealTimestamp = await auction.getRevealTimestamp(aid)
    await time.increaseTo(revealTimestamp)

    await reveal(auction, aid, auctionBids, identities[0], BigInt(100), BigInt(3));
    await reveal(auction, aid, auctionBids, identities[2], BigInt(20000), BigInt(5));

    const endTimestamp = await auction.getAuctionCompleteTimestamp(aid)
    await time.increaseTo(endTimestamp);

    await refund(auction, aid, escrowTree, escrowBal, auctionBids, identities[0], BigInt(100))
    await refund(auction, aid, escrowTree, escrowBal, auctionBids, identities[1], BigInt(1000))

    await distribute(auction, token, nft, aid, owner, identities[2], tid, BigInt(20000))

    await withdrawFunds(auction, escrowTree, escrowBal, identities[1], BigInt(7), BigInt(10000000))
  })
});