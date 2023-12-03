pragma solidity =0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {Starport, Stargate} from "starport-core/Starport.sol";

import {Consideration} from "seaport-core/src/lib/Consideration.sol";
import {Custodian} from "starport-core/Custodian.sol";

import {SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {Originator} from "starport-core/originators/Originator.sol";
import {AstariaV1Pricing} from "src/pricing/AstariaV1Pricing.sol";
import {AstariaV1Settlement} from "src/settlement/AstariaV1Settlement.sol";
import {AstariaV1Status} from "src/status/AstariaV1Status.sol";

contract Deploy is Script {
    Consideration public constant seaport = Consideration(payable(0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC));
    Account public borrower;
    Account public lender;
    Account public strategist;
    Account public deployer;
    Account public liquidator;

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

        vm.stopBroadcast();

        if (forkNet) {
//            seedOriginationData();
        }

        string memory contracts = "contracts";

        vm.serializeAddress(contracts, "Consideration", address(seaport));
        vm.serializeAddress(contracts, "Starport", address(SP));
        vm.serializeAddress(contracts, "Custodian", SP.defaultCustodian());

        vm.serializeAddress(contracts, "V1Pricing", address(v1Pricing));
        vm.serializeAddress(contracts, "V1Settlement", address(v1Settlement));
        string memory output = vm.serializeAddress(contracts, "V1Status", address(v1Status));

        vm.writeJson(output, "./out/contract-addresses.json");
    }


//    function seedOriginationData() internal {
//        uint256 liquidatorKey = vm.envUint("LIQUIDATOR_PRIVATE_KEY");
//        liquidator = Account({addr: vm.addr(liquidatorKey), key: liquidatorKey});
//
//        fund(FundingData({originatorDeposit: 1000 ether, liquidatorFunding: 1 ether}));
//
//        //non-liquidatable borrow
//        borrow(
//            RacerPricing.Details({
//                profitShare: 5e16,
//                rate: (uint256(1e16) * 150) / (365 * 1 days),
//                sellPriceAtOrigination: 0
//            }),
//            0x0,
//            0x0
//        );
//
//        //liquidatable borrow
//        borrow(RacerPricing.Details({profitShare: 5e16, rate: type(uint64).max, sellPriceAtOrigination: 0}), 0x0, 0x1);
//    }

    struct FundingData {
        uint256 originatorDeposit;
        uint256 liquidatorFunding;
    }

//    function fund(FundingData memory data) internal {
//        vm.startBroadcast(lender.key);
//        payable(address(ftOriginator)).transfer(data.originatorDeposit);
//        payable(address(liquidator.addr)).transfer(data.liquidatorFunding);
//        vm.stopBroadcast();
//    }

//    function borrow(RacerPricing.Details memory pricingDetails, uint256 offerSalt, uint256 obligationSalt) internal {
//        bytes memory pricingData = abi.encode(pricingDetails);
//
//        bytes memory hookData = abi.encode(RacerMarginHook.Details({margin: 0.0000001 ether}));
//
//        bytes memory handlerData = bytes("");
//
//        LoanManager.Terms memory terms = LoanManager.Terms({
//            pricing: address(ftPricing),
//            pricingData: pricingData,
//            hook: address(ftMarginHook),
//            hookData: hookData,
//            handler: address(fthandler),
//            handlerData: handlerData
//        });
//
//        SpentItem[] memory collateral = new SpentItem[](1);
//        collateral[0] = SpentItem({
//            itemType: ItemType.ERC1155,
//            token: address(wrappedFtShares),
//            identifier: uint256(uint160(shareSubject)),
//            amount: 1
//        });
//
//        //debt
//
//        SpentItem[] memory debt = new SpentItem[](1);
//        debt[0] = SpentItem({itemType: ItemType.NATIVE, token: address(0), identifier: 0, amount: 1 ether});
//
//        Originator.Details memory details = Originator.Details({
//            custodian: address(loanManager.defaultCustodian()),
//            conduit: address(0),
//            issuer: address(ftOriginator),
//            deadline: block.timestamp + 1 hours,
//            offer: Originator.Offer({salt: bytes32(offerSalt), terms: terms, collateral: collateral, debt: debt})
//        });
//
//        bytes memory encodedDetails = abi.encode(details);
//
//        (uint8 v, bytes32 r, bytes32 s) =
//                            vm.sign(strategist.key, keccak256(ftOriginator.encodeWithAccountCounter(keccak256(abi.encode(details)))));
//
//        bytes memory signature = abi.encodePacked(r, s, v);
//
//        LoanManager.Obligation memory obligation = LoanManager.Obligation({
//            custodian: loanManager.defaultCustodian(),
//            debt: debt,
//            originator: address(ftOriginator),
//            borrower: borrower.addr,
//            salt: bytes32(obligationSalt),
//            caveats: new LoanManager.Caveat[](0),
//            details: encodedDetails,
//            approval: signature
//        });
//
//        uint256 buyPrice = wrappedFtShares.FT().getBuyPriceAfterFee(shareSubject, 1);
//
//        vm.broadcast(borrower.key);
//        racerHelper.buyWithObligation{value: buyPrice}(obligation);
//    }
}
