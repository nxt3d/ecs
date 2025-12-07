// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/CredentialResolver.sol";
import "../src/utils/NameCoder.sol";

contract CredentialResolverTest is Test {
    /* --- Test Accounts --- */
    
    address owner = address(0x1001);
    address notOwner = address(0x1002);
    
    /* --- Contract Variables --- */
    
    CredentialResolver public resolver;
    
    /* --- Setup --- */
    
    function setUp() public {
        resolver = new CredentialResolver();
        resolver.initialize(owner);
    }
    
    /* --- Test Dividers --- */
    
    function test1000________________________________________________________________________________() public pure {}
    function test1100____________________CREDENTIAL_RESOLVER_TESTS_________________________________() public pure {}
    function test1200________________________________________________________________________________() public pure {}
    
    /* --- Setter Tests --- */
    
    function test_001____setText____________________OwnerCanSetText() public {
        string memory key = "com.twitter";
        string memory value = "@alice";
        
        vm.prank(owner);
        resolver.setText(key, value);
        
        assertEq(resolver.text(bytes32(0), key), value);
    }
    
    function test_002____setText____________________NonOwnerCannotSetText() public {
        string memory key = "com.twitter";
        string memory value = "@alice";
        
        vm.prank(notOwner);
        vm.expectRevert();
        resolver.setText(key, value);
    }
    
    function test_003____setData____________________OwnerCanSetData() public {
        string memory key = "credential.score";
        bytes memory value = abi.encode(uint256(100));
        
        vm.prank(owner);
        resolver.setData(key, value);
        
        assertEq(resolver.data(bytes32(0), key), value);
    }
    
    function test_004____setData____________________NonOwnerCannotSetData() public {
        string memory key = "credential.score";
        bytes memory value = abi.encode(uint256(100));
        
        vm.prank(notOwner);
        vm.expectRevert();
        resolver.setData(key, value);
    }
    
    function test_005____setAddr____________________OwnerCanSetAddress() public {
        address ethAddr = address(0x5678);
        
        vm.prank(owner);
        resolver.setAddr(ethAddr);
        
        bytes memory result = resolver.addr(bytes32(0), 60);
        assertEq(result, abi.encodePacked(ethAddr));
    }
    
    function test_006____setAddr____________________NonOwnerCannotSetAddress() public {
        address ethAddr = address(0x5678);
        
        vm.prank(notOwner);
        vm.expectRevert();
        resolver.setAddr(ethAddr);
    }
    
    function test_007____setContenthash_____________OwnerCanSetContenthash() public {
        bytes memory hash = hex"e301017012204edd2984eeaf3ddf50bac238ec95c5713fb40b5e428b508fdbe55d3b9f155ffe";
        
        vm.prank(owner);
        resolver.setContenthash(hash);
        
        assertEq(resolver.contenthash(bytes32(0)), hash);
    }
    
    function test_008____setContenthash_____________NonOwnerCannotSetContenthash() public {
        bytes memory hash = hex"e301017012204edd2984eeaf3ddf50bac238ec95c5713fb40b5e428b508fdbe55d3b9f155ffe";
        
        vm.prank(notOwner);
        vm.expectRevert();
        resolver.setContenthash(hash);
    }
    
    /* --- Getter Tests --- */
    
    function test_009____text_______________________ReturnsTextRecord() public {
        string memory key = "avatar";
        string memory value = "https://example.com/avatar.png";
        
        vm.prank(owner);
        resolver.setText(key, value);
        
        string memory result = resolver.text(bytes32(0), key);
        assertEq(result, value);
    }
    
    function test_010____data_______________________ReturnsDataRecord() public {
        string memory key = "proof";
        bytes memory value = abi.encode("signature_data");
        
        vm.prank(owner);
        resolver.setData(key, value);
        
        bytes memory result = resolver.data(bytes32(0), key);
        assertEq(result, value);
    }
    
    function test_011____addr_______________________ReturnsAddressRecord() public {
        address ethAddr = address(0x9999);
        
        vm.prank(owner);
        resolver.setAddr(ethAddr);
        
        bytes memory result = resolver.addr(bytes32(0), 60);
        assertEq(result, abi.encodePacked(ethAddr));
    }
    
    function test_012____contenthash________________ReturnsContenthash() public {
        bytes memory hash = hex"1234567890abcdef";
        
        vm.prank(owner);
        resolver.setContenthash(hash);
        
        bytes memory result = resolver.contenthash(bytes32(0));
        assertEq(result, hash);
    }
    
    /* --- Multi-coin Address Tests --- */
    
    function test_013____setAddr____________________OwnerCanSetMultiCoinAddress() public {
        uint256 btcCoinType = 0;
        bytes memory btcAddr = hex"76a91489abcdefabbaabbaabbaabbaabbaabbaabbaabba88ac";
        
        vm.prank(owner);
        resolver.setAddr(btcCoinType, btcAddr);
        
        bytes memory result = resolver.addr(bytes32(0), btcCoinType);
        assertEq(result, btcAddr);
    }
    
    function test_014____setAddr____________________NonOwnerCannotSetMultiCoinAddress() public {
        uint256 btcCoinType = 0;
        bytes memory btcAddr = hex"76a91489abcdefabbaabbaabbaabbaabbaabbaabbaabba88ac";
        
        vm.prank(notOwner);
        vm.expectRevert();
        resolver.setAddr(btcCoinType, btcAddr);
    }
    
    /* --- Ownership Tests --- */
    
    function test_015____owner______________________ReturnsCorrectOwner() public {
        assertEq(resolver.owner(), owner);
    }
    
    function test_016____transferOwnership__________OwnerCanTransferOwnership() public {
        address newOwner = address(0x2001);
        
        vm.prank(owner);
        resolver.transferOwnership(newOwner);
        
        assertEq(resolver.owner(), newOwner);
    }
    
    /* --- Interface Support Tests --- */
    
    function test_017____supportsInterface__________SupportsIERC165() public {
        assertTrue(resolver.supportsInterface(type(IERC165).interfaceId));
    }
    
    function test_018____supportsInterface__________SupportsIExtendedResolver() public {
        assertTrue(resolver.supportsInterface(type(IExtendedResolver).interfaceId));
    }
}
