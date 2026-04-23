# pragma version ^0.4.0
"""
@title 8232Factory: Factory for Deploying User-Specific ERC-8232 Proxies
@notice This factory contract allows users to deploy their own ERC-8232 compliant proxy contracts. Each user can have a personalized proxy that manages their agency permissions and interactions with RWA tokens.
@dev The factory uses the EVM's CREATE2 opcode to deploy minimal proxy contracts that forward calls to a master implementation. This design ensures that each user's proxy is immutable and has a unique address derived from their own address, allowing for easy integration with off-chain systems.
""" 


# The master template that all proxies will copy
master_proxy: public(address)

# Mapping of Bit Index -> Function Selector (4 bytes)
# Example: 0 -> 0xa9059cbb (transfer)
bit_to_selector: public(HashMap[uint256, bytes4])

# Track proxies: Owner => Proxy Address
get_proxy_by_owner: public(HashMap[address, address])
# Track owners: Proxy Address => Owner
get_owner_by_proxy: public(HashMap[address, address])

ERC8004_address: public(address)  # For ownership verification (optional)
USDC_address: public(address)    # For potential fee handling (optional)

event ProxyDeployed:
    owner: indexed(address) 
    proxy_address: address


@deploy
def __init__(_master_proxy: address, _erc8004: address, _usdc: address):
    self.master_proxy = _master_proxy
    self.ERC8004_address = _erc8004
    self.USDC_address = _usdc

@external
def deploy_settled_proxy() -> address:
    """
    @notice Deploys an immutable 'Settled Proxy' for the caller.
    @dev This uses the EVM's CREATE2 opcode to create a minimal proxy that forwards calls to a master implementation.
         The proxy is immutable and cannot be upgraded, ensuring consistent behavior. The caller becomes the owner
         of the proxy, which can be used for executing actions on behalf of the caller in other contracts.
    @return The address of the newly deployed proxy.
    """
    # Ensure a user only has one proxy for simplicity in v1
    assert self.get_proxy_by_owner[msg.sender] == empty(address), "Proxy already exists"

    # Create a clone of the master implementation
    # This is an immutable forwarder; the code at 'master_proxy' cannot change.
    new_proxy: address = create_forwarder_to(self.master_proxy)

    # Initialize the proxy (setting Bob as the owner of his new vault)
    # This assumes the Proxy has an 'initialize' function
    # Factory deploy should use:
    initialize_data: Bytes[100] = concat(
        method_id("initialize(address,address,address)"),
        convert(msg.sender, bytes32),
        convert(self.ERC8004_address, bytes32),
        convert(self.USDC_address, bytes32)
    )
    raw_call(new_proxy, initialize_data)
    
    # Record the mapping
    self.get_proxy_by_owner[msg.sender] = new_proxy
    self.get_owner_by_proxy[new_proxy] = msg.sender

    log ProxyDeployed(msg.sender, new_proxy)
    return new_proxy