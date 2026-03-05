# Getting Started in 15 Minutes

This quick path helps new contributors go from zero to a validated BAP-578 development baseline.

## Prerequisites (2 minutes)

- Node.js >= 18
- npm

```bash
node -v
npm -v
```

## Step 1: Generate Adapter Baseline (3 minutes)

```bash
npx @skillshub/bap578-adapter-blueprint
```

Goal: produce a vault-aware adapter skeleton and align naming/interfaces.

## Step 2: Run Vault Safety Checks (3 minutes)

```bash
npx @skillshub/bap578-vault-checklist
```

Goal: validate token ownership checks and vault debit/credit controls.

## Step 3: Build Deploy Sequence (3 minutes)

```bash
npx @skillshub/bap578-deploy-plan
```

Goal: define deployment order and command sequence before touching mainnet/testnet.

## Step 4: Create Test Skeleton (2 minutes)

```bash
npx @skillshub/bap578-test-template
```

Goal: enforce auth and balance consistency checks from day one.

## Step 5: Convert Idea to Scope (2 minutes)

```bash
npx @skillshub/bap578-contract-idea-sprint
```

Goal: turn feature intent into an executable contract task list.

## Local Validation Commands

Run these before opening a PR:

```bash
npm ci
npm run compile
npm test
npm run lint
npx prettier --check 'contracts/**/*.sol'
```
