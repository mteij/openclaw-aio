const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

console.log('🔍 [OpenClaw-AIO] Running startup checks...');
let hasErrors = false;

// 1. Check NODE_PATH
if (process.env.NODE_PATH !== '/app/node_modules') {
    console.error('❌ NODE_PATH is not set correctly to /app/node_modules');
    hasErrors = true;
} else {
    // console.log('✅ NODE_PATH set');
}

// 2. Check wrappers PATH priority
try {
    const npmPath = execSync('which npm', { encoding: 'utf8' }).trim();
    if (npmPath !== '/app/scripts/wrappers/npm') {
        console.error(`❌ Wrapper priority check failed: 'npm' found at ${npmPath}, expected /app/scripts/wrappers/npm`);
        hasErrors = true;
    } else {
        // console.log('✅ Wrapper PATH priority ok');
    }
} catch (e) {
    console.error('❌ Failed to check npm path');
    hasErrors = true;
}

// 3. Check Brew
try {
    execSync('brew --version', { stdio: 'ignore' });
    // console.log('✅ Brew available');
} catch (e) {
    console.error('❌ Brew not found or not working');
    hasErrors = true;
}

// 4. Check Playwright (without launching browser to be fast, just check deps)
try {
    require('playwright-core');
    // console.log('✅ Playwright-core module found');
} catch (e) {
    console.error('❌ Playwright-core module missing');
    hasErrors = true;
}

// Check if Chromium executable exists (basic check)
const playwrightCache = process.env.PLAYWRIGHT_BROWSERS_PATH || '/home/node/.cache/ms-playwright';
if (!fs.existsSync(playwrightCache)) {
    console.warn(`⚠️ Playwright cache directory missing at ${playwrightCache}`);
}

if (hasErrors) {
    console.error('⚠️ [OpenClaw-AIO] Some startup checks failed. See logs above.');
    // We do NOT exit(1) to avoid crash loops, just warn.
} else {
    console.log('✅ [OpenClaw-AIO] All systems operational (Wrappers, Brew, Playwright)');
}
