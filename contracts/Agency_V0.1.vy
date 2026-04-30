# pragma version ^0.4.0
"""
@title ERC-8232: On-Chain Agency Execution for Represented RWAs
@notice Agency vault implementation. Deployed as an immutable proxy for each user.
"""

# =============================================================
# Storage
# =============================================================
owner: public(address)
is_initialized: bool

# Agent Permissions: agent -> rwa_token -> bitmask
permissions: public(HashMap[address, HashMap[address, uint256]])

# THE FIREWALL: Bit Index -> Function Selector (e.g., 0 -> 0xa9059cbb) 
bit_to_selector: public(HashMap[uint256, bytes4])

erc_8004: public(address)
usdc: public(address)

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
# Core Logic
# =============================================================

@external
def initialize(_owner: address, _erc_8004: address, _usdc: address):
    assert not self.is_initialized, "Already initialized"
    self.owner = _owner
    self.erc_8004 = _erc_8004
    self.usdc = _usdc
    self.is_initialized = True

@external
def mapSelector(bit_index: uint256, selector: bytes4):
    """
    @notice Links a permission bit to a specific function selector. 
    """
    assert msg.sender == self.owner, "Not Owner"
    self.bit_to_selector[bit_index] = selector

@external
def setAgentPermission(agent: address, rwa_token: address, bitmask: uint256):
    assert msg.sender == self.owner, "Not Owner"
    self.permissions[agent][rwa_token] = bitmask
    log AgencyAuthorized(agent, rwa_token, bitmask)

@external
@nonreentrant
def performAgencyAction(
    rwa_token: address,
    action_type_bit: uint256,
    call_data: Bytes[1024]
) -> Bytes[1024]:


    # 1. Identity & Permission Check
    bitmask: uint256 = self.permissions[msg.sender][rwa_token]
    assert bitmask & (1 << action_type_bit) > 0, "ERROR: Permission Bit Off"

    # 2. Selector Validation (The Firewall)
    actual_selector: bytes4 = extract32(slice(call_data, 0, 4), 0, output_type=bytes4)
    expected_selector: bytes4 = self.bit_to_selector[action_type_bit]
    assert actual_selector == expected_selector, "ERROR: Selector Mismatch"

    # 3. Execution
    result: Bytes[1024] = raw_call(
        rwa_token,
        call_data,
        max_outsize=1024,
        revert_on_failure=True
    )

    log AgencyActionPerformed(msg.sender, rwa_token, action_type_bit, actual_selector)
    return result