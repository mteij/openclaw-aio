const fs = require('fs');
const path = require('path');

const CONFIG_PATH = path.join(process.env.HOME || '/root', '.openclaw', 'openclaw.json');
const TOKEN = process.env.OPENCLAW_GATEWAY_TOKEN;

if (!TOKEN) {
    console.log('⚠️ No OPENCLAW_GATEWAY_TOKEN provided. Skipping token configuration.');
    process.exit(0);
}

try {
    let config = {};
    if (fs.existsSync(CONFIG_PATH)) {
        config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
    }

    // Ensure nested objects exist
    config.gateway = config.gateway || {};
    config.gateway.auth = config.gateway.auth || {};
    config.gateway.remote = config.gateway.remote || {};

    let updated = false;

    // Set auth token (for the gateway server)
    if (config.gateway.auth.token !== TOKEN) {
        config.gateway.auth.token = TOKEN;
        updated = true;
    }

    // Set remote token (for the client connecting to gateway)
    if (config.gateway.remote.token !== TOKEN) {
        config.gateway.remote.token = TOKEN;
        updated = true;
    }

    if (updated) {
        fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
        console.log('🔑 [OpenClaw-AIO] Configured gateway token in openclaw.json');
    } else {
        console.log('KEYS [OpenClaw-AIO] Gateway token already configured.');
    }

} catch (err) {
    console.error('❌ Failed to configure gateway token:', err);
    process.exit(1);
}
