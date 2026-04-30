# pragma version ^0.4.0

master_proxy: public(address)
get_proxy_by_owner: public(HashMap[address, address])
get_owner_by_proxy: public(HashMap[address, address])
ERC8004_address: public(address)
USDC_address: public(address)

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
    assert self.get_proxy_by_owner[msg.sender] == empty(address), "Proxy already exists"

    # CREATE2 Deployment with deterministic address based on owner
    new_proxy: address = create_forwarder_to(self.master_proxy)

    # Standard Vyper 0.4.0 initialization 
    initialize_data: Bytes[128] = concat(
        method_id("initialize(address,address,address)"),
        convert(msg.sender, bytes32),
        convert(self.ERC8004_address, bytes32),
        convert(self.USDC_address, bytes32)
    )
    raw_call(new_proxy, initialize_data)
    
    self.get_proxy_by_owner[msg.sender] = new_proxy
    self.get_owner_by_proxy[new_proxy] = msg.sender

    log ProxyDeployed(msg.sender, new_proxy)
    return new_proxy