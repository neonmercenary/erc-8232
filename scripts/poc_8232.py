from ape import accounts, project, networks
from . import FACTORY, AGENCY, DEPLOYER, PASS, load_network_addresses

_8004, MOCK_USDC = load_network_addresses(networks.active_provider.network.name)

def main():
    deployer = accounts.load(DEPLOYER)
    deployer.set_autosign(True, passphrase=PASS)  # Enable auto-signing for transactions from this account
    print(f"Using deployer account: {deployer.address}")
    
    active_network = networks.active_provider.network.name
    print(f"Active network: {active_network}")

    factory = project.Factory.at(FACTORY)
    agency = project.Proxy.at(AGENCY)

    print(f"Factory address: {factory.address}")
    print(f"Agency address: {agency.address}")

    # 1. Deploy User Proxy, assuming the mastter proxy is already deployed and its address is known
    print("📦 Deploying Personal Proxy...")
    # receipt = factory.deploy_settled_proxy(sender=deployer)
    proxy_address = factory.get_proxy_by_owner(deployer.address)
    print(f"✅ Proxy Deployed at: {proxy_address}")

    
    # 2. MAPPING: Lock Bit 1 to 'transfer(address,uint256)'
    # Selector for transfer: 0xa9059cbb
    print("🔒 Hardening Proxy: Mapping Bit 1 to 'transfer'...")
    proxy = project.Agency.at(proxy_address)
    print("Owner:", proxy.owner())
    proxy.mapSelector(1, b'\xa9\x05\x9c\xbb', sender=deployer)

    # 3. AUTHORIZE: Give self permission for this test
    proxy.setAgentPermission(deployer.address, MOCK_USDC, 2, sender=deployer) # 2 = Bit 1

    print("🧪 Testing VALID Action (Transfer)...")
    cooked_data = "0xa9059cbb0000000000000000000000007e5b0000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001"
    try:
        receipt = proxy.performAgencyAction(MOCK_USDC, 1, bytes.fromhex(cooked_data[2:]), sender=deployer)
        print(f"🎉 Success! Valid action passed. Tx: {receipt.transactionHash.hex()}")
    except Exception as e:
        print(f"❌ Unexpected Failure: {e}")

    # 6. THE TEST: MALICIOUS CALL (Selector Mismatch)
    print("🛡️ Testing MALICIOUS Action (Wrong Selector)...")
    # Using 'approve' selector (0x095ea7b3) while bit is mapped to 'transfer'
    malicious_data = "0x095ea7b30000000000000000000000007e5b000000000000000000000000000000000001ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    try:
        receipt = proxy.performAgencyAction(MOCK_USDC, 1, bytes.fromhex(malicious_data[2:]), sender=deployer)
        print("🚨 CRITICAL FAILURE: Proxy allowed unmapped selector!")
    except Exception as e:
        print(f"🛡️ Proxy blocked the attack! Revert reason: {e}")