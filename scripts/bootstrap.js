const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

console.log('🦞 [OpenClaw-AIO] Bootstrapping environment...');

const OPENCLAW_DIR = path.join(os.homedir(), '.openclaw');
const PERSIST_FILES = {
    BREW: path.join(OPENCLAW_DIR, 'brew-packages.txt'),
    NPM: path.join(OPENCLAW_DIR, 'npm-packages.txt')
};

let hasWarnings = false;

// ============================================================================
// 1. ENVIRONMENT CHECKS
// ============================================================================
function checkEnv() {
    // Check NODE_PATH
    if (process.env.NODE_PATH !== '/app/node_modules') {
        console.warn('⚠️  NODE_PATH is not set correctly to /app/node_modules');
        hasWarnings = true;
    }

    // Check Wrappers Priority
    try {
        const npmPath = execSync('which npm', { encoding: 'utf8' }).trim();
        if (!npmPath.includes('/app/scripts/wrappers/npm')) {
            console.warn(`⚠️  Wrapper priority check failed: 'npm' found at ${npmPath}`);
            hasWarnings = true;
        }
    } catch (e) {
        console.warn('⚠️  Failed to check npm path');
        hasWarnings = true;
    }

    // Check Playwright Deps
    try {
        require('playwright-core');
    } catch (e) {
        console.warn('⚠️  Playwright-core module missing');
        hasWarnings = true;
    }
}

// ============================================================================
// 2. PACKAGE RESTORATION
// ============================================================================
function restorePackages() {
    // --- BREW ---
    if (fs.existsSync(PERSIST_FILES.BREW)) {
        try {
            const content = fs.readFileSync(PERSIST_FILES.BREW, 'utf8');
            const packages = content.split('\n')
                .map(l => l.trim())
                .filter(l => l && !l.startsWith('#'));

            if (packages.length > 0) {
                console.log(`🍺 Restoring ${packages.length} persistent brew packages...`);
                // Using the wrapper handling idempotency
                execSync(`brew install ${packages.join(' ')}`, { stdio: 'inherit' });
            }
        } catch (e) {
            console.error('❌ Failed to restore brew packages:', e.message);
            hasWarnings = true;
        }
    }

    // --- NPM ---
    if (fs.existsSync(PERSIST_FILES.NPM)) {
        try {
            const content = fs.readFileSync(PERSIST_FILES.NPM, 'utf8');
            const packages = content.split('\n')
                .map(l => l.trim())
                .filter(l => l && !l.startsWith('#'));

            if (packages.length > 0) {
                console.log(`📦 Restoring ${packages.length} persistent npm packages...`);
                execSync(`npm install -g ${packages.join(' ')}`, { stdio: 'inherit' });
            }
        } catch (e) {
            console.error('❌ Failed to restore npm packages:', e.message);
            hasWarnings = true;
        }
    }
}

// ============================================================================
// MAIN
// ============================================================================
try {
    checkEnv();
    restorePackages();
    
    if (hasWarnings) {
        console.log('⚠️  Bootstrap complete with warnings (see above).');
    } else {
        console.log('✅ [OpenClaw-AIO] Environment ready.');
    }
} catch (error) {
    console.error('❌ Bootstrap failed unexpected:', error);
    // Don't exit hard, let the container try to run the CMD anyway
}
