# zkAuction
This repository implements a Sealed-Bid auction. The auction starts when an admin (or rather the owner of the auctioned token) creates an auction and invites users to participate. For a user to bid in the auction, they must first deposit funds into the auction which effectively represents their maximum bid in the auction. All funds in the protocol are represented as cryptographic notes that hide the exact value of the note, but can be spent via the ZK circuits to hide bidding values. Note that due to the nature of the deposits, the total value that a user may spend is technically public, but we believe that is an acceptable trade-off. During an auction, a user may then use any amount of their deposited funds to submit a bid via the protocol's circuits. Once they do so, these funds are locked in the auction and may not be retrieved or withdrawn until after the auction has been completed. After a certain amount of time, bidding will close and the auction will enter the reveal phase. During this phase, users have a certain amount of time to reveal their bids where the highest revealed bid wins. Note, users do not have to reveal their bid which allows some users to bluff others (by using their public maximum) but that only increases the fun of the auction. After the reveal period ends, the winner auction can distribute the funds from the winning bid to the admin/beneficiary and the NFT to the winner. All other users at this point may recover their bids, which places the funds back in the user's liquid balance (i.e. at this point it can be withdrawn).

## 🛠 Build
Build the dependencies:

```bash
yarn
```

Build the circuits and generate the verifiers:
```bash
cd packages/circuits && bash build.sh
```
Note: You may need to modify the solidity versions of the generated verifiers (at `packages/contracts/base/BidVerifier/verifier.sol` and `packages/contracts/base/MembershipVerifier.sol`) to have a solidity version of `^0.8.0`.

Build contracts:
```bash
yarn compile
```

### Testing

Test the contracts:

```bash
yarn test
```

