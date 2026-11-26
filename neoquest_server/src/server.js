/**
 * neoquest/neoquest_server/src/server.js
 * Main entry point for the treasure hunt API server
 * 
 * 20250712 10:16 V1.4 Mission Upload Server routes integrated
 * 20250721 13:06 V1.5 Added: New endpoint for package size calculation
 * 20250801 - Fixed import issues and Express 5 compatibility
 * 20250803 15:11 V1.6 - Added IP address detection and display for easier testing
 */

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const path = require('path');
const fs = require('fs').promises;
const os = require('os'); // <- Neu für IP-Erkennung

// Import custom modules
const { testConnection } = require('./config/database');
const logger = require('./utils/logger');
const { validateIPAccess } = require('./middleware/security');
const { errorHandler } = require('./middleware/errorHandler');

// Import routes
const authRoutes = require('./routes/auth');
const gameRoutes = require('./routes/game');
const uploadRoutes = require('./routes/upload');
const adminRoutes = require('./routes/admin');
const missionRoutes = require('./routes/mission');
const sessionRoutes = require('./routes/game_session');
const level1Routes = require('./routes/level1');

// ESP32 routes (optional)
let esp32Routes;
try {
  esp32Routes = require('./routes/esp32');
} catch (error) {
  esp32Routes = express.Router();
  esp32Routes.get('/test', (req, res) => {
    res.json({ message: 'ESP32 routes placeholder' });
  });
}

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

// Helper function to get all network interfaces
function getNetworkAddresses() {
  const interfaces = os.networkInterfaces();
  const addresses = [];
  
  Object.keys(interfaces).forEach(interfaceName => {
    interfaces[interfaceName].forEach(iface => {
      // Skip internal/loopback and non-IPv4 addresses
      if (iface.family === 'IPv4' && !iface.internal) {
        addresses.push({
          interface: interfaceName,
          address: iface.address,
          url: `http://${iface.address}:${PORT}`
        });
      }
    });
  });
  
  return addresses;
}

// Helper function to display server info beautifully
function displayServerInfo() {
  const networkAddresses = getNetworkAddresses();
  
  console.log('\n' + '='.repeat(60));
  console.log('🚀 NEOQUEST SERVER STARTED SUCCESSFULLY!');
  console.log('='.repeat(60));
  console.log(`📍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🕒 Started at: ${new Date().toLocaleString()}`);
  console.log('');
  
  if (networkAddresses.length > 0) {
    console.log('🌐 SERVER ACCESSIBLE AT:');
    console.log('-'.repeat(40));
    
    networkAddresses.forEach((addr, index) => {
      console.log(`${index + 1}. ${addr.interface.padEnd(12)} → ${addr.url}`);
      console.log(`   API Base URL: ${addr.url}/api`);
      console.log(`   Health Check: ${addr.url}/health`);
      console.log('');
    });
    
    // Highlight the most likely LAN address
    const lanAddress = networkAddresses.find(addr => 
      addr.address.startsWith('192.168.') || 
      addr.address.startsWith('10.') ||
      addr.address.startsWith('172.')
    );
    
    if (lanAddress) {
      console.log('📱 FOR MOBILE TESTING USE:');
      console.log('━'.repeat(40));
      console.log(`   ${lanAddress.url}`);
      console.log(`   (Copy this to your Flutter app's api_service.dart)`);
      console.log('');
    }
    
    // Show Android emulator info
    console.log('🤖 FOR ANDROID EMULATOR USE:');
    console.log('━'.repeat(40));
    console.log('   http://10.0.2.2:' + PORT);
    console.log('   (This is automatically mapped to host)');
    console.log('');
    
  } else {
    console.log('⚠️  No external network interfaces found');
    console.log(`   Server running on localhost:${PORT} only`);
    console.log('');
  }
  
  console.log('🔧 QUICK TESTS:');
  console.log('-'.repeat(40));
  console.log('• Browser: Open any URL above + /health');
  console.log('• cURL: curl -X GET [URL]/health');
  console.log('• Flutter: Use IP in api_service.dart');
  console.log('');
  console.log('🛑 To stop server: Press Ctrl+C');
  console.log('='.repeat(60));
  console.log('');
}

// Security Middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" },
  contentSecurityPolicy: false
}));

// Rate limiting
// Ausgenommen vom allgemeinen Limit:
// - /session/status: die App fragt im Warteraum und beim Countdown alle 1-2 s ab;
//   mit 60-80 Spieler:innen waere jedes Limit pro IP sofort erschoepft.
// - Admin-Pfade: dafuer gilt das eigene adminLimiter (bzw. kein Limit in development).
//   Vorher galt das allgemeine Limit trotzdem, weil app.use(..., next) nichts ueberspringt.
const RATE_LIMIT_EXEMPT = [
  /^\/session\/status\/?$/,
  /^\/admin\//,
  /^\/session\/admin\//
];

const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 1000,
  skip: (req) => RATE_LIMIT_EXEMPT.some((re) => re.test(req.path)),
  message: {
    error: 'Too many requests from this IP, please try again later',
    retryAfter: '15 minutes'
  },
  standardHeaders: true,
  legacyHeaders: false
});

const adminLimiter = rateLimit({
  windowMs: 1 * 60 * 1000,
  max: 50,
  message: {
    error: 'Too many admin requests, please wait a moment',
    retryAfter: '1 minute'
  },
  standardHeaders: true,
  legacyHeaders: false
});

// Admin-Limit nur ausserhalb von development (vom allgemeinen Limit sind Admin-Pfade ausgenommen)
if (process.env.NODE_ENV !== 'development') {
  app.use('/api/session/admin/', adminLimiter);
  app.use('/api/admin/', adminLimiter);
}

app.use('/api/', limiter);

// IP Access Control (production only)
if (process.env.NODE_ENV === 'production') {
  app.use(validateIPAccess);
}

// CORS Configuration
const corsOptions = {
  origin: function (origin, callback) {
    if (!origin) return callback(null, true);
    if (process.env.NODE_ENV === 'development') {
      return callback(null, true);
    }
    callback(null, true);
  },
  credentials: true,
  optionsSuccessStatus: 200
};

if (process.env.ENABLE_CORS === 'true') {
  app.use(cors(corsOptions));
}

// Body parsing middleware
app.use(express.json({ 
  limit: process.env.UPLOAD_MAX_SIZE || '50mb',
  verify: (req, res, buf) => {
    req.rawBody = buf;
  }
}));
app.use(express.urlencoded({ 
  extended: true, 
  limit: process.env.UPLOAD_MAX_SIZE || '50mb' 
}));

// Compression and logging
app.use(compression());

if (process.env.ENABLE_REQUEST_LOGGING === 'true') {
  app.use(morgan('combined', {
    stream: {
      write: (message) => logger.info(message.trim())
    }
  }));
}

// Static file serving
app.use('/media', express.static(path.join(__dirname, '../media')));
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// Enhanced health check endpoint with network info
app.get('/health', async (req, res) => {
  try {
    let dbStatus = 'unknown';
    try {
      const dbConnected = await testConnection();
      dbStatus = dbConnected ? 'connected' : 'disconnected';
    } catch (error) {
      dbStatus = 'error';
    }
    
    // Include network information in health response
    const networkAddresses = getNetworkAddresses();
    
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: require('../package.json').version,
      database: dbStatus,
      uptime: process.uptime(),
      environment: process.env.NODE_ENV,
      server: {
        host: HOST,
        port: PORT,
        network_addresses: networkAddresses
      }
    });
  } catch (error) {
    logger.error('Health check failed:', error);
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: 'Health check failed'
    });
  }
});

// Root endpoint with network info
app.get('/', (req, res) => {
  const networkAddresses = getNetworkAddresses();
  
  res.json({
    message: 'NeoQuest Server is running!',
    version: require('../package.json').version,
    timestamp: new Date().toISOString(),
    server_info: {
      host: HOST,
      port: PORT,
      network_addresses: networkAddresses
    },
    endpoints: {
      health: '/health',
      api_docs: process.env.NODE_ENV === 'development' ? '/api/docs' : null
    },
    mobile_testing: {
      android_emulator: `http://10.0.2.2:${PORT}/api`,
      physical_device: networkAddresses.length > 0 ? `${networkAddresses[0].url}/api` : 'Check network addresses above'
    }
  });
});

// New endpoint specifically for client IP discovery
app.get('/network-info', (req, res) => {
  const networkAddresses = getNetworkAddresses();
  
  res.json({
    timestamp: new Date().toISOString(),
    server_addresses: networkAddresses,
    client_ip: req.ip || req.connection.remoteAddress,
    recommendations: {
      android_emulator: `http://10.0.2.2:${PORT}/api`,
      physical_device: networkAddresses.length > 0 ? `${networkAddresses[0].url}/api` : null,
      localhost: `http://localhost:${PORT}/api`
    }
  });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/game', gameRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/esp32', esp32Routes);
app.use('/api/level1', level1Routes);
app.use('/api/mission', missionRoutes);
app.use('/api/session', sessionRoutes);

// API Documentation (development only)
if (process.env.ENABLE_API_DOCS === 'true' && process.env.NODE_ENV === 'development') {
  app.get('/api/docs', (req, res) => {
    const networkAddresses = getNetworkAddresses();
    
    res.json({
      title: 'NeoQuest API Documentation',
      version: '1.0.0',
      server_info: {
        addresses: networkAddresses,
        recommendations: {
          android_emulator: `http://10.0.2.2:${PORT}/api`,
          physical_device: networkAddresses.length > 0 ? `${networkAddresses[0].url}/api` : null
        }
      },
      endpoints: {
        network: {
          'GET /network-info': 'Get server network information for client setup'
        },
        auth: {
          'POST /api/auth/register': 'Register player with QR token',
          'POST /api/auth/verify': 'Verify token validity'
        },
        game: {
          'GET /api/game/data': 'Get game data for player',
          'GET /api/game/data/:game_id': 'Download complete game package',
          'GET /api/game/media/:game_slug/...': 'Serve media files'
        },
        upload: {
          'POST /api/upload/results': 'Upload game results with files',
          'POST /api/upload/gps-track': 'Upload GPS tracking data',
          'POST /api/upload/photo': 'Upload photos'
        },
        admin: {
          'GET /api/admin/routes': 'Get all player routes',
          'GET /api/admin/stats': 'Get game statistics',
          'GET /api/admin/players': 'Get all players',
          'POST /api/admin/generate-token': 'Generate single token',
          'POST /api/admin/generate-tokens': 'Generate multiple tokens'
        },
        mission: {
          'POST /api/mission/upload-route': 'Upload GPS route data',
          'POST /api/mission/upload-photos': 'Upload photo evidence',
          'POST /api/mission/complete': 'Mark mission as complete'
        },
        session: {
          'GET /api/session/status': 'Get session status for polling',
          'POST /api/session/ready': 'Mark player as ready',
          'POST /api/session/admin/start': 'Admin start game session',
          'POST /api/session/admin/countdown/:seconds': 'Admin start countdown'
        }
      }
    });
  });
}

// 404 handler
app.all('/*catchall', (req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    path: req.originalUrl,
    method: req.method,
    timestamp: new Date().toISOString(),
    tip: 'Visit / for available endpoints or /health for server status'
  });
});

// Error handling middleware
app.use(errorHandler);

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');  
  process.exit(0);
});

// Start server
async function startServer() {
  try {
    await ensureDirectories();
    
    app.listen(PORT, HOST, () => {
      // Use the enhanced display function
      displayServerInfo();
      
      // Test database connection after server start
      testDatabaseConnection();
    });
    
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Database connection test (async)
async function testDatabaseConnection() {
  try {
    const dbConnected = await testConnection();
    if (dbConnected) {
      logger.info('✅ Database connection successful');
    } else {
      logger.warn('⚠️ Database connection failed');
    }
  } catch (error) {
    logger.error('❌ Database connection error:', error.message);
  }
}

// Ensure required directories exist
async function ensureDirectories() {
  const dirs = [
    process.env.UPLOAD_DIR || './uploads', 
    './uploads/missions',
    process.env.MEDIA_DIR || './media', 
    process.env.TEMP_DIR || './temp',
    './logs'
  ];
  
  for (const dir of dirs) {
    try {
      await fs.mkdir(path.resolve(dir), { recursive: true });
    } catch (error) {
      logger.error(`Failed to create directory ${dir}:`, error);
    }
  }
}

startServer();

module.exports = app;