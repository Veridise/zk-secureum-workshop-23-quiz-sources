//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// 2019 OKIMS
//      ported to solidity 0.6
//      fixed linter warnings
//      added requiere error messages
//
//
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
library Pairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the generator of G2
    function P2() internal pure returns (G2Point memory) {
        // Original code point
        return G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );

/*
        // Changed by Jordi point
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
*/
    }
    /// @return r the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) internal pure returns (G1Point memory r) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-add-failed");
    }
    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success,"pairing-mul-failed");
    }
    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length,"pairing-lengths-failed");
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }
        uint[1] memory out;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-opcode-failed");
        return out[0] != 0;
    }
    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}
contract Verifier {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[] IC;
    }
    struct Proof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }
    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = Pairing.G1Point(
            20491192805390485299153009773594534940189261866228447918068658471970481763042,
            9383485363053290200918347156157836566562967994039712273449902621266178545958
        );

        vk.beta2 = Pairing.G2Point(
            [4252822878758300859123897981450591353533073413197771768651442665752259397132,
             6375614351688725206403948262868962793625744043794305715222011528459656738731],
            [21847035105528745403288232691147584728191162732299865338377159692350059136679,
             10505242626370262277552901082094356697409835680220590971873171140371331206856]
        );
        vk.gamma2 = Pairing.G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );
        vk.delta2 = Pairing.G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );
        vk.IC = new Pairing.G1Point[](27);
        
        vk.IC[0] = Pairing.G1Point( 
            13380310948371072983829318994373810800614552381219514344344680442484993641856,
            15165277070951985483624402363099710307968827956806400166759017171383617208627
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            16532881341579010253167332614863553229446333259042089240412154510712222606359,
            18720899708488910727303750161344658382425607619138968675134666740297605410372
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            399649084354194837022511277071713384395123158461921043308675667604890812485,
            20070911448904364514010012621631370839357545516878333604602703147842944677267
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            13850646603571478072244585604507027871335338497430405036442556003256649394309,
            16338946783903911462979566552365674873691333227659096266826093396598135420592
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            3848268964485835663789103891110699628190388824521942714292618409998124349787,
            6323170980831765520280475180153269583816024423270357093089532230316449586011
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            2744735298482036383064180514700415216634436757730000329993814225192239415842,
            6401002879460023233003867231165578913921545108725699532991540105945662521665
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            10375719976993996709896221728768398283872766456242600169731779855077691510074,
            1507997408391911169053738965722073285608283781646121376711695264487366827901
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            13717898212726181641661899299807662926621586686322245405217521723770870655397,
            11152519499060042400653196617451470980712911929138706695834156320975184690001
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            9695679786412323368881148846670011577282776383184516776748777756895395708429,
            1908869464187386824726836837102482170151753427347428119758045913677712253314
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            12489948093932363396689175101209103400682351553875409473179590426296764107309,
            16726492632683987447448724052817361668539669640826993395891677309997537266527
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            8793447246887791370258486535839864481471593181852062479126704692070443535715,
            9256915458252109845500886766448382379121236474287383989751455903864102526583
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            18442915476953070244172677606959950143899232968122670997888111850156777105867,
            8997875233439486292404732768381643907441064296492165072004216789672242801808
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            9296984304038996723258851132566851759262217177262702825880567733390378348937,
            6201100632088490255233012141796330444336968575013767534035957110047137111373
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            4690489861296462493416260978901617766894159330382198256110135430603415830027,
            21010556110455133823635134059127073545745006555317805694838108554907958173551
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            4173783067458558559877242274839232111277344995436687466109925122167648278732,
            133018604593223874696625039329223924569632885570947106411642358112790788868
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            18689380730917097949246651107221508631524157878802615028707295655514416098535,
            10994608943542226504347246959064214139950302821063620414119782506261923994261
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            5639452669961134295406584371879362457810376900899882499589033572167569112953,
            21183052326977034823636021366150207342765414405383383401822697003416469134165
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            3578431312709592909565941833366552741209906024786528383278177419770563796761,
            6176757393663767890388325986374921664836650461838404864774144387285238589761
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            17593604575204880738472953622321155207454605387316053360633147863939843814119,
            15505159338275379527607148952072365059444545230583485520559430251094801839813
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            11710417322603320100258003482476578024642444295256786739434792128067594083196,
            2057949181638196191548036606620590722594340411139278603864557286277264029088
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            21083616588775008095361244307290251811844526478722118757659419361751635508800,
            3682003505253344668294843679522996572892466935724210735777217863893268593713
        );                                      
        
        vk.IC[21] = Pairing.G1Point( 
            3937594781960059558740015844043904430741407499621542929817695337477426958491,
            104722975534588144867984153706736528187474470202053206888206483025963261932
        );                                      
        
        vk.IC[22] = Pairing.G1Point( 
            662004026608622003313996310141041035749510614712465675848982886774943378275,
            9935282519074100816080239984634307516294515101559923375632926748191179069818
        );                                      
        
        vk.IC[23] = Pairing.G1Point( 
            11813002400325716867321353631962674902367037192828249516482141739281697183515,
            16416616723370723981588071656809831652003657792389029432578643793187705324224
        );                                      
        
        vk.IC[24] = Pairing.G1Point( 
            18447346197430709720852128930975174982125509832037915642735518200914753745135,
            6443232719099021076037277750589185214357708393143832420548873517640702016160
        );                                      
        
        vk.IC[25] = Pairing.G1Point( 
            7687449077852038410380882671953646128471040214532000296059414886719901240394,
            7207317903999297992980171485584758986078625695235505190820191375867741333404
        );                                      
        
        vk.IC[26] = Pairing.G1Point( 
            16376276443354010565177151376979962031715754522659922553914667971546687271885,
            11358231843218464344671404575016208838656640498646160365488122090842703336170
        );                                      
        
    }
    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.IC.length,"verifier-bad-input");
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field,"verifier-gte-snark-scalar-field");
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.IC[0]);
        if (!Pairing.pairingProd4(
            Pairing.negate(proof.A), proof.B,
            vk.alfa1, vk.beta2,
            vk_x, vk.gamma2,
            proof.C, vk.delta2
        )) return 1;
        return 0;
    }
    /// @return r  bool true if proof is valid
    function verifyProof(
            uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[26] memory input
        ) public view returns (bool r) {
        Proof memory proof;
        proof.A = Pairing.G1Point(a[0], a[1]);
        proof.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        proof.C = Pairing.G1Point(c[0], c[1]);
        uint[] memory inputValues = new uint[](input.length);
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}
