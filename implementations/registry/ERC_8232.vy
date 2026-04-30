# pragma version ^0.4.0
"""
@title ERC-8232: On-Chain Agency Execution for Represented RWAs
@notice Minimal execution interface for agents acting as delegated representatives on RWAs
"""

# =============================================================
# Interfaces
# =============================================================
interface IERC8004:
    def ownerOf(agentId: uint256) -> address: view   # optional, for future verification

# =============================================================
# Constants - Permission Bitmask
# =============================================================
TRANSFER: constant(uint256)           = 1 << 0
VOTE: constant(uint256)               = 1 << 1
REBALANCE: constant(uint256)          = 1 << 2
YIELD_OPTIMIZE: constant(uint256)     = 1 << 3
ERC3643_AGENT_ROLE: constant(uint256) = 1 << 4

# =============================================================
# Events
# =============================================================
event AgencyAuthorized:
    owner: indexed(address)
    agent: indexed(address)
    rwa_token: indexed(address)
    permissions: uint256
    expiration: uint256

event AgencyRevoked:
    owner: indexed(address)
    agent: indexed(address)
    rwa_token: indexed(address)

event AgencyActionPerformed:
    owner: indexed(address)
    agent: indexed(address)
    rwa_token: indexed(address)
    action_type: uint256
    data: Bytes[1024]

# =============================================================
# Storage
# =============================================================
struct Agency:
    permissions: uint256
    expiration: uint256
    active: bool



# owner → agent → rwa_token → Agency
agencies: public(HashMap[address, HashMap[address, HashMap[address, Agency]]])

# agent → rwa_token → owner/delegate (for reverse lookup)
delegates: public(HashMap[address, HashMap[address, address]])

ERC8004_address: public(address)  # For ownership verification (optional)
USDC_address: public(address)    # For potential fee handling (optional)


# =============================================================
# Internal Functions
# =============================================================
@internal
def _isValidAgency(owner: address, agent: address, rwa_token: address) -> bool:
    agency: Agency = self.agencies[owner][agent][rwa_token]
    if not agency.active:
        return False
    if agency.expiration < block.timestamp:
        return False
    return True

@internal
@view
def _getAgencyPermissions(owner: address, agent: address, rwa_token: address) -> uint256:
    return self.agencies[owner][agent][rwa_token].permissions
    
@internal
def _hasOnchainID(rwa_address: address) -> bool:
    # Placeholder for on-chain identity verification logic
    # In production, integrate with an actual on-chain ID registry or standard
    # Like ERC-3643 ONCHAIN ID or similar
    return True
    


# =============================================================
# deployment and initialization
# =============================================================
@deploy
def __init__(_erc_8004: address, _usdc: address):
    self.ERC8004_address = _erc_8004
    self.USDC_address = _usdc

# =============================================================
# Core Functions
# =============================================================

@external
def authorizeAgency(
    agent: address,
    rwa_token: address,
    permissions: uint256,
    expiration: uint256
) -> bool:
    # Check for ownership of the RWA token or delegate rights (simplified for demo)
    # In production, integrate with IERC8004 or specific RWA ownership logic
    self.agencies[msg.sender][agent][rwa_token] = Agency(
        permissions = permissions,
        expiration = expiration if expiration > 0 else max_value(uint256),
        active = True
    )
    self.delegates[agent][rwa_token] = msg.sender 
    log AgencyAuthorized(msg.sender, agent, rwa_token, permissions, expiration)
    return True


@external
def revokeAgency(agent: address, rwa_token: address) -> bool:
    owner: address = self.delegates[agent][rwa_token]
    assert msg.sender == owner or msg.sender == agent, "Not authorized to revoke"
    assert self.agencies[owner][agent][rwa_token].active, "No active agency"
    
    self.agencies[owner][agent][rwa_token].active = False
    log AgencyRevoked(owner, agent, rwa_token)
    return True


@view
@external
def isValidAgency(owner: address, agent: address, rwa_token: address) -> bool:
    agency: Agency = self.agencies[owner][agent][rwa_token]
    if not agency.active:
        return False
    if agency.expiration < block.timestamp:
        return False
    return True


@view
@external
def getAgencyPermissions(owner: address, agent: address, rwa_token: address) -> uint256:
    return self._getAgencyPermissions(owner, agent, rwa_token)

@nonreentrant
@external
def performAgencyAction(
    owner: address,
    rwa_token: address,
    action_type: uint256,
    calldata: Bytes[1024]
) -> Bytes[1024]:

    
    assert self._isValidAgency(owner, msg.sender, rwa_token), "Invalid agency"
    assert (self._getAgencyPermissions(owner, msg.sender, rwa_token) & action_type) != 0, "Permission denied"

    # Actually execute the call against the RWA token/contract
    result: Bytes[1024] = raw_call(
        rwa_token,
        calldata,
        max_outsize=1024,
        revert_on_failure=True
    )

    log AgencyActionPerformed(owner, msg.sender, rwa_token, action_type, calldata)
    return result


# Multi-chain helper
@view
@external
def getRepresentedOwner(agent: address, rwa_token: address, chain_id: uint256) -> address:
    """0 = current chain"""
    if chain_id == 0:
        active_chain_id: uint256 = chain.id
    # In production, add reverse mapping storage
    # For now, this is a stub
    return empty(address)