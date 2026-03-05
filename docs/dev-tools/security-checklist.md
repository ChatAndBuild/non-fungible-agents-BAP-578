# BAP-578 Security Checklist (Dev Kit Aligned)

Use this checklist before deployment and before PR merge.

## Authorization and Ownership

- [ ] Every operator-gated action verifies `ownerOf(tokenId)`.
- [ ] No write path can bypass `tokenId` ownership checks.
- [ ] Role boundaries for owner/operator/admin are explicit.

## Vault and Funds Safety

- [ ] Vault debit is restricted to approved controllers only.
- [ ] Credit/debit operations validate target addresses and amounts.
- [ ] Reentrancy-sensitive fund flows are guarded.

## Deployment Hygiene

- [ ] Deployment order is documented and reproducible.
- [ ] Post-deploy role/config assertions are scripted.
- [ ] Verification steps for BscScan are documented.

## Testing Baseline

- [ ] Positive path: owner/operator can execute expected actions.
- [ ] Negative path: unauthorized account is rejected.
- [ ] Balance invariants hold across deposit/withdraw flows.

## Audit Notes

- [ ] This checklist is a pre-audit baseline, not a replacement for formal smart-contract security audit.
- [ ] Any contract logic changes should still receive dedicated review and static/dynamic analysis.
