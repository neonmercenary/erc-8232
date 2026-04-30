import pytest
from ape import project, accounts, chain

def test_keccak_permissions_basic():
    """Test basic keccak256-based permission setting and execution"""
    owner = accounts.test_accounts[0]
    agent = accounts.test_accounts[1]
    erc8004 = accounts.test_accounts[3]
    usdc = accounts.test_accounts[4]

    # Deploy master proxy and factory
    master_proxy = owner.deploy(project.Proxy)
    factory = owner.deploy(project.Factory, master_proxy, erc8004, usdc)

    # Deploy user proxy
    receipt = factory.deploy_settled_proxy(sender=owner)
    deploy_events = list(receipt.decode_logs(factory.ProxyDeployed))
    proxy = project.Proxy.at(deploy_events[0].proxy_address)

    # Deploy mock token
    mock_rwa = owner.deploy(project.MockRWA)

    # Setup: map bit 0 to transfer selector
    proxy.mapSelector(0, "0xa9059cbb", sender=owner)

    # Set permission using keccak256 storage
    proxy.setAgentPermission(agent, mock_rwa, 1, 3600, sender=owner)  # bitmask=1 (bit 0)

    # Create transfer calldata
    to_address = accounts.test_accounts[5].address
    amount = 1000
    to_address_bytes = bytes.fromhex(to_address[2:])
    padded_address = to_address_bytes.rjust(32, b'\x00')
    amount_bytes = amount.to_bytes(32, 'big')
    calldata = b"\xa9\x05\x9c\xbb" + padded_address + amount_bytes

    # Execute action - should succeed
    tx = proxy.performAgencyAction(mock_rwa, 0, calldata, sender=agent)

    # Verify event was emitted
    events = list(tx.decode_logs(proxy.AgencyActionPerformed))
    assert len(events) == 1
    assert events[0].agent == agent
    assert events[0].rwa_token == mock_rwa
    assert events[0].action_type == 0
    assert events[0].selector == b"\xa9\x05\x9c\xbb"





def test_time_window_violation():
    """Test rejection when executing outside time window"""
    owner = accounts.test_accounts[0]
    agent = accounts.test_accounts[1]
    erc8004 = accounts.test_accounts[3]
    usdc = accounts.test_accounts[4]

    # Deploy contracts
    master_proxy = owner.deploy(project.Proxy)
    factory = owner.deploy(project.Factory, master_proxy, erc8004, usdc)
    receipt = factory.deploy_settled_proxy(sender=owner)
    deploy_events = list(receipt.decode_logs(factory.ProxyDeployed))
    proxy = project.Proxy.at(deploy_events[0].proxy_address)
    mock_rwa = owner.deploy(project.MockRWA)

    # Setup permissions
    proxy.mapSelector(0, "0xa9059cbb", sender=owner)
    proxy.setAgentPermission(agent, mock_rwa, 1, 3600, sender=owner)

    # Set restrictive time window (future only)
    current_time = chain.blocks[-1].timestamp
    start_time = current_time + 3600  # +1 hour
    end_time = current_time + 7200    # +2 hours

    metadata = (start_time << 128) | end_time
    transfer_selector = b"\xa9\x05\x9c\xbb"
    proxy.setSelectorMetadata(agent, mock_rwa, transfer_selector, metadata, sender=owner)

    # Try to execute before time window
    to_address = accounts.test_accounts[5].address
    amount = 1000
    to_address_bytes = bytes.fromhex(to_address[2:])
    padded_address = to_address_bytes.rjust(32, b'\x00')
    amount_bytes = amount.to_bytes(32, 'big')
    calldata = b"\xa9\x05\x9c\xbb" + padded_address + amount_bytes

    # Should fail - before execution window
    with pytest.raises(Exception) as exc_info:
        proxy.performAgencyAction(mock_rwa, 0, calldata, sender=agent)

    assert "failed".lower() in str(exc_info.value)

def test_expired_permission():
    """Test rejection when permission has expired"""
    owner = accounts.test_accounts[0]
    agent = accounts.test_accounts[1]
    erc8004 = accounts.test_accounts[3]
    usdc = accounts.test_accounts[4]

    # Deploy contracts
    master_proxy = owner.deploy(project.Proxy)
    factory = owner.deploy(project.Factory, master_proxy, erc8004, usdc)
    receipt = factory.deploy_settled_proxy(sender=owner)
    deploy_events = list(receipt.decode_logs(factory.ProxyDeployed))
    proxy = project.Proxy.at(deploy_events[0].proxy_address)
    mock_rwa = owner.deploy(project.MockRWA)

    # Setup permissions with short expiry
    proxy.mapSelector(0, "0xa9059cbb", sender=owner)
    proxy.setAgentPermission(agent, mock_rwa, 1, 10, sender=owner)  # 10 sec expiry

    # Advance time past expiry
    chain.mine(timestamp=chain.blocks[-1].timestamp + 11)

    # Create transfer calldata
    to_address = accounts.test_accounts[5].address
    amount = 1000
    to_address_bytes = bytes.fromhex(to_address[2:])
    padded_address = to_address_bytes.rjust(32, b'\x00')
    amount_bytes = amount.to_bytes(32, 'big')
    calldata = b"\xa9\x05\x9c\xbb" + padded_address + amount_bytes

    # Should fail - expired
    with pytest.raises(Exception) as exc_info:
        proxy.performAgencyAction(mock_rwa, 0, calldata, sender=agent)

    assert "Agency Expired" in str(exc_info.value)

def test_selector_mismatch():
    """Test rejection when selector doesn't match mapped bit"""
    owner = accounts.test_accounts[0]
    agent = accounts.test_accounts[1]
    erc8004 = accounts.test_accounts[3]
    usdc = accounts.test_accounts[4]

    # Deploy contracts
    master_proxy = owner.deploy(project.Proxy)
    factory = owner.deploy(project.Factory, master_proxy, erc8004, usdc)
    receipt = factory.deploy_settled_proxy(sender=owner)
    deploy_events = list(receipt.decode_logs(factory.ProxyDeployed))
    proxy = project.Proxy.at(deploy_events[0].proxy_address)
    mock_rwa = owner.deploy(project.MockRWA)

    # Setup: map bit 0 to transfer, but try to use approve selector
    proxy.mapSelector(0, "0xa9059cbb", sender=owner)  # transfer
    proxy.setAgentPermission(agent, mock_rwa, 1, 3600, sender=owner)

    # Create approve calldata (wrong selector)
    spender = accounts.test_accounts[5].address
    amount = 1000
    spender_bytes = bytes.fromhex(spender[2:])
    padded_spender = spender_bytes.rjust(32, b'\x00')
    amount_bytes = amount.to_bytes(32, 'big')
    calldata = b"\x09\x5e\xa7\xb3" + padded_spender + amount_bytes  # approve selector

    # Should fail - selector mismatch
    with pytest.raises(Exception) as exc_info:
        proxy.performAgencyAction(mock_rwa, 0, calldata, sender=agent)

    assert "failed" in str(exc_info.value)

def test_permission_bit_off():
    """Test rejection when agent doesn't have required permission bit"""
    owner = accounts.test_accounts[0]
    agent = accounts.test_accounts[1]
    erc8004 = accounts.test_accounts[3]
    usdc = accounts.test_accounts[4]

    # Deploy contracts
    master_proxy = owner.deploy(project.Proxy)
    factory = owner.deploy(project.Factory, master_proxy, erc8004, usdc)
    receipt = factory.deploy_settled_proxy(sender=owner)
    deploy_events = list(receipt.decode_logs(factory.ProxyDeployed))
    proxy = project.Proxy.at(deploy_events[0].proxy_address)
    mock_rwa = owner.deploy(project.MockRWA)

    # Setup: map bit 0 to transfer, but only grant bit 1 permission
    proxy.mapSelector(0, "0xa9059cbb", sender=owner)
    proxy.setAgentPermission(agent, mock_rwa, 2, 3600, sender=owner)  # bitmask=2 (bit 1 only)

    # Create transfer calldata and try to execute with bit 0
    to_address = accounts.test_accounts[5].address
    amount = 1000
    to_address_bytes = bytes.fromhex(to_address[2:])
    padded_address = to_address_bytes.rjust(32, b'\x00')
    amount_bytes = amount.to_bytes(32, 'big')
    calldata = b"\xa9\x05\x9c\xbb" + padded_address + amount_bytes

    # Should fail - permission bit off
    with pytest.raises(Exception) as exc_info:
        proxy.performAgencyAction(mock_rwa, 0, calldata, sender=agent)

    assert "Permission Bit Off".lower() in str(exc_info.value).lower()



# Result: 4/5 passed, 1 failed (time window violation)