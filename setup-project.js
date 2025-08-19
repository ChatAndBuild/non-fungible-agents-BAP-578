const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const readline = require('readline');

// ANSI color codes for terminal output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
};

// Helper function to print colored output
function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

// Helper function to execute commands with error handling
function executeCommand(command, description) {
  try {
    log(`\n${description}...`, 'cyan');
    execSync(command, { stdio: 'inherit' });
    log(`✓ ${description} completed`, 'green');
    return true;
  } catch (error) {
    log(`✗ ${description} failed: ${error.message}`, 'red');
    return false;
  }
}

// Helper function to check if a command exists
function commandExists(command) {
  try {
    execSync(`which ${command}`, { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

// Create readline interface for user input
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

// Helper function to ask questions
function askQuestion(question) {
  return new Promise((resolve) => {
    rl.question(`${colors.yellow}${question}${colors.reset}`, (answer) => {
      resolve(answer);
    });
  });
}

// Main setup function
async function setupProject() {
  log('\n====================================', 'bright');
  log('BAP-700 Non-Fungible Agents Setup', 'bright');
  log('====================================\n', 'bright');

  // Step 1: Check Node.js version
  log('Checking Node.js version...', 'cyan');
  try {
    const nodeVersion = execSync('node --version', { encoding: 'utf8' }).trim();
    const majorVersion = parseInt(nodeVersion.split('.')[0].substring(1));

    if (majorVersion < 14) {
      log(
        `✗ Node.js version ${nodeVersion} is too old. Please install Node.js 14 or higher.`,
        'red',
      );
      process.exit(1);
    }
    log(`✓ Node.js ${nodeVersion} detected`, 'green');
  } catch (error) {
    log('✗ Node.js not found. Please install Node.js 14 or higher.', 'red');
    process.exit(1);
  }

  // Step 2: Check npm version
  log('\nChecking npm version...', 'cyan');
  try {
    const npmVersion = execSync('npm --version', { encoding: 'utf8' }).trim();
    log(`✓ npm ${npmVersion} detected`, 'green');
  } catch (error) {
    log('✗ npm not found. Please install npm.', 'red');
    process.exit(1);
  }

  // Step 3: Install dependencies
  const installDeps = await askQuestion('\nDo you want to install project dependencies? (y/n): ');
  if (installDeps.toLowerCase() === 'y') {
    executeCommand('npm install', 'Installing dependencies');
  }

  // Step 4: Create necessary directories
  log('\nCreating necessary directories...', 'cyan');
  const directories = ['artifacts', 'cache', 'coverage', 'deployments'];
  directories.forEach((dir) => {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
      log(`✓ Created ${dir} directory`, 'green');
    } else {
      log(`✓ ${dir} directory already exists`, 'green');
    }
  });

  // Step 5: Setup environment variables
  log('\nSetting up environment variables...', 'cyan');
  const envPath = path.join(__dirname, '.env');
  const envExamplePath = path.join(__dirname, '.env.example');

  if (!fs.existsSync(envPath)) {
    if (fs.existsSync(envExamplePath)) {
      const setupEnv = await askQuestion(
        '\nDo you want to create .env file from .env.example? (y/n): ',
      );
      if (setupEnv.toLowerCase() === 'y') {
        fs.copyFileSync(envExamplePath, envPath);
        log('✓ Created .env file from .env.example', 'green');

        log('\n⚠️  Important: Please update the following in your .env file:', 'yellow');
        log('  - DEPLOYER_PRIVATE_KEY: Your wallet private key', 'yellow');
        log('  - BSCSCAN_API_KEY: Your BSCScan API key', 'yellow');
        log('  - RPC URLs: Update if using custom RPC endpoints', 'yellow');
      }
    } else {
      log('✗ .env.example file not found', 'red');
    }
  } else {
    log('✓ .env file already exists', 'green');
  }

  // Step 6: Compile contracts
  const compileContracts = await askQuestion('\nDo you want to compile smart contracts? (y/n): ');
  if (compileContracts.toLowerCase() === 'y') {
    executeCommand('npm run compile', 'Compiling smart contracts');
  }

  // Step 7: Run tests
  const runTests = await askQuestion('\nDo you want to run tests? (y/n): ');
  if (runTests.toLowerCase() === 'y') {
    executeCommand('npm test', 'Running tests');
  }

  // Step 8: Check for additional tools
  log('\nChecking for additional tools...', 'cyan');

  if (commandExists('git')) {
    log('✓ Git is installed', 'green');
  } else {
    log('⚠️  Git is not installed. Consider installing Git for version control.', 'yellow');
  }

  if (commandExists('code')) {
    log('✓ VS Code command line tool is installed', 'green');
  } else {
    log('⚠️  VS Code command line tool is not installed.', 'yellow');
  }

  // Step 9: Display project information
  log('\n====================================', 'bright');
  log('Setup Complete!', 'bright');
  log('====================================\n', 'bright');

  log('Project Structure:', 'cyan');
  log('  contracts/        - Smart contract source files', 'reset');
  log('  scripts/          - Deployment and utility scripts', 'reset');
  log('  test/             - Test files', 'reset');
  log('  docs/             - Documentation', 'reset');
  log('  whitepaper/       - Project whitepaper', 'reset');

  log('\nAvailable Commands:', 'cyan');
  log('  npm run compile         - Compile smart contracts', 'reset');
  log('  npm test               - Run tests', 'reset');
  log('  npm run deploy:testnet - Deploy to BSC testnet', 'reset');
  log('  npm run deploy:mainnet - Deploy to BSC mainnet', 'reset');
  log('  npm run lint           - Lint Solidity files', 'reset');
  log('  npm run format         - Format Solidity files', 'reset');

  log('\nNext Steps:', 'cyan');
  log('  1. Update .env file with your private key and API keys', 'reset');
  log('  2. Review and customize smart contracts in contracts/', 'reset');
  log('  3. Write tests for your contracts in test/', 'reset');
  log('  4. Deploy to testnet first for testing', 'reset');
  log('  5. After testing, deploy to mainnet', 'reset');

  log('\nUseful Resources:', 'cyan');
  log('  - README.md           - Project documentation', 'reset');
  log('  - ARCHITECTURE.md     - System architecture', 'reset');
  log('  - CONTRACTS.md        - Contract documentation', 'reset');
  log('  - whitepaper/         - Detailed project whitepaper', 'reset');

  // Close readline interface
  rl.close();
}

// Run the setup
setupProject().catch((error) => {
  log(`\n✗ Setup failed: ${error.message}`, 'red');
  rl.close();
  process.exit(1);
});
