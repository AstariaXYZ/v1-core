import fetch from 'node-fetch';
import {encodeFunctionResult} from 'viem'
//require viem abiencode

const ABI = {
    "abi": [{
        "type": "function", "name": "encodeLoan", "inputs": [{
            "name": "loan",
            "type": "tuple",
            "internalType": "struct Starport.Loan",
            "components": [{"name": "start", "type": "uint256", "internalType": "uint256"}, {
                "name": "custodian",
                "type": "address",
                "internalType": "address"
            }, {"name": "borrower", "type": "address", "internalType": "address"}, {
                "name": "issuer",
                "type": "address",
                "internalType": "address"
            }, {"name": "originator", "type": "address", "internalType": "address"}, {
                "name": "collateral",
                "type": "tuple[]",
                "internalType": "struct SpentItem[]",
                "components": [{"name": "itemType", "type": "uint8", "internalType": "enum ItemType"}, {
                    "name": "token",
                    "type": "address",
                    "internalType": "address"
                }, {"name": "identifier", "type": "uint256", "internalType": "uint256"}, {
                    "name": "amount",
                    "type": "uint256",
                    "internalType": "uint256"
                }]
            }, {
                "name": "debt",
                "type": "tuple[]",
                "internalType": "struct SpentItem[]",
                "components": [{"name": "itemType", "type": "uint8", "internalType": "enum ItemType"}, {
                    "name": "token",
                    "type": "address",
                    "internalType": "address"
                }, {"name": "identifier", "type": "uint256", "internalType": "uint256"}, {
                    "name": "amount",
                    "type": "uint256",
                    "internalType": "uint256"
                }]
            }, {
                "name": "terms",
                "type": "tuple",
                "internalType": "struct Starport.Terms",
                "components": [{"name": "status", "type": "address", "internalType": "address"}, {
                    "name": "statusData",
                    "type": "bytes",
                    "internalType": "bytes"
                }, {"name": "pricing", "type": "address", "internalType": "address"}, {
                    "name": "pricingData",
                    "type": "bytes",
                    "internalType": "bytes"
                }, {"name": "settlement", "type": "address", "internalType": "address"}, {
                    "name": "settlementData",
                    "type": "bytes",
                    "internalType": "bytes"
                }]
            }]
        }], "outputs": [{
            "name": "",
            "type": "tuple",
            "internalType": "struct Starport.Loan",
            "components": [{"name": "start", "type": "uint256", "internalType": "uint256"}, {
                "name": "custodian",
                "type": "address",
                "internalType": "address"
            }, {"name": "borrower", "type": "address", "internalType": "address"}, {
                "name": "issuer",
                "type": "address",
                "internalType": "address"
            }, {"name": "originator", "type": "address", "internalType": "address"}, {
                "name": "collateral",
                "type": "tuple[]",
                "internalType": "struct SpentItem[]",
                "components": [{"name": "itemType", "type": "uint8", "internalType": "enum ItemType"}, {
                    "name": "token",
                    "type": "address",
                    "internalType": "address"
                }, {"name": "identifier", "type": "uint256", "internalType": "uint256"}, {
                    "name": "amount",
                    "type": "uint256",
                    "internalType": "uint256"
                }]
            }, {
                "name": "debt",
                "type": "tuple[]",
                "internalType": "struct SpentItem[]",
                "components": [{"name": "itemType", "type": "uint8", "internalType": "enum ItemType"}, {
                    "name": "token",
                    "type": "address",
                    "internalType": "address"
                }, {"name": "identifier", "type": "uint256", "internalType": "uint256"}, {
                    "name": "amount",
                    "type": "uint256",
                    "internalType": "uint256"
                }]
            }, {
                "name": "terms",
                "type": "tuple",
                "internalType": "struct Starport.Terms",
                "components": [{"name": "status", "type": "address", "internalType": "address"}, {
                    "name": "statusData",
                    "type": "bytes",
                    "internalType": "bytes"
                }, {"name": "pricing", "type": "address", "internalType": "address"}, {
                    "name": "pricingData",
                    "type": "bytes",
                    "internalType": "bytes"
                }, {"name": "settlement", "type": "address", "internalType": "address"}, {
                    "name": "settlementData",
                    "type": "bytes",
                    "internalType": "bytes"
                }]
            }]
        }], "stateMutability": "pure"
    }],
    "bytecode": {
        "object": "0x608060405234801561001057600080fd5b5061073e806100206000396000f3fe608060405234801561001057600080fd5b506004361061002b5760003560e01c806342699aa014610030575b600080fd5b61004361003e3660046103f6565b610059565b6040516100509190610640565b60405180910390f35b610061610065565b5090565b6040518061010001604052806000815260200160006001600160a01b0316815260200160006001600160a01b0316815260200160006001600160a01b0316815260200160006001600160a01b03168152602001606081526020016060815260200161011a6040518060c0016040528060006001600160a01b031681526020016060815260200160006001600160a01b031681526020016060815260200160006001600160a01b03168152602001606081525090565b905290565b634e487b7160e01b600052604160045260246000fd5b6040516080810167ffffffffffffffff811182821017156101585761015861011f565b60405290565b60405160c0810167ffffffffffffffff811182821017156101585761015861011f565b604051610100810167ffffffffffffffff811182821017156101585761015861011f565b604051601f8201601f1916810167ffffffffffffffff811182821017156101ce576101ce61011f565b604052919050565b80356001600160a01b03811681146101ed57600080fd5b919050565b600082601f83011261020357600080fd5b8135602067ffffffffffffffff82111561021f5761021f61011f565b61022d818360051b016101a5565b82815260079290921b8401810191818101908684111561024c57600080fd5b8286015b848110156102b457608081890312156102695760008081fd5b610271610135565b8135600681106102815760008081fd5b815261028e8286016101d6565b818601526040828101359082015260608083013590820152835291830191608001610250565b509695505050505050565b600082601f8301126102d057600080fd5b813567ffffffffffffffff8111156102ea576102ea61011f565b6102fd601f8201601f19166020016101a5565b81815284602083860101111561031257600080fd5b816020850160208301376000918101602001919091529392505050565b600060c0828403121561034157600080fd5b61034961015e565b9050610354826101d6565b8152602082013567ffffffffffffffff8082111561037157600080fd5b61037d858386016102bf565b602084015261038e604085016101d6565b604084015260608401359150808211156103a757600080fd5b6103b3858386016102bf565b60608401526103c4608085016101d6565b608084015260a08401359150808211156103dd57600080fd5b506103ea848285016102bf565b60a08301525092915050565b60006020828403121561040857600080fd5b813567ffffffffffffffff8082111561042057600080fd5b90830190610100828603121561043557600080fd5b61043d610181565b8235815261044d602084016101d6565b602082015261045e604084016101d6565b604082015261046f606084016101d6565b6060820152610480608084016101d6565b608082015260a08301358281111561049757600080fd5b6104a3878286016101f2565b60a08301525060c0830135828111156104bb57600080fd5b6104c7878286016101f2565b60c08301525060e0830135828111156104df57600080fd5b6104eb8782860161032f565b60e08301525095945050505050565b60008151808452602080850194508084016000805b8481101561057057825180516006811061053757634e487b7160e01b84526021600452602484fd5b8952808501516001600160a01b0316858a0152604080820151908a0152606090810151908901526080909701969183019160010161050f565b50959695505050505050565b6000815180845260005b818110156105a257602081850181015186830182015201610586565b506000602082860101526020601f19601f83011685010191505092915050565b600060018060a01b03808351168452602083015160c060208601526105ea60c086018261057c565b90508160408501511660408601526060840151858203606087015261060f828261057c565b91505081608085015116608086015260a0840151915084810360a0860152610637818361057c565b95945050505050565b60208152815160208201526000602083015161066760408401826001600160a01b03169052565b5060408301516001600160a01b03811660608401525060608301516001600160a01b03811660808401525060808301516001600160a01b03811660a08401525060a08301516101008060c08501526106c36101208501836104fa565b915060c0850151601f19808685030160e08701526106e184836104fa565b935060e08701519150808685030183870152506106fe83826105c2565b969550505050505056fea264697066735822122015c379aa17cb7929f5a432484729e36fa0a16c7a0214b29ff0886a435f9fbf8964736f6c63430008110033",
        "sourceMap": "78:149:21:-:0;;;;;;;;;;;;;;;;;;;",
        "linkReferences": {}
    },
    "deployedBytecode": {
        "object": "0x608060405234801561001057600080fd5b506004361061002b5760003560e01c806342699aa014610030575b600080fd5b61004361003e3660046103f6565b610059565b6040516100509190610640565b60405180910390f35b610061610065565b5090565b6040518061010001604052806000815260200160006001600160a01b0316815260200160006001600160a01b0316815260200160006001600160a01b0316815260200160006001600160a01b03168152602001606081526020016060815260200161011a6040518060c0016040528060006001600160a01b031681526020016060815260200160006001600160a01b031681526020016060815260200160006001600160a01b03168152602001606081525090565b905290565b634e487b7160e01b600052604160045260246000fd5b6040516080810167ffffffffffffffff811182821017156101585761015861011f565b60405290565b60405160c0810167ffffffffffffffff811182821017156101585761015861011f565b604051610100810167ffffffffffffffff811182821017156101585761015861011f565b604051601f8201601f1916810167ffffffffffffffff811182821017156101ce576101ce61011f565b604052919050565b80356001600160a01b03811681146101ed57600080fd5b919050565b600082601f83011261020357600080fd5b8135602067ffffffffffffffff82111561021f5761021f61011f565b61022d818360051b016101a5565b82815260079290921b8401810191818101908684111561024c57600080fd5b8286015b848110156102b457608081890312156102695760008081fd5b610271610135565b8135600681106102815760008081fd5b815261028e8286016101d6565b818601526040828101359082015260608083013590820152835291830191608001610250565b509695505050505050565b600082601f8301126102d057600080fd5b813567ffffffffffffffff8111156102ea576102ea61011f565b6102fd601f8201601f19166020016101a5565b81815284602083860101111561031257600080fd5b816020850160208301376000918101602001919091529392505050565b600060c0828403121561034157600080fd5b61034961015e565b9050610354826101d6565b8152602082013567ffffffffffffffff8082111561037157600080fd5b61037d858386016102bf565b602084015261038e604085016101d6565b604084015260608401359150808211156103a757600080fd5b6103b3858386016102bf565b60608401526103c4608085016101d6565b608084015260a08401359150808211156103dd57600080fd5b506103ea848285016102bf565b60a08301525092915050565b60006020828403121561040857600080fd5b813567ffffffffffffffff8082111561042057600080fd5b90830190610100828603121561043557600080fd5b61043d610181565b8235815261044d602084016101d6565b602082015261045e604084016101d6565b604082015261046f606084016101d6565b6060820152610480608084016101d6565b608082015260a08301358281111561049757600080fd5b6104a3878286016101f2565b60a08301525060c0830135828111156104bb57600080fd5b6104c7878286016101f2565b60c08301525060e0830135828111156104df57600080fd5b6104eb8782860161032f565b60e08301525095945050505050565b60008151808452602080850194508084016000805b8481101561057057825180516006811061053757634e487b7160e01b84526021600452602484fd5b8952808501516001600160a01b0316858a0152604080820151908a0152606090810151908901526080909701969183019160010161050f565b50959695505050505050565b6000815180845260005b818110156105a257602081850181015186830182015201610586565b506000602082860101526020601f19601f83011685010191505092915050565b600060018060a01b03808351168452602083015160c060208601526105ea60c086018261057c565b90508160408501511660408601526060840151858203606087015261060f828261057c565b91505081608085015116608086015260a0840151915084810360a0860152610637818361057c565b95945050505050565b60208152815160208201526000602083015161066760408401826001600160a01b03169052565b5060408301516001600160a01b03811660608401525060608301516001600160a01b03811660808401525060808301516001600160a01b03811660a08401525060a08301516101008060c08501526106c36101208501836104fa565b915060c0850151601f19808685030160e08701526106e184836104fa565b935060e08701519150808685030183870152506106fe83826105c2565b969550505050505056fea264697066735822122015c379aa17cb7929f5a432484729e36fa0a16c7a0214b29ff0886a435f9fbf8964736f6c63430008110033",
        "sourceMap": "78:149:21:-:0;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;107:118;;;;;;:::i;:::-;;:::i;:::-;;;;;;;:::i;:::-;;;;;;;;;175:20;;:::i;:::-;-1:-1:-1;214:4:21;107:118::o;-1:-1:-1:-;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;:::o;14:127:22:-;75:10;70:3;66:20;63:1;56:31;106:4;103:1;96:15;130:4;127:1;120:15;146:253;218:2;212:9;260:4;248:17;;295:18;280:34;;316:22;;;277:62;274:88;;;342:18;;:::i;:::-;378:2;371:22;146:253;:::o;404:::-;476:2;470:9;518:4;506:17;;553:18;538:34;;574:22;;;535:62;532:88;;;600:18;;:::i;662:255::-;734:2;728:9;776:6;764:19;;813:18;798:34;;834:22;;;795:62;792:88;;;860:18;;:::i;922:275::-;993:2;987:9;1058:2;1039:13;;-1:-1:-1;;1035:27:22;1023:40;;1093:18;1078:34;;1114:22;;;1075:62;1072:88;;;1140:18;;:::i;:::-;1176:2;1169:22;922:275;;-1:-1:-1;922:275:22:o;1202:173::-;1270:20;;-1:-1:-1;;;;;1319:31:22;;1309:42;;1299:70;;1365:1;1362;1355:12;1299:70;1202:173;;;:::o;1380:1323::-;1443:5;1496:3;1489:4;1481:6;1477:17;1473:27;1463:55;;1514:1;1511;1504:12;1463:55;1550:6;1537:20;1576:4;1599:18;1595:2;1592:26;1589:52;;;1621:18;;:::i;:::-;1661:36;1693:2;1688;1685:1;1681:10;1677:19;1661:36;:::i;:::-;1731:15;;;1817:1;1813:10;;;;1801:23;;1797:32;;;1762:12;;;;1841:15;;;1838:35;;;1869:1;1866;1859:12;1838:35;1905:2;1897:6;1893:15;1917:757;1933:6;1928:3;1925:15;1917:757;;;2011:4;2005:3;2000;1996:13;1992:24;1989:114;;;2057:1;2086:2;2082;2075:14;1989:114;2129:22;;:::i;:::-;2192:3;2179:17;2231:1;2222:7;2219:14;2209:112;;2275:1;2304:2;2300;2293:14;2209:112;2334:22;;2392:32;2411:12;;;2392:32;:::i;:::-;2376:14;;;2369:56;2448:2;2499:12;;;2486:26;2470:14;;;2463:50;2536:2;2587:12;;;2574:26;2558:14;;;2551:50;2614:18;;2652:12;;;;1959:4;1950:14;1917:757;;;-1:-1:-1;2692:5:22;1380:1323;-1:-1:-1;;;;;;1380:1323:22:o;2708:530::-;2750:5;2803:3;2796:4;2788:6;2784:17;2780:27;2770:55;;2821:1;2818;2811:12;2770:55;2857:6;2844:20;2883:18;2879:2;2876:26;2873:52;;;2905:18;;:::i;:::-;2949:55;2992:2;2973:13;;-1:-1:-1;;2969:27:22;2998:4;2965:38;2949:55;:::i;:::-;3029:2;3020:7;3013:19;3075:3;3068:4;3063:2;3055:6;3051:15;3047:26;3044:35;3041:55;;;3092:1;3089;3082:12;3041:55;3157:2;3150:4;3142:6;3138:17;3131:4;3122:7;3118:18;3105:55;3205:1;3180:16;;;3198:4;3176:27;3169:38;;;;3184:7;2708:530;-1:-1:-1;;;2708:530:22:o;3243:944::-;3295:5;3343:4;3331:9;3326:3;3322:19;3318:30;3315:50;;;3361:1;3358;3351:12;3315:50;3383:22;;:::i;:::-;3374:31;;3428:29;3447:9;3428:29;:::i;:::-;3421:5;3414:44;3509:2;3498:9;3494:18;3481:32;3532:18;3573:2;3565:6;3562:14;3559:34;;;3589:1;3586;3579:12;3559:34;3625:45;3666:3;3657:6;3646:9;3642:22;3625:45;:::i;:::-;3620:2;3613:5;3609:14;3602:69;3703:38;3737:2;3726:9;3722:18;3703:38;:::i;:::-;3698:2;3691:5;3687:14;3680:62;3795:2;3784:9;3780:18;3767:32;3751:48;;3824:2;3814:8;3811:16;3808:36;;;3840:1;3837;3830:12;3808:36;3876:47;3919:3;3908:8;3897:9;3893:24;3876:47;:::i;:::-;3871:2;3864:5;3860:14;3853:71;3957:39;3991:3;3980:9;3976:19;3957:39;:::i;:::-;3951:3;3944:5;3940:15;3933:64;4050:3;4039:9;4035:19;4022:33;4006:49;;4080:2;4070:8;4067:16;4064:36;;;4096:1;4093;4086:12;4064:36;;4133:47;4176:3;4165:8;4154:9;4150:24;4133:47;:::i;:::-;4127:3;4120:5;4116:15;4109:72;;3243:944;;;;:::o;4192:1322::-;4273:6;4326:2;4314:9;4305:7;4301:23;4297:32;4294:52;;;4342:1;4339;4332:12;4294:52;4382:9;4369:23;4411:18;4452:2;4444:6;4441:14;4438:34;;;4468:1;4465;4458:12;4438:34;4491:22;;;;4547:6;4529:16;;;4525:29;4522:49;;;4567:1;4564;4557:12;4522:49;4593:22;;:::i;:::-;4651:2;4638:16;4631:5;4624:31;4687;4714:2;4710;4706:11;4687:31;:::i;:::-;4682:2;4675:5;4671:14;4664:55;4751:31;4778:2;4774;4770:11;4751:31;:::i;:::-;4746:2;4739:5;4735:14;4728:55;4815:31;4842:2;4838;4834:11;4815:31;:::i;:::-;4810:2;4803:5;4799:14;4792:55;4880:32;4907:3;4903:2;4899:12;4880:32;:::i;:::-;4874:3;4867:5;4863:15;4856:57;4959:3;4955:2;4951:12;4938:26;4989:2;4979:8;4976:16;4973:36;;;5005:1;5002;4995:12;4973:36;5042:65;5099:7;5088:8;5084:2;5080:17;5042:65;:::i;:::-;5036:3;5029:5;5025:15;5018:90;;5154:3;5150:2;5146:12;5133:26;5184:2;5174:8;5171:16;5168:36;;;5200:1;5197;5190:12;5168:36;5237:65;5294:7;5283:8;5279:2;5275:17;5237:65;:::i;:::-;5231:3;5224:5;5220:15;5213:90;;5349:3;5345:2;5341:12;5328:26;5379:2;5369:8;5366:16;5363:36;;;5395:1;5392;5385:12;5363:36;5432:51;5475:7;5464:8;5460:2;5456:17;5432:51;:::i;:::-;5426:3;5415:15;;5408:76;-1:-1:-1;5419:5:22;4192:1322;-1:-1:-1;;;;;4192:1322:22:o;5628:942::-;5690:3;5728:5;5722:12;5755:6;5750:3;5743:19;5781:4;5810:2;5805:3;5801:12;5794:19;;5847:2;5840:5;5836:14;5868:1;5889;5899:646;5915:6;5910:3;5907:15;5899:646;;;5984:6;5978:13;6020:2;6014:9;6053:1;6049:2;6046:9;6036:160;;-1:-1:-1;;;6087:31:22;;6145:4;6142:1;6135:15;6177:4;6094:1;6167:15;6036:160;6209:15;;6268:11;;;6262:18;-1:-1:-1;;;;;6258:44:22;6244:12;;;6237:66;6326:4;6370:11;;;6364:18;6350:12;;;6343:40;6406:4;6450:11;;;6444:18;6430:12;;;6423:40;6492:4;6483:14;;;;6520:15;;;;6299:1;5932:11;5899:646;;;-1:-1:-1;6561:3:22;;5628:942;-1:-1:-1;;;;;;5628:942:22:o;6575:422::-;6616:3;6654:5;6648:12;6681:6;6676:3;6669:19;6706:1;6716:162;6730:6;6727:1;6724:13;6716:162;;;6792:4;6848:13;;;6844:22;;6838:29;6820:11;;;6816:20;;6809:59;6745:12;6716:162;;;6720:3;6923:1;6916:4;6907:6;6902:3;6898:16;6894:27;6887:38;6986:4;6979:2;6975:7;6970:2;6962:6;6958:15;6954:29;6949:3;6945:39;6941:50;6934:57;;;6575:422;;;;:::o;7002:751::-;7050:3;7095:1;7091;7086:3;7082:11;7078:19;7136:2;7128:5;7122:12;7118:21;7113:3;7106:34;7186:4;7179:5;7175:16;7169:23;7224:4;7217;7212:3;7208:14;7201:28;7250:46;7290:4;7285:3;7281:14;7267:12;7250:46;:::i;:::-;7238:58;;7357:2;7349:4;7342:5;7338:16;7332:23;7328:32;7321:4;7316:3;7312:14;7305:56;7409:4;7402:5;7398:16;7392:23;7457:3;7451:4;7447:14;7440:4;7435:3;7431:14;7424:38;7485;7518:4;7502:14;7485:38;:::i;:::-;7471:52;;;7584:2;7576:4;7569:5;7565:16;7559:23;7555:32;7548:4;7543:3;7539:14;7532:56;7636:4;7629:5;7625:16;7619:23;7597:45;;7686:3;7678:6;7674:16;7667:4;7662:3;7658:14;7651:40;7707;7740:6;7724:14;7707:40;:::i;:::-;7700:47;7002:751;-1:-1:-1;;;;;7002:751:22:o;7758:1330::-;7931:2;7920:9;7913:21;7976:6;7970:13;7965:2;7954:9;7950:18;7943:41;7894:4;8031:2;8023:6;8019:15;8013:22;8044:52;8092:2;8081:9;8077:18;8063:12;-1:-1:-1;;;;;5585:31:22;5573:44;;5519:104;8044:52;-1:-1:-1;8145:2:22;8133:15;;8127:22;-1:-1:-1;;;;;5585:31:22;;8208:2;8193:18;;5573:44;-1:-1:-1;8261:2:22;8249:15;;8243:22;-1:-1:-1;;;;;5585:31:22;;8324:3;8309:19;;5573:44;-1:-1:-1;8378:3:22;8366:16;;8360:23;-1:-1:-1;;;;;5585:31:22;;8442:3;8427:19;;5573:44;8392:55;8496:3;8488:6;8484:16;8478:23;8520:6;8563:2;8557:3;8546:9;8542:19;8535:31;8589:74;8658:3;8647:9;8643:19;8627:14;8589:74;:::i;:::-;8575:88;;8712:3;8704:6;8700:16;8694:23;8740:2;8736:7;8808:2;8796:9;8788:6;8784:22;8780:31;8774:3;8763:9;8759:19;8752:60;8835:61;8889:6;8873:14;8835:61;:::i;:::-;8821:75;;8945:3;8937:6;8933:16;8927:23;8905:45;;9014:2;9002:9;8994:6;8990:22;8986:31;8981:2;8970:9;8966:18;8959:59;;9035:47;9075:6;9059:14;9035:47;:::i;:::-;9027:55;7758:1330;-1:-1:-1;;;;;;7758:1330:22:o",
        "linkReferences": {}
    },
    "methodIdentifiers": {"encodeLoan((uint256,address,address,address,address,(uint8,address,uint256,uint256)[],(uint8,address,uint256,uint256)[],(address,bytes,address,bytes,address,bytes)))": "42699aa0"},
    "rawMetadata": "{\"compiler\":{\"version\":\"0.8.17+commit.8df45f5f\"},\"language\":\"Solidity\",\"output\":{\"abi\":[{\"inputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"start\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"custodian\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"borrower\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"issuer\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"originator\",\"type\":\"address\"},{\"components\":[{\"internalType\":\"enum ItemType\",\"name\":\"itemType\",\"type\":\"uint8\"},{\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"identifier\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"internalType\":\"struct SpentItem[]\",\"name\":\"collateral\",\"type\":\"tuple[]\"},{\"components\":[{\"internalType\":\"enum ItemType\",\"name\":\"itemType\",\"type\":\"uint8\"},{\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"identifier\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"internalType\":\"struct SpentItem[]\",\"name\":\"debt\",\"type\":\"tuple[]\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"status\",\"type\":\"address\"},{\"internalType\":\"bytes\",\"name\":\"statusData\",\"type\":\"bytes\"},{\"internalType\":\"address\",\"name\":\"pricing\",\"type\":\"address\"},{\"internalType\":\"bytes\",\"name\":\"pricingData\",\"type\":\"bytes\"},{\"internalType\":\"address\",\"name\":\"settlement\",\"type\":\"address\"},{\"internalType\":\"bytes\",\"name\":\"settlementData\",\"type\":\"bytes\"}],\"internalType\":\"struct Starport.Terms\",\"name\":\"terms\",\"type\":\"tuple\"}],\"internalType\":\"struct Starport.Loan\",\"name\":\"loan\",\"type\":\"tuple\"}],\"name\":\"encodeLoan\",\"outputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"start\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"custodian\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"borrower\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"issuer\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"originator\",\"type\":\"address\"},{\"components\":[{\"internalType\":\"enum ItemType\",\"name\":\"itemType\",\"type\":\"uint8\"},{\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"identifier\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"internalType\":\"struct SpentItem[]\",\"name\":\"collateral\",\"type\":\"tuple[]\"},{\"components\":[{\"internalType\":\"enum ItemType\",\"name\":\"itemType\",\"type\":\"uint8\"},{\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"identifier\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"internalType\":\"struct SpentItem[]\",\"name\":\"debt\",\"type\":\"tuple[]\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"status\",\"type\":\"address\"},{\"internalType\":\"bytes\",\"name\":\"statusData\",\"type\":\"bytes\"},{\"internalType\":\"address\",\"name\":\"pricing\",\"type\":\"address\"},{\"internalType\":\"bytes\",\"name\":\"pricingData\",\"type\":\"bytes\"},{\"internalType\":\"address\",\"name\":\"settlement\",\"type\":\"address\"},{\"internalType\":\"bytes\",\"name\":\"settlementData\",\"type\":\"bytes\"}],\"internalType\":\"struct Starport.Terms\",\"name\":\"terms\",\"type\":\"tuple\"}],\"internalType\":\"struct Starport.Loan\",\"name\":\"\",\"type\":\"tuple\"}],\"stateMutability\":\"pure\",\"type\":\"function\"}],\"devdoc\":{\"kind\":\"dev\",\"methods\":{},\"version\":1},\"userdoc\":{\"kind\":\"user\",\"methods\":{},\"version\":1}},\"settings\":{\"compilationTarget\":{\"src/encodeHelpers/EncodeHelpers.sol\":\"EncodeHelpers\"},\"evmVersion\":\"london\",\"libraries\":{},\"metadata\":{\"bytecodeHash\":\"ipfs\"},\"optimizer\":{\"enabled\":true,\"runs\":200},\"remappings\":[\":@openzeppelin/=lib/starport/lib/seaport/lib/openzeppelin-contracts/\",\":@rari-capital/solmate/=lib/starport/lib/seaport/lib/solmate/\",\":ds-test/=lib/starport/lib/seaport/lib/ds-test/src/\",\":erc4626-tests/=lib/starport/lib/seaport/lib/openzeppelin-contracts/lib/erc4626-tests/\",\":forge-std/=lib/starport/lib/forge-std/src/\",\":murky/=lib/starport/lib/seaport/lib/murky/src/\",\":openzeppelin-contracts/=lib/starport/lib/seaport/lib/openzeppelin-contracts/\",\":seaport-core/=lib/starport/lib/seaport/lib/seaport-core/\",\":seaport-sol/=lib/starport/lib/seaport/lib/seaport-sol/\",\":seaport-types/=lib/starport/lib/seaport/lib/seaport-types/\",\":seaport/=lib/starport/lib/seaport/\",\":solady/=lib/starport/lib/solady/\",\":solarray/=lib/starport/lib/seaport/lib/solarray/src/\",\":solmate/=lib/starport/lib/solmate/src/\",\":starport-core/=lib/starport/src/\",\":starport-test/=lib/starport/test/\",\":starport/=lib/starport/src/\",\":v1-core/=src/\"]},\"sources\":{\"lib/starport/lib/seaport/lib/seaport-types/src/helpers/PointerLibraries.sol\":{\"keccak256\":\"0xf9106392d8616040b61748bce0ff35856c4a3eba5eb5eb269eaeb97747fe40e7\",\"license\":\"MIT\",\"urls\":[\"bzz-raw://046f05ce4d4428d3ca6264ab03e1b6cee5751776f02cc87d66d11ee479a42992\",\"dweb:/ipfs/Qme5bKudPZWxH4DYDLQE2sD23xNVbQH4NjrL6pBacv54FD\"]},\"lib/starport/lib/seaport/lib/seaport-types/src/interfaces/ContractOffererInterface.sol\":{\"keccak256\":\"0xb8e8bdf318dfb7e3a985ff5e3b41a58b183706f9abb09bc97b03479fce2743be\",\"license\":\"MIT\",\"urls\":[\"bzz-raw://3050796feef63943414f3b799269287c77e63f0151733de819a28a867fb677a9\",\"dweb:/ipfs/QmcQesS7LksoBa16c9q5pEVJdbnadogVSsyvDzd6J4YEpX\"]},\"lib/starport/lib/seaport/lib/seaport-types/src/interfaces/IERC165.sol\":{\"keccak256\":\"0x5d9b69ca598a236e397a4b849c2b800f33206fcc1a949e237fbfc387f022020f\",\"license\":\"MIT\",\"urls\":[\"bzz-raw://fe1c38152c5dfcf05f4157458bda1d4c4815f5b4ba1b442b42502442bd3466c2\",\"dweb:/ipfs/QmdhPePHcAnEpSotrwbr4r4aGJZuw3Wcjqz2QUmiNrhLr1\"]},\"lib/starport/lib/seaport/lib/seaport-types/src/lib/ConsiderationEnums.sol\":{\"keccak256\":\"0xeb0de4edbad252c3227c59b66721978316202c4d31c5370a8669c4051984e345\",\"license\":\"MIT\",\"urls\":[\"bzz-raw://00451d1ceb616b7cccf0e4be073483d5c99fcc205fe6a1056ce35b8703be16e3\",\"dweb:/ipfs/QmbeoxgRcgwK18Vw1G1mVAFKMnYYT2oQp1idfazNicwncq\"]},\"lib/starport/lib/seaport/lib/seaport-types/src/lib/ConsiderationStructs.sol\":{\"keccak256\":\"0x05bc9ccb74c9fb4d073c9adc36da28a5a0ab961886fcd4a681ccb8d7eb74e0ed\",\"license\":\"MIT\",\"urls\":[\"bzz-raw://911be5f248b2ad47a24ca9949f4b8114db5432c7f2769650c0f3e4ea6bb0b17b\",\"dweb:/ipfs/QmdNmqhwc1UMxbCPXqe9FDua7negVWSGU5cPAWSbUTnKDV\"]},\"lib/starport/lib/solady/src/auth/Ownable.sol\":{\"keccak256\":\"0x0b274f99e9437817b4cdb67302942bec80463ca5f14cfa64f9b271519ef79d30\",\"license\":\"MIT\",\"urls\":[\"bzz-raw://fdc968e5792317a71b5063754011efd0296e53911494a9035954ecffa5dc8122\",\"dweb:/ipfs/QmZZwVRubPWdjMba15MqqSxyH7duChepHm1jKTz5NPhVeq\"]},\"lib/starport/lib/solady/src/tokens/ERC1155.sol\":{\"keccak256\":\"0xacd1b60b0da3c371c9389187eeab27a1707550842a2b6f7dddcdd7dc3ace0457\",\"license\":\"MIT\",\"urls\":[\"bzz-raw://69df6a14f9a9ef751e193a14d9ac8319eb5979fa7e824717e4d9cb03753ad7b8\",\"dweb:/ipfs/QmaYBov45sqayYx81S2Rhyn8C7DTWkvStyvzrGA58RNAsj\"]},\"lib/starport/lib/solady/src/tokens/ERC20.sol\":{\"keccak256\":\"0x1842a735aaae719b62f7be21f8a260a255014cac10cc053966b7b8f120e84185\",\"license\":\"MIT\",\"urls\":[\"bzz-raw://4132a0904779af177218b731efb9da06813f38b6e990b46c3a0328a1b4cf4c1a\",\"dweb:/ipfs/QmStZxnz8GmxsZ7WVp4Rn7E72TjPETt1ZYdb3sR7rXhSze\"]},\"lib/starport/lib/solady/src/tokens/ERC721.sol\":{\"keccak256\":\"0xe44394ee63d1850a7b9938f39d558394462284d861c265eeb2610fc9f7d7c935\",\"license\":\"MIT\",\"urls\":[\"bzz-raw://e1661069b0113a4d39b9cc4f6e6a8ad42fe574c978f16f57382193ae99498c3f\",\"dweb:/ipfs/QmNqipGffseX5izz5fHi91LmDBnwsDXbYhM1VJGQch7xyB\"]},\"lib/starport/lib/solady/src/utils/FixedPointMathLib.sol\":{\"keccak256\":\"0xd665d762c3c415f9227b326d0e6c814f0366eb6c5dd3283de5fcdc028e6a07f5\",\"license\":\"MIT\",\"urls\":[\"bzz-raw://5cff139bf1da6a27cbc58502f4a25849250570ae19ad11b309c1ed8747169cd8\",\"dweb:/ipfs/QmXXkEPzxcuD8cBjiamq3raRV75aNsj5XdGLsg2jBcmnfp\"]},\"lib/starport/lib/solady/src/utils/SafeTransferLib.sol\":{\"keccak256\":\"0xc16ab13a5148c03ec4cc1ab9ec3f343b5531a15cc81d96a01e4205edb6cf6a83\",\"license\":\"MIT\",\"urls\":[\"bzz-raw://0bae1f51c1429529f2dc700b65239fb45f62bf997c87b0a4258a19005c32f38d\",\"dweb:/ipfs/QmdC9Pbst91miN1cMbqKacMmcm7EPoG1pGzqEQ7sUqNfWQ\"]},\"lib/starport/lib/solady/src/utils/SignatureCheckerLib.sol\":{\"keccak256\":\"0xbbac01555983ee04f61cc2b52bc416f4ea6f4da0a2ea0886f915b6560a747641\",\"license\":\"MIT\",\"urls\":[\"bzz-raw://6d4b8164f132b044a5ed25befed2bcd11f67c52e92d1dc4d200fd99063df9450\",\"dweb:/ipfs/QmVoBciA7PFHRNUbF8zYvxz5xEUQUkd5E3BkaaJUpZBSfY\"]},\"lib/starport/src/Custodian.sol\":{\"keccak256\":\"0x6dfd5d555badbdc510273a5cb4f1caff19bdb262444533492f2cbf28d727c2bf\",\"license\":\"BUSL-1.1\",\"urls\":[\"bzz-raw://70d003e64d04c1c1ea3d6672a16cf7572e7969cfc3bde34760f3fd1edfa03e65\",\"dweb:/ipfs/QmVXCwnVp7vgc6uj7jTv617YhH2poApdvyRfZjDo1nMV1A\"]},\"lib/starport/src/Starport.sol\":{\"keccak256\":\"0x98773fb76cc0c1f8a6bf0366914ef4248febc4c2ce3fd2bb3ccc17c9be0ed024\",\"license\":\"BUSL-1.1\",\"urls\":[\"bzz-raw://7e6e8c489279fc4de09adc6ed268e313f1a06c43fb231f1446b04f02454eec03\",\"dweb:/ipfs/QmYmbxYJfoHMpiywJ4JXvgfdnf8KMwMjcAbWyJ2y5JDjfD\"]},\"lib/starport/src/enforcers/CaveatEnforcer.sol\":{\"keccak256\":\"0xc5446776f0a7e4078dc57288cc0b81cc3b0cb7122568ba55521268bd7e2d9a1b\",\"license\":\"BUSL-1.1\",\"urls\":[\"bzz-raw://dd091bce5a872630817aab30ac0eefd8ea58cf9e88fac49fd7fab3d6df0d3156\",\"dweb:/ipfs/QmNbYtmy1gLFgaMv4tWQjLKGE1kS1a7JrD27F6aQtkXBi1\"]},\"lib/starport/src/lib/PausableNonReentrant.sol\":{\"keccak256\":\"0x7cd31ffbd522c61db2d0f837a09e916e153204c6a74ab22aea447739e8d8a07e\",\"license\":\"BUSL-1.1\",\"urls\":[\"bzz-raw://113c7fe96efd59148688155345c18aa28296457a9e3eead8b1052f85836965e2\",\"dweb:/ipfs/QmeoRR1GKq4VVnMPJGi9NmndKBLpisr76QfJsQLX3xZuS7\"]},\"lib/starport/src/lib/StarportLib.sol\":{\"keccak256\":\"0x4e1055ff071ad829b31914235271309c16a91a0c4e82fda776c14af4ac1c88d9\",\"license\":\"BUSL-1.1\",\"urls\":[\"bzz-raw://bb511572c36593ace2f18fe3f100599b3148b0ff3501e9607d03fc61ddbd0ce6\",\"dweb:/ipfs/QmTzu1NpEiVrvrmTrAkmKxd8YoUddKQTpCuiQb1evJpBwo\"]},\"lib/starport/src/lib/Validation.sol\":{\"keccak256\":\"0x5aced24de9ff148fc78120378155c7c6205ee34febbb3ba18523723f33cb03d9\",\"license\":\"BUSL-1.1\",\"urls\":[\"bzz-raw://62abe44f3e5745eb1abdc38e4dc638ac72149d372fcb38589a44517110df1fde\",\"dweb:/ipfs/QmVrvAF1drEzbFhu8nnSB7C4eXVieek7JEon3CrT1fa3dC\"]},\"lib/starport/src/pricing/Pricing.sol\":{\"keccak256\":\"0xd7cca1bfa7b8473e5d1fc68686e12a1b526755f68f04ee4cdc5db20e47a2c9b8\",\"license\":\"BUSL-1.1\",\"urls\":[\"bzz-raw://b1b82a790a7e8bfc113c98dc4064780120a83c3491cfb41b6d7ce7454f526444\",\"dweb:/ipfs/QmbhqbJCr7gQqaNNxJo8A6BBAPmD69DA7uWFq9Gh1MuKbv\"]},\"lib/starport/src/settlement/Settlement.sol\":{\"keccak256\":\"0x6d8411d7b32b6f8c98a85061a499b74d5a9533c28fadd40ce742081c79370869\",\"license\":\"BUSL-1.1\",\"urls\":[\"bzz-raw://3ecad917a73d8ac8f6593273f45e0abac81be467ccdd1e141dce028d9f183e3c\",\"dweb:/ipfs/QmVPZUfD2WjD6mNGWeCPs6vK9JMCw6haaJ2bPM5pZrVzxh\"]},\"lib/starport/src/status/Status.sol\":{\"keccak256\":\"0xf333483f3b32fa239976b63dd8dc200b5e0fe7f394c241979cf6b77f6b3dc9a1\",\"license\":\"BUSL-1.1\",\"urls\":[\"bzz-raw://9f5ebddb1455c5be8004b05be15a56ed064830542d6b87aaf8515a953ad02ebc\",\"dweb:/ipfs/QmaMCUMtJdrdf3L4qbExiUxYiay15WPMFxM2f4t9A7o7ck\"]},\"src/encodeHelpers/EncodeHelpers.sol\":{\"keccak256\":\"0x1f4ed1c2e3929ad98d0eeec9794d9cfb4e7fec77599d058695cc612b5cb30094\",\"urls\":[\"bzz-raw://90b4f3261b2ba3f39669c8940fb74632f3fb38b3d3de02646b53911a25ab27ad\",\"dweb:/ipfs/QmYiRndvcxiHw5RmFvrgSj5apRaB2QCTaHsujPUkkAp6hV\"]}},\"version\":1}",
    "metadata": {
        "compiler": {"version": "0.8.17+commit.8df45f5f"}, "language": "Solidity", "output": {
            "abi": [{
                "inputs": [{
                    "internalType": "struct Starport.Loan",
                    "name": "loan",
                    "type": "tuple",
                    "components": [{
                        "internalType": "uint256",
                        "name": "start",
                        "type": "uint256"
                    }, {"internalType": "address", "name": "custodian", "type": "address"}, {
                        "internalType": "address",
                        "name": "borrower",
                        "type": "address"
                    }, {"internalType": "address", "name": "issuer", "type": "address"}, {
                        "internalType": "address",
                        "name": "originator",
                        "type": "address"
                    }, {
                        "internalType": "struct SpentItem[]",
                        "name": "collateral",
                        "type": "tuple[]",
                        "components": [{
                            "internalType": "enum ItemType",
                            "name": "itemType",
                            "type": "uint8"
                        }, {"internalType": "address", "name": "token", "type": "address"}, {
                            "internalType": "uint256",
                            "name": "identifier",
                            "type": "uint256"
                        }, {"internalType": "uint256", "name": "amount", "type": "uint256"}]
                    }, {
                        "internalType": "struct SpentItem[]",
                        "name": "debt",
                        "type": "tuple[]",
                        "components": [{
                            "internalType": "enum ItemType",
                            "name": "itemType",
                            "type": "uint8"
                        }, {"internalType": "address", "name": "token", "type": "address"}, {
                            "internalType": "uint256",
                            "name": "identifier",
                            "type": "uint256"
                        }, {"internalType": "uint256", "name": "amount", "type": "uint256"}]
                    }, {
                        "internalType": "struct Starport.Terms",
                        "name": "terms",
                        "type": "tuple",
                        "components": [{
                            "internalType": "address",
                            "name": "status",
                            "type": "address"
                        }, {"internalType": "bytes", "name": "statusData", "type": "bytes"}, {
                            "internalType": "address",
                            "name": "pricing",
                            "type": "address"
                        }, {
                            "internalType": "bytes",
                            "name": "pricingData",
                            "type": "bytes"
                        }, {
                            "internalType": "address",
                            "name": "settlement",
                            "type": "address"
                        }, {"internalType": "bytes", "name": "settlementData", "type": "bytes"}]
                    }]
                }], "stateMutability": "pure", "type": "function", "name": "encodeLoan", "outputs": [{
                    "internalType": "struct Starport.Loan",
                    "name": "",
                    "type": "tuple",
                    "components": [{
                        "internalType": "uint256",
                        "name": "start",
                        "type": "uint256"
                    }, {"internalType": "address", "name": "custodian", "type": "address"}, {
                        "internalType": "address",
                        "name": "borrower",
                        "type": "address"
                    }, {"internalType": "address", "name": "issuer", "type": "address"}, {
                        "internalType": "address",
                        "name": "originator",
                        "type": "address"
                    }, {
                        "internalType": "struct SpentItem[]",
                        "name": "collateral",
                        "type": "tuple[]",
                        "components": [{
                            "internalType": "enum ItemType",
                            "name": "itemType",
                            "type": "uint8"
                        }, {"internalType": "address", "name": "token", "type": "address"}, {
                            "internalType": "uint256",
                            "name": "identifier",
                            "type": "uint256"
                        }, {"internalType": "uint256", "name": "amount", "type": "uint256"}]
                    }, {
                        "internalType": "struct SpentItem[]",
                        "name": "debt",
                        "type": "tuple[]",
                        "components": [{
                            "internalType": "enum ItemType",
                            "name": "itemType",
                            "type": "uint8"
                        }, {"internalType": "address", "name": "token", "type": "address"}, {
                            "internalType": "uint256",
                            "name": "identifier",
                            "type": "uint256"
                        }, {"internalType": "uint256", "name": "amount", "type": "uint256"}]
                    }, {
                        "internalType": "struct Starport.Terms",
                        "name": "terms",
                        "type": "tuple",
                        "components": [{
                            "internalType": "address",
                            "name": "status",
                            "type": "address"
                        }, {"internalType": "bytes", "name": "statusData", "type": "bytes"}, {
                            "internalType": "address",
                            "name": "pricing",
                            "type": "address"
                        }, {
                            "internalType": "bytes",
                            "name": "pricingData",
                            "type": "bytes"
                        }, {
                            "internalType": "address",
                            "name": "settlement",
                            "type": "address"
                        }, {"internalType": "bytes", "name": "settlementData", "type": "bytes"}]
                    }]
                }]
            }],
            "devdoc": {"kind": "dev", "methods": {}, "version": 1},
            "userdoc": {"kind": "user", "methods": {}, "version": 1}
        }, "settings": {
            "remappings": ["@openzeppelin/=lib/starport/lib/seaport/lib/openzeppelin-contracts/", "@rari-capital/solmate/=lib/starport/lib/seaport/lib/solmate/", "ds-test/=lib/starport/lib/seaport/lib/ds-test/src/", "erc4626-tests/=lib/starport/lib/seaport/lib/openzeppelin-contracts/lib/erc4626-tests/", "forge-std/=lib/starport/lib/forge-std/src/", "murky/=lib/starport/lib/seaport/lib/murky/src/", "openzeppelin-contracts/=lib/starport/lib/seaport/lib/openzeppelin-contracts/", "seaport-core/=lib/starport/lib/seaport/lib/seaport-core/", "seaport-sol/=lib/starport/lib/seaport/lib/seaport-sol/", "seaport-types/=lib/starport/lib/seaport/lib/seaport-types/", "seaport/=lib/starport/lib/seaport/", "solady/=lib/starport/lib/solady/", "solarray/=lib/starport/lib/seaport/lib/solarray/src/", "solmate/=lib/starport/lib/solmate/src/", "starport-core/=lib/starport/src/", "starport-test/=lib/starport/test/", "starport/=lib/starport/src/", "v1-core/=src/"],
            "optimizer": {"enabled": true, "runs": 200},
            "metadata": {"bytecodeHash": "ipfs"},
            "compilationTarget": {"src/encodeHelpers/EncodeHelpers.sol": "EncodeHelpers"},
            "libraries": {}
        }, "sources": {
            "lib/starport/lib/seaport/lib/seaport-types/src/helpers/PointerLibraries.sol": {
                "keccak256": "0xf9106392d8616040b61748bce0ff35856c4a3eba5eb5eb269eaeb97747fe40e7",
                "urls": ["bzz-raw://046f05ce4d4428d3ca6264ab03e1b6cee5751776f02cc87d66d11ee479a42992", "dweb:/ipfs/Qme5bKudPZWxH4DYDLQE2sD23xNVbQH4NjrL6pBacv54FD"],
                "license": "MIT"
            },
            "lib/starport/lib/seaport/lib/seaport-types/src/interfaces/ContractOffererInterface.sol": {
                "keccak256": "0xb8e8bdf318dfb7e3a985ff5e3b41a58b183706f9abb09bc97b03479fce2743be",
                "urls": ["bzz-raw://3050796feef63943414f3b799269287c77e63f0151733de819a28a867fb677a9", "dweb:/ipfs/QmcQesS7LksoBa16c9q5pEVJdbnadogVSsyvDzd6J4YEpX"],
                "license": "MIT"
            },
            "lib/starport/lib/seaport/lib/seaport-types/src/interfaces/IERC165.sol": {
                "keccak256": "0x5d9b69ca598a236e397a4b849c2b800f33206fcc1a949e237fbfc387f022020f",
                "urls": ["bzz-raw://fe1c38152c5dfcf05f4157458bda1d4c4815f5b4ba1b442b42502442bd3466c2", "dweb:/ipfs/QmdhPePHcAnEpSotrwbr4r4aGJZuw3Wcjqz2QUmiNrhLr1"],
                "license": "MIT"
            },
            "lib/starport/lib/seaport/lib/seaport-types/src/lib/ConsiderationEnums.sol": {
                "keccak256": "0xeb0de4edbad252c3227c59b66721978316202c4d31c5370a8669c4051984e345",
                "urls": ["bzz-raw://00451d1ceb616b7cccf0e4be073483d5c99fcc205fe6a1056ce35b8703be16e3", "dweb:/ipfs/QmbeoxgRcgwK18Vw1G1mVAFKMnYYT2oQp1idfazNicwncq"],
                "license": "MIT"
            },
            "lib/starport/lib/seaport/lib/seaport-types/src/lib/ConsiderationStructs.sol": {
                "keccak256": "0x05bc9ccb74c9fb4d073c9adc36da28a5a0ab961886fcd4a681ccb8d7eb74e0ed",
                "urls": ["bzz-raw://911be5f248b2ad47a24ca9949f4b8114db5432c7f2769650c0f3e4ea6bb0b17b", "dweb:/ipfs/QmdNmqhwc1UMxbCPXqe9FDua7negVWSGU5cPAWSbUTnKDV"],
                "license": "MIT"
            },
            "lib/starport/lib/solady/src/auth/Ownable.sol": {
                "keccak256": "0x0b274f99e9437817b4cdb67302942bec80463ca5f14cfa64f9b271519ef79d30",
                "urls": ["bzz-raw://fdc968e5792317a71b5063754011efd0296e53911494a9035954ecffa5dc8122", "dweb:/ipfs/QmZZwVRubPWdjMba15MqqSxyH7duChepHm1jKTz5NPhVeq"],
                "license": "MIT"
            },
            "lib/starport/lib/solady/src/tokens/ERC1155.sol": {
                "keccak256": "0xacd1b60b0da3c371c9389187eeab27a1707550842a2b6f7dddcdd7dc3ace0457",
                "urls": ["bzz-raw://69df6a14f9a9ef751e193a14d9ac8319eb5979fa7e824717e4d9cb03753ad7b8", "dweb:/ipfs/QmaYBov45sqayYx81S2Rhyn8C7DTWkvStyvzrGA58RNAsj"],
                "license": "MIT"
            },
            "lib/starport/lib/solady/src/tokens/ERC20.sol": {
                "keccak256": "0x1842a735aaae719b62f7be21f8a260a255014cac10cc053966b7b8f120e84185",
                "urls": ["bzz-raw://4132a0904779af177218b731efb9da06813f38b6e990b46c3a0328a1b4cf4c1a", "dweb:/ipfs/QmStZxnz8GmxsZ7WVp4Rn7E72TjPETt1ZYdb3sR7rXhSze"],
                "license": "MIT"
            },
            "lib/starport/lib/solady/src/tokens/ERC721.sol": {
                "keccak256": "0xe44394ee63d1850a7b9938f39d558394462284d861c265eeb2610fc9f7d7c935",
                "urls": ["bzz-raw://e1661069b0113a4d39b9cc4f6e6a8ad42fe574c978f16f57382193ae99498c3f", "dweb:/ipfs/QmNqipGffseX5izz5fHi91LmDBnwsDXbYhM1VJGQch7xyB"],
                "license": "MIT"
            },
            "lib/starport/lib/solady/src/utils/FixedPointMathLib.sol": {
                "keccak256": "0xd665d762c3c415f9227b326d0e6c814f0366eb6c5dd3283de5fcdc028e6a07f5",
                "urls": ["bzz-raw://5cff139bf1da6a27cbc58502f4a25849250570ae19ad11b309c1ed8747169cd8", "dweb:/ipfs/QmXXkEPzxcuD8cBjiamq3raRV75aNsj5XdGLsg2jBcmnfp"],
                "license": "MIT"
            },
            "lib/starport/lib/solady/src/utils/SafeTransferLib.sol": {
                "keccak256": "0xc16ab13a5148c03ec4cc1ab9ec3f343b5531a15cc81d96a01e4205edb6cf6a83",
                "urls": ["bzz-raw://0bae1f51c1429529f2dc700b65239fb45f62bf997c87b0a4258a19005c32f38d", "dweb:/ipfs/QmdC9Pbst91miN1cMbqKacMmcm7EPoG1pGzqEQ7sUqNfWQ"],
                "license": "MIT"
            },
            "lib/starport/lib/solady/src/utils/SignatureCheckerLib.sol": {
                "keccak256": "0xbbac01555983ee04f61cc2b52bc416f4ea6f4da0a2ea0886f915b6560a747641",
                "urls": ["bzz-raw://6d4b8164f132b044a5ed25befed2bcd11f67c52e92d1dc4d200fd99063df9450", "dweb:/ipfs/QmVoBciA7PFHRNUbF8zYvxz5xEUQUkd5E3BkaaJUpZBSfY"],
                "license": "MIT"
            },
            "lib/starport/src/Custodian.sol": {
                "keccak256": "0x6dfd5d555badbdc510273a5cb4f1caff19bdb262444533492f2cbf28d727c2bf",
                "urls": ["bzz-raw://70d003e64d04c1c1ea3d6672a16cf7572e7969cfc3bde34760f3fd1edfa03e65", "dweb:/ipfs/QmVXCwnVp7vgc6uj7jTv617YhH2poApdvyRfZjDo1nMV1A"],
                "license": "BUSL-1.1"
            },
            "lib/starport/src/Starport.sol": {
                "keccak256": "0x98773fb76cc0c1f8a6bf0366914ef4248febc4c2ce3fd2bb3ccc17c9be0ed024",
                "urls": ["bzz-raw://7e6e8c489279fc4de09adc6ed268e313f1a06c43fb231f1446b04f02454eec03", "dweb:/ipfs/QmYmbxYJfoHMpiywJ4JXvgfdnf8KMwMjcAbWyJ2y5JDjfD"],
                "license": "BUSL-1.1"
            },
            "lib/starport/src/enforcers/CaveatEnforcer.sol": {
                "keccak256": "0xc5446776f0a7e4078dc57288cc0b81cc3b0cb7122568ba55521268bd7e2d9a1b",
                "urls": ["bzz-raw://dd091bce5a872630817aab30ac0eefd8ea58cf9e88fac49fd7fab3d6df0d3156", "dweb:/ipfs/QmNbYtmy1gLFgaMv4tWQjLKGE1kS1a7JrD27F6aQtkXBi1"],
                "license": "BUSL-1.1"
            },
            "lib/starport/src/lib/PausableNonReentrant.sol": {
                "keccak256": "0x7cd31ffbd522c61db2d0f837a09e916e153204c6a74ab22aea447739e8d8a07e",
                "urls": ["bzz-raw://113c7fe96efd59148688155345c18aa28296457a9e3eead8b1052f85836965e2", "dweb:/ipfs/QmeoRR1GKq4VVnMPJGi9NmndKBLpisr76QfJsQLX3xZuS7"],
                "license": "BUSL-1.1"
            },
            "lib/starport/src/lib/StarportLib.sol": {
                "keccak256": "0x4e1055ff071ad829b31914235271309c16a91a0c4e82fda776c14af4ac1c88d9",
                "urls": ["bzz-raw://bb511572c36593ace2f18fe3f100599b3148b0ff3501e9607d03fc61ddbd0ce6", "dweb:/ipfs/QmTzu1NpEiVrvrmTrAkmKxd8YoUddKQTpCuiQb1evJpBwo"],
                "license": "BUSL-1.1"
            },
            "lib/starport/src/lib/Validation.sol": {
                "keccak256": "0x5aced24de9ff148fc78120378155c7c6205ee34febbb3ba18523723f33cb03d9",
                "urls": ["bzz-raw://62abe44f3e5745eb1abdc38e4dc638ac72149d372fcb38589a44517110df1fde", "dweb:/ipfs/QmVrvAF1drEzbFhu8nnSB7C4eXVieek7JEon3CrT1fa3dC"],
                "license": "BUSL-1.1"
            },
            "lib/starport/src/pricing/Pricing.sol": {
                "keccak256": "0xd7cca1bfa7b8473e5d1fc68686e12a1b526755f68f04ee4cdc5db20e47a2c9b8",
                "urls": ["bzz-raw://b1b82a790a7e8bfc113c98dc4064780120a83c3491cfb41b6d7ce7454f526444", "dweb:/ipfs/QmbhqbJCr7gQqaNNxJo8A6BBAPmD69DA7uWFq9Gh1MuKbv"],
                "license": "BUSL-1.1"
            },
            "lib/starport/src/settlement/Settlement.sol": {
                "keccak256": "0x6d8411d7b32b6f8c98a85061a499b74d5a9533c28fadd40ce742081c79370869",
                "urls": ["bzz-raw://3ecad917a73d8ac8f6593273f45e0abac81be467ccdd1e141dce028d9f183e3c", "dweb:/ipfs/QmVPZUfD2WjD6mNGWeCPs6vK9JMCw6haaJ2bPM5pZrVzxh"],
                "license": "BUSL-1.1"
            },
            "lib/starport/src/status/Status.sol": {
                "keccak256": "0xf333483f3b32fa239976b63dd8dc200b5e0fe7f394c241979cf6b77f6b3dc9a1",
                "urls": ["bzz-raw://9f5ebddb1455c5be8004b05be15a56ed064830542d6b87aaf8515a953ad02ebc", "dweb:/ipfs/QmaMCUMtJdrdf3L4qbExiUxYiay15WPMFxM2f4t9A7o7ck"],
                "license": "BUSL-1.1"
            },
            "src/encodeHelpers/EncodeHelpers.sol": {
                "keccak256": "0x1f4ed1c2e3929ad98d0eeec9794d9cfb4e7fec77599d058695cc612b5cb30094",
                "urls": ["bzz-raw://90b4f3261b2ba3f39669c8940fb74632f3fb38b3d3de02646b53911a25ab27ad", "dweb:/ipfs/QmYiRndvcxiHw5RmFvrgSj5apRaB2QCTaHsujPUkkAp6hV"],
                "license": null
            }
        }, "version": 1
    },
    "ast": {
        "absolutePath": "src/encodeHelpers/EncodeHelpers.sol",
        "id": 12105,
        "exportedSymbols": {"EncodeHelpers": [12104], "Starport": [11028]},
        "nodeType": "SourceUnit",
        "src": "0:228:21",
        "nodes": [{
            "id": 12089,
            "nodeType": "PragmaDirective",
            "src": "0:23:21",
            "nodes": [],
            "literals": ["solidity", "^", "0.8", ".0"]
        }, {
            "id": 12091,
            "nodeType": "ImportDirective",
            "src": "25:52:21",
            "nodes": [],
            "absolutePath": "lib/starport/src/Starport.sol",
            "file": "starport-core/Starport.sol",
            "nameLocation": "-1:-1:-1",
            "scope": 12105,
            "sourceUnit": 11029,
            "symbolAliases": [{
                "foreign": {
                    "id": 12090,
                    "name": "Starport",
                    "nodeType": "Identifier",
                    "overloadedDeclarations": [],
                    "referencedDeclaration": 11028,
                    "src": "33:8:21",
                    "typeDescriptions": {}
                }, "nameLocation": "-1:-1:-1"
            }],
            "unitAlias": ""
        }, {
            "id": 12104,
            "nodeType": "ContractDefinition",
            "src": "78:149:21",
            "nodes": [{
                "id": 12103,
                "nodeType": "FunctionDefinition",
                "src": "107:118:21",
                "nodes": [],
                "body": {
                    "id": 12102,
                    "nodeType": "Block",
                    "src": "197:28:21",
                    "nodes": [],
                    "statements": [{
                        "expression": {
                            "id": 12100,
                            "name": "loan",
                            "nodeType": "Identifier",
                            "overloadedDeclarations": [],
                            "referencedDeclaration": 12094,
                            "src": "214:4:21",
                            "typeDescriptions": {
                                "typeIdentifier": "t_struct$_Loan_$9675_memory_ptr",
                                "typeString": "struct Starport.Loan memory"
                            }
                        }, "functionReturnParameters": 12099, "id": 12101, "nodeType": "Return", "src": "207:11:21"
                    }]
                },
                "functionSelector": "42699aa0",
                "implemented": true,
                "kind": "function",
                "modifiers": [],
                "name": "encodeLoan",
                "nameLocation": "116:10:21",
                "parameters": {
                    "id": 12095,
                    "nodeType": "ParameterList",
                    "parameters": [{
                        "constant": false,
                        "id": 12094,
                        "mutability": "mutable",
                        "name": "loan",
                        "nameLocation": "148:4:21",
                        "nodeType": "VariableDeclaration",
                        "scope": 12103,
                        "src": "127:25:21",
                        "stateVariable": false,
                        "storageLocation": "memory",
                        "typeDescriptions": {
                            "typeIdentifier": "t_struct$_Loan_$9675_memory_ptr",
                            "typeString": "struct Starport.Loan"
                        },
                        "typeName": {
                            "id": 12093,
                            "nodeType": "UserDefinedTypeName",
                            "pathNode": {
                                "id": 12092,
                                "name": "Starport.Loan",
                                "nameLocations": ["127:8:21", "136:4:21"],
                                "nodeType": "IdentifierPath",
                                "referencedDeclaration": 9675,
                                "src": "127:13:21"
                            },
                            "referencedDeclaration": 9675,
                            "src": "127:13:21",
                            "typeDescriptions": {
                                "typeIdentifier": "t_struct$_Loan_$9675_storage_ptr",
                                "typeString": "struct Starport.Loan"
                            }
                        },
                        "visibility": "internal"
                    }],
                    "src": "126:27:21"
                },
                "returnParameters": {
                    "id": 12099,
                    "nodeType": "ParameterList",
                    "parameters": [{
                        "constant": false,
                        "id": 12098,
                        "mutability": "mutable",
                        "name": "",
                        "nameLocation": "-1:-1:-1",
                        "nodeType": "VariableDeclaration",
                        "scope": 12103,
                        "src": "175:20:21",
                        "stateVariable": false,
                        "storageLocation": "memory",
                        "typeDescriptions": {
                            "typeIdentifier": "t_struct$_Loan_$9675_memory_ptr",
                            "typeString": "struct Starport.Loan"
                        },
                        "typeName": {
                            "id": 12097,
                            "nodeType": "UserDefinedTypeName",
                            "pathNode": {
                                "id": 12096,
                                "name": "Starport.Loan",
                                "nameLocations": ["175:8:21", "184:4:21"],
                                "nodeType": "IdentifierPath",
                                "referencedDeclaration": 9675,
                                "src": "175:13:21"
                            },
                            "referencedDeclaration": 9675,
                            "src": "175:13:21",
                            "typeDescriptions": {
                                "typeIdentifier": "t_struct$_Loan_$9675_storage_ptr",
                                "typeString": "struct Starport.Loan"
                            }
                        },
                        "visibility": "internal"
                    }],
                    "src": "174:22:21"
                },
                "scope": 12104,
                "stateMutability": "pure",
                "virtual": false,
                "visibility": "public"
            }],
            "abstract": false,
            "baseContracts": [],
            "canonicalName": "EncodeHelpers",
            "contractDependencies": [],
            "contractKind": "contract",
            "fullyImplemented": true,
            "linearizedBaseContracts": [12104],
            "name": "EncodeHelpers",
            "nameLocation": "87:13:21",
            "scope": 12105,
            "usedErrors": []
        }]
    },
    "id": 21
}.abi;

const indexerURL = 'http://localhost:4000/graphql';


const loanFetchById =
    (loanId: string) => {

        const query = `
query MyQuery {
  loans (where: {id_eq : "${loanId}"}) {
    id
    issuer
    originator
    start
    terms {
      pricing
      pricingData
      settlement
      settlementData
      status
      statusData
    }
    custodian
    collateral {
      amount
      identifier
      itemType
      token
    }
    borrower
    debt {
      token
      itemType
      identifier
      amount
    }
  }
}
`;
        return query;
    }

const fetchLoan = async (loanId: string) => {
    const query = loanFetchById(loanId);
    const response = await fetch(indexerURL, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({query})
    });
    const json = await response.json();
    return json.data.loans[0];
}

const args = process.argv.slice(2);
const loanId = args[0];
const main = async () => {
    const loan = await fetchLoan(loanId);
    console.log(encodeFunctionResult({abi: ABI, result: [loan], functionName: 'encodeLoan'}));
}

main();