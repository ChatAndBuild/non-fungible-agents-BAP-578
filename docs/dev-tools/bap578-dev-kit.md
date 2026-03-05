# BAP-578 Dev Kit

The Dev Kit packages common BAP-578 developer friction points into five installable Skills.

## 1. Adapter Blueprint

```bash
npx @skillshub/bap578-adapter-blueprint
```

Generates a minimal vault-aware adapter skeleton for token-bound accounts.

## 2. Vault Checklist

```bash
npx @skillshub/bap578-vault-checklist
```

Produces a checklist for `tokenId` authorization and vault controller hygiene.

## 3. Deploy Plan

```bash
npx @skillshub/bap578-deploy-plan
```

Builds a sequenced deployment and verification plan for BSC environments.

## 4. Test Template

```bash
npx @skillshub/bap578-test-template
```

Generates a Hardhat test skeleton for permission checks and balance invariants.

## 5. Contract Idea Sprint

```bash
npx @skillshub/bap578-contract-idea-sprint
```

Converts a product idea into a one-day implementation plan for shippable BAP-578 contracts.

## Version Pinning (Recommended)

Use pinned versions in production docs or CI scripts:

```bash
npx @skillshub/bap578-adapter-blueprint@0.1.0
npx @skillshub/bap578-vault-checklist@0.1.0
npx @skillshub/bap578-deploy-plan@0.1.0
npx @skillshub/bap578-test-template@0.1.0
npx @skillshub/bap578-contract-idea-sprint@0.1.0
```

## Optional In-Repo Templates

This PR also includes minimal skeleton files for teams that want local starting points:

- `contracts/templates/BAP578AdapterBlueprint.sol`
- `test/templates/bap578-adapter.template.test.js`
