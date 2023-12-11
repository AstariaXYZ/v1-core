pragma solidity =0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {Starport, Stargate, CaveatEnforcer, AdditionalTransfer} from "starport-core/Starport.sol";
import {TestERC20, TestERC721} from "starport-test/StarportTest.sol";
import {Consideration} from "seaport-core/src/lib/Consideration.sol";
import {Custodian} from "starport-core/Custodian.sol";
import {AstariaV1LenderEnforcer} from "src/enforcers/AstariaV1LenderEnforcer.sol";
import {SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {Originator} from "starport-core/originators/Originator.sol";
import {AstariaV1Pricing, BasePricing} from "src/pricing/AstariaV1Pricing.sol";
import {AstariaV1Settlement, DutchAuctionSettlement} from "src/settlement/AstariaV1Settlement.sol";
import {AstariaV1Status, BaseRecall} from "src/status/AstariaV1Status.sol";

contract Deploy is Script {
    Consideration public constant seaport = Consideration(payable(0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC));
    Account public borrower;
    Account public lender;
    Account public strategist;
    Account public deployer;
    Account public liquidator;

    TestERC20 public erc20;
    TestERC721 public erc721;

    //    Starport public SP = Starport(address(0x75573d1dff9e2efe784d089f882a5ea320dd96f0));
    Starport public SP;
    AstariaV1Pricing public v1Pricing;
    AstariaV1Status public v1Status;
    AstariaV1Settlement public v1Settlement;

    //    RacerOriginator public ftOriginator;
    //    RacerPricing public ftPricing;
    //    RacerHandler public fthandler;
    //    RacerMarginHook public ftMarginHook;
    //    RacerHelper public racerHelper;

    bool forkNet = false;

    function run() public {
        if (vm.envBool("IS_FORK")) {
            forkNet = true;
        }
        string memory anvilConfig = vm.readFile("./out/anvil-config.json");
        address[] memory accounts = vm.parseJsonAddressArray(anvilConfig, ".available_accounts");
        uint256[] memory privateKeys = vm.parseJsonUintArray(anvilConfig, ".private_keys");
        uint256 deployerIndex = accounts.length - 1;
        borrower = Account({addr: accounts[0], key: privateKeys[0]});
        lender = Account({addr: accounts[1], key: privateKeys[1]});
        strategist = Account({addr: accounts[2], key: privateKeys[2]});
        deployer = Account({addr: accounts[deployerIndex], key: privateKeys[deployerIndex]});

        run1();
    }

    function run1() public {
        console.log("Deploying contracts");

        address originatorStrategist;
        address originatorOwner;
        if (forkNet) {
            vm.startBroadcast(deployer.key);
            originatorStrategist = strategist.addr;
            originatorOwner = deployer.addr;
        } else {
            originatorStrategist = msg.sender;
            originatorOwner = msg.sender;
            vm.startBroadcast();
        }

        SP = new Starport(address(seaport), Stargate(address(0)));

        v1Pricing = new AstariaV1Pricing(SP);
        v1Status = new AstariaV1Status(SP);
        v1Settlement = new AstariaV1Settlement(SP);
        AstariaV1LenderEnforcer lenderEnforcer = new AstariaV1LenderEnforcer();
        erc20 = new TestERC20();
        erc721 = new TestERC721();
        erc20.mint(address(lender.addr), 10e18);
        erc721.mint(address(borrower.addr), 1);
        erc721.mint(address(borrower.addr), 2);
        vm.stopBroadcast();

        vm.startBroadcast(borrower.key);
        erc721.setApprovalForAll(address(SP), true);
        vm.stopBroadcast();
        vm.startBroadcast(lender.key);
        erc20.approve(address(SP), 10e18);
        vm.stopBroadcast();

        seedOriginationData();

        string memory contracts = "contracts";

        vm.serializeAddress(contracts, "Consideration", address(seaport));
        vm.serializeAddress(contracts, "Starport", address(SP));
        vm.serializeAddress(contracts, "Custodian", SP.defaultCustodian());

        vm.serializeAddress(contracts, "V1Pricing", address(v1Pricing));
        vm.serializeAddress(contracts, "V1Settlement", address(v1Settlement));
        vm.serializeAddress(contracts, "ERC20Debt", address(erc20));
        vm.serializeAddress(contracts, "ERC721Collateral", address(erc721));
        vm.serializeUint(contracts, "block_number", block.number);
        string memory output = vm.serializeAddress(contracts, "V1Status", address(v1Status));

        vm.writeJson(output, "./out/contract-addresses.json");
    }

    function seedOriginationData() internal {
        uint256 liquidatorKey = vm.envUint("LIQUIDATOR_PRIVATE_KEY");
        liquidator = Account({addr: vm.addr(liquidatorKey), key: liquidatorKey});

        fund(FundingData({originatorDeposit: 1000 ether, liquidatorFunding: 1 ether}));

        //non-liquidatable borrow

        bytes memory pricingDetails =
            abi.encode(BasePricing.Details({rate: 0.0000001 ether, carryRate: 0.0000001 ether, decimals: 18}));

        borrow(pricingDetails);

        //liquidatable borrow
        //        borrow(pricingDetails, 0x0, 0x1);
    }

    struct FundingData {
        uint256 originatorDeposit;
        uint256 liquidatorFunding;
    }

    function fund(FundingData memory data) internal {
        vm.startBroadcast(lender.key);
        payable(address(liquidator.addr)).transfer(data.liquidatorFunding);
        vm.stopBroadcast();
    }

    function borrow(bytes memory pricingData) internal {
        bytes memory statusData = abi.encode(
            BaseRecall.Details({
                honeymoon: 7 days,
                recallWindow: 7 days,
                recallStakeDuration: 7 days,
                recallMax: 10e18,
                recallerRewardRatio: 0.5 ether
            })
        );

        bytes memory settlementData =
            abi.encode(DutchAuctionSettlement.Details({startingPrice: 100 ether, endingPrice: 100 wei, window: 7 days}));

        Starport.Terms memory terms = Starport.Terms({
            pricing: address(v1Pricing),
            pricingData: pricingData,
            status: address(v1Status),
            statusData: statusData,
            settlement: address(v1Settlement),
            settlementData: settlementData
        });

        SpentItem[] memory collateral = new SpentItem[](1);
        collateral[0] = SpentItem({itemType: ItemType.ERC721, token: address(erc721), identifier: 1, amount: 1});

        //debt

        SpentItem[] memory debt = new SpentItem[](1);
        debt[0] = SpentItem({itemType: ItemType.ERC20, token: address(erc20), identifier: 0, amount: 1 ether});

        CaveatEnforcer.SignedCaveats memory caveatsB;
        //bool singleUse;
        //        uint256 deadline;
        //        bytes32 salt;
        //        Caveat[] caveats;
        //        bytes signature;
        CaveatEnforcer.SignedCaveats memory caveats = CaveatEnforcer.SignedCaveats({
            singleUse: true,
            deadline: block.timestamp + 100,
            salt: bytes32(0),
            caveats: new CaveatEnforcer.Caveat[](0),
            signature: ""
        });
        //function hashCaveatWithSaltAndNonce(
        //        address account,
        //        bool singleUse,
        //        bytes32 salt,
        //        uint256 deadline,
        //        CaveatEnforcer.Caveat[] calldata caveats
        //    )

        bytes32 hash = SP.hashCaveatWithSaltAndNonce(lender.addr, true, 0, block.timestamp + 100, caveats.caveats);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(lender.key, hash);
        caveats.signature = abi.encodePacked(r, s, v);

        // uint256 start; // start of the loan
        //        address custodian; // where the collateral is being held
        //        address borrower; // the borrower
        //        address issuer; // the capital issuer/lender
        //        address originator; // who originated the loan
        //        SpentItem[] collateral; // array of collateral
        //        SpentItem[] debt; // array of debt
        //        Terms terms; //
        Starport.Loan memory loan = Starport.Loan({
            issuer: lender.addr,
            custodian: SP.defaultCustodian(),
            originator: lender.addr,
            borrower: borrower.addr,
            terms: terms,
            collateral: collateral,
            debt: debt,
            start: 0
        });
        vm.broadcast(borrower.key);
        SP.originate(new AdditionalTransfer[](0), caveatsB, caveats, loan);
    }
}