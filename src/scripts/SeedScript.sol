pragma solidity =0.8.17;
import {LibString} from "solady/src/utils/LibString.sol";
import {Vm} from "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import {Starport, Stargate, CaveatEnforcer, AdditionalTransfer} from "starport-core/Starport.sol";
import {TestERC20, TestERC721, TestERC1155} from "starport-test/StarportTest.sol";
import {Consideration} from "seaport-core/src/lib/Consideration.sol";
import {Custodian} from "starport-core/Custodian.sol";
import {StarportLib, Actions} from "starport-core/lib/StarportLib.sol";
import {AstariaV1LenderEnforcer} from "src/enforcers/AstariaV1LenderEnforcer.sol";
import {SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {Originator} from "starport-core/originators/Originator.sol";
import {AstariaV1Pricing, BasePricing} from "src/pricing/AstariaV1Pricing.sol";
import {AstariaV1Settlement, DutchAuctionSettlement} from "src/settlement/AstariaV1Settlement.sol";
import {AstariaV1Status, BaseRecall} from "src/status/AstariaV1Status.sol";
import {
    ItemType,
    ReceivedItem,
    OfferItem,
    SpentItem,
    OrderParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {
    ConsiderationItem,
    AdvancedOrder,
    CriteriaResolver,
    Fulfillment,
    FulfillmentComponent,
    OrderType
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {Settlement} from "starport-core/settlement/Settlement.sol";
import {Pricing} from "starport-core/pricing/Pricing.sol";
import {Status} from "starport-core/status/Status.sol";
contract ScriptSetup is Script {
    Consideration public constant seaport = Consideration(payable(0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC));
    Account public borrower;
    Account public lender;
    Account public strategist;
    Account public deployer;
    Account public liquidator;

    TestERC20 public erc20;
    TestERC721 public erc721;
    TestERC1155 public erc1155;

    //    Starport public SP = Starport(address(0x75573d1dff9e2efe784d089f882a5ea320dd96f0));
    Starport public SP;
    AstariaV1Pricing public v1Pricing;
    AstariaV1Status public v1Status;
    AstariaV1Settlement public v1Settlement;

    bool forkNet = false;

    function setUp() public {
        string memory anvilConfig = vm.readFile("./out/anvil-config.json");
        string memory deployedContracts = vm.readFile("./out/contract-addresses.json");
        address[] memory accounts = vm.parseJsonAddressArray(anvilConfig, ".available_accounts");
        uint256[] memory privateKeys = vm.parseJsonUintArray(anvilConfig, ".private_keys");
        uint256 deployerIndex = accounts.length - 1;
        borrower = Account({addr: accounts[0], key: privateKeys[0]});
        lender = Account({addr: accounts[1], key: privateKeys[1]});
        strategist = Account({addr: accounts[2], key: privateKeys[2]});
        deployer = Account({addr: accounts[deployerIndex], key: privateKeys[deployerIndex]});

        SP = Starport(vm.parseJsonAddress(deployedContracts, ".Starport"));
        v1Pricing = AstariaV1Pricing(vm.parseJsonAddress(deployedContracts, ".V1Pricing"));
        v1Status = AstariaV1Status(vm.parseJsonAddress(deployedContracts, ".V1Status"));
        v1Settlement = AstariaV1Settlement(vm.parseJsonAddress(deployedContracts, ".V1Settlement"));
        erc20 = TestERC20(vm.parseJsonAddress(deployedContracts, ".ERC20Debt"));
        erc721 = TestERC721(vm.parseJsonAddress(deployedContracts, ".ERC721Collateral"));
        erc1155 = TestERC1155(vm.parseJsonAddress(deployedContracts, ".ERC1155Collateral"));

    }
}

contract SeedScript is ScriptSetup {


    function recall(uint256 loanId) public {
        vm.startBroadcast(lender.key);
        Starport.Loan memory loan = _fetchLoan(loanId);
        BaseRecall(loan.terms.status).recall(loan);
        vm.stopBroadcast();
    }


    function repay(uint256 loanId) public {
        Starport.Loan memory loan = _fetchLoan(loanId);

        (SpentItem[] memory offer, ReceivedItem[] memory paymentConsideration) = Custodian(payable(loan.custodian))
            .previewOrder(
            address(seaport),
            loan.borrower,
            new SpentItem[](0),
            new SpentItem[](0),
            abi.encode(Custodian.Command(Actions.Repayment, loan, ""))
        );

        OrderParameters memory op = _buildContractOrder(
            address(loan.custodian), _SpentItemsToOfferItems(offer), _toConsiderationItems(paymentConsideration)
        );
        AdvancedOrder memory x = AdvancedOrder({
            parameters: op,
            numerator: 1,
            denominator: 1,
            signature: "0x",
            extraData: abi.encode(Custodian.Command(Actions.Repayment, loan, ""))
        });

//        seaport.fulfillAdvancedOrder({
//            advancedOrder: x,
//            criteriaResolvers: new CriteriaResolver[](0),
//            fulfillerConduitKey: bytes32(0),
//            recipient: address(0)
//        });
        seaport.fulfillAdvancedOrder(x, new CriteriaResolver[](0), bytes32(0), address(0));

    }

    function generate() public {
        SpentItem[] memory collateral = new SpentItem[](1);
        collateral[0] = SpentItem({itemType: ItemType.ERC721, token: address(erc721), identifier: block.number, amount: 1});

        //debt

        SpentItem[] memory debt = new SpentItem[](1);
        debt[0] = SpentItem({itemType: ItemType.ERC20, token: address(erc20), identifier: 0, amount: 10});

        _borrow(
            collateral,
            debt,
            abi.encode(BasePricing.Details({rate: 0.0000001 ether, carryRate: 0.0000001 ether, decimals: 18})),
            abi.encode(
                BaseRecall.Details({
                    honeymoon: 7 days,
                    recallWindow: 7 days,
                    recallStakeDuration: 7 days,
                    recallMax: 10e18,
                    recallerRewardRatio: 0.5 ether
                })
            ),
            abi.encode(DutchAuctionSettlement.Details({startingPrice: 100 ether, endingPrice: 100 wei, window: 7 days}))
        );

        //liquidatable borrow
        collateral[0] = SpentItem({itemType: ItemType.ERC721, token: address(erc721), identifier: block.number - 1, amount: 1});
        _borrow(
            collateral,
            debt,
            abi.encode(BasePricing.Details({rate: 0.0000001 ether, carryRate: 0.0000001 ether, decimals: 18})),
            abi.encode(
                BaseRecall.Details({
                    honeymoon: 0,
                    recallWindow: 0,
                    recallStakeDuration: 0,
                    recallMax: 10e18,
                    recallerRewardRatio: 0.1 ether
                })
            ),
            abi.encode(DutchAuctionSettlement.Details({startingPrice: 100 ether, endingPrice: 100 wei, window: 7 days}))
        );
    }

    function _borrow(SpentItem[] memory collateral, SpentItem[] memory debt, bytes memory pricingData, bytes memory statusData, bytes memory settlementData) internal {
        Starport.Terms memory terms = Starport.Terms({
            pricing: address(v1Pricing),
            pricingData: pricingData,
            status: address(v1Status),
            statusData: statusData,
            settlement: address(v1Settlement),
            settlementData: settlementData
        });

        CaveatEnforcer.SignedCaveats memory caveatsB;

        CaveatEnforcer.SignedCaveats memory caveats = CaveatEnforcer.SignedCaveats({
            singleUse: false,
            deadline: block.timestamp + 100,
            salt: bytes32(0),
            caveats: new CaveatEnforcer.Caveat[](0),
            signature: ""
        });

        bytes32 hash = SP.hashCaveatWithSaltAndNonce(lender.addr, caveats.singleUse, caveats.salt, caveats.deadline, caveats.caveats);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(lender.key, hash);
        caveats.signature = abi.encodePacked(r, s, v);


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

        vm.startBroadcast(borrower.key);
        erc721.mint(borrower.addr, loan.collateral[0].identifier);
        erc20.mint(lender.addr, loan.debt[0].amount);

        SP.originate(new AdditionalTransfer[](0), caveatsB, caveats, loan);
        vm.stopBroadcast();
    }


    function settle(uint256 loanId) public {
        Starport.Loan memory activeLoan = _fetchLoan(loanId);
        Custodian.Command memory command = Custodian.Command({action: Actions.Settlement, loan: activeLoan, extraData: ""});
        (ReceivedItem[] memory settlementConsideration, address authorized) =
                                Settlement(activeLoan.terms.settlement).getSettlementConsideration(activeLoan);
        settlementConsideration = StarportLib.removeZeroAmountItems(settlementConsideration);
        ConsiderationItem[] memory consider = new ConsiderationItem[](settlementConsideration.length);
        uint256 i = 0;
        for (; i < settlementConsideration.length;) {
            consider[i].token = settlementConsideration[i].token;
            consider[i].itemType = settlementConsideration[i].itemType;
            consider[i].identifierOrCriteria = settlementConsideration[i].identifier;
            consider[i].startAmount = settlementConsideration[i].amount;
            consider[i].endAmount = settlementConsideration[i].amount;
            consider[i].recipient = settlementConsideration[i].recipient;
            unchecked {
                ++i;
            }
        }
        OfferItem[] memory repayOffering = new OfferItem[](activeLoan.collateral.length);
        i = 0;
        for (; i < activeLoan.collateral.length;) {
            repayOffering[i] = OfferItem({
                itemType: activeLoan.collateral[i].itemType,
                token: address(activeLoan.collateral[i].token),
                identifierOrCriteria: activeLoan.collateral[i].identifier,
                endAmount: activeLoan.collateral[i].itemType != ItemType.ERC721 ? activeLoan.collateral[i].amount : 1,
                startAmount: activeLoan.collateral[i].itemType != ItemType.ERC721 ? activeLoan.collateral[i].amount : 1
            });
            unchecked {
                ++i;
            }
        }

        OrderParameters memory op = _buildContractOrder(address(activeLoan.custodian), repayOffering, consider);
        AdvancedOrder memory settlementOrder = AdvancedOrder({
            numerator: 1,
            denominator: 1,
            parameters: op,
            extraData: abi.encode(Custodian.Command(Actions.Settlement, activeLoan, "")),
            signature: ""
        });
/*

        seaport.fulfillAdvancedOrder({
            advancedOrder: settlementOrder,
            criteriaResolvers: new CriteriaResolver[](0),
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
*/

        seaport.fulfillAdvancedOrder(settlementOrder, new CriteriaResolver[](0), bytes32(0), address(0));
        vm.stopBroadcast();
    }

    function _fetchLoan(uint256 loanId) internal returns (Starport.Loan memory) {
        string[] memory ffiScript = new string[](3);
        ffiScript[0] = "ts-node";
        ffiScript[1] = "ffi-scripts/fetch-loan.ts";
        ffiScript[2] = LibString.toString(loanId);

        bytes memory encodedLoan = vm.ffi(ffiScript);

        return abi.decode(encodedLoan, (Starport.Loan));
    }

    function _buildContractOrder(address offerer, OfferItem[] memory offer, ConsiderationItem[] memory consider)
    internal
    view
    returns (OrderParameters memory op)
    {
        op = OrderParameters({
            offerer: offerer,
            zone: address(0),
            offer: offer,
            consideration: consider,
            orderType: OrderType.CONTRACT,
            startTime: block.timestamp,
            endTime: block.timestamp + 100,
            zoneHash: bytes32(0),
            salt: 0,
            conduitKey: bytes32(0),
            totalOriginalConsiderationItems: consider.length
        });
    }

    function _SpentItemsToOfferItems(SpentItem[] memory items) internal pure returns (OfferItem[] memory) {
        OfferItem[] memory copiedItems = new OfferItem[](items.length);
        for (uint256 i = 0; i < items.length; i++) {
            copiedItems[i] = _SpentItemToOfferItem(items[i]);
        }
        return copiedItems;
    }
    function _SpentItemToOfferItem(SpentItem memory item) internal pure returns (OfferItem memory) {
        return OfferItem({
            itemType: item.itemType,
            token: item.token,
            identifierOrCriteria: item.identifier,
            startAmount: item.amount,
            endAmount: item.amount
        });
    }

    function _toConsiderationItems(ReceivedItem[] memory _receivedItems)
    internal
    pure
    returns (ConsiderationItem[] memory)
    {
        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](_receivedItems.length);
        for (uint256 i = 0; i < _receivedItems.length; ++i) {
            considerationItems[i] = ConsiderationItem(
                _receivedItems[i].itemType,
                _receivedItems[i].token,
                _receivedItems[i].identifier,
                _receivedItems[i].amount,
                _receivedItems[i].amount,
                _receivedItems[i].recipient
            );
        }
        return considerationItems;
    }
}