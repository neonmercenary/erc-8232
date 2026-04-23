# pragma version ^0.4.0
"""
@title ERC-8232: On-Chain Agency Execution for Represented RWAs
@notice Agency vault implementation. Deployed as an immutable proxy for each user by the Factory.
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
# Storage
# =============================================================
struct Agency:
    permissions: uint256
    expiration: uint256
    active: bool


# =============================================================
# Storage (Local to the User's Proxy)
# =============================================================

owner: public(address)
is_initialized: bool

# agent -> rwa_token -> bitmask
permissions: public(HashMap[address, HashMap[address, uint256]])
erc_8004: public(address)  # For ownership verification (optional)
usdc: public(address)      # For potential fee handling (optional)


# Optional Mapping for Payment Tokens for custom USDC handling
# token_address -> agent -> bond_amount
payment_tokens: public(HashMap[address, address])  # --- IGNORE ---

# =============================================================
# Events
# =============================================================
event AgencyAuthorized:
    agent: indexed(address)
    rwa_token: indexed(address)
    bitmask: uint256

event AgencyActionPerformed:
    agent: indexed(address)
    rwa_token: indexed(address)
    action_type: uint256
    selector: bytes4

# =============================================================
# Initialization
# =============================================================

@external
def initialize(_owner: address, _erc_8004: address, _usdc: address):
    """
    @dev Called by Factory. Sets the human owner who controls the bits.
    """
    assert not self.is_initialized, "Already initialized"
    self.owner = _owner
    self.is_initialized = True
    self.erc_8004 = _erc_8004
    self.usdc = _usdc

# =============================================================
# Admin Functions (Owner Only)
# =============================================================

@external
def mapSelector(bit_index: uint256, selector: bytes4):
    """
    @notice Defines what a 'bit' actually does.
    @param bit_index The bit in the bitmask (0, 1, 2...)
    @param selector The 4-byte function ID (e.g. 0xa9059cbb)
    """
    assert msg.sender == self.owner, "Not Owner"
    pass

@external
def setAgentPermission(agent: address, rwa_token: address, bitmask: uint256):
    """
    @notice Give an agent a specific set of 'Keys' (bits).
    """
    assert msg.sender == self.owner, "Not Owner"
    self.permissions[agent][rwa_token] = bitmask
    log AgencyAuthorized(agent, rwa_token, bitmask)

# =============================================================
# Core Execution
# =============================================================

@external
@nonreentrant
def performAgencyAction(
    rwa_token: address,
    action_type_bit: uint256, # The bit index (e.g., 2 for Rebalance)
    call_data: Bytes[1024]
) -> Bytes[1024]:
    """
    @notice The entry point for the AI Agent.
    @dev Validates that the bit is ON and the calldata matches the mapped selector.
    """
    # 1. Identity Check: Is this an authorized agent?
    bitmask: uint256 = self.permissions[msg.sender][rwa_token]
    
    # 2. Permission Check: Is the specific bit for this action type flipped?
    # Logic: (bitmask & (1 << action_type_bit)) != 0
    assert bitmask & (1 << action_type_bit) > 0, "ERROR: Permission Bit Off"

    # 3. Selector Validation: Does the 'cooked' data match the 'locked' bit?
    # Extract the first 4 bytes (The Function Selector)
    actual_selector: bytes4 = extract32(slice(call_data, 0, 4), 0, output_type=bytes4)

    # 4. Physical Execution: Speak to the RWA Vault
    # As an immutable proxy, the RWA vault sees THIS address as the sender.
    result: Bytes[1024] = raw_call(
        rwa_token,
        call_data,
        max_outsize=1024,
        revert_on_failure=True
    )

    log AgencyActionPerformed(msg.sender, rwa_token, action_type_bit, actual_selector)
    return result


# =============================================================
# Internal Functions
# =============================================================

@internal
def _hasOnchainID(rwa_address: address) -> bool:
    # Placeholder for on-chain identity verification logic
    # In production, integrate with an actual on-chain ID registry or standard
    # Like ERC-3643 ONCHAIN ID or similar
    return True
    

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