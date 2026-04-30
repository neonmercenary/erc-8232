# pragma version ^0.4.0
"""
@title ERC-8232: On-Chain Agency Execution for Represented RWAs
@notice Enhanced implementation with Temporal Expiry and Role-Based Mapping.
"""

# =============================================================
# Storage
# =============================================================
owner: public(address)
is_initialized: bool

# Agent Permissions: agent -> rwa_token -> (bitmask, expiry)
struct Permission:
    bitmask: uint256
    expiry: uint256

permissions: public(HashMap[address, HashMap[address, Permission]])

# THE FIREWALL: Bit Index -> Function Selector
bit_to_selector: public(HashMap[uint256, bytes4])

erc_8004: public(address)
usdc: public(address)
FACTORY_ADDRESS: public(address)
# =============================================================
# Events
# =============================================================
event AgencyAuthorized:
    agent: indexed(address)
    rwa_token: indexed(address) 
    bitmask: uint256
    expiry: uint256

event AgencyActionPerformed:
    agent: indexed(address)
    owner: indexed(address) # Added for Portable Verification (Damon's point)
    rwa_token: indexed(address)
    action_type: uint256
    selector: bytes4

# =============================================================
# Core Logic
# =============================================================

@external
def initialize(_owner: address, _erc_8004: address, _usdc: address):
    assert not self.is_initialized, "Already initialized"
    self.FACTORY_ADDRESS = msg.sender
    self.owner = _owner
    self.erc_8004 = _erc_8004
    self.usdc = _usdc
    self.is_initialized = True

@external
def mapSelector(bit_index: uint256, selector: bytes4):
    """
    @notice Links a permission role bit to a specific function selector.
    """
    assert msg.sender == self.owner, "Not Owner"
    # Ensure bit_index is within our 6-role standard (0-5)
    assert bit_index < 6, "Out of standard range"
    self.bit_to_selector[bit_index] = selector

@external
def setAgentPermission(agent: address, rwa_token: address, bitmask: uint256, duration: uint256):
    """
    @notice Grants scoped agency with a temporal expiry.
    """
    assert msg.sender == self.owner, "Not Owner"
    
    expiry: uint256 = block.timestamp + duration
    self.permissions[agent][rwa_token] = Permission({
        bitmask: bitmask,
        expiry: expiry
    })
    
    log AgencyAuthorized(agent, rwa_token, bitmask, expiry)

@external
@nonreentrant
def performAgencyAction(
    rwa_token: address,
    action_type_bit: uint256,
    call_data: Bytes[1024]
) -> Bytes[1024]:

    # 1. Identity, Permission & Expiry Check
    perm: Permission = self.permissions[msg.sender][rwa_token]
    
    assert block.timestamp <= perm.expiry, "ERROR: Agency Expired"
    assert perm.bitmask & (1 << action_type_bit) > 0, "ERROR: Permission Bit Off"

    # 2. Selector Validation (The Firewall)
    # Using Vyper 0.4.0 extraction logic
    actual_selector: bytes4 = extract32(slice(call_data, 0, 4), 0, output_type=bytes4)
    expected_selector: bytes4 = self.bit_to_selector[action_type_bit]
    
    assert actual_selector == expected_selector, "ERROR: Selector Mismatch"

    # 3. Execution (Hand-off to RAMS/Token Layer)
    result: Bytes[1024] = raw_call(
        rwa_token,
        call_data,
        max_outsize=1024,
        revert_on_failure=True
    )

    # 4. Portable Event Emission
    log AgencyActionPerformed(msg.sender, self.owner, rwa_token, action_type_bit, actual_selector)
    return result