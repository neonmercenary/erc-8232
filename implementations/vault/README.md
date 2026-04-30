## Reference Implementation: ERC-8232 Agency Vault
 
### ⚠️ Compliance Note: Proxy Forwarding
When Agency.vy executes `raw_call(rwa_token, ...)`, the RWA token sees the **proxy address** as `msg.sender`.

To maintain ERC-3643/7943 compliance:
- Option A (Recommended): Use principal-custodied tokens + `transferFrom` allowances
- Option B: Issuers pre-whitelist Agency.vy factory addresses in their compliance registry
- Option C: Add a compliance bridge that re-attests ONCHAINID before forwarding (adds gas)

Default: Option A for maximum compatibility.

### For users requiring per-account isolation, AA compatibility, or advanced execution routing
The `ERC8232Factory` + `ERC8232Proxy` pattern implements this standard as a user-specific vault.
- Factory deploys immutable proxies via `create_forwarder_to`
- Bit-to-selector mapping prevents calldata spoofing
- Recommended for institutional treasuries, custodial agents, or ERC-4337 integration
⚠️ Note: Proxy architecture requires issuer-side compliance bridging or token migration to proxy custody.

