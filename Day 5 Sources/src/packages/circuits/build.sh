wget https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_14.ptau
circom mains/auction_bid.circom --r1cs --wasm --sym
circom mains/balance_membership.circom --r1cs --wasm --sym
snarkjs powersoftau prepare phase2 powersOfTau28_hez_final_14.ptau pot_final.ptau -v
snarkjs groth16 setup balance_membership.r1cs pot_final.ptau membership.zkey
snarkjs groth16 setup auction_bid.r1cs pot_final.ptau bid.zkey
snarkjs zkey export verificationkey membership.zkey membership_key.json
snarkjs zkey export verificationkey bid.zkey bid_key.json
snarkjs zkey export solidityverifier membership.zkey verifier.sol
mv verifier.sol ../contracts/contracts/base/MembershipVerifier
snarkjs zkey export solidityverifier bid.zkey verifier.sol
mv verifier.sol ../contracts/contracts/base/BidVerifier
